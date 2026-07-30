import 'dart:convert';
import 'dart:typed_data';

int _readUint64(ByteData data, int offset) {
  final low = data.getUint32(offset, Endian.little);
  final high = data.getUint32(offset + 4, Endian.little);
  // JavaScript numbers are exact through 2^53 - 1. This archive is far below
  // that limit, but rejecting larger ZIP64 values prevents silent corruption.
  if (high > 0x1fffff) {
    throw const FormatException(
      'ZIP64-Zahl überschreitet die sichere Webgrenze.',
    );
  }
  return high * 0x100000000 + low;
}

/// Conversion and validation shared by every platform-specific archive reader.
abstract final class OfflineArchivePath {
  static const virtualRoot = 'site/';

  /// The playlist compiler emits logical WAV paths while the immutable archive
  /// stores the matching Ogg/Opus file beneath its virtual `site/` root.
  static String? toArchiveKey(String rawPath) {
    final path = rawPath.replaceAll('\\', '/').trim();
    if (path.isEmpty ||
        path.startsWith('/') ||
        path
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..') ||
        !path.toLowerCase().endsWith('.wav')) {
      return null;
    }
    return '$virtualRoot${path.substring(0, path.length - 4)}.opus';
  }
}

class OfflineZipEntry {
  const OfflineZipEntry({
    required this.path,
    required this.compressionMethod,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
  });

  final String path;
  final int compressionMethod;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
}

/// Parser for the central-directory and local-header parts that are required
/// to seek individual stored clips from the immutable ZIP64 data pack.
class OfflineZipIndex {
  OfflineZipIndex._(this._entries);

  static const _centralDirectorySignature = 0x02014b50;
  static const _localFileSignature = 0x04034b50;
  static const _stored = 0;

  final Map<String, OfflineZipEntry> _entries;

  int get entryCount => _entries.length;

  static OfflineZipIndex parseCentralDirectory(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final entries = <String, OfflineZipEntry>{};
    var offset = 0;
    while (offset < bytes.length) {
      _requireRemaining(bytes.length, offset, 46, 'zentrales ZIP-Verzeichnis');
      if (data.getUint32(offset, Endian.little) != _centralDirectorySignature) {
        throw const FormatException(
          'Ungültige Signatur im zentralen ZIP-Verzeichnis.',
        );
      }
      final nameLength = data.getUint16(offset + 28, Endian.little);
      final extraLength = data.getUint16(offset + 30, Endian.little);
      final commentLength = data.getUint16(offset + 32, Endian.little);
      final next = offset + 46 + nameLength + extraLength + commentLength;
      _requireRemaining(
        bytes.length,
        offset,
        next - offset,
        'ZIP-Verzeichniseintrag',
      );
      final path = utf8.decode(
        bytes.sublist(offset + 46, offset + 46 + nameLength),
        allowMalformed: false,
      );
      _requireArchivePath(path);
      final sizes = _readZip64Values(
        data,
        bytes,
        offset: offset,
        nameLength: nameLength,
        extraLength: extraLength,
        compressedSize: data.getUint32(offset + 20, Endian.little),
        uncompressedSize: data.getUint32(offset + 24, Endian.little),
        localHeaderOffset: data.getUint32(offset + 42, Endian.little),
      );
      if (entries.containsKey(path)) {
        throw FormatException('Doppelter ZIP-Eintrag: $path');
      }
      entries[path] = OfflineZipEntry(
        path: path,
        compressionMethod: data.getUint16(offset + 10, Endian.little),
        compressedSize: sizes.compressedSize,
        uncompressedSize: sizes.uncompressedSize,
        localHeaderOffset: sizes.localHeaderOffset,
      );
      offset = next;
    }
    if (entries.isEmpty) {
      throw const FormatException('Das zentrale ZIP-Verzeichnis ist leer.');
    }
    return OfflineZipIndex._(Map.unmodifiable(entries));
  }

  OfflineZipEntry requireStored(String path) {
    final entry = _entries[path];
    if (entry == null) {
      throw StateError('Audio-Datei fehlt in der Offline-Bibliothek: $path');
    }
    if (entry.compressionMethod != _stored ||
        entry.compressedSize != entry.uncompressedSize ||
        entry.compressedSize <= 0) {
      throw FormatException(
        'Audio-Datei ist nicht als sicherer ZIP_STORED-Clip vorhanden: $path',
      );
    }
    return entry;
  }

