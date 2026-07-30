import 'dart:core';

/// German/RL100-aware normalisation shared by station search and sorting.
abstract final class SearchQuery {
  static String fold(String? value) => _normalise(value, expandUmlauts: false);

  static String expand(String? value) => _normalise(value, expandUmlauts: true);

  static String code(String? value) =>
      (value ?? '').trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  /// RL100 codes are deliberately recognised only when typed uppercase.
  /// A name such as "Cottbus" must remain a name search.
  static bool isCodeQuery(String? rawQuery) {
    final trimmed = (rawQuery ?? '').trim();
    return trimmed.isNotEmpty &&
        trimmed == trimmed.toUpperCase() &&
        RegExp(r'^[A-Z0-9 ]{1,7}$').hasMatch(trimmed);
  }

  static String _normalise(String? value, {required bool expandUmlauts}) {
    var result = (value ?? '').toLowerCase();
    if (expandUmlauts) {
      result = result
          .replaceAll('ä', 'ae')
          .replaceAll('ö', 'oe')
          .replaceAll('ü', 'ue');
    } else {
      result = result
          .replaceAll('ä', 'a')
          .replaceAll('ö', 'o')
          .replaceAll('ü', 'u');
    }
    result = result
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[àáâãåāăą]'), 'a')
        .replaceAll(RegExp(r'[çćč]'), 'c')
        .replaceAll(RegExp(r'[ďđ]'), 'd')
        .replaceAll(RegExp(r'[èéêëēĕėęě]'), 'e')
        .replaceAll(RegExp(r'[ìíîïīĭį]'), 'i')
        .replaceAll(RegExp(r'[ł]'), 'l')
        .replaceAll(RegExp(r'[ñńň]'), 'n')
        .replaceAll(RegExp(r'[òóôõøōŏő]'), 'o')
        .replaceAll(RegExp(r'[ŕř]'), 'r')
        .replaceAll(RegExp(r'[śšş]'), 's')
        .replaceAll(RegExp(r'[ťţ]'), 't')
        .replaceAll(RegExp(r'[ùúûūŭůűų]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll(RegExp(r'[źžż]'), 'z')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    return result.replaceAll(RegExp(r'\s+'), ' ');
  }
}
