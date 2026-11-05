import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../ai/data/gemini_service.dart';
import '../../wearables/data/wearables_service.dart';
import '../../wearables/logic/wearables_cubit.dart';
import '../../wearables/models/wearables_models.dart';
import '../logic/question_cubit.dart';

class QuestionScreen extends StatelessWidget {
  const QuestionScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => QuestionCubit(
      context.read<WearablesService>(),
      context.read<GeminiService>(),
    )..start(),
    child: const _QuestionView(),
  );
}

class _QuestionView extends StatefulWidget {
  const _QuestionView();

  @override
  State<_QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<_QuestionView> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onPause: context.read<QuestionCubit>().pauseCamera,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<WearablesCubit>().state;
    final configured = context.read<GeminiService>().isConfigured;
    return Scaffold(
      appBar: AppBar(title: const Text('Question Lens')),
      body: SafeArea(
        child: BlocBuilder<QuestionCubit, QuestionState>(
          builder: (context, state) {
            final cubit = context.read<QuestionCubit>();
            final answer = state.answer;
            final cameraView = state.phase == QuestionPhase.preview;
            return ListView(
              key: ValueKey(cameraView),
              padding: const EdgeInsets.all(Space.gutter),
              children: [
                if (!cameraView) ...[
                  Text(
                    'Look. Capture. Understand.',
                    style: context.text.headlineSmall,
                  ),
                  const SizedBox(height: Space.sm),
                  const Text(
                    'Open the glasses camera, frame a question including any code or options, '
                    'then press the shutter to send your photo to Gemini.',
                  ),
                  const SizedBox(height: Space.lg),
                  GlassPanel(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              connection.isConnected
                                  ? Icons.check_circle_outline
                                  : Icons.link_off,
                            ),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: Text(
                                connection.isConnected
                                    ? connection.deviceName ??
                                          'Glasses connected'
                                    : 'Connect Meta Ray-Ban Display',
                              ),
                            ),
                          ],
                        ),
                        if (!connection.isConnected)
                          TextButton(
                            onPressed: () async {
                              await cubit.suspend();
                              if (!context.mounted) return;
                              await context.push(Routes.glasses);
                              await cubit.start();
                            },
                            child: const Text('Connect glasses'),
                          ),
                        if (!configured) ...[
                          const SizedBox(height: Space.sm),
                          const Text(
                            'Gemini setup is required. Add GEMINI_API_KEY to .env '
                            'and run with --dart-define-from-file=.env.',
                          ),
                        ],
                        const SizedBox(height: Space.sm),
                        Text(
                          connection.inputs.name == 'available'
                              ? 'Next opens the preview. Capture or select opens it first, then captures on a second press.'
                              : 'Use the phone capture button. Hands-free controls require Meta Inputs access.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  FilledButton.icon(
                    onPressed:
                        connection.isConnected &&
                            configured &&
                            !state.busy &&
                            state.phase != QuestionPhase.preview
                        ? cubit.openPreview
                        : null,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                      state.photo == null
                          ? 'Open camera'
                          : 'Open camera for next question',
                    ),
                  ),
                ],
                if (cameraView && state.preview != null) ...[
                  const SizedBox(height: Space.lg),
                  Text('Live glasses camera', style: context.text.titleMedium),
                  const SizedBox(height: Space.sm),
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: state.preview!.aspectRatio,
                          child: ClipRect(
                            child: Transform.scale(
                              scale: state.zoom,
                              child: _LivePreviewImage(frame: state.preview!),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Text('Digital zoom: ${state.zoom.toStringAsFixed(1)}×'),
                  Slider(
                    value: state.zoom,
                    min: 1,
                    max: 3,
                    divisions: 20,
                    label: '${state.zoom.toStringAsFixed(1)}×',
                    semanticFormatterCallback: (value) =>
                        '${value.toStringAsFixed(1)} times zoom',
                    onChanged: cubit.setZoom,
                  ),
                  const Text(
                    'Keep the whole question, code, diagrams, and any options in view. Zoom crops the photo sent to AI.',
                  ),
                  const SizedBox(height: Space.md),
                  FilledButton.icon(
                    onPressed: connection.isConnected ? cubit.capture : null,
                    icon: const Icon(Icons.camera),
                    label: const Text('Take photo & answer'),
                  ),
                  TextButton(
                    onPressed: cubit.cancelPreview,
                    child: const Text('Close camera'),
                  ),
                ],
                if (state.phase == QuestionPhase.openingCamera)
                  TextButton(
                    onPressed: cubit.cancelPreview,
                    child: const Text('Cancel opening camera'),
                  ),
                const SizedBox(height: Space.sm),
                Text(
                  'Photos are sent to Google Gemini for analysis. Preview frames stay on your phone. '
                  'Nothing is sent until you press the shutter.',
                  style: context.text.bodySmall,
                ),
                if (state.busy) ...[
                  const SizedBox(height: Space.lg),
                  const LinearProgressIndicator(),
                  const SizedBox(height: Space.sm),
                  Semantics(
                    liveRegion: true,
                    child: Text(switch (state.phase) {
                      QuestionPhase.openingCamera =>
                        'Opening camera… Approve camera access in Meta AI if asked.',
                      QuestionPhase.closingCamera => 'Closing camera…',
                      QuestionPhase.capturing => 'Taking your photo…',
                      QuestionPhase.analyzing =>
                        'Reading and answering the question…',
                      _ => 'Sending answer to glasses…',
                    }),
                  ),
                ],
                if (state.message != null) ...[
                  const SizedBox(height: Space.lg),
                  Semantics(liveRegion: true, child: Text(state.message!)),
                  if (state.phase == QuestionPhase.error && state.photo != null)
                    TextButton(
                      onPressed: connection.isConnected ? cubit.retry : null,
                      child: const Text('Retry this photo'),
                    ),
                ],
                if (state.photo != null) ...[
                  const SizedBox(height: Space.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      state.photo!,
                      height: 220,
                      fit: BoxFit.contain,
                      gaplessPlayback: false,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 80,
                        child: Center(child: Text('Photo preview unavailable')),
                      ),
                    ),
                  ),
                ],
                if (answer != null) ...[
                  const SizedBox(height: Space.lg),
                  GlassPanel(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(answer.heading, style: context.text.labelLarge),
                        const SizedBox(height: Space.sm),
                        if (answer.hasAnswer)
                          SelectableText(
                            answer.answerText,
                            style: answer.selectedLabel != null
                                ? context.text.headlineSmall
                                : context.text.bodyLarge,
                          ),
                        if (answer.code.isNotEmpty) ...[
                          const SizedBox(height: Space.md),
                          Text(
                            'Code · ${answer.codeLanguage}',
                            style: context.text.labelLarge,
                          ),
                          const SizedBox(height: Space.sm),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(Space.md),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SelectableText(
                                answer.code,
                                style: const TextStyle(
                                  fontFamily: 'GeistMono',
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: Space.sm),
                        Text(answer.explanation),
                        const Divider(height: 32),
                        Text(answer.question, style: context.text.titleMedium),
                        for (final option in answer.options.entries)
                          Padding(
                            padding: const EdgeInsets.only(top: Space.sm),
                            child: Text(
                              '${option.key}. ${option.value}',
                              style: TextStyle(
                                fontWeight: option.key == answer.selectedLabel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        const SizedBox(height: Space.md),
                        Text(
                          state.shownOnGlasses
                              ? 'Summary shown on glasses'
                              : 'Available on phone',
                        ),
                        if (!state.shownOnGlasses && !state.busy)
                          TextButton(
                            onPressed: connection.canShowCues
                                ? cubit.showAgain
                                : null,
                            child: const Text('Send to glasses again'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'AI answers can be wrong. Check the explanation.',
                    style: context.text.bodySmall,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Evict superseded frames instead of retaining a video in the image cache.
class _LivePreviewImage extends StatefulWidget {
  const _LivePreviewImage({required this.frame});
  final CameraPreviewFrame frame;

  @override
  State<_LivePreviewImage> createState() => _LivePreviewImageState();
}

class _LivePreviewImageState extends State<_LivePreviewImage> {
  late MemoryImage _image = MemoryImage(widget.frame.jpeg);

  @override
  void didUpdateWidget(_LivePreviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.frame.jpeg, widget.frame.jpeg)) {
      unawaited(_image.evict());
      _image = MemoryImage(widget.frame.jpeg);
    }
  }

  @override
  void dispose() {
    unawaited(_image.evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Image(
    image: _image,
    fit: BoxFit.fill,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) =>
        const Center(child: Text('Preview unavailable. Reopen the camera.')),
  );
}
