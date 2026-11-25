import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ada.dart';
import 'data.dart';
import 'exercise_page.dart';
import 'kurulum.dart';
import 'lang.dart';
import 'media.dart';
import 'theme.dart';
import 'widgets.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = App.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final dayId = store.chosenDay;
        final ph = store.program.phases[store.phase];
        return CustomScrollView(slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverList.list(children: [
                Text(trUpper(trf('{0}, {1} {2}', [tr(gunler[now.weekday - 1]), now.day, tr(aylar[now.month - 1])])), style: T.overline),
                const SizedBox(height: 6),
                Text(tr('Bugün'), style: T.largeTitle),
                const SizedBox(height: 6),
                Text(trf('Hafta {0} · {1} · {2}', [store.week, ph.name, ph.rir]), style: T.callout),
                const SizedBox(height: 18),
                Segmented<String?>(
                  items: [for (final (wd, id) in store.weekOrder) (id, tr(gunKisa[wd - 1]))],
                  value: dayId,
                  onChanged: (id) => store.chooseDay(id == dayId ? null : id), // aynı güne yeniden dokunmak seçimi kaldırır
                ),
                if (store.usesPlan) _PlanToday(store: store),
              ]),
            ),
          ),
          if (dayId == null)
            SliverPadding(padding: const EdgeInsets.all(20), sliver: SliverToBoxAdapter(child: _RestDay(store: store)))
          else
            ..._plan(context, store, store.program.day(dayId)),
          const SliverToBoxAdapter(child: SizedBox(height: 130)),
        ]);
      },
    );
  }

  List<Widget> _plan(BuildContext context, Store store, Day day) {
    final warm = store.program.day('isinma'), cool = store.program.day('soguma');
    final slots = store.activeSlots(day);
    var target = 0, done = 0, restLeft = 0;
    for (final s in slots) {
      final e = store.exerciseFor(day, s);
      if (!e.logs) continue;
      final (sets, _) = parseDose(s.doseFor(store.phase));
      final tgt = sets ?? 3, d = store.todaySets(e.id).length;
      target += tgt;
      done += d < tgt ? d : tgt;
      if (d < tgt) restLeft += (tgt - d) * (45 + store.restFor(e));
    }
    final warmDone = warm.slots.where((s) => store.ticked(store.slotKey(warm, s))).length;
    final coolDone = cool.slots.where((s) => store.ticked(store.slotKey(cool, s))).length;

    // Group superset pairs (A5a + A5b) under one bracket.
    final groups = <List<Slot>>[];
    for (final s in slots) {
      if (s.superset && s.no.endsWith('b') && groups.isNotEmpty && groups.last.first.superset && groups.last.first.no.endsWith('a')) {
        groups.last.add(s);
      } else {
        groups.add([s]);
      }
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        sliver: SliverToBoxAdapter(
          child: Panel(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Ring(
                value: target == 0 ? 0 : done / target,
                size: 74,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$done', style: T.num(22, w: 720)),
                  Text(trf('/ {0} set', [target]), style: t(10.5, w: 560, color: C.text3)),
                ]),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(day.title, style: T.title3),
                  const SizedBox(height: 4),
                  Text(day.sub, style: T.callout, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text(done >= target && target > 0 ? tr('Ana bölüm bitti · soğumaya geç') : trf('Kalan ~{0} dk', [(restLeft / 60).ceil()]), style: t(13, w: 600, color: C.accent)),
                ]),
              ),
            ]),
          ),
        ),
      ),
      if (Ada.destekli && Ada.o != null)
        const SliverPadding(padding: EdgeInsets.fromLTRB(20, 12, 20, 0), sliver: SliverToBoxAdapter(child: _AdaSatiri())),
      _section(tr('Isınma'), '$warmDone/${warm.slots.length}'),
      _compactList(context, store, warm),
      _section(tr('Ana bölüm'), trf('{0} hareket', [slots.length])),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.separated(
          itemCount: groups.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final g = groups[i];
            if (g.length == 1) return _ExerciseCard(day: day, slot: g.first);
            return _Superset(children: [for (final s in g) _ExerciseCard(day: day, slot: s, inGroup: true)]);
          },
        ),
      ),
      _section(tr('Soğuma'), '$coolDone/${cool.slots.length}'),
      _compactList(context, store, cool),
    ];
  }

  Widget _section(String title, String trail) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(child: SectionLabel(title, trailing: Text(trail, style: T.caption))),
      );

  Widget _compactList(BuildContext context, Store store, Day d) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverToBoxAdapter(
        child: Panel(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < d.slots.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 74, color: C.line),
              _CompactRow(day: d, slot: d.slots[i]),
            ],
          ]),
        ),
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.day, required this.slot});
  final Day day;
  final Slot slot;

  @override
  Widget build(BuildContext context) {
    final store = App.of(context).store;
    final e = store.exerciseFor(day, slot);
    final key = store.slotKey(day, slot);
    final ok = store.ticked(key);
    return InkWell(
      onTap: () => Navigator.push(context, exerciseRoute(e, day: day, slot: slot)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(children: [
          ExThumb(exercise: e, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.name, style: t(15, w: 600, color: ok ? C.text3 : C.text).copyWith(decoration: ok ? TextDecoration.lineThrough : null, decorationColor: C.text3)),
              const SizedBox(height: 2),
              Text(slot.doseFor(store.phase) ?? '', style: T.caption),
            ]),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              store.tick(key);
            },
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: ok
                  ? const Icon(CupertinoIcons.checkmark_circle_fill, key: ValueKey(1), color: C.green, size: 28)
                  : const Icon(CupertinoIcons.circle, key: ValueKey(0), color: C.text3, size: 28),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.day, required this.slot, this.inGroup = false});
  final Day day;
  final Slot slot;
  final bool inGroup;

  @override
  Widget build(BuildContext context) {
    final store = App.of(context).store;
    final e = store.exerciseFor(day, slot);
    final swapped = store.isSwapped(day, slot);
    final dose = slot.doseFor(store.phase) ?? '';
    final (sets, _) = parseDose(dose);
    final type = e.type;
    final today = store.todaySets(e.id);
    final last = store.last(e.id);
    final best = type?.bestOf(store.records(e.id));
    final finished = sets != null && today.length >= sets;

    return Panel(
      padding: const EdgeInsets.all(14),
      color: inGroup ? C.surface2 : C.surface,
      border: finished ? C.green.withValues(alpha: 0.35) : null,
      onTap: () => Navigator.push(context, exerciseRoute(e, day: day, slot: slot)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ExThumb(exercise: e, size: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(slot.shortNo, style: t(12.5, w: 720, color: C.accent)),
              if (swapped) ...[const SizedBox(width: 8), Pill(tr('Alternatif'), color: C.blue)],
              if (slot.isNew && store.phase == (slot.dose is List ? (slot.dose as List).indexWhere((x) => x != null) : 0)) ...[const SizedBox(width: 8), Pill(tr('Yeni'), color: C.yellow)],
              const Spacer(),
              if (finished) const Icon(CupertinoIcons.checkmark_seal_fill, color: C.green, size: 18),
            ]),
            const SizedBox(height: 3),
            Text(e.name, style: T.headline),
            if (swapped) Text(trf('Programdaki: {0}', [store.catalog[slot.id]!.name]), style: T.caption),
            const SizedBox(height: 6),
            Text(dose, style: t(13.5, w: 560, color: C.text2)),
            if (type != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(
                    last == null ? tr('Henüz kayıt yok') : trf('Son {0} · {1}', [type.text(last), shortDate(last['d'])]),
                    style: T.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (best != null) ...[
                  const Icon(CupertinoIcons.star_fill, size: 12, color: C.accent2),
                  const SizedBox(width: 4),
                  Text(type.text(best), style: t(12, w: 650, color: C.accent2)),
                ],
              ]),
              if (sets != null) ...[const SizedBox(height: 10), SetDots(done: today.length, target: sets)],
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Superset extends StatelessWidget {
  const _Superset({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: C.accent.withValues(alpha: 0.35)),
        color: C.accent.withValues(alpha: 0.05),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          child: Row(children: [
            const Icon(CupertinoIcons.link, size: 14, color: C.accent),
            const SizedBox(width: 6),
            Text(tr('SÜPERSET · ARADA MOLA YOK'), style: t(11.5, w: 700, color: C.accent, ls: 0.8)),
          ]),
        ),
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 8), children[i]],
      ]),
    );
  }
}

