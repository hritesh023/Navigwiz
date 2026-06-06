import 'package:flutter/material.dart';

class AcronousLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showGlow;

  const AcronousLogo({
    super.key,
    this.size = 24.0,
    this.color,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AcronousLogoPainter(
          color: iconColor,
          showGlow: showGlow,
        ),
      ),
    );
  }
}

class _AcronousLogoPainter extends CustomPainter {
  final Color color;
  final bool showGlow;

  _AcronousLogoPainter({
    required this.color,
    this.showGlow = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * 2, glowPaint);
    }

    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, circlePaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'A',
        style: TextStyle(
          color: Colors.white,
          fontSize: size.width * 0.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => oldDelegate != this;
}
