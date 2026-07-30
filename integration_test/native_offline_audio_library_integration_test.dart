import 'dart:io';
import 'dart:typed_data';

import 'package:ansagengenerator/data/native_offline_audio_library.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('normalizes a real embedded Opus clip and exports PCM WAV', (
    tester,
  ) async {
    final library = NativeOfflineAudioLibrary();
    String? exported;
    addTearDown(() async {
      await library.dispose();
      if (exported != null) {
        final output = File(exported);
        if (await output.exists()) await output.delete();
      }
    });

    final source = await library.sourceForLogicalPath(
      'dt/gleise_zahlen/hoch/1.wav',
    );
    expect(source, isA<DeviceFileSource>());
    final playbackFile = File((source as DeviceFileSource).path);
    _expectPcmWav(await playbackFile.readAsBytes());

    exported = await library.exportWav(<String>['dt/gleise_zahlen/hoch/1.wav']);
    final bytes = await File(exported).readAsBytes();
    _expectPcmWav(bytes);
  });
}

void _expectPcmWav(Uint8List bytes) {
  expect(bytes.length, greaterThan(44));
  expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
  final header = ByteData.sublistView(bytes);
  expect(header.getUint16(20, Endian.little), 1);
  expect(header.getUint16(22, Endian.little), 1);
  expect(header.getUint32(24, Endian.little), 48000);
  expect(header.getUint16(34, Endian.little), 16);
}
