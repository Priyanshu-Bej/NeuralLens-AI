import 'package:flutter/material.dart';

/// Line drawing of a pair of smart glasses. When [lit], the right lens
/// shows a small heads-up display glow in [color].
class GlassesGlyph extends StatelessWidget {
  const GlassesGlyph({
    super.key,
    required this.color,
    this.width = 120,
    this.lit = false,
    this.stroke,
  });

  final Color color;
  final double width;
  final bool lit;

  /// Frame stroke width; scales with [width] by default.
  final double? stroke;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width * 0.42,
    child: CustomPaint(
      painter: _GlassesPainter(
        color: color,
        lit: lit,
        stroke: stroke ?? width * 0.035,
      ),
    ),
  );
}

class _GlassesPainter extends CustomPainter {
  _GlassesPainter({
    required this.color,
    required this.lit,
    required this.stroke,
  });

  final Color color;
  final bool lit;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final frame = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final lensW = w * 0.38;
    final lensH = h * 0.72;
    final top = h * 0.2;
    final left = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.07, top, lensW, lensH),
      topLeft: Radius.circular(lensH * 0.28),
      topRight: Radius.circular(lensH * 0.28),
      bottomLeft: Radius.circular(lensH * 0.5),
      bottomRight: Radius.circular(lensH * 0.42),
    );
    final right = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.55, top, lensW, lensH),
      topLeft: Radius.circular(lensH * 0.28),
      topRight: Radius.circular(lensH * 0.28),
      bottomLeft: Radius.circular(lensH * 0.42),
      bottomRight: Radius.circular(lensH * 0.5),
    );

    // Lens tint.
    final tint = Paint()..color = color.withValues(alpha: 0.08);
    canvas
      ..drawRRect(left, tint)
      ..drawRRect(right, tint);

    if (lit) {
      final hud = right.outerRect.deflate(lensW * 0.18);
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
        ).createShader(hud.inflate(lensW * 0.2));
      canvas.drawRRect(right, glow);
      final line = Paint()
        ..color = color
        ..strokeWidth = stroke * 0.8
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawLine(
          Offset(hud.left, hud.center.dy - stroke * 1.4),
          Offset(hud.right, hud.center.dy - stroke * 1.4),
          line,
        )
        ..drawLine(
          Offset(hud.left, hud.center.dy + stroke * 1.4),
          Offset(hud.left + hud.width * 0.6, hud.center.dy + stroke * 1.4),
          line..color = color.withValues(alpha: 0.6),
        );
    }

    canvas
      ..drawRRect(left, frame)
      ..drawRRect(right, frame);

    // Bridge.
    final bridge = Path()
      ..moveTo(w * 0.45, top + lensH * 0.22)
      ..quadraticBezierTo(
        w * 0.5,
        top - lensH * 0.04,
        w * 0.55,
        top + lensH * 0.22,
      );
    canvas.drawPath(bridge, frame);

    // Temples.
    canvas
      ..drawLine(
        Offset(w * 0.07, top + lensH * 0.12),
        Offset(0, top + lensH * 0.02),
        frame,
      )
      ..drawLine(
        Offset(w * 0.93, top + lensH * 0.12),
        Offset(w, top + lensH * 0.02),
        frame,
      );
  }

  @override
  bool shouldRepaint(_GlassesPainter old) =>
      old.color != color || old.lit != lit || old.stroke != stroke;
}
