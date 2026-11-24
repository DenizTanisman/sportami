import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'exercise_page.dart';
import 'theme.dart';
import 'wheel.dart';
import 'widgets.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  static const lifts = ['trapbar', 'frontsquat', 'bench', 'latpull'];

  @override
  Widget build(BuildContext context) {
    final store = App.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return CustomScrollView(slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverList.list(children: [
                Text('${store.recordCount} KAYIT', style: T.overline),
                const SizedBox(height: 6),
                Text('İlerleme', style: T.largeTitle),
                const SectionLabel('Ana kaldırışlar'),
                GridView.count(
                  padding: EdgeInsets.zero,
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                  children: [for (final id in lifts) if (store.catalog[id] != null) _LiftTile(exercise: store.catalog[id]!)],
                ),
                const SectionLabel('Vücut'),
                _Measurements(store: store),
                const SectionLabel('Bütün hareketler'),
                _AllExercises(store: store),
                const SectionLabel('Yedek'),
                _Backup(store: store),
                const SectionLabel('Kaynaklar'),
                Text(
                  'Anatomik animasyonlar ExerciseDB\'nin ücretsiz katmanından canlı gelir (oss.exercisedb.dev); uygulamada saklanmaz. '
                  'Vücut haritası: react-native-body-highlighter (MIT, ELABBASSI Hicham). Yazı tipi: Inter (SIL OFL). '
                  'Program, ipuçları ve kas açıklamaları bu uygulamanın kendi içeriğidir; tıbbi tavsiye değildir.',
                  style: T.caption,
                ),
                const SizedBox(height: 130),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

class _LiftTile extends StatelessWidget {
  const _LiftTile({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final store = App.of(context).store;
    final type = exercise.type!;
    final recs = store.records(exercise.id);
    final best = type.bestOf(recs);
    final first = recs.isEmpty ? null : recs.first;
    final last = recs.isEmpty ? null : recs.last;
    final delta = (first != null && last != null && recs.length > 1) ? type.y(last) - type.y(first) : null;
    return Panel(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.push(context, exerciseRoute(exercise)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(exercise.name, style: t(13.5, w: 600, color: C.text2), maxLines: 1, overflow: TextOverflow.ellipsis),
        const Spacer(),
        Text(best == null ? '–' : fmtKg(type.y(best)), style: T.num(34, w: 720, color: best == null ? C.text3 : C.text)),
        Text(best == null ? 'kayıt yok' : '${type.unit} · rekor', style: T.caption),
        const SizedBox(height: 8),
        if (delta != null)
          Pill('${delta >= 0 ? '+' : ''}${fmtKg(delta)} ${type.unit}', color: delta >= 0 ? C.green : C.red)
        else
          Text(last == null ? '' : 'son ${shortDate(last['d'])}', style: T.caption),
      ]),
    );
  }
}

class _Measurements extends StatelessWidget {
  const _Measurements({required this.store});
  final Store store;

  static const fields = [
    Field('kilo', 'Kilo', 40, 200, fraction: true, optional: true, unit: 'kg'),
    Field('bel', 'Bel', 50, 200, optional: true, unit: 'cm'),
    Field('sicrama', 'Dikey sıçrama', 1, 150, optional: true, unit: 'cm'),
    Field('diz', 'Diz ağrısı', 0, 10, optional: true, unit: '/10'),
  ];

  @override
  Widget build(BuildContext context) {
    final ms = store.measurements;
    Widget stat(String key, String label, String unit) {
      final pts = [for (final r in ms) if (r[key] != null) (parseDay(r['d']), n(r[key]))];
      final v = pts.isEmpty ? null : pts.last.$2;
      final d = pts.length > 1 ? pts.last.$2 - pts.first.$2 : null;
      return Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: T.caption),
          const SizedBox(height: 4),
          Text(v == null ? '–' : fmtKg(v), style: T.num(26, color: v == null ? C.text3 : C.text)),
          Text(d == null ? unit : '${d >= 0 ? '+' : ''}${fmtKg(d)} $unit', style: t(12, w: 600, color: d == null ? C.text3 : C.text2)),
        ]),
      );
    }

    final kilo = [for (final r in ms) if (r['kilo'] != null) (parseDay(r['d']), n(r['kilo']))];
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [stat('kilo', 'Kilo', 'kg'), stat('bel', 'Bel', 'cm'), stat('sicrama', 'Sıçrama', 'cm')]),
        const SizedBox(height: 16),
        if (kilo.length > 1) ...[MiniChart(points: kilo, unit: 'kg', height: 90), const SizedBox(height: 16)],
        QuietButton(
          label: 'Ölçüm ekle',
          icon: CupertinoIcons.add,
          onTap: () async {
            final r = await showWheelSheet(
              context,
              title: 'Ölçüm',
              subtitle: 'Kiloyu sabah aç ölç; beli göbek hizasından. Ölçmediğini "–" bırak.',
              fields: fields,
              values: {for (final f in fields) f.key: store.lastMeasure(f.key)},
              action: 'Kaydet',
            );
            if (r == null) return;
            final vals = <String, num>{for (final e in r.entries) if (e.value != null) e.key: e.value!};
            if (vals.isEmpty) return;
            store.addMeasurement(vals, null);
            HapticFeedback.mediumImpact();
          },
        ),
        if (ms.isNotEmpty) ...[
          const Divider(height: 28, color: C.line),
          for (final r in ms.reversed.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: GestureDetector(
                onLongPress: () => store.removeMeasurement(r['id']),
                child: Row(children: [
                  SizedBox(width: 64, child: Text(shortDate(r['d']), style: T.callout)),
                  Expanded(
                    child: Text(
                      [
                        if (r['kilo'] != null) '${fmtKg(r['kilo'])} kg',
                        if (r['bel'] != null) 'bel ${fmtKg(r['bel'])}',
                        if (r['sicrama'] != null) 'sıçrama ${r['sicrama']}',
                        if (r['diz'] != null) 'diz ${r['diz']}/10',
                      ].join(' · '),
                      style: T.num(14, w: 520),
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ]),
    );
  }
}

class _AllExercises extends StatelessWidget {
  const _AllExercises({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final withRecs = store.catalog.values.where((e) => e.logs && store.records(e.id).isNotEmpty).toList()
      ..sort((a, b) => n(store.last(b.id)!['t']).compareTo(n(store.last(a.id)!['t'])));
    if (withRecs.isEmpty) return Text('Henüz kayıt yok.', style: T.callout);
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < withRecs.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 16, color: C.line),
          InkWell(
            onTap: () => Navigator.push(context, exerciseRoute(withRecs[i])),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(children: [
                Expanded(child: Text(withRecs[i].name, style: t(15, w: 560))),
                Text(withRecs[i].type!.text(withRecs[i].type!.bestOf(store.records(withRecs[i].id))!), style: T.num(14, w: 600, color: C.text2)),
                const SizedBox(width: 8),
                const Icon(CupertinoIcons.chevron_right, size: 15, color: C.text3),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Backup extends StatelessWidget {
  const _Backup({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Kayıtların yalnızca bu telefonda. Dışa aktar bütün kayıtları panoya kopyalar; bir yerde sakla. İçe aktar, panodaki yedekten yalnızca eksikleri ekler, hiçbir şeyi silmez.', style: T.callout),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: QuietButton(
              label: 'Dışa aktar',
              icon: CupertinoIcons.square_arrow_up,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: store.exportText()));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yedek panoya kopyalandı.')));
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: QuietButton(
              label: 'İçe aktar',
              icon: CupertinoIcons.square_arrow_down,
              onTap: () async {
                final d = await Clipboard.getData('text/plain');
                String msg;
                try {
                  final c = store.importText(d?.text ?? '');
                  msg = c == 0 ? 'Eklenecek yeni kayıt yok.' : '$c kayıt eklendi.';
                } catch (_) {
                  msg = 'Panodaki metin bir yedek değil. Hiçbir şey değişmedi.';
                }
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              },
            ),
          ),
        ]),
      ]),
    );
  }
}
