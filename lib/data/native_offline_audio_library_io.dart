import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'generator_data.dart';
import 'offline_zip_index.dart';

typedef NativeWavConverter =
    Future<String> Function(String inputPath, String outputPath);
typedef NativeAssetLoader = Future<ByteData> Function(String key);

/// Reads individual ZIP_STORED Opus clips from the native Flutter bundle.
///
/// Desktop and iOS releases contain Flutter assets as ordinary files. Reading
/// the ZIP directly avoids loading the 467 MB archive into Dart memory and
/// avoids the Android-only `de.shedowe.ansagengenerator/audio` channel.
class NativeOfflineAudioLibrary {
  NativeOfflineAudioLibrary({
    File? archiveFile,
    Directory? cacheDirectory,
    Directory? exportDirectory,
    NativeWavConverter? convertToWav,
    NativeAssetLoader? loadAsset,
  }) : _archiveFileOverride = archiveFile,
       _cacheDirectoryOverride = cacheDirectory,
       _exportDirectoryOverride = exportDirectory,
       _convertToWav = convertToWav ?? _decodeToPcmWav,
       _loadAsset = loadAsset ?? rootBundle.load;

  static const _archiveAsset =
      '$assetRoot/offline/ansagengenerator-offline-opus-data.zip';
  static const _tailLength = 65557;
  static const _pcmSampleRate = 48000;
  static const _pcmChannels = 1;
  static const _pcmBitDepth = 16;

  final File? _archiveFileOverride;
  final Directory? _cacheDirectoryOverride;
  final Directory? _exportDirectoryOverride;
  final NativeWavConverter _convertToWav;
  final NativeAssetLoader _loadAsset;
  final Map<String, Future<File>> _materializing = <String, Future<File>>{};
  final Map<String, Future<File>> _normalizing = <String, Future<File>>{};

  late final Future<File> _archiveFile = _resolveArchiveFile();
  late final Future<Directory> _cacheDirectory = _resolveCacheDirectory();
  late final Future<_NativeZipArchive> _archive = _openArchive();

  /// Returns a locally cached PCM WAV source for native playback.
  Future<Source> sourceForLogicalPath(String rawPath) async =>
      DeviceFileSource((await _normalizedForPlayback(rawPath)).path);

  /// Materializes one logical playlist path as its original physical file.
  Future<File> materializeForPlayback(String rawPath) {
    final normalized = rawPath.trim();
    final existing = _materializing[normalized];
    if (existing != null) return existing;
    final created = _materialize(normalized);
    _materializing[normalized] = created;
    return created.whenComplete(() => _materializing.remove(normalized));
  }

  Future<File> _normalizedForPlayback(String rawPath) {
    final normalized = rawPath.trim();
    final existing = _normalizing[normalized];
    if (existing != null) return existing;
    final created = _convertForPlayback(normalized);
    _normalizing[normalized] = created;
    return created.whenComplete(() => _normalizing.remove(normalized));
  }

  /// Converts every source clip to uniform 48 kHz mono PCM and joins it into
  /// a single WAV file in the user's documents folder (or the injected test
  /// output folder). Conversion runs through native platform media APIs.
  Future<String> exportWav(List<String> rawPaths) async {
    if (rawPaths.isEmpty) {
      throw ArgumentError('Keine Audios zum Exportieren.');
    }
    final files = await Future.wait(
      rawPaths.map(_normalizedForPlayback),
      eagerError: true,
    );
    final cache = await _cacheDirectory;
    final working = Directory(
      '${cache.path}${Platform.pathSeparator}wav-export-${DateTime.now().microsecondsSinceEpoch}',
    );
    await working.create(recursive: true);
    try {
      final wavs = <File>[];
      for (var index = 0; index < files.length; index++) {
        final input = files[index];
        final output = File(
          '${working.path}${Platform.pathSeparator}${index.toString().padLeft(4, '0')}.wav',
        );
        await input.copy(output.path);
        wavs.add(output);
      }
      final exports = await _resolveExportDirectory();
      final output = await _nextExportFile(exports);
      await _PcmWavConcatenator.concatenate(wavs, output);
      return output.path;
    } finally {
      if (await working.exists()) {
        await working.delete(recursive: true);
      }
    }
  }

  /// No handles are held between reads. Cached clips deliberately remain in
  /// application support storage to make subsequent announcements immediate.
  Future<void> dispose() async {}

  Future<File> _convertForPlayback(String rawPath) async {
    final input = await materializeForPlayback(rawPath);
    final target = File('${input.path}.pcm.wav');
    if (await target.exists()) return target;
    await target.parent.create(recursive: true);
    final staging = File('${target.path}.part.wav');
    if (await staging.exists()) await staging.delete();
    final converted = await _convertToWav(input.path, staging.path);
    if (converted.isEmpty || !await staging.exists()) {
      throw StateError(
        'Der native Audiodecoder hat keine PCM-WAV-Datei erzeugt.',
      );
    }
    if (await target.exists()) await target.delete();
    await staging.rename(target.path);
    return target;
  }

