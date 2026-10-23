import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/util/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../models/script.dart';
import '../../models/script_enums.dart';
import '../../util/cue_segmenter.dart';
import '../../util/duration_estimator.dart';

/// Kind / AI badge for a script.
class ScriptStatusChip extends StatelessWidget {
  const ScriptStatusChip({super.key, required this.script});

  final Script script;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    if (script.kind == ScriptKind.note) {
      return Pill(label: 'Note', color: c.warning, filled: true);
    }
    if (script.isAiGenerated) {
      return Pill(
        label: 'AI',
        icon: Icons.auto_awesome_rounded,
        color: c.accent2,
        filled: true,
      );
    }
    return Pill(label: script.format.label, color: c.textSecondary);
  }
}

/// Leading tile describing what a script is at a glance.
class ScriptGlyph extends StatelessWidget {
  const ScriptGlyph({super.key, required this.script, this.size = 44});

  final Script script;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final (icon, color) = script.kind == ScriptKind.note
        ? (Icons.sticky_note_2_outlined, c.warning)
        : script.isAiGenerated
        ? (Icons.auto_awesome_rounded, c.accent2)
        : (script.format.icon, c.accentText);
    return IconTile(icon: icon, color: color, size: size);
  }
}

enum ScriptAction { present, duplicate, favorite, delete }

class ScriptCard extends StatelessWidget {
  const ScriptCard({
    super.key,
    required this.script,
    required this.onTap,
    required this.onAction,
  });

  final Script script;
  final VoidCallback onTap;
  final ValueChanged<ScriptAction> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final preview = script.preview;
    final seconds = DurationEstimator.estimateSeconds(script.spokenText);
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.lg,
        Space.xs,
        Space.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScriptGlyph(script: script),
          const SizedBox(width: Space.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 1),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        script.displayTitle,
                        style: context.text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (script.isFavorite) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.star_rounded, size: 16, color: c.accentText),
                    ],
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(
                  preview.isEmpty ? 'No content yet' : preview,
                  style: context.text.bodyMedium!.copyWith(
                    color: preview.isEmpty ? c.textMuted : c.textSecondary,
                    height: 1.45,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Space.md),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ScriptStatusChip(script: script),
                    for (final tag in script.tags.take(2)) Pill(label: '#$tag'),
                    Text(
                      [
                        if (seconds > 0)
                          DurationEstimator.formatApprox(seconds),
                        relativeTime(script.updatedAt),
                      ].join(' · '),
                      style: context.mono(size: 11.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<ScriptAction>(
            tooltip: 'Script actions',
            icon: Icon(Icons.more_horiz_rounded, color: c.textMuted),
            onSelected: onAction,
            itemBuilder: (_) => [
              if (script.kind == ScriptKind.script)
                const PopupMenuItem(
                  value: ScriptAction.present,
                  child: _MenuRow(Icons.play_arrow_rounded, 'Present'),
                ),
              PopupMenuItem(
                value: ScriptAction.favorite,
                child: _MenuRow(
                  script.isFavorite
                      ? Icons.star_outline_rounded
                      : Icons.star_rounded,
                  script.isFavorite ? 'Remove favorite' : 'Add to favorites',
                ),
              ),
              const PopupMenuItem(
                value: ScriptAction.duplicate,
                child: _MenuRow(Icons.copy_rounded, 'Duplicate'),
              ),
              PopupMenuItem(
                value: ScriptAction.delete,
                child: _MenuRow(
                  Icons.delete_outline_rounded,
                  'Delete',
                  color: c.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: color ?? context.nl.textSecondary),
      const SizedBox(width: Space.md),
      Text(label, style: TextStyle(color: color)),
    ],
  );
}
