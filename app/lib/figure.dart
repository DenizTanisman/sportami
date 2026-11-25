import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'theme.dart';

/// Port of the lesson's stick-figure engine (side view, figure faces right).
/// Limb angles: 0 = down, 90 = right, 180 = up. Torso: 0 = up, 90 = right.
/// Keyframes come from assets/data/figur.json.
const double _g = 188;
const _len = {'tor': 48.0, 'nk': 18.0, 'hr': 9.0, 'ua': 28.0, 'fa': 26.0, 'th': 42.0, 'sh': 41.0, 'ft': 13.0};
const _def = <String, dynamic>{'ax': 110, 'ay': null, 'air': 0, 'gy': 0, 'o': 1, 't': 2, 'hd': 0, 'ua1': 6, 'fa1': 4, 'ua2': -6, 'fa2': -4, 'th1': 0, 'sh1': 0, 'th2': 0, 'sh2': 0, 'ft1': 90, 'ft2': 90};
const _rad = math.pi / 180;

typedef P = Offset;
P _dv(num a) => Offset(math.sin(a * _rad), math.cos(a * _rad));
P _uv(num a) => Offset(math.sin(a * _rad), -math.cos(a * _rad));
P _ad(P p, P v, double l) => p + v * l;
double _d(dynamic v) => (v as num).toDouble();
P _pt(dynamic v) => Offset(_d(v[0]), _d(v[1]));

List<P> _ik(P root, P tg, double a, double b, String pref) {
  var dx = tg.dx - root.dx, dy = tg.dy - root.dy, d = math.sqrt(dx * dx + dy * dy);
  final dmax = a + b - 0.3;
  if (d > dmax) {
    tg = Offset(root.dx + dx / d * dmax, root.dy + dy / d * dmax);
    dx = tg.dx - root.dx;
    dy = tg.dy - root.dy;
    d = dmax;
  }
  final dmin = (a - b).abs() + 0.5;
  if (d < dmin) d = dmin;
  final base = math.atan2(dy, dx), c = ((a * a + d * d - b * b) / (2 * a * d)).clamp(-1.0, 1.0), al = math.acos(c);
  final j1 = Offset(root.dx + a * math.cos(base + al), root.dy + a * math.sin(base + al));
  final j2 = Offset(root.dx + a * math.cos(base - al), root.dy + a * math.sin(base - al));
  P j;
  if (pref == 'f') {
    j = j1.dx > j2.dx ? j1 : j2;
  } else if (pref == 'b') {
    j = j1.dx < j2.dx ? j1 : j2;
  } else if (pref == 'u') {
    j = j1.dy < j2.dy ? j1 : j2;
  } else {
    j = j1.dy > j2.dy ? j1 : j2;
  }
  return [j, tg];
}

