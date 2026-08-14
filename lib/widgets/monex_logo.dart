import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

typedef ExpenseOSLogo = MonexLogo;

class MonexLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final double fontSize;
  final Color? color;
  final bool isVertical;

  const MonexLogo({
    super.key,
    this.size = 54,
    this.showText = true,
    this.fontSize = 22,
    this.color,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.textPrimary;

    final iconWidget = Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.account_balance_wallet_rounded, size: size, color: AppTheme.monexBlue);
      },
    );

    if (!showText) return iconWidget;

    final textWidget = Text(
      'Expense OS',
      style: GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: effectiveColor,
        letterSpacing: -0.5,
      ),
    );

    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(height: 12),
          textWidget,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconWidget,
        const SizedBox(width: 10),
        textWidget,
      ],
    );
  }
}
