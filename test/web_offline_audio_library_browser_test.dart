@TestOn('browser')
library;

import 'package:ansagengenerator/data/web_offline_audio_library.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';

const _archiveUrl = String.fromEnvironment('OFFLINE_ARCHIVE_URL');

void main() {
  if (_archiveUrl.isEmpty) {
    fail(
      'Set OFFLINE_ARCHIVE_URL to a range-enabled web archive URL. '
      'Use tool/test_web_offline_audio.sh for the local check.',
    );
  }

  test('streams a normal offline clip as a browser Blob URL', () async {
    final library = WebOfflineAudioLibrary(archiveUrl: _archiveUrl);
    addTearDown(library.dispose);

    final source = await library.sourceForLogicalPath(
      'dt/ziele/variante1/hoch/8010205.wav',
    );

    expect(source, isA<UrlSource>());
    expect((source as UrlSource).url, startsWith('blob:'));
  });

  test('decodes a normal offline clip and starts a WAV download', () async {
    final library = WebOfflineAudioLibrary(archiveUrl: _archiveUrl);
    addTearDown(library.dispose);

    final result = await library.exportWav(<String>[
      'dt/ziele/variante1/hoch/8010205.wav',
    ]);

    expect(result, startsWith('Download gestartet: ansage-'));
    expect(result, endsWith('.wav'));
  });
}
