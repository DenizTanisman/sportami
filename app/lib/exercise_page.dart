import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ada.dart';
import 'body_map.dart';
import 'data.dart';
import 'lang.dart';
import 'media.dart';
import 'theme.dart';
import 'wheel.dart';
import 'widgets.dart';

Route<R> exerciseRoute<R>(Exercise e, {Day? day, Slot? slot, Exercise? previewFor}) =>
    CupertinoPageRoute<R>(builder: (_) => ExercisePage(exercise: e, day: day, slot: slot, previewFor: previewFor));

/// One movement: media, how to do it, which muscles, alternatives, history,
/// and a docked set logger.
class ExercisePage extends StatefulWidget {
  const ExercisePage({super.key, required this.exercise, this.day, this.slot, this.previewFor});
  final Exercise exercise;
  final Day? day;
  final Slot? slot;

  /// Set when this page shows an alternative of [previewFor] for the slot.
  final Exercise? previewFor;

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  Exercise get e => widget.exercise;
  bool get preview => widget.previewFor != null;

  /// The small bar title appears once the large title has scrolled away.
  final _showTitle = ValueNotifier(false);

  /// Deep in the page the logger shrinks to one line so there is room to read.
  final _compact = ValueNotifier(false);
  bool _userOpen = false;

  @override
  void dispose() {
    _showTitle.dispose();
    _compact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final store = app.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final slot = widget.slot, day = widget.day;
        final dose = slot?.doseFor(store.phase);
        final swapped = day != null && slot != null && store.isSwapped(day, slot) && !preview;
        return Scaffold(
          body: Stack(children: [
            NotificationListener<ScrollUpdateNotification>(
              onNotification: (n) {
                if (n.depth == 0) {
                  _showTitle.value = n.metrics.pixels > 330;
                  final deep = n.metrics.pixels > 420;
                  if (!deep) _userOpen = false;
                  _compact.value = deep && !_userOpen;
                }
                return false;
              },
              child: CustomScrollView(slivers: [
              SliverAppBar(
                expandedHeight: 330,
                pinned: true,
                stretch: true,
                backgroundColor: C.bg,
                surfaceTintColor: Colors.transparent,
                leading: _RoundIcon(icon: CupertinoIcons.back, onTap: () => Navigator.maybePop(context)),
                title: ValueListenableBuilder<bool>(
                  valueListenable: _showTitle,
                  builder: (_, on, _) => AnimatedOpacity(opacity: on ? 1 : 0, duration: const Duration(milliseconds: 180), child: Text(e.name, style: T.headline)),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: ExerciseMedia(exercise: e, height: 330 + MediaQuery.paddingOf(context).top),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverList.list(children: [
                  if (slot != null) Text(trUpper([if (day?.isMain ?? false) slot.shortNo, if (day != null) store.dayName(day)].join(' · ')), style: T.overline.copyWith(color: C.accent)),
                  // Kept above the title: lower down the docked logger would cover it.
                  if (swapped) ...[const SizedBox(height: 10), _swapBanner(store, day, slot)],
                  if (preview) ...[const SizedBox(height: 10), _previewBanner()],
                  const SizedBox(height: 6),
                  Text(e.name, style: T.largeTitle),
                  if (!Lang.en && e.en.isNotEmpty && e.en.toLowerCase() != e.name.toLowerCase()) ...[const SizedBox(height: 4), Text(e.en, style: T.callout)],
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (dose != null) Pill(dose, color: C.text, fill: C.surface3),
                    DifficultyDots(e.difficulty),
                    for (final g in slot?.tags ?? const <String>[]) Pill(store.program.tags[g] ?? g),
                  ]),
                  _todaySets(store),
                  ..._details(),
                  ..._muscles(),
                  ..._alternatives(store),
                  ..._history(store),
                  const SizedBox(height: 300),
                ]),
              ),
            ])),
            Positioned(left: 0, right: 0, bottom: 0, child: _dock(store)),
          ]),
        );
      },
    );
  }

  // ---- banners --------------------------------------------------------------

  Widget _swapBanner(Store store, Day day, Slot slot) {
    final orig = store.catalog[slot.id]!;
    return Panel(
      color: const Color(0xFF14233A),
      border: C.blue.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      child: Row(children: [
        const Icon(CupertinoIcons.arrow_2_squarepath, color: C.blue, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(trf('Bu günde alternatif kullanıyorsun. Programdaki: {0}', [orig.name]), style: t(13.5, w: 500, color: C.text))),
        TextButton(
          onPressed: () {
            store.swap(day, slot, null);
            Navigator.pushReplacement(context, exerciseRoute(orig, day: day, slot: slot));
          },
          child: Text(tr('Asılına dön'), style: t(13.5, w: 650, color: C.blue)),
        ),
      ]),
    );
  }

  Widget _previewBanner() {
    return Panel(
      color: const Color(0xFF14233A),
      border: C.blue.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        const Icon(CupertinoIcons.info_circle, color: C.blue, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(trf('{0} yerine yapılabilir. Seçersen bu günün planında bu hareket görünür.', [widget.previewFor!.name]), style: t(13.5, w: 500))),
      ]),
    );
  }

  // ---- today's sets ---------------------------------------------------------

  Widget _todaySets(Store store) {
    if (!e.logs) return const SizedBox();
    final sets = store.todaySets(e.id);
    if (sets.isEmpty) return const SizedBox();
    final type = e.type!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel(tr('Bugün')),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in sets)
          GestureDetector(
            onLongPress: () => _recordActions(store, r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${r['set']}', style: T.num(13, color: C.accent)),
                const SizedBox(width: 8),
                Text(type.text(r), style: T.num(14, w: 600)),
              ]),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      Text(tr('Düzenlemek ya da silmek için basılı tut.'), style: T.caption),
    ]);
  }

  /// Long press on a saved set: edit it or delete it.
  Future<void> _recordActions(Store store, Map r) async {
    HapticFeedback.mediumImpact();
    final type = e.type!;
    Widget secenek(BuildContext ctx, IconData icon, String label, Color c, String value) => Material(
          color: C.surface3,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.pop(ctx, value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(children: [
                Icon(icon, size: 21, color: c),
                const SizedBox(width: 14),
                Text(label, style: t(16, w: 620, color: c)),
              ]),
            ),
          ),
        );
    final secim = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Glass(
        radius: 28,
        opacity: 0.86,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(width: 38, height: 5, decoration: BoxDecoration(color: C.line2, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 16),
              Text(type.text(r), style: T.title3, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text([e.name, shortDate(r['d']), if (r['set'] != null) trf('Set {0}', [r['set']])].join(' · '), style: T.callout, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              secenek(ctx, CupertinoIcons.pencil, tr('Düzenle'), C.text, 'duzenle'),
              const SizedBox(height: 8),
              secenek(ctx, CupertinoIcons.trash, tr('Sil'), C.red, 'sil'),
            ]),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (secim == 'sil') _deleteRecord(store, r);
    if (secim == 'duzenle') await _editRecord(store, r);
  }

  Future<void> _editRecord(Store store, Map r) async {
    final type = e.type!;
    final res = await showWheelSheet(
      context,
      title: tr('Seti düzenle'),
      subtitle: [e.name, shortDate(r['d']), if (r['set'] != null) trf('Set {0}', [r['set']])].join(' · '),
      fields: type.fields,
      values: {for (final f in type.fields) f.key: r[f.key] == null ? null : n(r[f.key])},
      action: tr('Kaydet'),
    );
    if (res == null || !mounted) return;
    for (final f in type.fields) {
      if (!f.optional && res[f.key] == null) return;
    }
    final old = store.updateRecord(e.id, r['id'], res);
    if (old == null) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(trf('Düzenlendi: {0}', [type.text({...old, ...res})])),
        action: SnackBarAction(label: tr('Geri al'), textColor: C.accent, onPressed: () => store.putRecord(e.id, old)),
      ));
  }

  void _deleteRecord(Store store, Map r) {
    HapticFeedback.mediumImpact();
    store.removeRecord(e.id, r['id']);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(trf('Kayıt silindi: {0}', [e.type!.text(r)])),
        action: SnackBarAction(label: tr('Geri al'), textColor: C.accent, onPressed: store.restoreLast),
      ));
  }

  // ---- details ---------------------------------------------------------------

  List<Widget> _details() {
    return [
      SectionLabel(tr('Detay')),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(tr('Zorluk'), style: T.callout),
            const Spacer(),
            DifficultyDots(e.difficulty),
          ]),
          if (e.equipment.isNotEmpty) ...[
            const Divider(height: 26, color: C.line),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Ekipman'), style: T.callout),
              const SizedBox(width: 16),
              Expanded(child: Text(e.equipment.join(', '), style: t(14.5, w: 520), textAlign: TextAlign.right)),
            ]),
          ],
          if (e.purpose.isNotEmpty) ...[
            const Divider(height: 26, color: C.line),
            Text(tr('Amaç'), style: T.callout),
            const SizedBox(height: 6),
            Text(e.purpose, style: T.body),
          ],
        ]),
      ),
      if (e.cues.isNotEmpty) ...[
        SectionLabel(tr('Yaparken dikkat et')),
        Panel(child: Column(children: [for (final c in e.cues) _bullet(CupertinoIcons.checkmark_alt_circle_fill, C.green, c)])),
      ],
      if (e.mistakes.isNotEmpty) ...[
        SectionLabel(tr('Sık hatalar')),
        Panel(child: Column(children: [for (final c in e.mistakes) _bullet(CupertinoIcons.xmark_circle_fill, C.red, c)])),
      ],
      if (e.knee != null) ...[
        const SizedBox(height: 12),
        Panel(
          color: const Color(0xFF14233A),
          border: C.blue.withValues(alpha: 0.3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(CupertinoIcons.shield_lefthalf_fill, color: C.blue, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tr('Diz'), style: T.headline), const SizedBox(height: 4), Text(e.knee!, style: T.body)])),
          ]),
        ),
      ],
    ];
  }

  Widget _bullet(IconData icon, Color c, String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, color: c, size: 19)),
          const SizedBox(width: 12),
          Expanded(child: Text(s, style: T.body)),
        ]),
      );

  // ---- muscles -----------------------------------------------------------------

  static const _bolgeAd = {
    'chest': 'Göğüs', 'deltoids': 'Omuz', 'biceps': 'Pazı', 'triceps': 'Arka kol', 'forearm': 'Ön kol', 'abs': 'Karın', 'obliques': 'Yan karın',
    'quadriceps': 'Ön bacak', 'adductors': 'İç bacak', 'tibialis': 'Kaval', 'calves': 'Baldır', 'trapezius': 'Trapez', 'neck': 'Boyun',
    'upper-back': 'Sırt', 'lower-back': 'Bel', 'gluteal': 'Kalça', 'hamstring': 'Arka bacak',
  };
  static const _bolgeEn = {
    'chest': 'Chest', 'deltoids': 'Shoulders', 'biceps': 'Biceps', 'triceps': 'Triceps', 'forearm': 'Forearms', 'abs': 'Abs', 'obliques': 'Obliques',
    'quadriceps': 'Quads', 'adductors': 'Inner thigh', 'tibialis': 'Shin', 'calves': 'Calves', 'trapezius': 'Traps', 'neck': 'Neck',
    'upper-back': 'Upper back', 'lower-back': 'Lower back', 'gluteal': 'Glutes', 'hamstring': 'Hamstrings',
  };

  List<Widget> _muscles() {
    if (e.primary.isEmpty && e.secondary.isEmpty) return const [];
    Widget group(String title, List<Muscle> ms, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 14, bottom: 4), child: Text(title, style: t(12.5, w: 650, color: c, ls: 0.4))),
          for (final m in ms)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: m.name, style: t(15, w: 620)),
                      if (m.latin.isNotEmpty) TextSpan(text: '  ${m.latin}', style: t(13, w: 420, color: C.text3).copyWith(fontStyle: FontStyle.italic)),
                    ])),
                    if (m.detail.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(m.detail, style: T.callout)),
                    Padding(padding: const EdgeInsets.only(top: 3), child: Text((Lang.en ? _bolgeEn : _bolgeAd)[m.region] ?? m.region, style: T.caption)),
                  ]),
                ),
              ]),
            ),
        ]);
    return [
      SectionLabel(tr('Çalışan bölgeler')),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BodyMap(exercise: e, height: 290),
          const SizedBox(height: 12),
          const BodyLegend(),
          if (e.primary.isNotEmpty) group(tr('ANA KASLAR'), e.primary, C.accent),
          if (e.secondary.isNotEmpty) group(tr('YARDIMCI'), e.secondary, const Color(0xFFFFA36F)),
          if (e.stabilizers.isNotEmpty) group(tr('SABİTLEYİCİ'), e.stabilizers, const Color(0xFF5E8FD6)),
        ]),
      ),
    ];
  }

  // ---- alternatives --------------------------------------------------------------

  List<Widget> _alternatives(Store store) {
    final items = [(tr('Genel alternatif'), e.altGeneral), (tr('Daha kolay'), e.altEasier), (tr('Daha zor'), e.altHarder)]
        .where((x) => x.$2 != null && store.catalog.containsKey(x.$2) && x.$2 != e.id)
        .toList();
    if (items.isEmpty) return const [];
    final canSwap = widget.day != null && widget.slot != null && !preview;
    return [
      SectionLabel(tr('Alternatifler')),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 86, color: C.line),
            _altRow(store, items[i].$1, store.catalog[items[i].$2]!, canSwap),
          ],
        ]),
      ),
      if (canSwap) Padding(padding: const EdgeInsets.only(top: 8, left: 4), child: Text(tr('Birini seçersen bugünün planında doğrudan o görünür; istediğin an asılına dönebilirsin.'), style: T.caption)),
    ];
  }

  Widget _altRow(Store store, String label, Exercise alt, bool canSwap) {
    return InkWell(
      onTap: () async {
        final chosen = await Navigator.push<String>(context, exerciseRoute(alt, day: widget.day, slot: widget.slot, previewFor: canSwap ? e : null));
        if (chosen != null && mounted && widget.day != null && widget.slot != null) {
          store.swap(widget.day!, widget.slot!, chosen);
          Navigator.pushReplacement(context, exerciseRoute(store.catalog[chosen]!, day: widget.day, slot: widget.slot));
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          ExThumb(exercise: alt, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trUpper(label), style: T.overline),
              const SizedBox(height: 4),
              Text(alt.name, style: T.headline),
              const SizedBox(height: 6),
              DifficultyDots(alt.difficulty, label: false),
            ]),
          ),
          const Icon(CupertinoIcons.chevron_right, color: C.text3, size: 18),
        ]),
      ),
    );
  }

  // ---- history -------------------------------------------------------------------

  List<Widget> _history(Store store) {
    if (!e.logs) return const [];
    final recs = store.records(e.id);
    final type = e.type!;
    final best = type.bestOf(recs);
    final byDay = <String, Map>{};
    for (final r in recs) {
      final d = r['d'] as String;
      if (byDay[d] == null || type.better(r, byDay[d]!)) byDay[d] = r;
    }
    final pts = [for (final r in byDay.values) (parseDay(r['d']), type.y(r))];
    return [
      SectionLabel(tr('Geçmiş')),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Rekor'), style: T.callout),
                const SizedBox(height: 4),
                Text(best == null ? '–' : type.text(best), style: T.num(24, color: best == null ? C.text3 : C.text)),
              ]),
            ),
            if (best != null) Pill(shortDate(best['d']), color: C.accent),
          ]),
          const SizedBox(height: 18),
          MiniChart(points: pts, unit: type.unit),
          if (recs.isNotEmpty) ...[
            const Divider(height: 28, color: C.line),
            for (final r in recs.reversed.take(12))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: GestureDetector(
                  onLongPress: () => _recordActions(store, r),
                  child: Row(children: [
                    SizedBox(width: 64, child: Text(shortDate(r['d']), style: T.callout)),
                    Text(trf('H{0}', [r['w'] ?? '–']), style: T.caption),
                    const SizedBox(width: 14),
                    Expanded(child: Text(type.full(r) + (r['set'] != null ? trf('  · set {0}', [r['set']]) : ''), style: T.num(14.5, w: identical(r, best) ? 700 : 520, color: identical(r, best) ? C.accent : C.text))),
                  ]),
                ),
              ),
          ],
        ]),
      ),
    ];
  }

  // ---- dock -----------------------------------------------------------------------

  Widget _dock(Store store) {
    if (preview) {
      return _DockShell(
        child: PrimaryButton(
          label: tr('Bugün bunu yap'),
          icon: CupertinoIcons.arrow_2_squarepath,
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context, e.id);
          },
        ),
      );
    }
    if (!e.logs) {
      final key = widget.slot == null || widget.day == null ? null : store.slotKey(widget.day!, widget.slot!);
      if (key == null) return const SizedBox();
      final done = store.ticked(key);
      final next = done ? siradakiHareket(store, widget.day, widget.slot) : null;
      return _DockShell(
        child: done
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                if (next != null) ...[NextExerciseButton(next: next), const SizedBox(height: 10)],
                QuietButton(label: tr('Tamamlandı · geri al'), icon: CupertinoIcons.checkmark_alt, color: C.green, onTap: () => store.tick(key)),
              ])
            : PrimaryButton(label: tr('Tamamlandı'), icon: CupertinoIcons.checkmark_alt, onTap: () {
                HapticFeedback.mediumImpact();
                store.tick(key);
                // Stay when there is a next step to go to; otherwise back to the list.
                if (siradakiHareket(store, widget.day, widget.slot) == null) Navigator.maybePop(context);
              }),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: _compact,
      builder: (_, compact, _) => _SetLogger(
        exercise: e,
        slot: widget.slot,
        day: widget.day,
        compact: compact,
        onExpand: () {
          _userOpen = true;
          _compact.value = false;
        },
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Glass(
          radius: 99,
          opacity: 0.5,
          child: InkWell(onTap: onTap, child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 20, color: C.text))),
        ),
      );
}

