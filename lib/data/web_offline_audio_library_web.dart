import 'dart:async';
import 'dart:collection';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'generator_data.dart';
import 'offline_zip_index.dart';

/// Browser adapter for the immutable offline pack.
///
/// The archive is ZIP_STORED: this reads the ZIP64 central directory once, then
/// retrieves only the local header and Ogg/Opus bytes for a requested clip with
/// same-origin HTTP Range requests. It never downloads or inflates the complete
/// 467-MB data pack.
class WebOfflineAudioLibrary {
  WebOfflineAudioLibrary({this.archiveUrl});

  static const _archiveAsset =
      '$assetRoot/offline/ansagengenerator-offline-opus-data.zip';
  static const _expectedArchiveBytes = 467116673;
  static const _expectedEntryCount = 87902;
  static const _tailBytes = 65557;
  static const _maxCachedBlobBytes = 16 * 1024 * 1024;

  /// Explicit archive URL for controlled browser tests or custom hosting.
  final String? archiveUrl;
  final _BlobUrlCache _blobUrls = _BlobUrlCache(_maxCachedBlobBytes);
  late final _HttpRangeReader _reader = _HttpRangeReader(
    archiveUrl ?? Uri.base.resolve('assets/$_archiveAsset').toString(),
  );
  Future<_WebZipArchive>? _archive;

  Future<Source> sourceForLogicalPath(String rawPath) async {
    final key = OfflineArchivePath.toArchiveKey(rawPath);
    if (key == null) {
      throw ArgumentError('Ungültiger Offline-Audiopfad: $rawPath');
    }
    final cached = _blobUrls.urlFor(key);
    if (cached != null) return UrlSource(cached);
    final bytes = await _library().then((archive) => archive.readEntry(key));
    final blob = _createBlob(bytes, 'audio/ogg; codecs=opus');
    final url = web.URL.createObjectURL(blob);
    _blobUrls.put(key, url, bytes.lengthInBytes);
    return UrlSource(url);
  }

  Future<String> exportWav(List<String> rawPaths) async {
    if (rawPaths.isEmpty) {
      throw ArgumentError('Keine Audios zum Exportieren.');
    }
    final audioContext = _newAudioContext();
    try {
      final encoded = await Future.wait(rawPaths.map(_readRawPath));
      final decoded = <web.AudioBuffer>[];
      for (final clip in encoded) {
        decoded.add(await _decodeAudio(audioContext, clip));
      }
      final wav = _encodeMonoWav(decoded);
      final filename = 'ansage-${_timestamp()}.wav';
      final blob = _createBlob(wav, 'audio/wav');
      final url = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download = filename
        ..style.display = 'none';
      web.document.body?.appendChild(anchor);
      anchor.click();
      anchor.remove();
      Timer(const Duration(seconds: 5), () => web.URL.revokeObjectURL(url));
      return 'Download gestartet: $filename';
    } finally {
      await _closeAudioContext(audioContext);
    }
  }

  void dispose() {
    _blobUrls.dispose();
  }

  Future<_WebZipArchive> _library() =>
      _archive ??= _WebZipArchive.open(_reader);

  Future<Uint8List> _readRawPath(String rawPath) async {
    if (rawPath.startsWith('asset:/')) {
      final asset = rawPath.substring('asset:/'.length);
      if (asset.isEmpty || asset.contains('..')) {
        throw ArgumentError('Ungültiger Flutter-Audiopfad: $rawPath');
      }
      final byteData = await rootBundle.load('$assetRoot/$asset');
      return byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
    }
    final key = OfflineArchivePath.toArchiveKey(rawPath);
    if (key == null) {
      throw ArgumentError('Ungültiger Offline-Audiopfad: $rawPath');
    }
    return _library().then((archive) => archive.readEntry(key));
  }

