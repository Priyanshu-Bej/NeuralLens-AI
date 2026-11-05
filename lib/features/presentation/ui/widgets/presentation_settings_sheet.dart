import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/common.dart';
import '../../logic/presentation_cubit.dart';
import '../../models/presentation_settings.dart';

Future<void> showPresentationSettingsSheet(
  BuildContext context,
  PresentationCubit cubit,
) => showModalBottomSheet<void>(
  context: context,
  builder: (_) => BlocProvider.value(
    value: cubit,
    child: const _PresentationSettingsSheet(),
  ),
);

class _PresentationSettingsSheet extends StatelessWidget {
  const _PresentationSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PresentationCubit>();
    return BlocBuilder<PresentationCubit, PresentationState>(
      buildWhen: (a, b) => a.settings != b.settings,
      builder: (context, state) {
        final s = state.settings;
        final phone = s.mode == PresentationMode.phone;
        return SafeArea(
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
                Text('Display', style: context.text.headlineSmall),
                const SizedBox(height: Space.lg),
                SegmentedPill<PresentationMode>(
                  options: const [
                    SegmentOption(
                      PresentationMode.phone,
                      'Phone',
                      icon: Icons.smartphone_rounded,
                    ),
                    SegmentOption(
                      PresentationMode.glasses,
                      'Glasses',
                      icon: Icons.visibility_outlined,
                    ),
                  ],
                  selected: s.mode,
                  onChanged: (v) => cubit.updateSettings(s.copyWith(mode: v)),
                ),
                const SizedBox(height: Space.lg),
                _Row(
                  label: phone ? 'Scroll speed' : 'Pace',
                  value: '${s.speed} · ~${s.wordsPerMinute} wpm',
                ),
                Slider(
                  value: s.speed.toDouble(),
                  min: PresentationSettings.minSpeed.toDouble(),
                  max: PresentationSettings.maxSpeed.toDouble(),
                  divisions: 9,
                  onChanged: (v) =>
                      cubit.updateSettings(s.copyWith(speed: v.round())),
                ),
                if (phone) ...[
                  _Row(label: 'Font size', value: '${s.fontSize.round()} pt'),
                  Slider(
                    value: s.fontSize,
                    min: PresentationSettings.minFontSize,
                    max: PresentationSettings.maxFontSize,
                    divisions: 26,
                    onChanged: (v) =>
                        cubit.updateSettings(s.copyWith(fontSize: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mirror text'),
                    subtitle: const Text('For reflective teleprompter glass'),
                    value: s.mirror,
                    onChanged: (v) =>
                        cubit.updateSettings(s.copyWith(mirror: v)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: context.text.titleSmall)),
      Text(value, style: context.mono(size: 12, color: context.nl.textPrimary)),
    ],
  );
}
