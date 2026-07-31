import 'in_train_sequence.dart';

enum AnnouncementMode {
  entry,
  arrival,
  standing,
  information,
  connection,
  dispatch,
  passing,
  special,
  inTrain,
}

enum AnnouncementLanguage { german, english, french }

extension AnnouncementModeLabel on AnnouncementMode {
  String get label => switch (this) {
    AnnouncementMode.entry => 'Einfahrt',
    AnnouncementMode.arrival => 'Ankunft',
    AnnouncementMode.standing => 'Steht bereit',
    AnnouncementMode.information => 'Information',
    AnnouncementMode.connection => 'Anschluss',
    AnnouncementMode.dispatch => 'Abfertigung',
    AnnouncementMode.passing => 'Durchfahrt',
    AnnouncementMode.special => 'Sonderansage',
    AnnouncementMode.inTrain => 'Im Zug',
  };

  /// Matches the native form's [trainLike] modes. Dispatch and passing are
  /// standalone platform announcements; their playlists do not use train,
  /// target, via or time fields.
  bool get requiresTrainDetails => switch (this) {
    AnnouncementMode.entry ||
    AnnouncementMode.arrival ||
    AnnouncementMode.standing ||
    AnnouncementMode.information ||
    AnnouncementMode.connection => true,
    AnnouncementMode.dispatch ||
    AnnouncementMode.passing ||
    AnnouncementMode.special ||
    AnnouncementMode.inTrain => false,
  };
}

extension AnnouncementLanguageLabel on AnnouncementLanguage {
  String get label => switch (this) {
    AnnouncementLanguage.german => 'Deutsch',
    AnnouncementLanguage.english => 'Englisch',
    AnnouncementLanguage.french => 'Französisch (nur Sonderansage)',
  };
}

class TrainDraft {
  const TrainDraft({
    this.trainType = 'ICE',
    this.numbers = const <String>[],
    this.target = '',
    this.via = '0',
  });

  final String trainType;
  final List<String> numbers;
  final String target;
  final String via;
}

class ConnectionDraft extends TrainDraft {
  const ConnectionDraft({
    super.trainType,
    super.numbers,
    super.target,
    super.via,
    this.platform = '1',
    this.hour = '18',
    this.minute = '59',
    this.enabled = true,
  });

  final String platform;
  final String hour;
  final String minute;
  final bool enabled;
}

/// All mutable form values in a serialisable, framework-free model.
class AnnouncementDraft {
  const AnnouncementDraft({
    this.mode = AnnouncementMode.entry,
    this.language = AnnouncementLanguage.german,
    this.targetFile = '',
    this.platform = '1',
    this.hour = '18',
    this.minute = '59',
    this.trainType = 'ICE',
    this.trainNumbers = const <String>[],
    this.via = '0',
    this.substituteTrain = false,
    this.delayed = false,
    this.withTrains = const <TrainDraft>[],
    this.splitEnabled = false,
    this.splitTwoEnabled = false,
    this.splitFirstTarget = '',
    this.splitSecondTarget = '',
    this.noBoard = false,
    this.continueTrain = const TrainDraft(),
    this.continueEnabled = false,
    this.continueHour = '18',
    this.continueMinute = '59',
    this.infoDelay = '0',
    this.infoReason = '0',
    this.infoNewPlatform = '0',
    this.infoOnlyUntil = '0',
    this.haltPlus = const <String>[],
    this.haltMinus = const <String>[],
    this.cancelTrain = false,
    this.sorry = false,
    this.connections = const <ConnectionDraft>[],
    this.dispatchPlatform = '1',
    this.passingPlatform = '1',
    this.specialCode = '001.wav',
    this.inTrainSequence = const <String>[],
    this.selectedInTrainStationClip = '',
  });

  final AnnouncementMode mode;
  final AnnouncementLanguage language;
  final String targetFile;
  final String platform;
  final String hour;
  final String minute;
  final String trainType;
  final List<String> trainNumbers;
  final String via;
  final bool substituteTrain;
  final bool delayed;
  final List<TrainDraft> withTrains;
  final bool splitEnabled;
  final bool splitTwoEnabled;
  final String splitFirstTarget;
  final String splitSecondTarget;
  final bool noBoard;
  final TrainDraft continueTrain;
  final bool continueEnabled;
  final String continueHour;
  final String continueMinute;
  final String infoDelay;
  final String infoReason;
  final String infoNewPlatform;
  final String infoOnlyUntil;
  final List<String> haltPlus;
  final List<String> haltMinus;
  final bool cancelTrain;
  final bool sorry;
  final List<ConnectionDraft> connections;
  final String dispatchPlatform;
  final String passingPlatform;
  final String specialCode;
  final List<String> inTrainSequence;
  final String selectedInTrainStationClip;
}

