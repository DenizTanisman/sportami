import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'data.dart';
import 'figure.dart';
import 'lang.dart';
import 'theme.dart';

/// ExerciseDB V1 (free tier). Their terms: do not store API data; reference
/// the media URL the API returns (it rotates weekly). So every launch asks the
/// API again and the GIF lives only in the in-memory image cache.
class ExDb {
  static final _urls = <String, Future<String?>>{};

  static Future<String?> gifUrl(String id) => _urls.putIfAbsent(id, () async {
        try {
          final c = HttpClient()..connectionTimeout = const Duration(seconds: 8);
          final rq = await c.getUrl(Uri.parse('https://oss.exercisedb.dev/api/v1/exercises/$id'));
          final rs = await rq.close().timeout(const Duration(seconds: 10));
          if (rs.statusCode != 200) {
            _urls.remove(id);
            return null;
          }
          final j = jsonDecode(await rs.transform(utf8.decoder).join()) as Map;
          c.close();
          return (j['data'] as Map?)?['gifUrl'] as String?;
        } catch (_) {
          _urls.remove(id); // try again next time
          return null;
        }
      });
}

/// Loaded once at start: stick-figure keyframes by key.
class Figures {
  static Map<String, dynamic> data = {};
  static Future<void> load() async => data = jsonDecode(await rootBundle.loadString('assets/data/figur.json')) as Map<String, dynamic>;
  /// The exercise's own figure, or the one stored under its id.
  static Map? of(Exercise e) => (e.figure == null ? null : data[e.figure] as Map?) ?? data[e.id] as Map?;
}

/// Hero media: anatomical GIF from ExerciseDB when there is one, otherwise the
/// app's own figure. When both exist the viewer can switch.
class ExerciseMedia extends StatefulWidget {
  const ExerciseMedia({super.key, required this.exercise, this.height = 300});
  final Exercise exercise;
  final double height;

  @override
  State<ExerciseMedia> createState() => _ExerciseMediaState();
}

class _ExerciseMediaState extends State<ExerciseMedia> {
  bool _figure = false;
  Future<String?>? _url;
  double _speed = 1;

  @override
  void initState() {
    super.initState();
    final id = widget.exercise.exdb;
    if (id != null) _url = ExDb.gifUrl(id);
    _figure = id == null;
  }

  @override
  Widget build(BuildContext context) {
    final fig = Figures.of(widget.exercise);
    final canSwitch = widget.exercise.exdb != null && fig != null;
    return SizedBox(
      height: widget.height,
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _figure || _url == null
                ? (fig != null ? _figureStage(fig) : _empty())
                : FutureBuilder<String?>(
                    key: const ValueKey('gif'),
                    future: _url,
                    builder: (context, s) {
                      if (s.connectionState != ConnectionState.done) return _studio(const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9A9AA0)))));
                      if (s.data == null) return fig != null ? _figureStage(fig, note: tr('Animasyon için internet gerekiyor; çizim gösteriliyor')) : _empty(note: tr('Animasyon için internet gerekiyor'));
                      return _studio(Image.network(
                        s.data!,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => fig != null ? FigureView(data: fig) : const SizedBox(),
                      ), credit: true);
                    },
                  ),
          ),
        ),
        if (canSwitch)
          Positioned(
            right: 14,
            bottom: 14,
            child: _Switch(figure: _figure, onChanged: (v) => setState(() => _figure = v)),
          ),
        if (_figure && fig != null)
          Positioned(
            left: 14,
            bottom: 14,
            child: GestureDetector(
              onTap: () => setState(() => _speed = _speed < 1 ? 1 : 0.4),
              child: Pill(_speed < 1 ? tr('½× yavaş') : '1×', color: C.text, fill: const Color(0x33000000)),
            ),
          ),
      ]),
    );
  }

  Widget _studio(Widget child, {bool credit = false}) {
    return Container(
      key: const ValueKey('studio'),
      // Pure white like the GIF's own background, so its square edge disappears.
      color: Colors.white,
      child: Stack(children: [
        Positioned.fill(child: Padding(padding: const EdgeInsets.fromLTRB(24, 56, 24, 30), child: child)),
        if (credit) Positioned(left: 16, bottom: 12, child: Text(tr('Animasyon: ExerciseDB'), style: t(10.5, w: 520, color: const Color(0xFF8E8E93)))),
      ]),
    );
  }

  Widget _figureStage(Map fig, {String? note}) {
    return Container(
      key: const ValueKey('fig'),
      decoration: const BoxDecoration(
        gradient: RadialGradient(center: Alignment(0, -0.1), radius: 1.0, colors: [Color(0xFF202026), Color(0xFF0C0C0F)]),
      ),
      child: Stack(children: [
        Positioned.fill(child: Padding(padding: const EdgeInsets.fromLTRB(20, 60, 20, 26), child: FigureView(data: fig, speed: _speed))),
        if (note != null) Positioned(left: 16, right: 16, top: 64, child: Text(note, style: T.caption, textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _empty({String? note}) => Container(
        color: C.surface,
        alignment: Alignment.center,
        child: Text(note ?? tr('Bu hareketin animasyonu yok'), style: T.caption),
      );
}

class _Switch extends StatelessWidget {
  const _Switch({required this.figure, required this.onChanged});
  final bool figure;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String s, bool on, bool v) => GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: on ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(99)),
            child: Text(s, style: t(12.5, w: 620, color: on ? Colors.black : Colors.white)),
          ),
        );
    return Glass(
      radius: 99,
      opacity: 0.45,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [seg(tr('Anatomi'), !figure, false), seg(tr('Çizim'), figure, true)]),
      ),
    );
  }
}

