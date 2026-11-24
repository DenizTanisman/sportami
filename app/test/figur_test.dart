import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saha/figure.dart';

/// Her çubuk-adam animasyonu uygulamanın çizim motorunda hatasız oynamalı.
void main() {
  final figs = jsonDecode(File('assets/data/figur.json').readAsStringSync()) as Map<String, dynamic>;
  final kat = [
    ...jsonDecode(File('assets/data/katalog.json').readAsStringSync()) as List,
    ...jsonDecode(File('assets/data/katalog_ek.json').readAsStringSync()) as List,
  ];

  test('katalogdaki her hareketin animasyonu var', () {
    final yok = [
      for (final e in kat)
        if (!figs.containsKey(e['medya']?['figur']) && !figs.containsKey(e['id'])) e['id']
    ];
    expect(yok, isEmpty);
  });

  testWidgets('her animasyon çizilir', (tester) async {
    for (final e in figs.entries) {
      final a = FigureAnim(e.value as Map);
      expect(a.total, greaterThan(0), reason: e.key);
      await tester.pumpWidget(MaterialApp(home: SizedBox(width: 300, height: 300, child: FigureView(data: e.value as Map))));
      for (var i = 0; i < 6; i++) {
        await tester.pump(Duration(milliseconds: (a.total / 5).round()));
      }
      expect(tester.takeException(), isNull, reason: e.key);
    }
  });
}
