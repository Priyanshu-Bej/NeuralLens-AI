import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neural_lens_button.dart';
import '../../../core/widgets/neural_lens_scaffold.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/state_views.dart';
import '../../scripts/data/script_repository.dart';
import '../../scripts/models/script_enums.dart';
import '../../scripts/models/script_section.dart';
import '../../scripts/util/duration_estimator.dart';
import '../data/gemini_exception.dart';
import '../data/gemini_service.dart';
import '../logic/studio_cubit.dart';
import '../models/generated_script.dart';

class AiStudioScreen extends StatelessWidget {
  const AiStudioScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (ctx) => StudioCubit(
      gemini: ctx.read<GeminiService>(),
      repository: ctx.read<ScriptRepository>(),
    ),
    child: BlocBuilder<StudioCubit, StudioState>(
      buildWhen: (a, b) => a.status != b.status,
      builder: (context, state) => switch (state.status) {
        StudioStatus.success => const _ResultView(),
        _ => const _FormView(),
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Form

class _FormView extends StatefulWidget {
  const _FormView();

  @override
  State<_FormView> createState() => _FormViewState();
}

class _FormViewState extends State<_FormView> {
  late final StudioCubit _cubit = context.read<StudioCubit>();
  late final _notes = TextEditingController(text: _cubit.state.request.notes);
  late final _customFormat = TextEditingController(
    text: _cubit.state.request.customFormat,
  );
  late bool _customDuration = !_presetDurations.contains(
    _cubit.state.request.durationSeconds,
  );

  static const _presetDurations = [30, 60, 120];

  /// Segment value standing in for "custom" duration.
  static const _custom = -1;

  @override
  void dispose() {
    _notes.dispose();
    _customFormat.dispose();
    super.dispose();
  }

  void _update(ScriptGenerationRequest Function(ScriptGenerationRequest) f) =>
      _cubit.updateRequest(f(_cubit.state.request));

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return BlocBuilder<StudioCubit, StudioState>(
      builder: (context, state) {
        final r = state.request;
        final generating = state.status == StudioStatus.generating;
        final configured = _cubit.isConfigured;
        return NeuralLensScaffold(
          title: 'AI Script Studio',
          subtitle: 'POWERED BY GEMINI',
          aurora: true,
          bottom: generating
              ? NeuralLensButton.secondary(
                  label: 'Cancel',
                  icon: Icons.close_rounded,
                  expand: true,
                  onPressed: _cubit.cancel,
                )
              : NeuralLensButton.ai(
                  label: 'Generate script',
                  expand: true,
                  onPressed: configured && r.isValid
                      ? () {
                          FocusScope.of(context).unfocus();
                          _cubit.generate();
                        }
                      : null,
                ),
          slivers: [
            SliverGutter(
              sliver: SliverList.list(
                children: [
                  const SizedBox(height: Space.md),
                  if (!configured) ...[
                    const _GeminiSetupCard(),
                    const SizedBox(height: Space.lg),
                  ],
                  AnimatedSize(
                    duration: Motion.medium,
                    curve: Motion.emphasized,
                    child: generating
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: Space.lg),
                            child: _GeneratingCard(model: _cubit.model),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  if (state.status == StudioStatus.failure &&
                      state.error != null) ...[
                    ErrorStateView(
                      compact: true,
                      title: state.error!.title,
                      message: state.error!.message,
                      onRetry: state.error!.isRetryable
                          ? _cubit.generate
                          : null,
                    ),
                    const SizedBox(height: Space.lg),
                  ],
                  AbsorbPointer(
                    absorbing: generating,
                    child: AnimatedOpacity(
                      duration: Motion.fast,
                      opacity: generating ? 0.45 : 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Composer(
                            controller: _notes,
                            onChanged: (v) =>
                                _update((r) => r.copyWith(notes: v)),
                          ),
                          const _Label('Format'),
                          _FormatGrid(
                            selected: r.format,
                            onSelected: (f) =>
                                _update((r) => r.copyWith(format: f)),
                          ),
                          if (r.format == ScriptFormat.custom) ...[
                            const SizedBox(height: Space.md),
                            TextField(
                              controller: _customFormat,
                              onChanged: (v) =>
                                  _update((r) => r.copyWith(customFormat: v)),
                              decoration: const InputDecoration(
                                hintText:
                                    'Describe the format, e.g. wedding toast',
                              ),
                            ),
                          ],
                          const _Label('Duration'),
                          SegmentedPill<int>(
                            options: [
                              for (final d in _presetDurations)
                                SegmentOption(
                                  d,
                                  d < 60 ? '$d sec' : '${d ~/ 60} min',
                                ),
                              const SegmentOption(_custom, 'Custom'),
                            ],
                            selected: _customDuration
                                ? _custom
                                : r.durationSeconds,
                            onChanged: (d) {
                              setState(() => _customDuration = d == _custom);
                              if (d != _custom) {
                                _update((r) => r.copyWith(durationSeconds: d));
                              }
                            },
                          ),
                          if (_customDuration) ...[
                            const SizedBox(height: Space.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: r.durationSeconds
                                        .clamp(15, 600)
                                        .toDouble(),
                                    min: 15,
                                    max: 600,
                                    divisions: 39,
                                    label: DurationEstimator.format(
                                      r.durationSeconds,
                                    ),
                                    onChanged: (v) => _update(
                                      (r) => r.copyWith(
                                        durationSeconds: v.round(),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 56,
                                  child: Text(
                                    DurationEstimator.format(r.durationSeconds),
                                    textAlign: TextAlign.end,
                                    style: context.mono(
                                      size: 14,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const _Label('Tone'),
                          _ChoiceWrap<ScriptTone>(
                            values: ScriptTone.values,
                            selected: r.tone,
                            labelOf: (t) => t.label,
                            onSelected: (t) =>
                                _update((r) => r.copyWith(tone: t)),
                          ),
                          const _Label('Language'),
                          _ChoiceWrap<ScriptLanguage>(
                            values: ScriptLanguage.values,
                            selected: r.language,
                            labelOf: (l) => l.label,
                            onSelected: (l) =>
                                _update((r) => r.copyWith(language: l)),
                          ),
                          const SizedBox(height: Space.xl),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: c.textMuted,
                              ),
                              const SizedBox(width: Space.sm),
                              Expanded(
                                child: Text(
                                  'Target ≈ ${DurationEstimator.targetWords(r.durationSeconds)} '
                                  'spoken words. AI output can be inaccurate — review facts '
                                  'before presenting.',
                                  style: context.text.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.xl + 4, bottom: Space.md),
    child: Text(text.toUpperCase(), style: context.text.labelSmall),
  );
}

/// The notes field, presented as a large prompt card.
class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    const border = OutlineInputBorder(borderSide: BorderSide.none);
    return SurfaceCard(
      radius: Radii.lg,
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 18, color: c.accentText),
              const SizedBox(width: Space.sm),
              Text(
                'TOPIC OR ROUGH NOTES',
                style: context.text.labelSmall!.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
          TextField(
            controller: controller,
            onChanged: onChanged,
            minLines: 5,
            maxLines: 10,
            maxLength: ScriptGenerationRequest.maxNotesLength,
            textCapitalization: TextCapitalization.sentences,
            style: context.text.bodyLarge!.copyWith(fontSize: 17),
            decoration: const InputDecoration(
              hintText:
                  'e.g. Launching our new running app. Key points: '
                  'AI coach, offline maps, free for 30 days…',
              filled: false,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
              contentPadding: EdgeInsets.symmetric(vertical: Space.md),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatGrid extends StatelessWidget {
  const _FormatGrid({required this.selected, required this.onSelected});

  final ScriptFormat selected;
  final ValueChanged<ScriptFormat> onSelected;

  @override
  Widget build(BuildContext context) {
    const columns = 3;
    final rows = <List<ScriptFormat>>[
      for (var i = 0; i < ScriptFormat.values.length; i += columns)
        ScriptFormat.values.sublist(
          i,
          (i + columns).clamp(0, ScriptFormat.values.length),
        ),
    ];
    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: Space.sm),
          Row(
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: Space.sm),
                Expanded(
                  child: i < rows[r].length
                      ? _FormatTile(
                          format: rows[r][i],
                          selected: rows[r][i] == selected,
                          onTap: () => onSelected(rows[r][i]),
                        )
                      : const SizedBox(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.format,
    required this.selected,
    required this.onTap,
  });

  final ScriptFormat format;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Pressable(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.emphasized,
            height: 88,
            padding: const EdgeInsets.all(Space.md),
            decoration: ShapeDecoration(
              color: selected ? c.accentSoft : c.surfaceRaised,
              shape: Shapes.of(
                Radii.md,
                side: BorderSide(
                  color: selected
                      ? c.accentText.withValues(alpha: 0.6)
                      : c.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  format.icon,
                  size: 22,
                  color: selected ? c.accentText : c.textSecondary,
                ),
                const Spacer(),
                Text(
                  format.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium!.copyWith(
                    color: selected ? c.textPrimary : c.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceWrap<T> extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.sm,
    runSpacing: Space.sm,
    children: [
      for (final v in values)
        SelectChip(
          label: labelOf(v),
          selected: v == selected,
          onTap: () => onSelected(v),
        ),
    ],
  );
}

class _GeminiSetupCard extends StatelessWidget {
  const _GeminiSetupCard();

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: ShapeDecoration(
        color: c.warning.withValues(alpha: 0.07),
        shape: Shapes.of(
          Radii.md,
          side: BorderSide(color: c.warning.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: Icons.key_rounded, color: c.warning, size: 34),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  'Connect Gemini to generate',
                  style: context.text.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(
            const GeminiException(GeminiErrorKind.missingKey).message,
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: Space.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Space.md),
            decoration: ShapeDecoration(
              color: c.background,
              shape: Shapes.of(Radii.sm, side: BorderSide(color: c.border)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                'flutter run --dart-define-from-file=.env',
                maxLines: 1,
                style: context.mono(size: 12, color: c.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Development only: a key compiled into an APK can be extracted. '
            'Use a backend or Firebase AI Logic for public releases.',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _GeneratingCard extends StatelessWidget {
  const _GeneratingCard({required this.model});

  final String model;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return SurfaceCard(
      highlighted: true,
      radius: Radii.lg,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          const Positioned.fill(child: AuroraGlow(animate: true)),
          Padding(
            padding: const EdgeInsets.all(Space.lg + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: ShapeDecoration(
                        gradient: c.brandGradient,
                        shape: Shapes.of(12),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 19,
                        color: c.onAccent,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Text(
                        'Writing your script…',
                        style: context.text.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                Text(
                  'Using $model. This usually takes a few seconds.',
                  style: context.text.bodySmall!.copyWith(
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: Space.lg),
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  child: LinearProgressIndicator(minHeight: 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result

class _ResultView extends StatefulWidget {
  const _ResultView();

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  bool _saving = false;

  Future<void> _save({required bool present}) async {
    setState(() => _saving = true);
    final cubit = context.read<StudioCubit>();
    try {
      final script = await cubit.saveResult();
      if (!mounted || script == null) return;
      context.pushReplacement(
        present ? Routes.present(script.id) : Routes.editor(script.id),
      );
    } catch (_) {
      if (mounted) showSnack(context, 'Could not save the script. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _regenerate() async {
    final ok = await confirmDialog(
      context,
      title: 'Regenerate?',
      message:
          'This replaces the unsaved draft with a new version. Your input is kept.',
      confirmLabel: 'Regenerate',
    );
    if (ok && mounted) await context.read<StudioCubit>().generate();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final state = cubit.state;
    final result = state.result!;
    final c = context.nl;
    final target = state.request.durationSeconds;
    return NeuralLensScaffold(
      title: 'Your draft',
      largeTitle: false,
      aurora: true,
      bottom: Row(
        children: [
          Expanded(
            child: NeuralLensButton.secondary(
              label: 'Present',
              icon: Icons.play_arrow_rounded,
              expand: true,
              onPressed: _saving ? null : () => _save(present: true),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: NeuralLensButton(
              label: 'Save & edit',
              icon: Icons.check_rounded,
              expand: true,
              loading: _saving,
              onPressed: () => _save(present: false),
            ),
          ),
        ],
      ),
      slivers: [
        SliverGutter(
          sliver: SliverList.list(
            children: [
              const SizedBox(height: Space.sm),
              Pill(
                label: 'AI draft',
                icon: Icons.auto_awesome_rounded,
                color: c.accent2,
                filled: true,
              ),
              const SizedBox(height: Space.md),
              Text(result.title, style: context.text.headlineMedium),
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  Pill(label: result.format.label),
                  Pill(label: result.tone.label),
                  Pill(
                    label:
                        '${DurationEstimator.formatApprox(result.estimatedDurationSeconds)}'
                        ' · target ${DurationEstimator.format(target)}',
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              Row(
                children: [
                  Expanded(
                    child: NeuralLensButton.ghost(
                      label: 'Edit input',
                      icon: Icons.tune_rounded,
                      compact: true,
                      expand: true,
                      onPressed: cubit.editInput,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: NeuralLensButton.ghost(
                      label: 'Regenerate',
                      icon: Icons.refresh_rounded,
                      compact: true,
                      expand: true,
                      onPressed: _regenerate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              for (var i = 0; i < result.sections.length; i++) ...[
                _SectionCard(index: i, section: result.sections[i]),
                const SizedBox(height: Space.md),
              ],
              const SizedBox(height: Space.sm),
              Text(
                'AI-generated. Check names, numbers and claims before you present.',
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.index, required this.section});

  final int index;
  final ScriptSection section;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                (index + 1).toString().padLeft(2, '0'),
                style: context.mono(size: 12, color: c.textMuted),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  section.heading.toUpperCase(),
                  style: context.text.labelSmall!.copyWith(color: c.accentText),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(section.spokenText, style: context.text.bodyLarge),
          if (section.cueKeywords.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [for (final k in section.cueKeywords) Pill(label: k)],
            ),
          ],
        ],
      ),
    );
  }
}