Map<String, P> _solve(Map p, Map ex) {
  final o = <String, P>{'H': Offset.zero};
  o['S'] = _ad(o['H']!, _uv(_d(p['t'])), _len['tor']!);
  o['C'] = _ad(o['S']!, _uv(_d(p['t']) + _d(p['hd'])), _len['nk']!);
  for (final i in [1, 2]) {
    o['K$i'] = _ad(o['H']!, _dv(_d(p['th$i'])), _len['th']!);
    o['A$i'] = _ad(o['K$i']!, _dv(_d(p['sh$i'])), _len['sh']!);
    o['T$i'] = _ad(o['A$i']!, _dv(_d(p['ft$i'])), _len['ft']!);
    o['E$i'] = _ad(o['S']!, _dv(_d(p['ua$i'])), _len['ua']!);
    o['W$i'] = _ad(o['E$i']!, _dv(_d(p['fa$i'])), _len['fa']!);
  }
  double tx, ty;
  if (p['hip'] != null) {
    tx = _d(p['hip'][0]);
    ty = _d(p['hip'][1]);
  } else {
    final anc = (ex['anc'] ?? 'A1') as String;
    if (anc == 'A1' || anc == 'A2' || anc == 'H') {
      var m = -1e9;
      final keys = ['H', 'S'];
      for (final i in [1, 2]) {
        if (p['k$i'] == null) keys.addAll(['K$i', 'A$i', 'T$i']);
        if (p['w$i'] == null) keys.addAll(['E$i', 'W$i']);
      }
      for (final k in keys) {
        m = math.max(m, o[k]!.dy);
      }
      ty = _g - 4 - _d(p['gy']) - _d(p['air']) - m;
      tx = _d(p['ax']) - o[anc]!.dx;
    } else {
      tx = _d(p['ax']) - o[anc]!.dx;
      ty = (p['ay'] != null ? _d(p['ay']) : _g - 4) - o[anc]!.dy;
    }
  }
  final sh = Offset(tx, ty);
  o.updateAll((k, v) => v + sh);
  final kb = (ex['kb'] ?? const {}) as Map, eb = (ex['eb'] ?? const {}) as Map;
  for (final i in [1, 2]) {
    if (p['k$i'] != null) {
      final r = _ik(o['H']!, _pt(p['k$i']), _len['th']!, _len['sh']!, (kb['$i'] ?? 'f') as String);
      o['K$i'] = r[0];
      o['A$i'] = r[1];
      o['T$i'] = _ad(r[1], _dv(_d(p['ft$i'])), _len['ft']!);
    }
    if (p['w$i'] != null) {
      final r = _ik(o['S']!, _pt(p['w$i']), _len['ua']!, _len['fa']!, (eb['$i'] ?? 'd') as String);
      o['E$i'] = r[0];
      o['W$i'] = r[1];
    }
  }
  return o;
}

Map _lerp(Map a, Map b, double u) {
  final r = {};
  for (final k in a.keys) {
    final x = a[k], y = b[k];
    if (x is num && y is num) {
      r[k] = x + (y - x) * u;
    } else if (x is List && y is List) {
      r[k] = [_d(x[0]) + (_d(y[0]) - _d(x[0])) * u, _d(x[1]) + (_d(y[1]) - _d(x[1])) * u];
    } else {
      r[k] = u < 0.5 ? x : y;
    }
  }
  return r;
}

double _ease(double u) => 0.5 - 0.5 * math.cos(math.pi * u);

class FigureAnim {
  FigureAnim(this.ex) {
    frames = [for (final k in ex['kf'] as List) {..._def, ...(ex['base'] as Map? ?? const {}), ...k as Map}];
    final tm = ex['tm'] ?? 600;
    for (var i = 0; i < frames.length; i++) {
      final h = _d(frames[i]['hold'] ?? 0), d = tm is List ? _d(tm[i]) : _d(tm);
      hold.add(h);
      dur.add(d);
      total += h + d;
    }
    if (ex['ball'] != null) balls = [for (final f in frames) _ballPos(f, _solve(f, ex))];
    final vb = ((ex['vb'] ?? '0 -55 240 250') as String).split(' ').map(double.parse).toList();
    view = Rect.fromLTWH(vb[0], vb[1], vb[2], vb[3]);
  }

  final Map ex;
  late final List<Map> frames;
  final hold = <double>[], dur = <double>[];
  double total = 0;
  List<P>? balls;
  late final Rect view;

  P _ballPos(Map p, Map<String, P> o) {
    if (p['b'] != null) return _pt(p['b']);
    final bo = ex['bo'] ?? const [0, 0];
    return o['W1']! + _pt(bo);
  }

  /// Pose and ball at time [ms].
  (Map, P?) at(double ms) {
    var t = ms % total;
    var i = 0;
    final n = frames.length;
    while (true) {
      if (t < hold[i]) return (frames[i], balls?[i]);
      t -= hold[i];
      if (t < dur[i]) break;
      t -= dur[i];
      i = (i + 1) % n;
    }
    final j = (i + 1) % n, u = _ease(t / dur[i]);
    final p = _lerp(frames[i], frames[j], u);
    P? ball;
    if (balls != null) ball = Offset.lerp(balls![i], balls![j], u);
    return (p, ball);
  }