/// Small still figure for list rows.
class ExThumb extends StatelessWidget {
  const ExThumb({super.key, required this.exercise, this.size = 58});
  final Exercise exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fig = Figures.of(exercise);
    // No drawing of our own: show the anatomical GIF on a small white card.
    if (fig == null && exercise.exdb != null) {
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: FutureBuilder<String?>(
          future: ExDb.gifUrl(exercise.exdb!),
          builder: (context, s) => s.data == null
              ? const Icon(Icons.fitness_center_rounded, color: Color(0xFFB0B0B5), size: 22)
              : Image.network(s.data!, fit: BoxFit.cover, filterQuality: FilterQuality.medium, errorBuilder: (_, _, _) => const SizedBox()),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF24242A), Color(0xFF16161A)]),
        border: Border.all(color: C.line),
      ),
      padding: const EdgeInsets.all(4),
      child: fig == null ? const Icon(Icons.fitness_center_rounded, color: C.text3, size: 22) : FigureView(data: fig, playing: false, fit: true),
    );
  }
}

// ---------------------------------------------------------------------------
// Rest timer
// ---------------------------------------------------------------------------

class RestTimer extends ChangeNotifier {
  DateTime? _end;
  int total = 0;
  String label = '';
  Timer? _t;
  bool justFinished = false;

  /// The island over other apps gives the alert itself while it is shown.
  bool sessiz = false;

  bool get active => _end != null;
  DateTime? get end => _end;
  int get left => _end == null ? 0 : (_end!.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(0, 3600);

  void start(int seconds, String what) {
    total = seconds;
    label = what;
    justFinished = false;
    _end = DateTime.now().add(Duration(seconds: seconds));
    WakelockPlus.enable();
    _t?.cancel();
    _t = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (left <= 0) {
        _finish(alert: true);
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void add(int s) {
    if (_end == null) return;
    _end = _end!.add(Duration(seconds: s));
    total = (total + s).clamp(1, 3600);
    if (left <= 0) _finish(alert: false);
    notifyListeners();
  }

  void skip() => _finish(alert: false);

  Future<void> _finish({required bool alert}) async {
    _t?.cancel();
    _end = null;
    justFinished = alert;
    notifyListeners();
    if (alert && !sessiz) {
      for (var i = 0; i < 3; i++) {
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 220));
      }
      SystemSound.play(SystemSoundType.alert);
    }
    // Keep the screen on a little longer so the next set can start.
    Future.delayed(const Duration(minutes: 3), () {
      if (_end == null) WakelockPlus.disable();
    });
  }
}

String clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
