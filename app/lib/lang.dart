import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Interface and content language. Turkish is the source: every Turkish
/// literal is its own key, and English comes from [_en] (interface) or from
/// assets/data/en.json (exercise and program content). Anything without an
/// English text falls back to Turkish.
enum Dil { tr, en }

class Lang {
  static final ValueNotifier<Dil> current = ValueNotifier(Dil.tr);
  static bool get en => current.value == Dil.en;

  /// English content overlay: {katalog, kas, ekipman, program}.
  static Map<String, dynamic> content = {};

  static File? _file;

  /// Reads the saved choice (dil.json next to saha.json) and the English content.
  static Future<void> load({Directory? dir}) async {
    try {
      content = jsonDecode(await rootBundle.loadString('assets/data/en.json')) as Map<String, dynamic>;
    } catch (_) {
      content = {};
    }
    try {
      dir ??= await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/dil.json');
      if (await _file!.exists()) {
        final j = jsonDecode(await _file!.readAsString()) as Map;
        current.value = j['dil'] == 'en' ? Dil.en : Dil.tr;
      } else {
        // First run: follow the phone's language (Turkish phones get Turkish, everything else English).
        current.value = PlatformDispatcher.instance.locale.languageCode == 'tr' ? Dil.tr : Dil.en;
      }
    } catch (_) {}
  }

  static Future<void> set(Dil d) async {
    current.value = d;
    try {
      await _file?.writeAsString(jsonEncode({'dil': d.name}), flush: true);
    } catch (_) {}
  }

  // ---- content lookups (null when there is no English) -----------------------

  static Map? _m(Object? v) => v is Map ? v : null;
  static Map? exercise(String id) => _m(_m(content['katalog'])?[id]);
  static String? muscle(String turkish) => _m(content['kas'])?[turkish] as String?;
  static String? equipment(String turkish) => _m(content['ekipman'])?[turkish] as String?;
  static Map? get _program => _m(content['program']);
  static Map? phase(String weeks) => _m(_m(_program?['PH'])?[weeks]);
  static Map? day(String id) => _m(_m(_program?['DAYS'])?[id]);
  static Map? slot(String dayId, String key) => _m(_m(day(dayId)?['items'])?[key]);
  static Map<String, String> get tags => Map<String, String>.from(_m(_program?['TAGN']) ?? const {});

  /// The interface dictionary, for tests.
  static Map<String, String> get dictionary => _en;
}

/// Interface text: [s] is the Turkish literal; English when English is on.
String tr(String s) => Lang.en ? (_en[s] ?? s) : s;

/// Interface text with values: `trf('Hafta {0}', [3])`.
String trf(String s, List<Object?> args) {
  var r = tr(s);
  for (var i = 0; i < args.length; i++) {
    r = r.replaceAll('{$i}', '${args[i]}');
  }
  return r;
}

/// Content text: English when English is on and [english] is a non-empty string.
String pick(String turkish, Object? english) => Lang.en && english is String && english.trim().isNotEmpty ? english : turkish;

/// Content list: English when English is on and [english] is a non-empty list.
List<String> pickList(List<String> turkish, Object? english) =>
    Lang.en && english is List && english.isNotEmpty ? [for (var i = 0; i < english.length; i++) english[i] is String ? english[i] as String : (i < turkish.length ? turkish[i] : '')] : turkish;

/// Rebuilds the whole app, const widgets included, when the language changes.
/// State (tab, scroll, open sheets) stays.
class LangScope extends StatefulWidget {
  const LangScope({super.key, required this.child});
  final Widget child;

  @override
  State<LangScope> createState() => _LangScopeState();
}

class _LangScopeState extends State<LangScope> {
  @override
  void initState() {
    super.initState();
    Lang.current.addListener(_changed);
  }

