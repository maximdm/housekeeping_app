import 'package:flutter/material.dart';

class BackgroundTexture extends StatelessWidget {
  final Widget child;
  final Color? dotColor;

  const BackgroundTexture({
    super.key,
    required this.child,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = dotColor ??
        Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3);

    return CustomPaint(
      painter: _DotPatternPainter(color),
      child: child,
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  final Color color;

  _DotPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    const spacing = 24.0;
    const radius = 0.8;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPatternPainter oldDelegate) =>
      color != oldDelegate.color;
}
