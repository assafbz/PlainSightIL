import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic colors following the design system tokens for PlainSightIL
class AppColors {
  // Brand Hue Palette mapped to Slate Dark Mode
  static const Color baseBg = Color(0xFF0F131C);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceLow = Color(0xFF181B25);
  static const Color surfaceContainer = Color(0xFF1C1F29);
  static const Color surfaceHigh = Color(0xFF262A34);
  static const Color surfaceBright = Color(0xFF353943);

  // Brand Accents
  static const Color primary = Color(0xFF8ED5FF);         // Cyan/Teal (#8ed5ff)
  static const Color onPrimary = Color(0xFF00354A);
  static const Color primaryContainer = Color(0xFF38BDF8); // Cyan Accent (#38bdf8)
  
  static const Color secondary = Color(0xFFD0BCFF);       // Violet (#d0bcff)
  static const Color onSecondary = Color(0xFF3C0091);
  
  static const Color tertiary = Color(0xFFFFC42F);        // Amber (#ffc42f)

  // Text colors
  static const Color textPrimary = Color(0xFFDFE2EF);     // Crisp white-blue
  static const Color textSecondary = Color(0xFFBDC8D1);   // Muted slate
  static const Color textTertiary = Color(0xFF6B7280);    // Grey

  // Semantic Feedback
  static const Color success = Color(0xFF34D399);         // Emerald Green
  static const Color warning = Color(0xFFF59E0B);         // Amber
  static const Color danger = Color(0xFFF43F5E);          // Crimson
  static const Color info = Color(0xFF0EA5E9);            // Blue

  // Glassmorphic Accents
  static const Color glassBg = Color(0xC00F172A);         // rgba(15, 23, 42, 0.75)
  static const Color glassBorder = Color(0x14FFFFFF);     // rgba(255, 255, 255, 0.08)
  static const Color glassGlow = Color(0x2638BDF8);       // rgba(56, 189, 248, 0.15)
}

/// Helper class to resolve bilingual typography based on Directionality.
class AppTypography {
  static TextStyle getTextStyle(
    BuildContext context, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
    double? lineHeight,
  }) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final double? height = lineHeight != null ? lineHeight / fontSize : null;

    if (isRtl) {
      return GoogleFonts.assistant(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    } else {
      return GoogleFonts.outfit(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
  }

  static TextStyle headlineLg(BuildContext context, {Color color = AppColors.textPrimary}) {
    return getTextStyle(
      context,
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: color,
      lineHeight: 32,
      letterSpacing: -0.48,
    );
  }

  static TextStyle headlineMd(BuildContext context, {Color color = AppColors.textPrimary}) {
    return getTextStyle(
      context,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: color,
      lineHeight: 28,
      letterSpacing: -0.2,
    );
  }

  static TextStyle bodyLg(BuildContext context, {Color color = AppColors.textPrimary}) {
    return getTextStyle(
      context,
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: color,
      lineHeight: 24,
    );
  }

  static TextStyle bodySm(BuildContext context, {Color color = AppColors.textSecondary}) {
    return getTextStyle(
      context,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: color,
      lineHeight: 20,
      letterSpacing: 0.14,
    );
  }

  static TextStyle labelXs(BuildContext context, {Color color = AppColors.textSecondary}) {
    return getTextStyle(
      context,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: color,
      lineHeight: 16,
      letterSpacing: 0.6,
    );
  }
}

/// A Premium Glassmorphic Card implementing backdrop filtering and optional logical start border
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? startBorderColor;
  final double startBorderWidth;
  final VoidCallback? onTap;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.startBorderColor,
    this.startBorderWidth = 4.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.glassBorder,
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            decoration: startBorderColor != null
                ? BoxDecoration(
                    border: BorderDirectional(
                      start: BorderSide(
                        color: startBorderColor!,
                        width: startBorderWidth,
                      ),
                    ),
                  )
                : null,
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTapDown: (_) {
          // Subtle touch down/up scaling could be added if requested, 
          // but GestureDetector provides direct tap handler here.
        },
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
