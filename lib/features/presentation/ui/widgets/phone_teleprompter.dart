import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../scripts/models/cue.dart';
import '../../models/presentation_settings.dart';

/// Scrolling phone teleprompter.
///
/// Each cue is its own block keyed by index so the screen can map scroll
/// position to cues (and back) without measuring text.
class PhoneTeleprompter extends StatelessWidget {
  const PhoneTeleprompter({
    super.key,
    required this.cues,
    required this.currentIndex,
    required this.settings,
    required this.controller,
    required this.cueKeys,
    required this.viewportKey,
    required this.onScroll,
  });

  /// Fraction of the viewport height where the active line sits.
  static const readingLine = 0.32;

  final List<Cue> cues;
  final int currentIndex;
  final PresentationSettings settings;
  final ScrollController controller;
  final List<GlobalKey> cueKeys;
  final GlobalKey viewportKey;
  final VoidCallback onScroll;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final textStyle = TextStyle(
      fontSize: settings.fontSize,
      height: 1.42,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: c.textPrimary,
    );
    return LayoutBuilder(
      key: viewportKey,
      builder: (context, box) {
        final content = NotificationListener<ScrollNotification>(
          onNotification: (_) {
            onScroll();
            return false;
          },
          child: SingleChildScrollView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              Space.xl,
              box.maxHeight * readingLine,
              Space.xl,
              box.maxHeight * (1 - readingLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cues.length; i++) ...[
                  if (i == 0 ||
                      cues[i].sectionIndex != cues[i - 1].sectionIndex)
                    Padding(
                      padding: EdgeInsets.only(
                        top: i == 0 ? 0 : settings.fontSize * 0.9,
                        bottom: Space.sm,
                      ),
                      child: Text(
                        cues[i].heading.toUpperCase(),
                        style: context.text.labelSmall!.copyWith(
                          color: c.accentText,
                          fontSize: (settings.fontSize * 0.36).clamp(11, 20),
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  AnimatedOpacity(
                    key: cueKeys[i],
                    duration: Motion.medium,
                    opacity: i < currentIndex
                        ? 0.32
                        : (i == currentIndex ? 1 : 0.82),
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: settings.fontSize * 0.45,
                      ),
                      child: Text(cues[i].text, style: textStyle),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
        return Stack(
          children: [
            Positioned.fill(
              // Text dissolves toward the edges so the eye stays on the
              // reading line.
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.14, 0.78, 1],
                  colors: [
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                ).createShader(rect),
                child: settings.mirror
                    ? Transform.flip(flipX: true, child: content)
                    : content,
              ),
            ),
            // Reading-line marker.
            Positioned(
              left: 0,
              top: box.maxHeight * readingLine + settings.fontSize * 0.2,
              child: IgnorePointer(
                child: Container(
                  width: 4,
                  height: settings.fontSize * 1.1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [c.accent, c.accent2],
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.7),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
