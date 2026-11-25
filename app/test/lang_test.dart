import 'dart:ui' show PlatformDispatcher;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saha/data.dart';
import 'package:saha/lang.dart';
import 'package:saha/theme.dart';

Map<String, dynamic> _exJson() => {
      'id': 'x',
      'ad': 'Kutu sıçraması',
      'en': 'Box jump',
      'kayit': 'cm',
      'cm': {'etiket': 'Kutu (cm)', 'min': 10, 'max': 150, 'ilk': 45},
      'zorluk': 3,
      'ekipman': ['sağlam plyo kutusu', 'bilinmeyen alet'],
      'amac': 'Türkçe amaç',
      'ipuclari': ['bir', 'iki'],
      'hatalar': ['hata'],
      'diz': 'diz notu',
      'kaslar': {
        'ana': [
          {'bolge': 'gluteal', 'ad': 'Büyük kalça kası', 'latince': 'Gluteus maximus', 'detay': 'kalçayı açar'}
        ],
        'yardimci': [
          {'bolge': 'quadriceps', 'ad': 'Sözlükte olmayan kas', 'latince': '', 'detay': 'dizi açar'}
        ],
        'sabitleyici': [],
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Lang.current.value = Dil.tr;
    Lang.content = {};
  });

  group('interface text', () {
    test('Turkish is the key and stays as is', () {
      expect(tr('Bugün'), 'Bugün');
      expect(trf('Hafta {0} · {1}', [3, 'Temel']), 'Hafta 3 · Temel');
    });

    test('English when English is on, Turkish when no entry', () {
      Lang.current.value = Dil.en;
      expect(tr('Bugün'), 'Today');
      expect(trf('Kalan ~{0} dk', [12]), '~12 min left');
      expect(tr('Sözlükte olmayan cümle'), 'Sözlükte olmayan cümle');
    });

    test('weekday, month and upper case', () {
      Lang.current.value = Dil.en;
      expect(tr(gunKisa[0]), 'Mon');
      expect(tr(gunKisa[2]), 'Wed');
      expect(tr(gunKisa[5]), 'Sat');
      expect(tr(gunler[6]), 'Sunday');
      expect(shortDate('2026-11-24'), '24 Nov');
      expect(trUpper('this is it'), 'THIS IS IT');
      Lang.current.value = Dil.tr;
      expect(shortDate('2026-11-24'), '24 Kas');
      expect(trUpper('bir iki'), 'BİR İKİ');
    });

    test('every tr()/trf() literal in lib has an English entry', () {
      // A key may be several adjacent literals: tr('a ' 'b').
      final re = RegExp(r"""\btrf?\(\s*((?:'(?:[^'\\]|\\.)*'\s*)+)""");
      final piece = RegExp(r"""'((?:[^'\\]|\\.)*)'""");
      final missing = <String>[];
      for (final f in Directory('lib').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        if (f.path.endsWith('lang.dart')) continue;
        for (final m in re.allMatches(f.readAsStringSync())) {
          final key = [for (final x in piece.allMatches(m[1]!)) x[1]!].join().replaceAll(r"\'", "'");
          if (key.contains(r'$')) {
            missing.add('${f.path}: interpolation in key: $key');
          } else if (!Lang.dictionary.containsKey(key)) {
            missing.add('${f.path}: $key');
          }
        }
      }
      // Lists translated at display time.
      for (final k in [...gunler, ...gunKisa, ...aylar.where((a) => !['Mar', 'May'].contains(a))]) {
        if (!Lang.dictionary.containsKey(k)) missing.add('date: $k');
      }
      expect(missing, isEmpty);
    });
  });

  group('content overlay', () {
    setUp(() {
      Lang.content = {
        'katalog': {
          'x': {
            'ad': 'Box jump',
            'amac': 'English goal',
            'ipuclari': ['one', 'two'],
            // no "hatalar": falls back to Turkish
            'diz': 'knee note',
            'kaslar': {
              'ana': [
                {'detay': 'extends the hip'}
              ],
              'yardimci': [
                {'detay': ''}
              ],
            },
          },
        },
        'kas': {'Büyük kalça kası': 'Glute max'},
        'ekipman': {'sağlam plyo kutusu': 'sturdy plyo box'},
        'program': {
          'PH': {
            '1–2': {'name': 'Foundation', 'txt': 'Learn the movements.'}
          },
          'TAGN': {'smac': 'Dunk'},
          'DAYS': {
            'gunA': {
              'title': 'Lift and press',
              'items': {
                'A1:boxjump': {
                  'n': 'Box jump',
                  'cue': 'Land quietly.',
                  'd': ['3×3', null]
                },
              },
            },
          },
        },
      };
    });

    test('Turkish mode ignores the overlay', () {
      final e = Exercise.fromJson(_exJson());
      expect(e.name, 'Kutu sıçraması');
      expect(e.purpose, 'Türkçe amaç');
      expect(e.primary.first.name, 'Büyük kalça kası');
      expect(e.equipment, ['sağlam plyo kutusu', 'bilinmeyen alet']);
      expect(e.cm!.label, 'Kutu (cm)');
    });

    test('English mode reads the overlay and falls back field by field', () {
      final e = Exercise.fromJson(_exJson());
      Lang.current.value = Dil.en;
      expect(e.name, 'Box jump');
      expect(e.purpose, 'English goal');
      expect(e.cues, ['one', 'two']);
      expect(e.mistakes, ['hata']); // missing → Turkish
      expect(e.knee, 'knee note');
      expect(e.primary.first.name, 'Glute max'); // glossary
      expect(e.primary.first.detail, 'extends the hip');
      expect(e.secondary.first.name, 'Sözlükte olmayan kas'); // no glossary entry → Turkish
      expect(e.secondary.first.detail, 'dizi açar'); // empty English → Turkish
      expect(e.equipment, ['sturdy plyo box', 'bilinmeyen alet']);
      expect(e.cm!.label, 'Box (cm)');
      expect(e.type!.text({'r': 5}), isNot(contains('tekrar')));
    });

    test('exercise without English uses its English name, then Turkish', () {
      Lang.current.value = Dil.en;
      final j = _exJson()
        ..['id'] = 'y'
        ..['en'] = '';
      expect(Exercise.fromJson(j).name, 'Kutu sıçraması');
      final k = _exJson()..['id'] = 'z';
      expect(Exercise.fromJson(k).name, 'Box jump');
      expect(Exercise.fromJson(k).purpose, 'Türkçe amaç');
    });

    test('program: phase, day, slot and dose', () {
      final day = Day.fromJson({
        'id': 'gunA',
        'tag': 'Gün A',
        'title': 'Kaldır ve it',
        'sub': 'Türkçe alt',
        'items': [
          {'id': 'boxjump', 'a': 'boxjump', 'no': 'A1', 'n': 'Kutu sıçraması', 'd': ['3×3 her bacak', '2×3 (ağır)'], 'cue': 'Sessiz in.', 'g': ['smac']}
        ],
      });
      final ph = Phase('1–2', 'Temel', 'RIR 3', 'Hareketleri öğren.');
      final prog = ProgramData([ph], [0], [day], {'smac': 'Smaç', 'diz': 'Diz'});
      final s = day.slots.first;
      Lang.current.value = Dil.en;
      expect(ph.name, 'Foundation');
      expect(ph.text, 'Learn the movements.');
      expect(day.title, 'Lift and press');
      expect(day.sub, 'Türkçe alt');
      expect(s.name, 'Box jump');
      expect(s.cue, 'Land quietly.');
      expect(s.doseFor(0), '3×3');
      expect(s.doseFor(1), '2×3 (ağır)'); // null in English → Turkish
      expect(prog.tags['smac'], 'Dunk');
      expect(prog.tags['diz'], 'Diz');
      Lang.current.value = Dil.tr;
      expect(s.doseFor(0), '3×3 her bacak');
      expect(day.title, 'Kaldır ve it');
      expect(prog.tags['smac'], 'Smaç');
    });
  });

  group('shipped English content', () {
    test('en.json covers every exercise in the catalog', () {
      final cat = jsonDecode(File('assets/data/katalog.json').readAsStringSync()) as List;
      final en = jsonDecode(File('assets/data/en.json').readAsStringSync()) as Map;
      final missing = [for (final e in cat) if ((en['katalog'] as Map)[e['id']]?['ad'] == null) e['id']];
      expect(missing, isEmpty);
    });

    test('English doses keep the set × rep prefix', () {
      final prog = jsonDecode(File('assets/data/program.json').readAsStringSync()) as Map;
      Lang.content = jsonDecode(File('assets/data/en.json').readAsStringSync()) as Map<String, dynamic>;
      final days = [for (final d in prog['DAYS']) Day.fromJson(d)];
      final pre = RegExp(r'^\d+\s*×\s*\d*');
      for (final d in days) {
        for (final s in d.slots) {
          for (var p = 0; p < 7; p++) {
            Lang.current.value = Dil.tr;
            final a = s.doseFor(p);
            Lang.current.value = Dil.en;
            final b = s.doseFor(p);
            expect(b == null, a == null);
            if (a != null) expect(pre.stringMatch(b!), pre.stringMatch(a), reason: '${d.id} ${s.no}: $a / $b');
          }
        }
      }
    });
  });

  group('persistence and rebuild', () {
    test('choice is saved and read back', () async {
      final dir = Directory.systemTemp.createTempSync('saha_dil');
      await Lang.load(dir: dir);
      // No saved choice: the phone's language decides (Turkish → TR, anything else → EN).
      expect(Lang.current.value, PlatformDispatcher.instance.locale.languageCode == 'tr' ? Dil.tr : Dil.en);
      await Lang.set(Dil.en);
      Lang.current.value = Dil.tr;
      await Lang.load(dir: dir);
      expect(Lang.current.value, Dil.en);
      expect(Lang.exercise('trapbar'), isNotNull); // en.json asset loaded
      dir.deleteSync(recursive: true);
    });

    testWidgets('LangScope rebuilds const widgets at once', (tester) async {
      await tester.pumpWidget(const LangScope(child: MaterialApp(home: Scaffold(body: _Label()))));
      expect(find.text('Bugün'), findsOneWidget);
      Lang.current.value = Dil.en;
      await tester.pump();
      expect(find.text('Today'), findsOneWidget);
      Lang.current.value = Dil.tr;
      await tester.pump();
      expect(find.text('Bugün'), findsOneWidget);
    });
  });
}

class _Label extends StatelessWidget {
  const _Label();
  @override
  Widget build(BuildContext context) => Text(tr('Bugün'));
}
