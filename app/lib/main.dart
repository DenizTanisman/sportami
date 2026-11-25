import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'kurulum.dart';
import 'lang.dart';
import 'media.dart';
import 'program_page.dart';
import 'progress_page.dart';
import 'theme.dart';
import 'today.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Lang.load();
  final results = await Future.wait([Store.open(), Figures.load()]);
  App.ofStore = results[0] as Store;
  runApp(SahaApp(store: results[0] as Store));
}

class SahaApp extends StatelessWidget {
  SahaApp({super.key, required this.store});
  final Store store;
  final RestTimer rest = RestTimer();

  @override
  Widget build(BuildContext context) {
    return App(
      store: store,
      rest: rest,
      child: LangScope(
        child: MaterialApp(
          title: 'Sportami',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          // Genel sürüm: program yoksa önce kurulum akışı.
          home: ListenableBuilder(
            listenable: store,
            builder: (context, _) => store.needsSetup ? const KurulumAkisi(ilk: true) : const Shell(),
          ),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final rest = App.of(context).rest;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      extendBody: true,
      body: Stack(children: [
        IndexedStack(index: _tab, children: const [TodayPage(), ProgramPage(), ProgressPage()]),
        Positioned(
          left: 16,
          right: 16,
          bottom: 72 + bottom,
          child: ListenableBuilder(
            listenable: rest,
            builder: (context, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (c, a) => SlideTransition(position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(a), child: FadeTransition(opacity: a, child: c)),
              child: rest.active ? _RestPill(rest: rest) : const SizedBox(key: ValueKey('none')),
            ),
          ),
        ),
      ]),
      bottomNavigationBar: Glass(
        opacity: 0.78,
        child: Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
          padding: EdgeInsets.only(bottom: bottom, top: 6),
          child: Row(children: [
            _tabItem(0, CupertinoIcons.flame_fill, tr('Bugün')),
            _tabItem(1, CupertinoIcons.square_list_fill, tr('Program')),
            _tabItem(2, CupertinoIcons.chart_bar_alt_fill, tr('İlerleme')),
          ]),
        ),
      ),
    );
  }

  Widget _tabItem(int i, IconData icon, String label) {
    final on = _tab == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_tab != i) HapticFeedback.selectionClick();
          setState(() => _tab = i);
        },
        child: SizedBox(
          height: 54,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 24, color: on ? C.accent : C.text3),
            const SizedBox(height: 3),
            Text(label, style: t(10.5, w: on ? 650 : 520, color: on ? C.accent : C.text3)),
          ]),
        ),
      ),
    );
  }
}

class _RestPill extends StatelessWidget {
  const _RestPill({required this.rest});
  final RestTimer rest;

  @override
  Widget build(BuildContext context) {
    return Glass(
      key: const ValueKey('pill'),
      radius: 20,
      opacity: 0.8,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: C.accent.withValues(alpha: 0.4))),
        child: Row(children: [
          const Icon(CupertinoIcons.timer, color: C.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('MOLA'), style: t(10.5, w: 700, color: C.accent, ls: 0.8)),
              Text(rest.label, style: t(13.5, w: 600), overflow: TextOverflow.ellipsis),
            ]),
          ),
          Text(clock(rest.left), style: T.num(26, w: 680)),
          const SizedBox(width: 6),
          IconButton(onPressed: rest.skip, icon: const Icon(CupertinoIcons.forward_end_fill, color: C.text2, size: 20)),
        ]),
      ),
    );
  }
}
