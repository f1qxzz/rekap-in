
import 'package:flutter/material.dart';

class RekapInLogo extends StatelessWidget {
  const RekapInLogo({
    this.size = 64,
    this.showText = true,
    this.darkMode = false,
    super.key,
  });

  final double size;
  final bool showText;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _LogoPainter(darkMode: darkMode),
          ),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.1),
          Text(
            'REKAP',
            style: TextStyle(
              fontSize: size * 0.28,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: darkMode ? Colors.white : const Color(0xFF272130),
            ),
          ),
          Text(
            'IN',
            style: TextStyle(
              fontSize: size * 0.18,
              fontWeight: FontWeight.w400,
              letterSpacing: 8,
              color: (darkMode ? Colors.white : const Color(0xFF272130))
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({this.darkMode = false});

  final bool darkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF7E22CE), Color(0xFFA855F7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Rounded square background (22% corner radius)
    final cornerRadius = Radius.circular(radius * 0.44);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCircle(center: center, radius: radius),
      cornerRadius,
    );
    canvas.drawRRect(rrect, bgPaint);

    // Clock circle
    final clockRadius = radius * 0.625;
    final clockPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, clockRadius, clockPaint);

    // Clock tick marks (12, 3, 6, 9 o'clock)
    final tickPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025
      ..strokeCap = StrokeCap.round;

    final tickInner = clockRadius * 0.81;
    final tickOuter = clockRadius * 0.94;

    // Top (12)
    canvas.drawLine(
      Offset(center.dx, center.dy - tickInner),
      Offset(center.dx, center.dy - tickOuter),
      tickPaint,
    );
    // Right (3)
    canvas.drawLine(
      Offset(center.dx + tickInner, center.dy),
      Offset(center.dx + tickOuter, center.dy),
      tickPaint,
    );
    // Bottom (6)
    canvas.drawLine(
      Offset(center.dx, center.dy + tickInner),
      Offset(center.dx, center.dy + tickOuter),
      tickPaint,
    );
    // Left (9)
    canvas.drawLine(
      Offset(center.dx - tickInner, center.dy),
      Offset(center.dx - tickOuter, center.dy),
      tickPaint,
    );

    // Checkmark (matching Gemini's path: M 190 260 L 240 310 L 330 200)
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.047
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path();
    checkPath.moveTo(center.dx - radius * 0.258, center.dy + radius * 0.016);
    checkPath.lineTo(center.dx - radius * 0.063, center.dy + radius * 0.215);
    checkPath.lineTo(center.dx + radius * 0.289, center.dy - radius * 0.221);
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.darkMode != darkMode;
}