  Future<File> _materialize(String rawPath) async {
    if (rawPath.startsWith('asset:/')) {
      return _materializeCuratedAsset(rawPath.substring('asset:/'.length));
    }
    return _materializeArchiveClip(rawPath);
  }

  Future<File> _materializeCuratedAsset(String relativePath) async {
    _requireSafeRelativePath(relativePath);
    final cache = await _cacheDirectory;
    final target = _fileUnder(cache, <String>['clips', 'assets', relativePath]);
    if (await target.exists()) return target;
    await target.parent.create(recursive: true);
    final content = await _loadAsset('$assetRoot/$relativePath');
    await _writeAtomically(
      target,
      content.buffer.asUint8List(content.offsetInBytes, content.lengthInBytes),
    );
    return target;
  }

  Future<File> _materializeArchiveClip(String rawPath) async {
    final archiveKey = OfflineArchivePath.toArchiveKey(rawPath);
    if (archiveKey == null) {
      throw ArgumentError.value(
        rawPath,
        'rawPath',
        'Ungültiger oder unsicherer Offline-Audiopfad.',
      );
    }
    final cache = await _cacheDirectory;
    final target = _fileUnder(cache, <String>['clips', archiveKey]);
    if (await target.exists()) return target;
    await target.parent.create(recursive: true);
    final content = await (await _archive).readStoredEntry(archiveKey);
    await _writeAtomically(target, content);
    return target;
  }

  Future<_NativeZipArchive> _openArchive() async =>
      _NativeZipArchive.open(await _archiveFile);

  Future<File> _resolveArchiveFile() async {
    if (_archiveFileOverride != null) return _archiveFileOverride;
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    final candidates = <Directory>[
      Directory(
        _joinPath(executableDirectory.path, const <String>[
          'data',
          'flutter_assets',
        ]),
      ),
      Directory(
        _joinPath(executableDirectory.path, const <String>['flutter_assets']),
      ),
      Directory(
        _joinPath(executableDirectory.path, const <String>[
          '..',
          'data',
          'flutter_assets',
        ]),
      ),
      Directory(
        _joinPath(executableDirectory.path, const <String>[
          '..',
          'Frameworks',
          'App.framework',
          'Resources',
          'flutter_assets',
        ]),
      ),
      Directory(
        _joinPath(executableDirectory.path, const <String>[
          'Frameworks',
          'App.framework',
          'flutter_assets',
        ]),
      ),
    ];
    for (final root in candidates) {
      final candidate = _fileUnder(root, _archiveAsset.split('/'));
      if (await candidate.exists()) return candidate;
    }
    throw StateError(
      'Die Offline-Audiobibliothek wurde neben der Anwendung nicht gefunden. '
      'Erwarteter Flutter-Asset: $_archiveAsset',
    );
  }

  Future<Directory> _resolveCacheDirectory() async {
    final root =
        _cacheDirectoryOverride ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}'
          '${Platform.pathSeparator}offline-audio',
        );
    await root.create(recursive: true);
    return root;
  }

  Future<Directory> _resolveExportDirectory() async {
    final root =
        _exportDirectoryOverride ??
        Directory(
          '${(await getApplicationDocumentsDirectory()).path}'
          '${Platform.pathSeparator}Ansagengenerator',
        );
    await root.create(recursive: true);
    return root;
  }

  Future<File> _nextExportFile(Directory directory) async {
    final now = DateTime.now();
    final timestamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}-'
        '${now.millisecond.toString().padLeft(3, '0')}';
    for (var suffix = 0; ; suffix++) {
      final name = suffix == 0
          ? 'ansage-$timestamp.wav'
          : 'ansage-$timestamp-$suffix.wav';
      final candidate = File('${directory.path}${Platform.pathSeparator}$name');
      if (!await candidate.exists()) return candidate;
    }
  }

  static Future<String> _decodeToPcmWav(String inputPath, String outputPath) =>
      AudioDecoder.convertToWav(
        inputPath,
        outputPath,
        sampleRate: _pcmSampleRate,
        channels: _pcmChannels,
        bitDepth: _pcmBitDepth,
      );

  static File _fileUnder(Directory root, List<String> segments) =>
      File(_joinPath(root.path, segments));

  static String _joinPath(String root, List<String> segments) =>
      <String>[root, ...segments].join(Platform.pathSeparator);
  static Future<void> _writeAtomically(File target, Uint8List bytes) async {
    final temporary = File(
      '${target.path}.part-${DateTime.now().microsecondsSinceEpoch}',
    );
    await temporary.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await temporary.delete();
      return;
    }
    await temporary.rename(target.path);
  }

  static void _requireSafeRelativePath(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/').trim();
    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        normalized
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'Unsicherer Flutter-Asset-Pfad.',
      );
    }
  }
}

