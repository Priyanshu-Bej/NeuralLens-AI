import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'pressable.dart';

enum NeuralLensButtonVariant { primary, ai, secondary, ghost, danger }

/// The app's single button primitive. Keeps sizing, shape and loading
/// behavior consistent everywhere.
class NeuralLensButton extends StatelessWidget {
  const NeuralLensButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = NeuralLensButtonVariant.primary,
    this.loading = false,
    this.expand = false,
    this.compact = false,
  });

  const NeuralLensButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.compact = false,
  }) : variant = NeuralLensButtonVariant.secondary;

  const NeuralLensButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.compact = false,
  }) : variant = NeuralLensButtonVariant.ghost;

  /// Brand-gradient button for AI actions.
  const NeuralLensButton.ai({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.auto_awesome_rounded,
    this.loading = false,
    this.expand = false,
    this.compact = false,
  }) : variant = NeuralLensButtonVariant.ai;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final NeuralLensButtonVariant variant;
  final bool loading;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final enabled = onPressed != null && !loading;
    final accentFill =
        variant == NeuralLensButtonVariant.primary ||
        variant == NeuralLensButtonVariant.ai;
    // A faded accent reads as muddy; disabled filled buttons go neutral.
    final dormant = accentFill && onPressed == null && !loading;
    final filled = accentFill && !dormant;
    final (bg, fg, border) = switch (variant) {
      _ when dormant => (c.surfaceHigh, c.textMuted, c.border),
      NeuralLensButtonVariant.primary ||
      NeuralLensButtonVariant.ai => (c.accent, c.onAccent, Colors.transparent),
      NeuralLensButtonVariant.secondary => (
        c.surfaceHigh,
        c.textPrimary,
        c.borderStrong,
      ),
      NeuralLensButtonVariant.ghost => (
        Colors.transparent,
        c.textSecondary,
        Colors.transparent,
      ),
      NeuralLensButtonVariant.danger => (
        c.danger.withValues(alpha: 0.14),
        c.danger,
        c.danger.withValues(alpha: 0.3),
      ),
    };
    final height = compact ? 42.0 : 54.0;

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fg,
              backgroundColor: Colors.transparent,
            ),
          )
        else if (icon != null)
          Icon(icon, size: compact ? 18 : 20, color: fg),
        if (loading || icon != null) const SizedBox(width: Space.sm),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelLarge!.copyWith(
              color: fg,
              fontSize: compact ? 14 : 15.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final decoration = BoxDecoration(
      color: filled && variant == NeuralLensButtonVariant.ai ? null : bg,
      gradient: filled && variant == NeuralLensButtonVariant.ai
          ? c.brandGradient
          : filled
          // Subtle top light so the fill reads as a raised, tactile surface.
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(bg, Colors.white, 0.18)!, bg],
            )
          : null,
      borderRadius: BorderRadius.circular(Radii.pill),
      border: Border.all(color: border),
      boxShadow: filled && enabled
          ? [
              BoxShadow(
                color: c.accent.withValues(alpha: context.isDark ? 0.22 : 0.4),
                blurRadius: 20,
                spreadRadius: -6,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: enabled || loading || dormant ? 1 : 0.4,
        child: Pressable(
          enabled: enabled,
          child: SizedBox(
            height: height,
            width: expand ? double.infinity : null,
            child: DecoratedBox(
              decoration: decoration,
              child: Material(
                type: MaterialType.transparency,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled
                      ? () {
                          HapticFeedback.selectionClick();
                          onPressed!();
                        }
                      : null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? Space.lg : Space.xl,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
