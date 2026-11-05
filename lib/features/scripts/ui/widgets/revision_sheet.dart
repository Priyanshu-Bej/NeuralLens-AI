import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/neural_lens_button.dart';
import '../../../ai/models/generated_script.dart';
import '../../logic/editor_cubit.dart';
import '../../util/duration_estimator.dart';

const _presets = [
  'Make it tighter and punchier',
  'Use simpler, more conversational words',
  'Make it more energetic',
  'Make it more professional',
  'Shorten it by about a third',
];

/// Asks how to revise. Returns the instruction, or null when dismissed.
Future<String?> showRewriteSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RewriteSheet(),
    );

class _RewriteSheet extends StatefulWidget {
  const _RewriteSheet();

  @override
  State<_RewriteSheet> createState() => _RewriteSheetState();
}

class _RewriteSheetState extends State<_RewriteSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      Space.gutter,
      0,
      Space.gutter,
      Space.xl + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Revise with AI', style: context.text.headlineSmall),
        const SizedBox(height: Space.xs),
        Text(
          'You will review the revision before it replaces your text.',
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: Space.lg),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final p in _presets)
              ActionChip(
                label: Text(p),
                onPressed: () => Navigator.pop(context, p),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _controller,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Or describe the change you want…',
          ),
        ),
        const SizedBox(height: Space.lg),
        NeuralLensButton.ai(
          label: 'Revise',
          expand: true,
          onPressed: () => Navigator.pop(context, _controller.text),
        ),
      ],
    ),
  );
}

/// Shows an AI revision for confirmation. Returns true to replace the text.
Future<bool> showRevisionSheet(
  BuildContext context, {
  required GeneratedScript revision,
  required AiTask kind,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              children: [
                Text(kind.label, style: ctx.text.headlineSmall),
                const SizedBox(height: Space.xs),
                Text(
                  '${revision.sections.length} sections · '
                  '${DurationEstimator.formatApprox(revision.estimatedDurationSeconds)}'
                  ' · Review before replacing your current text.',
                  style: ctx.text.bodyMedium,
                ),
                const SizedBox(height: Space.lg),
                for (final (i, s) in revision.sections.indexed) ...[
                  Container(
                    padding: const EdgeInsets.all(Space.lg),
                    decoration: ShapeDecoration(
                      color: ctx.nl.surfaceHigh,
                      shape: Shapes.of(
                        Radii.md,
                        side: BorderSide(color: ctx.nl.border),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(i + 1).toString().padLeft(2, '0')}  '
                          '${s.heading.toUpperCase()}',
                          style: ctx.text.labelSmall!.copyWith(
                            color: ctx.nl.accentText,
                          ),
                        ),
                        const SizedBox(height: Space.sm),
                        Text(s.spokenText, style: ctx.text.bodyLarge),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.md),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.sm,
                Space.gutter,
                Space.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: NeuralLensButton.secondary(
                      label: 'Keep original',
                      expand: true,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: NeuralLensButton(
                      label: 'Replace text',
                      icon: Icons.check_rounded,
                      expand: true,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
