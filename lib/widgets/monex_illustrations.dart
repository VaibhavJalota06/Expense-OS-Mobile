import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

typedef ExpenseOSIllustration = MonexIllustration;

class MonexIllustration extends StatelessWidget {
  final int index; // 0 = Note Down, 1 = Money Management, 2 = Track & Analyze, 3 = Password Updated
  final double width;
  final double height;

  const MonexIllustration({
    super.key,
    required this.index,
    this.width = 240,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _IllustrationPainter(type: index),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  final int type;

  _IllustrationPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final bluePaint = Paint()
      ..color = AppTheme.monexBlue
      ..style = PaintingStyle.fill;

    final darkPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final outlineWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final softBluePaint = Paint()
      ..color = AppTheme.monexBlue.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    if (type == 0) {
      // 1. "Note Down Expenses"
      // Backdrop Blue Cloud Shape
      final path = Path();
      path.addOval(Rect.fromCenter(center: center, width: w * 0.85, height: h * 0.8));
      canvas.drawPath(path, bluePaint);

      // Dark Figure taking notes
      canvas.drawCircle(Offset(w * 0.45, h * 0.35), w * 0.14, darkPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(w * 0.45, h * 0.65), width: w * 0.45, height: h * 0.45),
          const Radius.circular(24),
        ),
        darkPaint,
      );

      // Floating Note Paper
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(w * 0.68, h * 0.55), width: w * 0.32, height: h * 0.4),
          const Radius.circular(12),
        ),
        whitePaint,
      );
      // Lines on paper
      final linePaint = Paint()
        ..color = AppTheme.monexBlue
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(w * 0.58, h * 0.45), Offset(w * 0.78, h * 0.45), linePaint);
      canvas.drawLine(Offset(w * 0.58, h * 0.53), Offset(w * 0.75, h * 0.53), linePaint);
      canvas.drawLine(Offset(w * 0.58, h * 0.61), Offset(w * 0.70, h * 0.61), linePaint);

      // Floating Dollar Coins & Sparkles
      _drawCoin(canvas, Offset(w * 0.25, h * 0.25), w * 0.08, whitePaint, bluePaint);
      _drawCoin(canvas, Offset(w * 0.80, h * 0.30), w * 0.06, whitePaint, bluePaint);
      _drawSparkle(canvas, Offset(w * 0.2, h * 0.65), 10, whitePaint);
      _drawSparkle(canvas, Offset(w * 0.8, h * 0.75), 12, whitePaint);
    } else if (type == 1) {
      // 2. "Simple Money Management"
      // Backdrop Blue Circle
      canvas.drawCircle(center, w * 0.42, bluePaint);

      // Dark Figure with alert eyes
      canvas.drawCircle(Offset(w * 0.5, h * 0.45), w * 0.2, darkPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(w * 0.5, h * 0.75), width: w * 0.55, height: h * 0.4),
          const Radius.circular(28),
        ),
        darkPaint,
      );

      // Alert Eye shapes on figure
      _drawEye(canvas, Offset(w * 0.43, h * 0.43), w * 0.06);
      _drawEye(canvas, Offset(w * 0.57, h * 0.43), w * 0.06);

      // Money Bag in hand
      canvas.drawCircle(Offset(w * 0.22, h * 0.55), w * 0.12, darkPaint);
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.18, h * 0.45)
          ..lineTo(w * 0.26, h * 0.45)
          ..lineTo(w * 0.24, h * 0.42)
          ..lineTo(w * 0.20, h * 0.42)
          ..close(),
        whitePaint,
      );
      // Small dollar on bag
      _drawSparkle(canvas, Offset(w * 0.22, h * 0.55), 6, whitePaint);

      // Warning / Notification badges around
      _drawBell(canvas, Offset(w * 0.78, h * 0.32), w * 0.12, whitePaint, bluePaint);
    } else if (type == 2) {
      // 3. "Easy to Track and Analyze"
      // Backdrop Blue Shape
      canvas.drawCircle(center, w * 0.42, bluePaint);

      // Growth Mountain / Chart polygon
      final mountainPath = Path();
      mountainPath.moveTo(w * 0.1, h * 0.85);
      mountainPath.lineTo(w * 0.45, h * 0.45);
      mountainPath.lineTo(w * 0.65, h * 0.6);
      mountainPath.lineTo(w * 0.9, h * 0.3);
      mountainPath.lineTo(w * 0.9, h * 0.85);
      mountainPath.close();
      canvas.drawPath(mountainPath, darkPaint);

      // Bar charts
      final barPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.25, h * 0.6, w * 0.08, h * 0.25), const Radius.circular(4)), barPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.45, h * 0.5, w * 0.08, h * 0.35), const Radius.circular(4)), barPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.65, h * 0.4, w * 0.08, h * 0.45), const Radius.circular(4)), barPaint);

      // Flag on top
      final polePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3;
      canvas.drawLine(Offset(w * 0.85, h * 0.18), Offset(w * 0.85, h * 0.45), polePaint);
      final flagPath = Path()
        ..moveTo(w * 0.85, h * 0.18)
        ..lineTo(w * 0.70, h * 0.24)
        ..lineTo(w * 0.85, h * 0.30)
        ..close();
      canvas.drawPath(flagPath, whitePaint);
    } else {
      // 4. "Password updated!"
      canvas.drawCircle(center, w * 0.42, softBluePaint);

      // Security Card Outline
      final cardRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: w * 0.55, height: h * 0.65),
        const Radius.circular(20),
      );
      final cardBorderPaint = Paint()
        ..color = AppTheme.monexBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawRRect(cardRect, cardBorderPaint);

      // PIN Dots + Checkmark
      canvas.drawCircle(Offset(w * 0.38, h * 0.58), 5, bluePaint);
      canvas.drawCircle(Offset(w * 0.46, h * 0.58), 5, bluePaint);
      canvas.drawCircle(Offset(w * 0.54, h * 0.58), 5, bluePaint);

      // Glowing Check Badge
      canvas.drawCircle(Offset(w * 0.68, h * 0.4), w * 0.12, bluePaint);
      final checkPath = Path()
        ..moveTo(w * 0.62, h * 0.4)
        ..lineTo(w * 0.66, h * 0.44)
        ..lineTo(w * 0.74, h * 0.36);
      canvas.drawPath(checkPath, outlineWhite..strokeWidth = 3.5);
    }
  }

  void _drawCoin(Canvas canvas, Offset offset, double r, Paint white, Paint blue) {
    canvas.drawCircle(offset, r, white);
    canvas.drawCircle(offset, r * 0.75, blue);
  }

  void _drawEye(Canvas canvas, Offset offset, double size) {
    final white = Paint()..color = Colors.white;
    final blue = Paint()..color = AppTheme.monexBlue;
    canvas.drawOval(Rect.fromCenter(center: offset, width: size * 1.4, height: size), white);
    canvas.drawCircle(offset, size * 0.3, blue);
  }

  void _drawBell(Canvas canvas, Offset offset, double size, Paint white, Paint blue) {
    canvas.drawCircle(offset, size, white);
    final iconPaint = Paint()
      ..color = AppTheme.monexBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawArc(Rect.fromCircle(center: offset, radius: size * 0.5), math.pi, math.pi, false, iconPaint);
  }

  void _drawSparkle(Canvas canvas, Offset offset, double size, Paint paint) {
    final path = Path()
      ..moveTo(offset.dx, offset.dy - size)
      ..lineTo(offset.dx + size * 0.25, offset.dy - size * 0.25)
      ..lineTo(offset.dx + size, offset.dy)
      ..lineTo(offset.dx + size * 0.25, offset.dy + size * 0.25)
      ..lineTo(offset.dx, offset.dy + size)
      ..lineTo(offset.dx - size * 0.25, offset.dy + size * 0.25)
      ..lineTo(offset.dx - size, offset.dy)
      ..lineTo(offset.dx - size * 0.25, offset.dy - size * 0.25)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _IllustrationPainter oldDelegate) => oldDelegate.type != type;
}