  static int dataOffsetFromLocalHeader(
    Uint8List header,
    OfflineZipEntry entry,
  ) {
    _requireRemaining(header.length, 0, 30, 'lokaler ZIP-Header');
    final data = ByteData.sublistView(header);
    if (data.getUint32(0, Endian.little) != _localFileSignature) {
      throw const FormatException('Ungültige Signatur im lokalen ZIP-Header.');
    }
    if (data.getUint16(8, Endian.little) != entry.compressionMethod) {
      throw FormatException(
        'Kompressionsmethode stimmt nicht für ${entry.path}.',
      );
    }
    final nameLength = data.getUint16(26, Endian.little);
    final extraLength = data.getUint16(28, Endian.little);
    _requireRemaining(
      header.length,
      0,
      30 + nameLength + extraLength,
      'lokaler ZIP-Dateiname',
    );
    final name = utf8.decode(
      header.sublist(30, 30 + nameLength),
      allowMalformed: false,
    );
    if (name != entry.path) {
      throw FormatException(
        'Lokaler ZIP-Header gehört nicht zu ${entry.path}.',
      );
    }
    return entry.localHeaderOffset + 30 + nameLength + extraLength;
  }

  static _Zip64Values _readZip64Values(
    ByteData data,
    Uint8List bytes, {
    required int offset,
    required int nameLength,
    required int extraLength,
    required int compressedSize,
    required int uncompressedSize,
    required int localHeaderOffset,
  }) {
    var compressed = compressedSize;
    var uncompressed = uncompressedSize;
    var localOffset = localHeaderOffset;
    if (compressed != 0xffffffff &&
        uncompressed != 0xffffffff &&
        localOffset != 0xffffffff) {
      return _Zip64Values(compressed, uncompressed, localOffset);
    }
    final extraStart = offset + 46 + nameLength;
    final extraEnd = extraStart + extraLength;
    var cursor = extraStart;
    while (cursor < extraEnd) {
      _requireRemaining(extraEnd, cursor, 4, 'ZIP64-Extrafelddaten');
      final id = data.getUint16(cursor, Endian.little);
      final length = data.getUint16(cursor + 2, Endian.little);
      final valueStart = cursor + 4;
      final valueEnd = valueStart + length;
      _requireRemaining(extraEnd, valueStart, length, 'ZIP64-Extrafelddaten');
      if (id == 0x0001) {
        var valueOffset = valueStart;
        if (uncompressed == 0xffffffff) {
          _requireRemaining(valueEnd, valueOffset, 8, 'ZIP64-Originalgröße');
          uncompressed = _readUint64(data, valueOffset);
          valueOffset += 8;
        }
        if (compressed == 0xffffffff) {
          _requireRemaining(
            valueEnd,
            valueOffset,
            8,
            'ZIP64-komprimierte Größe',
          );
          compressed = _readUint64(data, valueOffset);
          valueOffset += 8;
        }
        if (localOffset == 0xffffffff) {
          _requireRemaining(valueEnd, valueOffset, 8, 'ZIP64-lokaler Offset');
          localOffset = _readUint64(data, valueOffset);
        }
        break;
      }
      cursor = valueEnd;
    }
    if (compressed == 0xffffffff ||
        uncompressed == 0xffffffff ||
        localOffset == 0xffffffff) {
      throw const FormatException(
        'Unvollständige ZIP64-Daten im zentralen Verzeichnis.',
      );
    }
    return _Zip64Values(compressed, uncompressed, localOffset);
  }

  static void _requireArchivePath(String path) {
    if (!path.startsWith(OfflineArchivePath.virtualRoot) ||
        !path.toLowerCase().endsWith('.opus') ||
        path
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw FormatException('Unsicherer ZIP-Pfad: $path');
    }
  }

  static void _requireRemaining(
    int length,
    int offset,
    int amount,
    String what,
  ) {
    if (offset < 0 || amount < 0 || offset + amount > length) {
      throw FormatException('Unvollständige Daten für $what.');
    }
  }
}

