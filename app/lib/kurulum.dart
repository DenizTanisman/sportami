// Kurulum akışı: uyarı → profil → PAR-Q → rahatsızlıklar → amaçlar → kas dönütü → haftalık ihtiyaç
// → lojistik → süre → program. Bütün yanıtlar yalnız bu telefonda (saha.json) kalır.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'body_map.dart';
import 'data.dart';
import 'lang.dart';
import 'motor.dart';
import 'plan_program.dart';
import 'theme.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// İçerik dili: bilgi tabanının İngilizcesi en.json → "bilgi" altında.
// ---------------------------------------------------------------------------

Map? _bilgiEn(String tur, String id) {
  final b = Lang.content['bilgi'];
  if (!Lang.en || b is! Map) return null;
  final t = b[tur];
  return t is Map && t[id] is Map ? t[id] as Map : null;
}

String _bilgiAd(String tur, String id, String tr) {
  if (!Lang.en) return tr;
  final b = Lang.content['bilgi'];
  if (b is! Map) return tr;
  final t = b[tur];
  final v = t is Map ? t[id] : null;
  if (v is String) return v;
  if (v is Map && v['ad'] is String) return v['ad'];
  return tr;
}

String bolgeAd(String id) => _bilgiAd('bolge', id, Bilgi.b.bolge[id]?['ad'] ?? id);
String sporAd(String id) => _bilgiAd('spor', id, Bilgi.b.spor[id]?['ad'] ?? id);
String rahatsizlikAd(String id) => _bilgiAd('rahatsizlik', id, Bilgi.b.rahatsizlik[id]?['ad'] ?? id);

String _dereceAd(String kod) {
  if (Lang.en) {
    final b = Lang.content['bilgi'];
    final d = b is Map ? b['derece_kodu'] : null;
    if (d is Map && d[kod] is String) return d[kod];
  }
  if (RegExp(r'^\d$').hasMatch(kod)) return trf('{0}. derece', [kod]);
  final tr = _dereceTr[kod];
  if (tr != null) return tr;
  final s = kod.replaceAll('_', ' ');
  return s[0].toUpperCase() + s.substring(1);
}

String _dereceTanim(String rid, String kod, String tr) {
  final v = _bilgiEn('rahatsizlik', rid)?['dereceler'];
  return v is Map && v[kod] is String ? v[kod] : tr;
}

List<String> _bayraklar(String rid) {
  final tr = [for (final x in (Bilgi.b.rahatsizlik[rid]?['kirmizi_bayraklar'] as List? ?? const [])) '$x'];
  final en = _bilgiEn('rahatsizlik', rid)?['kirmizi_bayraklar'];
  return pickList(tr, en);
}

List<String> _parq() {
  final tr = [for (final x in Bilgi.b.kurallar['parq'] as List) '$x'];
  final b = Lang.content['bilgi'];
  return pickList(tr, b is Map ? b['parq'] : null);
}

(String, String) _seviyeTanim(int s) {
  final d = (Bilgi.b.kurallar['seviye_tanimlari'] as Map)['$s'] as Map;
  final b = Lang.content['bilgi'];
  final en = (Lang.en && b is Map && b['seviye'] is Map) ? (b['seviye'] as Map)['$s'] as Map? : null;
  return (pick(d['ad'], en?['ad']), pick(d['tanim'], en?['tanim']));
}

/// Kodu Türkçe karakter içeren derece etiketleri.
const _dereceTr = {
  '3_ameliyatli': '3. derece, ameliyatlı',
  '3_ameliyatsiz': '3. derece, ameliyatsız',
  'agir_ya_da_ameliyat': 'Ağır ya da ameliyat',
  'akut_travmatik_ya_da_ameliyatli': 'Akut travmatik ya da ameliyatlı',
  'cozulme_evresi': 'Çözülme evresi',
  'donmus_evre': 'Donmuş evre',
  'dusuk_riskli': 'Düşük riskli',
  'enerji_depolama_ve_kosu': 'Enerji depolama ve koşu',
  'evre_1': '1. evre',
  'evre_1_izometrik': '1. evre: izometrik',
  'evre_2': '2. evre',
  'evre_2_izotonik': '2. evre: izotonik',
  'evre_3_enerji_depolama': '3. evre: enerji depolama',
  'evre_3_kismi_yirtik': '3. evre: kısmi yırtık',
  'evre_4_spora_donus': '4. evre: spora dönüş',
  'hafif_aralikli': 'Hafif, aralıklı',
  'ilk_tam_cikik': 'İlk tam çıkık',
  'instabil': 'İnstabil',
  'kisa_sureli': 'Kısa süreli',
  'kismi': 'Kısmi',
  'kismi_cikik': 'Kısmi çıkık',
  'kismi_kalinlik': 'Kısmi kalınlık',
  'kola_yayilan': 'Kola yayılan',
  'kramp_sonrasi_agri': 'Kramp sonrası ağrı',
  'menisektomi_sonrasi': 'Menisektomi sonrası',
  'onarim_sonrasi': 'Onarım sonrası',
  'orta_surekli': 'Orta, sürekli',
  'reaktif_yuksek_agri': 'Reaktif, yüksek ağrı',
  'siddetli': 'Şiddetli',
  'siddetli_alevlenme': 'Şiddetli alevlenme',
  'suregen': 'Süregen',
  'tam_ameliyatli': 'Tam, ameliyatlı',
  'tam_ameliyatsiz': 'Tam, ameliyatsız',
  'tam_kat_kucuk_orta': 'Tam kat, küçük–orta',
  'tip_1': 'Tip 1',
  'tip_2': 'Tip 2',
  'tip_3': 'Tip 3',
  'tip_4_6': 'Tip 4–6',
  'travmatik_ameliyatsiz': 'Travmatik, ameliyatsız',
  'uzun_suren': 'Uzun süren',
  'yeni_baslayan': 'Yeni başlayan',
  'yuk_toleransi': 'Yük toleransı',
  'yuksek_riskli': 'Yüksek riskli',
};

