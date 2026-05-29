import 'package:flutter/material.dart';
import 'package:mbeck_shared/mbeck_shared.dart';

/// Layout & visual identity extension embedded in ThemeData.
///
/// Each shop preset maps to a unique combination of card styles, spacing,
/// hero sections, button shapes, and animation behaviors — making every
/// shop feel distinct, not just recolored.
class ShopThemeExtension extends ThemeExtension<ShopThemeExtension> {
  // ── Card Style ──────────────────────────────────
  final double cardBorderRadius;
  final String cardStyle; // 'elevated', 'flat', 'neon', 'outlined', 'soft'

  // ── Layout ──────────────────────────────────────
  final String productLayout; // 'grid', 'list'
  final int gridCrossAxisCount;
  final double gridChildAspectRatio;

  // ── Spacing Density ─────────────────────────────
  final EdgeInsets contentPadding;
  final double itemSpacing;

  // ── Hero ─────────────────────────────────────────
  final String heroStyle; // 'gradient', 'none', 'image', 'neon', 'soft'

  // ── Chips & Buttons ─────────────────────────────
  final double chipBorderRadius;
  final double buttonBorderRadius;
  final String buttonStyle; // 'filled', 'flat', 'pill', 'sharp'

  // ── Section Headers ─────────────────────────────
  final String sectionHeaderStyle; // 'bold', 'caps', 'elegant', 'glow', 'muted'

  // ── Animations ──────────────────────────────────
  final String animationStyle; // 'standard', 'none', 'fade', 'slide'

  // ── Module cards ────────────────────────────────
  final String moduleCardStyle; // 'gradient', 'flat', 'outlined', 'neon'

  const ShopThemeExtension({
    this.cardBorderRadius = 12.0,
    this.cardStyle = 'elevated',
    this.productLayout = 'grid',
    this.gridCrossAxisCount = 2,
    this.gridChildAspectRatio = 0.68,
    this.contentPadding = const EdgeInsets.all(16),
    this.itemSpacing = 12.0,
    this.heroStyle = 'gradient',
    this.chipBorderRadius = 20.0,
    this.buttonBorderRadius = 12.0,
    this.buttonStyle = 'filled',
    this.sectionHeaderStyle = 'bold',
    this.animationStyle = 'standard',
    this.moduleCardStyle = 'gradient',
  });

