import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'lang.dart';
import 'motor.dart';
import 'plan_program.dart';

// ---------------------------------------------------------------------------
// Catalog
// ---------------------------------------------------------------------------

class Muscle {
  Muscle(this.region, String name, this.latin, String detail, {this.ref})
      : _name = name,
        _detail = detail;
  final String region, latin;
  final String _name, _detail;

  /// (exercise id, group, index) for the English overlay.
  final (String, String, int)? ref;
  factory Muscle.fromJson(Map j, [(String, String, int)? ref]) => Muscle(j['bolge'] ?? '', j['ad'] ?? '', j['latince'] ?? '', j['detay'] ?? '', ref: ref);

  Map? get _x {
    final r = ref;
    if (r == null) return null;
    final l = (Lang.exercise(r.$1)?['kaslar'] as Map?)?[r.$2];
    return l is List && r.$3 < l.length && l[r.$3] is Map ? l[r.$3] as Map : null;
  }

  String get name => Lang.en ? pick(_name, _x?['ad'] ?? Lang.muscle(_name)) : _name;
  String get detail => Lang.en ? pick(_detail, _x?['detay']) : _detail;
}

class CmSpec {
  CmSpec(String label, this.min, this.max, this.first) : _label = label;
  final String _label;
  String get label => tr(_label);
  final int min, max, first;
}

class Exercise {
  Exercise.fromJson(Map j)
      : id = j['id'],
        _name = j['ad'],
        en = j['en'] ?? '',
        inProgram = j['program'] == true,
        kind = j['kayit'],
        cm = j['cm'] == null ? null : CmSpec(j['cm']['etiket'] ?? 'cm', (j['cm']['min'] as num).toInt(), (j['cm']['max'] as num).toInt(), (j['cm']['ilk'] as num).toInt()),
        difficulty = (j['zorluk'] as num?)?.toInt() ?? 2,
        _equipment = List<String>.from(j['ekipman'] ?? const []),
        _purpose = j['amac'] ?? '',
        _cues = List<String>.from(j['ipuclari'] ?? const []),
        _mistakes = List<String>.from(j['hatalar'] ?? const []),
        _knee = j['diz'],
        primary = [for (final (i, m) in ((j['kaslar']?['ana'] ?? const []) as List).indexed) Muscle.fromJson(m, (j['id'], 'ana', i))],
        secondary = [for (final (i, m) in ((j['kaslar']?['yardimci'] ?? const []) as List).indexed) Muscle.fromJson(m, (j['id'], 'yardimci', i))],
        stabilizers = [for (final (i, m) in ((j['kaslar']?['sabitleyici'] ?? const []) as List).indexed) Muscle.fromJson(m, (j['id'], 'sabitleyici', i))],
        altGeneral = j['alternatif']?['genel'],
        altEasier = j['alternatif']?['kolay'],
        altHarder = j['alternatif']?['zor'],
        exdb = j['medya']?['exdb'],
        figure = j['medya']?['figur'],
        rest = (j['mola'] as num?)?.toInt() ?? 90;

  final String id, en;
  final String _name;
  final bool inProgram;
  final String? kind;
  final CmSpec? cm;
  final int difficulty;
  final List<String> _equipment, _cues, _mistakes;
  final String _purpose;
  final String? _knee;

  // Text fields read the English overlay when English is on; Turkish otherwise.
  Map? get _x => Lang.en ? Lang.exercise(id) : null;
  String get name => Lang.en ? pick(_name, _x?['ad'] ?? (en.isEmpty ? null : en)) : _name;
  String get purpose => Lang.en ? pick(_purpose, _x?['amac']) : _purpose;
  List<String> get cues => Lang.en ? pickList(_cues, _x?['ipuclari']) : _cues;
  List<String> get mistakes => Lang.en ? pickList(_mistakes, _x?['hatalar']) : _mistakes;
  String? get knee => _knee == null ? null : (Lang.en ? pick(_knee, _x?['diz']) : _knee);
  List<String> get equipment => !Lang.en ? _equipment : (_x?['ekipman'] is List ? pickList(_equipment, _x?['ekipman']) : [for (final q in _equipment) Lang.equipment(q) ?? q]);
  final List<Muscle> primary, secondary, stabilizers;
  final String? altGeneral, altEasier, altHarder;
  final String? exdb, figure;
  final int rest;

  bool get logs => kind != null;
  LogType? get type => kind == null ? null : LogType.of(kind!, this);
}

