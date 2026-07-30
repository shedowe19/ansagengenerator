import 'package:ansagengenerator/data/announcement_audio_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Nächster Halt continues the active queue instead of rebuilding it', () {
    expect(PlaybackState.waitingForNextStop.continuesQueuedPlayback, isTrue);
  });

  test('ordinary playback states start a newly configured announcement', () {
    expect(PlaybackState.idle.continuesQueuedPlayback, isFalse);
    expect(PlaybackState.finished.continuesQueuedPlayback, isFalse);
    expect(PlaybackState.failed.continuesQueuedPlayback, isFalse);
  });
}
