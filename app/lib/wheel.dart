import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'theme.dart';

const _rowH = 42.0;

/// A brushed-metal drum: one scrolling column of values with a haptic detent
/// on every row. Digits look engraved; the centre row sits under a glass lens.
class MetalWheel extends StatefulWidget {
  const MetalWheel({super.key, required this.labels, required this.index, required this.onChanged, this.width = 84, this.semantic = ''});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final double width;
  final String semantic;

  @override
  State<MetalWheel> createState() => _MetalWheelState();
}

class _MetalWheelState extends State<MetalWheel> {
  late final FixedExtentScrollController _c = FixedExtentScrollController(initialItem: widget.index);
  late int _cur = widget.index;

  @override
  void didUpdateWidget(MetalWheel old) {
    super.didUpdateWidget(old);
    // Value changed from outside (prefill, set counter): move without a detent buzz.
    if (widget.index != _cur && _c.hasClients) {
      _cur = widget.index;
      _c.animateToItem(widget.index, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semantic,
      value: widget.labels[_cur.clamp(0, widget.labels.length - 1)],
      increasedValue: _cur + 1 < widget.labels.length ? widget.labels[_cur + 1] : null,
      decreasedValue: _cur > 0 ? widget.labels[_cur - 1] : null,
      onIncrease: () => _c.animateToItem(_cur + 1, duration: const Duration(milliseconds: 200), curve: Curves.easeOut),
      onDecrease: () => _c.animateToItem(_cur - 1, duration: const Duration(milliseconds: 200), curve: Curves.easeOut),
      child: SizedBox(
        width: widget.width,
        height: _rowH * 3.4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(fit: StackFit.expand, children: [
            const CustomPaint(painter: _DrumPainter()),
            ListWheelScrollView.useDelegate(
              controller: _c,
              itemExtent: _rowH,
              diameterRatio: 1.35,
              perspective: 0.0045,
              squeeze: 1.0,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) {
                if (i == _cur) return;
                _cur = i;
                HapticFeedback.selectionClick();
                widget.onChanged(i);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.labels.length,
                builder: (context, i) => Center(child: _Engraved(widget.labels[i])),
              ),
            ),
            const IgnorePointer(child: CustomPaint(painter: _LensPainter())),
          ]),
        ),
      ),
    );
  }
}

class _Engraved extends StatelessWidget {
  const _Engraved(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = T.num(23, w: 700, color: const Color(0xFF17181B));
    // A one-pixel light shadow below the glyph reads as a cut into metal.
    return Text(text, style: s.copyWith(shadows: const [Shadow(color: Color(0x99FFFFFF), offset: Offset(0, 1), blurRadius: 0.5)]));
  }
}

