import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../wearables/models/wearables_models.dart';

/// On-phone rendering of the compact glasses layout (the simulator).
///
/// Mirrors what the native bridge sends to a 600×600 display: a short
/// heading, a few short lines, a dim next cue and progress.
class GlassesCueView extends StatelessWidget {
  const GlassesCueView({super.key, required this.cue});

  final GlassesCue? cue;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: ShapeDecoration(
          color: Colors.black,
          shape: Shapes.of(Radii.lg + 8),
        ),
        // Faint diagonal sheen, like light catching a lens.
        foregroundDecoration: ShapeDecoration(
          shape: Shapes.of(Radii.lg + 8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.center,
            colors: [
              Colors.white.withValues(alpha: 0.07),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            // Scale typography with the simulated display size.
            final unit = box.maxWidth / 600;
            final cue = this.cue;
            if (cue == null) {
              return Center(
                child: Text(
                  'No cards',
                  style: TextStyle(color: Colors.white54, fontSize: 32 * unit),
                ),
              );
            }
            return Padding(
              padding: EdgeInsets.all(44 * unit),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cue.heading.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.accent,
                            fontSize: 26 * unit,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2 * unit,
                          ),
                        ),
                      ),
                      if (cue.paused)
                        Icon(
                          Icons.pause_rounded,
                          color: Colors.white54,
                          size: 30 * unit,
                        ),
                    ],
                  ),
                  const Spacer(),
                  // Lines arrive pre-wrapped for the glasses; shrink any that
                  // run wider in this font instead of overflowing the frame.
                  for (final line in cue.lines)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        line,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40 * unit,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.6 * unit,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (cue.next != null)
                    Text(
                      cue.next!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 24 * unit,
                      ),
                    ),
                  SizedBox(height: 16 * unit),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4 * unit),
                          child: LinearProgressIndicator(
                            value: cue.position / cue.total,
                            minHeight: 6 * unit,
                            color: c.accent,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                      ),
                      SizedBox(width: 16 * unit),
                      Text(
                        '${cue.position}/${cue.total}',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 22 * unit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
