import 'package:ansagengenerator/core/in_train_sequence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps self-contained station items, sequence order and duplicates', () {
    final hbf = InTrainSequence.stationItem('station_name_hagen_hbf.opus');
    final playlist = InTrainSequence.toAssetPlaylist([
      'gong',
      hbf,
      'next_station',
      hbf,
      'db_regio_farewell',
    ], selectedStationClip: '');

    expect(playlist, [
      'asset:/inzug/text/gong_start.opus',
      'asset:/inzug/station_name_only/station_name_hagen_hbf.opus',
      'asset:/inzug/text/naechste_station.opus',
      'asset:/inzug/station_name_only/station_name_hagen_hbf.opus',
      'asset:/inzug/text/hinweis_db_regio_verabschiedung.opus',
    ]);
    expect(InTrainSequence.requiresStation(['gong', hbf]), isFalse);
    expect(
      InTrainSequence.shouldPauseAfterQueueEntry(true, playlist[1]),
      isTrue,
    );
  });

  test(
    'pauses before a following gong so the next station starts explicitly',
    () {
      expect(
        InTrainSequence.shouldPauseBeforeQueueEntry(
          true,
          'asset:/inzug/text/gong_start.opus',
        ),
        isTrue,
      );
      expect(
        InTrainSequence.shouldPauseBeforeQueueEntry(
          true,
          'asset:/inzug/text/zug_endet_fahrgaeste_aussteigen.opus',
        ),
        isFalse,
      );
      expect(
        InTrainSequence.shouldPauseBeforeQueueEntry(
          false,
          'asset:/inzug/text/gong_start.opus',
        ),
        isFalse,
      );
    },
  );

  test('replaces split legacy end-stop blocks with one supplied clip', () {
    expect(
      InTrainSequence.idForLabel(
        'Dieser Zug endet dort · Fahrgäste bitte aussteigen',
      ),
      'train_ends_all_exit',
    );
    expect(
      InTrainSequence.migrateLegacySequence(['gong', 'train_ends', 'all_exit']),
      ['gong', 'train_ends_all_exit'],
    );
    expect(
      InTrainSequence.toAssetPlaylist([
        'train_ends',
        'all_exit',
      ], selectedStationClip: ''),
      ['asset:/inzug/text/zug_endet_fahrgaeste_aussteigen.opus'],
    );
  });

  test('adds the construction-work notice as an independent Im-Zug block', () {
    expect(
      InTrainSequence.idForLabel(
        'Hinweis · Bauarbeiten und Fahrplanänderungen',
      ),
      'construction_work_notice',
    );
    expect(
      InTrainSequence.labelForId('construction_work_notice'),
      'Hinweis · Bauarbeiten und Fahrplanänderungen',
    );
    expect(
      InTrainSequence.requiresStation(['construction_work_notice']),
      isFalse,
    );
    expect(
      InTrainSequence.toAssetPlaylist([
        'construction_work_notice',
      ], selectedStationClip: ''),
      ['asset:/inzug/text/hinweis_bauarbeiten_fahrplanaenderungen.opus'],
    );
  });

  test(
    'adds all supplied operational notices as independent Im-Zug blocks',
    () {
      expect(
        InTrainSequence.idForLabel('Hinweis · Trittstufen fahren nicht aus'),
        'step_extension_unavailable',
      );
      expect(
        InTrainSequence.labelForId('step_extension_unavailable'),
        'Hinweis · Trittstufen fahren nicht aus',
      );
      expect(
        InTrainSequence.idForLabel(
          'Hinweis · Verspätung wegen Signalreparatur',
        ),
        'signal_repair_delay_notice',
      );
      expect(
        InTrainSequence.labelForId('signal_repair_delay_notice'),
        'Hinweis · Verspätung wegen Signalreparatur',
      );
      expect(
        InTrainSequence.idForLabel('Hinweis · Türbereich freihalten'),
        'door_area_clear_notice',
      );
      expect(
        InTrainSequence.labelForId('door_area_clear_notice'),
        'Hinweis · Türbereich freihalten',
      );
      expect(
        InTrainSequence.idForLabel('Hinweis · Außerplanmäßiger Halt'),
        'unscheduled_stop_notice',
      );
      expect(
        InTrainSequence.labelForId('unscheduled_stop_notice'),
        'Hinweis · Außerplanmäßiger Halt',
      );
      expect(
        InTrainSequence.idForLabel('Hinweis · Abstand zur Bahnsteigkante'),
        'platform_edge_gap_notice',
      );
      expect(
        InTrainSequence.labelForId('platform_edge_gap_notice'),
        'Hinweis · Abstand zur Bahnsteigkante',
      );
      expect(
        InTrainSequence.idForLabel('Hinweis · Weiterfahrt in die Abstellung'),
        'stabling_exit_notice',
      );
      expect(
        InTrainSequence.labelForId('stabling_exit_notice'),
        'Hinweis · Weiterfahrt in die Abstellung',
      );
      expect(
        InTrainSequence.idForLabel(
          'Hinweis · Corona · Abstand und medizinische Maske',
        ),
        'corona_mask_notice',
      );
      expect(
        InTrainSequence.labelForId('corona_mask_notice'),
        'Hinweis · Corona · Abstand und medizinische Maske',
      );
      const notices = <String>[
        'step_extension_unavailable',
        'signal_repair_delay_notice',
        'door_area_clear_notice',
        'unscheduled_stop_notice',
        'platform_edge_gap_notice',
        'stabling_exit_notice',
        'corona_mask_notice',
      ];
      expect(InTrainSequence.requiresStation(notices), isFalse);
      expect(
        InTrainSequence.toAssetPlaylist(notices, selectedStationClip: ''),
        [
          'asset:/inzug/text/hinweis_trittstufen_fahren_nicht_aus.opus',
          'asset:/inzug/text/hinweis_signalreparatur_verzoegerung.opus',
          'asset:/inzug/text/hinweis_tuerbereich_freihalten.opus',
          'asset:/inzug/text/hinweis_ausserplanmaessiger_halt.opus',
          'asset:/inzug/text/hinweis_abstand_zur_bahnsteigkante.opus',
          'asset:/inzug/text/hinweis_weiterfahrt_in_die_abstellung.opus',
          'asset:/inzug/text/hinweis_corona_abstand_medizinische_maske.opus',
        ],
      );
    },
  );

  test('migrates the superseded platform-gap block to its replacement', () {
    expect(InTrainSequence.migrateLegacySequence(['platform_gap']), [
      'platform_edge_gap_notice',
    ]);
    expect(
      InTrainSequence.labelForId('platform_gap'),
      'Hinweis · Abstand zur Bahnsteigkante',
    );
    expect(
      InTrainSequence.toAssetPlaylist([
        'platform_gap',
      ], selectedStationClip: ''),
      ['asset:/inzug/text/hinweis_abstand_zur_bahnsteigkante.opus'],
    );
  });

  test('migrates legacy station WAV tokens to safe Opus paths', () {
    expect(
      InTrainSequence.stationClipForItem('station:station_name_hagen_hbf.wav'),
      'station_name_hagen_hbf.opus',
    );
    expect(
      () => InTrainSequence.stationItem('../outside.wav'),
      throwsArgumentError,
    );
  });

  test(
    'requires a selected station only for the legacy global station item',
    () {
      expect(InTrainSequence.requiresStation(['gong', 'station_name']), isTrue);
      expect(
        () => InTrainSequence.toAssetPlaylist([
          'station_name',
        ], selectedStationClip: ''),
        throwsArgumentError,
      );
    },
  );
}