class _NativeZipArchive {
  _NativeZipArchive._(this._file, this._length, this._index);

  final File _file;
  final int _length;
  final OfflineZipIndex _index;

  static Future<_NativeZipArchive> open(File file) async {
    final length = await file.length();
    if (length < 22) {
      throw const FormatException(
        'Offline-Audioarchiv ist kein vollständiges ZIP.',
      );
    }
    final reader = _NativeZipReader(file, length);
    final tailLength = length < NativeOfflineAudioLibrary._tailLength
        ? length
        : NativeOfflineAudioLibrary._tailLength;
    final tail = await reader.readAt(length - tailLength, tailLength);
    var location = OfflineZipDirectoryLocator.parseTail(
      tail,
      tailFileOffset: length - tailLength,
      archiveLength: length,
    );
    if (location.zip64EndRecordOffset != null) {
      location = OfflineZipDirectoryLocator.parseZip64EndRecord(
        await reader.readAt(location.zip64EndRecordOffset!, 56),
      );
    }
    final offset = location.centralDirectoryOffset;
    final size = location.centralDirectorySize;
    if (offset == null ||
        size == null ||
        offset < 0 ||
        size <= 0 ||
        offset + size > length) {
      throw const FormatException(
        'Das zentrale Offline-ZIP-Verzeichnis liegt außerhalb des Archivs.',
      );
    }
    return _NativeZipArchive._(
      file,
      length,
      OfflineZipIndex.parseCentralDirectory(await reader.readAt(offset, size)),
    );
  }

  Future<Uint8List> readStoredEntry(String path) async {
    final entry = _index.requireStored(path);
    final reader = _NativeZipReader(_file, _length);
    final fixedHeader = await reader.readAt(entry.localHeaderOffset, 30);
    final fixedData = ByteData.sublistView(fixedHeader);
    final headerLength =
        30 +
        fixedData.getUint16(26, Endian.little) +
        fixedData.getUint16(28, Endian.little);
    final header = await reader.readAt(entry.localHeaderOffset, headerLength);
    final dataOffset = OfflineZipIndex.dataOffsetFromLocalHeader(header, entry);
    return reader.readAt(dataOffset, entry.uncompressedSize);
  }
}

class _NativeZipReader {
  const _NativeZipReader(this._file, this._length);

  final File _file;
  final int _length;

  Future<Uint8List> readAt(int offset, int byteCount) async {
    if (offset < 0 || byteCount < 0 || offset + byteCount > _length) {
      throw const FormatException(
        'ZIP-Lesezugriff liegt außerhalb des Archivs.',
      );
    }
    final handle = await _file.open(mode: FileMode.read);
    try {
      await handle.setPosition(offset);
      return await _readExactly(handle, byteCount);
    } finally {
      await handle.close();
    }
  }

  static Future<Uint8List> _readExactly(
    RandomAccessFile handle,
    int byteCount,
  ) async {
    final chunks = BytesBuilder(copy: false);
    var remaining = byteCount;
    while (remaining > 0) {
      final chunk = await handle.read(remaining);
      if (chunk.isEmpty) {
        throw const FormatException('ZIP-Datei endet vorzeitig.');
      }
      chunks.add(chunk);
      remaining -= chunk.length;
    }
    return chunks.takeBytes();
  }
}

class _PcmWavConcatenator {
  static Future<void> concatenate(List<File> inputs, File output) async {
    if (inputs.isEmpty) {
      throw ArgumentError('Keine WAV-Dateien zum Zusammenfügen.');
    }
    final parts = await Future.wait(inputs.map(_PcmWavPart.read));
    final first = parts.first;
    var totalDataLength = 0;
    for (final part in parts) {
      if (part.sampleRate != first.sampleRate ||
          part.channels != first.channels ||
          part.bitDepth != first.bitDepth) {
        throw const FormatException(
          'Die exportierten Audio-Bausteine haben unterschiedliche PCM-Formate.',
        );
      }
      totalDataLength += part.dataLength;
      if (totalDataLength > 0xffffffff - 36) {
        throw const FormatException(
          'Die exportierte WAV-Datei wäre größer als 4 GB.',
        );
      }
    }
    await output.parent.create(recursive: true);
    final temporary = File('${output.path}.part');
    final writer = await temporary.open(mode: FileMode.write);
    try {
      await writer.writeFrom(
        _wavHeader(
          dataLength: totalDataLength,
          sampleRate: first.sampleRate,
          channels: first.channels,
          bitDepth: first.bitDepth,
        ),
      );
      for (final part in parts) {
        final reader = await part.file.open(mode: FileMode.read);
        try {
          await reader.setPosition(part.dataOffset);
          var remaining = part.dataLength;
          while (remaining > 0) {
            final bytes = await reader.read(
              remaining > 65536 ? 65536 : remaining,
            );
            if (bytes.isEmpty) {
              throw const FormatException('WAV-Datei endet vorzeitig.');
            }
            await writer.writeFrom(bytes);
            remaining -= bytes.length;
          }
        } finally {
          await reader.close();
        }
      }
    } finally {
      await writer.close();
    }
    if (await output.exists()) await output.delete();
    await temporary.rename(output.path);
  }

