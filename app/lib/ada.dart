import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'data.dart';
import 'figure.dart';
import 'lang.dart';
import 'media.dart';
import 'theme.dart';
import 'widgets.dart';

/// One step of the island's list, reduced to what choosing the next step needs.
class AdaAdim {
  const AdaAdim({required this.yapilan, required this.hedef, this.isinma = false, this.grup = -1});
  final int yapilan, hedef;
  final bool isinma;

  /// Superset group (A5a + A5b share one); -1 when alone.
  final int grup;

  bool get bitti => yapilan >= hedef;
}

/// The step to do now: continue after the last step with progress; in a superset take the
/// member with fewer sets (a, b, a, b). Earlier unfinished steps come back at the end,
/// except the warm-up: once training has started, a skipped warm-up is not asked for again.
int? adaSiradaki(List<AdaAdim> l) {
  if (l.isEmpty) return null;
  final gruplar = <List<int>>[];
  for (var i = 0; i < l.length; i++) {
    if (l[i].grup >= 0 && gruplar.isNotEmpty && l[gruplar.last.first].grup == l[i].grup) {
      gruplar.last.add(i);
    } else {
      gruplar.add([i]);
    }
  }
  var son = -1;
  for (var i = 0; i < l.length; i++) {
    if (l[i].yapilan > 0) son = i;
  }
  final bas = son < 0 ? 0 : gruplar.indexWhere((g) => g.contains(son));
  for (var j = 0; j < gruplar.length; j++) {
    final gi = (bas + j) % gruplar.length;
    final geri = gi < bas;
    int? en;
    for (final i in gruplar[gi]) {
      if (l[i].bitti || (geri && l[i].isinma)) continue;
      if (en == null || l[i].yapilan < l[en].yapilan) en = i;
    }
    if (en != null) return en;
  }
  return null;
}

/// Seconds in a dose like "2×20 sn" or "10 dk"; null when it is not timed.
int? adaSure(String? doz) {
  if (doz == null) return null;
  final s = RegExp(r'(\d+)\s*(sn|sec|s)\b').firstMatch(doz);
  if (s != null) return int.parse(s[1]!);
  final d = RegExp(r'(\d+)\s*(dk|min)\b').firstMatch(doz);
  return d == null ? null : int.parse(d[1]!) * 60;
}

/// "3×10 · RIR 3" → "3 × 10".
String adaDoz(String? doz) => (doz ?? '').split(' · ').first.replaceAll(RegExp(r'\s*×\s*'), ' × ').trim();

class _Kalem {
  _Kalem(this.day, this.slot, this.e, this.bolum);
  final Day day;
  final Slot slot;
  final Exercise e;
  final String bolum; // Isınma / Ana bölüm / Soğuma (Turkish key)
}

/// Today's steps in order: warm-up, the chosen day's main block, cool-down.
List<_Kalem> _gunKalemleri(Store store) {
  final id = store.chosenDay;
  if (id == null) return const [];
  final p = store.program;
  final out = <_Kalem>[];
  void ekle(Day d, List<Slot> ss, String b) {
    for (final s in ss) {
      out.add(_Kalem(d, s, store.exerciseFor(d, s), b));
    }
  }

  try {
    final w = p.day('isinma');
    ekle(w, w.slots, 'Isınma');
  } catch (_) {}
  final g = p.day(id);
  ekle(g, store.activeSlots(g), 'Ana bölüm');
  try {
    final c = p.day('soguma');
    ekle(c, c.slots, 'Soğuma');
  } catch (_) {}
  return out;
}

List<AdaAdim> _adimlar(List<_Kalem> l, int Function(_Kalem) yapilan, int Function(_Kalem) hedef) {
  var grup = -1, sonA = -1;
  return [
    for (final k in l)
      () {
        final s = k.slot;
        if (s.superset && s.no.endsWith('a')) {
          sonA = ++grup;
        } else if (!(s.superset && s.no.endsWith('b'))) {
          sonA = -1;
        }
        return AdaAdim(yapilan: yapilan(k), hedef: hedef(k), isinma: k.bolum == 'Isınma', grup: s.superset ? sonA : -1);
      }(),
  ];
}

