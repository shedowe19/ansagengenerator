import 'package:ansagengenerator/core/announcement_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'builds an Einfahrt playlist with deterministic station and number audio',
    () {
      final playlist = AnnouncementBuilder(
        draft: AnnouncementDraft(
          mode: AnnouncementMode.entry,
          language: AnnouncementLanguage.german,
          targetFile: '8010324.wav',
          platform: '2',
          hour: '08',
          minute: '05',
          trainType: 'RE',
          trainNumbers: const ['1035'],
          via: '0',
        ),
      ).build();

      expect(playlist.take(7), [
        'gong/513/513_2.wav',
        'dt/module_3_1/016.wav',
        'dt/gleise_zahlen/hoch/2.wav',
        'dt/module_3_1/012.wav',
        'dt/zuggattungen/hoch/re.wav',
        'dt/gleise_zahlen/hoch/10.wav',
        'dt/gleise_zahlen/hoch/35.wav',
      ]);
      expect(playlist, contains('dt/ziele/variante2/tief/8010324.wav'));
      expect(playlist, contains('dt/zeiten/stunden/hoch/08.wav'));
      expect(playlist, contains('dt/zeiten/minuten/tief/05.wav'));
    },
  );

  test('groups a five-digit train number as two, one, two digits', () {
    final playlist = AnnouncementBuilder(
      draft: const AnnouncementDraft(
        targetFile: '8010324.wav',
        trainType: 'RE',
        trainNumbers: <String>['10354'],
      ),
    ).build();

    expect(playlist.sublist(5, 8), <String>[
      'dt/gleise_zahlen/hoch/10.wav',
      'dt/gleise_zahlen/hoch/3.wav',
      'dt/gleise_zahlen/hoch/54.wav',
    ]);
  });

  test('does not emit optional sentinel values as audio', () {
    final playlist = AnnouncementBuilder(
      draft: AnnouncementDraft(
        mode: AnnouncementMode.information,
        language: AnnouncementLanguage.german,
        targetFile: '8010324.wav',
        platform: '1',
        trainType: 'ICE',
        trainNumbers: const ['0', '9999', '-'],
        via: '9999',
        infoOnlyUntil: '0',
        haltPlus: const ['0', '-', '9999'],
        haltMinus: const ['0', '-', '9999'],
      ),
    ).build();

    expect(playlist.any((path) => path.contains('9999')), isFalse);
  });

  test('uses the manual In-Train sequence unchanged', () {
    final playlist = AnnouncementBuilder(
      draft: AnnouncementDraft(
        mode: AnnouncementMode.inTrain,
        inTrainSequence: const ['gong', 'station:station_name_hagen_hbf.opus'],
      ),
    ).build();

    expect(playlist, [
      'asset:/inzug/text/gong_start.opus',
      'asset:/inzug/station_name_only/station_name_hagen_hbf.opus',
    ]);
  });

  test('matches the original Abfertigung playlist exactly', () {
    final playlist = AnnouncementBuilder(
      draft: const AnnouncementDraft(
        mode: AnnouncementMode.dispatch,
        language: AnnouncementLanguage.german,
        dispatchPlatform: '12',
        targetFile: '8010324.wav',
        trainType: 'ICE',
        trainNumbers: ['12345'],
        via: '9999',
        hour: '23',
        minute: '47',
      ),
    ).build();

    expect(playlist, [
      'gong/klangtyp_konvent/ceg-gongs2.wav',
      'dt/module/0048.wav',
      'dt/gleise_zahlen/hoch/12.wav',
      'dt/module/0011.wav',
    ]);
  });

  test('matches the original Durchfahrt playlist exactly', () {
    final playlist = AnnouncementBuilder(
      draft: const AnnouncementDraft(
        mode: AnnouncementMode.passing,
        language: AnnouncementLanguage.german,
        passingPlatform: '7',
        targetFile: '8010324.wav',
        trainType: 'ICE',
        trainNumbers: ['12345'],
        via: '9999',
        hour: '23',
        minute: '47',
      ),
    ).build();

    expect(playlist, [
      'gong/513/513_2.wav',
      'dt/module/0153.wav',
      'dt/gleise_zahlen/hoch/7.wav',
      'dt/module/0155.wav',
      'dt/gleise_zahlen/hoch/7.wav',
      'dt/module/0159.wav',
    ]);
  });
}
