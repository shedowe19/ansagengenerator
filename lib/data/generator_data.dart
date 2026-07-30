import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/station_search.dart';
import 'station_search_worker.dart';

const assetRoot = 'source-android/app/src/main/assets';

class InTrainStationClip {
  const InTrainStationClip({
    required this.station,
    required this.raw,
    required this.filepath,
    required this.clip,
  });

  factory InTrainStationClip.fromJson(Map<String, dynamic> json) =>
      InTrainStationClip(
        station: (json['station'] ?? '').toString(),
        raw: (json['raw'] ?? '').toString(),
        filepath: (json['filepath'] ?? '').toString(),
        clip: (json['clip'] ?? '').toString(),
      );

  final String station;
  final String raw;
  final String filepath;
  final String clip;
}

class GeneratorData {
  const GeneratorData({
    required this.index,
    required this.searchPayload,
    required this.trainTypes,
    required this.inTrainByFile,
    required this.stationCount,
    required this.rilCount,
  });

  final StationSearchIndex index;
  final StationSearchPayload searchPayload;
  final List<String> trainTypes;
  final Map<String, InTrainStationClip> inTrainByFile;
  final int stationCount;
  final int rilCount;

  InTrainStationClip? inTrainClipForFile(String filepath) =>
      inTrainByFile[filepath];

  static Future<GeneratorData> load() async {
    Future<String> readText(String asset) =>
        rootBundle.loadString('$assetRoot/$asset');

    List<dynamic> decodeArray(String asset, String raw) {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw FormatException('$asset enthält kein JSON-Array.');
      }
      return decoded;
    }

    final raw = await Future.wait(<Future<String>>[
      readText('stations.json'),
      readText('ril100.json'),
      readText('train_types.json'),
      readText('inzug/inzug_station_mapping.json'),
    ]);
    final arrays = <List<dynamic>>[
      decodeArray('stations.json', raw[0]),
      decodeArray('ril100.json', raw[1]),
      decodeArray('train_types.json', raw[2]),
      decodeArray('inzug/inzug_station_mapping.json', raw[3]),
    ];
    final stations = arrays[0]
        .whereType<Map>()
        .map((value) => StationEntry.fromJson(Map<String, dynamic>.from(value)))
        .toList(growable: false);
    final ril = arrays[1]
        .whereType<Map>()
        .map((value) => RilEntry.fromJson(Map<String, dynamic>.from(value)))
        .toList(growable: false);
    final trainTypes = arrays[2]
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final inTrain = <String, InTrainStationClip>{};
    for (final value in arrays[3].whereType<Map>()) {
      final clip = InTrainStationClip.fromJson(
        Map<String, dynamic>.from(value),
      );
      if (clip.filepath.isNotEmpty && clip.clip.isNotEmpty) {
        inTrain.putIfAbsent(clip.filepath, () => clip);
      }
    }
    return GeneratorData(
      index: StationSearchIndex(stations: stations, rilEntries: ril),
      searchPayload: StationSearchPayload(
        stationsJson: raw[0],
        rilJson: raw[1],
      ),
      trainTypes: trainTypes.isEmpty
          ? const <String>['ICE', 'IC', 'RE', 'RB', 'S']
          : trainTypes,
      inTrainByFile: Map.unmodifiable(inTrain),
      stationCount: stations.length,
      rilCount: ril.length,
    );
  }
}
