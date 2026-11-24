// Kurulum akışının ürettiği planı uygulamanın program yapısına (ProgramData) çevirir.
// Bugün / Program / İlerleme ekranları sabit programla nasıl çalışıyorsa üretilen planla da öyle çalışır.
import 'data.dart';
import 'lang.dart';
import 'motor.dart';

const odakAd = {'tum': 'Tüm vücut', 'ust': 'Üst vücut', 'alt': 'Alt vücut', 'itme': 'İtme', 'cekme': 'Çekme', 'bacak': 'Bacak'};

/// Motorun ürettiği Türkçe notları (noktalı virgülle birleşik olabilir) arayüz diline çevirir.
String motorMetni(String s) {
  if (s.isEmpty) return s;
  final m = RegExp(r'^(\d+) kas grubunun haftalık hedefi bu günlerle tam karşılanmıyor; (.*)$').firstMatch(s);
  if (m != null) return trf('{0} kas grubunun haftalık hedefi bu günlerle tam karşılanmıyor; {1}', [m[1], tr(m[2]!)]);
  return s.split('; ').map(tr).join('; ');
}

String _tekrar(String t) {
  if (!Lang.en) return t;
  return t.replaceAll(' (yavaş iniş)', ' (slow lowering)').replaceAll(' sn', ' s').replaceAll(' ya da ', ' or ');
}

/// Haftanın bir dozu: "3×6–10 · RIR 2". Deload ve teknik haftasında set sayısı azalır.
String _doz(Recete r, Hafta h) {
  final set = h.setCarpani < 1 ? (r.set * h.setCarpani).round().clamp(1, r.set) : r.set;
  final rir = r.kategori == 'pliometri' ? tr('patlayıcı, tam dinlen') : 'RIR ${r.hafif ? (h.rir < 2 ? 2 : h.rir) : h.rir}';
  final ek = [if (r.agriIzle) tr('ağrı izle'), if (r.hafif) tr('tükenişe gitme')];
  return ['$set×${_tekrar(r.tekrar)}', rir, ...ek].join(' · ');
}

Map<int, String> planSchedule(Map plan) => {
      for (final g in (plan['takvim'] as List).cast<Map>())
        if (g['tur'] == 'kuvvet') (g['gun'] as int) + 1: 'gun${g['gun']}',
    };

ProgramData planToProgram(Map plan) {
  final haftalar = [for (final h in plan['haftalar'] as List) Hafta.fromJson(h)];
  final takvim = [for (final g in plan['takvim'] as List) GunPlan.fromJson(g)];
  final blok2 = [for (final c in (plan['blok2'] as List? ?? const [])) (c['gun'] as int, c['eski'] as String, c['yeni'] as String)];
  final b = Bilgi.b;

  final phases = [
    for (final h in haftalar)
      Phase('${h.hafta}', h.deload ? tr('Deload') : trf('Blok {0}', [h.blok]), h.deload ? 'RIR 3+' : 'RIR ${h.rir}', motorMetni(h.not)),
  ];
  final weekPhase = [for (var w = 0; w < 12; w++) w < haftalar.length ? w : haftalar.length - 1];

  List<String?> dozlar(Recete r, {bool sadeceBlok1 = false, bool sadeceBlok2 = false}) => [
        for (final h in haftalar)
          (sadeceBlok1 && h.blok > 1) || (sadeceBlok2 && h.blok == 1) ? null : _doz(r, h),
      ];

  Map<String, dynamic> slot(Recete r, int no, {bool b1 = false, bool b2 = false}) => {
        'id': b.katalogId(r.hareket),
        'no': '$no',
        'n': r.ad,
        'd': dozlar(r, sadeceBlok1: b1, sadeceBlok2: b2),
        'cue': '',
        'g': [if (r.kategori == 'pliometri') 'guc', if (r.agriIzle) 'agri', if (r.hafif) 'hafif'],
        'isNew': b2,
      };

  final days = <Day>[];
  final pliometriVar = takvim.any((g) => g.pliometri.isNotEmpty);
  days.add(Day.fromJson({
    'id': 'isinma',
    'tag': tr('Her gün'),
    'title': tr('Isınma'),
    'sub': tr('5–10 dk: önce hafif tempolu yürüyüş ya da bisiklet, sonra bunlar'),
    'items': [
      {'id': 'arm_circles', 'no': '1', 'n': 'Kol çevirme', 'd': tr('1×10 her yön')},
      {'id': 'legswing', 'no': '2', 'n': 'Bacak savurma', 'd': tr('1×10 her bacak')},
      {'id': 'worlds_greatest_stretch', 'no': '3', 'n': "World's greatest stretch", 'd': tr('1×5 her taraf')},
      {'id': 'air_squat', 'no': '4', 'n': 'Vücut ağırlığıyla squat', 'd': '1×10'},
      if (pliometriVar) {'id': 'ankle', 'no': '5', 'n': 'Ayak bileği mobilitesi', 'd': tr('1×10 her bacak')},
    ],
  }));
  for (final g in takvim.where((g) => g.tur == 'kuvvet')) {
    var no = 0;
    final items = <Map<String, dynamic>>[];
    for (final r in [...g.pliometri, ...g.hareketler]) {
      no++;
      final degisim = blok2.where((c) => c.$1 == g.gun && c.$2 == r.hareket).firstOrNull;
      if (degisim == null) {
        items.add(slot(r, no));
      } else {
        items.add(slot(r, no, b1: true));
        final yeni = recete(degisim.$3, r.set, 1, const []); // yalnız ad ve kategori; doz eskisinden
        items.add(slot(Recete(degisim.$3, yeni.ad, r.set, r.tekrar, r.dinlenmeSn, r.hafif, r.agriIzle, r.kategori), no, b2: true));
      }
    }
    days.add(Day.fromJson({
      'id': 'gun${g.gun}',
      'tag': tr(gunKisa[g.gun]),
      'title': tr(odakAd[g.odak] ?? g.odak ?? ''),
      'sub': [trf('~{0} dk', [g.sureDk]), if (g.not.isNotEmpty) motorMetni(g.not)].join(' · '),
      'items': items,
    }));
  }
  days.add(Day.fromJson({
    'id': 'soguma',
    'tag': tr('Her gün'),
    'title': tr('Soğuma'),
    'sub': tr('5 dk hafif hareket ve esneme'),
    'items': [
      {'id': 'hamstr', 'no': '1', 'n': 'Arka bacak esnetme', 'd': tr('1×30 sn her bacak')},
      {'id': 'hipflexor', 'no': '2', 'n': 'Kalça ön esnetme', 'd': tr('1×30 sn her taraf')},
      {'id': 'doorway_chest_stretch', 'no': '3', 'n': 'Kapıda göğüs esnetme', 'd': tr('1×30 sn')},
      {'id': 'child_pose', 'no': '4', 'n': 'Çocuk pozu', 'd': tr('1×45 sn')},
    ],
  }));
  return ProgramData(phases, weekPhase, days, {'guc': tr('Patlayıcı'), 'agri': tr('Ağrı izle'), 'hafif': tr('Spordan önce: orta')});
}
