import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/pressable.dart';
import '../../logic/presentation_cubit.dart';
import '../../models/presentation_settings.dart';

/// Autoplay speed presets shown beside the − / + steps.
const speedPresets = [
  SegmentOption(3, 'Slow'),
  SegmentOption(5, 'Normal'),
  SegmentOption(7, 'Fast'),
];

/// Autoplay speed (presets and fine − / + steps) above the transport:
/// sections, cards and play/pause (restart when finished).
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
    required this.onSlower,
    required this.onFaster,
    required this.onSpeed,
  });

  final PresentationState state;
  final VoidCallback onTogglePlay;
  final VoidCallback onPreviousCue;
  final VoidCallback onNextCue;
  final VoidCallback onPreviousSection;
  final VoidCallback onNextSection;
  final VoidCallback onRestart;
  final VoidCallback onSlower;
  final VoidCallback onFaster;
  final ValueChanged<int> onSpeed;

  @override
  Widget build(BuildContext context) {
    final finished = state.status == PlaybackStatus.finished;
    final (icon, label) = switch (state.status) {
      PlaybackStatus.playing => (Icons.pause_rounded, 'Pause'),
      PlaybackStatus.finished => (Icons.replay_rounded, 'Restart'),
      PlaybackStatus.paused => (Icons.play_arrow_rounded, 'Resume'),
      PlaybackStatus.ready => (Icons.play_arrow_rounded, 'Start'),
    };
    final speed = state.settings.speed;
    return GlassPanel(
      radius: Radii.xl,
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.md,
        Space.md,
        Space.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleIconButton(
                icon: Icons.remove_rounded,
                tooltip: 'Slower',
                size: 42,
                onPressed: speed > PresentationSettings.minSpeed
                    ? onSlower
                    : null,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: SegmentedPill<int>(
                  options: speedPresets,
                  selected: speed,
                  onChanged: onSpeed,
                ),
              ),
              const SizedBox(width: Space.sm),
              CircleIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Faster',
                size: 42,
                onPressed: speed < PresentationSettings.maxSpeed
                    ? onFaster
                    : null,
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          _Transport(
            state: state,
            icon: icon,
            label: label,
            finished: finished,
            onTogglePlay: onTogglePlay,
            onPreviousCue: onPreviousCue,
            onNextCue: onNextCue,
            onPreviousSection: onPreviousSection,
            onNextSection: onNextSection,
            onRestart: onRestart,
          ),
        ],
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({
    required this.state,
    required this.icon,
    required this.label,
    required this.finished,
    required this.onTogglePlay,
    required this.onPreviousCue,
    required this.onNextCue,
    required this.onPreviousSection,
    required this.onNextSection,
    required this.onRestart,
  });

  final PresentationState state;
  final IconData icon;
  final String label;
  final bool finished;
  final VoidCallback onTogglePlay;
  final VoidCallback onPreviousCue;
  final VoidCallback onNextCue;
  final VoidCallback onPreviousSection;
  final VoidCallback onNextSection;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Row(
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
