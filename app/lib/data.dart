import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// ---------------------------------------------------------------------------
// Catalog
// ---------------------------------------------------------------------------

class Muscle {
  Muscle(this.region, this.name, this.latin, this.detail);
  final String region, name, latin, detail;
  factory Muscle.fromJson(Map j) => Muscle(j['bolge'] ?? '', j['ad'] ?? '', j['latince'] ?? '', j['detay'] ?? '');
}

class CmSpec {
  CmSpec(this.label, this.min, this.max, this.first);
  final String label;
  final int min, max, first;
}

class Exercise {
  Exercise.fromJson(Map j)
      : id = j['id'],
        name = j['ad'],
        en = j['en'] ?? '',
        inProgram = j['program'] == true,
        kind = j['kayit'],
        cm = j['cm'] == null ? null : CmSpec(j['cm']['etiket'] ?? 'cm', (j['cm']['min'] as num).toInt(), (j['cm']['max'] as num).toInt(), (j['cm']['ilk'] as num).toInt()),
        difficulty = (j['zorluk'] as num?)?.toInt() ?? 2,
        equipment = List<String>.from(j['ekipman'] ?? const []),
        purpose = j['amac'] ?? '',
        cues = List<String>.from(j['ipuclari'] ?? const []),
        mistakes = List<String>.from(j['hatalar'] ?? const []),
        knee = j['diz'],
        primary = [for (final m in (j['kaslar']?['ana'] ?? const [])) Muscle.fromJson(m)],
        secondary = [for (final m in (j['kaslar']?['yardimci'] ?? const [])) Muscle.fromJson(m)],
        stabilizers = [for (final m in (j['kaslar']?['sabitleyici'] ?? const [])) Muscle.fromJson(m)],
        altGeneral = j['alternatif']?['genel'],
        altEasier = j['alternatif']?['kolay'],
        altHarder = j['alternatif']?['zor'],
        exdb = j['medya']?['exdb'],
        figure = j['medya']?['figur'],
        rest = (j['mola'] as num?)?.toInt() ?? 90;

  final String id, name, en;
  final bool inProgram;
  final String? kind;
  final CmSpec? cm;
  final int difficulty;
  final List<String> equipment, cues, mistakes;
  final String purpose;
  final String? knee;
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
            (r) => n(r['kg']) > 0 ? '+${fmtKg(r['kg'])} kg × ${n(r['r'])}' : '${n(r['r'])} tekrar', (r) => n(r['r']), 'tekrar');
      case 'bw0':
        return LogType._(kind, const [Field('r', 'Tekrar', 1, 60)], (r) => [n(r['r'])], (r) => '${n(r['r'])} tekrar', (r) => n(r['r']), 'tekrar');
      case 'sn':
        return LogType._(kind, const [Field('sn', 'Süre', 5, 300, step: 5, unit: 'sn')], (r) => [n(r['sn'])], (r) => '${n(r['sn'])} sn', (r) => n(r['sn']), 'sn');
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
  String full(Map r) => text(r) + ((r['s'] ?? 1) > 1 ? ' · ${r['s']} set' : '');
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
  Phase(this.weeks, this.name, this.rir, this.text);
  final String weeks, name, rir, text;
}

class Slot {
  Slot.fromJson(Map j)
      : id = j['id'],
        no = j['no'],
        name = j['n'],
        dose = j['d'],
        cue = j['cue'] ?? '',
        alt = j['alt'],
        tags = List<String>.from(j['g'] ?? const []),
        superset = j['ss'] == true,
        isNew = j['isNew'] == true;

  final String id, no, name, cue;
  final dynamic dose; // String or List<String?> indexed by phase
  final String? alt;
  final List<String> tags;
  final bool superset, isNew;

  String? doseFor(int phase) => dose is String ? dose as String : (dose as List)[phase] as String?;
}

class Day {
  Day.fromJson(Map j)
      : id = j['id'],
        tag = j['tag'],
        title = j['title'],
        sub = j['sub'],
        slots = [for (final i in j['items']) Slot.fromJson(i)];
  final String id, tag, title, sub;
  final List<Slot> slots;
  bool get isMain => id.startsWith('gun');
  String get letter => id.startsWith('gun') ? id.substring(3) : '';
}

class ProgramData {
  ProgramData(this.phases, this.weekPhase, this.days, this.tags);
  final List<Phase> phases;
  final List<int> weekPhase;
  final List<Day> days;
  final Map<String, String> tags;

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
  return '${d.day} ${aylar[d.month - 1]}';
}

String uid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36) + math.Random().nextInt(1 << 20).toRadixString(36);

/// Old lesson keys whose records belong to a different movement now.
const legacyKeyMap = {'chinup': 'latpull'};

class Store extends ChangeNotifier {
  Store._(this.catalog, this.program, this._file, this._data);

  final Map<String, Exercise> catalog;
  final ProgramData program;
  final File _file;
  final Map<String, dynamic> _data;

  static Future<Store> open() async {
    final cat = jsonDecode(await rootBundle.loadString('assets/data/katalog.json')) as List;
    final prog = jsonDecode(await rootBundle.loadString('assets/data/program.json')) as Map;
    final catalog = {for (final e in cat) e['id'] as String: Exercise.fromJson(e)};
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
    return w.clamp(1, 12);
  }

  void setWeek(int w) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    _data['baslangic'] = isoDay(monday.subtract(Duration(days: 7 * (w - 1))));
    _changed();
  }

  int get phase => program.phaseOf(week);

  // ---- day plan -----------------------------------------------------------

  /// Weekday (1 = Monday) → program day: Monday A, Wednesday B, Saturday C.
  /// Changeable in Program › Gün düzeni.
  static const defaultSchedule = {1: 'gunA', 3: 'gunB', 6: 'gunC'};

  Map<int, String> get schedule {
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