  static Uint8List _encodeMonoWav(List<web.AudioBuffer> buffers) {
    if (buffers.isEmpty) {
      throw ArgumentError('Keine decodierten Audio-Bausteine.');
    }
    final sampleRate = buffers.first.sampleRate.round();
    if (sampleRate <= 0) {
      throw const FormatException(
        'Browser lieferte keine gültige Audio-Samplerate.',
      );
    }
    var frames = 0;
    for (final buffer in buffers) {
      final channels = buffer.numberOfChannels;
      final length = buffer.length;
      if (buffer.sampleRate.round() != sampleRate ||
          channels <= 0 ||
          length <= 0) {
        throw const FormatException(
          'Audio-Bausteine besitzen inkompatible Formate.',
        );
      }
      frames += length;
    }
    final dataBytes = frames * 2;
    final output = ByteData(44 + dataBytes);
    _writeAscii(output, 0, 'RIFF');
    output.setUint32(4, 36 + dataBytes, Endian.little);
    _writeAscii(output, 8, 'WAVE');
    _writeAscii(output, 12, 'fmt ');
    output.setUint32(16, 16, Endian.little);
    output.setUint16(20, 1, Endian.little);
    output.setUint16(22, 1, Endian.little);
    output.setUint32(24, sampleRate, Endian.little);
    output.setUint32(28, sampleRate * 2, Endian.little);
    output.setUint16(32, 2, Endian.little);
    output.setUint16(34, 16, Endian.little);
    _writeAscii(output, 36, 'data');
    output.setUint32(40, dataBytes, Endian.little);

    var target = 44;
    for (final buffer in buffers) {
      final channels = buffer.numberOfChannels;
      final length = buffer.length;
      final samples = List<Float32List>.generate(
        channels,
        (channel) => buffer.getChannelData(channel).toDart,
        growable: false,
      );
      for (var frame = 0; frame < length; frame++) {
        var value = 0.0;
        for (final channel in samples) {
          value += channel[frame];
        }
        final pcm = (value / channels * 32767)
            .round()
            .clamp(-32768, 32767)
            .toInt();
        output.setInt16(target, pcm, Endian.little);
        target += 2;
      }
    }
    return output.buffer.asUint8List();
  }

  static web.AudioContext _newAudioContext() {
    try {
      return web.AudioContext();
    } catch (error) {
      throw StateError(
        'Dieser Browser unterstützt den benötigten Web-Audio-Decoder nicht: $error',
      );
    }
  }

  static Future<web.AudioBuffer> _decodeAudio(
    web.AudioContext context,
    Uint8List clip,
  ) => context.decodeAudioData(Uint8List.fromList(clip).buffer.toJS).toDart;

  static Future<void> _closeAudioContext(web.AudioContext context) async {
    await context.close().toDart;
  }

  static web.Blob _createBlob(Uint8List bytes, String mimeType) => web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );

  static void _writeAscii(ByteData output, int offset, String text) {
    for (var index = 0; index < text.length; index++) {
      output.setUint8(offset + index, text.codeUnitAt(index));
    }
  }

  static String _timestamp() {
    final now = DateTime.now();
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${pad(now.month)}${pad(now.day)}-${pad(now.hour)}${pad(now.minute)}${pad(now.second)}';
  }
}

class _WebZipArchive {
  _WebZipArchive._(this._reader, this._archiveLength, this._index);

  final _HttpRangeReader _reader;
  final int _archiveLength;
  final OfflineZipIndex _index;

  static Future<_WebZipArchive> open(_HttpRangeReader reader) async {
    final tail = await reader.readSuffix(WebOfflineAudioLibrary._tailBytes);
    if (tail.totalLength != WebOfflineAudioLibrary._expectedArchiveBytes) {
      throw StateError(
        'Offline-Bibliothek hat unerwartete Größe: ${tail.totalLength} Byte.',
      );
    }
    var location = OfflineZipDirectoryLocator.parseTail(
      tail.bytes,
      tailFileOffset: tail.start,
      archiveLength: tail.totalLength,
    );
    final zip64EndOffset = location.zip64EndRecordOffset;
    if (zip64EndOffset != null) {
      final endRecord = await reader.readRange(
        zip64EndOffset,
        zip64EndOffset + 55,
      );
      location = OfflineZipDirectoryLocator.parseZip64EndRecord(
        endRecord.bytes,
      );
    }
    final directoryOffset = location.centralDirectoryOffset;
    final directorySize = location.centralDirectorySize;
    final entryCount = location.entryCount;
    if (directoryOffset == null ||
        directorySize == null ||
        entryCount != WebOfflineAudioLibrary._expectedEntryCount ||
        directorySize <= 0 ||
        directoryOffset < 0 ||
        directoryOffset + directorySize > tail.totalLength) {
      throw const FormatException(
        'Offline-Bibliothek enthält kein gültiges vollständiges ZIP-Verzeichnis.',
      );
    }
    final directory = await reader.readRange(
      directoryOffset,
      directoryOffset + directorySize - 1,
    );
    final index = OfflineZipIndex.parseCentralDirectory(directory.bytes);
    if (index.entryCount != WebOfflineAudioLibrary._expectedEntryCount) {
      throw const FormatException(
        'Offline-Bibliothek enthält nicht alle erwarteten Audio-Dateien.',
      );
    }
    return _WebZipArchive._(reader, tail.totalLength, index);
  }

