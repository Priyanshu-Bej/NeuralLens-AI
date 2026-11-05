import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../logic/library_cubit.dart';
import '../models/script.dart';
import '../models/script_enums.dart';
import 'widgets/script_card.dart';

/// Shared handler for [ScriptCard] menus on Home and Library.
Future<void> handleScriptAction(
  BuildContext context,
  Script script,
  ScriptAction action,
) async {
  final library = context.read<LibraryCubit>();
  switch (action) {
    case ScriptAction.present:
      await context.push(Routes.present(script.id));
    case ScriptAction.favorite:
      await library.toggleFavorite(script);
    case ScriptAction.duplicate:
      final copy = await library.duplicate(script);
      if (copy != null && context.mounted) {
        showSnack(context, 'Created "${copy.displayTitle}"');
      }
    case ScriptAction.delete:
      final confirmed = await confirmDialog(
        context,
        title: 'Delete "${script.displayTitle}"?',
        message: 'This permanently removes it from this device.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (!confirmed) return;
      await library.delete(script);
      if (context.mounted) showSnack(context, 'Deleted');
  }
}

/// Bottom sheet offering AI generation, a blank script or a note.
Future<void> showCreateSheet(BuildContext context) async {
  final route = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create', style: ctx.text.headlineSmall),
            const SizedBox(height: Space.xs),
            Text(
              'Start from rough notes or a blank page.',
              style: ctx.text.bodyMedium,
            ),
            const SizedBox(height: Space.xl),
            _CreateOption(
              icon: Icons.auto_awesome_rounded,
              title: 'Generate with AI',
              subtitle: 'Turn notes into a speakable script',
              featured: true,
              onTap: () => Navigator.pop(ctx, Routes.studio),
            ),
            const SizedBox(height: Space.sm),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _CreateOption(
                      icon: Icons.edit_note_rounded,
                      title: 'Script',
                      subtitle: 'Blank teleprompter script',
                      onTap: () => Navigator.pop(ctx, Routes.newScript()),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _CreateOption(
                      icon: Icons.sticky_note_2_outlined,
                      title: 'Note',
                      subtitle: 'Ideas and talking points',
                      color: ctx.nl.warning,
                      onTap: () =>
                          Navigator.pop(ctx, Routes.newScript(ScriptKind.note)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (route != null && context.mounted) await context.push(route);
}

class _CreateOption extends StatelessWidget {
  const _CreateOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.featured = false,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool featured;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final tile = IconTile(icon: icon, color: color, filled: featured, size: 44);
    final labels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: context.text.titleMedium),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: context.text.bodySmall!.copyWith(color: c.textSecondary),
        ),
      ],
    );
    return SurfaceCard(
      onTap: onTap,
      highlighted: featured,
      color: c.surfaceHigh,
      gradient: featured
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.accent.withValues(alpha: 0.16), c.surfaceHigh],
            )
          : null,
      padding: const EdgeInsets.all(Space.lg),
      child: featured
          ? Row(
              children: [
                tile,
                const SizedBox(width: Space.lg),
                Expanded(child: labels),
                Icon(Icons.arrow_forward_rounded, color: c.accentText),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tile,
                const SizedBox(height: Space.lg),
                labels,
              ],
            ),
    );
  }
}