  @override
  void dispose() {
    Lang.current.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

const _en = <String, String>{
  // Weekdays and months
  'Pazartesi': 'Monday', 'Salı': 'Tuesday', 'Çarşamba': 'Wednesday', 'Perşembe': 'Thursday', 'Cuma': 'Friday', 'Cumartesi': 'Saturday', 'Pazar': 'Sunday',
  'Pzt': 'Mon', 'Sal': 'Tue', 'Çar': 'Wed', 'Per': 'Thu', 'Cum': 'Fri', 'Cmt': 'Sat', 'Paz': 'Sun',
  'Oca': 'Jan', 'Şub': 'Feb', 'Nis': 'Apr', 'Haz': 'Jun', 'Tem': 'Jul', 'Ağu': 'Aug', 'Eyl': 'Sep', 'Eki': 'Oct', 'Kas': 'Nov', 'Ara': 'Dec',
  '{0}, {1} {2}': '{0}, {1} {2}',

  // Tabs and shell
  'Bugün': 'Today', 'Program': 'Program', 'İlerleme': 'Progress', 'MOLA': 'REST',

  // Today
  'Hafta {0} · {1} · {2}': 'Week {0} · {1} · {2}',
  '/ {0} set': '/ {0} sets',
  'Ana bölüm bitti · soğumaya geç': 'Main block done · on to the cool-down',
  'Kalan ~{0} dk': '~{0} min left',
  'Isınma': 'Warm-up', 'Ana bölüm': 'Main block', 'Soğuma': 'Cool-down',
  '{0} hareket': '{0} exercises',
  'Alternatif': 'Alternative', 'Yeni': 'New',
  'Programdaki: {0}': 'In the program: {0}',
  'Henüz kayıt yok': 'No records yet',
  'Son {0} · {1}': 'Last {0} · {1}',
  'SÜPERSET · ARADA MOLA YOK': 'SUPERSET · NO REST IN BETWEEN',
  'Bugün dinlenme günü': 'Rest day today',
  'Antrenman günlerin {0}. Kas, dinlenirken güçlenir. Yine de antrenman yapacaksan yukarıdan günü seç.':
      'Your training days are {0}. Muscle gets stronger while you rest. If you still want to train, pick the day above.',
  'Bugün için: yürüyüş, 7–9 saat uyku ve yeterli protein.': 'For today: a walk, 7–9 hours of sleep and enough protein.',
  ' ve ': ' and ',

  // Exercise page
  'Bu günde alternatif kullanıyorsun. Programdaki: {0}': "You're using an alternative on this day. In the program: {0}",
  'Asılına dön': 'Back to original',
  '{0} yerine yapılabilir. Seçersen bu günün planında bu hareket görünür.': "Can replace {0}. If you pick it, this movement shows in today's plan.",
  'Silmek için basılı tut.': 'Press and hold to delete.',
  'Kayıt silindi: {0}': 'Record deleted: {0}',
  'Geri al': 'Undo',
  'Detay': 'Details', 'Zorluk': 'Difficulty', 'Ekipman': 'Equipment', 'Amaç': 'Goal',
  'Yaparken dikkat et': 'Coaching cues', 'Sık hatalar': 'Common mistakes', 'Diz': 'Knee',
  'Çalışan bölgeler': 'Muscles worked',
  'ANA KASLAR': 'PRIMARY MUSCLES', 'YARDIMCI': 'SYNERGISTS', 'SABİTLEYİCİ': 'STABILIZERS',
  'Genel alternatif': 'General alternative', 'Daha kolay': 'Easier', 'Daha zor': 'Harder',
  'Alternatifler': 'Alternatives',
  'Birini seçersen bugünün planında doğrudan o görünür; istediğin an asılına dönebilirsin.':
      "Pick one and it shows straight in today's plan; you can switch back to the original any time.",
  'Geçmiş': 'History', 'Rekor': 'Best',
  'H{0}': 'W{0}',
  '  · set {0}': '  · set {0}',
  'Bugün bunu yap': 'Do this today',
  'Tamamlandı · geri al': 'Done · undo',
  'Tamamlandı': 'Done',
  'SET {0}': 'SET {0}', 'EKSTRA SET': 'EXTRA SET', 'SET {0} / {1}': 'SET {0} / {1}',
  'Mola {0}': 'Rest {0}',
  'Seti kaydet': 'Log set', 'Bitir': 'End', 'Kaydet': 'Save',
  'Mola süresi': 'Rest time', 'Saniye': 'Seconds',
  'Yeni rekor! {0}': 'New best! {0}',
  'Kaydedildi. Molasız devam: süpersetin ikinci hareketi': 'Saved. Keep going, no rest: second movement of the superset',
  'Kaydedildi: {0}': 'Saved: {0}',
  'Sonraki set': 'Next set',
  'Setler tamam · sıradaki harekete geç': 'Sets done · move to the next exercise',
  'Sonraki: set {0} / {1}': 'Next: set {0} / {1}',
  'Molayı bitir': 'End rest',

  // Body map
  'Ön': 'Front', 'Arka': 'Back', 'Ana kas': 'Primary', 'Yardımcı': 'Synergist', 'Sabitleyici': 'Stabilizer',

  // Logging
  'Ağırlık': 'Weight', 'Tekrar': 'Reps', 'Ek ağırlık': 'Added weight', 'Süre': 'Time', 'Tek el': 'Per hand', 'Mesafe': 'Distance',
  'sn': 's', 'tekrar': 'reps', '{0} tekrar': '{0} reps', ' · {0} set': ' · {0} sets',
  'Kutu (cm)': 'Box (cm)', 'Dokunuş (cm)': 'Touch (cm)', 'Mesafe (cm)': 'Distance (cm)',
  '{0} ondalık': '{0} decimal', 'Tamam': 'OK',

  // Difficulty and charts
  'Çok kolay': 'Very easy', 'Kolay': 'Easy', 'Orta': 'Moderate', 'Zor': 'Hard', 'Çok zor': 'Very hard',
  'İki kayıttan sonra burada grafik çıkar.': 'A chart appears here after two records.',
  'en düşük {0} · en yüksek {1} {2}': 'low {0} · high {1} {2}',

  // Program
  '12 HAFTA · 3 GÜN': '12 WEEKS · 3 DAYS',
  'Hafta {0} · faz haftaları {1}': 'Week {0} · phase weeks {1}',
  'Şu anki haftayı {0} yap': 'Make week {0} the current week',
  'Gün düzeni': 'Day schedule', 'Değiştir': 'Change', 'Alt.': 'Alt.',
  'Her gün en az 48 saat arayla dursun.': 'Keep at least 48 hours between the days.',

  // Progress
  '{0} KAYIT': '{0} RECORDS',
  'Ana kaldırışlar': 'Main lifts', 'Vücut': 'Body', 'Bütün hareketler': 'All exercises', 'Yedek': 'Backup', 'Kaynaklar': 'Sources',
  'Anatomik animasyonlar ExerciseDB\'nin ücretsiz katmanından canlı gelir (oss.exercisedb.dev); uygulamada saklanmaz. '
          'Vücut haritası: react-native-body-highlighter (MIT, ELABBASSI Hicham). Yazı tipi: Inter (SIL OFL). '
          'Program, ipuçları ve kas açıklamaları bu uygulamanın kendi içeriğidir; tıbbi tavsiye değildir.':
      "Anatomical animations stream live from ExerciseDB's free tier (oss.exercisedb.dev); the app does not store them. "
          'Body map: react-native-body-highlighter (MIT, ELABBASSI Hicham). Typeface: Inter (SIL OFL). '
          "The program, cues and muscle notes are this app's own content; they are not medical advice.",
  'kayıt yok': 'no records', '{0} · rekor': '{0} · best', 'son {0}': 'last {0}',
  'Kilo': 'Weight', 'Bel': 'Waist', 'Dikey sıçrama': 'Vertical jump', 'Diz ağrısı': 'Knee pain', 'Sıçrama': 'Jump',
  'Ölçüm ekle': 'Add measurement', 'Ölçüm': 'Measurement',
  'Kiloyu sabah aç ölç; beli göbek hizasından. Ölçmediğini "–" bırak.':
      'Weigh yourself in the morning before eating; measure your waist at the navel. Leave anything you didn\'t measure at "–".',
  'bel {0}': 'waist {0}', 'sıçrama {0}': 'jump {0}', 'diz {0}/10': 'knee {0}/10',
  'Henüz kayıt yok.': 'No records yet.',
  'Kayıtların yalnızca bu telefonda. Dışa aktar bütün kayıtları panoya kopyalar; bir yerde sakla. İçe aktar, panodaki yedekten yalnızca eksikleri ekler, hiçbir şeyi silmez.':
      'Your records live only on this phone. Export copies all records to the clipboard; keep it somewhere safe. Import adds only what is missing from the backup on the clipboard and never deletes anything.',
  'Dışa aktar': 'Export', 'İçe aktar': 'Import',
  'Yedek panoya kopyalandı.': 'Backup copied to the clipboard.',
  'Eklenecek yeni kayıt yok.': 'No new records to add.',
  '{0} kayıt eklendi.': '{0} records added.',
  'Panodaki metin bir yedek değil. Hiçbir şey değişmedi.': 'The clipboard text is not a backup. Nothing changed.',
  'Uygulamanın dili. İngilizcede hareket içeriği de İngilizce görünür.': 'App language. In English the exercise content is shown in English too.',

  // Media
  'Animasyon için internet gerekiyor; çizim gösteriliyor': 'The animation needs internet; showing the drawing',
  'Animasyon için internet gerekiyor': 'The animation needs internet',
  '½× yavaş': '½× slow',
  'Animasyon: ExerciseDB': 'Animation: ExerciseDB',
  'Bu hareketin animasyonu yok': 'No animation for this exercise',
  'Anatomi': 'Anatomy', 'Çizim': 'Drawing',

  // Kurulum akışı (global sürüm)
  '{0}. derece': 'Grade {0}',
  'Okudum, devam et': 'I\'ve read it, continue',
  'Programı oluştur': 'Build my program',
  'Programı başlat': 'Start the program',
  'Devam': 'Continue',
  'Başlamadan önce': 'Before you start',
  'Sana özel program': 'A program made for you',
  'Birkaç soruyla ağrılarını, amaçlarını ve zamanını öğrenip araştırmalara dayalı bir program kuracağız.': 'A few questions about your pain, goals and time, and we\'ll build a research-based program.',
  'Verilerin yalnız bu telefonda kalır. Hesap yok, sunucu yok; hiçbir yere gönderilmez.': 'Your data stays on this phone only. No account, no server; nothing is sent anywhere.',
  'Kurallar yayımlanmış kılavuz ve araştırmalardan gelir: WHO, ACSM, NSCA, spor hekimliği dergileri.': 'The rules come from published guidelines and research: WHO, ACSM, NSCA, sports medicine journals.',
  'Doktora gitmeni gerektiren bir belirti (kırmızı bayrak) varsa program çıkarılmaz.': 'If you have a sign that needs a doctor (a red flag), no program is built.',
  'Okudum ve anladım. Bu bir tıbbi tavsiye değildir.': 'I\'ve read and understood. This is not medical advice.',
  'Profil': 'Profile',
  'Seni tanıyalım': 'About you',
  'Cinsiyet': 'Sex',
  'Kadın': 'Female',
  'Erkek': 'Male',
  'Araştırmalar kadın ve erkek için aynı reçeteyi önerir; cinsiyet yalnız sporların kas vurgusunu ayarlar.': 'Research recommends the same prescription for women and men; sex only adjusts each sport\'s muscle emphasis.',
  'Yaş': 'Age',
  '18 yaş altındaysan programı bir antrenör ya da velinin gözetiminde uygula.': 'If you\'re under 18, follow the program under the supervision of a coach or parent.',
  '65 yaş üstünde denge çalışması ve haftada en az 3 gün çok bileşenli etkinlik önerilir (WHO).': 'Over 65, balance training and multicomponent activity on at least 3 days a week are recommended (WHO).',
  'Antrenman geçmişin': 'Your training history',
  'Sağlık taraması': 'Health screening',
  'Yedi kısa soru': 'Seven short questions',
  'PAR-Q+ (2023): egzersize başlamadan önce dünyada kullanılan ön tarama.': 'PAR-Q+ (2023): the pre-exercise screening used worldwide.',
  'Hayır': 'No',
  'Evet': 'Yes',
  'Kemik, eklem ya da kas sorununu bir sonraki adımda seçeceksin; program ona göre ayarlanır.': 'You\'ll pick your bone, joint or muscle problem in the next step; the program adapts to it.',
  'En az bir soruya "evet" dedin. Daha aktif olmadan önce bir doktora ya da uzman egzersiz profesyoneline danışman önerilir.': 'You answered "yes" to at least one question. Talk to a doctor or a qualified exercise professional before becoming more active.',
  'Doktorum egzersiz yapmama onay verdi.': 'My doctor has cleared me to exercise.',
  'Rahatsızlıklar': 'Conditions',
  'Şu an bir ağrın ya da sakatlığın var mı?': 'Do you have any pain or injury right now?',
  'Seçtiğin her biri ilgili bölgelerin sağlık puanını düşürür; program bu bölgeleri korur.': 'Each one you pick lowers the health score of the regions involved; the program protects those regions.',
  'Hiçbir ağrım ya da sakatlığım yok': 'I have no pain or injury',
  'Bu belirti bir uzmanın değerlendirmesini gerektiriyor. Program çıkarılmaz; lütfen bir doktora başvur.': 'This sign needs a professional\'s assessment. No program is built; please see a doctor.',
  'Ara: diz, bel, burkulma…': 'Search: knee, back, sprain…',
  'Hangi kas?': 'Which muscle?',
  'Ağrı': 'Pain',
  'Dinlenirken değil, günlük hareketlerde hissettiğin ağrı. 0 = yok, 10 = dayanılmaz.': 'The pain you feel in everyday movement, not at rest. 0 = none, 10 = unbearable.',
  'Derece (biliyorsan)': 'Grade (if you know it)',
  'Derece': 'Grade',
  'Kaç gün önce başladı / oldu?': 'How many days ago did it start / happen?',
  '{0} gün': '{0} days',
  'Şunlardan biri var mı? (kırmızı bayrak)': 'Do you have any of these? (red flags)',
  'Amaçlar': 'Goals',
  'Ne için çalışıyorsun?': 'What are you training for?',
  'Birden çok seçebilirsin. Haftalık hedef, amaçların en büyüğüne göre kurulur; amaçlar toplanmaz.': 'You can pick several. The weekly target follows the largest of your goals; goals aren\'t added together.',
  'Spor': 'Sport',
  'Kas grupları': 'Muscle groups',
  'Amaçların bunları istiyor': 'Your goals need these',
  'Gerekli': 'Needed',
  'Senin eklediğin': 'Added by you',
  'Şimdilik çalışma': 'Rest for now',
  'Gerekli kas grupları': 'Needed muscle groups',
  'Rahatsızlıkların yüzünden şimdilik çalışma': 'Don\'t train these for now because of your conditions',
  'Sağlık {0}/10 · {1}': 'Health {0}/10 · {1}',
  'Bölge sağlığı': 'Region health',
  'İstersen ekle': 'Add if you like',
  'Hasarlı bölgeler seçilemez.': 'Injured regions can\'t be selected.',
  'Haftalık ihtiyaç': 'Weekly need',
  'Haftada {0} gün kuvvet': '{0} strength days a week',
  'Her kas haftada en az 2 kez çalışmalı; bir seansta kas başına set sınırı var. Bu yüzden gün sayısı set hedefinden çıkar.': 'Each muscle should be trained at least twice a week, and there\'s a per-session set limit per muscle, so the number of days follows from the set target.',
  'kuvvet günü': 'strength days',
  'dk kardiyo': 'min cardio',
  'seviyende üst sınır': 'limit at your level',
  'WHO yetişkinler için ayrıca haftada 150–300 dk orta tempolu aerobik etkinlik önerir.': 'WHO also recommends 150–300 min of moderate aerobic activity a week for adults.',
  'Kas başına haftalık set ({0})': 'Weekly sets per muscle ({0})',
  'kas gelişimi': 'muscle growth',
  'genel sağlık': 'general health',
  'Set "fractional" sayılır: bir hareket ana kasına 1, yardımcı kasına 0,5 set yazar. Sarı: ağrılı bölge, hedef yarıya indi.': 'Sets are counted fractionally: an exercise counts 1 set for its prime mover and 0.5 for synergists. Yellow: painful region, target halved.',
  'Zaman ve yer': 'Time and place',
  'Nerede ve hangi günler?': 'Where and which days?',
  'Nerede çalışacaksın?': 'Where will you train?',
  'Elinde ne var?': 'What equipment do you have?',
  'Hiçbirini seçmezsen yalnız vücut ağırlığı hareketleri gelir.': 'If you pick none, you\'ll get bodyweight exercises only.',
  'Kuvvet antrenmanı günleri': 'Strength training days',
  'Seviyenin sınırından fazla gün seçersen fazlası kardiyo ya da esneme günü olur. Aynı kasa dinlenmesi için zaman bırakılır; örneğin Cumartesi → Pazartesi 48 saattir.': 'If you pick more days than your level allows, the extra ones become cardio or stretching days. Each muscle gets time to recover; for example, Saturday → Monday is 48 hours.',
  '{0} antrenmanı / maçı hangi günler?': 'Which days are your {0} practices / games?',
  '{0}: aynı gün hem kuvvet hem spor var. Aradaki süre en az 3 saat (tercihen 6) olmalı.': '{0}: strength and sport on the same day. Leave at least 3 hours between them (6 is better).',
  '3 saatten az': 'Less than 3 hours',
  '3 saat ya da fazla': '3 hours or more',
  'Bu gün kuvvet antrenmanı verilmez; spor korunur.': 'No strength session on this day; the sport stays.',
  'İsteğe bağlı': 'Optional',
  'Antrenmanım genelde yatmadan 1 saat içinde bitiyor': 'My workouts usually end within an hour of bedtime',
  'Geç saatte yoğun antrenman uykuya dalmayı geciktirebilir: son seti tükenişe götürme, soğumayı uzat.': 'Hard training late in the evening can delay falling asleep: don\'t take the last set to failure and extend the cool-down.',
  'Başlangıçta planlı deload yok: her hafta küçük bir artış. Yorgunluk birikirse bir hafta hafif geçersin.': 'Beginners have no planned deload: a small increase every week. If fatigue builds up, take an easy week.',
  'İlk blok 4 hafta yüklenme; ikinci blok 3 hafta yüklenme + 1 hafta deload.': 'Block 1: 4 loading weeks; block 2: 3 loading weeks + 1 deload week.',
  'Her blok 3 hafta yüklenme + 1 hafta deload (setler yarıya).': 'Each block: 3 loading weeks + 1 deload week (sets halved).',
  'Kaç aylık program?': 'How long a program?',
  'Program 4 haftalık bloklardan oluşur. Her blok sonunda kısa bir test yapılır ve program yenilenir.': 'The program is made of 4-week blocks. Each block ends with a short test and the program is renewed.',
  '1 ay': '1 month',
  '1 blok · 4 hafta': '1 block · 4 weeks',
  '2 ay': '2 months',
  '2 blok · 8 hafta · ikinci blokta 1–2 yardımcı hareket değişir': '2 blocks · 8 weeks · 1–2 accessory exercises change in block 2',
  'Program çıkarılmadı': 'No program built',
  'Programın hazır': 'Your program is ready',
  '{0} haftalık plan': '{0}-week plan',
  'dk': 'min',
  'Kardiyo / esneme': 'Cardio / stretching',
  'Spor günü: ertesi ve önceki gün bacaklar orta tutulur.': 'Sport day: legs are kept moderate the day before and after.',
  'Kardiyo': 'Cardio',
  'Spor günlerin haftalık aerobik hedefini karşılıyor.': 'Your sport days cover the weekly aerobic target.',
  'Haftada 5 gün {0} dk ile başla, bloklar boyunca {1} dk\'ya çık (haftada {2}→{3} dk). Orta tempo: konuşabilir ama şarkı söyleyemezsin.': 'Start with {0} min on 5 days a week and build up to {1} min over the blocks ({2}→{3} min a week). Moderate pace: you can talk but not sing.',
  'Sağlığın için değiştirilen hareketler': 'Exercises swapped for your health',
  'Haftada 2 seansın altında kalan: {0}': 'Trained less than twice a week: {0}',
  'Haftalar': 'Weeks',
  'Deload': 'Deload',
  'RIR: setin sonunda "kaç tekrar daha yapabilirdim". RIR 2 = 2 tekrar daha yapabilecek kadar ağır.': 'RIR: "how many more reps could I have done" at the end of a set. RIR 2 = heavy enough that 2 more reps were left.',
  '{0} kas grubunun haftalık hedefi bu günlerle tam karşılanmıyor; {1}': 'The weekly target of {0} muscle groups isn\'t fully met with these days; {1}',
  'patlayıcı, tam dinlen': 'explosive, rest fully',
  'ağrı izle': 'monitor pain',
  'tükenişe gitme': 'don\'t go to failure',
  'Blok {0}': 'Block {0}',
  'Her gün': 'Every day',
  '5–10 dk: önce hafif tempolu yürüyüş ya da bisiklet, sonra bunlar': '5–10 min: an easy walk or bike first, then these',
  '1×10 her yön': '1×10 each direction',
  '1×10 her bacak': '1×10 each leg',
  '1×5 her taraf': '1×5 each side',
  '~{0} dk': '~{0} min',
  '5 dk hafif hareket ve esneme': '5 min of easy movement and stretching',
  '1×30 sn her bacak': '1×30 s each leg',
  '1×30 sn her taraf': '1×30 s each side',
  '1×30 sn': '1×30 s',
  '1×45 sn': '1×45 s',
  'Patlayıcı': 'Explosive',
  'Ağrı izle': 'Monitor pain',
  'Spordan önce: orta': 'Before sport: moderate',
  'Programın bitti. Kısa testini yap ve yeni bloku oluştur (Program sekmesi).': 'Your program is over. Do your short test and build the next block (Program tab).',
  'Bugün {0} günü.': 'Today is {0} day.',
  'Bugün kardiyo ya da esneme günü.': 'Today is a cardio or stretching day.',
  'Kardiyo hedefi: ~{0} dk orta tempo.': 'Cardio target: ~{0} min at a moderate pace.',
  '{0} hafta · {1} gün': '{0} weeks · {1} days',
  'Program bitti: yeni blok zamanı': 'Program over: time for a new block',
  'Kendine özel program oluştur': 'Build your own program',
  'Ağrıların, amaçların ya da günlerin değişirse yeniden oluştur. Blok sonunda testini yapıp yeni blok kur.': 'Rebuild it if your pain, goals or days change. At the end of a block, do your test and build the next block.',
  'Ağrılarına, amaçlarına ve günlerine göre araştırmalara dayalı 1–2 aylık program.': 'A research-based 1–2 month program fitted to your pain, goals and days.',
  'Kardiyo: haftada 5 gün {0}→{1} dk, orta tempo.': 'Cardio: 5 days a week, {0}→{1} min, moderate pace.',
  'Yeniden oluştur': 'Rebuild',
  'Başla': 'Start',
  'Sabit programa dön': 'Back to the fixed program',
  'Oluşturduğum programa geç': 'Switch to my built program',
  'Öneriler araştırmalara dayanır; doktor, fizyoterapist ya da diyetisyen tavsiyesi değildir.': 'The suggestions are based on research; they aren\'t advice from a doctor, physiotherapist or dietitian.',
  'Tüm vücut': 'Full body',
  'Üst vücut': 'Upper body',
  'Alt vücut': 'Lower body',
  'İtme': 'Push',
  'Çekme': 'Pull',
  'Bacak': 'Legs',
  '18 altı': 'Under 18',
  '18–29': '18–29',
  '30–44': '30–44',
  '45–64': '45–64',
  '65+': '65+',
  'Spor salonu': 'Gym',
  'Ev': 'Home',
  'Dış mekân': 'Outdoors',
  'Dumbbell': 'Dumbbell',
  'Direnç bandı': 'Resistance band',
  'Kettlebell': 'Kettlebell',
  'Barfiks barı': 'Pull-up bar',
  'Sehpa': 'Bench',
  'Kutu / basamak': 'Box / step',
  'TRX': 'TRX',
  'Sağlık topu': 'Medicine ball',
  'Atlama ipi': 'Jump rope',
  'Barbell': 'Barbell',
  'Bel, sırt ve boyun': 'Lower back, back and neck',
  'Omuz': 'Shoulder',
  'Dirsek ve el bileği': 'Elbow and wrist',
  'Göğüs': 'Chest',
  'Kalça ve kasık': 'Hip and groin',
  'Uyluk': 'Thigh',
  'Baldır, kaval ve ayak': 'Calf, shin and foot',
  'Kas ağrısı, kramp, ezilme': 'Muscle soreness, cramp, bruise',
  'tam': 'full',
  'hafifletilmis': 'reduced',
  'rehabilitasyon': 'rehab',
  'dinlenme': 'rest',
  'Ertesi gün spor: alt vücut orta (≥2 RIR, tükenişe gitme).': 'Sport tomorrow: lower body moderate (≥2 RIR, no failure).',
  'Seviyenin kuvvet günü sınırı aşıldı: bu gün orta tempolu kardiyo ya da mobilite.': 'Above your level\'s strength-day limit: moderate cardio or mobility on this day.',
  'Diz/ayak bileği/kalça tam sağlıkta değil: pliometri verilmedi.': 'Knee/ankle/hip not fully healthy: no plyometrics given.',
  'Spor antrenmanında zaten sıçrama var: salonda ek pliometri verilmedi.': 'Your sport already has jumping: no extra plyometrics in the gym.',
  'Kırmızı bayrak işaretlendi: program çıkarılmaz. Lütfen bir doktora başvurun.': 'A red flag was ticked: no program is built. Please see a doctor.',
  'Teknik haftası: yükü rahat seç': 'Technique week: pick a comfortable load',
  'Teknik haftası: yükü rahat seç, hareket başına 1–2 set': 'Technique week: pick a comfortable load, 1–2 sets per exercise',
  'Bir önceki haftaya göre +1 tekrar; tekrar aralığının üstüne çıkınca yük +%2,5–5 (çift ilerleme)': '+1 rep over last week; once you pass the rep range, load +2.5–5% (double progression)',
  'Yeni blok: test iyiyse kas başına haftalık set +%10–20; 1–2 yardımcı hareket değişir': 'New block: if the test went well, weekly sets per muscle +10–20%; 1–2 accessory exercises change',
  'Blok sonu testi: ana hareketlerde aynı yükle tekrar sayısı, ağrı puanları yeniden girilir': 'End-of-block test: reps at the same load on the main lifts; re-enter your pain scores',
  'Deload: setler yarıya, RIR ≥3; hareketler ve günler aynı.': 'Deload: sets halved, RIR ≥3; same exercises and days.',
  'bir kuvvet günü eklemek dağılımı düzeltir.': 'adding a strength day would fix the spread.',
  'hedefler alt uçta tutuldu.': 'targets were kept at the low end.',
  'Haftada tek kuvvet seansı WHO\'nun ≥2 gün önerisini karşılamaz.': 'One strength session a week doesn\'t meet the WHO recommendation of ≥2 days.',
  'Buradaki öneriler, herkese açık yayımlanmış araştırmalara ve kılavuzlara dayanır. Doktor, fizyoterapist ya da diyetisyen tavsiyesi değildir. Doğru bilgi için uzmana danışınız.': 'These suggestions are based on publicly published research and guidelines. They are not advice from a doctor, physiotherapist or dietitian. Consult a professional for accurate guidance.',
  'tam sağlık': 'fully healthy',
  'hafifletilmiş': 'reduced load',
  'Bugün spor günü': 'Sport day today',
  'Antrenman günlerin {0}. Spor günü kas için de yük sayılır; bugün salonda ek iş yok.': 'Your training days are {0}. A sport day also counts as load for your muscles; no extra gym work today.',
  'Şiddetli ağrı. Bu ağrıyla egzersize başlamadan önce bir doktor ya da fizyoterapist görmelisin; onay almadan program çıkarılmaz.': 'Severe pain. See a doctor or physiotherapist before exercising with this pain; no program is built without their clearance.',
  'Bir doktor ya da fizyoterapist bu ağrıyla egzersiz yapmamı onayladı.': 'A doctor or physiotherapist cleared me to exercise with this pain.',
  'Orta düzeyde ağrı. İlgili hareketler hafifletilir; antrenman sırasında ağrı 5/10\'u geçmemeli ve ertesi sabah artmamalı.': "Moderate pain. Related exercises are scaled down; during training pain shouldn't exceed 5/10 or be worse the next morning.",
};