  Future<Uint8List> readEntry(String path) async {
    final entry = _index.requireStored(path);
    final headerEnd = (entry.localHeaderOffset + 65535).clamp(
      entry.localHeaderOffset,
      _archiveLength - 1,
    );
    final header = await _reader.readRange(entry.localHeaderOffset, headerEnd);
    final dataOffset = OfflineZipIndex.dataOffsetFromLocalHeader(
      header.bytes,
      entry,
    );
    if (dataOffset < 0 || dataOffset + entry.compressedSize > _archiveLength) {
      throw FormatException(
        'Audio-Datei liegt außerhalb der Offline-Bibliothek: $path',
      );
    }
    final payload = await _reader.readRange(
      dataOffset,
      dataOffset + entry.compressedSize - 1,
    );
    if (payload.bytes.lengthInBytes != entry.uncompressedSize) {
      throw FormatException('Audio-Datei hat eine ungültige Länge: $path');
    }
    return payload.bytes;
  }
}

class _HttpRangeReader {
  _HttpRangeReader(this.url);

  final String url;

  Future<_RangePayload> readSuffix(int maxBytes) =>
      _request('bytes=-$maxBytes');

  Future<_RangePayload> readRange(int start, int end) {
    if (start < 0 || end < start) {
      throw ArgumentError('Ungültiger HTTP-Range: $start-$end');
    }
    return _request('bytes=$start-$end');
  }

  Future<_RangePayload> _request(String range) async {
    final headers = web.Headers()..set('Range', range);
    final response = await web.window
        .fetch(url.toJS, web.RequestInit(method: 'GET', headers: headers))
        .toDart;
    if (response.status != 206) {
      throw StateError(
        'Der Webserver muss HTTP-Range-Anfragen für die Offline-Bibliothek unterstützen (Antwort ${response.status}).',
      );
    }
    final contentRange = response.headers.get('Content-Range');
    final match = RegExp(
      r'^bytes (\d+)-(\d+)/(\d+)$',
    ).firstMatch(contentRange ?? '');
    if (match == null) {
      throw const FormatException(
        'HTTP-Range-Antwort enthält keinen gültigen Content-Range-Header.',
      );
    }
    final start = int.parse(match.group(1)!);
    final end = int.parse(match.group(2)!);
    final total = int.parse(match.group(3)!);
    final bytes = (await response.bytes().toDart).toDart;
    if (start > end || end >= total || bytes.lengthInBytes != end - start + 1) {
      throw const FormatException(
        'HTTP-Range-Antwort hat eine inkonsistente Länge.',
      );
    }
    return _RangePayload(bytes: bytes, start: start, totalLength: total);
  }
}

class _RangePayload {
  const _RangePayload({
    required this.bytes,
    required this.start,
    required this.totalLength,
  });

  final Uint8List bytes;
  final int start;
  final int totalLength;
}

class _BlobUrlCache {
  _BlobUrlCache(this.maxBytes);

  final int maxBytes;
  final LinkedHashMap<String, _CachedBlobUrl> _urls =
      LinkedHashMap<String, _CachedBlobUrl>();
  var _usedBytes = 0;

  String? urlFor(String key) {
    final existing = _urls.remove(key);
    if (existing == null) return null;
    _urls[key] = existing;
    return existing.url;
  }

  void put(String key, String url, int bytes) {
    final previous = _urls.remove(key);
    if (previous != null) {
      _usedBytes -= previous.bytes;
      web.URL.revokeObjectURL(previous.url);
    }
    _urls[key] = _CachedBlobUrl(url, bytes);
    _usedBytes += bytes;
    while (_usedBytes > maxBytes && _urls.isNotEmpty) {
      final oldestKey = _urls.keys.first;
      final oldest = _urls.remove(oldestKey)!;
      _usedBytes -= oldest.bytes;
      web.URL.revokeObjectURL(oldest.url);
    }
  }

  void dispose() {
    for (final entry in _urls.values) {
      web.URL.revokeObjectURL(entry.url);
    }
    _urls.clear();
    _usedBytes = 0;
  }
}

class _CachedBlobUrl {
  const _CachedBlobUrl(this.url, this.bytes);

  final String url;
  final int bytes;
}
