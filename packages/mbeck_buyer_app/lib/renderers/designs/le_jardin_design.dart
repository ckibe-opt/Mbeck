import 'package:flutter/material.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../../theme/shop_theme_extension.dart';
import '../design_registry.dart';

/// Le Jardin — Inspired by Bon Bouquet.
/// Warm, organic, lifestyle-focused editorial layout.
/// Tier: Ultra Rare / Exclusive
class LeJardinDesign extends ModuleDesign {
  static const _background = Color(0xFFFAF9F6); // Warm white
  static const _text = Color(0xFF2D2926);
  static const _accent = Color(0xFFE67E22); // Warm orange

  @override
  DesignMeta get meta => const DesignMeta(
    id: 'le_jardin',
    name: 'Le Jardin',
    description: 'Warm, organic lifestyle aesthetic. Soft lighting, rich textures, and editorial typography.',
    tier: DesignTier.ultraRare,
    optimizedFor: ['restaurant', 'retail'],
    previewPrimary: Color(0xFFFAF9F6),
    previewSecondary: Color(0xFFE67E22),
    icon: Icons.local_florist,
  );

  @override
  ThemeData buildTheme(ShopThemeConfig config) {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _background,
      colorScheme: ColorScheme.fromSeed(seedColor: _accent, surface: _background),
      fontFamily: 'Roboto',
    );
  }

  @override
  ShopThemeExtension buildExtension(ShopThemeConfig config) {
    return const ShopThemeExtension(
      cardBorderRadius: 40, cardStyle: 'organic', productLayout: 'list',
      contentPadding: EdgeInsets.all(24), itemSpacing: 24,
      heroStyle: 'editorial', chipBorderRadius: 30, buttonBorderRadius: 30,
      buttonStyle: 'pill', sectionHeaderStyle: 'serif',
      animationStyle: 'fade', moduleCardStyle: 'organic',
    );
  }

  @override
  Widget buildRetailProductCard(BuildContext context, {required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap}) {
    return _buildJardinCard(context, item, isStarred, onStar, onTap);
  }

  @override
  Widget buildMenuItemCard(BuildContext context, {required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap, required int index}) {
    return _buildJardinCard(context, item, isStarred, onStar, onTap);
  }

  @override
  Widget buildGenericItemCard(BuildContext context, {required String module, required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap}) {
    return _buildJardinCard(context, item, isStarred, onStar, onTap);
  }

  Widget _buildJardinCard(BuildContext context, Map<String, dynamic> item, bool isStarred, VoidCallback onStar, VoidCallback onTap) {
    final name = item['name'] as String? ?? 'Untitled';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final imagePath = item['image_path'] as String? ?? item['image_url'] as String?;
    final description = item['description'] as String? ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: _text.withValues(alpha: 0.05), blurRadius: 30, offset: const Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagePath != null)
              AspectRatio(
                aspectRatio: 1.2,
                child: Image.network(imagePath, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: _text, letterSpacing: -0.5))),
                      GestureDetector(onTap: onStar, child: Icon(isStarred ? Icons.favorite : Icons.favorite_border, color: isStarred ? _accent : _text, size: 22)),
                    ],
                  ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(description, style: TextStyle(color: _text.withValues(alpha: 0.6), fontSize: 14, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  const SizedBox(height: 16),
                  Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildRetailHero(BuildContext context, {required int itemCount, required int categoryCount, required String shopName}) => const SizedBox.shrink();

  @override
  Widget buildMenuHero(BuildContext context, {required int itemCount, required int categoryCount}) => const SizedBox.shrink();

  @override
  Widget buildCategoryNav(BuildContext context, {required List<String> categories, required String selected, required ValueChanged<String> onSelect}) => const SizedBox.shrink();

  @override
  Widget buildSearchBar(BuildContext context, {required TextEditingController controller, required ValueChanged<String> onChanged, String hint = 'Search...'}) => const SizedBox.shrink();

  @override
  Widget buildContactBar(BuildContext context, {required String shopName, String? phoneNumber, String? locationAddress, required VoidCallback onCall, required VoidCallback onDirections}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text('Discover more', style: TextStyle(color: _text.withValues(alpha: 0.5)))])),
            if (phoneNumber != null) FloatingActionButton.small(onPressed: onCall, elevation: 0, backgroundColor: _background, child: const Icon(Icons.call, color: _text)),
            const SizedBox(width: 8),
            if (locationAddress != null) FloatingActionButton.small(onPressed: onDirections, elevation: 0, backgroundColor: _accent, child: const Icon(Icons.directions, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  @override
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
  }) {
    final filtered = items.where((item) {
      final matchesCat = selectedCategory == 'All' || (item is Map ? item['category'] == selectedCategory : (item as InventoryItem).category == selectedCategory);
      return matchesCat;
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elegant Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BIENVENUE', style: TextStyle(color: _accent, fontWeight: FontWeight.bold, letterSpacing: 4, fontSize: 12)),
                const SizedBox(height: 12),
                Text(shopName, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w200, color: _text, letterSpacing: -1, height: 1)),
              ],
            ),
          ),

          // Categories as floating items
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: categories.length,
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                final active = cat == selectedCategory;
                return GestureDetector(
                  onTap: () => onCategorySelected(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 16),
                    width: 100,
                    decoration: BoxDecoration(
                      color: active ? _accent : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: (active ? _accent : _text).withValues(alpha: 0.1), blurRadius: 20)],
                    ),
                    child: Center(
                      child: Text(cat, style: TextStyle(color: active ? Colors.white : _text, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 40),

          // Search layer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search the collection...',
                prefixIcon: const Icon(Icons.search_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: BorderSide.none),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Content
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => itemRenderer(filtered[i]),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
  @override
  Widget buildItemDetailSheet(
    BuildContext context, {
    required Map<String, dynamic> item,
    required bool isStarred,
    required VoidCallback onStar,
    String? phoneNumber,
    String? locationAddress,
    required VoidCallback onCall,
    required VoidCallback onDirections,
  }) {
    final name = item['name'] as String? ?? 'Our Speciality';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final imagePath = item['image_path'] as String? ?? item['image_url'] as String?;
    final description = item['description'] as String? ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(50)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          if (imagePath != null)
            Center(
              child: Container(
                width: 280, height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(image: Image.network(imagePath).image, fit: BoxFit.cover),
                  boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, 20))],
                ),
              ),
            ),
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Text('LE MOMENT', style: TextStyle(color: _accent, fontWeight: FontWeight.bold, letterSpacing: 4, fontSize: 12)),
                const SizedBox(height: 16),
                Text(name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: _text, letterSpacing: -1), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Text(description, style: TextStyle(color: _text.withValues(alpha: 0.6), fontSize: 16, height: 1.6), textAlign: TextAlign.center),
                const SizedBox(height: 40),
                Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 24)),
                const SizedBox(height: 60),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton.extended(
                      onPressed: onCall,
                      label: const Text('RESERVE NOW'),
                      backgroundColor: _text,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      onPressed: onDirections,
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      child: const Icon(Icons.map),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