// Rahatsızlıkları vücut bölümüne göre grupla.
const _grupSirasi = ['Bel, sırt ve boyun', 'Omuz', 'Dirsek ve el bileği', 'Göğüs', 'Kalça ve kasık', 'Uyluk', 'Diz', 'Baldır, kaval ve ayak', 'Kas ağrısı, kramp, ezilme'];
String _grup(Map r) {
  if (r['etki_modeli'] == 'secilen_kas') return 'Kas ağrısı, kramp, ezilme';
  switch (r['bolge']) {
    case 'bel_omurgasi':
    case 'sirt_omurgasi':
    case 'boyun_omurgasi':
      return 'Bel, sırt ve boyun';
    case 'omuz_eklemi':
    case 'rotator_manset':
      return 'Omuz';
    case 'dirsek':
    case 'el_bilegi':
      return 'Dirsek ve el bileği';
    case 'gogus':
      return 'Göğüs';
    case 'kalca_eklemi':
    case 'ic_bacak':
    case 'kalca_on':
      return 'Kalça ve kasık';
    case 'arka_bacak':
    case 'on_bacak':
      return 'Uyluk';
    case 'diz':
      return 'Diz';
    default:
      return 'Baldır, kaval ve ayak';
  }
}

const _yaslar = ['18 altı', '18–29', '30–44', '45–64', '65+'];
const _ortamlar = [('salon', 'Spor salonu'), ('ev', 'Ev'), ('dis_mekan', 'Dış mekân')];
const _ekipmanlar = [
  ('dambil', 'Dumbbell'),
  ('direnc_bandi', 'Direnç bandı'),
  ('kettlebell', 'Kettlebell'),
  ('barfiks_bari', 'Barfiks barı'),
  ('bench', 'Sehpa'),
  ('kutu_basamak', 'Kutu / basamak'),
  ('trx', 'TRX'),
  ('saglik_topu', 'Sağlık topu'),
  ('atlama_ipi', 'Atlama ipi'),
  ('barbell', 'Barbell'),
];

class _R {
  _R(this.id);
  final String id;
  int agri = 3;
  String? derece;
  int gunOnce = 7;
  String? bolge;
  final Set<int> bayrak = {};

  /// Şiddetli ağrı (≥8/10, Boonstra 2016): uzman onayı olmadan program çıkmaz.
  bool uzmanOnay = false;
  bool get siddetli => agri >= 8;
  Map get veri => Bilgi.b.rahatsizlik[id]!;
  bool get agriIle => veri['agri_ile_puanlanir'] == true;
  bool get secilenKas => veri['etki_modeli'] == 'secilen_kas';
  bool get tamam => (agriIle || derece != null) && (!secilenKas || bolge != null) && (!siddetli || uzmanOnay);

  Rahatsizlik girdi(DateTime bugun) => Rahatsizlik(id,
      agri: agri, derece: derece, tarih: derece == null ? null : bugun.subtract(Duration(days: gunOnce)), bolge: secilenKas ? bolge : null);
}

enum _Adim { uyari, profil, parq, rahatsizlik, amac, donut, ihtiyac, lojistik, sure, sonuc }

class KurulumAkisi extends StatefulWidget {
  const KurulumAkisi({super.key, this.ilk = false});

  /// İlk açılış: geri düğmesi yok, bitince uygulama açılır.
  final bool ilk;

  @override
  State<KurulumAkisi> createState() => _KurulumAkisiState();
}

class _KurulumAkisiState extends State<KurulumAkisi> {
  final _sayfa = PageController();
  var _adim = _Adim.uyari;

  var _onay = false;
  String _cinsiyet = 'kadin';
  String? _yas;
  int? _seviye;
  final _parqCevap = List<bool?>.filled(7, null);
  var _doktorOnay = false;
  final _rah = <_R>[];
  var _rahYok = false;
  final _amac = <String>{};
  final _ekKas = <String>{};
  final _ortam = <String>{};
  final _ekipman = <String>{};
  final _gun = <int>{};
  final _spor = <int, String>{};
  final _ayniGunUzak = <int>{}; // spor ve kuvvet aynı gün, arada ≥3 saat
  var _gec = false;
  int _ay = 2;
  Plan? _plan;
  Girdi? _girdi;
  String _ara = '';
  final _araKutu = TextEditingController();

  @override
  void initState() {
    super.initState();
    final store = App.ofStore;
    if (store?.acceptedNotice ?? false) _onay = true;
    final p = store?.profile;
    if (p != null) _yukle(p);
  }

  void _yukle(Map p) {
    try {
      final g = Girdi.fromJson(p);
      _cinsiyet = g.cinsiyet;
      _seviye = g.seviye;
      _yas = p['yas'] as String?;
      _amac.addAll(g.amaclar);
      _ekKas.addAll(g.ekKaslar);
      _ortam.addAll(g.ortamlar);
      _ekipman.addAll(g.ekipman ?? const []);
      _gun.addAll(g.gunler);
      _spor.addAll(g.sporGunleri);
      _ay = g.ay;
      _gec = p['gec'] == true;
      final pq = p['parq'] as List?;
      if (pq != null) {
        for (var i = 0; i < 7 && i < pq.length; i++) {
          _parqCevap[i] = pq[i] as bool?;
        }
      }
      _doktorOnay = p['doktor_onay'] == true;
      // Rahatsızlıklar her seferinde yeniden sorulur: ağrı ve iyileşme değişir.
    } catch (_) {}
  }

  @override
  void dispose() {
    _sayfa.dispose();
    _araKutu.dispose();
    super.dispose();
  }

  List<_Adim> get _adimlar => _Adim.values;
  int get _i => _adimlar.indexOf(_adim);

  bool get _parqEvet => [for (var i = 0; i < 7; i++) if (i != 5 && _parqCevap[i] == true) i].isNotEmpty;
  bool get _bayrak => _rah.any((r) => r.bayrak.isNotEmpty);

