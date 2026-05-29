import 'package:flutter/material.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import 'font_loader.dart';
import 'shop_theme_extension.dart';

/// Buyer app theme matching the seller app aesthetic
/// Enhanced with complete component theming for premium UX
class BuyerTheme {
  // Primary Colors - Fallback
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color primaryGreenDark = Color(0xFF388E3C);
  
  // Neutral Colors
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color cardWhite = Colors.white;
  static const Color textDark = Color(0xFF212121);
  static const Color textGrey = Color(0xFF757575);

  /// Standard default theme (Light)
  static ThemeData lightTheme() {
    return create(ShopThemeConfig.standard());
  }

  /// Create a ThemeData dynamically from a ShopThemeConfig
  /// [fontLoader] can be provided for testing (to avoid network calls)
  static ThemeData create(ShopThemeConfig config, {FontLoader fontLoader = const GoogleFontLoader()}) {
    final primary = config.primaryColor;
    final secondary = config.secondaryColor;
    
    // Determine font family based on preset if not explicitly set
    String? fontFamily = config.fontFamily;
    if (fontFamily == null) {
      switch (config.stylePreset) {
        case 'minimal': fontFamily = 'Montserrat'; break;
        case 'cyberpunk': fontFamily = 'Orbitron'; break; // Requires font asset
        case 'nordic': fontFamily = 'Lato'; break;
        default: fontFamily = 'Roboto';
      }
    }

    final isDark = config.stylePreset == 'cyberpunk' || config.stylePreset == 'dark';
    
    // Restore missing definitions
    final background = isDark ? const Color(0xFF121212) : backgroundLight;
    final surface = isDark ? const Color(0xFF1E1E1E) : cardWhite;
    final textColor = isDark ? Colors.white : textDark;

    // --- PRESET OVERRIDES ---
    Color appBarBg = isDark ? surface : primary;
    Color appBarFg = isDark ? Colors.white : Colors.white;
    
    // Minimal: White AppBar, Black Text
    if (config.stylePreset == 'minimal') {
      appBarBg = Colors.white;
      appBarFg = Colors.black;
    }

    // Base Text Theme (Roboto default)
    TextTheme textTheme = TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor),
        bodyLarge: TextStyle(fontSize: 16, color: textColor),
        bodyMedium: TextStyle(fontSize: 14, color: textColor),
    );

    // Apply Google Font Dynamically
    if (fontFamily != null) {
      try {
        // This ensures the font file is fetched/loaded via loader (Mockable)
        final fontTextStyle = fontLoader.getFont(fontFamily);
        // Apply the font family to the entire text theme
        textTheme = textTheme.apply(fontFamily: fontTextStyle.fontFamily);
      } catch (e) {
        debugPrint("⚠️ Font error: $e");
      }
    }

    final double elevation = config.showShadows ? 2.0 : 0.0;
    final double cardElevation = config.showShadows ? 3.0 : 0.0;
    
    return ThemeData(
      useMaterial3: true,
      extensions: [ShopThemeExtension.fromConfig(config)],
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: surface,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      
      // Scaffold Background
      scaffoldBackgroundColor: background,
      
      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: elevation,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: appBarFg,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(config.borderRadius),
          side: (!config.showShadows && config.cardStyle == 'flat') 
            ? BorderSide(color: Colors.grey.shade300) 
            : BorderSide.none,
        ),
        color: surface,
      ),
      
      // Navigation Bar Theme (Bottom Nav)
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 8,
        backgroundColor: surface,
        indicatorColor: primary.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: textGrey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary, size: 24);
          }
          return IconThemeData(color: textGrey.withValues(alpha: 0.6), size: 24);
        }),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surface : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: textGrey),
      ),
      
      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      
      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      
      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? Colors.black : Colors.white, // Text color on button
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: elevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(color: primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: secondary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade100,
        selectedColor: primary.withOpacity(0.2),
        labelStyle: TextStyle(color: textColor, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      
      // Text Theme
      textTheme: textTheme,
    );
  }
}
