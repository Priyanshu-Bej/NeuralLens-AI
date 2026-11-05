import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'neural_lens_button.dart';
import 'pressable.dart';

/// App mark: bold display glasses with a glowing heads-up panel in the right
/// lens, on a dark rounded tile. Matches the launcher icon
/// (`res/drawable/ic_launcher_foreground.xml`), which uses the same geometry.
class NeuralLensLogo extends StatelessWidget {
  const NeuralLensLogo({super.key, this.size = 28, this.rounded = true});

  final double size;

  /// Square corners for exported app icons, which the OS masks itself.
  final bool rounded;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _LogoPainter(rounded: rounded)),
  );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.rounded});

  final bool rounded;

  // Geometry is in the launcher icon's 108-unit space; the tile shows the
  // [_viewStart, _viewStart + _viewSize] window of it.
  static const _viewStart = 14.0;
  static const _viewSize = 80.0;

  /// Wayfarer-style lens: straight brow, tapering sides, flat rounded base.
  static Path lens(double x0, double x1) {
    const y0 = 45.0, y1 = 63.0, r = 3.0;
    return Path()
      ..moveTo(x0 + r, y0)
      ..lineTo(x1 - r, y0)
      ..quadraticBezierTo(x1, y0, x1, y0 + r)
      ..cubicTo(x1 - 0.5, y0 + 8, x1 - 3, y1, x1 - 9, y1)
      ..lineTo(x0 + 9, y1)
      ..cubicTo(x0 + 3, y1, x0 + 0.5, y0 + 8, x0, y0 + r)
      ..quadraticBezierTo(x0, y0, x0 + r, y0)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    // Dark tile with a soft top light, like the launcher icon.
    final tile = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(rounded ? s * 0.28 : 0),
    );
    canvas.drawRRect(
      tile,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s), const [
          Palette.graphite800,
          Palette.ink,
        ]),
    );

    canvas
      ..save()
      ..scale(s / _viewSize)
      ..translate(-_viewStart, -_viewStart);

    final brand = ui.Gradient.linear(
      const Offset(24, 45),
      const Offset(84, 63),
      [Palette.lime, Palette.aqua],
    );
    final left = lens(24, 51);
    final right = lens(57, 84);

    // Lens tint, then the in-lens display with its glow, kept inside the
    // right lens.
    final tint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    canvas
      ..drawPath(left, tint)
      ..drawPath(right, tint)
      ..save()
      ..clipPath(right)
      ..drawRRect(
        RRect.fromLTRBR(63.5, 47.6, 78.5, 56.4, const Radius.circular(2.6)),
        Paint()..color = Palette.aqua.withValues(alpha: 0.25),
      )
      ..drawRRect(
        RRect.fromLTRBR(65, 49, 77, 55, const Radius.circular(1.6)),
        Paint()..shader = brand,
      )
      ..restore();

    final frame = Paint()
      ..shader = brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final bridge = Path()
      ..moveTo(51, 48)
      ..quadraticBezierTo(54, 45.5, 57, 48);
    canvas
      ..drawPath(left, frame)
      ..drawPath(right, frame)
      ..drawPath(bridge, frame)
      ..restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.rounded != rounded;
}

class NeuralLensWordmark extends StatelessWidget {
  const NeuralLensWordmark({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const NeuralLensLogo(size: 30),
      const SizedBox(width: Space.sm + 2),
      Text(
        'NeuralLens',
        style: context.text.titleMedium!.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
    ],
  );
}

/// Monospaced uppercase eyebrow with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.padding = const EdgeInsets.only(top: Space.xxl, bottom: Space.md),
  });

  final String title;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: SizedBox(
      height: 28,
      child: Row(
        children: [
          Expanded(
            child: Text(title.toUpperCase(), style: context.text.labelSmall),
          ),
          ?action,
        ],
      ),
    ),
  );
}

/// Small text action used beside a [SectionHeader].
class HeaderAction extends StatelessWidget {
  const HeaderAction({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      minimumSize: const Size(0, 28),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: context.text.labelMedium!.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 2),
        const Icon(Icons.arrow_forward_rounded, size: 14),
      ],
    ),
  );
}