/// Where to go after this exercise (the "Sıradaki" button on the exercise page): once its sets
/// are done, or straight away to the other half of a superset. Null when there is nowhere to go.
(Day, Slot, Exercise)? siradakiHareket(Store store, Day? day, Slot? slot) {
  if (day == null || slot == null) return null;
  final l = _gunKalemleri(store);
  final i = l.indexWhere((k) => k.day.id == day.id && k.slot.no == slot.no && k.slot.id == slot.id);
  if (i < 0) return null;
  int hedef(_Kalem k) => parseDose(k.slot.doseFor(store.phase)).$1 ?? (k.e.logs ? 3 : 1);
  int yapilan(_Kalem k) => k.e.logs ? store.todaySets(k.e.id).length : (store.ticked(store.slotKey(k.day, k.slot)) ? hedef(k) : 0);
  final ad = _adimlar(l, yapilan, hedef);
  final j = adaSiradaki(ad);
  if (j == null || j == i) return null;
  final ikinciYari = ad[i].grup >= 0 && ad[j].grup == ad[i].grup && ad[i].yapilan > 0;
  if (!ad[i].bitti && !ikinciYari) return null;
  return (l[j].day, l[j].slot, l[j].e);
}

class _Is {
  _Is(this.anahtar, this.toplam, this.zamanlayici) : son = DateTime.now().add(Duration(seconds: toplam));
  final String anahtar;
  final int toplam;
  final DateTime son;
  final Timer zamanlayici;
  int get gecen => (toplam - son.difference(DateTime.now()).inSeconds).clamp(1, toplam);
}

/// What a workout shows outside the app:
/// - an ongoing notification (a Live Update on Android 16) for the whole workout: the
///   exercise and set, the rest counting down, the day's exercises as progress, a button;
/// - the island over other apps (Android "display over other apps", when turned on), only
///   while the app is in the background: a black pill under the status bar that opens into
///   a card with the animation, the dose and the buttons.
/// Both log sets without opening the app.
class Ada extends ChangeNotifier with WidgetsBindingObserver {
  Ada(this.store, this.rest) {
    o = this;
    if (!destekli) return;
    WidgetsBinding.instance.addObserver(this);
    _kanal.setMethodCallHandler(_gelen);
    store.addListener(_degisti);
    rest.addListener(_degisti);
    Lang.current.addListener(_degisti);
    _imza = _imzaHesapla();
    izinYenile();
    _onYukle = Timer(const Duration(seconds: 3), _kareOnYukle);
    // The workout ends two hours after the last set even if nothing else happens.
    Timer.periodic(const Duration(minutes: 1), (_) => _gonder());
  }

  static Ada? o;
  static const _kanal = MethodChannel('saha/ada');
  static bool get destekli => !kIsWeb && Platform.isAndroid;

  final Store store;
  final RestTimer rest;

  /// "Display over other apps" is granted.
  bool izin = false;
  bool get acik => store.adaAcik;
  bool get hazir => destekli && acik && izin;

  bool _arkada = false, _gosteriliyor = false, _kapatildi = false;
  int _elleMs = 0;
  String? _imlec;
  final Map<String, int> _sayac = {};

  /// kg / reps changed on the island before the set is logged, per step.
  final Map<String, Map<String, num?>> _ayar = {};
  _Is? _is;
  String? _not;
  int _notT = 0;
  String _sonGiden = '';
  final Set<String> _kareGitti = {};
  int _imza = 0;
  Timer? _onYukle;

  /// A rest ran out (not skipped): the next set waits for the owner, shown in amber.
  int _dikkatMs = 0;
  bool _molaVardi = false;
  bool _bildirimSoruldu = false;