  static Uint8List _wavHeader({
    required int dataLength,
    required int sampleRate,
    required int channels,
    required int bitDepth,
  }) {
    final bytes = ByteData(44)
      ..setUint32(0, 0x46464952, Endian.little)
      ..setUint32(4, 36 + dataLength, Endian.little)
      ..setUint32(8, 0x45564157, Endian.little)
      ..setUint32(12, 0x20746d66, Endian.little)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, channels, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, sampleRate * channels * (bitDepth ~/ 8), Endian.little)
      ..setUint16(32, channels * (bitDepth ~/ 8), Endian.little)
      ..setUint16(34, bitDepth, Endian.little)
      ..setUint32(36, 0x61746164, Endian.little)
      ..setUint32(40, dataLength, Endian.little);
    return bytes.buffer.asUint8List();
  }
}

class _PcmWavPart {
  const _PcmWavPart({
    required this.file,
    required this.dataOffset,
    required this.dataLength,
    required this.sampleRate,
    required this.channels,
    required this.bitDepth,
  });

  final File file;
  final int dataOffset;
  final int dataLength;
  final int sampleRate;
  final int channels;
  final int bitDepth;

  static Future<_PcmWavPart> read(File file) async {
    final length = await file.length();
    final handle = await file.open(mode: FileMode.read);
    try {
      final riff = await _NativeZipReader._readExactly(handle, 12);
      if (_ascii(riff, 0, 4) != 'RIFF' || _ascii(riff, 8, 4) != 'WAVE') {
        throw FormatException('Kein RIFF/WAV-PCM-Export: ${file.path}');
      }
      int? sampleRate;
      int? channels;
      int? bitDepth;
      int? dataOffset;
      int? dataLength;
      var offset = 12;
      while (offset + 8 <= length &&
          (dataOffset == null || sampleRate == null)) {
        await handle.setPosition(offset);
        final chunkHeader = await _NativeZipReader._readExactly(handle, 8);
        final chunkSize = ByteData.sublistView(
          chunkHeader,
        ).getUint32(4, Endian.little);
        final chunkOffset = offset + 8;
        final nextOffset = chunkOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
        if (nextOffset > length) {
          throw FormatException('Ungültiger WAV-Chunk in ${file.path}');
        }
        final type = _ascii(chunkHeader, 0, 4);
        if (type == 'fmt ') {
          if (chunkSize < 16) {
            throw FormatException(
              'Unvollständiger WAV-Format-Chunk in ${file.path}',
            );
          }
          await handle.setPosition(chunkOffset);
          final format = ByteData.sublistView(
            await _NativeZipReader._readExactly(handle, 16),
          );
          if (format.getUint16(0, Endian.little) != 1) {
            throw FormatException('WAV-Export ist nicht PCM: ${file.path}');
          }
          channels = format.getUint16(2, Endian.little);
          sampleRate = format.getUint32(4, Endian.little);
          bitDepth = format.getUint16(14, Endian.little);
          if (channels <= 0 ||
              sampleRate <= 0 ||
              bitDepth <= 0 ||
              bitDepth % 8 != 0) {
            throw FormatException('Ungültiges PCM-Format in ${file.path}');
          }
        } else if (type == 'data') {
          dataOffset = chunkOffset;
          dataLength = chunkSize;
        }
        offset = nextOffset;
      }
      if (sampleRate == null ||
          channels == null ||
          bitDepth == null ||
          dataOffset == null ||
          dataLength == null) {
        throw FormatException(
          'WAV-Export enthält kein vollständiges PCM-Audio: ${file.path}',
        );
      }
      return _PcmWavPart(
        file: file,
        dataOffset: dataOffset,
        dataLength: dataLength,
        sampleRate: sampleRate,
        channels: channels,
        bitDepth: bitDepth,
      );
    } finally {
      await handle.close();
    }
  }

  static String _ascii(Uint8List bytes, int start, int length) =>
      String.fromCharCodes(bytes.sublist(start, start + length));
}
