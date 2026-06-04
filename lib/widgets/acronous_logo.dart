import 'package:flutter/material.dart';

class AcronousLogo extends StatelessWidget {
  final double size;
  final bool showGlow;

  const AcronousLogo({
    super.key,
    this.size = 24,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: Image.asset(
        'assets/images/Acronous_Ai_svj_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8EF9FF), Color(0xFF1F6FFF)],
              ),
              borderRadius: BorderRadius.circular(size * 0.18),
            ),
            child: Icon(
              Icons.auto_awesome,
              size: size * 0.58,
              color: Colors.white,
            ),
          );
        },
      ),
    );

    if (!showGlow) return icon;

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF29D3FF).withValues(alpha: 0.28),
            blurRadius: size * 0.4,
            spreadRadius: size * 0.04,
          ),
        ],
      ),
      child: icon,
    );
  }
}
