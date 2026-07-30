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
          'asset:/inzug/text/fahrgaeste_bitte_alle_aussteigen.opus',
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
