import 'package:audioplayers/audioplayers.dart';

// Native targets receive the local ZIP64 reader through a conditional import.
// Browser builds never instantiate this implementation.
class NativeOfflineAudioLibrary {
  NativeOfflineAudioLibrary({
    Object? archiveFile,
    Object? cacheDirectory,
    Object? exportDirectory,
    Object? convertToWav,
    Object? loadAsset,
  });

  Future<Source> sourceForLogicalPath(String rawPath) => Future<Source>.error(
    UnsupportedError('Native offline audio is not available in the browser.'),
  );

  Future<Object> materializeForPlayback(String rawPath) => Future<Object>.error(
    UnsupportedError('Native offline audio is not available in the browser.'),
  );

  Future<String> exportWav(List<String> rawPaths) => Future<String>.error(
    UnsupportedError('Native WAV export is not available in the browser.'),
  );

  Future<void> dispose() async {}
}
