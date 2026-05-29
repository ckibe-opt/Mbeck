import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 🎨 Color Palette
class AppColors {
  // PRIMARY BRAND COLORS
  static const Color primaryGreen = Color(0xFF10B981); // Emerald 500
  static const Color primaryDark = Color(0xFF059669);  // Emerald 600
  static const Color primaryLight = Color(0xFF6EE7B7); // Emerald 300
  static const Color primaryBlack = Color(0xFF000000); // Black

  // SEMANTIC COLORS
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningYellow = Color(0xFFF59E0B); // Alias for warning
  static const Color danger = Color(0xFFEF4444);  // Red 500
  static const Color errorText = Color(0xFFEF4444);  // Alias for danger
  static const Color info = Color(0xFF3B82F6);    // Blue 500

  // NEUTRAL PALETTE (Tailwind-inspired)
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);

  // SURFACE COLORS
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceGray = Color(0xFFF9FAFB);
  static const Color surfaceDark = Color(0xFF111827);
}

// ✒️ Typography Scale
class AppTypography {
  static final TextTheme textTheme = TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
  );

  // Additional semantic sizes for specific use cases
  static final TextStyle displayMedium = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.2,
  );

  static final TextStyle titleLarge = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );
}

// 📏 Spacing System
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

// 🌟 Elevation & Shadows
class AppShadows {
  static const BoxShadow sm = BoxShadow(
    color: Color(0x0F000000), // 6% opacity
    blurRadius: 3,
    offset: Offset(0, 1),
  );
  
  static const BoxShadow md = BoxShadow(
    color: Color(0x14000000), // 8% opacity
    blurRadius: 6,
    offset: Offset(0, 2),
  );
  
  static const BoxShadow lg = BoxShadow(
    color: Color(0x1A000000), // 10% opacity
    blurRadius: 15,
    offset: Offset(0, 4),
  );
}

// 📐 Border Radius
class AppRadii {
  static const double sm = 6.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double full = 9999.0; // Pills
}

// 🎬 Animation Constants
class AppAnimations {
  // Durations (per UX research: ≤300ms for micro-interactions)
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  // Curves (research-based: easeOutCubic for natural feel)
  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.easeOutBack;
  static const Curve linearCurve = Curves.linear;
}

// 📏 Icon Sizes (research: 32px → 36px for operation tiles)
class AppIconSizes {
  static const double sm = 16.0;
  static const double md = 24.0;
  static const double lg = 32.0;
  static const double xl = 36.0; // For dashboard operation tiles
  static const double xxl = 48.0;
}

// Skeleton loader (no spinners per UX_Design.md)
class AppSkeleton {
  static Widget box({double? width, double? height}) {
    return Container(
      width: width,
      height: height ?? 16,
      decoration: BoxDecoration(
        color: AppColors.gray200,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    );
  }

  static Widget listItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          box(width: 40, height: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: box(height: 14)),
          const SizedBox(width: AppSpacing.sm),
          box(width: 60, height: 14),
        ],
      ),
    );
  }

  static Widget screen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          listItem(),
          listItem(),
          listItem(),
          listItem(),
          listItem(),
        ],
      ),
    );
  }
}

// 🎨 ThemeData
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AppColors.primaryGreen,
      scaffoldBackgroundColor: AppColors.gray50,
      textTheme: AppTypography.textTheme,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryGreen,
        secondary: AppColors.primaryLight,
        surface: AppColors.surfaceWhite,
        background: AppColors.gray50,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: AppColors.gray900,
        onSurface: AppColors.gray900,
        onBackground: AppColors.gray900,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.gray900,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
        titleTextStyle: AppTypography.textTheme.headlineMedium?.copyWith(
          color: AppColors.gray900,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: AppTypography.textTheme.labelLarge,
        ),
      ),
      // Add other theme properties here
    );
  }
}