class _RestDay extends StatelessWidget {
  const _RestDay({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final gunlerMetni = _liste([for (final (wd, _) in store.weekOrder) tr(gunler[wd - 1])]);
    final bugun = DateTime.now().weekday - 1;
    final spor = store.usesPlan && (store.plan!['takvim'] as List).any((x) => x['gun'] == bugun && x['tur'] == 'spor');
    return Panel(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(spor ? CupertinoIcons.sportscourt_fill : CupertinoIcons.moon_stars_fill, color: C.blue, size: 30),
        const SizedBox(height: 14),
        Text(spor ? tr('Bugün spor günü') : tr('Bugün dinlenme günü'), style: T.title2),
        const SizedBox(height: 8),
        Text(
            spor
                ? trf('Antrenman günlerin {0}. Spor günü kas için de yük sayılır; bugün salonda ek iş yok.', [gunlerMetni])
                : trf('Antrenman günlerin {0}. Kas, dinlenirken güçlenir. Yine de antrenman yapacaksan yukarıdan günü seç.', [gunlerMetni]),
            style: T.body),
        const SizedBox(height: 16),
        Text(tr('Bugün için: yürüyüş, 7–9 saat uyku ve yeterli protein.'), style: T.callout),
      ]),
    );
  }
}

/// "Pazartesi, Çarşamba ve Cumartesi"
String _liste(List<String> l) => l.length < 2 ? l.join() : '${l.sublist(0, l.length - 1).join(', ')}${tr(' ve ')}${l.last}';

