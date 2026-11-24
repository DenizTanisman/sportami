// Karar ve program motoru: bilgi/motor/motor.py + program.py'nin Dart karşılığı.
// Aynı girdiye Python prototipiyle aynı programı üretir (test/motor_test.dart karşılaştırır).
//
// Uyarı: Öneriler yayımlanmış araştırmalara dayanır; doktor, fizyoterapist ya da diyetisyen
// tavsiyesi değildir. Doğru bilgi için uzmana danışınız.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

const uyariMetni = 'Buradaki öneriler, herkese açık yayımlanmış araştırmalara ve kılavuzlara dayanır. Doktor, fizyoterapist '
    'ya da diyetisyen tavsiyesi değildir. Doğru bilgi için uzmana danışınız.';

const gunKodlari = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

const _agriPuan = 0.5;
const _darbeli = {'pliometri', 'sprint_hiz', 'ceviklik'};
const _rol = {'ana': 1.0, 'yardimci': 0.5, 'sabitleyici': 0.0};

const _ust = {'gogus', 'on_omuz', 'yan_omuz', 'arka_omuz', 'rotator_manset', 'trapez', 'ust_sirt', 'kanat', 'pazi', 'arka_kol', 'on_kol', 'boyun'};
const alt = {'kalca', 'kalca_yan', 'kalca_on', 'on_bacak', 'arka_bacak', 'ic_bacak', 'baldir', 'kaval'};
const core = {'karin', 'yan_karin', 'derin_core', 'bel'};
const _itme = {'gogus', 'on_omuz', 'yan_omuz', 'arka_kol'};
const _cekme = {'kanat', 'ust_sirt', 'arka_omuz', 'pazi', 'trapez', 'on_kol', 'rotator_manset'};
final Map<String, Set<String>> odak = {
  'tum': {..._ust, ...alt, ...core},
  'ust': {..._ust, ...core},
  'alt': {...alt, ...core},
  'itme': {..._itme, 'rotator_manset', ...core},
  'cekme': {..._cekme, ...core},
  'bacak': {...alt, ...core},
};
const _kucuk = {'derin_core', 'rotator_manset', 'on_kol', 'boyun', 'kaval', 'bel', 'kalca_on'};
const _kuvvetKat = {
  'itme_yatay', 'itme_dikey', 'cekme_yatay', 'cekme_dikey', 'squat', 'mentese', 'tek_bacak', 'izolasyon_ust', 'izolasyon_alt', 'baldir', 'tasima',
  'core_anti_ekstansiyon', 'core_anti_rotasyon', 'core_anti_yan_egilme', 'core_fleksiyon', 'rotasyon_guc'
};
const _bilesik = {'itme_yatay', 'itme_dikey', 'cekme_yatay', 'cekme_dikey', 'squat', 'mentese', 'tek_bacak'};
const _c = ['core_anti_ekstansiyon', 'core_anti_rotasyon', 'core_anti_yan_egilme', 'core_fleksiyon'];
const _zorunlu = <String, List<List<String>>>{
  'tum': [['squat', 'tek_bacak'], ['mentese'], ['itme_yatay', 'itme_dikey'], ['cekme_yatay', 'cekme_dikey'], _c],
  'ust': [['itme_yatay'], ['cekme_dikey'], ['cekme_yatay'], ['itme_dikey']],
  'alt': [['squat'], ['mentese'], ['tek_bacak'], _c],
  'itme': [['itme_yatay'], ['itme_dikey']],
  'cekme': [['cekme_dikey'], ['cekme_yatay']],
  'bacak': [['squat'], ['mentese'], ['tek_bacak']],
};
const _izometrik = {'wall_sit', 'front_plank', 'side_plank', 'hollow_hold', 'copenhagen_plank', 'glute_bridge_hold'};
const _coreKat = {'core_anti_ekstansiyon', 'core_anti_rotasyon', 'core_anti_yan_egilme', 'core_fleksiyon', 'rotasyon_guc'};
const _sira = {
  'pliometri': 0, 'squat': 1, 'mentese': 1, 'itme_yatay': 2, 'cekme_dikey': 2, 'itme_dikey': 2, 'cekme_yatay': 2, 'tek_bacak': 3, 'tasima': 4,
  'izolasyon_alt': 5, 'izolasyon_ust': 5, 'baldir': 5
};
const _disYuk = {'barbell', 'dambil', 'kettlebell', 'makine', 'kablo'};
const _yavasEksantrik = {'nordic_hamstring_curl', 'copenhagen_plank'};
const _gucAmac = {'basketbol', 'smac_dikey_sicrama', 'voleybol', 'futbol', 'hentbol', 'tenis'};
const sicramaliSpor = {'basketbol', 'voleybol', 'futbol', 'hentbol', 'tenis', 'smac_dikey_sicrama'};
const _kuvvetAmac = {'kuvvet'};
const _hipertrofiAmac = {'kas_kazanma', 'kuvvet', 'fonksiyonel_fitness', 'smac_dikey_sicrama', 'basketbol', 'voleybol', 'futbol', 'hentbol', 'tenis', 'dovus_sporlari'};
const kardiyoAmac = {'genel_saglik', 'kilo_verme', 'kosu', 'yuzme', 'bisiklet', 'saglikli_yaslanma', 'fonksiyonel_fitness'};

/// Python round(): yarıda kalanı çifte yuvarlar.
int pyRound(num x) {
  final f = x.floorToDouble();
  final d = x - f;
  if (d > 0.5) return f.toInt() + 1;
  if (d < 0.5) return f.toInt();
  return f.toInt().isEven ? f.toInt() : f.toInt() + 1;
}

