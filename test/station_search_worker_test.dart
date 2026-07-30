import 'dart:convert';

import 'package:ansagengenerator/data/station_search_worker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'searches in a dedicated worker and preserves RL100/name behavior',
    () async {
      final worker = await StationSearchWorker.start(
        StationSearchPayload(
          stationsJson: jsonEncode(<Map<String, String>>[
            <String, String>{
              'station': 'Köln Hbf',
              'filepath': '8010205.wav',
              'ibnr': '8000207',
            },
            <String, String>{
              'station': 'Cottbus',
              'filepath': '8010073.wav',
              'ibnr': '8010073',
            },
          ]),
          rilJson: jsonEncode(<Map<String, String>>[
            <String, String>{
              'code': 'KASZ',
              'name': 'Kassel-Wilhelmshöhe',
              'station': 'Kassel-Wilhelmshöhe',
              'filepath': '8012308.wav',
              'ibnr': '8003200',
            },
          ]),
        ),
      );
      addTearDown(worker.dispose);

      expect((await worker.search('KASZ')).single.title, 'Kassel-Wilhelmshöhe');
      expect((await worker.search('Koeln')).single.filepath, '8010205.wav');
      expect((await worker.search('Cottbus')).single.title, 'Cottbus');
    },
  );
}
