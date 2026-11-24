import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'exercise_page.dart';
import 'media.dart';
import 'theme.dart';
import 'widgets.dart';

class ProgramPage extends StatefulWidget {
  const ProgramPage({super.key});

  @override
  State<ProgramPage> createState() => _ProgramPageState();
}

class _ProgramPageState extends State<ProgramPage> {
  int? _week;

  @override
  Widget build(BuildContext context) {
    final store = App.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final week = _week ?? store.week;
        final pi = store.program.phaseOf(week);
        final ph = store.program.phases[pi];
        return CustomScrollView(slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverList.list(children: [
                Text('12 HAFTA · 3 GÜN', style: T.overline),
                const SizedBox(height: 6),
                Text('Program', style: T.largeTitle),
                const SizedBox(height: 18),
                _WeekStrip(store: store, selected: week, onSelect: (w) => setState(() => _week = w)),
                const SizedBox(height: 16),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(ph.name, style: T.title2),
                      const Spacer(),
                      Pill(ph.rir, color: C.accent),
                    ]),
                    const SizedBox(height: 4),
                    Text('Hafta $week · faz haftaları ${ph.weeks}', style: T.caption),
                    const SizedBox(height: 10),
                    Text(ph.text, style: T.body),
                    if (week != store.week) ...[
                      const SizedBox(height: 14),
                      QuietButton(
                        label: 'Şu anki haftayı $week yap',
                        icon: CupertinoIcons.calendar,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          store.setWeek(week);
                          setState(() => _week = null);
                        },
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 12),
                Panel(
                  padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                  child: Row(children: [
                    const Icon(CupertinoIcons.calendar, color: C.accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Gün düzeni', style: T.headline),
                        const SizedBox(height: 2),
                        Text([for (final (wd, id) in store.weekOrder) '${gunKisa[wd - 1]} ${id.substring(3)}'].join(' · '), style: T.callout),
                      ]),
                    ),
                    TextButton(onPressed: () => _scheduleSheet(context, store), child: Text('Değiştir', style: t(14, w: 650, color: C.accent))),
                  ]),
                ),
              ]),
            ),
          ),
          for (final d in [store.program.day('isinma'), for (final (_, id) in store.weekOrder) store.program.day(id), store.program.day('soguma')]) ..._day(context, store, d, pi),
          const SliverToBoxAdapter(child: SizedBox(height: 130)),
        ]);
      },
    );
  }

  List<Widget> _day(BuildContext context, Store store, Day d, int phase) {
    final slots = [for (final s in d.slots) if (s.doseFor(phase) != null) s];
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(child: SectionLabel([if (store.weekdayOf(d.id) != null) gunler[store.weekdayOf(d.id)! - 1], d.tag, d.title].join(' · '))),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(
          child: Panel(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < slots.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 74, color: C.line),
                _row(context, store, d, slots[i], phase),
              ],
            ]),
          ),
        ),
      ),
    ];
  }

  Widget _row(BuildContext context, Store store, Day d, Slot s, int phase) {
    final e = store.exerciseFor(d, s);
    return InkWell(
      onTap: () => Navigator.push(context, exerciseRoute(e, day: d, slot: s)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: Row(children: [
          ExThumb(exercise: e, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (d.isMain) ...[Text(s.no, style: t(12, w: 700, color: C.accent)), const SizedBox(width: 8)],
                Flexible(child: Text(e.name, style: t(15, w: 600), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 2),
              Text(s.doseFor(phase) ?? '', style: T.caption),
            ]),
          ),
          if (store.isSwapped(d, s)) const Padding(padding: EdgeInsets.only(right: 8), child: Pill('Alt.', color: C.blue)),
          const Icon(CupertinoIcons.chevron_right, size: 16, color: C.text3),
        ]),
      ),
    );
  }
}

Future<void> _scheduleSheet(BuildContext context, Store store) async {
  final m = Map<int, String>.of(store.schedule);
  int? wdOf(String id) => m.entries.where((e) => e.value == id).map((e) => e.key).firstOrNull;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Glass(
        radius: 28,
        opacity: 0.88,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 38, height: 5, decoration: BoxDecoration(color: C.line2, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 16),
              Center(child: Text('Gün düzeni', style: T.title3)),
              const SizedBox(height: 4),
              Center(child: Text('Her gün en az 48 saat arayla dursun.', style: T.callout)),
              for (final id in const ['gunA', 'gunB', 'gunC']) ...[
                const SizedBox(height: 18),
                Text('${store.program.day(id).tag} · ${store.program.day(id).title}', style: T.headline),
                const SizedBox(height: 8),
                Row(children: [
                  for (var wd = 1; wd <= 7; wd++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          set(() {
                            final mine = wdOf(id), other = m[wd];
                            m.remove(mine);
                            if (other != null && other != id && mine != null) m[mine] = other;
                            if (other != null && mine == null) m.remove(wd);
                            m[wd] = id;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: wdOf(id) == wd ? C.accentGradient : null,
                            color: wdOf(id) == wd ? null : C.surface3,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(gunKisa[wd - 1], style: t(12.5, w: 620, color: wdOf(id) == wd ? Colors.white : C.text2)),
                        ),
                      ),
                    ),
                ]),
              ],
              const SizedBox(height: 22),
              PrimaryButton(label: 'Kaydet', onTap: () => Navigator.pop(ctx, true)),
            ]),
          ),
        ),
      ),
    ),
  );
  if (saved == true) store.setSchedule(m);
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.store, required this.selected, required this.onSelect});
  final Store store;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var w = 1; w <= 12; w++) ...[
            if (w > 1 && store.program.phaseOf(w) != store.program.phaseOf(w - 1)) const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(w);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: w == selected ? C.accentGradient : null,
                    color: w == selected ? null : C.surface2,
                    border: Border.all(color: w == store.week && w != selected ? C.accent : C.line),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$w', style: T.num(18, w: 700, color: w == selected ? Colors.white : C.text)),
                    const SizedBox(height: 2),
                    Text(store.program.phases[store.program.phaseOf(w)].name.split(' ').first, style: t(9.5, w: 600, color: w == selected ? Colors.white70 : C.text3), overflow: TextOverflow.clip, maxLines: 1),
                  ]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
