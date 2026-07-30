import 'package:ansagengenerator/data/announcement_audio_controller.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads curated Im-Zug assets from their declared Flutter path',
    () async {
      AnnouncementAudioController.configureCuratedAssetCache();

      final data = await AudioCache.instance.loadAsset(
        'source-android/app/src/main/assets/inzug/text/gong_start.opus',
      );

      expect(data.lengthInBytes, greaterThan(0));
    },
  );
}
