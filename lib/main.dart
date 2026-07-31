import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/announcement_builder.dart';
import 'core/information_options.dart';
import 'core/in_train_sequence.dart';
import 'core/station_search.dart';
import 'data/announcement_audio_controller.dart';
import 'data/generator_data.dart';
import 'data/station_search_worker.dart';

void main() {
  AnnouncementAudioController.configureCuratedAssetCache();
  runApp(const AnsagengeneratorApp());
}

class AnsagengeneratorApp extends StatelessWidget {
  const AnsagengeneratorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ansagengenerator',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff7c7cff),
        brightness: Brightness.dark,
        surface: const Color(0xff10141f),
      ),
      scaffoldBackgroundColor: const Color(0xff05060a),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff161b29),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    home: const GeneratorScreen(),
  );
}

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  final _audio = AnnouncementAudioController();
  final _search = TextEditingController();
  final _platform = TextEditingController(text: '1');
  final _hour = TextEditingController(text: '18');
  final _minute = TextEditingController(text: '59');
  final _trainNumber = TextEditingController();
  final _via = TextEditingController(text: '0');
  final _withNumber = TextEditingController();
  final _withTarget = TextEditingController();
  final _splitFirst = TextEditingController();
  final _splitSecond = TextEditingController();
  final _continueNumber = TextEditingController();
  final _continueTarget = TextEditingController();
  final _continueHour = TextEditingController(text: '18');
  final _continueMinute = TextEditingController(text: '59');
  final _newPlatform = TextEditingController(text: '0');
  final _onlyUntil = TextEditingController(text: '0');
  final _plusStops = TextEditingController(text: '0');
  final _minusStops = TextEditingController(text: '0');
  final _connection2Number = TextEditingController();
  final _connection2Target = TextEditingController();
  final _connection2Platform = TextEditingController(text: '1');
  final _dispatchPlatform = TextEditingController(text: '1');
  final _passingPlatform = TextEditingController(text: '1');

  GeneratorData? _data;
  StationSearchWorker? _searchWorker;
  Object? _loadError;
  Object? _searchError;
  Timer? _searchDebounce;
  int _searchGeneration = 0;
  bool _searchPending = false;
  bool _suppressSearch = false;
  List<StationSearchResult> _results = const <StationSearchResult>[];
  StationSearchResult? _selected;
  AnnouncementMode _mode = AnnouncementMode.entry;
  AnnouncementLanguage _language = AnnouncementLanguage.german;
  String _trainType = 'ICE';
  String _withTrainType = 'RE';
  String _continueTrainType = 'RE';
  String _connection2TrainType = 'RE';
  String _infoDelay = '0 · keine';
  String _infoReason = '0 · keiner';
  String _special = '001.wav · Gepäck';
  String _inTrainLabel = InTrainSequence.labels.first;
  final List<String> _inTrainSequence = <String>[];
  bool _delayed = false;
  bool _substitute = false;
  bool _withTrain = false;
  bool _split = false;
  bool _splitSecondEnabled = false;
  bool _noBoard = false;
  bool _continueEnabled = false;
  bool _cancel = false;
  bool _sorry = false;
  bool _connection2Enabled = false;
  bool _pauseAfterStation = true;
  List<Map<String, dynamic>> _favorites = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];

  static const _delayOptions = InformationOptions.delays;
  static const _reasonOptions = InformationOptions.reasons;
  static const _specialOptions = <String>[
    '001.wav · Gepäck',
    '002.wav · Rauchverbot',
    '003.wav · Raucherbereich',
    '004.wav · Bettelgruppen',
    '005.wav · Trickdiebe',
    '006.wav · Hinweis Zugbetrieb',
    '007.wav · Feueralarm',
    '008.wav · Bombendrohung',
  ];

  @override
  void initState() {
    super.initState();
    _search.addListener(_scheduleSearch);
    _audio.addListener(_onAudioChanged);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        GeneratorData.load(),
        SharedPreferences.getInstance(),
      ]);
      final data = results[0] as GeneratorData;
      final prefs = results[1] as SharedPreferences;
      final worker = await StationSearchWorker.start(data.searchPayload);
      if (!mounted) {
        worker.dispose();
        return;
      }
      setState(() {
        _data = data;
        _searchWorker = worker;
        _favorites = _readStored(prefs.getString('favorites'));
        _history = _readStored(prefs.getString('history'));
        if (data.trainTypes.contains('ICE')) {
          _trainType = 'ICE';
        } else {
          _trainType = data.trainTypes.first;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  List<Map<String, dynamic>> _readStored(String? raw) {
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  void _onAudioChanged() {
    if (mounted) setState(() {});
  }

  void _scheduleSearch() {
    if (_suppressSearch) return;
    final query = _search.text.trim();
    final generation = ++_searchGeneration;
    _searchDebounce?.cancel();
    setState(() {
      _results = const <StationSearchResult>[];
      _searchPending = query.isNotEmpty;
      _searchError = null;
    });
    if (query.isEmpty) return;
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      unawaited(_runSearch(generation, query));
    });
  }

  Future<void> _runSearch(int generation, String query) async {
    final worker = _searchWorker;
    if (worker == null) return;
    try {
      final results = await worker.search(query);
      if (!mounted ||
          generation != _searchGeneration ||
          query != _search.text.trim()) {
        return;
      }
      setState(() {
        _results = results;
        _searchPending = false;
      });
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchPending = false;
        _searchError = error;
      });
    }
  }

  void _select(StationSearchResult result) {
    ++_searchGeneration;
    _searchDebounce?.cancel();
    _suppressSearch = true;
    _search.clear();
    _suppressSearch = false;
    setState(() {
      _selected = result;
      _results = const <StationSearchResult>[];
      _searchPending = false;
    });
  }

  String get _selectedTitle => _selected == null ? '' : _selected!.title;

  AnnouncementDraft _draft() {
    final connections = <ConnectionDraft>[];
    if (_connection2Enabled) {
      connections.add(
        ConnectionDraft(
          trainType: _trainType,
          numbers: _numbers(),
          target: _selected?.filepath ?? '',
          via: _via.text,
          platform: _platform.text,
          hour: _hour.text,
          minute: _minute.text,
        ),
      );
      connections.add(
        ConnectionDraft(
          trainType: _connection2TrainType,
          numbers: <String>[_connection2Number.text],
          target: _connection2Target.text,
          platform: _connection2Platform.text,
          hour: _hour.text,
          minute: _minute.text,
        ),
      );
    }
    return AnnouncementDraft(
      mode: _mode,
      language: _language,
      targetFile: _selected?.filepath ?? '',
      platform: _platform.text,
      hour: _hour.text,
      minute: _minute.text,
      trainType: _trainType,
      trainNumbers: _numbers(),
      via: _via.text,
      delayed: _delayed,
      substituteTrain: _substitute,
      withTrains: _withTrain
          ? <TrainDraft>[
              TrainDraft(
                trainType: _withTrainType,
                numbers: <String>[_withNumber.text],
                target: _withTarget.text,
              ),
            ]
          : const <TrainDraft>[],
      splitEnabled: _split,
      splitTwoEnabled: _splitSecondEnabled,
      splitFirstTarget: _splitFirst.text,
      splitSecondTarget: _splitSecond.text,
      noBoard: _noBoard,
      continueEnabled: _continueEnabled,
      continueTrain: TrainDraft(
        trainType: _continueTrainType,
        numbers: <String>[_continueNumber.text],
        target: _continueTarget.text,
      ),
      continueHour: _continueHour.text,
      continueMinute: _continueMinute.text,
      infoDelay: _infoDelay,
      infoReason: _infoReason,
      infoNewPlatform: _newPlatform.text,
      infoOnlyUntil: _onlyUntil.text,
      haltPlus: _plusStops.text
          .split(',')
          .map((value) => value.trim())
          .toList(),
      haltMinus: _minusStops.text
          .split(',')
          .map((value) => value.trim())
          .toList(),
      cancelTrain: _cancel,
      sorry: _sorry,
      connections: connections,
      dispatchPlatform: _dispatchPlatform.text,
      passingPlatform: _passingPlatform.text,
      specialCode: _special,
      inTrainSequence: List<String>.unmodifiable(_inTrainSequence),
      selectedInTrainStationClip:
          _data?.inTrainClipForFile(_selected?.filepath ?? '')?.clip ?? '',
    );
  }

  List<String> _numbers() => <String>[_trainNumber.text];

  List<String> _playlist() => AnnouncementBuilder(
    draft: _draft(),
    stationFileResolver: _data?.index.resolveFile,
  ).build();

  Future<void> _play() async {
    if (_mode != AnnouncementMode.inTrain && _selected == null) {
      _notice('Bitte zuerst einen Zielbahnhof auswählen.');
      return;
    }
    if (_mode == AnnouncementMode.inTrain && _inTrainSequence.isEmpty) {
      _notice('Bitte mindestens einen Im-Zug-Baustein hinzufügen.');
      return;
    }
    try {
      final playlist = _playlist();
      await _audio.play(
        playlist,
        pauseAfterStations:
            _mode == AnnouncementMode.inTrain && _pauseAfterStation,
      );
      await _storeHistory();
    } catch (error) {
      _notice('Wiedergabe nicht möglich: $error');
    }
  }

  Future<void> _export() async {
    if (_mode != AnnouncementMode.inTrain && _selected == null) {
      _notice('Bitte zuerst einen Zielbahnhof auswählen.');
      return;
    }
    try {
      final output = await _audio.exportWav(_playlist());
      await _storeHistory();
      _notice('WAV exportiert: $output');
    } catch (error) {
      _notice('Export nicht verfügbar: $error');
    }
  }

  Future<void> _storeFavorite() async {
    final item = _preset();
    setState(() {
      _favorites = <Map<String, dynamic>>[
        item,
        ..._favorites.where((value) => value['title'] != item['title']),
      ].take(12).toList();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('favorites', jsonEncode(_favorites));
    _notice('Vorlage gespeichert.');
  }

  Future<void> _storeHistory() async {
    final item = _preset();
    setState(() {
      _history = <Map<String, dynamic>>[
        item,
        ..._history.where((value) => value['title'] != item['title']),
      ].take(12).toList();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('history', jsonEncode(_history));
  }

  Map<String, dynamic> _preset() => <String, dynamic>{
    'title': '${_mode.label}${_selected == null ? '' : ' · $_selectedTitle'}',
    'mode': _mode.index,
    'language': _language.index,
    'target': _selected?.filepath ?? '',
    'platform': _platform.text,
    'hour': _hour.text,
    'minute': _minute.text,
    'trainType': _trainType,
    'trainNumber': _trainNumber.text,
    'via': _via.text,
    'delayed': _delayed,
    'inTrain': _inTrainSequence,
    'pauseAfterStation': _pauseAfterStation,
  };

  void _applyPreset(Map<String, dynamic> preset) {
    final data = _data;
    if (data == null) return;
    final mode = int.tryParse('${preset['mode']}') ?? 0;
    final language = int.tryParse('${preset['language']}') ?? 0;
    final filepath = '${preset['target'] ?? ''}';
    final station = data.index.findByFile(filepath);
    setState(() {
      _mode = AnnouncementMode
          .values[mode.clamp(0, AnnouncementMode.values.length - 1)];
      _language = AnnouncementLanguage
          .values[language.clamp(0, AnnouncementLanguage.values.length - 1)];
      _selected = station == null
          ? null
          : StationSearchResult(
              title: station.name,
              subtitle: 'IBNR ${station.ibnr}',
              filepath: station.filepath,
              score: 0,
            );
      _platform.text = '${preset['platform'] ?? '1'}';
      _hour.text = '${preset['hour'] ?? '18'}';
      _minute.text = '${preset['minute'] ?? '59'}';
      _trainType = '${preset['trainType'] ?? _trainType}';
      _trainNumber.text = '${preset['trainNumber'] ?? ''}';
      _via.text = '${preset['via'] ?? '0'}';
      _delayed = preset['delayed'] == true;
      _inTrainSequence
        ..clear()
        ..addAll(
          (preset['inTrain'] as List? ?? const <Object>[])
              .map((value) => value.toString())
              .where(InTrainSequence.isKnown),
        );
      _pauseAfterStation = preset['pauseAfterStation'] != false;
    });
  }

  void _addInTrainBlock() {
    final id = InTrainSequence.idForLabel(_inTrainLabel);
    if (id == null) return;
    setState(() => _inTrainSequence.add(id));
  }

  void _addSelectedInTrainStation() {
    final clip = _data?.inTrainClipForFile(_selected?.filepath ?? '');
    if (clip == null) {
      _notice('Für $_selectedTitle gibt es keinen kuratierten Im-Zug-Clip.');
      return;
    }
    setState(
      () => _inTrainSequence.add(InTrainSequence.stationItem(clip.clip)),
    );
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchWorker?.dispose();
    _audio
      ..removeListener(_onAudioChanged)
      ..dispose();
    for (final controller in <TextEditingController>[
      _search,
      _platform,
      _hour,
      _minute,
      _trainNumber,
      _via,
      _withNumber,
      _withTarget,
      _splitFirst,
      _splitSecond,
      _continueNumber,
      _continueTarget,
      _continueHour,
      _continueMinute,
      _newPlatform,
      _onlyUntil,
      _plusStops,
      _minusStops,
      _connection2Number,
      _connection2Target,
      _connection2Platform,
      _dispatchPlatform,
      _passingPlatform,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ansagengenerator'),
      actions: <Widget>[
        IconButton(
          tooltip: 'Wiedergabe stoppen',
          icon: const Icon(Icons.stop_circle_outlined),
          onPressed: () => _audio.stop(),
        ),
      ],
    ),
    bottomNavigationBar: _playerDock(),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              _hero(),
              const SizedBox(height: 12),
              _targetCard(),
              const SizedBox(height: 12),
              _announcementCard(),
              const SizedBox(height: 12),
              _savedCard(),
              const SizedBox(height: 12),
              _dataCard(),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _hero() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.volume_up_outlined),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Ansagengenerator',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 3),
                Text('Ziel wählen · Ansage konfigurieren · abspielen'),
              ],
            ),
          ),
          _data == null
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Chip(label: Text('${_data!.stationCount} Ziele')),
        ],
      ),
    ),
  );

  Widget _targetCard() => _card(
    title: 'Zielbahnhof',
    subtitle: 'Bahnhof oder RIL-100-Code eingeben',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _search,
          enabled: _data != null && _searchWorker != null,
          decoration: InputDecoration(
            labelText: 'Suchen',
            hintText: 'z. B. KASZ, Köln Hbf oder Cottbus',
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _search.clear(),
                  ),
          ),
        ),
        if (_selected != null) ...<Widget>[
          const SizedBox(height: 10),
          Material(
            color: const Color(0xff0d2224),
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              leading: const Icon(
                Icons.location_on_outlined,
                color: Color(0xff10b981),
              ),
              title: Text(_selected!.title),
              subtitle: Text(_selected!.subtitle),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selected = null),
              ),
            ),
          ),
        ],
        if (_searchPending)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Suche läuft im Hintergrund …'),
              ],
            ),
          ),
        if (!_searchPending && _results.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          ..._results.map(
            (result) => ListTile(
              dense: true,
              leading: const Icon(Icons.train_outlined),
              title: Text(result.title),
              subtitle: Text(result.subtitle),
              onTap: () => _select(result),
            ),
          ),
        ],
        if (!_searchPending &&
            _search.text.trim().isNotEmpty &&
            _results.isEmpty &&
            _searchError == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Keine passenden Stationen oder RL100-Codes.'),
          ),
        if (_searchError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Stationssuche nicht verfügbar: $_searchError',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_loadError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Daten konnten nicht geladen werden: $_loadError',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
  );

  Widget _announcementCard() => _card(
    title: 'Ansage',
    subtitle: 'Alle Generator-Modi nutzen dieselbe geprüfte Playlistlogik.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _dropdown<AnnouncementMode>(
              label: 'Modus',
              value: _mode,
              items: AnnouncementMode.values,
              text: (value) => value.label,
              onChanged: (value) => setState(() => _mode = value!),
            ),
            _dropdown<AnnouncementLanguage>(
              label: 'Sprache',
              value: _language,
              items: AnnouncementLanguage.values,
              text: (value) => value.label,
              onChanged: (value) => setState(() => _language = value!),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_mode.requiresTrainDetails) _coreFields(),
        if (_mode == AnnouncementMode.entry ||
            _mode == AnnouncementMode.standing)
          _entryOptions(),
        if (_mode == AnnouncementMode.arrival) _arrivalOptions(),
        if (_mode == AnnouncementMode.information) _informationOptions(),
        if (_mode == AnnouncementMode.connection) _connectionOptions(),
        if (_mode == AnnouncementMode.dispatch)
          _field('Abfertigung Gleis', _dispatchPlatform, numeric: true),
        if (_mode == AnnouncementMode.passing)
          _field('Durchfahrt Gleis', _passingPlatform, numeric: true),
        if (_mode == AnnouncementMode.special)
          _dropdown<String>(
            label: 'Sonderansage',
            value: _special,
            items: _specialOptions,
            text: (value) => value,
            onChanged: (value) => setState(() => _special = value!),
          ),
        if (_mode == AnnouncementMode.inTrain) _inTrainEditor(),
      ],
    ),
  );

  Widget _coreFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const Text(
        'Zug, Ziel und Zeit',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          _field('Gleis', _platform, numeric: true),
          _field('Stunde', _hour, numeric: true),
          _field('Minute', _minute, numeric: true),
          _dropdown<String>(
            label: 'Zuggattung',
            value: _trainType,
            items: _data?.trainTypes ?? const <String>['ICE'],
            text: (value) => value,
            onChanged: (value) => setState(() => _trainType = value!),
          ),
          _field('Zugnummer', _trainNumber, numeric: true),
          _field('Via / über', _via),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('verspätet / ursprünglich'),
        value: _delayed,
        onChanged: (value) => setState(() => _delayed = value),
      ),
    ],
  );

  Widget _entryOptions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const Divider(),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ersatzzug'),
        value: _substitute,
        onChanged: (value) => setState(() => _substitute = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Mit-Zug hinzufügen'),
        value: _withTrain,
        onChanged: (value) => setState(() => _withTrain = value),
      ),
      if (_withTrain)
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _dropdown<String>(
              label: 'Mit-Zug Typ',
              value: _withTrainType,
              items: _data?.trainTypes ?? const ['RE'],
              text: (value) => value,
              onChanged: (value) => setState(() => _withTrainType = value!),
            ),
            _field('Mit-Zug Nummer', _withNumber, numeric: true),
            _field('Mit-Zug Ziel', _withTarget),
          ],
        ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Zugteilung'),
        value: _split,
        onChanged: (value) => setState(() => _split = value),
      ),
      if (_split)
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _field('Teilung Ziel 1', _splitFirst),
            _field('Teilung Ziel 2', _splitSecond),
            FilterChip(
              label: const Text('zweites Ziel ansagen'),
              selected: _splitSecondEnabled,
              onSelected: (value) =>
                  setState(() => _splitSecondEnabled = value),
            ),
          ],
        ),
    ],
  );

  Widget _arrivalOptions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const Divider(),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Bitte nicht einsteigen'),
        value: _noBoard,
        onChanged: (value) => setState(() => _noBoard = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Weiter als'),
        value: _continueEnabled,
        onChanged: (value) => setState(() => _continueEnabled = value),
      ),
      if (_continueEnabled)
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _dropdown<String>(
              label: 'Weiter Typ',
              value: _continueTrainType,
              items: _data?.trainTypes ?? const ['RE'],
              text: (value) => value,
              onChanged: (value) => setState(() => _continueTrainType = value!),
            ),
            _field('Weiter Nummer', _continueNumber, numeric: true),
            _field('Weiter Ziel', _continueTarget),
            _field('Weiter Stunde', _continueHour, numeric: true),
            _field('Weiter Minute', _continueMinute, numeric: true),
          ],
        ),
    ],
  );

  Widget _informationOptions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const Divider(),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          _dropdown<String>(
            label: 'Verspätung',
            value: _infoDelay,
            items: _delayOptions,
            text: (value) => value,
            onChanged: (value) => setState(() => _infoDelay = value!),
          ),
          _dropdown<String>(
            label: 'Grund',
            value: _infoReason,
            items: _reasonOptions,
            text: (value) => value,
            onChanged: (value) => setState(() => _infoReason = value!),
          ),
          _field('Neues Gleis', _newPlatform, numeric: true),
          _field('Heute nur bis', _onlyUntil),
          _field('Zusatzhalte (Komma)', _plusStops),
          _field('Entfallende Halte (Komma)', _minusStops),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Zugausfall'),
        value: _cancel,
        onChanged: (value) => setState(() => _cancel = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Entschuldigung'),
        value: _sorry,
        onChanged: (value) => setState(() => _sorry = value),
      ),
    ],
  );

  Widget _connectionOptions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const Divider(),
      const Text(
        'Anschluss 1 nutzt die Hauptfelder.',
        style: TextStyle(color: Color(0xffbbc7d8)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Anschluss 2'),
        value: _connection2Enabled,
        onChanged: (value) => setState(() => _connection2Enabled = value),
      ),
      if (_connection2Enabled)
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _dropdown<String>(
              label: 'Anschluss 2 Typ',
              value: _connection2TrainType,
              items: _data?.trainTypes ?? const ['RE'],
              text: (value) => value,
              onChanged: (value) =>
                  setState(() => _connection2TrainType = value!),
            ),
            _field('Anschluss 2 Nummer', _connection2Number, numeric: true),
            _field('Anschluss 2 Ziel', _connection2Target),
            _field('Anschluss 2 Gleis', _connection2Platform, numeric: true),
          ],
        ),
    ],
  );

  Widget _inTrainEditor() {
    final clipAvailable =
        _data?.inTrainClipForFile(_selected?.filepath ?? '') != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          'Im Zug · Wiedergabeliste',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Bausteine und kuratierte Stationen dürfen beliebig sortiert und wiederholt werden.',
          style: TextStyle(color: Color(0xffbbc7d8)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _dropdown<String>(
              label: 'Baustein',
              value: _inTrainLabel,
              items: InTrainSequence.labels,
              text: (value) => value,
              onChanged: (value) => setState(() => _inTrainLabel = value!),
            ),
            FilledButton.icon(
              onPressed: _addInTrainBlock,
              icon: const Icon(Icons.add),
              label: const Text('Baustein'),
            ),
            OutlinedButton.icon(
              onPressed: clipAvailable ? _addSelectedInTrainStation : null,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Ausgewählte Station'),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Nach jedem Stationsnamen auf „Nächster Halt“ warten',
          ),
          value: _pauseAfterStation,
          onChanged: (value) => setState(() => _pauseAfterStation = value),
        ),
        if (_inTrainSequence.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Noch keine Bausteine.',
              style: TextStyle(color: Color(0xff9aa9bf)),
            ),
          ),
        ...List<Widget>.generate(_inTrainSequence.length, (index) {
          final item = _inTrainSequence[index];
          return Card(
            color: const Color(0xff161b29),
            child: ListTile(
              leading: Text(
                '${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              title: Text(InTrainSequence.labelForId(item)),
              subtitle: Text(item),
              trailing: Wrap(
                spacing: 0,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: index == 0
                        ? null
                        : () => setState(() {
                            final value = _inTrainSequence.removeAt(index);
                            _inTrainSequence.insert(index - 1, value);
                          }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: index + 1 == _inTrainSequence.length
                        ? null
                        : () => setState(() {
                            final value = _inTrainSequence.removeAt(index);
                            _inTrainSequence.insert(index + 1, value);
                          }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        setState(() => _inTrainSequence.removeAt(index)),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _savedCard() => _card(
    title: 'Vorlagen & Verlauf',
    subtitle: 'Vorlagen bleiben lokal auf diesem Gerät.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            FilledButton.icon(
              onPressed: _storeFavorite,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Vorlage speichern'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _history.isEmpty
                  ? null
                  : () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('history');
                      if (mounted) {
                        setState(() => _history = <Map<String, dynamic>>[]);
                      }
                    },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Verlauf löschen'),
            ),
          ],
        ),
        if (_favorites.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          const Text(
            'Favoriten',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          ..._favorites
              .take(3)
              .map(
                (item) => ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: Text('${item['title']}'),
                  onTap: () => _applyPreset(item),
                ),
              ),
        ],
        if (_history.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          const Text(
            'Zuletzt verwendet',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          ..._history
              .take(3)
              .map(
                (item) => ListTile(
                  leading: const Icon(Icons.history),
                  title: Text('${item['title']}'),
                  onTap: () => _applyPreset(item),
                ),
              ),
        ],
      ],
    ),
  );

  Widget _dataCard() => _card(
    title: 'App & Daten',
    subtitle: _data == null
        ? 'Lokale Daten werden geladen …'
        : '${_data!.rilCount} RL100-Einträge · ${_data!.inTrainByFile.length} Im-Zug-Stationen',
    child: const Text(
      'Android nutzt die vollständige Opus-Bibliothek direkt aus dem eingebetteten ZIP64-Asset und kopiert nur benötigte Clips kurz in den Cache. '
      'Die Flutter-Zielprojekte für iOS, Web und Desktop enthalten dieselbe UI und Generatorlogik; für die komplette historische Offline-Bibliothek benötigen diese Plattformen einen gleichartigen lokalen Datenpaket-Adapter.',
      style: TextStyle(color: Color(0xffbbc7d8)),
    ),
  );

  Widget _playerDock() => SafeArea(
    child: Material(
      color: const Color(0xff10141f),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _audio.status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _audio.state.continuesQueuedPlayback
                      ? _audio.resume
                      : _play,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    _audio.state.continuesQueuedPlayback
                        ? 'Nächster Halt'
                        : 'Abspielen',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: switch (_audio.state) {
                    PlaybackState.playing => _audio.pause,
                    PlaybackState.paused => _audio.resume,
                    _ => null,
                  },
                  icon: Icon(
                    _audio.state == PlaybackState.paused
                        ? Icons.play_arrow
                        : Icons.pause,
                  ),
                  label: Text(
                    _audio.state == PlaybackState.paused ? 'Weiter' : 'Pause',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _audio.stop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
                TextButton.icon(
                  onPressed: _export,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('WAV exportieren'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: Color(0xffbbc7d8))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller, {
    bool numeric = false,
  }) => SizedBox(
    width: 210,
    child: TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) text,
    required ValueChanged<T?> onChanged,
  }) => SizedBox(
    width: 260,
    child: DropdownButtonFormField<T>(
      key: ValueKey<Object>('$label-$value'),
      initialValue: items.contains(value) ? value : items.first,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(text(item), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    ),
  );
}
