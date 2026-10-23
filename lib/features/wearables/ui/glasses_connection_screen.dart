import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neural_lens_button.dart';
import '../../../core/widgets/neural_lens_scaffold.dart';
import '../../presentation/models/presentation_settings.dart';
import '../../scripts/data/script_repository.dart';
import '../../scripts/logic/library_cubit.dart';
import '../../scripts/models/script_enums.dart';
import '../logic/wearables_cubit.dart';
import '../models/wearables_models.dart';
import 'widgets/glass_connection_card.dart';
import 'widgets/glasses_glyph.dart';

class GlassesConnectionScreen extends StatelessWidget {
  const GlassesConnectionScreen({super.key});

  Future<void> _openSimulator(BuildContext context) async {
    final scripts = context
        .read<LibraryCubit>()
        .state
        .scripts
        .where((s) => s.kind == ScriptKind.script && s.body.trim().isNotEmpty)
        .toList();
    var id = scripts.firstOrNull?.id;
    if (id == null) {
      final create = await confirmDialog(
        context,
        title: 'No scripts yet',
        message:
            'Create a short sample script to try the glasses simulator? You can '
            'edit or delete it later.',
        confirmLabel: 'Create sample',
      );
      if (!create || !context.mounted) return;
      final repo = context.read<ScriptRepository>();
      final sample = await repo.save(
        repo.draft(
          title: 'Sample: NeuralLens tour',
          body: _sampleBody,
          format: ScriptFormat.presentation,
        ),
      );
      id = sample.id;
    }
    if (context.mounted) {
      await context.push(Routes.present(id, mode: PresentationMode.glasses));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WearablesCubit>();
    return BlocBuilder<WearablesCubit, WearablesState>(
      builder: (context, s) => NeuralLensScaffold(
        title: 'Glasses',
        largeTitle: false,
        aurora: true,
        slivers: [
          SliverGutter(
            sliver: SliverList.list(
              children: [
                _StatusHero(state: s),
                const SizedBox(height: Space.xl),
                ..._actions(context, cubit, s),
                if (s.isConnected) ...[
                  const SectionHeader(title: 'Capabilities'),
                  Row(
                    children: [
                      Expanded(
                        child: _CapabilityTile(
                          icon: Icons.crop_square_rounded,
                          label: 'Display',
                          value: s.displayAvailable
                              ? 'Ready'
                              : 'Not available yet',
                          ok: s.displayAvailable,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: _CapabilityTile(
                          icon: Icons.watch_outlined,
                          label: 'Neural Band',
                          value: switch (s.inputs) {
                            InputsAvailability.available => 'Active',
                            InputsAvailability.denied => 'Not enabled',
                            InputsAvailability.unavailable => 'Unavailable',
                            InputsAvailability.unknown => 'Starting…',
                          },
                          ok: s.inputs == InputsAvailability.available,
                        ),
                      ),
                    ],
                  ),
                ],
                const SectionHeader(title: 'Simulator'),
                _SimulatorCard(onOpen: () => _openSimulator(context)),
                const SectionHeader(title: 'Setup'),
                const _SetupSteps(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    WearablesCubit cubit,
    WearablesState s,
  ) {
    Widget primary(
      String label,
      IconData icon,
      VoidCallback? onPressed, {
      bool loading = false,
    }) => NeuralLensButton(
      label: label,
      icon: icon,
      expand: true,
      loading: loading,
      onPressed: onPressed,
    );
    Widget secondary(String label, VoidCallback onPressed) => Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: NeuralLensButton.ghost(
        label: label,
        expand: true,
        onPressed: onPressed,
      ),
    );

    return switch (s.status) {
      WearablesStatus.unsupported => const [],
      WearablesStatus.initializing => [
        primary(
          'Starting…',
          Icons.hourglass_empty_rounded,
          null,
          loading: true,
        ),
      ],
      WearablesStatus.unregistered => [
        primary('Connect with Meta AI', Icons.link_rounded, cubit.register),
      ],
      WearablesStatus.registering => [
        primary(
          'Waiting for approval…',
          Icons.hourglass_empty_rounded,
          null,
          loading: true,
        ),
        secondary('Open Meta AI again', cubit.register),
      ],
      WearablesStatus.disconnected => [
        primary('Connect glasses', Icons.visibility_rounded, cubit.connect),
        secondary('Remove app registration', cubit.unregister),
      ],
      WearablesStatus.connecting => [
        primary(
          'Connecting…',
          Icons.hourglass_empty_rounded,
          null,
          loading: true,
        ),
      ],
      WearablesStatus.connected => [
        NeuralLensButton.secondary(
          label: 'Disconnect',
          icon: Icons.link_off_rounded,
          expand: true,
          onPressed: cubit.disconnect,
        ),
      ],
      // Registering again while already registered breaks the SDK, so the
      // error state offers a repair (unregister, then register once) instead.
      WearablesStatus.error when s.needsRepair => [
        primary('Repair connection', Icons.build_rounded, cubit.repair),
        secondary('Try again', cubit.connect),
      ],
      WearablesStatus.error => [
        primary('Try again', Icons.refresh_rounded, cubit.connect),
        secondary('Repair connection', cubit.repair),
      ],
    };
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.state});

  final WearablesState state;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final color = state.color(c);
    final explanation = switch (state.status) {
      WearablesStatus.unsupported =>
        'Meta glasses integration is available on Android only in this version.',
      WearablesStatus.unregistered =>
        'Link NeuralLens with the Meta AI app to show cards on Meta Ray-Ban '
            'Display glasses.',
      WearablesStatus.registering =>
        'Approve NeuralLens in the Meta AI app, then return here.',
      WearablesStatus.disconnected =>
        'Registered with Meta AI. Wear your glasses and connect to start a session.',
      WearablesStatus.connecting => 'Starting a session with your glasses…',
      WearablesStatus.connected =>
        state.displayAvailable
            ? 'Cards will appear on your glasses in Glasses mode.'
            : 'Connected. Waiting for the display to become available.',
      WearablesStatus.error => 'Something went wrong talking to the glasses.',
      WearablesStatus.initializing => 'Checking the Meta Wearables SDK…',
    };
    return Column(
      children: [
        const SizedBox(height: Space.md),
        _DeviceHalo(
          color: state.isConnected || state.isBusy ? color : c.textSecondary,
          glow: color,
          lit: state.canShowCues,
          active: state.isBusy,
        ),
        const SizedBox(height: Space.lg),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusDot(color: color, pulse: state.isBusy),
            const SizedBox(width: Space.xs),
            Flexible(
              child: Text(
                state.label,
                textAlign: TextAlign.center,
                style: context.text.headlineSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            explanation,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium,
          ),
        ),
        if (state.message != null) ...[
          const SizedBox(height: Space.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.sm,
            ),
            decoration: ShapeDecoration(
              color:
                  (state.status == WearablesStatus.error
                          ? c.danger
                          : c.textSecondary)
                      .withValues(alpha: 0.08),
              shape: Shapes.of(Radii.sm),
            ),
            child: Text(
              state.message!,
              textAlign: TextAlign.center,
              style: context.mono(
                size: 11.5,
                color: state.status == WearablesStatus.error
                    ? c.danger
                    : c.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Glasses illustration inside soft concentric rings. Rings ripple outward
/// while a connection step is in progress.
class _DeviceHalo extends StatefulWidget {
  const _DeviceHalo({
    required this.color,
    required this.glow,
    required this.lit,
    required this.active,
  });

  final Color color;
  final Color glow;
  final bool lit;
  final bool active;

  @override
  State<_DeviceHalo> createState() => _DeviceHaloState();
}

class _DeviceHaloState extends State<_DeviceHalo>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_DeviceHalo old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.active && !MediaQuery.disableAnimationsOf(context);
    if (run && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!run && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return SizedBox(
      height: 200,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          Widget ring(double base, double alpha) {
            final t = (_controller.value + base) % 1;
            final size = widget.active ? 120 + 90 * t : 120 + 90 * base;
            final a = widget.active ? alpha * (1 - t) : alpha;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: widget.glow.withValues(alpha: a)),
              ),
            );
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.glow.withValues(alpha: 0.18),
                      widget.glow.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              ring(0, 0.18),
              ring(0.5, 0.1),
              ring(0.9, 0.06),
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.surfaceHigh, c.surface],
                  ),
                  border: Border.all(color: c.borderStrong),
                ),
              ),
              child!,
            ],
          );
        },
        child: GlassesGlyph(color: widget.color, width: 96, lit: widget.lit),
      ),
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: icon,
                color: ok ? c.accentText : c.textMuted,
                size: 36,
              ),
              const Spacer(),
              StatusDot(color: ok ? c.accentText : c.textMuted, size: 7),
            ],
          ),
          const SizedBox(height: Space.lg),
          Text(label, style: context.text.titleSmall),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall!.copyWith(
              color: ok ? c.accentText : c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimulatorCard extends StatelessWidget {
  const _SimulatorCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _MiniDisplay(),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Presentation simulator',
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      'Preview the compact glasses layout on your phone. '
                      'Works without glasses and never reports a connection.',
                      style: context.text.bodySmall!.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          NeuralLensButton.secondary(
            label: 'Try presentation simulator',
            icon: Icons.play_arrow_rounded,
            compact: true,
            expand: true,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}

/// Tiny rendition of the 600×600 glasses display.
class _MiniDisplay extends StatelessWidget {
  const _MiniDisplay();

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    Widget bar(double w, double alpha) => Container(
      width: w,
      height: 4,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(2),
      ),
    );
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        color: Colors.black,
        shape: Shapes.of(16, side: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 3,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Spacer(),
          bar(48, 0.9),
          bar(40, 0.9),
          bar(30, 0.35),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: 0.4,
              minHeight: 3,
              color: c.accent,
              backgroundColor: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupSteps extends StatelessWidget {
  const _SetupSteps();

  static const _steps = [
    (
      'Get the hardware',
      'Use Meta Ray-Ban Display glasses with up-to-date firmware and the latest '
          'Meta AI app on this phone.',
    ),
    (
      'Enable Developer Mode',
      'In the Meta AI app, open App Info and tap the app version five times '
          '(needed for development builds).',
    ),
    (
      'Link NeuralLens',
      'Tap "Connect with Meta AI" above and approve NeuralLens in Meta AI.',
    ),
    (
      'Connect and present',
      'Wear the glasses, tap "Connect glasses", then present in Glasses mode.',
    ),
    (
      'Optional: Neural Band',
      'Band input requires Inputs to be enabled for this app in the Meta '
          'Wearables Developer Center. On-screen controls always work.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.lg + 2,
        Space.lg,
        Space.sm,
      ),
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.accentSoft,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c.accentText.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: context.mono(
                            size: 12,
                            color: c.accentText,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (i < _steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: c.borderStrong,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: Space.md + 2),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 4,
                        bottom: Space.lg + 2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_steps[i].$1, style: context.text.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            _steps[i].$2,
                            style: context.text.bodySmall!.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

const _sampleBody = '''## Hook
Ever lost your place while speaking? NeuralLens keeps your words right where you need them.

## How it works
Write a script, or let AI draft one from your notes. Then present it on your phone, or as short cards on your glasses.

## Close
Try advancing this card with the controls below. That's it. You're ready to present.''';
