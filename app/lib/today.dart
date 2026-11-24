import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'exercise_page.dart';
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
                Text(trUpper('${gunler[now.weekday - 1]}, ${now.day} ${aylar[now.month - 1]}'), style: T.overline),
                const SizedBox(height: 6),
                Text('Bugün', style: T.largeTitle),
                const SizedBox(height: 6),
                Text('Hafta ${store.week} · ${ph.name} · ${ph.rir}', style: T.callout),
                const SizedBox(height: 18),
                Segmented<String?>(
                  items: [for (final (wd, id) in store.weekOrder) (id, '${gunKisa[wd - 1]} · ${id.substring(3)}')],
                  value: dayId,
                  onChanged: (id) => store.chooseDay(id == dayId ? null : id), // aynı güne yeniden dokunmak seçimi kaldırır
                ),
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
                  Text('/ $target set', style: t(10.5, w: 560, color: C.text3)),
                ]),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(day.title, style: T.title3),
                  const SizedBox(height: 4),
                  Text(day.sub, style: T.callout, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text(done >= target && target > 0 ? 'Ana bölüm bitti · soğumaya geç' : 'Kalan ~${(restLeft / 60).ceil()} dk', style: t(13, w: 600, color: C.accent)),
                ]),
              ),
            ]),
          ),
        ),
      ),
      _section('Isınma', '$warmDone/${warm.slots.length}'),
      _compactList(context, store, warm),
      _section('Ana bölüm', '${slots.length} hareket'),
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
      _section('Soğuma', '$coolDone/${cool.slots.length}'),
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
              Text(slot.no, style: t(12.5, w: 720, color: C.accent)),
              if (swapped) ...[const SizedBox(width: 8), const Pill('Alternatif', color: C.blue)],
              if (slot.isNew && store.phase == (slot.dose is List ? (slot.dose as List).indexWhere((x) => x != null) : 0)) ...[const SizedBox(width: 8), const Pill('Yeni', color: C.yellow)],
              const Spacer(),
              if (finished) const Icon(CupertinoIcons.checkmark_seal_fill, color: C.green, size: 18),
            ]),
            const SizedBox(height: 3),
            Text(e.name, style: T.headline),
            if (swapped) Text('Programdaki: ${store.catalog[slot.id]!.name}', style: T.caption),
            const SizedBox(height: 6),
            Text(dose, style: t(13.5, w: 560, color: C.text2)),
            if (type != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(
                    last == null ? 'Henüz kayıt yok' : 'Son ${type.text(last)} · ${shortDate(last['d'])}',
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
            Text('SÜPERSET · ARADA MOLA YOK', style: t(11.5, w: 700, color: C.accent, ls: 0.8)),
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
    return Panel(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(CupertinoIcons.moon_stars_fill, color: C.blue, size: 30),
        const SizedBox(height: 14),
        Text('Bugün dinlenme günü', style: T.title2),
        const SizedBox(height: 8),
        Text('Program ${[for (final (wd, id) in store.weekOrder) '${gunler[wd - 1]} ${id.substring(3)}'].join(', ')}. Kas, dinlenirken güçlenir. Yine de antrenman yapacaksan yukarıdan günü seç.', style: T.body),
        const SizedBox(height: 16),
        Text('Bugün için: yürüyüş, 7–9 saat uyku ve yeterli protein.', style: T.callout),
      ]),
    );
  }
}
