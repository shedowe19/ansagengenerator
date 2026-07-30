import 'package:ansagengenerator/core/station_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final stations = <StationEntry>[
    StationEntry(name: 'Köln Hbf', filepath: '8010205.wav', ibnr: '8000207'),
    StationEntry(name: 'Cottbus', filepath: '8010073.wav', ibnr: '8010073'),
  ];
  final ril = <RilEntry>[
    RilEntry(
      code: 'KASZ',
      name: 'Kassel-Wilhelmshöhe',
      station: 'Kassel-Wilhelmshöhe',
      filepath: '8012308.wav',
      ibnr: '8003200',
    ),
    RilEntry(
      code: 'KÖLH',
      name: 'Köln Hbf',
      station: 'Köln Hbf',
      filepath: '8010205.wav',
      ibnr: '8000207',
    ),
  ];
  final index = StationSearchIndex(stations: stations, rilEntries: ril);

  test('prioritizes uppercase RL100 code matches', () {
    final results = index.search('KASZ');
    expect(results, hasLength(1));
    expect(results.single.title, 'Kassel-Wilhelmshöhe');
    expect(results.single.filepath, '8012308.wav');
  });

  test('keeps mixed-case place names as a normalized name search', () {
    final results = index.search('Cottbus');
    expect(results.first.title, 'Cottbus');
  });

  test('resolves RIL codes and expanded umlaut names to audio files', () {
    expect(index.resolveFile('KASZ', ''), '8012308.wav');
    expect(index.resolveFile('Koeln Hbf', ''), '8010205.wav');
    expect(index.resolveFile('9999', 'fallback.wav'), '');
  });
}
