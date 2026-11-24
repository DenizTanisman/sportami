import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saha/motor.dart';

/// Dart motoru, Python prototipiyle (bilgi/motor/program.py) aynı programı üretmeli.
/// Fikstür: python3 bilgi/motor/fikstur.py
void main() {
  Bilgi.kur(jsonDecode(File('assets/data/motor.json').readAsStringSync()) as Map);
  final durumlar = jsonDecode(File('test/fixtures/motor_fikstur.json').readAsStringSync()) as List;
  final bugun = DateTime(2026, 11, 24);

  test('pyRound yarımı çifte yuvarlar', () {
    expect([pyRound(0.5), pyRound(1.5), pyRound(2.5), pyRound(2.4), pyRound(2.6)], [0, 2, 2, 2, 3]);
  });

  for (final (i, d) in durumlar.indexed) {
    final g = Girdi.fromJson(d['girdi']);
    test('durum $i: sv${g.seviye} ${g.amaclar.join('+')} ${g.ortamlar.first} ${g.gunler} ${g.rahatsizliklar.map((r) => r.id).join(',')}', () {
      final p = programUret(g, bugun: bugun);
      final c = d['cikti'] as Map;
      expect(p.hedefSet, Map<String, int>.from(c['hedef_set']), reason: 'hedef set');
      expect({for (final e in p.saglik.entries) if (e.value < 10) e.key: e.value}, {for (final e in (c['saglik'] as Map).entries) e.key: (e.value as num).toDouble()}, reason: 'sağlık');
      final takvim = [
        for (final x in p.takvim)
          {
            'gun': x.gun,
            'tur': x.tur,
            'odak': x.odak,
            'h': [for (final r in x.hareketler) [r.hareket, r.set, r.tekrar, r.hafif, r.agriIzle]],
            'p': [for (final r in x.pliometri) r.hareket],
            'sure': x.tur == 'kuvvet' ? x.sureDk : null,
          }
      ];
      expect(takvim, c['takvim'], reason: 'takvim');
      expect([for (final w in p.haftalar) [w.hafta, w.rir, w.deload]], c['haftalar']);
      expect([for (final (gg, e, y) in p.blok2) [gg, e, y]], c['blok2']);
      final k = p.kardiyo;
      expect(k == null ? null : [k.baslangicDk, k.hedefDk, k.gunBasinaDk], c['kardiyo']);
      expect(p.eksikSet, {for (final e in (c['eksik'] as Map).entries) e.key: (e.value as num).toDouble()});
    });
  }

  test('kırmızı bayrakta program yok', () {
    final p = programUret(Girdi(seviye: 1, cinsiyet: 'kadin', amaclar: ['genel_saglik'], ortamlar: ['ev'], gunler: [0], kirmiziBayrak: true));
    expect(p.durdur, isNotNull);
    expect(p.takvim, isEmpty);
  });
}
