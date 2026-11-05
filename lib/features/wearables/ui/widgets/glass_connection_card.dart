import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/common.dart';
import '../../logic/wearables_cubit.dart';
import '../../models/wearables_models.dart';
import 'glasses_glyph.dart';

extension WearablesStatusUi on WearablesState {
  String get label => switch (status) {
    WearablesStatus.unsupported => 'Not available on this device',
    WearablesStatus.initializing => 'Starting…',
    WearablesStatus.unregistered => 'Not set up',
    WearablesStatus.registering => 'Waiting for Meta AI approval',
    WearablesStatus.disconnected => 'Not connected',
    WearablesStatus.connecting => 'Connecting…',
    WearablesStatus.connected =>
      deviceName == null ? 'Connected' : 'Connected · $deviceName',
    WearablesStatus.error => 'Connection problem',
  };

  Color color(NeuralLensColors c) => switch (status) {
    WearablesStatus.connected => c.accentText,
    WearablesStatus.error => c.danger,
    WearablesStatus.connecting ||
    WearablesStatus.registering ||
    WearablesStatus.initializing => c.warning,
    _ => c.textMuted,
  };

  /// In-progress states get a breathing status dot.
  bool get isBusy =>
      status == WearablesStatus.connecting ||
      status == WearablesStatus.registering ||
      status == WearablesStatus.initializing;

  IconData get icon => switch (status) {
    WearablesStatus.connected => Icons.visibility_rounded,
    WearablesStatus.error => Icons.error_outline_rounded,
    WearablesStatus.unsupported => Icons.visibility_off_outlined,
    _ => Icons.visibility_outlined,
  };
}

/// Compact, honest glasses status. Reflects only SDK-reported state.
class GlassConnectionCard extends StatelessWidget {
  const GlassConnectionCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return BlocBuilder<WearablesCubit, WearablesState>(
      builder: (context, s) => SurfaceCard(
        onTap: onTap,
        highlighted: s.isConnected,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 44,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: s.color(c).withValues(alpha: 0.1),
                shape: Shapes.of(
                  Radii.sm,
                  side: BorderSide(color: s.color(c).withValues(alpha: 0.18)),
                ),
              ),
              child: GlassesGlyph(
                color: s.color(c),
                width: 40,
                lit: s.canShowCues,
              ),
            ),
            const SizedBox(width: Space.md + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Meta glasses', style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  _StatusLine(state: s),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Tall bento tile for the home screen.
class GlassesBentoTile extends StatelessWidget {
  const GlassesBentoTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return BlocBuilder<WearablesCubit, WearablesState>(
      builder: (context, s) => SurfaceCard(
        onTap: onTap,
        highlighted: s.isConnected,
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GLASSES', style: context.text.labelSmall),
            Expanded(
              child: Center(
                child: GlassesGlyph(
                  color: s.isConnected ? s.color(c) : c.textSecondary,
                  width: 96,
                  lit: s.canShowCues,
                ),
              ),
            ),
            Text('Meta Ray-Ban', style: context.text.titleSmall),
            const SizedBox(height: 2),
            _StatusLine(state: s, maxLines: 2),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state, this.maxLines = 1});

  final WearablesState state;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: const Offset(-4, -2),
          child: StatusDot(color: state.color(c), pulse: state.isBusy, size: 7),
        ),
        Expanded(
          child: Text(
            state.label,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall!.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}
