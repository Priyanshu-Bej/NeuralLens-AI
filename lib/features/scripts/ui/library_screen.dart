import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neural_lens_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../logic/library_cubit.dart';
import 'script_actions.dart';
import 'widgets/script_card.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final _search = TextEditingController(
    text: context.read<LibraryCubit>().state.query,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LibraryCubit>();
    final c = context.nl;
    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, state) {
        final visible = state.visible;
        final count = state.scripts.length;
        return NeuralLensScaffold(
          title: 'Library',
          subtitle: state.status == LoadStatus.ready
              ? '$count ${count == 1 ? 'ITEM' : 'ITEMS'} · STORED ON DEVICE'
              : null,
          slivers: [
            SliverGutter(
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Space.md),
                    TextField(
                      controller: _search,
                      onChanged: cubit.search,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search scripts and notes',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          borderSide: BorderSide(color: c.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          borderSide: BorderSide(color: c.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          borderSide: BorderSide(
                            color: c.accentText.withValues(alpha: 0.7),
                            width: 1.5,
                          ),
                        ),
                        suffixIcon: state.query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _search.clear();
                                  cubit.search('');
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: Space.md),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Row(
                  children: [
                    for (final f in LibraryFilter.values) ...[
                      SelectChip(
                        label: f.label,
                        selected: state.filter == f,
                        onTap: () => cubit.setFilter(f),
                      ),
                      const SizedBox(width: Space.sm),
                    ],
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.lg)),
            if (state.status == LoadStatus.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingStateView(),
              )
            else if (state.status == LoadStatus.failure)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorStateView(
                  title: 'Could not load your library',
                  message: 'Local storage returned an error.',
                  onRetry: cubit.load,
                ),
              )
            else if (state.scripts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateView(
                  icon: Icons.layers_outlined,
                  title: 'Nothing saved yet',
                  message:
                      'Scripts and notes you create are stored on this device '
                      'and work offline.',
                  actionLabel: 'Create',
                  actionIcon: Icons.add_rounded,
                  onAction: () => showCreateSheet(context),
                ),
              )
            else if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateView(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message: state.query.isEmpty
                      ? 'Nothing in ${state.filter.label.toLowerCase()} yet.'
                      : 'Nothing matches "${state.query}".',
                ),
              )
            else
              SliverGutter(
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                  itemBuilder: (context, i) {
                    final script = visible[i];
                    return ScriptCard(
                      key: ValueKey(script.id),
                      script: script,
                      onTap: () => context.push(Routes.editor(script.id)),
                      onAction: (a) => handleScriptAction(context, script, a),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
