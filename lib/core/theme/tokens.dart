import 'package:flutter/material.dart';

/// Spacing scale (4pt base).
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter.
  static const double gutter = 20;
}

/// Corner radii. Surfaces use continuous (superellipse) corners via
/// [Shapes] so large radii stay soft instead of looking pill-like.
abstract final class Radii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 20;
  static const double lg = 28;
  static const double xl = 36;
  static const double pill = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
}

abstract final class Shapes {
  static RoundedSuperellipseBorder of(
    double radius, {
    BorderSide side = BorderSide.none,
  }) => RoundedSuperellipseBorder(
    borderRadius: BorderRadius.circular(radius),
    side: side,
  );
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 460);
  static const Curve curve = Curves.easeOutCubic;

  /// Emphasized deceleration for things entering the screen.
  static const Curve emphasized = Curves.easeOutQuart;

  /// Slight overshoot for press release and selection changes.
  static const Curve spring = Curves.easeOutBack;
}

/// Font families bundled in `assets/fonts` (Geist, SIL OFL 1.1).
abstract final class Fonts {
  static const sans = 'Geist';
  static const mono = 'GeistMono';
}

/// Raw palette. Widgets should read colors through [NeuralLensColors].
abstract final class Palette {
  static const lime = Color(0xFFC8F542);
  static const limeDeep = Color(0xFF4A6400);
  static const aqua = Color(0xFF5BE4D8);
  static const aquaDeep = Color(0xFF00796E);
  static const violet = Color(0xFF8E7BFF);
  static const ink = Color(0xFF060708);
  static const graphite950 = Color(0xFF0B0C0E);
  static const graphite900 = Color(0xFF111316);
  static const graphite800 = Color(0xFF181B1F);
  static const graphite700 = Color(0xFF20242A);
  static const fog100 = Color(0xFFF3F5F1);
  static const fog300 = Color(0xFFA6ADB5);
  static const fog500 = Color(0xFF6C747D);
  static const coral = Color(0xFFFF6B5E);
  static const amber = Color(0xFFFFB648);
}

/// Semantic color tokens, available via `context.nl`.
@immutable
class NeuralLensColors extends ThemeExtension<NeuralLensColors> {
  const NeuralLensColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceHigh,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.accentSoft,
    required this.accent2,
    required this.accent3,
    required this.glass,
    required this.danger,
    required this.warning,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;

  /// Highest tonal step, for controls sitting on [surfaceRaised].
  final Color surfaceHigh;

  /// Hairline separating surfaces from each other.
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Fill color for primary actions.
  final Color accent;
  final Color onAccent;

  /// Accent used for text/icons on [surface] with sufficient contrast.
  final Color accentText;
  final Color accentSoft;

  /// Secondary and tertiary accents for gradients and glows (AI, optics).
  final Color accent2;
  final Color accent3;

  /// Translucent fill for blurred floating chrome.
  final Color glass;
  final Color danger;
  final Color warning;

  /// Signature lime → aqua sweep.
  LinearGradient get brandGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accent2],
  );

  static const dark = NeuralLensColors(
    background: Palette.ink,
    surface: Palette.graphite950,
    surfaceRaised: Palette.graphite900,
    surfaceHigh: Palette.graphite800,
    border: Color(0x14FFFFFF),
    borderStrong: Color(0x24FFFFFF),
    textPrimary: Palette.fog100,
    textSecondary: Palette.fog300,
    textMuted: Palette.fog500,
    accent: Palette.lime,
    onAccent: Palette.ink,
    accentText: Palette.lime,
    accentSoft: Color(0x1FC8F542),
    accent2: Palette.aqua,
    accent3: Palette.violet,
    glass: Color(0xB8121418),
    danger: Palette.coral,
    warning: Palette.amber,
  );

  static const light = NeuralLensColors(
    background: Color(0xFFF4F5F1),
    surface: Colors.white,
    surfaceRaised: Color(0xFFF9FAF7),
    surfaceHigh: Color(0xFFECEEE8),
    border: Color(0x14000000),
    borderStrong: Color(0x24000000),
    textPrimary: Color(0xFF0E1013),
    textSecondary: Color(0xFF4A5058),
    textMuted: Color(0xFF737B84),
    accent: Palette.lime,
    onAccent: Palette.ink,
    accentText: Palette.limeDeep,
    accentSoft: Color(0x29A4CC1F),
    accent2: Palette.aquaDeep,
    accent3: Color(0xFF5B48E8),
    glass: Color(0xC7FFFFFF),
    danger: Color(0xFFD23B2E),
    warning: Color(0xFFB86E00),
  );

  @override
  NeuralLensColors copyWith() => this;

  @override
  NeuralLensColors lerp(NeuralLensColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return NeuralLensColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentText: l(accentText, other.accentText),
      accentSoft: l(accentSoft, other.accentSoft),
      accent2: l(accent2, other.accent2),
      accent3: l(accent3, other.accent3),
      glass: l(glass, other.glass),
      danger: l(danger, other.danger),
      warning: l(warning, other.warning),
    );
  }
}

extension NeuralLensThemeX on BuildContext {
  NeuralLensColors get nl => Theme.of(this).extension<NeuralLensColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Monospaced style for numbers, counters and technical labels.
  TextStyle mono({double size = 12, Color? color, FontWeight? weight}) =>
      TextStyle(
        fontFamily: Fonts.mono,
        fontSize: size,
        fontWeight: weight ?? FontWeight.w500,
        letterSpacing: 0,
        height: 1.3,
        color: color ?? nl.textMuted,
        // Geist Mono's coding ligatures would merge text like " --".
        fontFeatures: const [
          FontFeature.disable('liga'),
          FontFeature.disable('calt'),
        ],
      );
}
