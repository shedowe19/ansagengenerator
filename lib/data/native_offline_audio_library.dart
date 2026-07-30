// Native implementation for Android, Windows, Linux, macOS, and iOS.
//
// Browser builds use the stub because their archive reader performs HTTP range
// requests instead of accessing bundled files directly.
export 'native_offline_audio_library_stub.dart'
    if (dart.library.io) 'native_offline_audio_library_io.dart';