/// Cylinder shading: dark rims, bright specular band, fine circumferential
/// brushing.
class _DrumPainter extends CustomPainter {
  const _DrumPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, 0.16, 0.36, 0.47, 0.53, 0.66, 0.86, 1], colors: [
          Color(0xFF1D1E22),
          Color(0xFF5D6066),
          Color(0xFFB9BCC2),
          Color(0xFFEDEFF2),
          Color(0xFFE2E4E8),
          Color(0xFFA7AAB0),
          Color(0xFF4D5056),
          Color(0xFF17181B),
        ]).createShader(r),
    );
    // Brushing: deterministic hairlines so the texture does not shimmer.
    final rnd = math.Random(7);
    final p = Paint()..strokeWidth = 0.6;
    for (double y = 0; y < size.height; y += 1.3) {
      final a = 0.025 + rnd.nextDouble() * 0.07;
      p.color = (rnd.nextBool() ? Colors.white : Colors.black).withValues(alpha: a);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    // Side bevel so the drum reads as round left to right as well.
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0x55000000)], stops: [0, 0.18, 0.82, 1]).createShader(r),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LensPainter extends CustomPainter {
  const _LensPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final lens = Rect.fromCenter(center: Offset(size.width / 2, cy), width: size.width - 6, height: _rowH);
    final rr = RRect.fromRectAndRadius(lens, const Radius.circular(9));
    // Glass: faint top sheen and edge lines.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x33FFFFFF), Color(0x05FFFFFF), Color(0x14000000)]).createShader(lens),
    );
    canvas.drawRRect(rr, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x55000000));
    canvas.drawRRect(rr.deflate(1), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x66FFFFFF));
    // Outer bezel.
    final o = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.drawRRect(o, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x88000000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// One value made of one or two drums (whole part + quarter), with its label.
class ValueWheel extends StatefulWidget {
  const ValueWheel({super.key, required this.field, required this.value, required this.onChanged, this.compact = false});
  final Field field;
  final num? value;
  final ValueChanged<num?> onChanged;
  final bool compact;

  @override
  State<ValueWheel> createState() => _ValueWheelState();
}

class _ValueWheelState extends State<ValueWheel> {
  static const fractions = [0.0, 0.25, 0.5, 0.75];

  late List<num?> _whole;
  late List<String> _wholeLabels;
  int _wi = 0, _fi = 0;

  @override
  void initState() {
    super.initState();
    _build();
    _split(widget.value);
  }

  @override
  void didUpdateWidget(ValueWheel old) {
    super.didUpdateWidget(old);
    if (old.field != widget.field) _build();
    if (widget.value != _join()) _split(widget.value);
  }

  void _build() {
    final f = widget.field;
    _whole = [if (f.optional) null];
    for (double x = f.min; x <= f.max + 1e-9; x += f.step) {
      _whole.add(x.round());
    }
    _wholeLabels = [for (final v in _whole) v == null ? '–' : '$v'];
  }

  void _split(num? v) {
    if (v == null) {
      _wi = 0;
      _fi = 0;
      return;
    }
    final base = widget.field.fraction ? v.floor() : v;
    var best = double.infinity;
    for (var i = 0; i < _whole.length; i++) {
      final w = _whole[i];
      if (w == null) continue;
      final d = (w - base).abs().toDouble();
      if (d < best) {
        best = d;
        _wi = i;
      }
    }
    if (widget.field.fraction && _whole[_wi] != null) {
      final fr = v - _whole[_wi]!;
      var bd = double.infinity;
      for (var i = 0; i < fractions.length; i++) {
        final d = (fractions[i] - fr).abs();
        if (d < bd) {
          bd = d;
          _fi = i;
        }
      }
    }
  }

  num? _join() {
    final w = _whole[_wi];
    if (w == null) return null;
    if (!widget.field.fraction) return w;
    final v = w + fractions[_fi];
    return v == v.roundToDouble() ? v.toInt() : v;
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(f.unit.isEmpty ? f.label : '${f.label} · ${f.unit}', style: t(11.5, w: 620, color: C.text3, ls: 0.6)),
      const SizedBox(height: 8),
      Row(mainAxisSize: MainAxisSize.min, children: [
        MetalWheel(
          labels: _wholeLabels,
          index: _wi,
          width: f.fraction ? 78 : 92,
          semantic: f.label,
          onChanged: (i) {
            _wi = i;
            widget.onChanged(_join());
          },
        ),
        if (f.fraction) ...[
          const SizedBox(width: 4),
          MetalWheel(
            labels: const [',00', ',25', ',50', ',75'],
            index: _fi,
            width: 58,
            semantic: '${f.label} ondalık',
            onChanged: (i) {
              _fi = i;
              widget.onChanged(_join());
            },
          ),
        ],
      ]),
    ]);
  }
}

/// Bottom sheet with drums for one or more fields (measurements, settings).
Future<Map<String, num?>?> showWheelSheet(BuildContext context, {required String title, required List<Field> fields, required Map<String, num?> values, String action = 'Tamam', String? subtitle}) {
  final v = Map<String, num?>.from(values);
  return showModalBottomSheet<Map<String, num?>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Glass(
      radius: 28,
      opacity: 0.86,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 38, height: 5, decoration: BoxDecoration(color: C.line2, borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 16),
            Text(title, style: T.title3),
            if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle, style: T.callout, textAlign: TextAlign.center)],
            const SizedBox(height: 18),
            Wrap(spacing: 18, runSpacing: 14, alignment: WrapAlignment.center, children: [
              for (final f in fields) ValueWheel(field: f, value: v[f.key], onChanged: (x) => v[f.key] = x),
            ]),
            const SizedBox(height: 22),
            PrimaryButton(label: action, onTap: () => Navigator.pop(ctx, v)),
          ]),
        ),
      ),
    ),
  );
}
