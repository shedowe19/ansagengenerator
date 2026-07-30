# Third-party notices

This distribution includes native FFmpeg functionality through
[`ffmpeg_kit_flutter_new_audio` 2.5.2](https://pub.dev/packages/ffmpeg_kit_flutter_new_audio).
It is used only to decode local offline audio clips to PCM WAV for playback and
WAV export.

- **FFmpegKit Audio / FFmpeg runtime:** LGPL-3.0
- **FFmpeg:** LGPL-2.1-or-later by default; see the upstream project for its
  complete license and source information.
- **Enabled audio component:** libopus (BSD-3-Clause).

Sources and license texts:

- https://github.com/sk3llo/ffmpeg_kit_flutter
- https://github.com/FFmpeg/FFmpeg
- https://opus-codec.org/license/

The GitHub build resolves the exact Dart package archive through `pubspec.lock`.
For the Windows and Linux distributions, the workflow downloads their
release-bound FFmpegKit Audio runtimes, verifies the pinned SHA-256 before
extraction, and passes those verified bundles to the Flutter build:

- Windows ZIP: `dcd9eabb067a3ef34ae8e7c1d01bf06592714978496e3b03c9015d2dc21ea94d`
- Linux TAR.GZ: `6b01c49cf90d19193317cba84752f2b76150fa4c49b387dbd7f2f237c57b3cfb`

Apple targets use the release-bound native bundles selected by the plugin's platform
build configuration. The package selected here is the non-GPL `audio` variant;
it does not include the GPL-only codecs.