  // ---- settings -------------------------------------------------------------

  Future<void> izinYenile() async {
    if (!destekli) return;
    try {
      izin = await _kanal.invokeMethod<bool>('izin') ?? false;
    } catch (_) {
      izin = false;
    }
    notifyListeners();
  }

  Future<void> ac(bool on) async {
    store.setAda(on);
    if (on && !izin) await izinIste();
    notifyListeners();
  }

  Future<void> izinIste() async {
    try {
      await _kanal.invokeMethod('izinIste');
    } catch (_) {}
  }

  /// "Adaya geç": start the session now and send the app to the background.
  Future<void> adayaGec() async {
    _elleMs = DateTime.now().millisecondsSinceEpoch;
    _kapatildi = false;
    // The animation frames are drawn by the app; in the background that can stall, so the first ones go now.
    await _kareOnYukle(enCok: 3).timeout(const Duration(seconds: 3), onTimeout: () {});
    try {
      await _kanal.invokeMethod('arkayaAl');
    } catch (_) {}
  }

  // ---- what is on the list today -----------------------------------------------

  List<_Kalem> _kalemler() => _gunKalemleri(store);

  String _anahtar(_Kalem k) => store.slotKey(k.day, k.slot);
  String? _doz(_Kalem k) => k.slot.doseFor(store.phase);
  int _hedef(_Kalem k) => parseDose(_doz(k)).$1 ?? (k.e.logs ? 3 : 1);
  int _yapilan(_Kalem k) {
    if (k.e.logs) return store.todaySets(k.e.id).length;
    final key = _anahtar(k);
    return store.ticked(key) ? _hedef(k) : (_sayac[key] ?? 0);
  }

  /// What the next set will log ([setPrefill]) plus changes made on the island.
  Map<String, num?> _degerler(_Kalem k) {
    return {...setPrefill(store, k.e, k.slot), ...?_ayar[_anahtar(k)]};
  }

  void _ayarla(_Kalem k, String alan, int yon) {
    final f = k.e.type?.fields.where((f) => f.key == alan).firstOrNull;
    if (f == null) return;
    final adim = const {'kg': 2.5, 'r': 1, 'm': 5, 'sn': 5}[alan] ?? 1;
    final x = ((_degerler(k)[alan] ?? f.min) + yon * adim).clamp(f.min, f.max);
    _ayar[_anahtar(k)] = {...?_ayar[_anahtar(k)], alan: x};
  }

  int? _simdiki(List<_Kalem> l) {
    if (_imlec != null) {
      final i = l.indexWhere((k) => _anahtar(k) == _imlec);
      if (i >= 0) return i;
      _imlec = null;
    }
    return adaSiradaki(_adimlar(l, _yapilan, _hedef));
  }

  /// Sets logged and steps ticked today: when it grows, a workout is going on.
  int _imzaHesapla() {
    var n = 0;
    for (final k in _kalemler()) {
      n += _yapilan(k);
    }
    return n;
  }

  int get _sonKayitMs {
    var m = _elleMs;
    for (final k in _kalemler()) {
      for (final r in store.todaySets(k.e.id)) {
        final t = (r['t'] as num?)?.toInt() ?? 0;
        if (t > m) m = t;
      }
    }
    return m;
  }

  bool get _oturum => DateTime.now().millisecondsSinceEpoch - _sonKayitMs < const Duration(hours: 2).inMilliseconds;

  /// A workout is on: the notification shows (in the app too).
  bool get _oturumVar => destekli && !_kapatildi && (rest.active || _is != null || (_oturum && store.chosenDay != null));

  /// The island shows too: turned on, allowed, and the app is in the background.
  bool get _adaVar => hazir && _arkada;

  bool get _dikkat =>
      _dikkatMs > 0 && !rest.active && _is == null && DateTime.now().millisecondsSinceEpoch - _dikkatMs < const Duration(minutes: 10).inMilliseconds;