  (Map, P?) still() {
    final i = (ex['still'] as num?)?.toInt() ?? (1 % frames.length);
    return (frames[i], balls?[i]);
  }
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.anim, this.pose, this.ball, {this.fit = false});
  final FigureAnim anim;
  final Map pose;
  final P? ball;

  /// Zoom to the figure itself (list thumbnails) instead of the whole scene.
  final bool fit;

  static const near = Color(0xFFEDEDF0), far = Color(0xFF55565C), prop = Color(0xFF34353B), propLine = Color(0xFF44454C);

  @override
  void paint(Canvas canvas, Size size) {
    final ex = anim.ex;
    var v = anim.view;
    if (fit) {
      final o = _solve(pose, ex);
      var b = Rect.fromPoints(o.values.first, o.values.first);
      for (final p in o.values) {
        b = b.expandToInclude(Rect.fromCenter(center: p, width: 1, height: 1));
      }
      b = b.inflate(16);
      final side = math.max(b.width, b.height);
      v = Rect.fromCenter(center: b.center, width: side, height: side);
    }
    final s = math.min(size.width / v.width, size.height / v.height);
    canvas.save();
    canvas.translate((size.width - v.width * s) / 2 - v.left * s, (size.height - v.height * s) / 2 - v.top * s);
    canvas.scale(s);

    // Floor with a soft fade at both ends.
    final floor = Rect.fromLTRB(-60, _g - 0.6, 300, _g + 0.6);
    canvas.drawRect(floor, Paint()..shader = const LinearGradient(colors: [Color(0x00FFFFFF), Color(0x33FFFFFF), Color(0x00FFFFFF)]).createShader(floor));

    for (final pr in (ex['props'] as List? ?? const [])) {
      final k = pr['k'];
      final cls = pr['c'] ?? 'pr';
      final fill = cls == 'box' ? const Color(0xFF3B342D) : (cls == 'wall' ? const Color(0xFF222328) : prop);
      if (k == 'rect') {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(_d(pr['x']), _d(pr['y']), _d(pr['w']), _d(pr['h'])), Radius.circular(_d(pr['rx'] ?? 2))), Paint()..color = fill);
      } else if (k == 'line') {
        canvas.drawLine(Offset(_d(pr['x1']), _d(pr['y1'])), Offset(_d(pr['x2']), _d(pr['y2'])), Paint()
          ..color = propLine
          ..strokeWidth = _d(pr['w'] ?? 4)
          ..strokeCap = StrokeCap.round);
      } else if (k == 'circ') {
        canvas.drawCircle(Offset(_d(pr['x']), _d(pr['y'])), _d(pr['r']), Paint()..color = fill);
      } else if (k == 'rim') {
        final x = _d(pr['x']), y = _d(pr['y']);
        final pl = Paint()
          ..color = propLine
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x + 30, y - 34), Offset(x + 30, y + 10), pl);
        canvas.drawLine(Offset(x, y), Offset(x + 28, y), Paint()
          ..color = C.accent
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
        final net = Path()
          ..moveTo(x + 2, y + 2)
          ..lineTo(x + 6, y + 22)
          ..lineTo(x + 22, y + 22)
          ..lineTo(x + 26, y + 2)
          ..moveTo(x + 10, y + 2)
          ..lineTo(x + 11, y + 22)
          ..moveTo(x + 18, y + 2)
          ..lineTo(x + 17, y + 22);
        canvas.drawPath(net, Paint()
          ..color = const Color(0x88FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
      }
    }

    final o = _solve(pose, ex);
    final dyn = (ex['dyn'] as List? ?? const []);
    if (dyn.contains('benchUnder')) {
      final x1 = math.min(o['S']!.dx, o['H']!.dx) - 16, x2 = math.max(o['S']!.dx, o['H']!.dx) + 8, y = math.max(o['S']!.dy, o['H']!.dy) + 5;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x1, y, x2 - x1, 7), const Radius.circular(2)), Paint()..color = prop);
      final lp = Paint()
        ..color = propLine
        ..strokeWidth = 4;
      canvas.drawLine(Offset(x1 + 8, y + 6), Offset(x1 + 8, _g), lp);
      canvas.drawLine(Offset(x2 - 8, y + 6), Offset(x2 - 8, _g), lp);
    }
    if (dyn.contains('incline')) {
      final vv = o['S']! - o['H']!;
      final l = vv.distance;
      var nn = Offset(-vv.dy / l, vv.dx / l);
      if (nn.dy <= 0) nn = -nn;
      final a = o['H']! + nn * 7, b = o['S']! + nn * 7 - vv * 0.1;
      final lp = Paint()
        ..color = propLine
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a, b + vv * 0.25, lp);
      canvas.drawLine(a - const Offset(4, 0), a + const Offset(26, 0), lp);
      canvas.drawLine(a + const Offset(6, 0), Offset(a.dx + 6, _g), lp..strokeWidth = 4);
    }
    if (dyn.contains('cable')) {
      canvas.drawLine(_pt(ex['cable']), o['W1']!, Paint()
        ..color = const Color(0x99FFFFFF)
        ..strokeWidth = 1.2);
    }

    final hl = Set<String>.from(ex['hl'] ?? const []);
    final op = _d(pose['o']).clamp(0.0, 1.0);
    Paint seg(Color base, String key, double w) => Paint()
      ..color = (hl.contains(key) ? C.accent : base).withValues(alpha: op * (base == far && hl.contains(key) ? 0.55 : 1))
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

    void limb(P a, P b, Paint p) => canvas.drawLine(a, b, p);

    // Far side.
    limb(o['H']!, o['K2']!, seg(far, 'th', 9));
    limb(o['K2']!, o['A2']!, seg(far, 'sh', 8));
    limb(o['A2']!, o['T2']!, seg(far, 'sh', 6));
    limb(o['S']!, o['E2']!, seg(far, 'ua', 7.5));
    limb(o['E2']!, o['W2']!, seg(far, 'fa', 6.5));
    _held(canvas, o, far: true, op: op);

    // Torso, neck, head.
    limb(o['H']!, o['S']!, seg(near, 'torso', 12));
    final nv = o['C']! - o['S']!;
    final nl = nv.distance == 0 ? 1 : nv.distance;
    limb(o['S']!, o['C']! - nv / nl.toDouble() * _len['hr']!, seg(near, 'nk', 6.5));
    canvas.drawCircle(o['C']!, _len['hr']!, Paint()..color = near.withValues(alpha: op));

    // Near side.
    limb(o['H']!, o['K1']!, seg(near, 'th', 10));
    limb(o['K1']!, o['A1']!, seg(near, 'sh', 9));
    limb(o['A1']!, o['T1']!, seg(near, 'sh', 7));
    _held(canvas, o, far: false, op: op);
    limb(o['S']!, o['E1']!, seg(near, 'ua', 8.5));
    limb(o['E1']!, o['W1']!, seg(near, 'fa', 7.5));

    final b = ex['ball'];
    if (b != null && ball != null) {
      final k = b['k'];
      if (k == 'mb') {
        canvas.drawCircle(ball!, _d(b['r'] ?? 10), Paint()..color = const Color(0xFF8A5A3C).withValues(alpha: op));
      } else {
        final w = _d(b['w']), h = _d(b['h']);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: ball!, width: w, height: h), Radius.circular(k == 'sb' ? 8 : 5)),
            Paint()..color = (k == 'pad' ? C.blue : const Color(0xFF7A6A52)).withValues(alpha: op));
      }
    }
    canvas.restore();
  }

  void _held(Canvas canvas, Map<String, P> o, {required bool far, required double op}) {
    final h = anim.ex['held'];
    if (h == null) return;
    final ho = anim.ex['ho'] != null ? _pt(anim.ex['ho']) : Offset.zero;
    final hat = (anim.ex['hat'] ?? 'W') as String;
    if ((h == 'bb' || h == 'tb') && !far) {
      final c = o['${hat}1']! + ho;
      final r = _d(anim.ex['pr'] ?? 15);
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF2B2C31).withValues(alpha: op));
      canvas.drawCircle(c, r, Paint()
        ..color = const Color(0xFF5B5D64).withValues(alpha: op)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      canvas.drawCircle(c, 3, Paint()..color = const Color(0xFFBFC1C6).withValues(alpha: op));
    } else if (h == 'db' || h == 'db1' || h == 'gob') {
      if (far && h != 'db') return;
      final i = far ? 2 : 1, w = (h == 'gob' && !far) ? 15.0 : 13.0;
      final c = o['W$i']! + ho;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w, height: w), const Radius.circular(3)),
          Paint()..color = (far ? const Color(0xFF3A3B40) : const Color(0xFF8E9096)).withValues(alpha: op));
    } else if (h == 'kb' && !far) {
      final e = o['E1']!, w = o['W1']!, v = w - e, l = v.distance == 0 ? 1.0 : v.distance;
      canvas.drawCircle(w + v / l * 9, 8.5, Paint()..color = const Color(0xFF8E9096).withValues(alpha: op));
      canvas.drawCircle(w + v / l * 2, 4.5, Paint()
        ..color = const Color(0xFF8E9096).withValues(alpha: op)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _FigurePainter old) => true;
}