  bool get _gecerli {
    switch (_adim) {
      case _Adim.uyari:
        return _onay;
      case _Adim.profil:
        return _yas != null && _seviye != null;
      case _Adim.parq:
        return !_parqCevap.contains(null) && (!_parqEvet || _doktorOnay);
      case _Adim.rahatsizlik:
        return !_bayrak && (_rahYok || (_rah.isNotEmpty && _rah.every((r) => r.tamam)));
      case _Adim.amac:
        return _amac.isNotEmpty;
      case _Adim.donut:
      case _Adim.ihtiyac:
        return true;
      case _Adim.lojistik:
        return _ortam.isNotEmpty && _kuvvetGunleri.isNotEmpty;
      case _Adim.sure:
        return true;
      case _Adim.sonuc:
        return _plan != null && _plan!.durdur == null;
    }
  }

  /// Kuvvet günleri: aynı gün spor varsa yalnız arada ≥3 saat olacaksa kuvvet kalır.
  List<int> get _kuvvetGunleri => [for (final g in _gun.toList()..sort()) if (!_spor.containsKey(g) || _ayniGunUzak.contains(g)) g];

  Girdi _girdiKur() => Girdi(
        seviye: _seviye ?? 1,
        cinsiyet: _cinsiyet,
        rahatsizliklar: [for (final r in _rah) r.girdi(DateTime.now())],
        amaclar: _amac.toList(),
        ortamlar: _ortam.toList(),
        gunler: _kuvvetGunleri,
        sporGunleri: {for (final e in _spor.entries) if (!_ayniGunUzak.contains(e.key)) e.key: e.value},
        ekKaslar: _ekKas.toList(),
        ekipman: _ortam.contains('salon') || _ekipman.isEmpty ? null : _ekipman.toList(),
        ay: _ay,
      );

  (Map<String, double>, Donut) get _durum {
    final (s, _) = bolgeSagligi([for (final r in _rah) r.girdi(DateTime.now())], DateTime.now());
    return (s, kasDonutu(_amac.toList(), _cinsiyet, _seviye ?? 1, s));
  }

  void _ileri() {
    if (!_gecerli) return;
    HapticFeedback.selectionClick();
    final store = App.ofStore;
    if (_adim == _Adim.uyari && store != null && !store.acceptedNotice) store.acceptNotice();
    if (_adim == _Adim.sure) {
      _girdi = _girdiKur();
      _plan = programUret(_girdi!);
    }
    if (_adim == _Adim.sonuc) {
      _bitir();
      return;
    }
    _git(_i + 1);
  }

  void _git(int i) {
    setState(() => _adim = _adimlar[i]);
    _sayfa.animateToPage(i, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  void _bitir() {
    final store = App.ofStore!;
    store.savePlan(_girdi!, _plan!, {
      'yas': _yas,
      'parq': _parqCevap,
      'doktor_onay': _doktorOnay,
      'gec': _gec,
      'rahatsizlik_ozet': [for (final r in _rah) r.girdi(DateTime.now()).toJson()],
    });
    if (!widget.ilk && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top, bottom = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: _i == 0 && !widget.ilk,
      onPopInvokedWithResult: (did, _) {
        if (!did && _i > 0) _git(_i - 1);
      },
      child: Scaffold(
        backgroundColor: C.bg,
        body: Column(children: [
          SizedBox(height: top + 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              if (_i > 0 || !widget.ilk)
                IconButton(
                  onPressed: () => _i > 0 ? _git(_i - 1) : Navigator.of(context).maybePop(),
                  icon: Icon(_i > 0 ? CupertinoIcons.chevron_back : CupertinoIcons.xmark, color: C.text2),
                )
              else
                const SizedBox(width: 48),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (_i + 1) / _adimlar.length),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 4, backgroundColor: C.surface3, valueColor: const AlwaysStoppedAnimation(C.accent)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${_i + 1}/${_adimlar.length}', style: T.caption),
              const SizedBox(width: 10),
              const DilDugmesi(),
              const SizedBox(width: 8),
            ]),
          ),
          Expanded(
            child: PageView(
              controller: _sayfa,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _sayfaKur(_uyari()),
                _sayfaKur(_profil()),
                _sayfaKur(_parqSayfa()),
                _sayfaKur(_rahatsizlik()),
                _sayfaKur(_amacSayfa()),
                _sayfaKur(_donutSayfa()),
                _sayfaKur(_ihtiyacSayfa()),
                _sayfaKur(_lojistik()),
                _sayfaKur(_sureSayfa()),
                _sayfaKur(_sonuc()),
              ],
            ),
          ),
          Glass(
            child: Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
              child: PrimaryButton(
                label: switch (_adim) {
                  _Adim.uyari => tr('Okudum, devam et'),
                  _Adim.sure => tr('Programı oluştur'),
                  _Adim.sonuc => tr('Programı başlat'),
                  _ => tr('Devam'),
                },
                icon: _adim == _Adim.sonuc ? CupertinoIcons.play_fill : null,
                onTap: _gecerli ? _ileri : null,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sayfaKur(List<Widget> cocuklar) => ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 40), children: cocuklar);

  Widget _baslik(String ust, String baslik, [String? alt]) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(trUpper(ust), style: T.overline.copyWith(color: C.accent)),
          const SizedBox(height: 6),
          Text(baslik, style: T.title1),
          if (alt != null) ...[const SizedBox(height: 8), Text(alt, style: T.callout)],
        ]),
      );

  // ---- 1. Uyarı ----------------------------------------------------------------

