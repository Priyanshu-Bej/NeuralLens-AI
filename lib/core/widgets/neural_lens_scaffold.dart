import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'common.dart';

/// Page scaffold with a collapsing large title and consistent gutters.
///
/// Pass [slivers] for scrollable pages or [body] for custom layouts.
class NeuralLensScaffold extends StatelessWidget {
  const NeuralLensScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.slivers,
    this.body,
    this.bottom,
    this.largeTitle = true,
    this.aurora = false,
  }) : assert(slivers != null || body != null);

  final String? title;

  /// Small monospaced line under the large title (e.g. a count).
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget>? slivers;
  final Widget? body;

  /// Pinned content below the scroll area (e.g. a primary action bar).
  final Widget? bottom;
  final bool largeTitle;

  /// Paints a soft accent glow behind the header.
  final bool aurora;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final Widget content;
    if (slivers != null) {
      content = Builder(
        // Inside the Scaffold, so bottom padding includes [bottom] and any
        // floating navigation the body extends behind.
        builder: (context) => CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            if (title != null || actions.isNotEmpty || canPop)
              SliverPersistentHeader(
                pinned: true,
                delegate: _LargeTitleHeader(
                  title: title,
                  subtitle: subtitle,
                  actions: actions,
                  canPop: canPop,
                  large: largeTitle && title != null,
                  topInset: MediaQuery.paddingOf(context).top,
                ),
              ),
            ...slivers!,
            SliverToBoxAdapter(
              child: SizedBox(
                height: Space.xxl + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      );
    } else {
      content = SafeArea(bottom: bottom == null, child: body!);
    }

    return Scaffold(
      extendBody: bottom != null,
      appBar: slivers == null && (title != null || canPop)
          ? AppBar(
              title: title == null ? null : Text(title!),
              actions: [
                ...actions,
                const SizedBox(width: Space.sm),
              ],
            )
          : null,
      body: Stack(
        children: [
          if (aurora)
            const Positioned(
              top: -140,
              left: -40,
              right: -40,
              height: 420,
              child: AuroraGlow(intensity: 0.8),
            ),
          Positioned.fill(child: content),
        ],
      ),
      bottomNavigationBar: bottom == null ? null : _BottomBar(child: bottom!),
    );
  }
}

/// Fades content out beneath a pinned action area.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bg = context.nl.background;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.35],
          colors: [bg.withValues(alpha: 0), bg],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Space.gutter,
            Space.xl,
            Space.gutter,
            Space.md + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _LargeTitleHeader extends SliverPersistentHeaderDelegate {
  _LargeTitleHeader({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.canPop,
    required this.large,
    required this.topInset,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final bool canPop;
  final bool large;
  final double topInset;

  static const _bar = 60.0;

  double get _largeHeight => large ? (subtitle == null ? 62 : 84) : 0;

  @override
  double get minExtent => topInset + _bar;

  @override
  double get maxExtent => topInset + _bar + _largeHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final c = context.nl;
    final range = maxExtent - minExtent;
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    // Glass fades in as content slides underneath the bar. A fixed-height
    // bar never reports [overlaps], so derive it from the scroll offset.
    final under = shrinkOffset - range * 0.6;
    final g = overlaps
        ? 1.0
        : (under / (range * 0.4).clamp(12.0, double.infinity)).clamp(0.0, 1.0);
    final smallTitle = large ? ((t - 0.75) / 0.25).clamp(0.0, 1.0) : 1.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (g > 0)
          ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20 * g, sigmaY: 20 * g),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.background.withValues(alpha: 0.78 * g),
                  border: Border(
                    bottom: BorderSide(
                      color: c.border.withValues(alpha: c.border.a * g),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: topInset,
          left: 0,
          right: 0,
          height: _bar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Row(
              children: [
                if (canPop) ...[
                  CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: Space.md),
                ] else
                  // Aligns the collapsed title with the page gutter.
                  const SizedBox(width: Space.gutter - Space.md),
                Expanded(
                  child: Opacity(
                    opacity: smallTitle,
                    child: Text(
                      title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium,
                    ),
                  ),
                ),
                ...actions,
              ],
            ),
          ),
        ),
        if (large)
          Positioned(
            left: Space.gutter,
            right: Space.gutter,
            bottom: Space.sm + 2,
            child: Opacity(
              opacity: (1 - t * 1.6).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -12 * t),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.displaySmall,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: Space.xs),
                      Text(subtitle!, style: context.mono(size: 12)),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  bool shouldRebuild(_LargeTitleHeader old) =>
      old.title != title ||
      old.subtitle != subtitle ||
      old.actions != actions ||
      old.canPop != canPop ||
      old.large != large ||
      old.topInset != topInset;
}

/// Horizontal page padding helper for slivers.
class SliverGutter extends StatelessWidget {
  const SliverGutter({super.key, required this.sliver});

  final Widget sliver;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
    sliver: sliver,
  );
}
