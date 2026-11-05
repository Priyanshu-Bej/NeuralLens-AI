import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neural_lens_button.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/state_views.dart';
import '../../ai/data/gemini_exception.dart';
import '../../ai/data/gemini_service.dart';
import '../data/script_repository.dart';
import '../logic/editor_cubit.dart';
import '../models/script.dart';
import '../models/script_enums.dart';
import '../util/cue_segmenter.dart';
import '../util/duration_estimator.dart';
import 'widgets/revision_sheet.dart';

class EditorScreen extends StatelessWidget {
  const EditorScreen({
    super.key,
    this.scriptId,
    this.newKind = ScriptKind.script,
  });

  /// Null creates a new draft of [newKind].
  final String? scriptId;
  final ScriptKind newKind;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (ctx) {
      final cubit = EditorCubit(
        repository: ctx.read<ScriptRepository>(),
        gemini: ctx.read<GeminiService>(),
      );
      scriptId == null ? cubit.createNew(newKind) : cubit.open(scriptId!);
      return cubit;
    },
    child: const _EditorView(),
  );
}

class _EditorView extends StatefulWidget {
  const _EditorView();

  @override
  State<_EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<_EditorView> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _bodyFocus = FocusNode();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _syncControllers(Script script) {
    _title.text = script.title;
    _body.text = script.body;
  }

  Future<void> _present(EditorCubit cubit) async {
    await cubit.save();
    final script = cubit.state.script;
    if (!mounted || script == null || !cubit.state.persisted) return;
    if (script.body.trim().isEmpty) {
      showSnack(context, 'Add some text before presenting.');
      return;
    }
    await context.push(Routes.present(script.id));
  }

  Future<void> _duplicate(EditorCubit cubit) async {
    final copy = await cubit.duplicate();
    if (!mounted) return;
    if (copy == null) {
      showSnack(context, 'Add some content before duplicating.');
      return;
    }
    showSnack(context, 'Opened "${copy.displayTitle}"');
    context.pushReplacement(Routes.editor(copy.id));
  }

