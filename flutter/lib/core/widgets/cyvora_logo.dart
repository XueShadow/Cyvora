import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/cyvora_theme.dart';

/// Glowing shield mark with a “C”, matching the Cyvora reference.
class CyvoraShieldLogo extends StatelessWidget {
  const CyvoraShieldLogo({
    super.key,
    required this.size,
    this.isSplash = false,
    this.progress = 0,
  });

  final double size;
  final bool isSplash;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShieldMarkPainter(glow: isSplash, progress: progress),
      ),
    );
  }
}

class _ShieldMarkPainter extends CustomPainter {
  const _ShieldMarkPainter({required this.glow, required this.progress});

  final bool glow;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);

    final pulse = 0.55 + 0.45 * math.sin(progress * math.pi * 2);
    if (glow) {
      final halo = Paint()
        ..color = CyvoraColors.electric.withValues(alpha: 0.28 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(const Offset(50, 52), 42, halo);
    }

    final shield = Path()
      ..moveTo(50, 6)
      ..cubicTo(68, 14, 82, 18, 90, 22)
      ..lineTo(90, 48)
      ..cubicTo(90, 68, 74, 84, 50, 96)
      ..cubicTo(26, 84, 10, 68, 10, 48)
      ..lineTo(10, 22)
      ..cubicTo(18, 18, 32, 14, 50, 6)
      ..close();

    canvas.drawPath(
      shield.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      shield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC084FC), Color(0xFF7C3AED), Color(0xFF5B21B6)],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );
    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFE9D5FF).withValues(alpha: 0.7),
    );

    final letter = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    canvas.drawArc(
      const Rect.fromLTWH(32, 30, 36, 40),
      math.pi * 0.55,
      math.pi * 1.9,
      false,
      letter,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShieldMarkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.glow != glow;
}
