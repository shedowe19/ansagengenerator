import 'package:ansagengenerator/core/search_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchQuery', () {
    test('normalizes German umlauts, ß, punctuation and whitespace', () {
      expect(
        SearchQuery.fold('  Köln-Bonn  Flughafen  '),
        'koln bonn flughafen',
      );
      expect(SearchQuery.expand('Köln-Bonn Flughafen'), 'koeln bonn flughafen');
      expect(SearchQuery.fold('Straße'), 'strasse');
    });

    test('recognizes only uppercase RL100-shaped input as a code query', () {
      expect(SearchQuery.isCodeQuery('KASZ'), isTrue);
      expect(SearchQuery.isCodeQuery('MH'), isTrue);
      expect(SearchQuery.isCodeQuery('Cottbus'), isFalse);
      expect(SearchQuery.isCodeQuery('Köln'), isFalse);
    });
  });
}