/// How a movement is recorded. Each saved record is one set.
class Field {
  const Field(this.key, this.label, this.min, this.max, {this.step = 1, this.fraction = false, this.optional = false, this.unit = ''});
  final String key, label, unit;
  final double min, max, step;
  final bool fraction, optional;
}

class LogType {
  LogType._(this.kind, this.fields, this.best, this.text, this.y, this.unit);
  final String kind;
  final List<Field> fields;
  final List<num> Function(Map r) best;
  final String Function(Map r) text;
  final num Function(Map r) y;
  final String unit;

  static LogType of(String kind, Exercise e) {
    switch (kind) {
      case 'kg':
        return LogType._(kind, const [Field('kg', 'Ağırlık', 0, 300, fraction: true, unit: 'kg'), Field('r', 'Tekrar', 1, 60)], (r) => [n(r['kg']), n(r['r'])], (r) => '${fmtKg(r['kg'])} kg × ${n(r['r'])}', (r) => n(r['kg']), 'kg');
      case 'bw':
        return LogType._(kind, const [Field('r', 'Tekrar', 1, 60), Field('kg', 'Ek ağırlık', 0, 100, fraction: true, optional: true, unit: 'kg')], (r) => [n(r['kg']), n(r['r'])],
            (r) => n(r['kg']) > 0 ? '+${fmtKg(r['kg'])} kg × ${n(r['r'])}' : trf('{0} tekrar', [n(r['r'])]), (r) => n(r['r']), tr('tekrar'));
      case 'bw0':
        return LogType._(kind, const [Field('r', 'Tekrar', 1, 60)], (r) => [n(r['r'])], (r) => trf('{0} tekrar', [n(r['r'])]), (r) => n(r['r']), tr('tekrar'));
      case 'sn':
        return LogType._(kind, const [Field('sn', 'Süre', 5, 300, step: 5, unit: 'sn')], (r) => [n(r['sn'])], (r) => '${n(r['sn'])} ${tr('sn')}', (r) => n(r['sn']), tr('sn'));
      case 'm':
        return LogType._(kind, const [Field('kg', 'Tek el', 0, 150, fraction: true, unit: 'kg'), Field('m', 'Mesafe', 5, 200, step: 5, unit: 'm')], (r) => [n(r['kg']), n(r['m'])],
            (r) => '${fmtKg(r['kg'])} kg × ${n(r['m'])} m', (r) => n(r['kg']), 'kg');
      default: // cm
        final c = e.cm ?? CmSpec('cm', 1, 400, 100);
        return LogType._(kind, [Field('cm', c.label, c.min.toDouble(), c.max.toDouble()), const Field('r', 'Tekrar', 1, 20, optional: true)], (r) => [n(r['cm'])],
            (r) => '${n(r['cm'])} cm', (r) => n(r['cm']), 'cm');
    }
  }

  bool better(Map a, Map b) {
    final x = best(a), y = best(b);
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) return x[i] > y[i];
    }
    return false;
  }

  Map? bestOf(Iterable<Map> recs) {
    Map? b;
    for (final r in recs) {
      if (b == null || better(r, b)) b = r;
    }
    return b;
  }

  /// "60 kg × 8 · 3 set" for legacy whole-exercise records, plain text for sets.
  String full(Map r) => text(r) + ((r['s'] ?? 1) > 1 ? trf(' · {0} set', [r['s']]) : '');
}

num n(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);

String fmtKg(dynamic v) {
  final x = n(v).toDouble();
  if (x == x.roundToDouble()) return x.toInt().toString();
  var s = x.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return s.replaceAll('.', ',');
}

// ---------------------------------------------------------------------------
// Program
// ---------------------------------------------------------------------------

class Phase {
  Phase(this.weeks, String name, this.rir, String text)
      : _name = name,
        _text = text;
  final String weeks, rir;
  final String _name, _text;
  String get name => Lang.en ? pick(_name, Lang.phase(weeks)?['name']) : _name;
  String get text => Lang.en ? pick(_text, Lang.phase(weeks)?['txt']) : _text;
}

class Slot {
  Slot.fromJson(Map j, [this.dayId = ''])
      : id = j['id'],
        no = j['no'],
        _name = j['n'],
        dose = j['d'],
        _cue = j['cue'] ?? '',
        _alt = j['alt'],
        tags = List<String>.from(j['g'] ?? const []),
        superset = j['ss'] == true,
        isNew = j['isNew'] == true;

