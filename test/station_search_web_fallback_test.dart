import 'package:ansagengenerator/data/station_search_worker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('in-process web fallback searches without ReceivePort support', () async {
    final worker = await StationSearchWorker.startInProcess(
      const StationSearchPayload(
        stationsJson:
            '[{"station":"Köln Hbf","filepath":"8010205.wav","ibnr":"8010205"}]',
        rilJson:
            '[{"code":"KASZ","name":"Köln Hbf","station":"Köln Hbf","filepath":"8010205.wav","ibnr":"8010205"}]',
      ),
    );
    addTearDown(worker.dispose);

    final results = await worker.search('KASZ');

    expect(results, hasLength(1));
    expect(results.single.title, 'Köln Hbf');
    expect(results.single.filepath, '8010205.wav');
  });
}