class _DockShell extends StatelessWidget {
  const _DockShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Glass(
        opacity: 0.82,
        child: Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
          padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.paddingOf(context).bottom),
          child: child,
        ),
      );
}

/// Docked logger: metal drums prefilled with the last values, then a rest
/// countdown after each set.
class _SetLogger extends StatefulWidget {
  const _SetLogger({required this.exercise, this.slot, this.day, this.compact = false, this.onExpand});
  final Exercise exercise;
  final Slot? slot;
  final Day? day;
  final bool compact;
  final VoidCallback? onExpand;

  @override
  State<_SetLogger> createState() => _SetLoggerState();
}

class _SetLoggerState extends State<_SetLogger> {
  final Map<String, num?> _v = {};
  bool _ready = false;

  /// All sets are done but one more is wanted: show the drums again.
  bool _extra = false;

  Exercise get e => widget.exercise;

  void _prefill(Store store) {
    _v
      ..clear()
      ..addAll(setPrefill(store, e, widget.slot));
    _ready = true;
  }

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final store = app.store, rest = app.rest;
    if (!_ready) _prefill(store);
    final type = e.type!;
    final done = store.todaySets(e.id).length;
    final (target, _) = parseDose(widget.slot?.doseFor(store.phase));
    return ListenableBuilder(
      listenable: rest,
      builder: (context, _) {
        // A rest is between sets whichever exercise started it: on the next exercise's page too.
        final resting = rest.active;
        return _DockShell(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: widget.compact
                ? _compactView(store, rest, type, resting, done, target)
                : (resting ? _restView(store, rest, done, target) : _logView(store, rest, type, done, target)),
          ),
        );
      },
    );
  }

  Widget _logView(Store store, RestTimer rest, LogType type, int done, int? target) {
    final next = siradakiHareket(store, widget.day, widget.slot);
    final finished = target != null && done >= target;
    if (finished && next != null && !_extra) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(CupertinoIcons.checkmark_seal_fill, color: C.green, size: 16),
          const SizedBox(width: 6),
          Text(trf('SETLER TAMAM · {0} / {1}', [done, target]), style: t(12.5, w: 700, color: C.green, ls: 1)),
        ]),
        const SizedBox(height: 12),
        NextExerciseButton(next: next),
        const SizedBox(height: 10),
        QuietButton(label: tr('Ekstra set'), icon: CupertinoIcons.plus, onTap: () => setState(() => _extra = true)),
      ]);
    }
    final setNo = done + 1;
    final label = target == null ? trf('SET {0}', [setNo]) : (setNo > target ? tr('EKSTRA SET') : trf('SET {0} / {1}', [setNo, target]));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Text(label, style: t(12.5, w: 700, color: C.accent, ls: 1)),
        const Spacer(),
        GestureDetector(
          onTap: () => _editRest(store),
          child: Row(children: [
            const Icon(CupertinoIcons.timer, size: 15, color: C.text2),
            const SizedBox(width: 5),
            Text(trf('Mola {0}', [clock(store.restFor(e))]), style: t(13, w: 560, color: C.text2)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        for (final f in type.fields) ValueWheel(field: f, value: _v[f.key], onChanged: (x) => setState(() => _v[f.key] = x)),
      ]),
      const SizedBox(height: 14),
      PrimaryButton(label: tr('Seti kaydet'), icon: CupertinoIcons.checkmark_alt, onTap: () => _save(store, rest, type)),
      // Superset: straight on to the other half after a set.
      if (next != null && !finished) ...[const SizedBox(height: 10), NextExerciseButton(next: next)],
    ]);
  }

  Widget _compactView(Store store, RestTimer rest, LogType type, bool resting, int done, int? target) {
    if (resting) {
      return Row(children: [
        Text(tr('MOLA'), style: t(12.5, w: 700, color: C.accent, ls: 1)),
        const SizedBox(width: 12),
        Text(clock(rest.left), style: T.num(30, w: 660)),
        const Spacer(),
        QuietButton(label: tr('Bitir'), icon: CupertinoIcons.forward_end_fill, color: C.accent, onTap: rest.skip),
      ]);
    }
    final setNo = done + 1;
    final ready = type.fields.every((f) => f.optional || _v[f.key] != null);
    return Row(children: [
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onExpand,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(target == null ? trf('SET {0}', [setNo]) : (setNo > target ? tr('EKSTRA SET') : trf('SET {0} / {1}', [setNo, target])), style: t(11.5, w: 700, color: C.accent, ls: 1)),
            const SizedBox(height: 2),
            Row(children: [
              Flexible(child: Text(ready ? type.text(_v) : '–', style: T.num(19, w: 680), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.chevron_up, size: 15, color: C.text3),
            ]),
          ]),
        ),
      ),
      PrimaryButton(label: tr('Kaydet'), icon: CupertinoIcons.checkmark_alt, expand: false, onTap: ready ? () => _save(store, rest, type) : null),
    ]);
  }

  Future<void> _editRest(Store store) async {
    final r = await showWheelSheet(context,
        title: tr('Mola süresi'),
        subtitle: e.name,
        fields: const [Field('sn', 'Saniye', 15, 600, step: 15, unit: 'sn')],
        values: {'sn': store.restFor(e)});
    if (r?['sn'] != null) store.setRest(e, r!['sn']!.toInt());
  }

  void _save(Store store, RestTimer rest, LogType type) {
    for (final f in type.fields) {
      if (!f.optional && _v[f.key] == null) return;
    }
    final prevBest = type.bestOf(store.records(e.id));
    final rec = store.addSet(e, Map.of(_v));
    final pr = prevBest == null || type.better(rec, prevBest);
    HapticFeedback.mediumImpact();
    final slot = widget.slot;
    final supersetA = slot != null && slot.superset && slot.no.endsWith('a');
    if (!supersetA) rest.start(store.restFor(e), e.name);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(pr && prevBest != null ? trf('Yeni rekor! {0}', [type.text(rec)]) : (supersetA ? tr('Kaydedildi. Molasız devam: süpersetin ikinci hareketi') : trf('Kaydedildi: {0}', [type.text(rec)]))),
      ));
  }

  Widget _restView(Store store, RestTimer rest, int done, int? target) {
    final nextEx = target != null && done >= target ? siradakiHareket(store, widget.day, widget.slot) : null;
    final frac = rest.total == 0 ? 0.0 : rest.left / rest.total;
    final next = target == null ? tr('Sonraki set') : (done >= target ? tr('Setler tamam · sıradaki harekete geç') : trf('Sonraki: set {0} / {1}', [done + 1, target]));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Text(tr('MOLA'), style: t(12.5, w: 700, color: C.accent, ls: 1)),
        const Spacer(),
        Text(next, style: t(13, w: 560, color: C.text2)),
      ]),
      const SizedBox(height: 10),
      Text(clock(rest.left), style: T.num(64, w: 640)),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: frac, minHeight: 6, backgroundColor: C.surface3, color: C.accent),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: QuietButton(label: '−15', onTap: () => rest.add(-15))),
        const SizedBox(width: 8),
        Expanded(child: QuietButton(label: '+15', onTap: () => rest.add(15))),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: QuietButton(label: tr('Molayı bitir'), icon: CupertinoIcons.forward_end_fill, color: C.accent, onTap: rest.skip)),
      ]),
      if (nextEx != null) ...[const SizedBox(height: 10), NextExerciseButton(next: nextEx)],
    ]);
  }
}

/// "SIRADAKİ" card at the bottom of an exercise: opens the next step of today's plan
/// in place of this page.
class NextExerciseButton extends StatelessWidget {
  const NextExerciseButton({super.key, required this.next});
  final (Day, Slot, Exercise) next;

  @override
  Widget build(BuildContext context) {
    final (day, slot, e) = next;
    final store = App.of(context).store;
    final dose = slot.doseFor(store.phase) ?? '';
    return Material(
      color: C.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.pushReplacement(context, exerciseRoute(e, day: day, slot: slot));
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: C.accent.withValues(alpha: 0.45))),
          child: Row(children: [
            ExThumb(exercise: e, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(trUpper(tr('Sıradaki hareket')), style: t(11, w: 700, color: C.accent, ls: 0.8)),
                const SizedBox(height: 2),
                Text(e.name, style: t(15.5, w: 650), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (dose.isNotEmpty) Text(dose, style: T.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const Icon(CupertinoIcons.chevron_right, color: C.accent, size: 20),
          ]),
        ),
      ),
    );
  }
}