  List<Widget> _uyari() => [
        _baslik(tr('Başlamadan önce'), tr('Sana özel program'), tr('Birkaç soruyla ağrılarını, amaçlarını ve zamanını öğrenip araştırmalara dayalı bir program kuracağız.')),
        Panel(
          border: C.yellow.withValues(alpha: 0.35),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: C.yellow, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(tr(uyariMetni), style: t(15, w: 520, h: 1.45))),
          ]),
        ),
        const SizedBox(height: 12),
        _madde(CupertinoIcons.lock_fill, C.green, tr('Verilerin yalnız bu telefonda kalır. Hesap yok, sunucu yok; hiçbir yere gönderilmez.')),
        _madde(CupertinoIcons.book_fill, C.blue, tr('Kurallar yayımlanmış kılavuz ve araştırmalardan gelir: WHO, ACSM, NSCA, spor hekimliği dergileri.')),
        _madde(CupertinoIcons.heart_fill, C.red, tr('Doktora gitmeni gerektiren bir belirti (kırmızı bayrak) varsa program çıkarılmaz.')),
        const SizedBox(height: 14),
        _onayKutusu(_onay, tr('Okudum ve anladım. Bu bir tıbbi tavsiye değildir.'), (v) => setState(() => _onay = v)),
      ];

  Widget _madde(IconData i, Color c, String s) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
            child: Icon(i, color: c, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 5), child: Text(s, style: T.body))),
        ]),
      );

  Widget _onayKutusu(bool v, String s, ValueChanged<bool> f) => Panel(
        onTap: () {
          HapticFeedback.selectionClick();
          f(!v);
        },
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: v ? C.accent.withValues(alpha: 0.5) : null,
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: v ? C.accent : Colors.transparent, borderRadius: BorderRadius.circular(7), border: Border.all(color: v ? C.accent : C.text3, width: 1.6)),
            child: v ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(s, style: t(14.5, w: 560))),
        ]),
      );

  // ---- 2. Profil -----------------------------------------------------------------

  List<Widget> _profil() => [
        _baslik(tr('Profil'), tr('Seni tanıyalım')),
        SectionLabel(tr('Cinsiyet')),
        Segmented<String>(items: [('kadin', tr('Kadın')), ('erkek', tr('Erkek'))], value: _cinsiyet, onChanged: (v) => setState(() => _cinsiyet = v)),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(tr('Araştırmalar kadın ve erkek için aynı reçeteyi önerir; cinsiyet yalnız sporların kas vurgusunu ayarlar.'), style: T.caption),
        ),
        SectionLabel(tr('Yaş')),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final y in _yaslar) _cip(tr(y), _yas == y, () => setState(() => _yas = y))]),
        if (_yas == '18 altı') _not(C.yellow, tr('18 yaş altındaysan programı bir antrenör ya da velinin gözetiminde uygula.')),
        if (_yas == '65+') _not(C.blue, tr('65 yaş üstünde denge çalışması ve haftada en az 3 gün çok bileşenli etkinlik önerilir (WHO).')),
        SectionLabel(tr('Antrenman geçmişin')),
        for (final s in [1, 2, 3]) ...[
          Builder(builder: (_) {
            final (ad, tanim) = _seviyeTanim(s);
            final on = _seviye == s;
            return Panel(
              onTap: () => setState(() => _seviye = s),
              border: on ? C.accent : null,
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: on ? C.accent : C.surface3, shape: BoxShape.circle),
                  child: Text('$s', style: T.num(17, color: on ? Colors.white : C.text2)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ad, style: T.headline),
                    const SizedBox(height: 3),
                    Text(tanim, style: T.callout),
                  ]),
                ),
              ]),
            );
          }),
          const SizedBox(height: 10),
        ],
      ];

  Widget _cip(String s, bool on, VoidCallback f, {bool kapali = false, Color renk = C.accent}) => Opacity(
        opacity: kapali ? 0.4 : 1,
        child: GestureDetector(
          onTap: kapali
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  f();
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: on ? renk.withValues(alpha: 0.16) : C.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? renk : C.line2),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              if (kapali) ...[const Icon(CupertinoIcons.lock_fill, size: 13, color: C.text3), const SizedBox(width: 6)],
              if (on) ...[Icon(Icons.check_rounded, size: 16, color: renk), const SizedBox(width: 5)],
              Text(s, style: t(14, w: on ? 640 : 520, color: on ? C.text : C.text2)),
            ]),
          ),
        ),
      );

  Widget _not(Color c, String s) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.35))),
          child: Text(s, style: t(14, w: 500, h: 1.4)),
        ),
      );

  // ---- 3. PAR-Q ------------------------------------------------------------------

  List<Widget> _parqSayfa() {
    final sorular = _parq();
    return [
      _baslik(tr('Sağlık taraması'), tr('Yedi kısa soru'), tr('PAR-Q+ (2023): egzersize başlamadan önce dünyada kullanılan ön tarama.')),
      for (var i = 0; i < sorular.length; i++) ...[
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sorular[i], style: t(14.5, w: 520, h: 1.4)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _cip(tr('Hayır'), _parqCevap[i] == false, () => setState(() => _parqCevap[i] = false), renk: C.green)),
              const SizedBox(width: 10),
              Expanded(child: _cip(tr('Evet'), _parqCevap[i] == true, () => setState(() => _parqCevap[i] = true), renk: C.yellow)),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
      ],
      if (_parqCevap[5] == true) _not(C.blue, tr('Kemik, eklem ya da kas sorununu bir sonraki adımda seçeceksin; program ona göre ayarlanır.')),
      if (_parqEvet) ...[
        _not(C.yellow, tr('En az bir soruya "evet" dedin. Daha aktif olmadan önce bir doktora ya da uzman egzersiz profesyoneline danışman önerilir.')),
        const SizedBox(height: 12),
        _onayKutusu(_doktorOnay, tr('Doktorum egzersiz yapmama onay verdi.'), (v) => setState(() => _doktorOnay = v)),
      ],
    ];
  }

  // ---- 4. Rahatsızlıklar -----------------------------------------------------------

  List<Widget> _rahatsizlik() {
    final b = Bilgi.b;
    final secili = {for (final r in _rah) r.id};
    final gruplar = <String, List<String>>{};
    for (final e in b.rahatsizlik.entries) {
      final ad = rahatsizlikAd(e.key);
      if (_ara.isNotEmpty && !ad.toLowerCase().contains(_ara.toLowerCase())) continue;
      gruplar.putIfAbsent(_grup(e.value), () => []).add(e.key);
    }
    return [
      _baslik(tr('Rahatsızlıklar'), tr('Şu an bir ağrın ya da sakatlığın var mı?'), tr('Seçtiğin her biri ilgili bölgelerin sağlık puanını düşürür; program bu bölgeleri korur.')),
      _onayKutusu(_rahYok && _rah.isEmpty, tr('Hiçbir ağrım ya da sakatlığım yok'), (v) => setState(() {
            _rahYok = v;
            if (v) _rah.clear();
          })),
      for (final r in _rah) ...[const SizedBox(height: 12), _rahKart(r)],
      if (_bayrak) _not(C.red, tr('Bu belirti bir uzmanın değerlendirmesini gerektiriyor. Program çıkarılmaz; lütfen bir doktora başvur.')),
      const SizedBox(height: 14),
      TextField(
        controller: _araKutu,
        onChanged: (v) => setState(() => _ara = v),
        style: T.body,
        decoration: InputDecoration(
          hintText: tr('Ara: diz, bel, burkulma…'),
          hintStyle: t(15, color: C.text3),
          prefixIcon: const Icon(CupertinoIcons.search, color: C.text3, size: 19),
          filled: true,
          fillColor: C.surface2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      for (final g in _grupSirasi)
        if (gruplar[g] != null) ...[
          SectionLabel(tr(g)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final id in gruplar[g]!)
              _cip(rahatsizlikAd(id), secili.contains(id), () => setState(() {
                    if (secili.contains(id)) {
                      _rah.removeWhere((r) => r.id == id);
                    } else {
                      _rah.add(_R(id));
                      _rahYok = false;
                    }
                  })),
          ]),
        ],
    ];
  }

  Widget _rahKart(_R r) {
    final dereceler = (r.veri['dereceler'] as List).cast<Map>();
    final bayrak = _bayraklar(r.id);
    return Panel(
      border: r.bayrak.isNotEmpty ? C.red : C.accent.withValues(alpha: 0.35),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(rahatsizlikAd(r.id), style: T.headline)),
          GestureDetector(onTap: () => setState(() => _rah.remove(r)), child: const Icon(CupertinoIcons.xmark_circle_fill, color: C.text3, size: 22)),
        ]),
        if (r.secilenKas) ...[
          const SizedBox(height: 12),
          Text(tr('Hangi kas?'), style: T.caption),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in Bilgi.b.bolge.entries)
              if (e.value['tur'] == 'kas') _cip(bolgeAd(e.key), r.bolge == e.key, () => setState(() => r.bolge = e.key)),
          ]),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Text(tr('Ağrı'), style: T.caption),
          const Spacer(),
          Text('${r.agri}/10', style: T.num(17, color: r.agri >= 7 ? C.red : (r.agri >= 4 ? C.yellow : C.green))),
        ]),
        SliderTheme(
          data: SliderThemeData(activeTrackColor: C.accent, inactiveTrackColor: C.surface3, thumbColor: Colors.white, overlayColor: C.accent.withValues(alpha: 0.15), trackHeight: 4),
          child: Slider(value: r.agri.toDouble(), min: 0, max: 10, divisions: 10, onChanged: (v) => setState(() => r.agri = v.round())),
        ),
        Text(tr('Dinlenirken değil, günlük hareketlerde hissettiğin ağrı. 0 = yok, 10 = dayanılmaz.'), style: T.caption),
        if (r.siddetli) ...[
          _not(C.red, tr('Şiddetli ağrı. Bu ağrıyla egzersize başlamadan önce bir doktor ya da fizyoterapist görmelisin; onay almadan program çıkarılmaz.')),
          const SizedBox(height: 10),
          _onayKutusu(r.uzmanOnay, tr('Bir doktor ya da fizyoterapist bu ağrıyla egzersiz yapmamı onayladı.'), (v) => setState(() => r.uzmanOnay = v)),
        ] else if (r.agri >= 6)
          _not(C.yellow, tr('Orta düzeyde ağrı. İlgili hareketler hafifletilir; antrenman sırasında ağrı 5/10\'u geçmemeli ve ertesi sabah artmamalı.')),
        const SizedBox(height: 14),
        Text(r.agriIle ? tr('Derece (biliyorsan)') : tr('Derece'), style: T.caption),
        const SizedBox(height: 8),
        for (final d in dereceler)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SizedBox(width: double.infinity, child: Panel(
              onTap: () => setState(() => r.derece = r.derece == d['derece'] ? null : d['derece']),
              color: C.surface2,
              radius: 14,
              border: r.derece == d['derece'] ? C.accent : null,
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_dereceAd(d['derece']), style: t(14, w: 640, color: r.derece == d['derece'] ? C.accent : C.text)),
                if (d['tanim'] != null) ...[const SizedBox(height: 3), Text(_dereceTanim(r.id, d['derece'], d['tanim']), style: T.caption)],
              ]),
            )),
          ),
        if (r.derece != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(tr('Kaç gün önce başladı / oldu?'), style: T.caption)),
            IconButton(onPressed: () => setState(() => r.gunOnce = (r.gunOnce - (r.gunOnce > 14 ? 7 : 1)).clamp(0, 365)), icon: const Icon(CupertinoIcons.minus_circle, color: C.text2)),
            Text(trf('{0} gün', [r.gunOnce]), style: T.num(16)),
            IconButton(onPressed: () => setState(() => r.gunOnce = (r.gunOnce + (r.gunOnce >= 14 ? 7 : 1)).clamp(0, 365)), icon: const Icon(CupertinoIcons.plus_circle, color: C.text2)),
          ]),
        ],
        if (bayrak.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(tr('Şunlardan biri var mı? (kırmızı bayrak)'), style: t(12.5, w: 650, color: C.red)),
          const SizedBox(height: 6),
          for (var i = 0; i < bayrak.length; i++)
            GestureDetector(
              onTap: () => setState(() => r.bayrak.contains(i) ? r.bayrak.remove(i) : r.bayrak.add(i)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(r.bayrak.contains(i) ? CupertinoIcons.checkmark_square_fill : CupertinoIcons.square, size: 20, color: r.bayrak.contains(i) ? C.red : C.text3),
                  const SizedBox(width: 10),
                  Expanded(child: Text(bayrak[i], style: t(13, color: C.text2, h: 1.35))),
                ]),
              ),
            ),
        ],
      ]),
    );
  }

  // ---- 5. Amaçlar ----------------------------------------------------------------------

  List<Widget> _amacSayfa() {
    final s = Bilgi.b.spor;
    Widget grup(String tur) => Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in s.entries)
            if (e.value['tur'] == tur) _cip(sporAd(e.key), _amac.contains(e.key), () => setState(() => _amac.contains(e.key) ? _amac.remove(e.key) : _amac.add(e.key))),
        ]);
    return [
      _baslik(tr('Amaçlar'), tr('Ne için çalışıyorsun?'), tr('Birden çok seçebilirsin. Haftalık hedef, amaçların en büyüğüne göre kurulur; amaçlar toplanmaz.')),
      SectionLabel(tr('Amaç')),
      grup('amac'),
      SectionLabel(tr('Spor')),
      grup('spor'),
    ];
  }

  // ---- 6. Kas dönütü --------------------------------------------------------------------

  List<Widget> _donutSayfa() {
    if (_amac.isEmpty || _seviye == null) return const [];
    final (saglik, don) = _durum;
    final b = Bilgi.b;
    final renk = <String, Color>{};
    for (final (bl, w) in don.gerekli) {
      final slug = b.bolge[bl]?['slug'] as String?;
      if (slug != null) renk[slug] = Color.lerp(const Color(0xFF5A3424), C.accent, w.clamp(0.0, 1.0))!;
    }
    for (final bl in _ekKas) {
      final slug = b.bolge[bl]?['slug'] as String?;
      if (slug != null && !renk.containsKey(slug)) renk[slug] = C.blue;
    }
    for (final (bl, _, _) in don.kacin) {
      final slug = b.bolge[bl]?['slug'] as String?;
      if (slug != null) renk[slug] = C.red;
    }
    final hasar = [for (final e in saglik.entries) if (e.value < 10) e];
    final tumKas = [for (final e in b.bolge.entries) if (e.value['tur'] == 'kas' && !don.gerekli.any((x) => x.$1 == e.key)) e.key];
    return [
      _baslik(tr('Kas grupları'), tr('Amaçların bunları istiyor')),
      Panel(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(children: [
        SlugMap(colors: renk, height: 300),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 6, alignment: WrapAlignment.center, children: [
          _nokta(C.accent, tr('Gerekli')),
          _nokta(C.blue, tr('Senin eklediğin')),
          _nokta(C.red, tr('Şimdilik çalışma')),
        ]),
      ])),
      SectionLabel(tr('Gerekli kas grupları')),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (bl, w) in don.gerekli)
          if (b.bolge[bl]!['tur'] == 'kas') Pill('${bolgeAd(bl)}${w >= 0.8 ? ' ●' : ''}', color: bant(saglik[bl]!) == 'tam' ? C.accent : C.yellow),
      ]),
      if (don.kacin.isNotEmpty) ...[
        SectionLabel(tr('Rahatsızlıkların yüzünden şimdilik çalışma')),
        for (final (bl, p, bt) in don.kacin)
          _satir(C.red, bolgeAd(bl), trf('Sağlık {0}/10 · {1}', [p.toStringAsFixed(1), _bantAd(bt)])),
      ],
      if (hasar.isNotEmpty) ...[
        SectionLabel(tr('Bölge sağlığı')),
        for (final e in hasar) _satir(_bantRenk(bant(e.value)), bolgeAd(e.key), '${e.value.toStringAsFixed(1)}/10 · ${_bantAd(bant(e.value))}'),
      ],
      SectionLabel(tr('İstersen ekle')),
      Text(tr('Hasarlı bölgeler seçilemez.'), style: T.caption),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final bl in tumKas)
          _cip(bolgeAd(bl), _ekKas.contains(bl), () => setState(() => _ekKas.contains(bl) ? _ekKas.remove(bl) : _ekKas.add(bl)),
              kapali: !don.secilebilirEk.contains(bl), renk: C.blue),
      ]),
    ];
  }

  String _bantAd(String bt) => tr(const {'tam': 'tam sağlık', 'hafifletilmis': 'hafifletilmiş', 'rehabilitasyon': 'rehabilitasyon', 'dinlenme': 'dinlenme'}[bt] ?? bt);

  Color _bantRenk(String bt) => switch (bt) { 'tam' => C.green, 'hafifletilmis' => C.yellow, 'rehabilitasyon' => C.accent2, _ => C.red };

  Widget _nokta(Color c, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(s, style: T.caption),
      ]);

  Widget _satir(Color c, String a, String b) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(child: Text(a, style: t(14.5, w: 600))),
            Text(b, style: T.caption),
          ]),
        ),
      );

  // ---- 7. Haftalık ihtiyaç -----------------------------------------------------------------

  List<Widget> _ihtiyacSayfa() {
    if (_amac.isEmpty || _seviye == null) return const [];
    final (saglik, don) = _durum;
    final (hedef, tablo) = haftalikIhtiyac(_amac.toList(), _seviye!, don, saglik, ekKaslar: _ekKas.toList());
    final (gun, _) = gerekenSeans(hedef, _seviye!);
    final enCok = hedef.values.fold(1, (a, x) => x > a ? x : a);
    final ust = {1: 3, 2: 4, 3: 6}[_seviye]!;
    final oneri = gun < 3 && _seviye! > 1 ? 3 : gun;
    final kardiyo = _amac.any(kardiyoAmac.contains);
    return [
      _baslik(tr('Haftalık ihtiyaç'), trf('Haftada {0} gün kuvvet', [oneri]),
          tr('Her kas haftada en az 2 kez çalışmalı; bir seansta kas başına set sınırı var. Bu yüzden gün sayısı set hedefinden çıkar.')),
      Panel(
        child: Column(children: [
          Row(children: [
            Expanded(child: _sayi('$oneri', tr('kuvvet günü'))),
            Expanded(child: _sayi(kardiyo ? (_amac.contains('kilo_verme') ? '150–300' : '150') : '—', tr('dk kardiyo'))),
            Expanded(child: _sayi('≤$ust', tr('seviyende üst sınır'))),
          ]),
        ]),
      ),
      if (!kardiyo) _not(C.blue, tr('WHO yetişkinler için ayrıca haftada 150–300 dk orta tempolu aerobik etkinlik önerir.')),
      SectionLabel(trf('Kas başına haftalık set ({0})', [tablo == 'hipertrofi' ? tr('kas gelişimi') : tr('genel sağlık')])),
      Panel(
        child: Column(children: [
          for (final e in hedef.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 110, child: Text(bolgeAd(e.key), style: t(13.5, w: 560), overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: e.value / enCok, minHeight: 8, backgroundColor: C.surface3, valueColor: AlwaysStoppedAnimation(bant(saglik[e.key]!) == 'tam' ? C.accent : C.yellow)),
                  ),
                ),
                SizedBox(width: 40, child: Text('${e.value}', textAlign: TextAlign.right, style: T.num(14))),
              ]),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
        child: Text(tr('Set "fractional" sayılır: bir hareket ana kasına 1, yardımcı kasına 0,5 set yazar. Sarı: ağrılı bölge, hedef yarıya indi.'), style: T.caption),
      ),
    ];
  }

  Widget _sayi(String a, String b) => Column(children: [
        Text(a, style: T.num(28, color: C.accent)),
        const SizedBox(height: 2),
        Text(b, style: T.caption, textAlign: TextAlign.center),
      ]);

  // ---- 8. Lojistik ------------------------------------------------------------------------

  List<Widget> _lojistik() {
    final sporlar = [for (final a in _amac) if (Bilgi.b.spor[a]?['tur'] == 'spor') a];
    final cakisan = [for (final g in _gun.toList()..sort()) if (_spor.containsKey(g)) g];
    final evde = _ortam.isNotEmpty && !_ortam.contains('salon');
    return [
      _baslik(tr('Zaman ve yer'), tr('Nerede ve hangi günler?')),
      SectionLabel(tr('Nerede çalışacaksın?')),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (id, ad) in _ortamlar) _cip(tr(ad), _ortam.contains(id), () => setState(() => _ortam.contains(id) ? _ortam.remove(id) : _ortam.add(id))),
      ]),
      if (evde) ...[
        SectionLabel(tr('Elinde ne var?')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (id, ad) in _ekipmanlar) _cip(tr(ad), _ekipman.contains(id), () => setState(() => _ekipman.contains(id) ? _ekipman.remove(id) : _ekipman.add(id))),
        ]),
        Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child: Text(tr('Hiçbirini seçmezsen yalnız vücut ağırlığı hareketleri gelir.'), style: T.caption)),
      ],
      SectionLabel(tr('Kuvvet antrenmanı günleri')),
      _gunSecici(_gun, (g) => setState(() => _gun.contains(g) ? _gun.remove(g) : _gun.add(g))),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Text(tr('Seviyenin sınırından fazla gün seçersen fazlası kardiyo ya da esneme günü olur. Aynı kasa dinlenmesi için zaman bırakılır; örneğin Cumartesi → Pazartesi 48 saattir.'), style: T.caption),
      ),
      for (final s in sporlar) ...[
        SectionLabel(trf('{0} antrenmanı / maçı hangi günler?', [sporAd(s)])),
        _gunSecici({for (final e in _spor.entries) if (e.value == s) e.key}, (g) => setState(() => _spor[g] == s ? _spor.remove(g) : _spor[g] = s), renk: C.blue),
      ],
      for (final g in cakisan) ...[
        _not(C.yellow, trf('{0}: aynı gün hem kuvvet hem spor var. Aradaki süre en az 3 saat (tercihen 6) olmalı.', [tr(gunler[g])])),
        const SizedBox(height: 8),
        Segmented<bool>(
          items: [(false, tr('3 saatten az')), (true, tr('3 saat ya da fazla'))],
          value: _ayniGunUzak.contains(g),
          onChanged: (v) => setState(() => v ? _ayniGunUzak.add(g) : _ayniGunUzak.remove(g)),
        ),
        if (!_ayniGunUzak.contains(g)) Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child: Text(tr('Bu gün kuvvet antrenmanı verilmez; spor korunur.'), style: T.caption)),
      ],
      SectionLabel(tr('İsteğe bağlı')),
      _onayKutusu(_gec, tr('Antrenmanım genelde yatmadan 1 saat içinde bitiyor'), (v) => setState(() => _gec = v)),
      if (_gec) _not(C.blue, tr('Geç saatte yoğun antrenman uykuya dalmayı geciktirebilir: son seti tükenişe götürme, soğumayı uzat.')),
    ];
  }

  Widget _gunSecici(Set<int> secili, ValueChanged<int> f, {Color renk = C.accent}) => Row(children: [
        for (var g = 0; g < 7; g++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: g < 6 ? 6 : 0),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  f(g);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: secili.contains(g) ? renk : C.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: secili.contains(g) ? renk : C.line2),
                  ),
                  child: Text(tr(gunKisa[g]), style: t(13, w: 650, color: secili.contains(g) ? Colors.white : C.text2)),
                ),
              ),
            ),
          ),
      ]);

  // ---- 9. Süre -------------------------------------------------------------------------------

  List<Widget> _sureSayfa() {
    final sv = _seviye ?? 1;
    final aciklama = {
      1: tr('Başlangıçta planlı deload yok: her hafta küçük bir artış. Yorgunluk birikirse bir hafta hafif geçersin.'),
      2: tr('İlk blok 4 hafta yüklenme; ikinci blok 3 hafta yüklenme + 1 hafta deload.'),
      3: tr('Her blok 3 hafta yüklenme + 1 hafta deload (setler yarıya).'),
    }[sv]!;
    return [
      _baslik(tr('Süre'), tr('Kaç aylık program?'), tr('Program 4 haftalık bloklardan oluşur. Her blok sonunda kısa bir test yapılır ve program yenilenir.')),
      for (final (ay, ad, alt) in [
        (1, tr('1 ay'), tr('1 blok · 4 hafta')),
        (2, tr('2 ay'), tr('2 blok · 8 hafta · ikinci blokta 1–2 yardımcı hareket değişir')),
      ]) ...[
        Panel(
          onTap: () => setState(() => _ay = ay),
          border: _ay == ay ? C.accent : null,
          child: Row(children: [
            Icon(_ay == ay ? CupertinoIcons.largecircle_fill_circle : CupertinoIcons.circle, color: _ay == ay ? C.accent : C.text3),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(ad, style: T.headline), const SizedBox(height: 3), Text(alt, style: T.callout)])),
          ]),
        ),
        const SizedBox(height: 10),
      ],
      _not(C.blue, aciklama),
    ];
  }

  // ---- 10. Sonuç --------------------------------------------------------------------------------

  List<Widget> _sonuc() {
    final p = _plan;
    if (p == null) return const [];
    if (p.durdur != null) return [_baslik(tr('Program'), tr('Program çıkarılmadı')), _not(C.red, tr(p.durdur!))];
    final b = Bilgi.b;
    final takvim = {for (final g in p.takvim) g.gun: g};
    return [
      _baslik(tr('Programın hazır'), trf('{0} haftalık plan', [p.haftalar.length]), tr(uyariMetni)),
      Row(children: [
        for (var g = 0; g < 7; g++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: g < 6 ? 5 : 0),
              child: Column(children: [
                Text(tr(gunKisa[g]), style: T.caption),
                const SizedBox(height: 6),
                Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: switch (takvim[g]?.tur) { 'kuvvet' => C.accent, 'spor' => C.blue, 'kardiyo_mobilite' => C.green.withValues(alpha: 0.7), _ => C.surface2 },
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    switch (takvim[g]?.tur) { 'kuvvet' => CupertinoIcons.flame_fill, 'spor' => CupertinoIcons.sportscourt_fill, 'kardiyo_mobilite' => CupertinoIcons.heart_fill, _ => CupertinoIcons.moon_fill },
                    size: 16,
                    color: takvim[g] == null ? C.text3 : Colors.white,
                  ),
                ),
              ]),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      for (final g in p.takvim) ...[
        SectionLabel(switch (g.tur) {
          'kuvvet' => '${tr(gunler[g.gun])} · ${tr(odakAd[g.odak] ?? '')} · ~${g.sureDk} ${tr('dk')}',
          'spor' => '${tr(gunler[g.gun])} · ${sporAd(g.amac!)}',
          _ => '${tr(gunler[g.gun])} · ${tr('Kardiyo / esneme')}',
        }),
        if (g.tur == 'kuvvet')
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(children: [
              for (final r in [...g.pliometri, ...g.hareketler])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Expanded(child: Text(App.ofStore?.catalog[b.katalogId(r.hareket)]?.name ?? r.ad, style: t(14.5, w: 580))),
                    if (r.agriIzle) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(CupertinoIcons.waveform_path_ecg, size: 15, color: C.yellow)),
                    Text('${r.set}×${r.tekrar.replaceAll(' (yavaş iniş)', '')}', style: T.caption),
                  ]),
                ),
              if (g.not.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4, bottom: 6), child: Text(motorMetni(g.not), style: T.caption)),
            ]),
          )
        else
          Panel(padding: const EdgeInsets.all(14), child: Text(g.tur == 'spor' ? tr('Spor günü: ertesi ve önceki gün bacaklar orta tutulur.') : tr(g.not), style: T.callout)),
      ],
      if (p.kardiyo != null) ...[
        SectionLabel(tr('Kardiyo')),
        Panel(
          child: Text(
            p.kardiyo!.gunBasinaDk[1] == 0
                ? tr('Spor günlerin haftalık aerobik hedefini karşılıyor.')
                : trf('Haftada 5 gün {0} dk ile başla, bloklar boyunca {1} dk\'ya çık (haftada {2}→{3} dk). Orta tempo: konuşabilir ama şarkı söyleyemezsin.',
                    [p.kardiyo!.gunBasinaDk[0], p.kardiyo!.gunBasinaDk[1], p.kardiyo!.baslangicDk, p.kardiyo!.hedefDk]),
            style: T.callout,
          ),
        ),
      ],
      if (p.degisen.isNotEmpty) ...[
        SectionLabel(tr('Sağlığın için değiştirilen hareketler')),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            for (final e in p.degisen.entries.where((e) => _gorunur(p, e.value.$1)).take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(child: Text(b.hareket[e.key]!['ad'], style: t(13.5, color: C.text3).copyWith(decoration: TextDecoration.lineThrough))),
                  const Icon(CupertinoIcons.arrow_right, size: 14, color: C.text3),
                  const SizedBox(width: 6),
                  Expanded(child: Text(b.hareket[e.value.$1]!['ad'], style: t(13.5, w: 600))),
                ]),
              ),
          ]),
        ),
      ],
      if (p.pliometriNotu != null) _not(C.blue, tr(p.pliometriNotu!)),
      for (final o in p.oneriler) _not(C.yellow, motorMetni(o)),
      if (p.azFrekans.isNotEmpty) _not(C.yellow, trf('Haftada 2 seansın altında kalan: {0}', [p.azFrekans.map(bolgeAd).join(', ')])),
      SectionLabel(tr('Haftalar')),
      Panel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(children: [
          for (final h in p.haftalar)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 44, child: Text(trf('H{0}', [h.hafta]), style: T.num(14, color: h.deload ? C.blue : C.text))),
                SizedBox(width: 62, child: Text(h.deload ? tr('Deload') : 'RIR ${h.rir}', style: t(13, w: 650, color: h.deload ? C.blue : C.accent))),
                Expanded(child: Text(motorMetni(h.not), style: T.caption)),
              ]),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: Text(tr('RIR: setin sonunda "kaç tekrar daha yapabilirdim". RIR 2 = 2 tekrar daha yapabilecek kadar ağır.'), style: T.caption),
      ),
    ];
  }

  bool _gorunur(Plan p, String yeni) => p.takvim.any((g) => g.hareketler.any((r) => r.hareket == yeni));
}



/// Small TR | EN switch in the setup flow's top bar: the language can be chosen before anything else.
class DilDugmesi extends StatelessWidget {
  const DilDugmesi({super.key});

  @override
  Widget build(BuildContext context) {
    Widget parca(Dil d, String s) {
      final secili = Lang.current.value == d;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (secili) return;
          HapticFeedback.selectionClick();
          Lang.set(d);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: secili ? C.surface3 : null, borderRadius: BorderRadius.circular(9)),
          child: Text(s, style: t(12.5, w: secili ? 700 : 520, color: secili ? C.text : C.text3)),
        ),
      );
    }

    return Semantics(
      label: 'Language / Dil',
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(11), border: Border.all(color: C.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [parca(Dil.tr, 'TR'), parca(Dil.en, 'EN')]),
      ),
    );
  }
}