class _Zip64Values {
  const _Zip64Values(
    this.compressedSize,
    this.uncompressedSize,
    this.localHeaderOffset,
  );

  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
}

class OfflineZipDirectoryLocation {
  const OfflineZipDirectoryLocation._standard({
    required this.centralDirectoryOffset,
    required this.centralDirectorySize,
    required this.entryCount,
  }) : zip64EndRecordOffset = null;

  const OfflineZipDirectoryLocation._zip64({required this.zip64EndRecordOffset})
    : centralDirectoryOffset = null,
      centralDirectorySize = null,
      entryCount = null;

  final int? centralDirectoryOffset;
  final int? centralDirectorySize;
  final int? entryCount;
  final int? zip64EndRecordOffset;
}

/// Locates the central directory from the fixed-size tail of a ZIP/ZIP64 file.
abstract final class OfflineZipDirectoryLocator {
  static const _endSignature = 0x06054b50;
  static const _zip64LocatorSignature = 0x07064b50;
  static const _zip64EndSignature = 0x06064b50;
  static const _zip64Marker = 0xffffffff;

  static OfflineZipDirectoryLocation parseTail(
    Uint8List tail, {
    required int tailFileOffset,
    required int archiveLength,
  }) {
    if (tailFileOffset < 0 || tailFileOffset + tail.length != archiveLength) {
      throw const FormatException(
        'ZIP-Endbereich passt nicht zur Archivgröße.',
      );
    }
    final data = ByteData.sublistView(tail);
    for (var offset = tail.length - 22; offset >= 0; offset--) {
      if (data.getUint32(offset, Endian.little) != _endSignature) continue;
      final commentLength = data.getUint16(offset + 20, Endian.little);
      if (offset + 22 + commentLength != tail.length) continue;
      final entryCount = data.getUint16(offset + 10, Endian.little);
      final directorySize = data.getUint32(offset + 12, Endian.little);
      final directoryOffset = data.getUint32(offset + 16, Endian.little);
      if (entryCount != 0xffff &&
          directorySize != _zip64Marker &&
          directoryOffset != _zip64Marker) {
        _validateDirectoryBounds(directoryOffset, directorySize, archiveLength);
        return OfflineZipDirectoryLocation._standard(
          centralDirectoryOffset: directoryOffset,
          centralDirectorySize: directorySize,
          entryCount: entryCount,
        );
      }
      final locatorOffset = offset - 20;
      if (locatorOffset < 0 ||
          data.getUint32(locatorOffset, Endian.little) !=
              _zip64LocatorSignature) {
        throw const FormatException(
          'ZIP64-Endlocator fehlt oder ist ungültig.',
        );
      }
      final zip64Offset = _readUint64(data, locatorOffset + 8);
      if (zip64Offset < 0 || zip64Offset >= archiveLength) {
        throw const FormatException(
          'ZIP64-Endrecord liegt außerhalb der Archivdatei.',
        );
      }
      return OfflineZipDirectoryLocation._zip64(
        zip64EndRecordOffset: zip64Offset,
      );
    }
    throw const FormatException('ZIP-Endrecord wurde nicht gefunden.');
  }

  static OfflineZipDirectoryLocation parseZip64EndRecord(Uint8List bytes) {
    if (bytes.length < 56) {
      throw const FormatException('ZIP64-Endrecord ist unvollständig.');
    }
    final data = ByteData.sublistView(bytes);
    if (data.getUint32(0, Endian.little) != _zip64EndSignature ||
        _readUint64(data, 4) < 44) {
      throw const FormatException('ZIP64-Endrecord ist ungültig.');
    }
    return OfflineZipDirectoryLocation._standard(
      centralDirectoryOffset: _readUint64(data, 48),
      centralDirectorySize: _readUint64(data, 40),
      entryCount: _readUint64(data, 32),
    );
  }

  static void _validateDirectoryBounds(
    int offset,
    int size,
    int archiveLength,
  ) {
    if (offset < 0 || size <= 0 || offset + size > archiveLength) {
      throw const FormatException(
        'Zentrales ZIP-Verzeichnis liegt außerhalb der Archivdatei.',
      );
    }
  }
}
