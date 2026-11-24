import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'lang.dart';
import 'media.dart';
import 'theme.dart';

/// App-wide objects, reachable from any widget.
class App extends InheritedWidget {
  const App({super.key, required this.store, required this.rest, required super.child});
  final Store store;
  final RestTimer rest;

  static App of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<App>()!;

  /// The one store, for places without a context (initState of the set-up flow).
  static Store? ofStore;

  @override
  bool updateShouldNotify(App oldWidget) => false;
}

const zorlukAd = ['', 'Çok kolay', 'Kolay', 'Orta', 'Zor', 'Çok zor'];

class DifficultyDots extends StatelessWidget {
  const DifficultyDots(this.level, {super.key, this.label = true});
  final int level;
  final bool label;

  @override
  Widget build(BuildContext context) {
    final c = level <= 2 ? C.green : (level == 3 ? C.yellow : C.accent);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Container(
          width: 6,
          height: 14,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(color: i <= level ? c : C.surface3, borderRadius: BorderRadius.circular(3)),
        ),
      if (label) ...[const SizedBox(width: 6), Text(tr(zorlukAd[level.clamp(1, 5)]), style: t(12.5, w: 600, color: c))],
    ]);
  }
}

/// iOS-style segmented control.
class Segmented<V> extends StatelessWidget {
  const Segmented({super.key, required this.items, required this.value, required this.onChanged});
  final List<(V, String)> items;
  final V value;
  final ValueChanged<V> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(13), border: Border.all(color: C.line)),
      child: LayoutBuilder(builder: (context, box) {
        final w = (box.maxWidth) / items.length;
        final i = items.indexWhere((e) => e.$1 == value);
        return Stack(children: [
          if (i >= 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: w * i,
              top: 0,
              bottom: 0,
              width: w,
              child: Container(
                decoration: BoxDecoration(
                  color: C.surface3,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2))],
                  border: Border.all(color: C.line2),
                ),
              ),
            ),
          Row(children: [
            for (final it in items)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(it.$1);
                  },
                  child: SizedBox(height: 36, child: Center(child: Text(it.$2, style: t(14, w: it.$1 == value ? 650 : 520, color: it.$1 == value ? C.text : C.text2)))),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

class SetDots extends StatelessWidget {
  const SetDots({super.key, required this.done, required this.target});
  final int done, target;

  @override
  Widget build(BuildContext context) {
    final n = math.max(done, target);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < n; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < done ? C.accent : Colors.transparent,
            border: Border.all(color: i < done ? C.accent : C.text3, width: 1.2),
          ),
        ),
    ]);
  }
}

/// Smooth line chart for record history.
class MiniChart extends StatelessWidget {
  const MiniChart({super.key, required this.points, this.height = 110, this.unit = ''});
  final List<(DateTime, num)> points;
  final double height;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(height: 48, child: Center(child: Text(tr('İki kayıttan sonra burada grafik çıkar.'), style: T.caption)));
    }
    final ys = points.map((p) => p.$2.toDouble());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: height, child: CustomPaint(painter: _ChartPainter(points))),
      const SizedBox(height: 8),
      Row(children: [
        Text(shortDate(isoDay(points.first.$1)), style: T.caption),
        const Spacer(),
        Text(trf('en düşük {0} · en yüksek {1} {2}', [fmtKg(ys.reduce(math.min)), fmtKg(ys.reduce(math.max)), unit]), style: T.caption),
        const Spacer(),
        Text(shortDate(isoDay(points.last.$1)), style: T.caption),
      ]),
    ]);
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.points);
  final List<(DateTime, num)> points;

  @override
  void paint(Canvas canvas, Size size) {
    final xs = points.map((p) => p.$1.millisecondsSinceEpoch.toDouble()).toList();
    final ys = points.map((p) => p.$2.toDouble()).toList();
    final x0 = xs.first, x1 = math.max(xs.last, x0 + 1);
    var y0 = ys.reduce(math.min), y1 = ys.reduce(math.max);
    if (y1 - y0 < 1e-6) {
      y0 -= 1;
      y1 += 1;
    }
    final pad = (y1 - y0) * 0.18;
    y0 -= pad;
    y1 += pad;
    Offset at(int i) => Offset((xs[i] - x0) / (x1 - x0) * (size.width - 12) + 6, size.height - (ys[i] - y0) / (y1 - y0) * size.height);
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      final a = at(i - 1), b = at(i), mx = (a.dx + b.dx) / 2;
      line.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final area = Path.from(line)
      ..lineTo(at(points.length - 1).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.accent.withValues(alpha: 0.28), C.accent.withValues(alpha: 0)]).createShader(Offset.zero & size));
    canvas.drawPath(line, Paint()
      ..color = C.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round);
    for (var i = 0; i < points.length; i++) {
      final last = i == points.length - 1;
      canvas.drawCircle(at(i), last ? 4.5 : 3, Paint()..color = last ? C.accent : C.bg);
      canvas.drawCircle(at(i), last ? 4.5 : 3, Paint()
        ..color = C.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.points != points;
}

/// Progress ring used on the day summary.
class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, this.size = 64, this.child});
  final double value;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(painter: _RingPainter(v), child: Center(child: child)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v);
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r.deflate(4), 0, math.pi * 2, false, p..color = C.surface3);
    if (v > 0) {
      canvas.drawArc(r.deflate(4), -math.pi / 2, math.pi * 2 * v, false,
          p..shader = SweepGradient(startAngle: -math.pi / 2, endAngle: math.pi * 1.5, colors: const [Color(0xFFFF9F0A), C.accent, Color(0xFFFF9F0A)]).createShader(r));
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v;
}

/// Parses "4×8 · RIR 2" into (sets, reps).
(int?, int?) parseDose(String? d) {
  if (d == null) return (null, null);
  final m = RegExp(r'^(\d+)\s*×\s*(\d+)').firstMatch(d);
  if (m != null) return (int.parse(m[1]!), int.parse(m[2]!));
  final s = RegExp(r'^(\d+)\s*×').firstMatch(d);
  return (s == null ? null : int.parse(s[1]!), null);
}
