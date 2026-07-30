/// Pure mapping for freely ordered, bundled Im-Zug announcement atoms.
abstract final class InTrainSequence {
  static const _stationItemPrefix = 'station:';
  static const _stationAssetPrefix = 'asset:/inzug/station_name_only/';
  static const _gongAssetPath = 'asset:/inzug/text/gong_start.opus';

  static const labels = <String>[
    'Gong',
    'Nächste Station',
    'Dieser Zug endet dort',
    'Fahrgäste bitte alle aussteigen',
    'Ausstieg in Fahrtrichtung links',
    'Ausstieg in Fahrtrichtung rechts',
    'Maskenhinweis FFP2',
    'Maskenhinweis FFP2 Englisch',
    'Hinweis · Persönliche Gegenstände',
    'Hinweis · Vielen Dank und auf Wiedersehen',
    'Hinweis · DB Regio Verabschiedung',
    'Hinweis · Bis zum nächsten Mal · S-Bahn Rhein-Ruhr',
    'Hinweis · Höhenunterschied zur Bahnsteigkante',
  ];

  static String stationItem(String stationClip) {
    final opus = _toBundledStationClip(stationClip);
    if (opus.isEmpty) {
      throw ArgumentError.value(
        stationClip,
        'stationClip',
        'Ungültiger Im-Zug-Stationsclip.',
      );
    }
    return '$_stationItemPrefix$opus';
  }

  static bool isStationItem(String? id) =>
      id != null &&
      id.startsWith(_stationItemPrefix) &&
      _toBundledStationClip(id.substring(_stationItemPrefix.length)).isNotEmpty;

  static String stationClipForItem(String? id) => isStationItem(id)
      ? _toBundledStationClip(id!.substring(_stationItemPrefix.length))
      : '';

  static bool isStationAssetPath(String? path) =>
      path != null &&
      path.startsWith(_stationAssetPrefix) &&
      _toBundledStationClip(
        path.substring(_stationAssetPrefix.length),
      ).isNotEmpty;

  static bool shouldPauseAfterQueueEntry(
    bool pauseAfterStations,
    String assetPath,
  ) => pauseAfterStations && isStationAssetPath(assetPath);

  /// A later gong begins the next manually assembled station group. The
  /// controller checks this before starting the next queue item, never before
  /// the queue's initial gong.
  static bool shouldPauseBeforeQueueEntry(
    bool pauseAfterStations,
    String assetPath,
  ) => pauseAfterStations && assetPath == _gongAssetPath;

  static bool requiresStation(Iterable<String> sequence) =>
      sequence.contains('station_name');

  static bool isKnown(String id) =>
      isStationItem(id) || _assetById.containsKey(id);

  static String? idForLabel(String label) {
    const ids = <String, String>{
      'Gong': 'gong',
      'Nächste Station': 'next_station',
      'Stationsname (Auswahl oben)': 'station_name',
      'Stationsname (alte Vorlage / Auswahl oben)': 'station_name',
      'Dieser Zug endet dort': 'train_ends',
      'Fahrgäste bitte alle aussteigen': 'all_exit',
      'Ausstieg in Fahrtrichtung links': 'exit_left',
      'Ausstieg in Fahrtrichtung rechts': 'exit_right',
      'Maskenhinweis FFP2': 'mask_ffp2',
      'Maskenhinweis FFP2 Englisch': 'mask_ffp2_en',
      'Hinweis · Persönliche Gegenstände': 'personal_belongings',
      'Hinweis · Vielen Dank und auf Wiedersehen': 'thank_you',
      'Hinweis · DB Regio Verabschiedung': 'db_regio_farewell',
      'Hinweis · Bis zum nächsten Mal · S-Bahn Rhein-Ruhr':
          'next_time_sbahn_rheinruhr',
      'Hinweis · Höhenunterschied zur Bahnsteigkante': 'platform_gap',
    };
    return ids[label];
  }

  static String labelForId(String id) {
    if (isStationItem(id)) return 'Station in Wiedergabeliste';
    const labelsById = <String, String>{
      'gong': 'Gong',
      'next_station': 'Nächste Station',
      'station_name': 'Stationsname (alte Vorlage / Auswahl oben)',
      'train_ends': 'Dieser Zug endet dort',
      'all_exit': 'Fahrgäste bitte alle aussteigen',
      'exit_left': 'Ausstieg in Fahrtrichtung links',
      'exit_right': 'Ausstieg in Fahrtrichtung rechts',
      'mask_ffp2': 'Maskenhinweis FFP2',
      'mask_ffp2_en': 'Maskenhinweis FFP2 Englisch',
      'personal_belongings': 'Hinweis · Persönliche Gegenstände',
      'thank_you': 'Hinweis · Vielen Dank und auf Wiedersehen',
      'db_regio_farewell': 'Hinweis · DB Regio Verabschiedung',
      'next_time_sbahn_rheinruhr':
          'Hinweis · Bis zum nächsten Mal · S-Bahn Rhein-Ruhr',
      'platform_gap': 'Hinweis · Höhenunterschied zur Bahnsteigkante',
    };
    return labelsById[id] ?? 'Unbekannter Baustein';
  }

  static List<String> toAssetPlaylist(
    Iterable<String> sequence, {
    required String selectedStationClip,
  }) {
    final output = <String>[];
    for (final block in sequence) {
      if (isStationItem(block)) {
        output.add('$_stationAssetPrefix${stationClipForItem(block)}');
        continue;
      }
      if (block == 'station_name') {
        final clip = _toBundledStationClip(selectedStationClip);
        if (clip.isEmpty) {
          throw ArgumentError(
            'Für den Baustein Stationsname fehlt ein Im-Zug-Stationsclip.',
          );
        }
        output.add('$_stationAssetPrefix$clip');
        continue;
      }
      final asset = _assetById[block];
      if (asset == null) {
        throw ArgumentError('Unbekannter Im-Zug-Baustein: $block');
      }
      output.add('asset:/inzug/text/$asset');
    }
    return output;
  }

  static String _toBundledStationClip(String? clip) {
    final safe = (clip ?? '').trim();
    if (!RegExp(r'^[a-z0-9][a-z0-9_]*\.(?:wav|opus)$').hasMatch(safe)) {
      return '';
    }
    return safe.endsWith('.wav')
        ? '${safe.substring(0, safe.length - 4)}.opus'
        : safe;
  }

  static const _assetById = <String, String>{
    'gong': 'gong_start.opus',
    'next_station': 'naechste_station.opus',
    'train_ends': 'dieser_zug_endet_dort.opus',
    'all_exit': 'fahrgaeste_bitte_alle_aussteigen.opus',
    'exit_left': 'ausstieg_fahrtrichtung_links.opus',
    'exit_right': 'ausstieg_fahrtrichtung_rechts.opus',
    'mask_ffp2': 'hinweis_maskenpflicht_ffp2_komplett.opus',
    'mask_ffp2_en': 'hinweis_ffp2_mask_english.opus',
    'personal_belongings': 'hinweis_persoenliche_gegenstaende.opus',
    'thank_you': 'hinweis_vielen_dank_und_auf_wiedersehen.opus',
    'db_regio_farewell': 'hinweis_db_regio_verabschiedung.opus',
    'next_time_sbahn_rheinruhr':
        'hinweis_bis_zum_naechsten_mal_s_bahn_rhein_ruhr.opus',
    'platform_gap': 'hinweis_bahnsteigkante.opus',
  };
}
