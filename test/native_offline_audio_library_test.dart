import 'dart:io';
import 'dart:typed_data';

import 'package:ansagengenerator/data/native_offline_audio_library.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NativeOfflineAudioLibrary', () {
    late Directory temporary;

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp(
        'ansagengenerator-native-audio-test-',
      );
    });

    tearDown(() async {
      if (await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    });

    test(
      'materializes one ZIP_STORED Opus clip from the local offline archive',
      () async {
        final archive = File('${temporary.path}/offline.zip');
        const opus = <int>[79, 103, 103, 83, 1, 2, 3, 4];
        await archive.writeAsBytes(
          _storedZip(path: 'site/dt/test.opus', payload: opus),
        );
        final cache = Directory('${temporary.path}/cache');
        var conversions = 0;
        final library = NativeOfflineAudioLibrary(
          archiveFile: archive,
          cacheDirectory: cache,
          convertToWav: (inputPath, outputPath) async {
            conversions++;
            await File(outputPath).writeAsBytes(_pcmWav(const <int>[1, 2]));
            return outputPath;
          },
        );
        addTearDown(library.dispose);

        final source = await library.sourceForLogicalPath('dt/test.wav');
        final cachedSource = await library.sourceForLogicalPath('dt/test.wav');

        expect(source, isA<DeviceFileSource>());
        expect(cachedSource, isA<DeviceFileSource>());
        expect(conversions, 1);
        final extracted = File('${cache.path}/clips/site/dt/test.opus');
        expect(await extracted.readAsBytes(), opus);
      },
    );

    test(
      'reads a real ZIP64 release clip without loading the archive',
      () async {
        final archive = File(
          'source-android/app/src/main/assets/offline/'
          'ansagengenerator-offline-opus-data.zip',
        );
        expect(await archive.exists(), isTrue);
        final library = NativeOfflineAudioLibrary(
          archiveFile: archive,
          cacheDirectory: Directory('${temporary.path}/cache'),
        );
        addTearDown(library.dispose);

        await library.materializeForPlayback('dt/gleise_zahlen/hoch/1.wav');

        final extracted = File(
          '${temporary.path}/cache/clips/site/dt/gleise_zahlen/hoch/1.opus',
        );
        final bytes = await extracted.readAsBytes();
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'OggS');
      },
    );

    test('rejects an unsafe logical path before archive access', () async {
      final library = NativeOfflineAudioLibrary(
        archiveFile: File('${temporary.path}/missing.zip'),
        cacheDirectory: Directory('${temporary.path}/cache'),
      );
      addTearDown(library.dispose);

      await expectLater(
        library.sourceForLogicalPath('../outside.wav'),
        throwsArgumentError,
      );
    });

    test(
      'combines normalized decoded fragments into one PCM WAV export',
      () async {
        final archive = File('${temporary.path}/offline.zip');
        await archive.writeAsBytes(
          _storedZip(
            path: 'site/dt/test.opus',
            payload: const <int>[79, 103, 103, 83, 9],
          ),
        );
        var conversion = 0;
        final exportDirectory = Directory('${temporary.path}/exports');
        final library = NativeOfflineAudioLibrary(
          archiveFile: archive,
          cacheDirectory: Directory('${temporary.path}/cache'),
          exportDirectory: exportDirectory,
          convertToWav: (inputPath, outputPath) async {
            conversion++;
            await File(
              outputPath,
            ).writeAsBytes(_pcmWav(<int>[conversion, conversion + 10]));
            return outputPath;
          },
        );
        addTearDown(library.dispose);

        final output = await library.exportWav(<String>[
          'dt/test.wav',
          'dt/test.wav',
        ]);

        expect(conversion, 1);
        final file = File(output);
        expect(file.parent.path, exportDirectory.path);
        expect(_wavPcm(await file.readAsBytes()), <int>[1, 11, 1, 11]);
      },
    );
  });
}

Uint8List _storedZip({required String path, required List<int> payload}) {
  final name = Uint8List.fromList(path.codeUnits);
  final local = ByteData(30 + name.length + payload.length)
    ..setUint32(0, 0x04034b50, Endian.little)
    ..setUint16(4, 20, Endian.little)
    ..setUint16(8, 0, Endian.little)
    ..setUint32(18, payload.length, Endian.little)
    ..setUint32(22, payload.length, Endian.little)
    ..setUint16(26, name.length, Endian.little);
  final localBytes = local.buffer.asUint8List();
  localBytes.setRange(30, 30 + name.length, name);
  localBytes.setRange(30 + name.length, localBytes.length, payload);

  final central = ByteData(46 + name.length)
    ..setUint32(0, 0x02014b50, Endian.little)
    ..setUint16(4, 20, Endian.little)
    ..setUint16(6, 20, Endian.little)
    ..setUint16(10, 0, Endian.little)
    ..setUint32(20, payload.length, Endian.little)
    ..setUint32(24, payload.length, Endian.little)
    ..setUint16(28, name.length, Endian.little)
    ..setUint32(42, 0, Endian.little);
  final centralBytes = central.buffer.asUint8List();
  centralBytes.setRange(46, 46 + name.length, name);

  final eocd = ByteData(22)
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(8, 1, Endian.little)
    ..setUint16(10, 1, Endian.little)
    ..setUint32(12, centralBytes.length, Endian.little)
    ..setUint32(16, localBytes.length, Endian.little);
  return Uint8List.fromList(<int>[
    ...localBytes,
    ...centralBytes,
    ...eocd.buffer.asUint8List(),
  ]);
}

Uint8List _pcmWav(List<int> pcm) {
  final wav = ByteData(44 + pcm.length)
    ..setUint32(0, 0x46464952, Endian.little)
    ..setUint32(4, 36 + pcm.length, Endian.little)
    ..setUint32(8, 0x45564157, Endian.little)
    ..setUint32(12, 0x20746d66, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, 48000, Endian.little)
    ..setUint32(28, 96000, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x61746164, Endian.little)
    ..setUint32(40, pcm.length, Endian.little);
  final bytes = wav.buffer.asUint8List();
  bytes.setRange(44, bytes.length, pcm);
  return bytes;
}

List<int> _wavPcm(List<int> bytes) => bytes.sublist(44);