/// Deterministic port of the native playlist compiler. Values are original
/// relative WAV paths; the platform audio adapter maps those to Opus at runtime.
class AnnouncementBuilder {
  AnnouncementBuilder({required this.draft, this.stationFileResolver});

  final AnnouncementDraft draft;
  final String Function(String raw, String fallback)? stationFileResolver;

  List<String> build() => switch (draft.mode) {
    AnnouncementMode.entry => _buildEntry(),
    AnnouncementMode.arrival => _buildArrival(),
    AnnouncementMode.standing => _buildStanding(),
    AnnouncementMode.information => _buildInformation(),
    AnnouncementMode.connection => _buildConnections(),
    AnnouncementMode.dispatch => _buildDispatch(),
    AnnouncementMode.passing => _buildPassing(),
    AnnouncementMode.special => _buildSpecial(),
    AnnouncementMode.inTrain => InTrainSequence.toAssetPlaylist(
      draft.inTrainSequence,
      selectedStationClip: draft.selectedInTrainStationClip,
    ),
  };

  String get _lang => switch (draft.language) {
    AnnouncementLanguage.german => 'dt',
    AnnouncementLanguage.english => 'en',
    AnnouncementLanguage.french =>
      draft.mode == AnnouncementMode.special ? 'fr' : 'dt',
  };

  String get _target => _station(draft.targetFile, '8010324.wav');

  List<String> _buildEntry() {
    final out = <String>['gong/513/513_2.wav'];
    _module31(out, '016', '023', '042');
    _number(out, _int(draft.platform, 1), high: true);
    _module31(out, '012', '022', '042');
    if (draft.substituteTrain) _module31(out, '008', '025', '042');
    _train(out, draft.trainType, draft.trainNumbers);
    _nach(out);
    _targetWithVia(out, _target, draft.via, viaVariantOne: true);
    for (final train in draft.withTrains) {
      _withTrain(out, train);
    }
    _module31(
      out,
      draft.delayed ? '002' : '001',
      draft.delayed ? '027' : '008',
      '042',
    );
    _time(out, draft.hour, draft.minute);
    _split(out);
    _caution(out);
    return out;
  }

  List<String> _buildArrival() {
    final out = <String>['gong/513/513_2.wav'];
    _module31(out, '016', '023', '042');
    _number(out, _int(draft.platform, 1), high: true);
    _module31(out, '012', '022', '042');
    _train(out, draft.trainType, draft.trainNumbers);
    _von(out);
    out.add('$_lang/ziele/variante2/tief/$_target');
    if (draft.continueEnabled) {
      _module31(out, '040', '006', '042');
      _train(out, draft.continueTrain.trainType, draft.continueTrain.numbers);
      _nach(out);
      _targetWithVia(
        out,
        _station(draft.continueTrain.target, _target),
        draft.continueTrain.via,
        viaVariantOne: false,
      );
      _departure(out, draft.continueHour, draft.continueMinute);
      _caution(out);
    } else {
      if (draft.delayed) {
        _module31(out, '005', '026', '042');
      } else {
        _module(out, '0004', '0001', '0004');
      }
      _time(out, draft.hour, draft.minute);
      if (draft.noBoard) _module31(out, '007', '024', '042');
      _caution(out);
    }
    return out;
  }

  List<String> _buildStanding() {
    final out = <String>['gong/513/513_2.wav'];
    _module31(out, '016', '023', '042');
    _number(out, _int(draft.platform, 1), high: true);
    _module31(out, '034', '000', '042');
    _train(out, draft.trainType, draft.trainNumbers);
    _nach(out);
    _targetWithVia(out, _target, draft.via, viaVariantOne: true);
    for (final train in draft.withTrains) {
      _withTrain(out, train);
    }
    _departure(out, draft.hour, draft.minute);
    _split(out);
    return out;
  }

  List<String> _buildInformation() {
    final out = <String>['gong/513/513_2.wav'];
    _module31(out, '030', '020', '042');
    _train(out, draft.trainType, draft.trainNumbers);
    _nach(out);
    _targetWithVia(out, _target, draft.via, viaVariantOne: true);
    for (final train in draft.withTrains) {
      _withTrain(out, train);
    }
    _departure(out, draft.hour, draft.minute);
    final delay = _optionFile(draft.infoDelay);
    if (_hasFile(delay)) out.add('$_lang/zeiten/verspaetung_heute/$delay');
    final newPlatform = _int(draft.infoNewPlatform, 0);
    if (newPlatform > 0) {
      _module(out, '0323', '0073', '042');
      _number(out, newPlatform, high: true);
    }
    final onlyUntil = _station(draft.infoOnlyUntil, '');
    if (_hasFile(onlyUntil)) {
      _module31(out, '021', '011', '042');
      out.add('$_lang/ziele/variante2/tief/$onlyUntil');
      _module31(out, '044', '021', '042');
    }
    _halts(out, draft.haltPlus, plus: true);
    _halts(out, draft.haltMinus, plus: false);
    if (draft.cancelTrain) _module31(out, '014', '015', '042');
    final reason = _optionFile(draft.infoReason);
    if (_hasFile(reason)) out.add('$_lang/gruende/grund_dafuer/$reason');
    if (draft.sorry) _module31(out, '042', '036', '042');
    return out;
  }

