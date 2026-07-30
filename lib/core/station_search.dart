import 'search_query.dart';

class StationEntry {
  StationEntry({required this.name, required this.filepath, required this.ibnr})
    : foldedName = SearchQuery.fold(name),
      expandedName = SearchQuery.expand(name);

  factory StationEntry.fromJson(Map<String, dynamic> json) => StationEntry(
    name: (json['station'] ?? '').toString(),
    filepath: (json['filepath'] ?? '').toString(),
    ibnr: (json['ibnr'] ?? '').toString(),
  );

  final String name;
  final String filepath;
  final String ibnr;
  final String foldedName;
  final String expandedName;
}

class RilEntry {
  RilEntry({
    required this.code,
    required this.name,
    required this.station,
    required this.filepath,
    required this.ibnr,
  }) : normalizedCode = SearchQuery.code(code),
       foldedName = SearchQuery.fold(name),
       expandedName = SearchQuery.expand(name),
       foldedStation = SearchQuery.fold(station),
       expandedStation = SearchQuery.expand(station);

  factory RilEntry.fromJson(Map<String, dynamic> json) => RilEntry(
    code: (json['code'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    station: (json['station'] ?? '').toString(),
    filepath: (json['filepath'] ?? '').toString(),
    ibnr: (json['ibnr'] ?? '').toString(),
  );

  final String code;
  final String name;
  final String station;
  final String filepath;
  final String ibnr;
  final String normalizedCode;
  final String foldedName;
  final String expandedName;
  final String foldedStation;
  final String expandedStation;
  String get displayName => station.isEmpty ? name : station;
}

class StationSearchResult {
  const StationSearchResult({
    required this.title,
    required this.subtitle,
    required this.filepath,
    required this.score,
  });

  final String title;
  final String subtitle;
  final String filepath;
  final int score;
}

/// Immutable index used by both the UI and the dedicated search isolate.
class StationSearchIndex {
  StationSearchIndex({
    required List<StationEntry> stations,
    required List<RilEntry> rilEntries,
  }) : _stations = List.unmodifiable(stations),
       _rilEntries = List.unmodifiable(rilEntries) {
    for (final station in _stations) {
      _byFolded.putIfAbsent(station.foldedName, () => station);
      _byExpanded.putIfAbsent(station.expandedName, () => station);
      if (station.filepath.isNotEmpty) {
        _byFile.putIfAbsent(station.filepath, () => station);
      }
    }
    for (final entry in _rilEntries) {
      if (entry.normalizedCode.isNotEmpty) {
        _rilByCode.putIfAbsent(entry.normalizedCode, () => entry);
        _addPrefixes(_rilCodePrefixes, entry.normalizedCode, entry);
      }
    }
  }

  final List<StationEntry> _stations;
  final List<RilEntry> _rilEntries;
  final _byFolded = <String, StationEntry>{};
  final _byExpanded = <String, StationEntry>{};
  final _byFile = <String, StationEntry>{};
  final _rilByCode = <String, RilEntry>{};
  final _rilCodePrefixes = <String, List<RilEntry>>{};

  List<StationSearchResult> search(String rawQuery, {int maxResults = 24}) {
    if (maxResults <= 0) return const <StationSearchResult>[];
    final raw = rawQuery.trim();
    if (raw.isEmpty) return const <StationSearchResult>[];

    final folded = SearchQuery.fold(raw);
    final expanded = SearchQuery.expand(raw);
    final code = SearchQuery.code(raw);
    final isCodeQuery = SearchQuery.isCodeQuery(raw);
    // Avoid broad one- and two-character substring scans. Prefix and code
    // matches remain available while the user keeps typing.
    final allowContains = folded.length >= 3;
    final results = _TopResults(maxResults);

    if (isCodeQuery) {
      final exact = _rilByCode[code];
      if (exact != null) results.add(_rilResult(exact, 1000));
      for (final entry in _rilCodePrefixes[code] ?? const <RilEntry>[]) {
        if (entry.normalizedCode.startsWith(code)) {
          results.add(_rilResult(entry, 900));
        }
      }
      return results.finish();
    }

    for (final station in _stations) {
      final score = _nameScore(
        station.foldedName,
        station.expandedName,
        folded,
        expanded,
        allowContains: allowContains,
      );
      if (score > 0) {
        results.add(
          StationSearchResult(
            title: station.name,
            subtitle: station.ibnr.isEmpty ? 'Bahnhof' : 'IBNR ${station.ibnr}',
            filepath: station.filepath,
            score: score,
          ),
        );
      }
    }
    for (final entry in _rilEntries) {
      final score = _bestNameScore(
        entry,
        folded,
        expanded,
        allowContains: allowContains,
      );
      if (score > 0) results.add(_rilResult(entry, score - 25));
    }
    return results.finish();
  }

  String resolveFile(String raw, String fallback) {
    final value = raw.trim();
    if (_isSentinel(value)) return '';
    final normalizedPath = value.replaceAll('\\', '/');
    final tail = normalizedPath.substring(normalizedPath.lastIndexOf('/') + 1);
    if (tail.endsWith('.wav')) return tail;
    if (RegExp(r'^\d{4,8}$').hasMatch(tail)) return '$tail.wav';

    final ril = _rilByCode[SearchQuery.code(value)];
    if (ril != null && ril.filepath.isNotEmpty) return ril.filepath;
    final exact =
        _byFolded[SearchQuery.fold(value)] ??
        _byExpanded[SearchQuery.expand(value)];
    if (exact != null) return exact.filepath;

    final folded = SearchQuery.fold(value);
    final expanded = SearchQuery.expand(value);
    for (final station in _stations) {
      if (station.foldedName.contains(folded) ||
          station.expandedName.contains(expanded)) {
        return station.filepath;
      }
    }
    return fallback;
  }

  StationEntry? findByFile(String filepath) => _byFile[filepath];

  static void _addPrefixes<T>(
    Map<String, List<T>> index,
    String value,
    T item,
  ) {
    for (var length = 1; length <= value.length; length++) {
      final prefix = value.substring(0, length);
      (index[prefix] ??= <T>[]).add(item);
    }
  }

  static StationSearchResult _rilResult(RilEntry entry, int score) =>
      StationSearchResult(
        title: entry.displayName,
        subtitle: 'RIL-100 ${entry.normalizedCode}',
        filepath: entry.filepath,
        score: score,
      );

  static int _bestNameScore(
    RilEntry entry,
    String foldedQuery,
    String expandedQuery, {
    required bool allowContains,
  }) {
    final nameScore = _nameScore(
      entry.foldedName,
      entry.expandedName,
      foldedQuery,
      expandedQuery,
      allowContains: allowContains,
    );
    final stationScore = _nameScore(
      entry.foldedStation,
      entry.expandedStation,
      foldedQuery,
      expandedQuery,
      allowContains: allowContains,
    );
    return nameScore > stationScore ? nameScore : stationScore;
  }

  static int _nameScore(
    String foldedName,
    String expandedName,
    String foldedQuery,
    String expandedQuery, {
    required bool allowContains,
  }) {
    if (foldedQuery.isEmpty || expandedQuery.isEmpty) return 0;
    if (foldedName == foldedQuery || expandedName == expandedQuery) return 800;
    if (foldedName.startsWith(foldedQuery) ||
        expandedName.startsWith(expandedQuery)) {
      return 600;
    }
    if (allowContains &&
        (foldedName.contains(foldedQuery) ||
            expandedName.contains(expandedQuery))) {
      return 400;
    }
    return 0;
  }

  static bool _isSentinel(String value) =>
      value.isEmpty || value == '0' || value == '-' || value == '9999';
}

class _TopResults {
  _TopResults(this.limit);

  final int limit;
  final Set<String> _seen = <String>{};
  final List<StationSearchResult> _results = <StationSearchResult>[];

  void add(StationSearchResult result) {
    final key = result.filepath.isNotEmpty ? result.filepath : result.title;
    if (!_seen.add(key)) return;
    if (_results.length < limit) {
      _results.add(result);
      return;
    }
    var worstIndex = 0;
    for (var index = 1; index < _results.length; index++) {
      if (_compare(_results[worstIndex], _results[index]) < 0) {
        worstIndex = index;
      }
    }
    if (_compare(result, _results[worstIndex]) < 0) {
      _results[worstIndex] = result;
    }
  }

  List<StationSearchResult> finish() {
    _results.sort(_compare);
    return List<StationSearchResult>.unmodifiable(_results);
  }

  static int _compare(StationSearchResult left, StationSearchResult right) {
    final score = right.score.compareTo(left.score);
    if (score != 0) return score;
    return left.title.compareTo(right.title);
  }
}
