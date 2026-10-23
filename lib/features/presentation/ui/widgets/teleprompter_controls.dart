import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/pressable.dart';
import '../../logic/presentation_cubit.dart';

/// Transport controls: sections, cues and play/pause (restart when
/// finished).
class TeleprompterControls extends StatelessWidget {
  const TeleprompterControls({
    super.key,
    required this.state,
    required this.onTogglePlay,
    required this.onPreviousCue,
    required this.onNextCue,
    required this.onPreviousSection,
    required this.onNextSection,
    required this.onRestart,
  });

  final PresentationState state;
  final VoidCallback onTogglePlay;
  final VoidCallback onPreviousCue;
  final VoidCallback onNextCue;
  final VoidCallback onPreviousSection;
  final VoidCallback onNextSection;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final finished = state.status == PlaybackStatus.finished;
    final (icon, label) = switch (state.status) {
      PlaybackStatus.playing => (Icons.pause_rounded, 'Pause'),
      PlaybackStatus.finished => (Icons.replay_rounded, 'Restart'),
      PlaybackStatus.paused => (Icons.play_arrow_rounded, 'Resume'),
      PlaybackStatus.ready => (Icons.play_arrow_rounded, 'Start'),
    };
    return GlassPanel(
      radius: Radii.pill,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundIcon(
            icon: Icons.skip_previous_rounded,
            tooltip: 'Previous section',
            onPressed: onPreviousSection,
          ),
          _RoundIcon(
            icon: Icons.keyboard_arrow_up_rounded,
            tooltip: 'Previous card',
            onPressed: onPreviousCue,
          ),
          Semantics(
            button: true,
            label: label,
            child: Tooltip(
              message: label,
              child: Pressable(
                scale: 0.9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: c.brandGradient,
                    boxShadow: [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: finished ? onRestart : onTogglePlay,
                      child: SizedBox.square(
                        dimension: 64,
                        child: AnimatedSwitcher(
                          duration: Motion.fast,
                          transitionBuilder: (child, a) =>
                              ScaleTransition(scale: a, child: child),
                          child: Icon(
                            icon,
                            key: ValueKey(icon),
                            color: c.onAccent,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _RoundIcon(
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: 'Next card',
            onPressed: onNextCue,
          ),
          _RoundIcon(
            icon: Icons.skip_next_rounded,
            tooltip: 'Next section',
            onPressed: onNextSection,
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    iconSize: 26,
    color: context.nl.textPrimary,
    icon: Icon(icon),
  );
}
