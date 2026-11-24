import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

import 'data.dart';
import 'theme.dart';

/// Front and back muscle map. Artwork: react-native-body-highlighter (MIT).
class BodyArt {
  BodyArt._(this.front, this.back, this.outlines);
  final List<(String, Path)> front, back;
  final List<Path> outlines;

  static BodyArt? _cache;
  static Future<BodyArt> load() async {
    if (_cache != null) return _cache!;
    final j = jsonDecode(await rootBundle.loadString('assets/data/vucut.json')) as Map;
    List<(String, Path)> parts(List l, {double dx = 0}) => [
          for (final p in l)
            for (final d in p['paths']) (p['slug'] as String, parseSvgPathData(d as String).shift(Offset(dx, 0))),
        ];
    return _cache = BodyArt._(parts(j['front']), parts(j['back'], dx: -724), [for (final d in j['outlines']) parseSvgPathData(d as String)]);
  }
}

enum Load { primary, secondary, stabilizer }

class BodyMap extends StatefulWidget {
  const BodyMap({super.key, required this.exercise, this.height = 300});
  final Exercise exercise;
  final double height;

  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> {
  BodyArt? _art;

  @override
  void initState() {
    super.initState();
    BodyArt.load().then((a) {
      if (mounted) setState(() => _art = a);
    });
  }

  Map<String, Load> get _loads {
    final m = <String, Load>{};
    for (final x in widget.exercise.stabilizers) {
      m[x.region] = Load.stabilizer;
    }
    for (final x in widget.exercise.secondary) {
      m[x.region] = Load.secondary;
    }
    for (final x in widget.exercise.primary) {
      m[x.region] = Load.primary;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final art = _art;
    return SizedBox(
      height: widget.height,
      child: art == null
          ? const SizedBox()
          : Row(children: [
              Expanded(child: _side(art.front, art.outlines.where((o) => o.getBounds().center.dx < 724).toList(), 0, 'Ön')),
              Expanded(child: _side(art.back, art.outlines.where((o) => o.getBounds().center.dx >= 724).map((o) => o.shift(const Offset(-724, 0))).toList(), 0, 'Arka')),
            ]),
    );
  }

  Widget _side(List<(String, Path)> parts, List<Path> outlines, double dx, String label) {
    return Column(children: [
      Expanded(child: CustomPaint(painter: _BodyPainter(parts, outlines, _loads), size: Size.infinite)),
      const SizedBox(height: 6),
      Text(label, style: T.caption),
    ]);
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter(this.parts, this.outlines, this.loads);
  final List<(String, Path)> parts;
  final List<Path> outlines;
  final Map<String, Load> loads;

  @override
  void paint(Canvas canvas, Size size) {
    // The artwork sits in a 724 × 1448 box; the figure itself is narrower.
    const box = Rect.fromLTWH(60, 150, 604, 1250);
    final s = (size.height / box.height).clamp(0.0, size.width / box.width);
    canvas.save();
    canvas.translate((size.width - box.width * s) / 2 - box.left * s, (size.height - box.height * s) / 2 - box.top * s);
    canvas.scale(s);
    for (final o in outlines) {
      canvas.drawPath(o, Paint()
        ..color = const Color(0x1FFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / s * 0.9);
    }
    for (final (slug, path) in parts) {
      final l = loads[slug];
      Color c;
      if (slug == 'hair') {
        c = const Color(0xFF1F1F23);
      } else if (slug == 'head' || slug == 'hands' || slug == 'feet' || slug == 'knees' || slug == 'ankles') {
        c = const Color(0xFF2A2A2F);
      } else if (l == Load.primary) {
        c = C.accent;
      } else if (l == Load.secondary) {
        c = const Color(0xFFFFA36F);
      } else if (l == Load.stabilizer) {
        c = const Color(0xFF5E8FD6);
      } else {
        c = const Color(0xFF34343A);
      }
      canvas.drawPath(path, Paint()..color = c);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BodyPainter old) => old.loads != loads;
}

/// Legend row under the map.
class BodyLegend extends StatelessWidget {
  const BodyLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(s, style: T.caption),
        ]);
    return Wrap(spacing: 16, runSpacing: 6, alignment: WrapAlignment.center, children: [
      dot(C.accent, 'Ana kas'),
      dot(const Color(0xFFFFA36F), 'Yardımcı'),
      dot(const Color(0xFF5E8FD6), 'Sabitleyici'),
    ]);
  }
}