/// Üretilen planda bugünün spor ya da kardiyo notu; program bitince yenileme çağrısı.
class _PlanToday extends StatelessWidget {
  const _PlanToday({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final p = store.plan!;
    final bugun = DateTime.now().weekday - 1;
    final g = (p['takvim'] as List).cast<Map>().where((x) => x['gun'] == bugun).firstOrNull;
    final k = p['kardiyo'] as Map?;
    final gk = (k?['gun_basina_dk'] as List?)?.cast<num>();
    final satirlar = <(IconData, Color, String)>[
      if (store.planFinished) (CupertinoIcons.flag_fill, C.accent, tr('Programın bitti. Kısa testini yap ve yeni bloku oluştur (Program sekmesi).')),
      if (g?['tur'] == 'spor') (CupertinoIcons.sportscourt_fill, C.blue, trf('Bugün {0} günü.', [sporAd(g!['amac'])])),
      if (g?['tur'] == 'kardiyo_mobilite') (CupertinoIcons.heart_fill, C.green, tr('Bugün kardiyo ya da esneme günü.')),
      if (gk != null && gk.length == 2 && gk[0] > 0 && g?['tur'] != 'spor') (CupertinoIcons.heart_fill, C.green, trf('Kardiyo hedefi: ~{0} dk orta tempo.', [gk[0]])),
    ];
    if (satirlar.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(children: [
        for (final (i, c, s) in satirlar)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(i, size: 16, color: c),
              const SizedBox(width: 8),
              Expanded(child: Text(s, style: t(13.5, w: 560, color: C.text2))),
            ]),
          ),
      ]),
    );
  }
}

/// "Adaya geç" once the island is on; a one-time offer to turn it on otherwise.
class _AdaSatiri extends StatelessWidget {
  const _AdaSatiri();

  @override
  Widget build(BuildContext context) {
    final ada = Ada.o!;
    return ListenableBuilder(
      listenable: ada,
      builder: (context, _) {
        if (ada.hazir) {
          return QuietButton(
            label: tr('Adaya geç · molada başka uygulama kullan'),
            icon: CupertinoIcons.rectangle_dock,
            color: C.accent,
            onTap: () {
              HapticFeedback.mediumImpact();
              ada.adayaGec();
            },
          );
        }
        if (ada.store.adaSecildi && !ada.acik) return const SizedBox.shrink();
        return Panel(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(children: [
            const Icon(CupertinoIcons.rectangle_dock, color: C.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(ada.acik ? tr('Ada için izin gerekli: diğer uygulamaların üzerinde göster.') : tr('Antrenman adası: mola sayacı ve setler diğer uygulamaların üzerinde.'), style: t(13, w: 520, color: C.text2))),
            TextButton(
              onPressed: () => ada.acik ? ada.izinIste() : ada.ac(true),
              child: Text(ada.acik ? tr('İzin ver') : tr('Aç'), style: t(13.5, w: 650, color: C.accent)),
            ),
          ]),
        );
      },
    );
  }
}