/// Python'daki gibi kararlı sıralama.
void _kararliSirala<T>(List<T> l, int Function(T a, T b) cmp) {
  final idx = [for (var i = 0; i < l.length; i++) (i, l[i])];
  idx.sort((a, b) {
    final c = cmp(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  for (var i = 0; i < l.length; i++) {
    l[i] = idx[i].$2;
  }
}

int aralikSaat(int g1, int g2) {
  final f = (g2 - g1) % 7;
  return (f == 0 ? 7 : f) * 24;
}

// ---------------------------------------------------------------------------
// Bilgi
// ---------------------------------------------------------------------------

class Bilgi {
  Bilgi(Map j)
      : hareket = {for (final h in j['hareketler']) h['id'] as String: Map<String, dynamic>.from(h)},
        rahatsizlik = {for (final r in j['rahatsizliklar']) r['id'] as String: Map<String, dynamic>.from(r)},
        spor = {for (final s in j['sporlar']) s['id'] as String: Map<String, dynamic>.from(s)},
        bolge = {for (final b in j['bolgeler']) b['id'] as String: Map<String, dynamic>.from(b)},
        kurallar = Map<String, dynamic>.from(j['kurallar']);

  final Map<String, Map<String, dynamic>> hareket, rahatsizlik, spor, bolge;
  final Map<String, dynamic> kurallar;

  static Bilgi? _b;
  static Bilgi get b => _b!;
  static bool get yuklu => _b != null;
  static Future<Bilgi> yukle() async => _b ??= Bilgi(jsonDecode(await rootBundle.loadString('assets/data/motor.json')) as Map);
  static void kur(Map j) => _b = Bilgi(j);

  Map<String, dynamic> get program => Map<String, dynamic>.from(kurallar['program']);
  List get bantlar => kurallar['saglik_bantlari'] as List;

  /// Hareketin katalog kimliği (kayıtlar ve medya bununla).
  String katalogId(String hid) => (hareket[hid]?['k'] as String?) ?? hid;
}

Map<String, double> _yuk(Map h) => {for (final k in (h['kaslar'] as List? ?? const [])) k['bolge'] as String: _rol[k['rol']]!};
Set<String> _ana(Map h) => {for (final k in (h['kaslar'] as List? ?? const [])) if (k['rol'] == 'ana') k['bolge'] as String};
List<String> _sl(dynamic l) => [for (final x in (l as List? ?? const [])) '$x'];

// ---------------------------------------------------------------------------
// motor.py
// ---------------------------------------------------------------------------

/// Kullanıcının girdiği bir rahatsızlık.
class Rahatsizlik {
  Rahatsizlik(this.id, {this.agri, this.derece, this.tarih, this.bolge});
  final String id;
  final num? agri;
  final String? derece;
  final DateTime? tarih;
  final String? bolge;

  Map<String, dynamic> toJson() => {
        'id': id,
        if (agri != null) 'agri': agri,
        if (derece != null) 'derece': derece,
        if (tarih != null) 'tarih': '${tarih!.year}-${tarih!.month.toString().padLeft(2, '0')}-${tarih!.day.toString().padLeft(2, '0')}',
        if (bolge != null) 'bolge': bolge,
      };

  factory Rahatsizlik.fromJson(Map j) =>
      Rahatsizlik(j['id'], agri: j['agri'] as num?, derece: j['derece'] as String?, tarih: j['tarih'] == null ? null : DateTime.parse(j['tarih']), bolge: j['bolge'] as String?);
}

double _r2(double x) => (x * 100).roundToDouble() / 100;

(Map<String, double>, List<String>) bolgeSagligi(List<Rahatsizlik> rahatsizliklar, DateTime bugun) {
  final b = Bilgi.b;
  final dusus = {for (final k in b.bolge.keys) k: 0.0};
  final aciklama = <String>[];
  final gun = DateTime(bugun.year, bugun.month, bugun.day);
  for (final g in rahatsizliklar) {
    final r = b.rahatsizlik[g.id]!;
    var etkiler = (r['etkiler'] as List? ?? const []).cast<Map>();
    if (r['etki_modeli'] == 'secilen_kas' && g.bolge != null) etkiler = [{'bolge': g.bolge, 'katsayi': 1.0}];
    var ceza0 = 0.0;
    if (g.derece != null) {
      final d = (r['dereceler'] as List).cast<Map>().where((x) => x['derece'] == g.derece).firstOrNull;
      if (d != null) {
        final ig = d['iyilesme_gun'] as List;
        final t = ((ig[0] as num) + (ig[1] as num)) / 2;
        final gecen = g.tarih != null ? gun.difference(DateTime(g.tarih!.year, g.tarih!.month, g.tarih!.day)).inDays : 0;
        final bc = (d['baslangic_ceza'] as num).toDouble();
        ceza0 = t != 0 ? bc * math.max(0.0, 1 - gecen / t) : bc;
      }
    }
    final agri = (g.agri ?? 0).toDouble();
    for (final e in etkiler) {
      final k = (e['katsayi'] as num).toDouble();
      dusus[e['bolge']] = dusus[e['bolge']]! + math.max(agri * _agriPuan * k, ceza0 * k);
    }
    aciklama.add('${r['ad']}: ağrı ${_fmt(agri)}/10${g.derece != null ? ', ${g.derece} derece, ceza ${ceza0.toStringAsFixed(1)}' : ''}');
  }
  return ({for (final e in dusus.entries) e.key: _r2(math.max(0.0, 10 - e.value))}, aciklama);
}

String _fmt(num x) => x == x.roundToDouble() ? x.toInt().toString() : '$x';

String bant(double puan) {
  for (final b in Bilgi.b.bantlar) {
    final lo = (b['aralik'][0] as num).toDouble(), hi = (b['aralik'][1] as num).toDouble();
    if ((lo <= puan && puan < hi) || (puan == 10 && hi == 10)) return b['ad'];
  }
  return 'dinlenme';
}

List<String> _gerekenBolgeler(Map h) => [
      for (final k in (h['kaslar'] as List? ?? const [])) if (k['rol'] == 'ana') k['bolge'] as String,
      for (final e in (h['eklemler'] as List? ?? const [])) if (e['yuk'] == 'orta' || e['yuk'] == 'yuksek') e['bolge'] as String,
    ];

class Karar {
  Karar(this.hareket, this.karar, this.neden, this.yerine);
  final String hareket, karar;
  final List<String> neden;
  final String? yerine;
}

Karar hareketKarari(String hid, Map<String, double> saglik, int seviye, [int derinlik = 0]) {
  final b = Bilgi.b;
  final h = b.hareket[hid]!;
  final esik = (h['saglik_esigi'] as Map?) ?? const {};
  final vars = (esik['varsayilan'] as num?) ?? 6;
  final neden = <String>[];
  if ((h['seviye'] as num) > seviye) neden.add('seviye ${h['seviye']} gerekiyor (sende $seviye)');
  var enDusuk = 10.0;
  for (final bl in _gerekenBolgeler(h)) {
    final e = ((esik['bolgeler'] as Map?)?[bl] as num?) ?? vars;
    if (saglik[bl]! < e) neden.add('${b.bolge[bl]!['ad']} sağlığı ${saglik[bl]} < eşik $e');
    enDusuk = math.min(enDusuk, saglik[bl]!);
  }
  if (neden.isEmpty && bant(enDusuk) != 'tam') {
    final etkilenen = {for (final bl in _gerekenBolgeler(h)) if (bant(saglik[bl]!) != 'tam') bl};
    if (_darbeli.contains(h['kategori'])) neden.add('${etkilenen.map((x) => b.bolge[x]!['ad']).join(', ')} hafifletilmiş bantta; darbeli/patlayıcı iş yok');
    for (final e in (h['eklemler'] as List? ?? const [])) {
      if (e['yuk'] == 'yuksek' && etkilenen.contains(e['bolge'])) neden.add('${b.bolge[e['bolge']]!['ad']} hafifletilmiş bantta; bu harekette yükü yüksek');
    }
  }
  if (neden.isEmpty) {
    final karar = bant(enDusuk) == 'tam' ? 'uygun' : 'hafif';
    return Karar(hid, karar, karar == 'uygun' ? [] : ['ağrı izlenerek, hafif yükle'], null);
  }
  if (derinlik < 4) {
    for (final k in _sl(h['kolay'])) {
      final a = hareketKarari(k, saglik, seviye, derinlik + 1);
      if (a.karar == 'uygun' || a.karar == 'hafif') return Karar(hid, 'degistir', neden, a.yerine ?? k);
      if (a.yerine != null) return Karar(hid, 'degistir', neden, a.yerine);
    }
  }
  return Karar(hid, 'yok', neden, null);
}

class Donut {
  Donut(this.gerekli, this.kacin, this.secilebilirEk);
  final List<(String, double)> gerekli;
  final List<(String, double, String)> kacin;
  final List<String> secilebilirEk;
}

Donut kasDonutu(List<String> amaclar, String cinsiyet, int seviye, Map<String, double> saglik) {
  final b = Bilgi.b;
  final agirlik = <String, double>{};
  for (final a in amaclar) {
    for (final v in (b.spor[a]!['vurgu'] as List? ?? const [])) {
      final c = v['cinsiyet'];
      if (c != 'hepsi' && c != cinsiyet) continue;
      final sv = '${v['seviye']}';
      if (sv != 'hepsi' && sv != '$seviye') continue;
      final w = (v['agirlik'] as num).toDouble();
      agirlik[v['bolge']] = math.max(agirlik[v['bolge']] ?? 0, w);
    }
  }
  final sirali = agirlik.entries.toList();
  _kararliSirala(sirali, (x, y) => y.value.compareTo(x.value));
  final gerekli = <(String, double)>[], kacin = <(String, double, String)>[];
  for (final e in sirali) {
    final bt = bant(saglik[e.key]!);
    if (bt == 'rehabilitasyon' || bt == 'dinlenme') {
      kacin.add((e.key, saglik[e.key]!, bt));
    } else {
      gerekli.add((e.key, e.value));
    }
  }
  final ek = [
    for (final e in b.bolge.entries)
      if (e.value['tur'] == 'kas' && !agirlik.containsKey(e.key) && {'tam', 'hafifletilmis'}.contains(bant(saglik[e.key]!))) e.key
  ];
  return Donut(gerekli, kacin, ek);
}

// ---------------------------------------------------------------------------
// program.py
// ---------------------------------------------------------------------------

(Map<String, int>, String) haftalikIhtiyac(List<String> amaclar, int seviye, Donut don, Map<String, double> saglik, {List<String> ekKaslar = const [], bool sporVar = false}) {
  final b = Bilgi.b;
  final tablo = amaclar.any(_hipertrofiAmac.contains) ? 'hipertrofi' : 'saglik_genel';
  final tt = b.program['haftalik_set_hedefi'][tablo] as Map;
  final t = (tt['$seviye'] ?? tt['hepsi']) as Map;
  final mn = (t['minimum'] as num).toDouble(), lo = (t['tipik'][0] as num).toDouble(), hi = (t['tipik'][1] as num).toDouble();
  final agirlik = <String, double>{for (final (bl, w) in don.gerekli) if (b.bolge[bl]!['tur'] == 'kas') bl: w};
  for (final bl in ekKaslar) {
    if (don.secilebilirEk.contains(bl)) agirlik[bl] = math.max(agirlik[bl] ?? 0, 0.6);
  }
  final hedef = <String, int>{};
  for (final e in agirlik.entries) {
    final w = e.value;
    double n;
    if (_kucuk.contains(e.key) || w < 0.4) {
      n = mn;
    } else if (w < 0.7) {
      n = mn + (lo - mn) * (w - 0.4) / 0.3;
    } else {
      n = lo + (hi - lo) / 2 * (w - 0.7) / 0.3;
    }
    if (sporVar && alt.contains(e.key)) n = math.min(n, lo);
    if (bant(saglik[e.key]!) == 'hafifletilmis') n /= 2;
    hedef[e.key] = math.max(2, pyRound(n));
  }
  return (hedef, tablo);
}

Iterable<List<int>> _kombinasyon(List<int> l, int n, [int bas = 0]) sync* {
  if (n == 0) {
    yield [];
    return;
  }
  for (var i = bas; i <= l.length - n; i++) {
    for (final r in _kombinasyon(l, n - 1, i + 1)) {
      yield [l[i], ...r];
    }
  }
}

int _listeKarsilastir(List<num> a, List<num> b) {
  for (var i = 0; i < math.min(a.length, b.length); i++) {
    final c = a[i].compareTo(b[i]);
    if (c != 0) return c;
  }
  return a.length.compareTo(b.length);
}

(List<(int, String)>, List<int>) gunYapisi(List<int> gunler, int seviye) {
  final idx = gunler.toSet().toList()..sort();
  final ustSinir = {1: 3, 2: 4, 3: 6}[seviye]!;
  final n = math.min(idx.length, ustSinir);
  List<List<String>> kaliplar;
  if (n <= 1) {
    kaliplar = [List.filled(n, 'tum')];
  } else if (n == 2) {
    kaliplar = [['tum', 'tum'], ['ust', 'alt']];
  } else if (n == 3 || seviye == 1) {
    kaliplar = [['tum', 'tum', 'tum'], ['tum', 'ust', 'alt']];
  } else if (n == 4) {
    kaliplar = [['ust', 'alt', 'ust', 'alt']];
  } else if (n == 5) {
    kaliplar = [['ust', 'alt', 'itme', 'cekme', 'bacak']];
  } else {
    kaliplar = [['itme', 'cekme', 'bacak', 'itme', 'cekme', 'bacak']];
  }
  bool cakisir(String o1, String o2) => odak[o1]!.intersection(odak[o2]!).difference(core).isNotEmpty;

  List<(int, String)>? en;
  List<num>? enPuan;
  List<int>? enUc;
  for (var ki = 0; ki < kaliplar.length; ki++) {
    final kalip = kaliplar[ki];
    for (final a in _kombinasyon(idx, n)) {
      for (var kay = 0; kay < kalip.length; kay++) {
        final od = [...kalip.sublist(kay), ...kalip.sublist(0, kay)];
        final ar = <int>[];
        for (var i = 0; i < a.length; i++) {
          for (var j = 0; j < a.length; j++) {
            if (i != j && cakisir(od[i], od[j])) ar.add(aralikSaat(a[i], a[j]));
          }
        }
        var ardisik = 0;
        for (var i = 0; i < a.length; i++) {
          final g2 = i + 1 < a.length ? a[i + 1] : a[0] + 7;
          if (g2 - a[i] == 1) ardisik++;
        }
        final enKisa = ar.isEmpty ? 168 : ar.reduce(math.min);
        final puan = <num>[math.min(enKisa, 48), -ki, enKisa, -ardisik];
        final uc = (ar.toList()..sort()).take(3).toList();
        var daha = enPuan == null;
        if (!daha) {
          final c = _listeKarsilastir(puan, enPuan);
          daha = c > 0 || (c == 0 && _listeKarsilastir(uc, enUc!) > 0);
        }
        if (daha) {
          en = [for (var i = 0; i < a.length; i++) (a[i], od[i])];
          enPuan = puan;
          enUc = uc;
        }
      }
    }
  }
  final kuvvet = {for (final x in en ?? const <(int, String)>[]) x.$1};
  return (en ?? [], [for (final g in idx) if (!kuvvet.contains(g)) g]);
}

/// Kişiye uygun hareketler: {id: "uygun"|"hafif"} ve değişenler {asıl: (yerine, neden)}.
(Map<String, String>, Map<String, (String, List<String>)>) havuz(Map<String, double> saglik, int seviye, List<String> ortamlar, [List<String>? ekipman]) {
  final b = Bilgi.b;
  final ek = (ekipman != null && ekipman.isNotEmpty) ? {...ekipman, 'vucut_agirligi', 'sandalye_duvar'} : null;
  bool varMi(Map h) {
    if (!_sl(h['ortam']).any(ortamlar.contains)) return false;
    if (ek == null) return true;
    final he = _sl(h['ekipman']);
    return ek.containsAll(he) || (he.isNotEmpty && he.any(ek.contains) && he.length > 1 && ek.contains(he.first));
  }

  final out = <String, String>{}, neden = <String, (String, List<String>)>{};
  for (final e in b.hareket.entries) {
    if (!varMi(e.value)) continue;
    final k = hareketKarari(e.key, saglik, seviye);
    final hedef = (k.karar == 'uygun' || k.karar == 'hafif') ? e.key : k.yerine;
    if (hedef != null && varMi(b.hareket[hedef]!)) {
      final durum = (k.karar == 'uygun' && hedef == e.key) ? 'uygun' : (k.karar == 'hafif' ? 'hafif' : 'uygun');
      out.putIfAbsent(hedef, () => durum);
      if (hedef != e.key) neden[e.key] = (hedef, k.neden);
    }
  }
  return (out, neden);
}

double? _secimPuani(String h, Map<String, double> kalanSeans, Map<String, double> prio, List<String> secilenKat, Set<String> kullanilan, List<String> anahtar,
    Set<String> odakBolgeler, int set, int seviye, bool hafifIzinli, bool zorunluMod) {
  final hh = Bilgi.b.hareket[h]!;
  final yuk = _yuk(hh), ana = _ana(hh);
  if (ana.isEmpty || ana.intersection(odakBolgeler).isEmpty) return null;
  if (ana.difference(odakBolgeler).difference(core).isNotEmpty) return null;
  final kat = hh['kategori'] as String;
  if (secilenKat.contains(kat) && kat != 'izolasyon_ust' && kat != 'izolasyon_alt') return null;
  if (secilenKat.where((x) => x == kat).length >= 2) return null;
  final katki = {for (final e in yuk.entries) e.key: e.value * math.min(1.0, math.max(0.0, kalanSeans[e.key] ?? 0) / set) * (prio[e.key] ?? 0)};
  var fayda = katki.values.fold(0.0, (a, x) => a + x);
  if (zorunluMod) {
    fayda = katki.entries.where((e) => ana.contains(e.key)).fold(0.0, (a, e) => a + e.value) +
        0.25 * katki.entries.where((e) => !ana.contains(e.key)).fold(0.0, (a, e) => a + e.value);
  }
  if (fayda <= 0) {
    if (!zorunluMod) return null;
    fayda = 0.05 * ana.intersection(odakBolgeler).length;
  }
  if (_bilesik.contains(kat)) fayda *= 1.25;
  if (anahtar.contains(h)) fayda = fayda * 1.3 + 0.4;
  if (kullanilan.contains(h)) fayda *= _bilesik.contains(kat) ? {1: 0.95, 2: 0.75, 3: 0.7}[seviye]! : 0.7;
  if (seviye >= 2 && _sl(hh['ekipman']).any(_disYuk.contains)) fayda *= 1.15;
  if (!hafifIzinli) {
    final mutlak = ((hh['seviye'] as num) - 1) * 10 + ((hh['zorluk'] as num?) ?? 3);
    fayda *= 1 - math.max(0, {1: 0, 2: 5, 3: 10}[seviye]! - mutlak) / 12;
  }
  return fayda;
}

/// Bir seanstaki hareket reçetesi.
class Recete {
  Recete(this.hareket, this.ad, this.set, this.tekrar, this.dinlenmeSn, this.hafif, this.agriIzle, this.kategori);
  final String hareket, ad, tekrar, kategori;
  final int set;
  final List<int> dinlenmeSn;
  final bool hafif, agriIzle;

  Map<String, dynamic> toJson() => {'hareket': hareket, 'ad': ad, 'set': set, 'tekrar': tekrar, 'dinlenme_sn': dinlenmeSn, 'hafif': hafif, 'agri_izle': agriIzle, 'kategori': kategori};
  factory Recete.fromJson(Map j) =>
      Recete(j['hareket'], j['ad'], j['set'], j['tekrar'], [for (final x in j['dinlenme_sn']) (x as num).toInt()], j['hafif'] == true, j['agri_izle'] == true, j['kategori']);
}

Recete recete(String h, int set, int seviye, List<String> amaclar, {bool hafif = false, bool agriIzle = false}) {
  final hh = Bilgi.b.hareket[h]!;
  final kat = hh['kategori'] as String;
  final sn = (hh['set_arasi_sn'] as Map?) ?? const {};
  String tekrar, hedef;
  if (kat == 'pliometri') {
    (tekrar, hedef) = ('3–5', 'guc');
  } else if (_izometrik.contains(h)) {
    (tekrar, hedef) = ('20–45 sn', 'dayaniklilik');
  } else if (_yavasEksantrik.contains(h)) {
    (tekrar, hedef) = ('3–6 (yavaş iniş)', 'kuvvet');
  } else if (kat == 'tasima') {
    (tekrar, hedef) = ('20–40 m', 'dayaniklilik');
  } else if (kat == 'rotasyon_guc') {
    (tekrar, hedef) = ('6–10', 'guc');
  } else if (_coreKat.contains(kat)) {
    (tekrar, hedef) = ('8–12', 'dayaniklilik');
  } else if (seviye == 1) {
    (tekrar, hedef) = ('10–15', 'hipertrofi');
  } else if (amaclar.any(_kuvvetAmac.contains) && _bilesik.contains(kat) && _sl(hh['ekipman']).any(_disYuk.contains)) {
    (tekrar, hedef) = ('4–6', 'kuvvet');
  } else if (_bilesik.contains(kat)) {
    (tekrar, hedef) = ('6–10', 'hipertrofi');
  } else {
    (tekrar, hedef) = ('10–15', 'hipertrofi');
  }
  final d = (sn[hedef] ?? sn['hipertrofi'] ?? (sn.isNotEmpty ? sn.values.first : null) ?? const [60, 120]) as List;
  return Recete(h, hh['ad'], set, tekrar, [for (final x in d) (x as num).toInt()], hafif, agriIzle, kat);
}

List<Recete> _seansKur(int g, String od, int seviye, Map<String, String> uygun, Map<String, double> prio, Map<String, double> kalan, Map<String, int> sonCalisma,
    Map<String, int> toparlanma, Map<String, int> kalanFirsat, List<String> anahtar, Set<String> kullanilan, List<String> amaclar, bool hafifAlt) {
  final b = Bilgi.b;
  final sk = b.program['seans_basina_set_siniri'] as Map;
  final tavan = (sk['hipertrofi_fractional_ust']['$seviye'] as num).toDouble();
  final ta = sk['seans_toplam']['calisma_seti']['$seviye'] as List;
  final seansToplam = ((ta[0] as num) + (ta[1] as num)) / 2;
  final hareketSayisi = {1: 6, 2: 7, 3: 8}[seviye]!;
  final set = {1: 2, 2: 3, 3: 3}[seviye]!;
  final bolgeler = odak[od]!;
  if (hafifAlt) uygun = {for (final e in uygun.entries) if (!_yavasEksantrik.contains(e.key)) e.key: e.value};
  final acik = {for (final bl in bolgeler) if (!sonCalisma.containsKey(bl) || aralikSaat(sonCalisma[bl]!, g) >= toparlanma[bl]!) bl};
  final kapali = {for (final e in sonCalisma.entries) if (aralikSaat(e.value, g) < toparlanma[e.key]!) e.key};
  final kalanSeans = <String, double>{};
  for (final bl in acik) {
    if ((kalan[bl] ?? 0) > 0) {
      final firsat = math.max(1, kalanFirsat[bl] ?? 1);
      kalanSeans[bl] = math.min(tavan, (kalan[bl]! / firsat).ceilToDouble());
    }
  }
  final secim = <(String, int)>[], katListesi = <String>[], seansYuk = <String, double>{};
  var toplam = 0;
  var zorunlu = [for (final k in _zorunlu[od] ?? const <List<String>>[]) k.toSet()];
  while (toplam < seansToplam && secim.length < hareketSayisi) {
    String? en;
    var enPuan = 0.0;
    zorunlu = [for (final z in zorunlu) if (z.intersection(katListesi.toSet()).isEmpty) z];
    for (final tur in const ['zorunlu', 'serbest']) {
      if (tur == 'zorunlu' && zorunlu.isEmpty) continue;
      for (final h in uygun.keys) {
        final hh = b.hareket[h]!;
        if (tur == 'zorunlu' && !zorunlu.first.contains(hh['kategori'])) continue;
        // _aday_puani
        if (!_kuvvetKat.contains(hh['kategori']) || secim.any((x) => x.$1 == h)) continue;
        if (_ana(hh).difference(acik).difference(core).isNotEmpty) continue;
        var red = false;
        for (final e in _yuk(hh).entries) {
          if (kapali.contains(e.key) && e.value > 0 && (seansYuk[e.key] ?? 0) + e.value * set >= 3) {
            red = true;
            break;
          }
        }
        if (red) continue;
        final p = _secimPuani(h, kalanSeans, prio, katListesi, kullanilan, anahtar, acik, set, seviye, uygun[h] == 'hafif', tur == 'zorunlu');
        if (p != null && p != 0 && p > enPuan) {
          en = h;
          enPuan = p;
        }
      }
      if (en != null) break;
      if (tur == 'zorunlu') zorunlu.removeAt(0);
    }
    if (en == null) break;
    final hh = b.hareket[en]!;
    final s = _coreKat.contains(hh['kategori']) ? 2 : set;
    secim.add((en, s));
    katListesi.add(hh['kategori']);
    toplam += s;
    for (final e in _yuk(hh).entries) {
      if (kalanSeans.containsKey(e.key)) kalanSeans[e.key] = kalanSeans[e.key]! - e.value * s;
      if (kalan.containsKey(e.key)) kalan[e.key] = math.max(0.0, kalan[e.key]! - e.value * s);
      seansYuk[e.key] = (seansYuk[e.key] ?? 0) + e.value * s;
      if (seansYuk[e.key]! >= 3) sonCalisma[e.key] = g;
    }
  }
  _kararliSirala(secim, (x, y) {
    final a = b.hareket[x.$1]!, c = b.hareket[y.$1]!;
    final s1 = _sira[a['kategori']] ?? 6, s2 = _sira[c['kategori']] ?? 6;
    if (s1 != s2) return s1.compareTo(s2);
    return (-_ana(a).length).compareTo(-_ana(c).length);
  });
  return [
    for (final (h, s) in secim)
      recete(h, s, seviye, amaclar, hafif: hafifAlt && _ana(b.hareket[h]!).intersection(alt).isNotEmpty, agriIzle: uygun[h] == 'hafif')
  ];
}

int seansSuresi(List<Recete> r, [int isinmaDk = 10]) {
  var dk = isinmaDk.toDouble();
  for (final x in r) {
    dk += x.set * (0.75 + (x.dinlenmeSn[0] + x.dinlenmeSn[1]) / 2 / 60);
  }
  return pyRound(dk / 5) * 5;
}

// ---------------------------------------------------------------------------
// Plan
// ---------------------------------------------------------------------------

class GunPlan {
  GunPlan({required this.gun, required this.tur, this.odak, this.hareketler = const [], this.pliometri = const [], this.not = '', this.sureDk = 0, this.amac});
  final int gun; // 0 = Pazartesi
  final String tur; // kuvvet | spor | kardiyo_mobilite
  final String? odak, amac;
  List<Recete> hareketler, pliometri;
  String not;
  int sureDk;

  Map<String, dynamic> toJson() => {
        'gun': gun,
        'tur': tur,
        if (odak != null) 'odak': odak,
        if (amac != null) 'amac': amac,
        'hareketler': [for (final r in hareketler) r.toJson()],
        'pliometri': [for (final r in pliometri) r.toJson()],
        'not': not,
        'sure_dk': sureDk,
      };

  factory GunPlan.fromJson(Map j) => GunPlan(
        gun: j['gun'],
        tur: j['tur'],
        odak: j['odak'],
        amac: j['amac'],
        hareketler: [for (final r in j['hareketler'] ?? const []) Recete.fromJson(r)],
        pliometri: [for (final r in j['pliometri'] ?? const []) Recete.fromJson(r)],
        not: j['not'] ?? '',
        sureDk: j['sure_dk'] ?? 0,
      );
}

class Hafta {
  Hafta(this.hafta, this.blok, this.deload, this.rir, this.setCarpani, this.not);
  final int hafta, blok, rir;
  final bool deload;
  final double setCarpani;
  final String not;
  Map<String, dynamic> toJson() => {'hafta': hafta, 'blok': blok, 'deload': deload, 'rir': rir, 'set_carpani': setCarpani, 'not': not};
  factory Hafta.fromJson(Map j) => Hafta(j['hafta'], j['blok'], j['deload'] == true, j['rir'], (j['set_carpani'] as num).toDouble(), j['not'] ?? '');
}

class Kardiyo {
  Kardiyo(this.baslangicDk, this.hedefDk, this.sporSayilanDk, this.gunSayisi, this.gunBasinaDk);
  final int baslangicDk, hedefDk, sporSayilanDk, gunSayisi;
  final List<int> gunBasinaDk;
  Map<String, dynamic> toJson() => {'baslangic_dk': baslangicDk, 'hedef_dk': hedefDk, 'spor_sayilan_dk': sporSayilanDk, 'gun_sayisi': gunSayisi, 'gun_basina_dk': gunBasinaDk};
  factory Kardiyo.fromJson(Map j) => Kardiyo(j['baslangic_dk'], j['hedef_dk'], j['spor_sayilan_dk'], j['gun_sayisi'], List<int>.from(j['gun_basina_dk']));
}

class Plan {
  Plan({
    this.durdur,
    this.saglik = const {},
    this.saglikAciklama = const [],
    this.donut,
    this.tablo = '',
    this.hedefSet = const {},
    this.eksikSet = const {},
    this.seansSayisi = const {},
    this.azFrekans = const [],
    this.takvim = const [],
    this.haftalar = const [],
    this.blok2 = const [],
    this.kardiyo,
    this.pliometriNotu,
    this.degisen = const {},
    this.oneriler = const [],
  });
  final String? durdur;
  final Map<String, double> saglik;
  final List<String> saglikAciklama;
  final Donut? donut;
  final String tablo;
  final Map<String, int> hedefSet;
  final Map<String, double> eksikSet;
  final Map<String, int> seansSayisi;
  final List<String> azFrekans;
  final List<GunPlan> takvim;
  final List<Hafta> haftalar;
  final List<(int, String, String)> blok2; // gün, eski, yeni
  final Kardiyo? kardiyo;
  final String? pliometriNotu;
  final Map<String, (String, List<String>)> degisen;
  final List<String> oneriler;

  /// Uygulamada saklanan biçim (program sayfaları bundan kurulur).
  Map<String, dynamic> toJson() => {
        'takvim': [for (final g in takvim) g.toJson()],
        'haftalar': [for (final h in haftalar) h.toJson()],
        'blok2': [for (final (g, e, y) in blok2) {'gun': g, 'eski': e, 'yeni': y}],
        'kardiyo': kardiyo?.toJson(),
        'hedef_set': hedefSet,
        'pliometri_notu': pliometriNotu,
        'oneriler': oneriler,
      };
}

class Girdi {
  Girdi({
    required this.seviye,
    required this.cinsiyet,
    this.rahatsizliklar = const [],
    required this.amaclar,
    required this.ortamlar,
    required this.gunler,
    this.sporGunleri = const {},
    this.ekKaslar = const [],
    this.ekipman,
    this.ay = 1,
    this.kirmiziBayrak = false,
  });
  final int seviye;
  final String cinsiyet;
  final List<Rahatsizlik> rahatsizliklar;
  final List<String> amaclar, ortamlar;
  final List<int> gunler; // 0 = Pazartesi
  final Map<int, String> sporGunleri;
  final List<String> ekKaslar;
  final List<String>? ekipman;
  final int ay;
  final bool kirmiziBayrak;

  Map<String, dynamic> toJson() => {
        'seviye': seviye,
        'cinsiyet': cinsiyet,
        'rahatsizliklar': [for (final r in rahatsizliklar) r.toJson()],
        'amaclar': amaclar,
        'ortamlar': ortamlar,
        'gunler': gunler,
        'spor_gunleri': {for (final e in sporGunleri.entries) '${e.key}': e.value},
        'ek_kaslar': ekKaslar,
        if (ekipman != null) 'ekipman': ekipman,
        'ay': ay,
      };

  factory Girdi.fromJson(Map j) => Girdi(
        seviye: j['seviye'],
        cinsiyet: j['cinsiyet'],
        rahatsizliklar: [for (final r in j['rahatsizliklar'] ?? const []) Rahatsizlik.fromJson(r)],
        amaclar: List<String>.from(j['amaclar']),
        ortamlar: List<String>.from(j['ortamlar']),
        gunler: List<int>.from(j['gunler']),
        sporGunleri: {for (final e in ((j['spor_gunleri'] as Map?) ?? const {}).entries) int.parse('${e.key}'): '${e.value}'},
        ekKaslar: List<String>.from(j['ek_kaslar'] ?? const []),
        ekipman: j['ekipman'] == null ? null : List<String>.from(j['ekipman']),
        ay: j['ay'] ?? 1,
      );
}

Plan programUret(Girdi g, {DateTime? bugun}) {
  if (g.kirmiziBayrak) return Plan(durdur: 'Kırmızı bayrak işaretlendi: program çıkarılmaz. Lütfen bir doktora başvurun.');
  final b = Bilgi.b;
  for (final a in g.amaclar) {
    if (!b.spor.containsKey(a)) throw ArgumentError('bilinmeyen amaç: $a');
  }
  final spor = g.sporGunleri;
  final seviye = g.seviye;
  final (saglik, saglikAciklama) = bolgeSagligi(g.rahatsizliklar, bugun ?? DateTime.now());
  final don = kasDonutu(g.amaclar, g.cinsiyet, seviye, saglik);
  final (hedef, tablo) = haftalikIhtiyac(g.amaclar, seviye, don, saglik, ekKaslar: g.ekKaslar, sporVar: spor.isNotEmpty);
  final prio = {for (final k in hedef.keys) k: 1.0};
  for (final (bl, w) in don.gerekli) {
    if (prio.containsKey(bl)) prio[bl] = 0.5 + w / 2;
  }
  for (final (bl, _, _) in don.kacin) {
    prio[bl] = 0.0;
  }
  final toparlanma = {for (final e in b.bolge.entries) e.key: ((e.value['toparlanma_saat'] as List)[1] as num).toInt()};
  final (yapi, fazla) = gunYapisi([for (final x in g.gunler) if (!spor.containsKey(x)) x], seviye);
  final (uygun, degisen) = havuz(saglik, seviye, g.ortamlar, g.ekipman);
  final anahtar = [for (final a in g.amaclar) ..._sl(b.spor[a]!['anahtar_hareketler'])];

  var sonTur1 = <String, int>{};
  var kalan = <String, double>{};
  var gunluk = <GunPlan>[];
  for (var tur = 0; tur < 2; tur++) {
    kalan = {for (final e in hedef.entries) e.key: e.value.toDouble()};
    final son = tur == 0 ? <String, int>{} : {for (final e in sonTur1.entries) e.key: e.value - 7};
    final kullanilan = <String>{};
    gunluk = [];
    for (var i = 0; i < yapi.length; i++) {
      final (gun, od) = yapi[i];
      final kalanFirsat = {for (final bl in hedef.keys) bl: yapi.sublist(i).where((x) => odak[x.$2]!.contains(bl)).length};
      final ertesiSpor = spor.containsKey((gun + 1) % 7);
      final hs = _seansKur(gun, od, seviye, uygun, prio, kalan, son, toparlanma, kalanFirsat, anahtar, kullanilan, g.amaclar, ertesiSpor);
      kullanilan.addAll(hs.map((r) => r.hareket));
      gunluk.add(GunPlan(gun: gun, tur: 'kuvvet', odak: od, hareketler: hs, pliometri: [], not: ertesiSpor ? 'Ertesi gün spor: alt vücut orta (≥2 RIR, tükenişe gitme).' : ''));
    }
    sonTur1 = Map.of(son);
  }

  String? pliometriNotu;
  if (g.amaclar.any(_gucAmac.contains)) {
    if (['diz', 'ayak_bilegi', 'kalca_eklemi'].any((x) => bant(saglik[x]!) != 'tam')) {
      pliometriNotu = 'Diz/ayak bileği/kalça tam sağlıkta değil: pliometri verilmedi.';
    } else if (spor.isNotEmpty && spor.values.any(sicramaliSpor.contains)) {
      pliometriNotu = 'Spor antrenmanında zaten sıçrama var: salonda ek pliometri verilmedi.';
    } else {
      final sirali = uygun.keys.toList()..sort();
      final adaylar = <String>[];
      for (final h in [...anahtar, ...sirali]) {
        if (uygun.containsKey(h) && b.hareket[h]!['kategori'] == 'pliometri' && (b.hareket[h]!['seviye'] as num) <= seviye && !adaylar.contains(h)) adaylar.add(h);
      }
      final plio = <int>[];
      for (final gp in gunluk) {
        if (!{'tum', 'alt', 'bacak'}.contains(gp.odak) || plio.length >= 2 || adaylar.isEmpty) continue;
        if (plio.any((p) => aralikSaat(p, gp.gun) < 48 || aralikSaat(gp.gun, p) < 48)) continue;
        final uyan = [for (final h in adaylar) if (_ana(b.hareket[h]!).difference(odak[gp.odak]!).isEmpty) h];
        if (uyan.isEmpty) continue;
        final h = uyan[plio.length % uyan.length];
        gp.pliometri = [recete(h, 3, seviye, g.amaclar)];
        plio.add(gp.gun);
      }
    }
  }
  for (final gp in gunluk) {
    gp.sureDk = seansSuresi([...gp.pliometri, ...gp.hareketler]);
  }

  final takvim = <int, GunPlan>{for (final gp in gunluk) gp.gun: gp};
  for (final e in spor.entries) {
    takvim[e.key] = GunPlan(gun: e.key, tur: 'spor', amac: e.value);
  }
  for (final x in fazla) {
    takvim[x] = GunPlan(gun: x, tur: 'kardiyo_mobilite', not: 'Seviyenin kuvvet günü sınırı aşıldı: bu gün orta tempolu kardiyo ya da mobilite.');
  }

  final kh = b.program['kardiyo_hedefi'] as Map;
  Kardiyo? kardiyo;
  if (g.amaclar.any(kardiyoAmac.contains)) {
    final lo = (kh['orta_dk_hafta'][0] as num).toInt(), hi = (kh['orta_dk_hafta'][1] as num).toInt();
    final son = g.amaclar.contains('kilo_verme') ? hi : (seviye == 1 ? lo : (lo + hi) ~/ 2);
    final sporDk = 60 * spor.length;
    kardiyo = Kardiyo(lo, son, sporDk, 5, [(math.max(0, lo - sporDk) / 5).ceil(), (math.max(0, son - sporDk) / 5).ceil()]);
  }

  final mz = b.program['mezosiklus'] as Map;
  final rirDizi = mz['blok_ici_ilerleme']['rir']['$seviye'] as List;
  final haftalar = <Hafta>[];
  for (var w = 1; w <= 4 * g.ay; w++) {
    final blok = (w - 1) ~/ 4 + 1, i = (w - 1) % 4;
    final r = rirDizi[i];
    final deload = r == 'deload' || (seviye == 2 && w == 8);
    if (deload) {
      haftalar.add(Hafta(w, blok, true, 3, 0.5, 'Deload: setler yarıya, RIR ≥3; hareketler ve günler aynı.'));
      continue;
    }
    final not = <String>[];
    if (w == 1) {
      not.add('Teknik haftası: yükü rahat seç${seviye == 1 ? ', hareket başına 1–2 set' : ''}');
    } else if (i > 0) {
      not.add('Bir önceki haftaya göre +1 tekrar; tekrar aralığının üstüne çıkınca yük +%2,5–5 (çift ilerleme)');
    }
    if (blok == 2 && i == 0) not.add('Yeni blok: test iyiyse kas başına haftalık set +%10–20; 1–2 yardımcı hareket değişir');
    if (i == 3 || (seviye == 2 && w == 7)) not.add('Blok sonu testi: ana hareketlerde aynı yükle tekrar sayısı, ağrı puanları yeniden girilir');
    haftalar.add(Hafta(w, blok, false, (r as num).toInt(), (seviye == 1 && w == 1) ? 0.5 : 1.0, not.join('; ')));
  }

  final blok2 = <(int, String, String)>[];
  if (g.ay == 2) {
    for (final gp in gunluk) {
      for (final r in gp.hareketler.reversed) {
        if (_bilesik.contains(r.kategori) && {'squat', 'mentese', 'itme_yatay', 'cekme_dikey'}.contains(r.kategori)) continue;
        final a = _sl(b.hareket[r.hareket]!['alternatif']).where((x) => uygun.containsKey(x) && !gp.hareketler.any((y) => y.hareket == x)).firstOrNull;
        if (a != null) {
          blok2.add((gp.gun, r.hareket, a));
          break;
        }
      }
    }
  }

  final seansSayisi = {
    for (final bl in hedef.keys) bl: gunluk.where((gp) => gp.hareketler.any((r) => (_yuk(b.hareket[r.hareket]!)[bl] ?? 0) >= 0.5)).length
  };
  final azFrekans = [for (final e in seansSayisi.entries) if (e.value < 2 && gunluk.length >= 2 && (prio[e.key] ?? 0) >= 0.85) e.key];
  final eksik = {for (final e in kalan.entries) if (e.value >= 2) e.key: (e.value * 10).roundToDouble() / 10};
  final oneriler = <String>[];
  if (eksik.isNotEmpty) {
    oneriler.add('${eksik.length} kas grubunun haftalık hedefi bu günlerle tam karşılanmıyor; ${gunluk.length < 4 ? 'bir kuvvet günü eklemek dağılımı düzeltir.' : 'hedefler alt uçta tutuldu.'}');
  }
  if (gunluk.length == 1) oneriler.add("Haftada tek kuvvet seansı WHO'nun ≥2 gün önerisini karşılamaz.");

  final gunlerSirali = takvim.keys.toList()..sort();
  return Plan(
    saglik: saglik,
    saglikAciklama: saglikAciklama,
    donut: don,
    tablo: tablo,
    hedefSet: hedef,
    eksikSet: eksik,
    seansSayisi: seansSayisi,
    azFrekans: azFrekans,
    takvim: [for (final x in gunlerSirali) takvim[x]!],
    haftalar: haftalar,
    blok2: blok2,
    kardiyo: kardiyo,
    pliometriNotu: pliometriNotu,
    degisen: degisen,
    oneriler: oneriler,
  );
}

/// Kas başına gereken seans sayısı (seans_kas = max(2, tavan(set / seans tavanı))) ve önerilen gün sayısı.
(int, Map<String, int>) gerekenSeans(Map<String, int> hedef, int seviye) {
  final tavan = (Bilgi.b.program['seans_basina_set_siniri']['hipertrofi_fractional_ust']['$seviye'] as num).toDouble();
  final m = {for (final e in hedef.entries) e.key: math.max(2, (e.value / tavan).ceil())};
  final enCok = m.values.fold(2, math.max);
  return (enCok, m);
}
