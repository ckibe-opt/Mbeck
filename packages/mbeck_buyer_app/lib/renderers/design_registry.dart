import 'package:flutter/material.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../theme/shop_theme_extension.dart';

// ── Design Catalog Metadata ─────────────────────────────

/// Design tier classification
enum DesignTier { decent, rare, ultraRare, oneOfAKind }

/// Metadata about a design for the gallery/catalog
class DesignMeta {
  final String id;
  final String name;
  final String description;
  final DesignTier tier;
  final List<String> optimizedFor; // ['retail', 'restaurant', ...]
  final Color previewPrimary;
  final Color previewSecondary;
  final IconData icon;
  final bool isDark;

  const DesignMeta({
    required this.id,
    required this.name,
    required this.description,
    required this.tier,
    required this.optimizedFor,
    required this.previewPrimary,
    required this.previewSecondary,
    required this.icon,
    this.isDark = false,
  });

  String get tierLabel {
    switch (tier) {
      case DesignTier.decent: return 'Standard';
      case DesignTier.rare: return 'Rare';
      case DesignTier.ultraRare: return 'Ultra Rare';
      case DesignTier.oneOfAKind: return 'Exclusive';
    }
  }

  Color get tierColor {
    switch (tier) {
      case DesignTier.decent: return const Color(0xFF78909C);
      case DesignTier.rare: return const Color(0xFF1E88E5);
      case DesignTier.ultraRare: return const Color(0xFF9C27B0);
      case DesignTier.oneOfAKind: return const Color(0xFFFF6F00);
    }
  }
}

// ── Abstract Module Design ──────────────────────────────

/// Each design implements this to provide a complete visual identity.
/// The design controls how every element renders — from cards to hero sections.
abstract class ModuleDesign {
  /// Design metadata
  DesignMeta get meta;

  /// Build the full ThemeData for this design
  ThemeData buildTheme(ShopThemeConfig config);

  /// Build the ShopThemeExtension layout config
  ShopThemeExtension buildExtension(ShopThemeConfig config);

  // ── Retail Renderers ──────────────────────────────
  Widget buildRetailProductCard(
    BuildContext context, {
    required Map<String, dynamic> item,
    required bool isStarred,
    required VoidCallback onStar,
    required VoidCallback onTap,
  });

  Widget buildRetailHero(
    BuildContext context, {
    required int itemCount,
    required int categoryCount,
    required String shopName,
  });

  // ── Restaurant Renderers ──────────────────────────
  Widget buildMenuItemCard(
    BuildContext context, {
    required Map<String, dynamic> item,
    required bool isStarred,
    required VoidCallback onStar,
    required VoidCallback onTap,
    required int index,
  });

  Widget buildMenuHero(
    BuildContext context, {
    required int itemCount,
    required int categoryCount,
  });

  // ── Generic Item Card (services, entertainment, lodging) ──
  Widget buildGenericItemCard(
    BuildContext context, {
    required String module,
    required Map<String, dynamic> item,
    required bool isStarred,
    required VoidCallback onStar,
    required VoidCallback onTap,
  });

  // ── Category Navigation ───────────────────────────
  Widget buildCategoryNav(
    BuildContext context, {
    required List<String> categories,
    required String selected,
    required ValueChanged<String> onSelect,
  });

  // ── Business Contact Bar ──────────────────────────
  Widget buildContactBar(
    BuildContext context, {
    required String shopName,
    String? phoneNumber,
    String? locationAddress,
    required VoidCallback onCall,
    required VoidCallback onDirections,
  });

  // ── Search Bar ────────────────────────────────────
  Widget buildSearchBar(
    BuildContext context, {
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    String hint = 'Search...',
  });

  /// If this returns a non-null widget, the Browse Screen will use it
  /// instead of the standard sliver-based layout.
  Widget? buildImmersiveBody(
    BuildContext context, {
    required String module,
    required String shopName,
    required List<dynamic> items,
    required List<String> categories,
    required String selectedCategory,
    required Function(String) onCategorySelected,
    required String searchQuery,
    required Function(String) onSearchChanged,
    required bool isLoading,
    required Future<void> Function() onRefresh,
    required Widget Function(dynamic item) itemRenderer,
  }) => null;

  /// Build the item detail view (usually shown in a bottom sheet or full-screen)
  Widget buildItemDetailSheet(
    BuildContext context, {
    required Map<String, dynamic> item,
    required bool isStarred,
    required VoidCallback onStar,
    String? phoneNumber,
    String? locationAddress,
    required VoidCallback onCall,
    required VoidCallback onDirections,
  });
}



// ── Design Registry ─────────────────────────────────────

/// Central registry that resolves design IDs to ModuleDesign instances.
class DesignRegistry {
  static final Map<String, ModuleDesign> _designs = {};

  /// Register a design
  static void register(ModuleDesign design) {
    _designs[design.meta.id] = design;
  }

  /// Resolve a design by ID (falls back to clean_standard)
  static ModuleDesign resolve(String designId) {
    return _designs[designId] ?? _designs['clean_standard']!;
  }

  /// Get all registered designs
  static List<ModuleDesign> get allDesigns => _designs.values.toList();

  /// Get designs by tier
  static List<ModuleDesign> byTier(DesignTier tier) {
    return _designs.values.where((d) => d.meta.tier == tier).toList();
  }

  /// Get designs optimized for a specific module
  static List<ModuleDesign> forModule(String module) {
    return _designs.values.where((d) =>
      d.meta.optimizedFor.contains(module) || d.meta.optimizedFor.contains('universal')
    ).toList();
  }

  /// Get all design metadata (for gallery display)
  static List<DesignMeta> get catalog => _designs.values.map((d) => d.meta).toList();
}