  List<String> _buildConnections() {
    final base = ConnectionDraft(
      trainType: draft.trainType,
      numbers: draft.trainNumbers,
      target: _target,
      via: draft.via,
      platform: draft.platform,
      hour: draft.hour,
      minute: draft.minute,
    );
    final connections = draft.connections.isEmpty
        ? <ConnectionDraft>[base]
        : draft.connections;
    final enabled = connections
        .where((connection) => connection.enabled)
        .toList();
    final out = <String>['gong/513/513_2.wav'];
    for (var index = 0; index < enabled.length; index++) {
      final connection = enabled[index];
      if (index == 0) {
        _module31(out, '026', '040', '042');
      } else {
        _module31(out, '036', '002', '042');
      }
      _train(out, connection.trainType, connection.numbers);
      _nach(out);
      _targetWithVia(
        out,
        _station(connection.target, _target),
        connection.via,
        viaVariantOne: true,
      );
      _departure(out, connection.hour, connection.minute);
      _module31(out, '039', '014', '042');
      _number(out, _int(connection.platform, 1), high: false);
    }
    return out;
  }

  List<String> _buildDispatch() {
    final out = <String>['gong/klangtyp_konvent/ceg-gongs2.wav'];
    _module(out, '0048', '0021', '0048');
    _number(out, _int(draft.dispatchPlatform, 1), high: true);
    _module(out, '0011', '0029', '0029');
    return out;
  }

  List<String> _buildPassing() {
    final platform = _int(draft.passingPlatform, 1);
    final out = <String>['gong/513/513_2.wav'];
    _module(out, '0153', '040', '0153');
    _number(out, platform, high: true);
    _module(out, '0155', '040', '0155');
    _number(out, platform, high: true);
    _module(out, '0159', '040', '0159');
    return out;
  }

  List<String> _buildSpecial() => <String>[
    'gong/513/513_2.wav',
    '$_lang/nza/${_optionFile(draft.specialCode)}',
  ];

  void _halts(List<String> out, List<String> raw, {required bool plus}) {
    final stops = raw
        .map((value) => _station(value, ''))
        .where(_hasFile)
        .take(3)
        .toList();
    if (stops.isEmpty) return;
    _module31(out, plus ? '020' : '022', plus ? '037' : '038', '042');
    if (stops.length == 1) {
      out.add('$_lang/ziele/variante2/tief/${stops.single}');
    } else if (stops.length == 2) {
      out.add('$_lang/ziele/variante2/hoch/${stops[0]}');
      _module31(out, '036', '002', '042');
      out.add('$_lang/ziele/variante2/tief/${stops[1]}');
    } else {
      out.add('$_lang/ziele/variante2/hoch/${stops[0]}');
      out.add('$_lang/ziele/variante2/hoch/${stops[1]}');
      _module31(out, '036', '002', '042');
      out.add('$_lang/ziele/variante2/${plus ? 'tief' : 'hoch'}/${stops[2]}');
    }
  }

  void _split(List<String> out) {
    if (!draft.splitEnabled) return;
    final first = _station(draft.splitFirstTarget, _target);
    final second = _station(draft.splitSecondTarget, '');
    _module31(out, '045', '030', '042');
    if (draft.splitTwoEnabled && _hasFile(second)) {
      out.add('$_lang/ziele/variante2/hoch/$first');
      _module31(out, '036', '002', '042');
      out.add('$_lang/ziele/variante2/tief/$second');
    } else {
      out.add('$_lang/ziele/variante2/tief/$first');
    }
    _module31(out, '015', '000', '042');
  }

  void _withTrain(List<String> out, TrainDraft train) {
    _module31(out, '031', '039', '042');
    _train(out, train.trainType, train.numbers);
    _nach(out);
    _targetWithVia(
      out,
      _station(train.target, _target),
      train.via,
      viaVariantOne: true,
    );
  }

