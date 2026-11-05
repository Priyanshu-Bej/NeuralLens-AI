import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/common.dart';

/// Hero entry point to the AI Script Studio, styled as a prompt composer.
class AiGenerationButton extends StatelessWidget {
  const AiGenerationButton({
    super.key,
    required this.onPressed,
    required this.configured,
  });

  final VoidCallback onPressed;
  final bool configured;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return SurfaceCard(
      onTap: onPressed,
      radius: Radii.lg,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          const Positioned.fill(child: AuroraGlow(intensity: 1.2)),
          Padding(
            padding: const EdgeInsets.all(Space.xl - 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _GradientIcon(),
                    const SizedBox(width: Space.sm + 2),
                    Expanded(
                      child: Text(
                        'AI SCRIPT STUDIO',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall!.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    if (!configured)
                      Pill(
                        label: 'Setup required',
                        icon: Icons.key_rounded,
                        color: c.warning,
                        filled: true,
                      ),
                  ],
                ),
                const SizedBox(height: Space.xl),
                Text('Create with AI', style: context.text.headlineMedium),
                const SizedBox(height: Space.xs),
                Text(
                  'Turn rough notes into a script you can say out loud.',
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: Space.lg + 2),
                _PromptBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientIcon extends StatelessWidget {
  const _GradientIcon();

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Container(
      width: 32,
      height: 32,
      decoration: ShapeDecoration(
        gradient: c.brandGradient,
        shape: Shapes.of(10),
      ),
      child: Icon(Icons.auto_awesome_rounded, size: 17, color: c.onAccent),
    );
  }
}

/// Decorative input that hints at what to type; the whole card is the tap
/// target.
class _PromptBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: Space.lg, right: 6),
      decoration: BoxDecoration(
        color: c.background.withValues(alpha: context.isDark ? 0.55 : 0.7),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: c.borderStrong),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Pitch our app in 60 seconds…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium!.copyWith(color: c.textMuted),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: c.brandGradient,
            ),
            child: Icon(
              Icons.arrow_upward_rounded,
              size: 20,
              color: c.onAccent,
            ),
          ),
        ],
      ),
    );
  }
}
