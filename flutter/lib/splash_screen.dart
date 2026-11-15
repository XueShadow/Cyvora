import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.destination});

  final Widget destination;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              widget.destination,
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.55, 0.45),
                  radius: 1.05,
                  colors: [Color(0xFF0A3440), Color(0xFF041523)],
                ),
              ),
            ),
            CustomPaint(
              painter: _EarthPainter(progress: _animationController.value),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const SizedBox(height: 32),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CyvoraShieldLogo(
                                  size: 202,
                                  isSplash: true,
                                  progress: _animationController.value,
                                ),
                                const SizedBox(height: 9),
                                RichText(
                                  text: const TextSpan(
                                    style: TextStyle(
                                      fontSize: 61,
                                      height: 1,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -2.5,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Cyv',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      TextSpan(
                                        text: 'ora',
                                        style: TextStyle(
                                          color: Color(0xFF34F5AA),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Smarter Protection. Safer Family.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 33),
                                const Text(
                                  'Detect Scams • Protect Your Family\n'
                                  'Keep Your Loved Ones Safe',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFD8E8FF),
                                    height: 1.45,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        painter: _ShieldFamilyPainter(
          scale: size / 100,
          glow: isSplash,
          progress: progress,
        ),
      ),
    );
  }
}

class _EarthPainter extends CustomPainter {
  const _EarthPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final horizonY = size.height * 0.77;
    final earthRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 1.14),
      width: size.width * 1.48,
      height: size.height * 0.76,
    );
    final earth = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A5B50), Color(0xFF041523)],
      ).createShader(earthRect);
    canvas.drawOval(earthRect, earth);

    final glow = Paint()
      ..color = const Color(0xFF34F5AA).withValues(alpha: 0.72)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 1.14),
        width: size.width * 1.50,
        height: size.height * 0.77,
      ),
      math.pi * 1.12,
      math.pi * 0.76,
      false,
      glow,
    );

    final network = Paint()
      ..color = const Color(0xFF86FFD0).withValues(alpha: 0.55)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final stars = <Offset>[
      Offset(size.width * 0.08, horizonY + 36),
      Offset(size.width * 0.20, horizonY + 15),
      Offset(size.width * 0.34, horizonY + 43),
      Offset(size.width * 0.47, horizonY + 7),
      Offset(size.width * 0.61, horizonY + 33),
      Offset(size.width * 0.77, horizonY + 11),
      Offset(size.width * 0.92, horizonY + 39),
    ];
    for (var index = 0; index < stars.length - 1; index++) {
      final path = Path()
        ..moveTo(stars[index].dx, stars[index].dy)
        ..quadraticBezierTo(
          (stars[index].dx + stars[index + 1].dx) / 2,
          horizonY - 17 - 8 * math.sin(progress * math.pi + index),
          stars[index + 1].dx,
          stars[index + 1].dy,
        );
      canvas.drawPath(path, network);
    }

    final nodePaint = Paint()..color = const Color(0xFFDDF8FF);
    for (final point in stars) {
      canvas.drawCircle(point, 2.1, nodePaint);
      canvas.drawCircle(
        point,
        7,
        Paint()
          ..color = const Color(0xFF34F5AA).withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EarthPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ShieldFamilyPainter extends CustomPainter {
  const _ShieldFamilyPainter({
    required this.scale,
    required this.glow,
    required this.progress,
  });

  final double scale;
  final bool glow;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    final shield = Path()
      ..moveTo(50, 5)
      ..cubicTo(62, 13, 75, 17, 91, 20)
      ..lineTo(91, 46)
      ..cubicTo(91, 66, 75, 84, 50, 97)
      ..cubicTo(25, 84, 9, 66, 9, 46)
      ..lineTo(9, 20)
      ..cubicTo(25, 17, 38, 13, 50, 5)
      ..close();
    final shadow = Paint()
      ..color = const Color(0xFF00133B).withValues(alpha: glow ? 0.4 : 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawPath(shield.shift(const Offset(0, 3)), shadow);
    final shieldFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: glow
            ? const [Color(0xFF34E89B), Color(0xFF087D66), Color(0xFF073047)]
            : const [Color(0xFFFBFDFF), Color(0xFFDDEBFF)],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    canvas.drawPath(shield, shieldFill);

    final inset = Path()
      ..moveTo(50, 15)
      ..cubicTo(62, 22, 72, 25, 82, 27)
      ..lineTo(82, 46)
      ..cubicTo(82, 63, 69, 77, 50, 87)
      ..cubicTo(31, 77, 18, 63, 18, 46)
      ..lineTo(18, 27)
      ..cubicTo(28, 25, 38, 22, 50, 15)
      ..close();
    canvas.drawPath(inset, Paint()..color = const Color(0xFFFCFEFF));
    final innerLine = Paint()
      ..color = glow ? const Color(0xFF86FFD0) : const Color(0xFF34E89B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawPath(inset, innerLine);

    final personPaint = Paint()
      ..color = glow ? const Color(0xFF064B49) : const Color(0xFF087D66);
    canvas.drawCircle(const Offset(38, 34), 7.3, personPaint);
    canvas.drawCircle(const Offset(63, 36), 7, personPaint);
    canvas.drawCircle(const Offset(51, 56), 6.5, Paint()..color = _shieldBlue);

    final adults = Path()
      ..moveTo(25, 61)
      ..cubicTo(25, 48, 30, 43, 38, 43)
      ..cubicTo(46, 43, 49, 50, 49, 63)
      ..lineTo(44, 71)
      ..lineTo(28, 71)
      ..close()
      ..moveTo(54, 62)
      ..cubicTo(54, 50, 56, 44, 64, 44)
      ..cubicTo(72, 44, 76, 51, 76, 64)
      ..lineTo(70, 72)
      ..lineTo(55, 72)
      ..close();
    canvas.drawPath(adults, personPaint);

    final child = Path()
      ..moveTo(42, 78)
      ..lineTo(42, 67)
      ..cubicTo(42, 61, 46, 58, 51, 58)
      ..cubicTo(57, 58, 60, 62, 60, 68)
      ..lineTo(60, 80)
      ..lineTo(55, 82)
      ..lineTo(55, 69)
      ..lineTo(52, 69)
      ..lineTo(52, 83)
      ..close();
    canvas.drawPath(
      child,
      Paint()..color = glow ? const Color(0xFF087D66) : const Color(0xFF075C4D),
    );
    final cutout = Paint()
      ..color = const Color(0xFFF9FCFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(46, 67), const Offset(46, 80), cutout);
    canvas.drawLine(const Offset(56, 67), const Offset(56, 80), cutout);

    final badge = Path()
      ..moveTo(81, 57)
      ..lineTo(94, 62)
      ..lineTo(94, 75)
      ..cubicTo(94, 83, 87, 89, 81, 92)
      ..cubicTo(75, 89, 68, 83, 68, 75)
      ..lineTo(68, 62)
      ..close();
    canvas.drawPath(
      badge,
      Paint()
        ..color = const Color(0xFF34F5AA)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      badge,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final check = Path()
      ..moveTo(75, 74)
      ..lineTo(80, 79)
      ..lineTo(88, 69);
    canvas.drawPath(
      check,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  static const _shieldBlue = Color(0xFF087D66);

  @override
  bool shouldRepaint(covariant _ShieldFamilyPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.scale != scale ||
      oldDelegate.glow != glow;
}
