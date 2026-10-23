import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'neural_lens_button.dart';

/// Intentional empty state with an optional primary action.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.secondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xxl,
        vertical: Space.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HaloIcon(icon: icon),
          const SizedBox(height: Space.xl),
          Text(
            title,
            style: context.text.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              message,
              style: context.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: Space.xl),
            NeuralLensButton(
              label: actionLabel!,
              icon: actionIcon,
              onPressed: onAction,
            ),
          ],
          if (secondary != null) ...[
            const SizedBox(height: Space.sm),
            secondary!,
          ],
        ],
      ),
    ),
  );
}

/// Icon inside concentric hairline rings with a soft accent bloom.
class _HaloIcon extends StatelessWidget {
  const _HaloIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    Widget ring(double size, double alpha) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.textPrimary.withValues(alpha: alpha)),
      ),
    );
    return SizedBox.square(
      dimension: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  c.accent.withValues(alpha: 0.16),
                  c.accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          ring(132, 0.04),
          ring(100, 0.07),
          Container(
            width: 68,
            height: 68,
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.surfaceHigh, c.surfaceRaised],
              ),
              shape: Shapes.of(22, side: BorderSide(color: c.borderStrong)),
            ),
            child: Icon(icon, color: c.accentText, size: 30),
          ),
        ],
      ),
    );
  }
}

class LoadingStateView extends StatelessWidget {
  const LoadingStateView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            strokeCap: StrokeCap.round,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: Space.lg),
          Text(message!, style: context.text.bodyMedium),
        ],
      ],
    ),
  );
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.compact = false,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  /// Renders as an inline card instead of a centered page state.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: c.danger, size: 20),
            const SizedBox(width: Space.sm),
            Flexible(child: Text(title, style: context.text.titleSmall)),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(
          message,
          style: context.text.bodyMedium,
          textAlign: compact ? TextAlign.start : TextAlign.center,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: Space.lg),
          NeuralLensButton.secondary(
            label: retryLabel,
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
            compact: true,
          ),
        ],
      ],
    );
    if (!compact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xxl),
          child: content,
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.lg),
      decoration: ShapeDecoration(
        color: c.danger.withValues(alpha: 0.08),
        shape: Shapes.of(
          Radii.md,
          side: BorderSide(color: c.danger.withValues(alpha: 0.3)),
        ),
      ),
      child: content,
    );
  }
}