  Future<void> _delete(EditorCubit cubit) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete "${cubit.state.script?.displayTitle}"?',
      message: 'This permanently removes it from this device.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    await cubit.delete();
    if (mounted) context.pop();
  }

  Future<void> _editTags(EditorCubit cubit) async {
    final result = await promptText(
      context,
      title: 'Tags',
      initial: cubit.state.script?.tags.join(', ') ?? '',
      hint: 'pitch, weekly, demo',
    );
    if (result == null) return;
    cubit.setTags(
      result
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList(),
    );
  }

  Future<void> _aiAction(EditorCubit cubit, AiTask task) async {
    if (!cubit.geminiConfigured) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Gemini is not configured'),
          content: Text(
            const GeminiException(GeminiErrorKind.missingKey).message,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    if (cubit.state.script?.body.trim().isEmpty ?? true) {
      showSnack(context, 'Write or paste some text first.');
      return;
    }
    if (task == AiTask.cueSections) {
      await cubit.requestCueSections();
      return;
    }
    final instruction = await showRewriteSheet(context);
    if (instruction != null) {
      await cubit.requestRewrite(instruction: instruction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    return MultiBlocListener(
      listeners: [
        BlocListener<EditorCubit, EditorState>(
          listenWhen: (a, b) => a.contentVersion != b.contentVersion,
          listener: (_, s) => _syncControllers(s.script!),
        ),
        BlocListener<EditorCubit, EditorState>(
          listenWhen: (a, b) =>
              b.pendingRevision != null &&
              a.pendingRevision != b.pendingRevision,
          listener: (context, s) async {
            final accept = await showRevisionSheet(
              context,
              revision: s.pendingRevision!,
              kind: s.pendingKind,
            );
            accept ? await cubit.acceptRevision() : cubit.discardRevision();
          },
        ),
      ],
      child: BlocBuilder<EditorCubit, EditorState>(
        builder: (context, state) {
          if (state.load == EditorLoad.loading) {
            return const Scaffold(body: LoadingStateView());
          }
          if (state.load == EditorLoad.notFound || state.script == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const EmptyStateView(
                icon: Icons.find_in_page_outlined,
                title: 'Script not found',
                message: 'It may have been deleted.',
              ),
            );
          }
          final script = state.script!;
          final isScript = script.kind == ScriptKind.script;
          return Scaffold(
            appBar: AppBar(
              toolbarHeight: 64,
              leadingWidth: 64,
              leading: Center(
                child: CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              title: _SaveIndicator(
                status: state.saveStatus,
                persisted: state.persisted,
              ),
              actions: [
                CircleIconButton(
                  tooltip: script.isFavorite ? 'Remove favorite' : 'Favorite',
                  onPressed: cubit.toggleFavorite,
                  icon: script.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: script.isFavorite ? context.nl.accentText : null,
                ),
                const SizedBox(width: Space.sm),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (v) => switch (v) {
                    'tags' => _editTags(cubit),
                    'duplicate' => _duplicate(cubit),
                    'kind' => cubit.setKind(
                      isScript ? ScriptKind.note : ScriptKind.script,
                    ),
                    'delete' => _delete(cubit),
                    _ => null,
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'tags',
                      child: Text('Edit tags'),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Text('Duplicate'),
                    ),
                    PopupMenuItem(
                      value: 'kind',
                      child: Text(
                        isScript ? 'Convert to note' : 'Convert to script',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: context.nl.danger),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: Space.xs),
              ],
            ),
            body: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  0,
                  Space.gutter,
                  Space.xxl,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.manual,
                children: [
                  TextField(
                    controller: _title,
                    onChanged: cubit.updateTitle,
                    style: context.text.headlineMedium,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _bodyFocus.requestFocus(),
                    decoration: InputDecoration(
                      hintText: isScript ? 'Script title' : 'Note title',
                      hintStyle: context.text.headlineMedium!.copyWith(
                        color: context.nl.textMuted,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: Space.sm,
                      ),
                    ),
                  ),
                  _MetaRow(script: script, onEditTags: () => _editTags(cubit)),
                  const SizedBox(height: Space.lg),
                  if (isScript)
                    _AiToolbar(
                      state: state,
                      onAction: (t) => _aiAction(cubit, t),
                    ),
                  if (state.aiError != null) ...[
                    const SizedBox(height: Space.md),
                    ErrorStateView(
                      compact: true,
                      title: state.aiError!.title,
                      message: state.aiError!.message,
                      onRetry: state.aiError!.isRetryable
                          ? () {
                              cubit.dismissAiError();
                              _aiAction(cubit, state.failedTask);
                            }
                          : cubit.dismissAiError,
                      retryLabel: state.aiError!.isRetryable
                          ? 'Try again'
                          : 'Dismiss',
                    ),
                  ],
                  const SizedBox(height: Space.lg),
                  Divider(color: context.nl.border),
                  TextField(
                    controller: _body,
                    focusNode: _bodyFocus,
                    onChanged: cubit.updateBody,
                    maxLines: null,
                    minLines: 12,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: context.text.bodyLarge!.copyWith(
                      fontSize: 17.5,
                      height: 1.65,
                    ),
                    decoration: InputDecoration(
                      hintText: isScript
                          ? 'Start writing what you want to say…\n\n'
                                'Tip: start a line with "## " to begin a new section.'
                          : 'Jot down ideas, talking points or reminders…',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: Space.lg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: isScript
                ? SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        Space.gutter,
                        Space.sm,
                        Space.gutter,
                        Space.md + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: NeuralLensButton(
                        label: 'Present',
                        icon: Icons.play_arrow_rounded,
                        expand: true,
                        onPressed: script.body.trim().isEmpty
                            ? null
                            : () => _present(cubit),
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.status, required this.persisted});

  final SaveStatus status;
  final bool persisted;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final (label, color, icon) = switch (status) {
      SaveStatus.saving => ('Saving…', c.textMuted, Icons.sync_rounded),
      SaveStatus.unsaved => ('Editing', c.textMuted, Icons.edit_rounded),
      SaveStatus.failed => (
        'Save failed',
        c.danger,
        Icons.error_outline_rounded,
      ),
      SaveStatus.saved when !persisted => (
        'Draft',
        c.textMuted,
        Icons.edit_outlined,
      ),
      SaveStatus.saved => ('Saved', c.accentText, Icons.check_rounded),
    };
    return AnimatedSwitcher(
      duration: Motion.fast,
      child: Container(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: context.mono(size: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.script, required this.onEditTags});

  final Script script;
  final VoidCallback onEditTags;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    final words = DurationEstimator.wordCount(script.spokenText);
    final seconds = DurationEstimator.estimateSeconds(script.spokenText);
    final cues = CueSegmenter.cues(script.resolvedSections).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$words words · ${DurationEstimator.formatApprox(seconds)} · '
                  '$cues cards'
              .toUpperCase(),
          style: context.mono(size: 11.5),
        ),
        if (script.kind == ScriptKind.script) ...[
          const SizedBox(height: Space.lg),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              _EnumMenu<ScriptFormat>(
                icon: script.format.icon,
                label: script.format.label,
                values: ScriptFormat.values,
                labelOf: (f) => f.label,
                onSelected: cubit.setFormat,
              ),
              _EnumMenu<ScriptTone>(
                icon: Icons.record_voice_over_outlined,
                label: script.tone.label,
                values: ScriptTone.values,
                labelOf: (t) => t.label,
                onSelected: cubit.setTone,
              ),
              _MetaChip(
                icon: Icons.tag_rounded,
                label: script.tags.isEmpty
                    ? 'Add tags'
                    : script.tags.join(', '),
                onTap: onEditTags,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _EnumMenu<T> extends StatelessWidget {
  const _EnumMenu({
    required this.icon,
    required this.label,
    required this.values,
    required this.labelOf,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      for (final v in values)
        MenuItemButton(onPressed: () => onSelected(v), child: Text(labelOf(v))),
    ],
    builder: (context, controller, _) => _MetaChip(
      icon: icon,
      label: label,
      trailing: Icons.expand_more_rounded,
      onTap: () => controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Pressable(
      child: Material(
        color: c.surfaceRaised,
        shape: StadiumBorder(side: BorderSide(color: c.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: c.textSecondary),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge!.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 2),
                  Icon(trailing, size: 16, color: c.textMuted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiToolbar extends StatelessWidget {
  const _AiToolbar({required this.state, required this.onAction});

  final EditorState state;
  final ValueChanged<AiTask> onAction;

  @override
  Widget build(BuildContext context) {
    final busy = state.aiTask != AiTask.none;
    return AnimatedSwitcher(
      duration: Motion.medium,
      child: busy
          ? SurfaceCard(
              key: const ValueKey('busy'),
              highlighted: true,
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.sm,
                Space.sm,
                Space.sm,
              ),
              child: Row(
                children: [
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      state.aiTask == AiTask.rewrite
                          ? 'Writing a revised version…'
                          : 'Splitting into cards…',
                      style: context.text.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: context.read<EditorCubit>().cancelAi,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            )
          : Container(
              key: const ValueKey('idle'),
              padding: const EdgeInsets.all(6),
              decoration: ShapeDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.nl.accent.withValues(alpha: 0.1),
                    context.nl.accent2.withValues(alpha: 0.08),
                  ],
                ),
                shape: Shapes.of(
                  Radii.pill,
                  side: BorderSide(color: context.nl.borderStrong),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: NeuralLensButton.ghost(
                      label: 'Revise with AI',
                      icon: Icons.auto_awesome_rounded,
                      compact: true,
                      expand: true,
                      onPressed: () => onAction(AiTask.rewrite),
                    ),
                  ),
                  Container(width: 1, height: 22, color: context.nl.border),
                  Expanded(
                    child: NeuralLensButton.ghost(
                      label: 'Split into cards',
                      icon: Icons.view_agenda_outlined,
                      compact: true,
                      expand: true,
                      onPressed: () => onAction(AiTask.cueSections),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