/// Looping figure animation. Pauses with TickerMode (off-screen routes).
class FigureView extends StatefulWidget {
  const FigureView({super.key, required this.data, this.playing = true, this.speed = 1, this.fit = false});
  final Map data;
  final bool playing;
  final double speed;
  final bool fit;

  @override
  State<FigureView> createState() => _FigureViewState();
}

class _FigureViewState extends State<FigureView> with SingleTickerProviderStateMixin {
  late final FigureAnim _a = FigureAnim(widget.data);
  late final Ticker _ticker;
  double _clock = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      final dt = (d - _last).inMicroseconds / 1000.0;
      _last = d;
      setState(() => _clock += math.min(dt, 100) * widget.speed);
    });
    if (widget.playing) _ticker.start();
  }

  @override
  void didUpdateWidget(FigureView old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!widget.playing && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (pose, ball) = widget.playing ? _a.at(_clock) : _a.still();
    return CustomPaint(painter: _FigurePainter(_a, pose, ball, fit: widget.fit), size: Size.infinite);
  }
}

/// The animation as PNG frames, for the island drawn outside Flutter (Android overlay).
/// Returns (milliseconds per frame, frames). A single-pose figure gives one frame.
Future<(int, List<Uint8List>)> figureFramesPng(Map data, {int size = 128}) async {
  final a = FigureAnim(data);
  final count = a.total <= 0 || a.frames.length < 2 ? 1 : (a.total / 70).round().clamp(12, 36);
  final out = <Uint8List>[];
  for (var i = 0; i < count; i++) {
    final (pose, ball) = count == 1 ? a.still() : a.at(a.total * i / count);
    final rec = ui.PictureRecorder();
    _FigurePainter(a, pose, ball).paint(Canvas(rec), Size(size.toDouble(), size.toDouble()));
    final img = await rec.endRecording().toImage(size, size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    if (bytes != null) out.add(bytes.buffer.asUint8List());
  }
  return (count == 1 ? 1000 : (a.total / count).round(), out);
}
