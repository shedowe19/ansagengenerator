import 'dart:typed_data';

import 'package:ansagengenerator/data/offline_zip_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps a logical WAV playlist path to its guarded archive key', () {
    expect(
      OfflineArchivePath.toArchiveKey('dt/ziele/variante1/hoch/8010205.wav'),
      'site/dt/ziele/variante1/hoch/8010205.opus',
    );
    expect(OfflineArchivePath.toArchiveKey('../outside.wav'), isNull);
    expect(OfflineArchivePath.toArchiveKey('dt/clip.mp3'), isNull);
  });

  test(
    'parses a stored ZIP central-directory entry and computes data range',
    () {
      final directory = _centralDirectoryEntry(
        path: 'site/dt/sample.opus',
        method: 0,
        compressedSize: 7,
        uncompressedSize: 7,
        localHeaderOffset: 123,
      );
      final index = OfflineZipIndex.parseCentralDirectory(directory);
      final entry = index.requireStored('site/dt/sample.opus');

      expect(entry.localHeaderOffset, 123);
      expect(entry.compressedSize, 7);
      expect(
        OfflineZipIndex.dataOffsetFromLocalHeader(
          _localHeader(path: 'site/dt/sample.opus'),
          entry,
        ),
        123 + 30 + 'site/dt/sample.opus'.length,
      );
    },
  );

  test('locates a ZIP64 central directory from the end records', () {
    final tail = _zip64Tail(zip64EndRecordOffset: 983);
    final locator = OfflineZipDirectoryLocator.parseTail(
      tail,
      tailFileOffset: 1_158,
      archiveLength: 1_200,
    );

    expect(locator.zip64EndRecordOffset, 983);
    expect(locator.centralDirectoryOffset, isNull);
    final directory = OfflineZipDirectoryLocator.parseZip64EndRecord(
      _zip64EndRecord(
        centralDirectoryOffset: 400,
        centralDirectorySize: 583,
        entryCount: 87_902,
      ),
    );
    expect(directory.centralDirectoryOffset, 400);
    expect(directory.centralDirectorySize, 583);
    expect(directory.entryCount, 87_902);
  });

  test('rejects compressed or unsafe ZIP entries', () {
    final compressed = OfflineZipIndex.parseCentralDirectory(
      _centralDirectoryEntry(
        path: 'site/dt/compressed.opus',
        method: 8,
        compressedSize: 5,
        uncompressedSize: 7,
        localHeaderOffset: 0,
      ),
    );
    expect(
      () => compressed.requireStored('site/dt/compressed.opus'),
      throwsA(isA<FormatException>()),
    );

    expect(
      () => OfflineZipIndex.parseCentralDirectory(
        _centralDirectoryEntry(
          path: 'site/../outside.opus',
          method: 0,
          compressedSize: 1,
          uncompressedSize: 1,
          localHeaderOffset: 0,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

Uint8List _centralDirectoryEntry({
  required String path,
  required int method,
  required int compressedSize,
  required int uncompressedSize,
  required int localHeaderOffset,
}) {
  final name = Uint8List.fromList(path.codeUnits);
  final out = ByteData(46 + name.length);
  out.setUint32(0, 0x02014b50, Endian.little);
  out.setUint16(4, 20, Endian.little);
  out.setUint16(6, 20, Endian.little);
  out.setUint16(8, 0, Endian.little);
  out.setUint16(10, method, Endian.little);
  out.setUint32(20, compressedSize, Endian.little);
  out.setUint32(24, uncompressedSize, Endian.little);
  out.setUint16(28, name.length, Endian.little);
  out.setUint16(30, 0, Endian.little);
  out.setUint16(32, 0, Endian.little);
  out.setUint32(42, localHeaderOffset, Endian.little);
  Uint8List.view(out.buffer).setRange(46, 46 + name.length, name);
  return out.buffer.asUint8List();
}

Uint8List _zip64Tail({required int zip64EndRecordOffset}) {
  final tail = ByteData(42);
  // ZIP64 locator immediately precedes the standard EOCD record.
  tail.setUint32(0, 0x07064b50, Endian.little);
  tail.setUint64(8, zip64EndRecordOffset, Endian.little);
  tail.setUint32(20, 0x06054b50, Endian.little);
  tail.setUint16(28, 0xffff, Endian.little);
  tail.setUint16(30, 0xffff, Endian.little);
  tail.setUint32(32, 0xffffffff, Endian.little);
  tail.setUint32(36, 0xffffffff, Endian.little);
  return tail.buffer.asUint8List();
}

Uint8List _zip64EndRecord({
  required int centralDirectoryOffset,
  required int centralDirectorySize,
  required int entryCount,
}) {
  final record = ByteData(56);
  record.setUint32(0, 0x06064b50, Endian.little);
  record.setUint64(4, 44, Endian.little);
  record.setUint64(24, entryCount, Endian.little);
  record.setUint64(32, entryCount, Endian.little);
  record.setUint64(40, centralDirectorySize, Endian.little);
  record.setUint64(48, centralDirectoryOffset, Endian.little);
  return record.buffer.asUint8List();
}

Uint8List _localHeader({required String path}) {
  final name = Uint8List.fromList(path.codeUnits);
  final out = ByteData(30 + name.length);
  out.setUint32(0, 0x04034b50, Endian.little);
  out.setUint16(26, name.length, Endian.little);
  out.setUint16(28, 0, Endian.little);
  Uint8List.view(out.buffer).setRange(30, 30 + name.length, name);
  return out.buffer.asUint8List();
}