  /// Build card decoration based on theme style
  BoxDecoration buildCardDecoration({
    required Color surface,
    Color? accentColor,
    bool isSelected = false,
  }) {
    switch (cardStyle) {
      case 'flat':
        return BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(cardBorderRadius),
          border: Border.all(color: Colors.grey.shade300),
        );
      case 'neon':
        final glow = accentColor ?? Colors.cyanAccent;
        return BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(cardBorderRadius),
          border: Border.all(color: glow.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(color: glow.withOpacity(0.2), blurRadius: 12, spreadRadius: 1),
          ],
        );
      case 'outlined':
        return BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(cardBorderRadius),
          border: Border.all(
            color: isSelected
                ? (accentColor ?? Colors.grey.shade400)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        );
      case 'soft':
        return BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(cardBorderRadius),
          boxShadow: [
            BoxShadow(
              color: (accentColor ?? Colors.grey).withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        );
      case 'elevated':
      default:
        return BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(cardBorderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        );
    }
  }

  /// Build hero section decoration
  BoxDecoration buildHeroDecoration({
    required Color primary,
    Color? secondary,
  }) {
    final sec = secondary ?? primary.withOpacity(0.7);
    switch (heroStyle) {
      case 'none':
        return const BoxDecoration();
      case 'neon':
        return BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, sec],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(cardBorderRadius),
          border: Border.all(color: primary.withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(color: primary.withOpacity(0.3), blurRadius: 16, spreadRadius: 2),
          ],
        );
      case 'soft':
        return BoxDecoration(
          gradient: LinearGradient(
            colors: [primary.withOpacity(0.15), sec.withOpacity(0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(cardBorderRadius),
        );
      case 'image':
      case 'gradient':
      default:
        return BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, sec],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(cardBorderRadius),
          boxShadow: [
            BoxShadow(color: primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        );
    }
  }

  /// Build chip shape
  OutlinedBorder buildChipShape({Color? borderColor}) {
    switch (chipBorderRadius.toInt()) {
      case 0:
      case 1:
      case 2:
      case 3:
      case 4:
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(chipBorderRadius),
          side: borderColor != null ? BorderSide(color: borderColor) : BorderSide.none,
        );
      default:
        return StadiumBorder(
          side: borderColor != null ? BorderSide(color: borderColor) : BorderSide.none,
        );
    }
  }

  /// Build button shape
  RoundedRectangleBorder buildButtonShape() {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonBorderRadius),
    );
  }

  /// Build section header text style
  TextStyle buildSectionHeaderStyle(TextStyle base) {
    switch (sectionHeaderStyle) {
      case 'caps':
        return base.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        );
      case 'elegant':
        return base.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.italic,
        );
      case 'glow':
        return base.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        );
      case 'muted':
        return base.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: base.color?.withOpacity(0.7),
        );
      case 'bold':
      default:
        return base.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        );
    }
  }

  /// Section header transform (e.g. UPPERCASE for 'caps')
  String transformSectionHeader(String text) {
    if (sectionHeaderStyle == 'caps') return text.toUpperCase();
    return text;
  }

  /// Whether hero section should be shown
  bool get showHero => heroStyle != 'none';

  /// Whether to use dark text on hero (for soft/transparent heroes)
  bool get heroDarkText => heroStyle == 'soft' || heroStyle == 'none';

  // ── Factory: map preset name → full layout config ──────

  factory ShopThemeExtension.fromConfig(ShopThemeConfig config) {
    switch (config.stylePreset) {
      // ── Retail ───────────────────────────────
      case 'retail_fresh':
        return ShopThemeExtension(
          cardBorderRadius: config.borderRadius,
          cardStyle: 'elevated',
          productLayout: 'grid',
          gridCrossAxisCount: 2,
          gridChildAspectRatio: 0.68,
          contentPadding: const EdgeInsets.all(16),
          itemSpacing: 12,
          heroStyle: 'gradient',
          chipBorderRadius: 20,
          buttonBorderRadius: 12,
          buttonStyle: 'filled',
          sectionHeaderStyle: 'bold',
          animationStyle: 'standard',
          moduleCardStyle: 'gradient',
        );

      case 'retail_urban':
        return ShopThemeExtension(
          cardBorderRadius: config.borderRadius, // 8
          cardStyle: 'flat',
          productLayout: 'grid',
          gridCrossAxisCount: 2,
          gridChildAspectRatio: 0.72,
          contentPadding: const EdgeInsets.all(12),
          itemSpacing: 8,
          heroStyle: 'none',
          chipBorderRadius: 4,
          buttonBorderRadius: 6,
          buttonStyle: 'sharp',
          sectionHeaderStyle: 'caps',
          animationStyle: 'none',
          moduleCardStyle: 'flat',
        );

      // ── Restaurant ──────────────────────────
      case 'restaurant_warm':
        return ShopThemeExtension(
          cardBorderRadius: config.borderRadius, // 14
          cardStyle: 'elevated',
          productLayout: 'list',
          gridCrossAxisCount: 1,
          gridChildAspectRatio: 2.8,
          contentPadding: const EdgeInsets.all(18),
          itemSpacing: 14,
          heroStyle: 'gradient',
          chipBorderRadius: 20,
          buttonBorderRadius: 14,
          buttonStyle: 'pill',
          sectionHeaderStyle: 'bold',
          animationStyle: 'fade',
          moduleCardStyle: 'gradient',
        );

      case 'restaurant_bistro':
        return ShopThemeExtension(
          cardBorderRadius: config.borderRadius, // 16
          cardStyle: 'soft',
          productLayout: 'list',
          gridCrossAxisCount: 1,
          gridChildAspectRatio: 2.5,
          contentPadding: const EdgeInsets.all(20),
          itemSpacing: 16,
          heroStyle: 'soft',
          chipBorderRadius: 20,
          buttonBorderRadius: 24,
          buttonStyle: 'pill',
          sectionHeaderStyle: 'elegant',
          animationStyle: 'fade',
          moduleCardStyle: 'outlined',
        );

      // ── Services ────────────────────────────
      case 'services_serene':
        return ShopThemeExtension(
          cardBorderRadius: config.borderRadius, // 20
          cardStyle: 'soft',
          productLayout: 'list',
          gridCrossAxisCount: 1,
          gridChildAspectRatio: 2.2,
          contentPadding: const EdgeInsets.all(20),
          itemSpacing: 16,
          heroStyle: 'soft',
          chipBorderRadius: 24,
          buttonBorderRadius: 24,
          buttonStyle: 'pill',
          sectionHeaderStyle: 'muted',
          animationStyle: 'fade',
          moduleCardStyle: 'outlined',
        );

      case 'services_pro':
        return ShopThemeExtension(
          cardBorderRadius: config.borderRadius, // 10
          cardStyle: 'flat',
          productLayout: 'grid',
          gridCrossAxisCount: 2,
          gridChildAspectRatio: 0.75,
          contentPadding: const EdgeInsets.all(14),
          itemSpacing: 10,
          heroStyle: 'gradient',
          chipBorderRadius: 6,
          buttonBorderRadius: 8,
          buttonStyle: 'filled',
          sectionHeaderStyle: 'caps',
          animationStyle: 'standard',
          moduleCardStyle: 'flat',
        );

      // ── Entertainment ───────────────────────
      case 'entertainment_neon':
        return ShopThemeExtension(
          cardBorderRadius: config.borderRadius, // 4
          cardStyle: 'neon',
          productLayout: 'grid',
          gridCrossAxisCount: 2,
          gridChildAspectRatio: 0.85,
          contentPadding: const EdgeInsets.all(12),
          itemSpacing: 10,
          heroStyle: 'neon',
          chipBorderRadius: 4,
          buttonBorderRadius: 4,
          buttonStyle: 'sharp',
          sectionHeaderStyle: 'glow',
          animationStyle: 'slide',
          moduleCardStyle: 'neon',
        );

      case 'entertainment_lounge':
        return ShopThemeExtension(
          cardBorderRadius: config.borderRadius, // 14
          cardStyle: 'elevated',
          productLayout: 'list',
          gridCrossAxisCount: 1,
          gridChildAspectRatio: 2.5,
          contentPadding: const EdgeInsets.all(18),
          itemSpacing: 14,
          heroStyle: 'gradient',
          chipBorderRadius: 20,
          buttonBorderRadius: 14,
          buttonStyle: 'filled',
          sectionHeaderStyle: 'bold',
          animationStyle: 'fade',
          moduleCardStyle: 'gradient',
        );

      // ── Lodging ─────────────────────────────
      case 'lodging_resort':
        return ShopThemeExtension(
          cardBorderRadius: config.borderRadius, // 16
          cardStyle: 'elevated',
          productLayout: 'list',
          gridCrossAxisCount: 1,
          gridChildAspectRatio: 1.8,
          contentPadding: const EdgeInsets.all(18),
          itemSpacing: 16,
          heroStyle: 'gradient',
          chipBorderRadius: 20,
          buttonBorderRadius: 16,
          buttonStyle: 'pill',
          sectionHeaderStyle: 'bold',
          animationStyle: 'fade',
          moduleCardStyle: 'gradient',
        );

      case 'lodging_boutique':
        return ShopThemeExtension(
          cardBorderRadius: config.borderRadius, // 12
          cardStyle: 'outlined',
          productLayout: 'list',
          gridCrossAxisCount: 1,
          gridChildAspectRatio: 1.6,
          contentPadding: const EdgeInsets.all(20),
          itemSpacing: 16,
          heroStyle: 'soft',
          chipBorderRadius: 8,
          buttonBorderRadius: 8,
          buttonStyle: 'filled',
          sectionHeaderStyle: 'elegant',
          animationStyle: 'fade',
          moduleCardStyle: 'outlined',
        );

      // ── Universal ───────────────────────────
      case 'minimal':
        return ShopThemeExtension(
          cardBorderRadius: config.borderRadius, // 4
          cardStyle: 'flat',
          productLayout: 'grid',
          gridCrossAxisCount: 2,
          gridChildAspectRatio: 0.72,
          contentPadding: const EdgeInsets.all(12),
          itemSpacing: 8,
          heroStyle: 'none',
          chipBorderRadius: 4,
          buttonBorderRadius: 4,
          buttonStyle: 'flat',
          sectionHeaderStyle: 'caps',
          animationStyle: 'none',
          moduleCardStyle: 'flat',
        );

      case 'sunset':
        return ShopThemeExtension(
          cardBorderRadius: config.borderRadius, // 14
          cardStyle: 'elevated',
          productLayout: 'grid',
          gridCrossAxisCount: 2,
          gridChildAspectRatio: 0.7,
          contentPadding: const EdgeInsets.all(16),
          itemSpacing: 12,
          heroStyle: 'gradient',
          chipBorderRadius: 20,
          buttonBorderRadius: 14,
          buttonStyle: 'filled',
          sectionHeaderStyle: 'bold',
          animationStyle: 'standard',
          moduleCardStyle: 'gradient',
        );

      case 'ocean':
        return ShopThemeExtension(
          cardBorderRadius: config.borderRadius, // 12
          cardStyle: 'soft',
          productLayout: 'grid',
          gridCrossAxisCount: 2,
          gridChildAspectRatio: 0.68,
          contentPadding: const EdgeInsets.all(16),
          itemSpacing: 12,
          heroStyle: 'gradient',
          chipBorderRadius: 16,
          buttonBorderRadius: 12,
          buttonStyle: 'filled',
          sectionHeaderStyle: 'muted',
          animationStyle: 'fade',
          moduleCardStyle: 'gradient',
        );

      // ── Fallback (standard) ─────────────────
      default:
        return ShopThemeExtension(
          cardBorderRadius: config.borderRadius,
          cardStyle: config.showShadows ? 'elevated' : 'flat',
          productLayout: config.productListLayout,
          gridCrossAxisCount: config.productListLayout == 'list' ? 1 : 2,
          gridChildAspectRatio: config.productListLayout == 'list' ? 2.8 : 0.68,
          contentPadding: const EdgeInsets.all(16),
          itemSpacing: 12,
          heroStyle: 'gradient',
          chipBorderRadius: 20,
          buttonBorderRadius: config.borderRadius,
          buttonStyle: 'filled',
          sectionHeaderStyle: 'bold',
          animationStyle: 'standard',
          moduleCardStyle: 'gradient',
        );
    }
  }

  @override
  ShopThemeExtension copyWith({
    double? cardBorderRadius,
    String? cardStyle,
    String? productLayout,
    int? gridCrossAxisCount,
    double? gridChildAspectRatio,
    EdgeInsets? contentPadding,
    double? itemSpacing,
    String? heroStyle,
    double? chipBorderRadius,
    double? buttonBorderRadius,
    String? buttonStyle,
    String? sectionHeaderStyle,
    String? animationStyle,
    String? moduleCardStyle,
  }) {
    return ShopThemeExtension(
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      cardStyle: cardStyle ?? this.cardStyle,
      productLayout: productLayout ?? this.productLayout,
      gridCrossAxisCount: gridCrossAxisCount ?? this.gridCrossAxisCount,
      gridChildAspectRatio: gridChildAspectRatio ?? this.gridChildAspectRatio,
      contentPadding: contentPadding ?? this.contentPadding,
      itemSpacing: itemSpacing ?? this.itemSpacing,
      heroStyle: heroStyle ?? this.heroStyle,
      chipBorderRadius: chipBorderRadius ?? this.chipBorderRadius,
      buttonBorderRadius: buttonBorderRadius ?? this.buttonBorderRadius,
      buttonStyle: buttonStyle ?? this.buttonStyle,
      sectionHeaderStyle: sectionHeaderStyle ?? this.sectionHeaderStyle,
      animationStyle: animationStyle ?? this.animationStyle,
      moduleCardStyle: moduleCardStyle ?? this.moduleCardStyle,
    );
  }

  @override
  ShopThemeExtension lerp(covariant ShopThemeExtension? other, double t) {
    if (other == null) return this;
    return ShopThemeExtension(
      cardBorderRadius: lerpDouble(cardBorderRadius, other.cardBorderRadius, t) ?? cardBorderRadius,
      cardStyle: t < 0.5 ? cardStyle : other.cardStyle,
      productLayout: t < 0.5 ? productLayout : other.productLayout,
      gridCrossAxisCount: t < 0.5 ? gridCrossAxisCount : other.gridCrossAxisCount,
      gridChildAspectRatio: lerpDouble(gridChildAspectRatio, other.gridChildAspectRatio, t) ?? gridChildAspectRatio,
      contentPadding: EdgeInsets.lerp(contentPadding, other.contentPadding, t) ?? contentPadding,
      itemSpacing: lerpDouble(itemSpacing, other.itemSpacing, t) ?? itemSpacing,
      heroStyle: t < 0.5 ? heroStyle : other.heroStyle,
      chipBorderRadius: lerpDouble(chipBorderRadius, other.chipBorderRadius, t) ?? chipBorderRadius,
      buttonBorderRadius: lerpDouble(buttonBorderRadius, other.buttonBorderRadius, t) ?? buttonBorderRadius,
      buttonStyle: t < 0.5 ? buttonStyle : other.buttonStyle,
      sectionHeaderStyle: t < 0.5 ? sectionHeaderStyle : other.sectionHeaderStyle,
      animationStyle: t < 0.5 ? animationStyle : other.animationStyle,
      moduleCardStyle: t < 0.5 ? moduleCardStyle : other.moduleCardStyle,
    );
  }

  static double? lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }
}
