import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Springy scale-down feedback for anything tappable.
///
/// Listens to raw pointer events, so it composes with an [InkWell] or
/// [GestureDetector] inside [child] without stealing gestures.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.97,
  });

  final Widget child;
  final bool enabled;

  /// Scale while pressed.
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: Motion.medium,
  );
  late final _scale = Tween<double>(begin: 1, end: widget.scale).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Motion.spring,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent _) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward();
  }

  void _up([PointerEvent? _]) {
    if (_controller.status != AnimationStatus.dismissed) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerUp: _up,
    onPointerCancel: _up,
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}
