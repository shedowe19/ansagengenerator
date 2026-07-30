import 'package:audioplayers/audioplayers.dart';

/// Native targets use their platform bridge instead. This declaration keeps
/// the shared controller free from web-only imports.
class WebOfflineAudioLibrary {
  WebOfflineAudioLibrary({String? archiveUrl});

  Future<Source> sourceForLogicalPath(String rawPath) => Future<Source>.error(
    UnsupportedError(
      'Der Browser-Audioadapter ist auf diesem Ziel nicht verfügbar.',
    ),
  );

  Future<String> exportWav(List<String> rawPaths) => Future<String>.error(
    UnsupportedError(
      'Der Browser-WAV-Export ist auf diesem Ziel nicht verfügbar.',
    ),
  );

  void dispose() {}
}
