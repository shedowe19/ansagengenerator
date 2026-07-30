import 'package:audioplayers/audioplayers.dart';

/// Browser-only functionality is supplied by a conditional implementation.
/// Native targets retain their existing Android MethodChannel resolver.
export 'web_offline_audio_library_stub.dart'
    if (dart.library.html) 'web_offline_audio_library_web.dart';

abstract class WebOfflineAudioLibraryContract {
  Future<Source> sourceForLogicalPath(String rawPath);

  Future<String> exportWav(List<String> rawPaths);

  void dispose();
}
