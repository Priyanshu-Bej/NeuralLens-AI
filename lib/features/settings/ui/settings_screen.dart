import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neural_lens_scaffold.dart';
import '../../presentation/models/presentation_settings.dart';
import '../../wearables/logic/wearables_cubit.dart';
import '../../wearables/models/wearables_models.dart';
import '../../wearables/ui/widgets/glass_connection_card.dart';
import '../logic/settings_cubit.dart';
import '../models/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    final config = context.read<AppConfig>();
    final c = context.nl;
    return BlocBuilder<SettingsCubit, AppSettings>(
      builder: (context, s) {
        final p = s.presentation;
        return NeuralLensScaffold(
          title: 'Settings',
          slivers: [
            SliverGutter(
              sliver: SliverList.list(
                children: [
                  const SectionHeader(
                    title: 'Teleprompter defaults',
                    padding: EdgeInsets.only(top: Space.lg, bottom: Space.md),
                  ),
                  _Group(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(Space.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                              selected: p.mode,
                              onChanged: (v) =>
                                  cubit.setPresentation(p.copyWith(mode: v)),
                            ),
                            const SizedBox(height: Space.sm + 2),
                            Text(
                              p.mode.description,
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      _SliderTile(
                        icon: Icons.format_size_rounded,
                        label: 'Font size',
                        valueLabel: '${p.fontSize.round()} pt',
                        value: p.fontSize,
                        min: PresentationSettings.minFontSize,
                        max: PresentationSettings.maxFontSize,
                        divisions: 26,
                        onChanged: (v) =>
                            cubit.setPresentation(p.copyWith(fontSize: v)),
                      ),
                      _SliderTile(
                        icon: Icons.speed_rounded,
                        label: 'Scroll speed',
                        valueLabel: '${p.speed} · ~${p.wordsPerMinute} wpm',
                        value: p.speed.toDouble(),
                        min: PresentationSettings.minSpeed.toDouble(),
                        max: PresentationSettings.maxSpeed.toDouble(),
                        divisions: 9,
                        onChanged: (v) =>
                            cubit.setPresentation(p.copyWith(speed: v.round())),
                      ),
                      _SettingRow(
                        icon: Icons.flip_rounded,
                        title: 'Mirror text',
                        subtitle: 'For reflective teleprompter glass',
                        trailing: Switch(
                          value: p.mirror,
                          onChanged: (v) =>
                              cubit.setPresentation(p.copyWith(mirror: v)),
                        ),
                        onTap: () => cubit.setPresentation(
                          p.copyWith(mirror: !p.mirror),
                        ),
                      ),
                    ],
                  ),
                  const SectionHeader(title: 'Appearance'),
                  _Group(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(Space.lg),
                        child: SegmentedPill<ThemeMode>(
                          options: const [
                            SegmentOption(
                              ThemeMode.dark,
                              'Dark',
                              icon: Icons.dark_mode_outlined,
                            ),
                            SegmentOption(
                              ThemeMode.light,
                              'Light',
                              icon: Icons.light_mode_outlined,
                            ),
                            SegmentOption(
                              ThemeMode.system,
                              'Auto',
                              icon: Icons.brightness_auto_outlined,
                            ),
                          ],
                          selected: s.themeMode,
                          onChanged: cubit.setThemeMode,
                        ),
                      ),
                    ],
                  ),
                  const SectionHeader(title: 'Glasses'),
                  GlassConnectionCard(
                    onTap: () => context.push(Routes.glasses),
                  ),
                  const SizedBox(height: Space.md),
                  _Group(
                    children: [
                      const _NeuralBandStatus(),
                      _SettingRow(
                        icon: Icons.swap_vert_rounded,
                        title: 'Invert navigation',
                        subtitle: 'Swap next / previous for Neural Band swipes',
                        trailing: Switch(
                          value: s.invertBandNavigation,
                          onChanged: cubit.setInvertBandNavigation,
                        ),
                        onTap: () => cubit.setInvertBandNavigation(
                          !s.invertBandNavigation,
                        ),
                      ),
                      _SettingRow(
                        icon: Icons.touch_app_outlined,
                        title: 'Select gesture',
                        subtitle: s.bandSelectAction.label,
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: c.textMuted,
                        ),
                        onTap: () async {
                          final action = await _pickSelectAction(
                            context,
                            s.bandSelectAction,
                          );
                          if (action != null) cubit.setBandSelectAction(action);
                        },
                      ),
                    ],
                  ),
                  const SectionHeader(title: 'AI'),
                  _Group(
                    children: [
                      _SettingRow(
                        icon: config.isGeminiConfigured
                            ? Icons.auto_awesome_rounded
                            : Icons.key_off_rounded,
                        iconColor: config.isGeminiConfigured
                            ? c.accent2
                            : c.warning,
                        title: config.isGeminiConfigured
                            ? 'Gemini configured'
                            : 'Gemini not configured',
                        subtitle: config.isGeminiConfigured
                            ? 'Model: ${config.geminiModel}'
                            : 'Run with --dart-define=GEMINI_API_KEY=YOUR_KEY',
                        trailing: Pill(
                          label: config.isGeminiConfigured ? 'Ready' : 'Off',
                          color: config.isGeminiConfigured
                              ? c.accentText
                              : c.warning,
                          filled: true,
                        ),
                      ),
                    ],
                  ),
                  const SectionHeader(title: 'About'),
                  const _Group(children: [_VersionTile()]),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<BandSelectAction?> _pickSelectAction(
    BuildContext context,
    BandSelectAction current,
  ) => showModalBottomSheet<BandSelectAction>(
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
            Text('Select gesture', style: ctx.text.headlineSmall),
            const SizedBox(height: Space.xs),
            Text(
              'What a Neural Band select does while presenting.',
              style: ctx.text.bodyMedium,
            ),
            const SizedBox(height: Space.lg),
            _Group(
              children: [
                for (final a in BandSelectAction.values)
                  _SettingRow(
                    icon: a == BandSelectAction.pauseResume
                        ? Icons.pause_circle_outline_rounded
                        : Icons.skip_next_outlined,
                    title: a.label,
                    trailing: a == current
                        ? Icon(Icons.check_rounded, color: ctx.nl.accentText)
                        : null,
                    onTap: () => Navigator.pop(ctx, a),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(height: 1, indent: Space.lg, color: context.nl.border),
          children[i],
        ],
      ],
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md + 2,
        ),
        child: Row(
          children: [
            IconTile(icon: icon, color: iconColor ?? c.textSecondary, size: 36),
            const SizedBox(width: Space.md + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: context.text.bodySmall!.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Space.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md + 2, Space.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: icon, color: c.textSecondary, size: 36),
              const SizedBox(width: Space.md + 2),
              Expanded(child: Text(label, style: context.text.titleSmall)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: ShapeDecoration(
                  color: c.surfaceHigh,
                  shape: Shapes.of(Radii.xs),
                ),
                child: Text(
                  valueLabel,
                  style: context.mono(size: 11.5, color: c.textPrimary),
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _NeuralBandStatus extends StatelessWidget {
  const _NeuralBandStatus();

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final s = context.watch<WearablesCubit>().state;
    final (title, subtitle, color) = switch (s.inputs) {
      InputsAvailability.available => (
        'Neural Band input active',
        'Swipe to change cards; select to pause or resume.',
        c.accentText,
      ),
      InputsAvailability.denied => (
        'Neural Band input not enabled',
        'Inputs must be enabled for this app in the Meta Wearables Developer Center.',
        c.warning,
      ),
      InputsAvailability.unavailable => (
        'Neural Band input unavailable',
        s.message ?? 'The connected glasses did not provide input events.',
        c.textMuted,
      ),
      InputsAvailability.unknown => (
        'Neural Band input',
        'Available after glasses connect. On-screen controls always work.',
        c.textSecondary,
      ),
    };
    return _SettingRow(
      icon: Icons.watch_outlined,
      iconColor: color,
      title: title,
      subtitle: subtitle,
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile();

  static final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: _info,
    builder: (context, snap) => InkWell(
      onTap: () => showLicensePage(
        context: context,
        applicationName: 'NeuralLens',
        applicationVersion: snap.data?.version,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Row(
          children: [
            const NeuralLensLogo(size: 36),
            const SizedBox(width: Space.md + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NeuralLens', style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    snap.hasData
                        ? 'v${snap.data!.version} (${snap.data!.buildNumber})'
                        : 'See beyond the screen.',
                    style: context.mono(size: 11.5),
                  ),
                ],
              ),
            ),
            Text(
              'Licenses',
              style: context.text.labelMedium!.copyWith(
                color: context.nl.textMuted,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.nl.textMuted),
          ],
        ),
      ),
    ),
  );
}
