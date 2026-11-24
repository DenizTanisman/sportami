import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Design tokens. Dark, near-black surfaces with one warm accent, in the
/// spirit of Apple's dark system palette.
class C {
  static const bg = Color(0xFF09090B);
  static const surface = Color(0xFF141417);
  static const surface2 = Color(0xFF1C1C21);
  static const surface3 = Color(0xFF26262C);
  static const line = Color(0x14FFFFFF);
  static const line2 = Color(0x24FFFFFF);
  static const text = Color(0xFFF5F5F7);
  static const text2 = Color(0xFFA1A1A6);
  static const text3 = Color(0xFF6E6E73);
  static const accent = Color(0xFFFF6A2B);
  static const accent2 = Color(0xFFFF9F0A);
  static const green = Color(0xFF30D158);
  static const blue = Color(0xFF0A84FF);
  static const red = Color(0xFFFF453A);
  static const yellow = Color(0xFFFFD60A);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7A2F), Color(0xFFFF4D2E)],
  );
}

/// Inter is a variable font; weight goes through the `wght` axis.
TextStyle t(double size, {double w = 400, Color color = C.text, double? h, double ls = 0, bool tabular = false}) {
  return TextStyle(
    fontFamily: 'Inter',
    fontSize: size,
    fontWeight: _weight(w),
    fontVariations: [FontVariation('wght', w), FontVariation('opsz', size.clamp(14, 32).toDouble())],
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    color: color,
    height: h,
    letterSpacing: ls,
  );
}

FontWeight _weight(double w) {
  const ws = [FontWeight.w100, FontWeight.w200, FontWeight.w300, FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800, FontWeight.w900];
  return ws[((w / 100).round() - 1).clamp(0, 8)];
}

/// Upper case with Turkish dotted İ (Dart's toUpperCase maps i to I).
String trUpper(String s) => s.replaceAll('i', 'İ').toUpperCase();

class T {
  static TextStyle get largeTitle => t(34, w: 760, ls: -0.8, h: 1.08);
  static TextStyle get title1 => t(28, w: 720, ls: -0.6, h: 1.1);
  static TextStyle get title2 => t(22, w: 680, ls: -0.4, h: 1.15);
  static TextStyle get title3 => t(19, w: 640, ls: -0.3, h: 1.2);
  static TextStyle get headline => t(16, w: 620, ls: -0.2, h: 1.25);
  static TextStyle get body => t(15, w: 420, color: C.text, h: 1.42, ls: -0.1);
  static TextStyle get callout => t(14, w: 440, color: C.text2, h: 1.4);
  static TextStyle get caption => t(12, w: 520, color: C.text3, h: 1.3);
  static TextStyle get overline => t(11.5, w: 640, color: C.text3, ls: 1.1);
  static TextStyle num(double size, {double w = 680, Color color = C.text}) => t(size, w: w, color: color, ls: -0.5, tabular: true);
}

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: 'Inter');
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    colorScheme: const ColorScheme.dark(primary: C.accent, secondary: C.accent2, surface: C.surface, error: C.red),
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    }),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: C.accent),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.surface3,
      contentTextStyle: t(14, w: 500),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// A rounded surface with a hairline border and a faint top highlight.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.radius = 22, this.color = C.surface, this.onTap, this.border});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final VoidCallback? onTap;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? C.line),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.025)!, color],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: box),
    );
  }
}

/// Frosted glass background for bars and sheets.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 0, this.opacity = 0.72});
  final Widget child;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(color: C.bg.withValues(alpha: opacity), child: child),
      ),
    );
  }
}

/// Primary action: accent gradient pill.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onTap, this.icon, this.expand = true});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: C.accentGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: C.accent.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 54,
              width: expand ? double.infinity : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 20, color: Colors.white), const SizedBox(width: 8)],
                    Text(label, style: t(16, w: 650, color: Colors.white, ls: -0.2)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action: quiet filled pill.
class QuietButton extends StatelessWidget {
  const QuietButton({super.key, required this.label, required this.onTap, this.icon, this.color = C.text});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.surface3,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 17, color: color), const SizedBox(width: 6)],
            Text(label, style: t(14, w: 600, color: color)),
          ]),
        ),
      ),
    );
  }
}

/// Small rounded label.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color = C.text2, this.fill});
  final String label;
  final Color color;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: fill ?? color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: t(12, w: 600, color: color, ls: -0.1)),
    );
  }
}

/// Section heading in small caps, Apple settings style.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 4, 10),
      child: Row(children: [
        Expanded(child: Text(trUpper(text), style: T.overline)),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