  final String id, no, dayId;
  final String _name, _cue;
  final dynamic dose; // String or List<String?> indexed by phase (Turkish)
  final String? _alt;

  Map? get _x => Lang.en ? Lang.slot(dayId, '$no:$id') : null;
  String get name => Lang.en ? pick(_name, _x?['n']) : _name;
  String get cue => Lang.en ? pick(_cue, _x?['cue']) : _cue;
  String? get alt => _alt == null ? null : (Lang.en ? pick(_alt, _x?['alt']) : _alt);
  final List<String> tags;
  final bool superset, isNew;

  String? doseFor(int phase) {
    final d = dose is String ? dose as String : (dose as List)[phase] as String?;
    if (d == null || !Lang.en) return d;
    final e = _x?['d'];
    final v = e is List ? (phase < e.length ? e[phase] : null) : e;
    return pick(d, v);
  }

  /// Number without the day letter: A2 → 2, A5a → 5a. Days are named by weekday.
  String get shortNo => no.replaceFirst(RegExp(r'^[ABC]'), '');
}

class Day {
  Day.fromJson(Map j)
      : id = j['id'],
        _tag = j['tag'],
        _title = j['title'],
        _sub = j['sub'],
        slots = [for (final i in j['items']) Slot.fromJson(i, j['id'])];
  final String id;
  final String _tag, _title, _sub;
  String get tag => Lang.en ? pick(_tag, Lang.day(id)?['tag']) : _tag;
  String get title => Lang.en ? pick(_title, Lang.day(id)?['title']) : _title;
  String get sub => Lang.en ? pick(_sub, Lang.day(id)?['sub']) : _sub;
  final List<Slot> slots;
  bool get isMain => id.startsWith('gun');
  String get letter => id.startsWith('gun') ? id.substring(3) : '';
}

class ProgramData {
  ProgramData(this.phases, this.weekPhase, this.days, Map<String, String> tags) : _tags = tags;
  final List<Phase> phases;
  final List<int> weekPhase;
  final List<Day> days;
  final Map<String, String> _tags;
  Map<String, String> get tags => Lang.en ? {..._tags, ...Lang.tags} : _tags;

  Day day(String id) => days.firstWhere((d) => d.id == id);
  int phaseOf(int week) => weekPhase[(week - 1).clamp(0, 11)];
}

// ---------------------------------------------------------------------------
// App state
// ---------------------------------------------------------------------------

