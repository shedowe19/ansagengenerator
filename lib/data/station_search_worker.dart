import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../core/station_search.dart';

/// Sendable startup snapshot for the dedicated station-search isolate.
class StationSearchPayload {
  const StationSearchPayload({
    required this.stationsJson,
    required this.rilJson,
  });

  final String stationsJson;
  final String rilJson;
}

/// A single long-lived worker equivalent to the native app's one-thread search
/// executor. On Web, Dart's `ReceivePort`/`Isolate.spawn` transport is not
/// available, so the already indexed search runs in a scheduled in-process
/// task after the same debounce/stale-result guard.
class StationSearchWorker {
  StationSearchWorker._native(this._inbox) : _inProcessIndex = null;

  StationSearchWorker._inProcess(this._inProcessIndex) : _inbox = null;

  static const _maxResults = 18;

  final ReceivePort? _inbox;
  final StationSearchIndex? _inProcessIndex;
  final Completer<void> _ready = Completer<void>();
  final Map<int, Completer<List<StationSearchResult>>> _pending =
      <int, Completer<List<StationSearchResult>>>{};
  StreamSubscription<dynamic>? _subscription;
  Isolate? _isolate;
  SendPort? _workerPort;
  int _nextRequestId = 0;
  bool _disposed = false;

  static Future<StationSearchWorker> start(StationSearchPayload payload) =>
      kIsWeb ? startInProcess(payload) : _startNative(payload);

  /// Browser fallback for runtimes without `ReceivePort` support. Kept public
  /// so the behavior can be regression-tested on the VM as well.
  static Future<StationSearchWorker> startInProcess(
    StationSearchPayload payload,
  ) async {
    final index = StationSearchIndex(
      stations: _decodeStations(payload.stationsJson),
      rilEntries: _decodeRil(payload.rilJson),
    );
    return StationSearchWorker._inProcess(index);
  }

  static Future<StationSearchWorker> _startNative(
    StationSearchPayload payload,
  ) async {
    final worker = StationSearchWorker._native(ReceivePort());
    worker._subscription = worker._inbox!.listen(worker._onMessage);
    worker._isolate = await Isolate.spawn<Map<String, Object?>>(
      _workerMain,
      <String, Object?>{
        'reply': worker._inbox.sendPort,
        'stationsJson': payload.stationsJson,
        'rilJson': payload.rilJson,
      },
      debugName: 'station-search',
      errorsAreFatal: true,
    );
    await worker._ready.future;
    return worker;
  }

  Future<List<StationSearchResult>> search(String query) async {
    if (_disposed) {
      throw StateError('Die Stationssuche wurde bereits beendet.');
    }
    final inProcessIndex = _inProcessIndex;
    if (inProcessIndex != null) {
      // Schedule after the current event so the UI can render its pending state.
      return Future<List<StationSearchResult>>(
        () => inProcessIndex.search(query, maxResults: _maxResults),
      );
    }
    await _ready.future;
    final requestId = ++_nextRequestId;
    final completion = Completer<List<StationSearchResult>>();
    _pending[requestId] = completion;
    _workerPort!.send(<String, Object?>{
      'type': 'search',
      'id': requestId,
      'query': query,
      'maxResults': _maxResults,
    });
    return completion.future;
  }

  void _onMessage(dynamic message) {
    if (message is List) {
      _fail(StateError('Stationssuche ist abgestürzt: $message'));
      return;
    }
    if (message is! Map) return;
    final type = message['type'];
    if (type == 'ready') {
      final port = message['port'];
      if (port is SendPort) {
        _workerPort = port;
        if (!_ready.isCompleted) _ready.complete();
      }
      return;
    }
    if (type == 'error') {
      _fail(StateError('${message['message'] ?? 'Unbekannter Suchfehler'}'));
      return;
    }
    if (type != 'results') return;
    final requestId = message['id'];
    if (requestId is! int) return;
    final completion = _pending.remove(requestId);
    if (completion == null || completion.isCompleted) return;
    final rawResults = message['results'];
    if (rawResults is! List) {
      completion.completeError(StateError('Ungültige Suchantwort.'));
      return;
    }
    completion.complete(
      rawResults
          .whereType<Map>()
          .map(
            (raw) => StationSearchResult(
              title: '${raw['title'] ?? ''}',
              subtitle: '${raw['subtitle'] ?? ''}',
              filepath: '${raw['filepath'] ?? ''}',
              score: (raw['score'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(growable: false),
    );
  }

  void _fail(Object error) {
    if (!_ready.isCompleted) _ready.completeError(error);
    for (final completion in _pending.values) {
      if (!completion.isCompleted) completion.completeError(error);
    }
    _pending.clear();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    if (_inProcessIndex == null) {
      _fail(StateError('Die Stationssuche wurde beendet.'));
    }
    unawaited(_subscription?.cancel());
    _inbox?.close();
  }
}

void _workerMain(Map<String, Object?> config) {
  final reply = config['reply']! as SendPort;
  try {
    final stations = _decodeStations(config['stationsJson'] as String);
    final ril = _decodeRil(config['rilJson'] as String);
    final index = StationSearchIndex(stations: stations, rilEntries: ril);
    final inbox = ReceivePort();
    reply.send(<String, Object?>{'type': 'ready', 'port': inbox.sendPort});
    inbox.listen((dynamic message) {
      if (message is! Map || message['type'] != 'search') return;
      final requestId = message['id'];
      final query = message['query'];
      final maxResults = message['maxResults'];
      if (requestId is! int || query is! String || maxResults is! int) return;
      try {
        final results = index.search(query, maxResults: maxResults);
        reply.send(<String, Object?>{
          'type': 'results',
          'id': requestId,
          'results': results
              .map(
                (result) => <String, Object>{
                  'title': result.title,
                  'subtitle': result.subtitle,
                  'filepath': result.filepath,
                  'score': result.score,
                },
              )
              .toList(growable: false),
        });
      } catch (error) {
        reply.send(<String, Object?>{
          'type': 'error',
          'message': error.toString(),
        });
      }
    });
  } catch (error) {
    reply.send(<String, Object?>{'type': 'error', 'message': error.toString()});
  }
}

List<StationEntry> _decodeStations(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw const FormatException('stations.json ist ungültig.');
  }
  return decoded
      .whereType<Map>()
      .map((value) => StationEntry.fromJson(Map<String, dynamic>.from(value)))
      .toList(growable: false);
}

List<RilEntry> _decodeRil(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw const FormatException('ril100.json ist ungültig.');
  }
  return decoded
      .whereType<Map>()
      .map((value) => RilEntry.fromJson(Map<String, dynamic>.from(value)))
      .toList(growable: false);
}