  // ---- state sent to the overlay ----------------------------------------------------

  Map<String, Object?> _durum() {
    final l = _kalemler();
    final i = _simdiki(l);
    final k = i == null ? null : l[i];
    final now = DateTime.now().millisecondsSinceEpoch;
    String gun = '';
    try {
      gun = store.program.day(store.chosenDay!).title;
    } catch (_) {}
    var ilerlemeTum = 0.0;
    final liste = <Map<String, Object?>>[];
    for (var j = 0; j < l.length; j++) {
      final y = _yapilan(l[j]), h = _hedef(l[j]);
      final oran = h == 0 ? 0.0 : (y / h).clamp(0.0, 1.0);
      ilerlemeTum += oran;
      liste.add({'ad': l[j].e.name, 'alt': adaDoz(_doz(l[j])), 'd': j == i ? 's' : (y >= h ? 'b' : 'q'), if (j == i) 'oran': oran});
    }
    final adimYazi = i == null ? '' : trf('Adım {0}/{1}', [i + 1, l.length]);
    final dikkat = _dikkat && k != null;
    final d = <String, Object?>{
      'L': {'eksi': '−15', 'arti': '+15', 'molaBitir': tr('Molayı bitir'), 'kanal': tr('Antrenman')},
      'sira': i == null ? '' : '${i + 1}/${l.length}',
      'gun': gun,
      'adimYazi': adimYazi,
      'nAlt': [adimYazi, gun].where((x) => x.isNotEmpty).join(' · '),
      'toplam': l.length,
      'ilerlemeTum': ilerlemeTum,
      'liste': liste,
      'ada': _adaVar,
      'arkada': _arkada,
      'dikkat': dikkat,
      'gezinme': l.length > 1,
      if (_not != null && now - _notT < 4000) 'not': _not,
      'notT': _notT,
    };
    final sn = tr('sn');
    if (k == null) {
      if (rest.active) {
        return {...d, 'mod': 'mola', 'ust': tr('MOLA'), 'baslik': rest.label, 'kisa': rest.label, 'kisaAlt': tr('MOLA'), 'setNo': 1, 'doz': '', 'set': '', 'kayit': '', 'kapsul': '',
          'molaSon': rest.end?.millisecondsSinceEpoch ?? now, 'molaToplam': rest.total, 'birincil': tr('Molayı bitir'), 'sonraki': '',
          'dugmeler': [{'y': '−15', 'e': 'eksi'}, {'y': '+15', 'e': 'arti'}],
          'nBaslik': trf('Mola · {0}', [rest.label]), 'nMetin': tr('Dinlen'),
          'nEylemler': [{'y': '+15 $sn', 'e': 'arti'}, {'y': tr('Molayı bitir'), 'e': 'molaBitir'}]};
      }
      return {...d, 'mod': 'bitti', 'ust': trUpper(tr('Antrenman')), 'baslik': tr('Bugünlük bitti'), 'kisa': tr('Bugünlük bitti'), 'kisaAlt': '✓', 'setNo': 1, 'doz': '', 'set': '', 'kapsul': '',
        'kayit': tr('Kayıtlar uygulamada. İyi dinlen.'), 'birincil': tr('Adayı kapat'), 'ilerleme': 1.0,
        'nBaslik': tr('Bugünlük bitti'), 'nMetin': tr('Kayıtlar uygulamada. İyi dinlen.'),
        'nEylemler': [{'y': tr('Kapat'), 'e': 'kapat'}]};
    }
    final e = k.e, hedef = _hedef(k), yapilan = _yapilan(k);
    final setNo = yapilan + 1;
    final setYazi = setNo > hedef ? tr('EKSTRA SET') : trf('SET {0} / {1}', [setNo, hedef]);
    final doz = adaDoz(_doz(k));
    final type = e.type;
    final degerler = e.logs ? _degerler(k) : null;
    final sure = e.logs ? (type!.kind == 'sn' ? degerler!['sn']?.toInt() : null) : adaSure(_doz(k));
    final yuk = type == null || type.kind == 'sn' ? '' : type.text(degerler!);
    final kayit = yuk.isEmpty ? (k.slot.cue.isNotEmpty ? k.slot.cue : '') : trf('Kaydedilecek: {0}', [yuk]);
    d.addAll({
      'id': e.id,
      'ust': trUpper([tr(k.bolum), if (k.day.isMain) k.slot.shortNo].join(' · ')),
      'baslik': e.name,
      'kisa': e.name,
      'doz': doz,
      'set': setYazi,
      'setNo': setNo,
      'kayit': kayit,
      'ilerleme': hedef == 0 ? 0.0 : (yapilan / hedef).clamp(0.0, 1.0),
      'sag': '${yapilan.clamp(0, hedef)}/$hedef',
      'kapsul': '',
    });
    final setSatiri = [setYazi.toLowerCase().replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase()), doz].where((x) => x.isNotEmpty).join(' · ');
    if (_is != null) {
      return {...d, 'mod': 'is', 'kisaAlt': setYazi, 'isSon': _is!.son.millisecondsSinceEpoch, 'isToplam': _is!.toplam, 'birincil': tr('Bitir'),
        'nBaslik': e.name, 'nMetin': setSatiri, 'nEylemler': [{'y': tr('Bitir'), 'e': 'birincil'}]};
    }
    if (rest.active) {
      final sonraki = yapilan >= hedef ? trf('Sıradaki: {0}', [e.name]) : trf('Sonraki: set {0} / {1}', [setNo, hedef]);
      final siradaki = trf('Sırada: {0} · {1}', [e.name, setSatiri]);
      return {...d, 'mod': 'mola', 'kisaAlt': tr('MOLA'), 'molaSon': rest.end?.millisecondsSinceEpoch ?? now, 'molaToplam': rest.total, 'birincil': tr('Molayı bitir'),
        'sonraki': sonraki, 'kapsul': siradaki, 'dugmeler': [{'y': '−15', 'e': 'eksi'}, {'y': '+15', 'e': 'arti'}],
        'nBaslik': trf('Mola · {0}', [rest.label.isEmpty ? e.name : rest.label]), 'nMetin': siradaki,
        'nEylemler': [{'y': '+15 $sn', 'e': 'arti'}, {'y': tr('Molayı bitir'), 'e': 'molaBitir'}]};
    }
    final String birincil;
    final dugmeler = <Map<String, String>>[];
    if (e.logs) {
      birincil = sure != null ? trf('Başlat · {0} sn', [sure]) : tr('Set bitti');
      const ad = {'kg': 'kg', 'r': 'tekrar', 'm': 'm', 'sn': 'sn'};
      for (final f in type!.fields) {
        if (f.optional || !ad.containsKey(f.key)) continue;
        final y = f.key == 'r' || f.key == 'sn' ? tr(ad[f.key]!) : ad[f.key]!;
        dugmeler
          ..add({'y': '− $y', 'e': 'ayar:${f.key}:-'})
          ..add({'y': '+ $y', 'e': 'ayar:${f.key}:+'});
      }
    } else if (sure != null) {
      birincil = trf('Başlat · {0} sn', [sure]);
      dugmeler.add({'y': tr('Tamam'), 'e': 'ikincil'});
    } else {
      birincil = tr('Tamam');
    }
    return {...d, 'mod': 'set', 'kisaAlt': '$setYazi · $doz', 'birincil': birincil, 'dugmeler': dugmeler,
      'kapsul': dikkat ? trf('Sıradaki: {0}', [[setSatiri, if (yuk.isNotEmpty) yuk].join(' · ')]) : '',
      'nBaslik': dikkat ? trf('Mola bitti · {0}', [e.name]) : e.name,
      'nMetin': [setSatiri, if (yuk.isNotEmpty) yuk].join(' · '),
      'nKisa': '${yapilan.clamp(0, hedef)}/$hedef',
      'nEylemler': [{'y': birincil, 'e': 'birincil'}]};
  }

  // ---- sending ---------------------------------------------------------------------------

  void _degisti() {
    final imza = _imzaHesapla();
    if (imza > _imza) {
      _elleMs = DateTime.now().millisecondsSinceEpoch;
      _kapatildi = false;
      _dikkatMs = 0;
    }
    if (rest.active) {
      _molaVardi = true;
      _dikkatMs = 0;
    } else if (_molaVardi) {
      _molaVardi = false;
      if (rest.justFinished) _dikkatMs = DateTime.now().millisecondsSinceEpoch;
    }
    _imza = imza;
    if (!_arkada && hazir) {
      _onYukle?.cancel();
      _onYukle = Timer(const Duration(milliseconds: 1500), _kareOnYukle);
    }
    _gonder();
  }

  bool _gonderiyor = false, _yeniden = false;

  Future<void> _gonder() async {
    if (_gonderiyor) {
      _yeniden = true;
      return;
    }
    _gonderiyor = true;
    try {
      do {
        _yeniden = false;
        if (!_oturumVar) {
          rest.sessiz = false;
          if (_gosteriliyor) {
            _gosteriliyor = false;
            _sonGiden = '';
            await _kanal.invokeMethod('gizle');
          }
          continue;
        }
        final d = _durum();
        final s = jsonEncode(d);
        if (_gosteriliyor && s == _sonGiden) continue;
        final id = d['id'] as String?;
        // Never wait for frames here: drawing them in the background can stall the island's updates.
        if (id != null && _adaVar) unawaited(_kareGonder(id));
        // In the background the native side rings at the end of a rest; in the app the app does.
        rest.sessiz = _arkada;
        if (!_arkada && !_bildirimSoruldu) {
          _bildirimSoruldu = true;
          await _kanal.invokeMethod('bildirimIzni');
        }
        _sonGiden = s;
        final ok = await _kanal.invokeMethod<bool>(_gosteriliyor ? 'guncelle' : 'goster', d);
        _gosteriliyor = ok ?? true;
      } while (_yeniden);
    } catch (_) {
      _gosteriliyor = false;
    } finally {
      _gonderiyor = false;
    }
  }

  /// Animation frames of the current and the next steps, drawn while the app is open.
  /// Animation frames of today's exercises, drawn while the app is open (from the current one on, then the
  /// earlier ones), so the island can show every exercise it moves to.
  Future<void> _kareOnYukle({int? enCok}) async {
    if (_arkada || !hazir) return;
    final l = _kalemler();
    if (l.isEmpty) return;
    final i = _simdiki(l) ?? 0;
    final sira = [for (var j = 0; j < l.length; j++) l[(i + j) % l.length].e.id];
    var n = 0;
    for (final id in sira) {
      if (_arkada && enCok == null) return;
      if (enCok != null && n++ >= enCok) return;
      await _kareGonder(id);
    }
  }

  Future<void> _kareGonder(String id) async {
    if (_kareGitti.contains(id)) return;
    _kareGitti.add(id);
    final e = store.catalog[id];
    final fig = e == null ? null : Figures.of(e);
    if (fig == null) return;
    try {
      final (ms, kareler) = await figureFramesPng(fig).timeout(const Duration(seconds: 4));
      await _kanal.invokeMethod('kareler', {'id': id, 'ms': ms, 'kareler': kareler});
    } catch (_) {
      _kareGitti.remove(id);
    }
  }

  // ---- lifecycle ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final s = state;
    if (s == AppLifecycleState.resumed) {
      _arkada = false;
      izinYenile();
      _onYukle?.cancel();
      _onYukle = Timer(const Duration(milliseconds: 1500), _kareOnYukle);
    } else if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      _arkada = true;
    }
    _gonder();
  }

  // ---- taps on the island ------------------------------------------------------------------

  Future<dynamic> _gelen(MethodCall c) async {
    if (c.method != 'eylem') return null;
    final a = c.arguments as String;
    final l = _kalemler();
    final i = _simdiki(l);
    final k = i == null ? null : l[i];
    switch (a) {
      case 'birincil':
        if (_is != null) {
          _isBitir(_is!.gecen);
        } else if (rest.active) {
          rest.skip();
        } else if (k == null) {
          _kapat();
        } else {
          _birincil(k);
        }
      case 'ikincil':
        if (k != null && !k.e.logs && !store.ticked(_anahtar(k))) {
          store.tick(_anahtar(k));
          _imlec = null;
        }
      case 'onceki' || 'sonraki':
        if (l.isNotEmpty) {
          final j = ((i ?? 0) + (a == 'sonraki' ? 1 : -1)) % l.length;
          _imlec = _anahtar(l[j]);
        }
      case 'eksi':
        rest.add(-15);
      case 'arti':
        rest.add(15);
      case 'molaBitir':
        rest.skip();
      case 'kapat':
        _kapat();
      case _ when a.startsWith('ayar:') && k != null:
        final p = a.split(':');
        _ayarla(k, p[1], p[2] == '+' ? 1 : -1);
    }
    _gonder();
    return null;
  }

  void _kapat() {
    _kapatildi = true;
    _is?.zamanlayici.cancel();
    _is = null;
  }

  void _birincil(_Kalem k) {
    final e = k.e;
    if (e.logs) {
      final v = _degerler(k);
      if (e.type!.kind == 'sn') {
        _isBaslat(k, (v['sn'] ?? 30).toInt());
      } else {
        _setKaydet(k, v);
      }
      return;
    }
    final sure = adaSure(_doz(k));
    if (sure != null) {
      _isBaslat(k, sure);
    } else if (!store.ticked(_anahtar(k))) {
      store.tick(_anahtar(k));
      _imlec = null;
    }
  }

  void _isBaslat(_Kalem k, int saniye) {
    _is?.zamanlayici.cancel();
    _imlec = _anahtar(k);
    _is = _Is(_anahtar(k), saniye, Timer(Duration(seconds: saniye), () => _isBitir(saniye)));
    _gonder();
  }

  /// End of a timed set (or "Bitir" early): log the seconds done.
  void _isBitir(int saniye) {
    final w = _is;
    if (w == null) return;
    w.zamanlayici.cancel();
    _is = null;
    final l = _kalemler();
    final k = l.where((x) => _anahtar(x) == w.anahtar).firstOrNull;
    if (k == null) {
      _gonder();
      return;
    }
    if (k.e.logs) {
      _setKaydet(k, {..._degerler(k), 'sn': saniye});
    } else {
      final key = _anahtar(k);
      final n = (_sayac[key] ?? 0) + 1;
      _sayac[key] = n;
      if (n >= _hedef(k) && !store.ticked(key)) store.tick(key);
      _imlec = n >= _hedef(k) ? null : key;
      _bildir(trf('{0}: {1} / {2}', [k.e.name, n, _hedef(k)]));
    }
    _gonder();
  }

  void _setKaydet(_Kalem k, Map<String, num?> v) {
    final rec = store.addSet(k.e, v);
    _ayar.remove(_anahtar(k));
    final supersetA = k.slot.superset && k.slot.no.endsWith('a');
    if (!supersetA) rest.start(store.restFor(k.e), k.e.name);
    _imlec = null;
    _bildir(supersetA ? tr('Kaydedildi. Molasız devam: süpersetin ikinci hareketi') : trf('Kaydedildi: {0}', [k.e.type!.text(rec)]));
  }

  void _bildir(String s) {
    _not = s;
    _notT = DateTime.now().millisecondsSinceEpoch;
    Timer(const Duration(milliseconds: 4100), _gonder);
  }
}
