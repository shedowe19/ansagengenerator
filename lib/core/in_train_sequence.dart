/// Pure mapping for freely ordered, bundled Im-Zug announcement atoms.
abstract final class InTrainSequence {
  static const _stationItemPrefix = 'station:';
  static const _stationAssetPrefix = 'asset:/inzug/station_name_only/';
  static const _gongAssetPath = 'asset:/inzug/text/gong_start.opus';
  static const _combinedEndId = 'train_ends_all_exit';
  static const _combinedEndLabel =
      'Dieser Zug endet dort · Fahrgäste bitte aussteigen';

  static const labels = <String>[
    'Gong',
    'Nächste Station',
    _combinedEndLabel,
    'Ausstieg in Fahrtrichtung links',
    'Ausstieg in Fahrtrichtung rechts',
    'Maskenhinweis FFP2',
    'Maskenhinweis FFP2 Englisch',
    'Hinweis · Persönliche Gegenstände',
    'Hinweis · Vielen Dank und auf Wiedersehen',
    'Hinweis · DB Regio Verabschiedung',
    'Hinweis · Bis zum nächsten Mal · S-Bahn Rhein-Ruhr',
    'Hinweis · Bauarbeiten und Fahrplanänderungen',
    'Hinweis · Trittstufen fahren nicht aus',
    'Hinweis · Verspätung wegen Signalreparatur',
    'Hinweis · Türbereich freihalten',
    'Hinweis · Außerplanmäßiger Halt',
    'Hinweis · Abstand zur Bahnsteigkante',
    'Hinweis · Weiterfahrt in die Abstellung',
    'Hinweis · Corona · Abstand und medizinische Maske',
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

  /// Turns historic, split end-stop entries into one supplied announcement.
  /// Adjacent legacy halves belonged to one sentence and must not be replayed
  /// twice after an existing template is restored.
  static List<String> migrateLegacySequence(Iterable<String> sequence) {
    final migrated = <String>[];
    for (final raw in sequence) {
      final id = _canonicalBlockId(raw);
      if (id == _combinedEndId &&
          migrated.isNotEmpty &&
          migrated.last == _combinedEndId) {
        continue;
      }
      migrated.add(id);
    }
    return migrated;
  }

  static bool isKnown(String id) =>
      isStationItem(id) || _assetById.containsKey(_canonicalBlockId(id));

  static String? idForLabel(String label) {
    const ids = <String, String>{
      'Gong': 'gong',
      'Nächste Station': 'next_station',
      'Stationsname (Auswahl oben)': 'station_name',
      'Stationsname (alte Vorlage / Auswahl oben)': 'station_name',
      _combinedEndLabel: _combinedEndId,
      'Dieser Zug endet dort': _combinedEndId,
      'Fahrgäste bitte alle aussteigen': _combinedEndId,
      'Ausstieg in Fahrtrichtung links': 'exit_left',
      'Ausstieg in Fahrtrichtung rechts': 'exit_right',
      'Maskenhinweis FFP2': 'mask_ffp2',
      'Maskenhinweis FFP2 Englisch': 'mask_ffp2_en',
      'Hinweis · Persönliche Gegenstände': 'personal_belongings',
      'Hinweis · Vielen Dank und auf Wiedersehen': 'thank_you',
      'Hinweis · DB Regio Verabschiedung': 'db_regio_farewell',
      'Hinweis · Bis zum nächsten Mal · S-Bahn Rhein-Ruhr':
          'next_time_sbahn_rheinruhr',
      'Hinweis · Bauarbeiten und Fahrplanänderungen':
          'construction_work_notice',
      'Hinweis · Trittstufen fahren nicht aus': 'step_extension_unavailable',
      'Hinweis · Verspätung wegen Signalreparatur':
          'signal_repair_delay_notice',
      'Hinweis · Türbereich freihalten': 'door_area_clear_notice',
      'Hinweis · Außerplanmäßiger Halt': 'unscheduled_stop_notice',
      'Hinweis · Abstand zur Bahnsteigkante': 'platform_edge_gap_notice',
      'Hinweis · Höhenunterschied zur Bahnsteigkante':
          'platform_edge_gap_notice',
      'Hinweis · Weiterfahrt in die Abstellung': 'stabling_exit_notice',
      'Hinweis · Corona · Abstand und medizinische Maske': 'corona_mask_notice',
    };
    return ids[label];
  }

  static String labelForId(String id) {
    if (isStationItem(id)) return 'Station in Wiedergabeliste';
    const labelsById = <String, String>{
      'gong': 'Gong',
      'next_station': 'Nächste Station',
      'station_name': 'Stationsname (alte Vorlage / Auswahl oben)',
      _combinedEndId: _combinedEndLabel,
      'exit_left': 'Ausstieg in Fahrtrichtung links',
      'exit_right': 'Ausstieg in Fahrtrichtung rechts',
      'mask_ffp2': 'Maskenhinweis FFP2',
      'mask_ffp2_en': 'Maskenhinweis FFP2 Englisch',
      'personal_belongings': 'Hinweis · Persönliche Gegenstände',
      'thank_you': 'Hinweis · Vielen Dank und auf Wiedersehen',
      'db_regio_farewell': 'Hinweis · DB Regio Verabschiedung',
      'next_time_sbahn_rheinruhr':
          'Hinweis · Bis zum nächsten Mal · S-Bahn Rhein-Ruhr',
      'construction_work_notice':
          'Hinweis · Bauarbeiten und Fahrplanänderungen',
      'step_extension_unavailable': 'Hinweis · Trittstufen fahren nicht aus',
      'signal_repair_delay_notice':
          'Hinweis · Verspätung wegen Signalreparatur',
      'door_area_clear_notice': 'Hinweis · Türbereich freihalten',
      'unscheduled_stop_notice': 'Hinweis · Außerplanmäßiger Halt',
      'platform_edge_gap_notice': 'Hinweis · Abstand zur Bahnsteigkante',
      'stabling_exit_notice': 'Hinweis · Weiterfahrt in die Abstellung',
      'corona_mask_notice': 'Hinweis · Corona · Abstand und medizinische Maske',
    };
    return labelsById[_canonicalBlockId(id)] ?? 'Unbekannter Baustein';
  }

  static List<String> toAssetPlaylist(
    Iterable<String> sequence, {
    required String selectedStationClip,
  }) {
    final output = <String>[];
    for (final raw in migrateLegacySequence(sequence)) {
      final block = _canonicalBlockId(raw);
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

  static String _canonicalBlockId(String id) =>
      id == 'train_ends' || id == 'all_exit'
      ? _combinedEndId
      : id == 'platform_gap'
      ? 'platform_edge_gap_notice'
      : id;

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
    _combinedEndId: 'zug_endet_fahrgaeste_aussteigen.opus',
    'exit_left': 'ausstieg_fahrtrichtung_links.opus',
    'exit_right': 'ausstieg_fahrtrichtung_rechts.opus',
    'mask_ffp2': 'hinweis_maskenpflicht_ffp2_komplett.opus',
    'mask_ffp2_en': 'hinweis_ffp2_mask_english.opus',
    'personal_belongings': 'hinweis_persoenliche_gegenstaende.opus',
    'thank_you': 'hinweis_vielen_dank_und_auf_wiedersehen.opus',
    'db_regio_farewell': 'hinweis_db_regio_verabschiedung.opus',
    'next_time_sbahn_rheinruhr':
        'hinweis_bis_zum_naechsten_mal_s_bahn_rhein_ruhr.opus',
    'construction_work_notice': 'hinweis_bauarbeiten_fahrplanaenderungen.opus',
    'step_extension_unavailable': 'hinweis_trittstufen_fahren_nicht_aus.opus',
    'signal_repair_delay_notice': 'hinweis_signalreparatur_verzoegerung.opus',
    'door_area_clear_notice': 'hinweis_tuerbereich_freihalten.opus',
    'unscheduled_stop_notice': 'hinweis_ausserplanmaessiger_halt.opus',
    'platform_edge_gap_notice': 'hinweis_abstand_zur_bahnsteigkante.opus',
    'stabling_exit_notice': 'hinweis_weiterfahrt_in_die_abstellung.opus',
    'corona_mask_notice': 'hinweis_corona_abstand_medizinische_maske.opus',
  };
}
