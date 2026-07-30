import 'dart:io';

import 'package:ansagengenerator/data/native_offline_audio_library.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens a real embedded Opus clip and exports a valid PCM WAV', (
    tester,
  ) async {
    final library = NativeOfflineAudioLibrary();
    final player = AudioPlayer();
    String? exported;
    addTearDown(() async {
      await player.dispose();
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

    // Exercises the platform playback backend without requiring audio output.
    await player.setSource(source);
    await player.stop();

    exported = await library.exportWav(<String>['dt/gleise_zahlen/hoch/1.wav']);
    final bytes = await File(exported).readAsBytes();
    expect(bytes.length, greaterThan(44));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
  });
}
