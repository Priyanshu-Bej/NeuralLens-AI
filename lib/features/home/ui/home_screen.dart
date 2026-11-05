import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../ai/ui/widgets/ai_generation_button.dart';
import '../../scripts/logic/library_cubit.dart';
import '../../scripts/models/script.dart';
import '../../scripts/models/script_enums.dart';
import '../../scripts/ui/script_actions.dart';
import '../../scripts/ui/widgets/script_card.dart';
import '../../scripts/util/cue_segmenter.dart';
import '../../settings/logic/settings_cubit.dart';
import '../../wearables/ui/widgets/glass_connection_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _recentCount = 4;

  @override
  Widget build(BuildContext context) {
    final configured = context.read<AppConfig>().isGeminiConfigured;
    final library = context.watch<LibraryCubit>().state;
    final lastScriptId = context.select(
      (SettingsCubit c) => c.state.lastScriptId,
    );
    final scripts = library.scripts;
    final resume = scripts
        .where((s) => s.id == lastScriptId && s.lastPosition > 0)
        .firstOrNull;
    final favorites = scripts.where((s) => s.isFavorite).toList();

    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -160,
            left: -60,
            right: -60,
            height: 460,
            child: AuroraGlow(intensity: 0.7),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.md,
                    Space.gutter,
                    0,
                  ),
                  sliver: SliverList.list(
                    children: [
                      Row(
                        children: [
                          const NeuralLensWordmark(),
                          const Spacer(),
                          CircleIconButton(
                            icon: Icons.search_rounded,
                            tooltip: 'Search library',
                            onPressed: () => context.go(Routes.library),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.xxl),
                      Text(
                        DateFormat(
                          'EEEE · d MMM',
                        ).format(DateTime.now()).toUpperCase(),
                        style: context.text.labelSmall,
                      ),
                      const SizedBox(height: Space.sm),
                      Text(_greeting(), style: context.text.displayMedium),
                      const SizedBox(height: Space.sm),
                      Text(
                        'See beyond the screen.',
                        style: context.text.bodyLarge!.copyWith(
                          color: context.nl.textSecondary,
                        ),
                      ),
                      const SizedBox(height: Space.xl),
                      AiGenerationButton(
                        configured: configured,
                        onPressed: () => context.push(Routes.studio),
                      ),
                      const SizedBox(height: Space.md),
                      const _Bento(),
                      const SizedBox(height: Space.md),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.document_scanner_outlined),
                          title: const Text('Question Lens'),
                          subtitle: const Text(
                            'Capture a question. See the answer on your glasses.',
                          ),
                          trailing: const Icon(Icons.arrow_forward_rounded),
                          onTap: () => context.push(Routes.questions),
                        ),
                      ),
                      if (resume != null) ...[
                        const SectionHeader(title: 'Continue presenting'),
                        _ContinueCard(script: resume),
                      ],
                      if (favorites.isNotEmpty) ...[
                        const SectionHeader(title: 'Favorites'),
                        _FavoritesStrip(scripts: favorites),
                      ],
                      SectionHeader(
                        title: 'Recent',
                        action: scripts.length > _recentCount
                            ? HeaderAction(
                                label: 'See all',
                                onTap: () => context.go(Routes.library),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
                if (library.status == LoadStatus.ready && scripts.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyStateView(
                      icon: Icons.subject_rounded,
                      title: 'Your library is empty',
                      message:
                          'Write your first script or let AI draft one from a '
                          'few rough notes.',
                      actionLabel: 'Write a script',
                      actionIcon: Icons.edit_rounded,
                      onAction: () => context.push(Routes.newScript()),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.gutter,
                    ),
                    sliver: SliverList.separated(
                      itemCount: scripts.length.clamp(0, _recentCount),
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Space.md),
                      itemBuilder: (context, i) {
                        final script = scripts[i];
                        return ScriptCard(
                          script: script,
                          onTap: () => context.push(Routes.editor(script.id)),
                          onAction: (a) =>
                              handleScriptAction(context, script, a),
                        );
                      },
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: Space.xl + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Working late?';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

/// Glasses status beside quick "new" actions.
class _Bento extends StatelessWidget {
  const _Bento();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 200,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GlassesBentoTile(onTap: () => context.push(Routes.glasses)),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.edit_note_rounded,
                  label: 'New script',
                  onTap: () => context.push(Routes.newScript()),
                ),
              ),
              const SizedBox(height: Space.md),
              Expanded(
                child: _QuickTile(
                  icon: Icons.sticky_note_2_outlined,
                  label: 'New note',
                  color: context.nl.warning,
                  onTap: () => context.push(Routes.newScript(ScriptKind.note)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
    child: Row(
      children: [
        IconTile(icon: icon, color: color, size: 38),
        const SizedBox(width: Space.md),
        Expanded(
          child: Text(
            label,
            style: context.text.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.script});

  final Script script;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final total = CueSegmenter.cues(script.resolvedSections).length;
    final progress = total == 0
        ? 0.0
        : (script.lastPosition / total).clamp(0.0, 1.0);
    return SurfaceCard(
      highlighted: true,
      onTap: () => context.push(Routes.present(script.id)),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3.5,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Icon(Icons.play_arrow_rounded, color: c.accentText, size: 26),
              ],
            ),
          ),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  script.displayTitle,
                  style: context.text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'CARD ${script.lastPosition + 1} / $total · '
                  '${(progress * 100).round()}%',
                  style: context.mono(size: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accentSoft,
              border: Border.all(color: c.accentText.withValues(alpha: 0.3)),
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: c.accentText,
              semanticLabel: 'Resume',
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoritesStrip extends StatelessWidget {
  const _FavoritesStrip({required this.scripts});

  final List<Script> scripts;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 108,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      itemCount: scripts.length,
      separatorBuilder: (_, _) => const SizedBox(width: Space.md),
      itemBuilder: (context, i) => SizedBox(
        width: 168,
        child: SurfaceCard(
          onTap: () => context.push(Routes.editor(scripts[i].id)),
          padding: const EdgeInsets.all(Space.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ScriptGlyph(script: scripts[i], size: 30),
                  const Spacer(),
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: context.nl.accentText,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                scripts[i].displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
