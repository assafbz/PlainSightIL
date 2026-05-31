import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic colors following the design system tokens for PlainSightIL
class AppColors {
  static bool _isDark = true;

  static void setDarkMode(bool dark) {
    _isDark = dark;
  }

  static bool get isDark => _isDark;

  // Getters resolving active palette dynamically
  static Color get baseBg => _isDark 
      ? const Color(0xFF0F131C) 
      : HSLColor.fromAHSL(1.0, 222.0, 0.40, 0.98).toColor(); // Slate light background

  static Color get surface => _isDark 
      ? const Color(0xFF111827) 
      : const Color(0xFFFFFFFF);

  static Color get surfaceLow => _isDark 
      ? const Color(0xFF181B25) 
      : const Color(0xFFF8FAFC);

  static Color get surfaceContainer => _isDark 
      ? const Color(0xFF1C1F29) 
      : const Color(0xFFF1F5F9);

  static Color get surfaceHigh => _isDark 
      ? const Color(0xFF262A34) 
      : const Color(0xFFE2E8F0);

  static Color get surfaceBright => _isDark 
      ? const Color(0xFF353943) 
      : const Color(0xFFCBD5E1);

  // Brand Accents
  static Color get primary => _isDark 
      ? const Color(0xFF8ED5FF) // Cyan/Teal (#8ed5ff)
      : HSLColor.fromAHSL(1.0, 195.0, 0.90, 0.40).toColor(); // Rich Cyan/Teal

  static Color get onPrimary => _isDark 
      ? const Color(0xFF00354A) 
      : const Color(0xFFFFFFFF);

  static Color get primaryContainer => _isDark 
      ? const Color(0xFF38BDF8) // Cyan Accent (#38bdf8)
      : HSLColor.fromAHSL(1.0, 195.0, 0.90, 0.40).toColor();
  
  static Color get secondary => _isDark 
      ? const Color(0xFFD0BCFF) // Violet (#d0bcff)
      : HSLColor.fromAHSL(1.0, 260.0, 0.60, 0.50).toColor();
  
  static Color get onSecondary => _isDark 
      ? const Color(0xFF3C0091) 
      : const Color(0xFFFFFFFF);
  
  static Color get tertiary => _isDark 
      ? const Color(0xFFFFC42F) // Amber (#ffc42f)
      : const Color(0xFFD97706);

  // Text colors
  static Color get textPrimary => _isDark 
      ? HSLColor.fromAHSL(1.0, 210.0, 0.40, 0.98).toColor() // Crisp white-blue
      : HSLColor.fromAHSL(1.0, 222.0, 0.47, 0.11).toColor(); // Deep slate navy

  static Color get textSecondary => _isDark 
      ? HSLColor.fromAHSL(1.0, 215.0, 0.20, 0.65).toColor() // Muted slate
      : HSLColor.fromAHSL(1.0, 215.0, 0.25, 0.40).toColor(); // Medium slate grey

  static Color get textTertiary => _isDark 
      ? HSLColor.fromAHSL(1.0, 215.0, 0.15, 0.45).toColor() // Dark muted slate
      : HSLColor.fromAHSL(1.0, 215.0, 0.16, 0.57).toColor(); // Light slate grey

  // Semantic Feedback
  static Color get success => _isDark 
      ? const Color(0xFF34D399) // Emerald Green
      : const Color(0xFF059669);

  static Color get warning => _isDark 
      ? const Color(0xFFF59E0B) // Amber
      : const Color(0xFFD97706);

  static Color get danger => _isDark 
      ? const Color(0xFFF43F5E) // Crimson
      : const Color(0xFFE11D48);

  static Color get info => _isDark 
      ? const Color(0xFF0EA5E9) // Blue
      : const Color(0xFF0284C7);

  // Glassmorphic Accents
  static Color get glassBg => _isDark 
      ? HSLColor.fromAHSL(0.75, 222.0, 0.40, 0.09).toColor() // rgba(15, 23, 42, 0.75)
      : HSLColor.fromAHSL(0.80, 210.0, 0.40, 0.96).toColor(); // rgba(241, 245, 249, 0.80)

  static Color get glassBorder => _isDark 
      ? const Color(0x14FFFFFF) // rgba(255, 255, 255, 0.08)
      : const Color(0x0F0F172A); // rgba(15, 23, 42, 0.06)

  static Color get glassGlow => _isDark 
      ? const Color(0x2638BDF8) // rgba(56, 189, 248, 0.15)
      : const Color(0x1A0EA5E9); // rgba(14, 165, 233, 0.10)

  // Status and Roadmap badge color getters for drawer UI elements
  static Color get roadmapBg => _isDark
      ? HSLColor.fromAHSL(0.15, 38.0, 0.92, 0.50).toColor()
      : HSLColor.fromAHSL(0.12, 38.0, 0.90, 0.40).toColor();

  static Color get roadmapText => _isDark
      ? HSLColor.fromAHSL(1.0, 38.0, 0.92, 0.55).toColor()
      : HSLColor.fromAHSL(1.0, 38.0, 0.90, 0.40).toColor();

  static Color get activeBg => _isDark
      ? HSLColor.fromAHSL(0.15, 142.0, 0.70, 0.45).toColor()
      : HSLColor.fromAHSL(0.12, 142.0, 0.65, 0.35).toColor();

  static Color get activeText => _isDark
      ? HSLColor.fromAHSL(1.0, 142.0, 0.70, 0.45).toColor()
      : HSLColor.fromAHSL(1.0, 142.0, 0.65, 0.35).toColor();
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

  static TextStyle headlineLg(BuildContext context, {Color? color}) {
    return getTextStyle(
      context,
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: color ?? AppColors.textPrimary,
      lineHeight: 32,
      letterSpacing: -0.48,
    );
  }

  static TextStyle headlineMd(BuildContext context, {Color? color}) {
    return getTextStyle(
      context,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: color ?? AppColors.textPrimary,
      lineHeight: 28,
      letterSpacing: -0.2,
    );
  }

  static TextStyle bodyLg(BuildContext context, {Color? color}) {
    return getTextStyle(
      context,
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: color ?? AppColors.textPrimary,
      lineHeight: 24,
    );
  }

  static TextStyle bodySm(BuildContext context, {Color? color}) {
    return getTextStyle(
      context,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: color ?? AppColors.textSecondary,
      lineHeight: 20,
      letterSpacing: 0.14,
    );
  }

  static TextStyle labelXs(BuildContext context, {Color? color}) {
    return getTextStyle(
      context,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: color ?? AppColors.textSecondary,
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
