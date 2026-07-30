import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/in_train_sequence.dart';
import '../data/generator_data.dart';
import 'web_offline_audio_library.dart';

enum PlaybackState {
  idle,
  playing,
  paused,
  waitingForNextStop,
  finished,
  failed,
}

/// The station-stop state must retain the already assembled queue and advance
/// from its current index instead of creating a fresh announcement.
extension PlaybackStateQueueContinuation on PlaybackState {
  bool get continuesQueuedPlayback => this == PlaybackState.waitingForNextStop;
}

/// Cross-platform queue player. Curated Im-Zug atoms use ordinary Flutter
/// assets everywhere; the large historical archive is resolved through the
/// Android bridge without loading or unpacking the whole archive.
class AnnouncementAudioController extends ChangeNotifier {
  /// The Flutter asset keys in this project start at `source-android/`, not
  /// at the audioplayers default `assets/` prefix.
  static void configureCuratedAssetCache() {
    AudioCache.instance = AudioCache(prefix: '');
  }

  AnnouncementAudioController() {
    configureCuratedAssetCache();
    _player.audioCache = AudioCache.instance;
    _completion = _player.onPlayerComplete.listen((_) => _onPlayerComplete());
  }

  static const _channel = MethodChannel('de.shedowe.ansagengenerator/audio');
  final AudioPlayer _player = AudioPlayer();
  final WebOfflineAudioLibrary _webAudio = WebOfflineAudioLibrary();
  late final StreamSubscription<void> _completion;
  final List<String> _queue = <String>[];
  int _index = 0;
  bool _pauseAfterStation = false;
  PlaybackState state = PlaybackState.idle;
  String status = 'Bereit';

  Future<void> play(
    List<String> paths, {
    required bool pauseAfterStations,
  }) async {
    await stop(silent: true);
    if (paths.isEmpty) {
      throw ArgumentError('Keine Audio-Bausteine in der Ansage.');
    }
    _queue.addAll(paths);
    _pauseAfterStation = pauseAfterStations;
    _index = 0;
    await _startNext();
  }

  Future<void> resume() async {
    if (state == PlaybackState.waitingForNextStop) {
      await _startNext();
      return;
    }
    if (state == PlaybackState.paused) {
      await _player.resume();
      state = PlaybackState.playing;
      status = 'Wiedergabe $_index/${_queue.length}';
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (state != PlaybackState.playing) return;
    await _player.pause();
    state = PlaybackState.paused;
    status = 'Pausiert · $_index/${_queue.length}';
    notifyListeners();
  }

  Future<void> stop({bool silent = false}) async {
    _queue.clear();
    _index = 0;
    await _player.stop();
    if (!silent) {
      state = PlaybackState.idle;
      status = 'Gestoppt';
      notifyListeners();
    }
  }

  Future<String> exportWav(List<String> paths) async {
    if (paths.isEmpty) throw ArgumentError('Keine Audios zum Exportieren.');
    if (kIsWeb) return _webAudio.exportWav(paths);
    final export = await _channel.invokeMethod<String>(
      'exportWav',
      <String, Object>{'paths': paths},
    );
    if (export == null || export.isEmpty) {
      throw StateError('Android hat keinen Exportpfad zurückgegeben.');
    }
    return export;
  }

  Future<void> _startNext() async {
    if (_index >= _queue.length) {
      state = PlaybackState.finished;
      status = 'Ansage fertig';
      notifyListeners();
      return;
    }
    final rawPath = _queue[_index++];
    try {
      final source = await _sourceFor(rawPath);
      await _player.play(source);
      state = PlaybackState.playing;
      status =
          'Wiedergabe $_index/${_queue.length} · ${rawPath.split('/').last}';
      notifyListeners();
    } catch (error) {
      state = PlaybackState.failed;
      status = 'Audiofehler: $error';
      notifyListeners();
      rethrow;
    }
  }

  Future<Source> _sourceFor(String rawPath) async {
    if (rawPath.startsWith('asset:/')) {
      return AssetSource('$assetRoot/${rawPath.substring('asset:/'.length)}');
    }
    if (kIsWeb) return _webAudio.sourceForLogicalPath(rawPath);
    final resolved = await _channel.invokeMethod<List<Object?>>(
      'resolveAudioPaths',
      <String, Object>{
        'paths': <String>[rawPath],
      },
    );
    final file = resolved?.cast<String>().singleOrNull;
    if (file == null || file.isEmpty) {
      throw StateError(
        'Die Offline-Bibliothek konnte diesen Baustein nicht bereitstellen: $rawPath',
      );
    }
    return DeviceFileSource(file);
  }

  void _onPlayerComplete() {
    if (_index == 0 || _queue.isEmpty) return;
    final finished = _queue[_index - 1];
    final hasNextEntry = _index < _queue.length;
    final pauseAfterStation =
        hasNextEntry &&
        _pauseAfterStation &&
        InTrainSequence.shouldPauseAfterQueueEntry(true, finished);
    final pauseBeforeNextGong =
        hasNextEntry &&
        _pauseAfterStation &&
        InTrainSequence.shouldPauseBeforeQueueEntry(true, _queue[_index]);
    if (pauseAfterStation || pauseBeforeNextGong) {
      state = PlaybackState.waitingForNextStop;
      status = pauseBeforeNextGong
          ? 'Nächste Station bereit · Nächster Halt'
          : 'Haltestelle fertig · Nächster Halt bereit';
      notifyListeners();
      return;
    }
    unawaited(_startNext());
  }

  @override
  void dispose() {
    _completion.cancel();
    _webAudio.dispose();
    _player.dispose();
    super.dispose();
  }
}
