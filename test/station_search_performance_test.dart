import 'dart:io';

import 'package:ansagengenerator/core/station_search.dart';
import 'package:ansagengenerator/data/station_search_worker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'real station dataset is served from the background search worker',
    () async {
      final assets = Directory('source-android/app/src/main/assets');
      final startup = Stopwatch()..start();
      final worker = await StationSearchWorker.start(
        StationSearchPayload(
          stationsJson: await File(
            '${assets.path}/stations.json',
          ).readAsString(),
          rilJson: await File('${assets.path}/ril100.json').readAsString(),
        ),
      );
      startup.stop();
      addTearDown(worker.dispose);

      final latencies = <String, Duration>{};
      List<StationSearchResult> results = const <StationSearchResult>[];
      for (final query in <String>[
        'K',
        'Ko',
        'Kol',
        'Köln',
        'KASZ',
        'Cottbus',
      ]) {
        final stopwatch = Stopwatch()..start();
        results = await worker.search(query);
        stopwatch.stop();
        latencies[query] = stopwatch.elapsed;
      }

      final worst = latencies.values.reduce(
        (left, right) => left.compareTo(right) >= 0 ? left : right,
      );
      // This is intentionally generous for a shared CI host. The important
      // invariant is that this work happens off the Flutter UI isolate.
      expect(worst, lessThan(const Duration(milliseconds: 250)));
      expect(results, isNotEmpty);
      // ignore: avoid_print
      print(
        'search worker startup=${startup.elapsedMilliseconds}ms '
        'latencies=${latencies.map((key, value) => MapEntry(key, '${value.inMilliseconds}ms'))}',
      );
    },
  );
}