/// Tonal surface with continuous corners, a hairline edge and a soft top
/// light. Scales slightly when pressed if tappable.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(Space.lg),
    this.highlighted = false,
    this.radius = Radii.md,
    this.color,
    this.gradient,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;

  /// Accent edge and glow for the most important card on a screen.
  final bool highlighted;
  final double radius;
  final Color? color;

  /// Replaces the default fill.
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final dark = context.isDark;
    final shape = Shapes.of(
      radius,
      side: BorderSide(
        color: highlighted ? c.accentText.withValues(alpha: 0.4) : c.border,
      ),
    );
    final fill =
        gradient ??
        (color == null && dark
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c.surfaceRaised, c.surface],
              )
            : null);
    final tappable = onTap != null || onLongPress != null;

    Widget card = Material(
      type: MaterialType.transparency,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: ShapeDecoration(
          shape: shape,
          color: fill == null ? (color ?? c.surface) : null,
          gradient: fill,
          shadows: [
            if (highlighted)
              BoxShadow(
                color: c.accent.withValues(alpha: dark ? 0.12 : 0.22),
                blurRadius: 32,
                spreadRadius: -6,
                offset: const Offset(0, 10),
              )
            else if (!dark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (tappable) card = Pressable(child: card);
    return card;
  }
}

/// Frosted, translucent floating surface. Use sparingly: navigation and
/// overlay chrome only.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = Radii.lg,
    this.padding = EdgeInsets.zero,
    this.blur = 24,
    this.color,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final Color? color;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final shape = Shapes.of(radius);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: context.isDark ? 0.45 : 0.12,
                  ),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: color ?? c.glass,
              shape: Shapes.of(radius, side: BorderSide(color: c.borderStrong)),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Soft lime / aqua / violet light blooms painted behind content.
///
/// Static by default; [animate] slowly drifts the blooms (skipped when the
/// platform asks for reduced motion).
class AuroraGlow extends StatefulWidget {
  const AuroraGlow({super.key, this.animate = false, this.intensity = 1});

  final bool animate;
  final double intensity;

  @override
  State<AuroraGlow> createState() => _AuroraGlowState();
}

class _AuroraGlowState extends State<AuroraGlow>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (run && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!run && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final strength = (context.isDark ? 1.0 : 0.7) * widget.intensity;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _AuroraPainter(
            progress: _controller,
            colors: [c.accent, c.accent2, c.accent3],
            strength: strength,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.progress,
    required this.colors,
    required this.strength,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final List<Color> colors;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value * 2 * math.pi;
    final w = size.width;
    final h = size.height;
    void bloom(Color color, Offset center, double radius, double alpha) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha * strength),
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    bloom(
      colors[0],
      Offset(w * (0.18 + 0.06 * math.sin(t)), h * (0.2 + 0.05 * math.cos(t))),
      w * 0.7,
      0.22,
    );
    bloom(
      colors[1],
      Offset(w * (0.86 + 0.05 * math.cos(t)), h * (0.1 + 0.06 * math.sin(t))),
      w * 0.6,
      0.16,
    );
    bloom(
      colors[2],
      Offset(w * (0.62 + 0.06 * math.sin(t + 1)), h * 0.72),
      w * 0.55,
      0.12,
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.colors != colors || old.strength != strength;
}

/// Tinted rounded square holding an icon.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.color,
    this.size = 40,
    this.filled = false,
  });

  final IconData icon;
  final Color? color;
  final double size;

  /// Solid accent background instead of a tint.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final fg = color ?? c.accentText;
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: filled ? fg : fg.withValues(alpha: 0.12),
        shape: Shapes.of(
          size * 0.32,
          side: BorderSide(color: fg.withValues(alpha: filled ? 0 : 0.16)),
        ),
      ),
      child: Icon(icon, size: size * 0.5, color: filled ? c.onAccent : fg),
    );
  }
}

/// Status dot with an optional breathing halo for live / in-progress states.
class StatusDot extends StatefulWidget {
  const StatusDot({
    super.key,
    required this.color,
    this.pulse = false,
    this.size = 8,
  });

