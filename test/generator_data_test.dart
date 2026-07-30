import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('source snapshot has parseable non-empty offline data files', () async {
    const assets = <String>[
      'stations.json',
      'ril100.json',
      'train_types.json',
      'inzug/inzug_station_mapping.json',
    ];
    const root = 'source-android/app/src/main/assets';

    for (final asset in assets) {
      final value = jsonDecode(await File('$root/$asset').readAsString());
      expect(value, isA<List>());
      expect(value, isNotEmpty);
    }
  });
}
