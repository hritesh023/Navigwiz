import 'package:flutter/material.dart';

class SaturnLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showGlow;
  final bool animated;

  const SaturnLogo({
    super.key,
    this.size = 24.0,
    this.color,
    this.showGlow = false,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget logoWidget = Image.asset(
      'assets/images/navigwiz_logo_192.png',
      width: size,
      height: size,
      cacheWidth: (size * 2).ceil(),
      cacheHeight: (size * 2).ceil(),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _SaturnLogoPainter(showGlow: showGlow),
        ),
      ),
    );

    if (animated) {
      return TweenAnimationBuilder<double>(
        duration: const Duration(seconds: 2),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.rotate(
            angle: value * 2 * 3.14159,
            child: child,
          );
        },
        child: logoWidget,
      );
    }

    return logoWidget;
  }
}

class _SaturnLogoPainter extends CustomPainter {
  final bool showGlow;

  _SaturnLogoPainter({
    this.showGlow = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;
    final ringRadius = size.width * 0.45;
    final ringThickness = size.width * 0.12;

    // Draw glow effect if enabled
    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, radius * 2.5, glowPaint);
    }

    // Draw the purple ring (outer ring with darker purple outline)
    final ringPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF8B5CF6), // Purple
          Color(0xFF7C3AED), // Darker purple
          Color(0xFF6D28D9), // Darkest purple
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: ringRadius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringThickness;

    canvas.drawCircle(center, ringRadius, ringPaint);

    // Draw darker purple outline for the ring
    final ringOutlinePaint = Paint()
      ..color = const Color(0xFF4C1D95) // Very dark purple
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringThickness * 0.3;

    canvas.drawCircle(center, ringRadius, ringOutlinePaint);

    // Draw the black planet
    final planetPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        radius: 0.8,
        colors: [
          Colors.black26, // Light edge
          Colors.black87, // Mid tone
          Colors.black, // Dark center
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, planetPaint);

    // Add subtle highlight on the planet
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(center.dx - radius * 0.4, center.dy - radius * 0.4),
      radius * 0.2,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}
