import 'dart:ui';

import 'package:flutter/widgets.dart';

/// Draws a dashed rounded border around [child] (CSS `border: 2px dashed`).
/// Flutter has no built-in dashed border, so we paint it ourselves.
class DashedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dash;
  final double gap;

  const DashedBorder({
    super.key,
    required this.child,
    required this.color,
    this.strokeWidth = 2,
    this.radius = 20,
    this.dash = 6,
    this.gap = 4,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // Painted on top of the child so a filled background can't hide it.
      foregroundPainter: _DashedBorderPainter(color, strokeWidth, radius, dash, gap),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dash;
  final double gap;

  _DashedBorderPainter(this.color, this.strokeWidth, this.radius, this.dash, this.gap);

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    for (final PathMetric metric in (Path()..addRRect(rect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || old.radius != radius;
}