  void _targetWithVia(
    List<String> out,
    String target,
    String rawVia, {
    required bool viaVariantOne,
  }) {
    final via = _station(rawVia, '');
    if (_hasFile(via)) {
      out.add('$_lang/ziele/variante2/hoch/$target');
      _module31(out, '035', '035', '042');
      out.add(
        '$_lang/ziele/${viaVariantOne ? 'variante1' : 'variante2'}/tief/$via',
      );
    } else {
      out.add('$_lang/ziele/variante2/tief/$target');
    }
  }

  void _train(List<String> out, String type, List<String> numbers) {
    final safeType = type.trim().isEmpty ? 'ICE' : type.trim().toLowerCase();
    out.add('$_lang/zuggattungen/hoch/$safeType.wav');
    for (final number in numbers) {
      _trainNumber(out, number);
    }
  }

  void _trainNumber(List<String> out, String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty || _isSentinel(raw)) return;
    if (digits.length <= 3 && !digits.startsWith('0')) {
      _number(out, _int(digits, 0), high: true);
      return;
    }

    // Operational train-number notation groups four digits as 2–2 and five
    // digits as 2–1–2: 1035 → "10 35", 10354 → "10 3 54". Leading-zero
    // groups remain digit-wise so no significant zero is dropped.
    final groups = switch (digits.length) {
      4 => <String>[digits.substring(0, 2), digits.substring(2, 4)],
      5 => <String>[
        digits.substring(0, 2),
        digits.substring(2, 3),
        digits.substring(3, 5),
      ],
      _ => digits.split('').take(5).toList(growable: false),
    };
    for (final group in groups) {
      if (group.startsWith('0')) {
        for (final digit in group.split('')) {
          out.add('$_lang/gleise_zahlen/hoch/$digit.wav');
        }
      } else {
        _number(out, _int(group, 0), high: true);
      }
    }
  }

  void _number(List<String> out, int number, {required bool high}) {
    if (number < 0) return;
    final tone = high ? 'hoch' : 'tief';
    if (number < 100 || number % 100 == 0) {
      out.add('$_lang/gleise_zahlen/$tone/$number.wav');
    } else if (number < 1000) {
      final rest = number % 100;
      out.add('$_lang/gleise_zahlen/$tone/${number - rest}_.wav');
      if (rest > 0) out.add('$_lang/gleise_zahlen/$tone/$rest.wav');
    } else {
      for (final digit in '$number'.split('').take(5)) {
        out.add('$_lang/gleise_zahlen/$tone/$digit.wav');
      }
    }
  }

  void _departure(List<String> out, String hour, String minute) {
    _module31(out, '001', '008', '042');
    _time(out, hour, minute);
  }

  void _time(List<String> out, String hour, String minute) {
    out.add('$_lang/zeiten/stunden/hoch/${_two(_int(hour, 18))}.wav');
    out.add('$_lang/zeiten/minuten/tief/${_two(_int(minute, 59))}.wav');
  }

  void _nach(List<String> out) => _module(out, '0054', '0049', '0049');
  void _von(List<String> out) => _module(out, '0065', '0012', '0012');
  void _caution(List<String> out) => _module31(out, '046', '005', '042');

  void _module31(List<String> out, String dt, String en, String fr) => out.add(
    '$_lang/module_3_1/${_lang == 'dt'
        ? dt
        : _lang == 'en'
        ? en
        : fr}.wav',
  );

  void _module(List<String> out, String dt, String en, String fr) => out.add(
    '$_lang/module/${_lang == 'dt'
        ? dt
        : _lang == 'en'
        ? en
        : fr}.wav',
  );

  String _station(String raw, String fallback) {
    if (_isSentinel(raw)) return '';
    final resolved =
        stationFileResolver?.call(raw, fallback) ??
        _referenceFile(raw, fallback);
    return _isSentinel(resolved) ? '' : resolved;
  }

  static String _referenceFile(String raw, String fallback) {
    final value = raw.trim().replaceAll('\\', '/');
    if (value.isEmpty) return fallback;
    final tail = value.substring(value.lastIndexOf('/') + 1);
    if (tail.endsWith('.wav')) return tail;
    if (RegExp(r'^\d{4,8}$').hasMatch(tail)) return '$tail.wav';
    return fallback;
  }

  static bool _isSentinel(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ||
        normalized == '0' ||
        normalized == '-' ||
        normalized == '9999';
  }

  static bool _hasFile(String value) => !_isSentinel(value);

  static int _int(String value, int fallback) =>
      int.tryParse(value.trim()) ?? fallback;
  static String _two(int value) => value < 10 ? '0$value' : '$value';

  static String _optionFile(String value) {
    final match = RegExp(r'(\d{3,4}\.wav)').firstMatch(value);
    return match?.group(1) ?? (value.endsWith('.wav') ? value : '');
  }
}