  final Color color;
  final bool pulse;
  final double size;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(StatusDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.pulse && !MediaQuery.disableAnimationsOf(context);
    if (run && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!run && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox.square(
      dimension: s * 2.5,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.pulse)
                Container(
                  width: s + s * 1.5 * t,
                  height: s + s * 1.5 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.45 * (1 - t)),
                  ),
                ),
              Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.6),
                      blurRadius: s,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Compact pill used for status and metadata.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final fg = color ?? c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? fg.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(
          color: filled ? fg.withValues(alpha: 0.14) : c.borderStrong,
        ),
      ),
      // Text.rich (not a Row) so long labels ellipsize when space is tight.
      child: Text.rich(
        TextSpan(
          children: [
            if (icon != null) ...[
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(icon, size: 13, color: fg),
              ),
              const WidgetSpan(child: SizedBox(width: 5)),
            ],
            TextSpan(text: label),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.labelMedium!.copyWith(
          color: fg,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class SegmentOption<T> {
  const SegmentOption(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Segmented control with a sliding thumb.
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final dark = context.isDark;
    final index = options.indexWhere((o) => o.value == selected);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: dark ? c.background : c.surfaceHigh,
        shape: Shapes.of(Radii.md, side: BorderSide(color: c.border)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / options.length;
          return Stack(
            children: [
              if (index >= 0)
                AnimatedPositioned(
                  duration: Motion.medium,
                  curve: Motion.emphasized,
                  left: w * index,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: dark ? Palette.graphite700 : Colors.white,
                      shape: Shapes.of(
                        Radii.md - 4,
                        side: BorderSide(color: c.borderStrong),
                      ),
                      shadows: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: dark ? 0.35 : 0.08,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  for (final o in options)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: o.value == selected,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(o.value),
                          child: _SegmentLabel(
                            option: o,
                            active: o.value == selected,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({required this.option, required this.active});

  final SegmentOption<Object?> option;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final color = active ? c.textPrimary : c.textMuted;
    return Center(
      child: AnimatedDefaultTextStyle(
        duration: Motion.fast,
        style: context.text.labelLarge!.copyWith(color: color),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.icon != null) ...[
              Icon(
                option.icon,
                size: 17,
                color: active ? c.accentText : c.textMuted,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selectable chip with an animated accent state.
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final fg = selected ? c.textPrimary : c.textSecondary;
    return Pressable(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.emphasized,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? c.accentSoft : c.surfaceRaised,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(
                color: selected
                    ? c.accentText.withValues(alpha: 0.55)
                    : c.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? c.accentText : c.textMuted,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: context.text.labelLarge!.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round, hairline-bordered icon button for toolbars.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.size = 40,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Pressable(
      scale: 0.92,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: c.surfaceRaised,
          shape: CircleBorder(side: BorderSide(color: c.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(
                icon,
                size: size * 0.5,
                color: color ?? c.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: IconTile(
        icon: destructive
            ? Icons.delete_outline_rounded
            : Icons.help_outline_rounded,
        color: destructive ? ctx.nl.danger : ctx.nl.accentText,
        size: 48,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsPadding: const EdgeInsets.fromLTRB(
        Space.xl,
        0,
        Space.xl,
        Space.xl,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: NeuralLensButton.secondary(
                label: 'Cancel',
                compact: true,
                expand: true,
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: NeuralLensButton(
                label: confirmLabel,
                compact: true,
                expand: true,
                variant: destructive
                    ? NeuralLensButtonVariant.danger
                    : NeuralLensButtonVariant.primary,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Single-field text prompt. Returns the entered text, or null if cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String confirmLabel = 'Save',
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPromptDialog(
    title: title,
    initial: initial,
    hint: hint,
    confirmLabel: confirmLabel,
  ),
);

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.confirmLabel,
  });

  final String title;
  final String initial;
  final String? hint;
  final String confirmLabel;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(hintText: widget.hint),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actionsPadding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
    actions: [
      Row(
        children: [
          Expanded(
            child: NeuralLensButton.secondary(
              label: 'Cancel',
              compact: true,
              expand: true,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: NeuralLensButton(
              label: widget.confirmLabel,
              compact: true,
              expand: true,
              onPressed: () => Navigator.pop(context, _controller.text),
            ),
          ),
        ],
      ),
    ],
  );
}
