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
    final effectiveColor = color ?? (AppTheme.isDark(context) ? Colors.white : AppTheme.textPrimary);

    final logoImageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppTheme.monexBlue,
            borderRadius: BorderRadius.circular(size * 0.22),
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            size: size * 0.6,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (!showText) return logoImageWidget;

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
          logoImageWidget,
          const SizedBox(height: 12),
          textWidget,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoImageWidget,
        const SizedBox(width: 10),
        textWidget,
      ],
    );
  }
}