String isoDay([DateTime? d]) {
  d ??= DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

DateTime parseDay(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

const aylar = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
const gunler = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
const gunKisa = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
String shortDate(String iso) {
  final d = parseDay(iso);
  return '${d.day} ${tr(aylar[d.month - 1])}';
}

String uid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36) + math.Random().nextInt(1 << 20).toRadixString(36);

/// Old lesson keys whose records belong to a different movement now.
const legacyKeyMap = {'chinup': 'latpull'};

class Store extends ChangeNotifier {
  Store._(this.catalog, this._fixed, this._file, this._data) {
    _buildPlan();
    // Day titles and doses of the generated plan are built in the interface language.
    Lang.current.addListener(() {
      _buildPlan();
      notifyListeners();
    });
  }

  final Map<String, Exercise> catalog;
  final ProgramData _fixed;
  final File _file;
  final Map<String, dynamic> _data;

  /// The public build has no fixed program: everyone starts from the set-up flow.
  static const genel = true;

  // ---- generated plan (set-up flow) ----------------------------------------

  ProgramData? _generated;

  /// Saved set-up answers ([Girdi] as JSON) and the plan built from them.
  Map<String, dynamic>? get profile => (_data['profil'] as Map?)?.cast<String, dynamic>();
  Map<String, dynamic>? get plan => (_data['plan'] as Map?)?.cast<String, dynamic>();

  /// The generated plan is in use (the owner can switch back to the fixed one).
  bool get usesPlan => _generated != null;
  bool get hasPlan => plan != null;
  bool get needsSetup => genel && !hasPlan;
  bool get acceptedNotice => _data['onay'] != null;

  ProgramData get program => _generated ?? _fixed;

  void _buildPlan() {
    final p = plan;
    _generated = (p != null && _data['planKullan'] != false) ? planToProgram(p) : null;
  }

  void acceptNotice() {
    _data['onay'] = DateTime.now().toIso8601String();
    _changed();
  }

  /// Saves the set-up answers and the plan; the plan starts this week.
  void savePlan(Girdi girdi, Plan p, Map<String, dynamic> extra) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    _data['profil'] = {...girdi.toJson(), ...extra};
    _data['plan'] = {...p.toJson(), 'baslangic': isoDay(monday), 'olusturma': now.toIso8601String(), 'ay': girdi.ay};
    _data['planKullan'] = true;
    _data.remove('secilen');
    _buildPlan();
    _changed();
  }

  void usePlan(bool on) {
    _data['planKullan'] = on;
    _data.remove('secilen');
    _buildPlan();
    _changed();
  }

  int get planWeeks => (plan?['haftalar'] as List?)?.length ?? 12;
  bool get planFinished => usesPlan && DateTime.now().difference(start).inDays ~/ 7 + 1 > planWeeks;

  static Future<Store> open() async {
    final cat = jsonDecode(await rootBundle.loadString('assets/data/katalog.json')) as List;
    final prog = jsonDecode(await rootBundle.loadString('assets/data/program.json')) as Map;
    final ek = jsonDecode(await rootBundle.loadString('assets/data/katalog_ek.json')) as List;
    final catalog = {for (final e in [...cat, ...ek]) e['id'] as String: Exercise.fromJson(e)};
    await Bilgi.yukle();
    final program = ProgramData(
      [for (final p in prog['PH']) Phase(p['w'], p['name'], p['rir'], p['txt'])],
      List<int>.from(prog['WK']),
      [for (final d in prog['DAYS']) Day.fromJson(d)],
      Map<String, String>.from(prog['TAGN']),
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/saha.json');
    Map<String, dynamic> data;
    if (await file.exists()) {
      data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } else {
      data = {'surum': 1, 'kayitlar': {}, 'olcumler': [], 'degisim': {}, 'mola': {}, 'tamam': {}};
    }
    final s = Store._(catalog, program, file, data);
    await s._save();
    return s;
  }

  // ---- persistence --------------------------------------------------------

  Future<void> _save() async {
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(_data), flush: true);
    await tmp.rename(_file.path);
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  /// Merge an export from the old Not lesson ({"uygulama":"saha","veri":{...}})
  /// or from this app ({"surum":1,"kayitlar":{...}}). Never overwrites; adds
  /// records whose id is missing. Returns how many records were added.
  static int _importInto(Map<String, dynamic> data, String text) {
    final d = jsonDecode(text) as Map;
    var added = 0;
    final recs = (data['kayitlar'] as Map).cast<String, dynamic>();
    void add(String key, List list) {
      final k = legacyKeyMap[key] ?? key;
      final dst = (recs[k] as List?)?.cast<Map>().toList() ?? <Map>[];
      final have = {for (final r in dst) r['id']};
      for (final r in list) {
        if (r is Map && r['t'] is num && !have.contains(r['id'])) {
          final c = Map<String, dynamic>.from(r);
          if (key != k) c['eski'] = key;
          dst.add(c);
          added++;
        }
      }
      dst.sort((a, b) => n(a['t']).compareTo(n(b['t'])));
      recs[k] = dst;
    }

    if (d['uygulama'] == 'saha' && d['veri'] is Map) {
      final v = d['veri'] as Map;
      v.forEach((key, val) {
        if (key is String && key.startsWith('kayit:') && val is List) add(key.substring(6), val);
      });
      if (v['olcum'] is List) {
        final ol = (data['olcumler'] as List);
        final have = {for (final r in ol) r['id']};
        for (final r in v['olcum']) {
          if (r is Map && !have.contains(r['id'])) {
            ol.add(r);
            added++;
          }
        }
      }
    } else if (d['kayitlar'] is Map) {
      (d['kayitlar'] as Map).forEach((k, v) => add(k, v as List));
      final ol = (data['olcumler'] as List);
      final have = {for (final r in ol) r['id']};
      for (final r in (d['olcumler'] as List? ?? const [])) {
        if (!have.contains(r['id'])) {
          ol.add(r);
          added++;
        }
      }
    }
    return added;
  }

  int importText(String text) {
    final c = _importInto(_data, text);
    _changed();
    return c;
  }

  String exportText() => const JsonEncoder.withIndent(' ').convert({..._data, 'tarih': DateTime.now().toIso8601String()});

  // ---- week ---------------------------------------------------------------

  /// Program start: the Monday of the first recorded workout unless set.
  DateTime get start {
    if (usesPlan) return parseDay(plan!['baslangic'] as String);
    final s = _data['baslangic'] as String?;
    if (s != null) return parseDay(s);
    var first = DateTime.now();
    for (final list in (_data['kayitlar'] as Map).values) {
      for (final r in list as List) {
        final d = DateTime.fromMillisecondsSinceEpoch(n(r['t']).toInt());
        if (d.isBefore(first)) first = d;
      }
    }
    final day = DateTime(first.year, first.month, first.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  int get week {
    final w = DateTime.now().difference(start).inDays ~/ 7 + 1;
    return w.clamp(1, usesPlan ? planWeeks : 12);
  }

  void setWeek(int w) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final iso = isoDay(monday.subtract(Duration(days: 7 * (w - 1))));
    if (usesPlan) {
      _data['plan'] = {...plan!, 'baslangic': iso};
      _buildPlan();
    } else {
      _data['baslangic'] = iso;
    }
    _changed();
  }

  int get phase => program.phaseOf(week);

  // ---- day plan -----------------------------------------------------------

  /// Weekday (1 = Monday) → program day: Monday A, Wednesday B, Saturday C.
  /// Changeable in Program › Gün düzeni.
  static const defaultSchedule = {1: 'gunA', 3: 'gunB', 6: 'gunC'};

  Map<int, String> get schedule {
    if (usesPlan) return planSchedule(plan!);
    final m = _data['duzen'] as Map?;
    if (m == null) return defaultSchedule;
    return {for (final e in m.entries) int.parse('${e.key}'): '${e.value}'};
  }

  void setSchedule(Map<int, String> m) {
    _data['duzen'] = {for (final e in m.entries) '${e.key}': e.value};
    _changed();
  }

  /// Program days in the order they fall in the week, with their weekday.
  List<(int, String)> get weekOrder => (schedule.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => a.$1.compareTo(b.$1)));

  int? weekdayOf(String dayId) {
    for (final e in schedule.entries) {
      if (e.value == dayId) return e.key;
    }
    return null;
  }

  String? get scheduledDay => schedule[DateTime.now().weekday];

  /// Weekday name a program day falls on ("Pazartesi"), or its own tag.
  String dayName(Day d) {
    final wd = weekdayOf(d.id);
    return wd == null ? d.tag : tr(gunler[wd - 1]);
  }

  String? get chosenDay {
    final c = _data['secilen'] as Map?;
    if (c != null && c['d'] == isoDay()) return c['gun'];
    return scheduledDay;
  }

  void chooseDay(String? id) {
    _data['secilen'] = {'d': isoDay(), 'gun': id};
    _changed();
  }

  String slotKey(Day d, Slot s) => '${d.id}:${s.no}:${s.id}';

  /// The exercise shown in a slot: the program's own or a chosen alternative.
  Exercise exerciseFor(Day d, Slot s) {
    final alt = (_data['degisim'] as Map)[slotKey(d, s)];
    return catalog[alt] ?? catalog[s.id]!;
  }

  bool isSwapped(Day d, Slot s) => (_data['degisim'] as Map).containsKey(slotKey(d, s));

  void swap(Day d, Slot s, String? exerciseId) {
    final m = _data['degisim'] as Map;
    if (exerciseId == null || exerciseId == s.id) {
      m.remove(slotKey(d, s));
    } else {
      m[slotKey(d, s)] = exerciseId;
    }
    _changed();
  }

  /// Slots of a day that are in this week's plan.
  List<Slot> activeSlots(Day d) => [for (final s in d.slots) if (s.doseFor(phase) != null) s];

  // ---- warm-up / cool-down ticks ---------------------------------------------

  bool ticked(String key) => ((_data['tamam'] as Map)[isoDay()] as List? ?? const []).contains(key);

  void tick(String key) {
    final m = _data['tamam'] as Map;
    final l = (m[isoDay()] as List?)?.toList() ?? [];
    l.contains(key) ? l.remove(key) : l.add(key);
    m
      ..clear()
      ..[isoDay()] = l;
    _changed();
  }

  // ---- records ------------------------------------------------------------

  List<Map> records(String exerciseId) => ((_data['kayitlar'] as Map)[exerciseId] as List? ?? const []).cast<Map>();

  List<Map> todaySets(String exerciseId) => [for (final r in records(exerciseId)) if (r['d'] == isoDay() && r['set'] != null) r];

  Map? last(String exerciseId) {
    final r = records(exerciseId);
    return r.isEmpty ? null : r.last;
  }

  Map addSet(Exercise e, Map<String, num?> values) {
    final rec = <String, dynamic>{'id': uid(), 't': DateTime.now().millisecondsSinceEpoch, 'd': isoDay(), 'w': week, 'set': todaySets(e.id).length + 1};
    values.forEach((k, v) {
      if (v != null) rec[k] = v;
    });
    final m = _data['kayitlar'] as Map;
    final l = (m[e.id] as List?)?.toList() ?? [];
    l.add(rec);
    m[e.id] = l;
    _changed();
    return rec;
  }

  void removeRecord(String exerciseId, String id) {
    final m = _data['kayitlar'] as Map;
    final l = (m[exerciseId] as List?)?.toList() ?? [];
    final i = l.indexWhere((r) => r['id'] == id);
    if (i < 0) return;
    final bin = (_data['cop'] as List?)?.toList() ?? [];
    bin.add({'k': exerciseId, 'rec': l[i], 'silindi': DateTime.now().millisecondsSinceEpoch});
    while (bin.length > 200) {
      bin.removeAt(0);
    }
    _data['cop'] = bin;
    l.removeAt(i);
    m[exerciseId] = l;
    _changed();
  }

  /// Changes a saved set's values (null removes an optional one). Returns the record as it was,
  /// for undo, or null when it is not there.
  Map<String, dynamic>? updateRecord(String exerciseId, String id, Map<String, num?> values) {
    final m = _data['kayitlar'] as Map;
    final l = (m[exerciseId] as List?)?.toList() ?? [];
    final i = l.indexWhere((r) => r['id'] == id);
    if (i < 0) return null;
    final old = Map<String, dynamic>.from(l[i] as Map);
    final r = Map<String, dynamic>.from(old);
    values.forEach((k, v) {
      if (v == null) {
        r.remove(k);
      } else {
        r[k] = v;
      }
    });
    r['duzenlendi'] = DateTime.now().millisecondsSinceEpoch;
    l[i] = r;
    m[exerciseId] = l;
    _changed();
    return old;
  }

  /// Puts a record back exactly as it was (undo of [updateRecord]).
  void putRecord(String exerciseId, Map record) {
    final m = _data['kayitlar'] as Map;
    final l = (m[exerciseId] as List?)?.toList() ?? [];
    final i = l.indexWhere((r) => r['id'] == record['id']);
    if (i < 0) return;
    l[i] = Map<String, dynamic>.from(record);
    m[exerciseId] = l;
    _changed();
  }

  void restoreLast() {
    final bin = (_data['cop'] as List?)?.toList() ?? [];
    if (bin.isEmpty) return;
    final c = bin.removeLast();
    _data['cop'] = bin;
    final m = _data['kayitlar'] as Map;
    final l = (m[c['k']] as List?)?.toList() ?? [];
    l.add(c['rec']);
    l.sort((a, b) => n(a['t']).compareTo(n(b['t'])));
    m[c['k']] = l;
    _changed();
  }

  int get recordCount => (_data['kayitlar'] as Map).values.fold<int>(0, (a, l) => a + (l as List).length) + measurements.length;

  // ---- island over other apps ----------------------------------------------

  bool get adaAcik => _data['ada'] == true;
  bool get adaSecildi => _data.containsKey('ada');

  void setAda(bool on) {
    _data['ada'] = on;
    _changed();
  }

  // ---- rest ---------------------------------------------------------------

  int restFor(Exercise e) => n((_data['mola'] as Map)[e.id] ?? e.rest).toInt();

  void setRest(Exercise e, int seconds) {
    (_data['mola'] as Map)[e.id] = seconds.clamp(15, 600);
    _changed();
  }

  // ---- measurements -------------------------------------------------------

  List<Map> get measurements => (_data['olcumler'] as List).cast<Map>();

  void addMeasurement(Map<String, num> values, String? note) {
    final r = <String, dynamic>{'id': uid(), 't': DateTime.now().millisecondsSinceEpoch, 'd': isoDay(), 'w': week, ...values};
    if (note != null && note.trim().isNotEmpty) r['not'] = note.trim();
    (_data['olcumler'] as List).add(r);
    _changed();
  }

  void removeMeasurement(String id) {
    (_data['olcumler'] as List).removeWhere((r) => r['id'] == id);
    _changed();
  }

  num? lastMeasure(String key) {
    for (final r in measurements.reversed) {
      if (r[key] != null) return n(r[key]);
    }
    return null;
  }
}
