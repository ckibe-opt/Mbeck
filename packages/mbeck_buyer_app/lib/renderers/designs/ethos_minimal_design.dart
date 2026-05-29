import 'package:flutter/material.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../../theme/shop_theme_extension.dart';
import '../design_registry.dart';

/// Ethos Minimal — Swiss-design inspired, architectural and clean.
/// Focused on structure, grid lines, and bold black/white contrast.
/// Tier: Ultra Rare / Exclusive
class EthosMinimalDesign extends ModuleDesign {
  static const _bg = Color(0xFFF8F8F8);
  static const _ink = Color(0xFF000000);
  static const _accent = Color(0xFFE31E24); // Pure Red
  static const _muted = Color(0xFFBCBCBC);

  @override
  DesignMeta get meta => const DesignMeta(
    id: 'ethos_minimal',
    name: 'Ethos Minimal',
    description: 'Swiss precision. Bold typography, grid structures, and absolute clarity.',
    tier: DesignTier.ultraRare,
    optimizedFor: ['retail', 'services', 'universal'],
    previewPrimary: Color(0xFFF8F8F8),
    previewSecondary: Color(0xFF000000),
    icon: Icons.grid_view,
  );

  @override
  ThemeData buildTheme(ShopThemeConfig config) {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.light(primary: _ink, surface: _bg),
      fontFamily: 'Roboto', // We'll use bold weights for the 'Swiss' feel
    );
  }

  @override
  ShopThemeExtension buildExtension(ShopThemeConfig config) {
    return const ShopThemeExtension(
      cardBorderRadius: 0, cardStyle: 'grid', productLayout: 'grid',
      gridCrossAxisCount: 2, gridChildAspectRatio: 0.8,
      contentPadding: EdgeInsets.zero, itemSpacing: 0,
      heroStyle: 'minimal', chipBorderRadius: 0, buttonBorderRadius: 0,
      buttonStyle: 'sharp', sectionHeaderStyle: 'bold',
      animationStyle: 'fade', moduleCardStyle: 'grid',
    );
  }

  @override
  Widget buildRetailProductCard(BuildContext context, {required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap}) {
    return _buildEthosCard(context, item, isStarred, onStar, onTap);
  }

  @override
  Widget buildMenuItemCard(BuildContext context, {required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap, required int index}) {
    return _buildEthosCard(context, item, isStarred, onStar, onTap);
  }

  @override
  Widget buildGenericItemCard(BuildContext context, {required String module, required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap}) {
    return _buildEthosCard(context, item, isStarred, onStar, onTap);
  }

  Widget _buildEthosCard(BuildContext context, Map<String, dynamic> item, bool isStarred, VoidCallback onStar, VoidCallback onTap) {
    final name = item['name'] as String? ?? 'ITEM';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final imagePath = item['image_path'] as String? ?? item['image_url'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: _ink.withValues(alpha: 0.1), width: 0.5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imagePath != null 
                        ? Image.network(imagePath, fit: BoxFit.cover) 
                        : Container(color: Colors.white, child: const Center(child: Icon(Icons.shopping_bag_outlined, color: _muted))),
                  ),
                  Positioned(
                    bottom: 0, left: 0,
                    child: Container(
                      color: _ink,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: Text(name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1, color: _ink), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  GestureDetector(onTap: onStar, child: Icon(isStarred ? Icons.star : Icons.star_border, size: 18, color: isStarred ? _accent : _ink)),
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
      color: _ink,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(child: Text(shopName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 16))),
            IconButton(icon: const Icon(Icons.call, color: Colors.white), onPressed: onCall),
            IconButton(icon: const Icon(Icons.directions, color: _accent), onPressed: onDirections),
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

    return Container(
      color: _bg,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _ink, width: 4))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CATALOGUE / 2026', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Text(shopName.toUpperCase(), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -2, height: 0.9)),
                ],
              ),
            ),
          ),
          
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverHeaderDelegate(
              child: Container(
                color: _bg,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (ctx, i) {
                          final cat = categories[i];
                          final active = cat == selectedCategory;
                          return GestureDetector(
                            onTap: () => onCategorySelected(cat),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 20),
                                child: Text(cat.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: active ? _accent : _ink, letterSpacing: 1)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Icon(Icons.search, size: 20),
                  ],
                ),
              ),
            ),
          ),

          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => itemRenderer(filtered[i]),
              childCount: filtered.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
    final name = item['name'] as String? ?? 'CATALOG ITEM';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final imagePath = item['image_path'] as String? ?? item['image_url'] as String?;
    final description = item['description'] as String? ?? '';

    return Container(
      color: _bg,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (imagePath != null)
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: _ink, width: 2)),
                      margin: const EdgeInsets.all(24),
                      child: Image.network(imagePath, fit: BoxFit.cover),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ITEM SPECIFICATION', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
                      const SizedBox(height: 16),
                      Text(name.toUpperCase(), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -2, height: 0.9)),
                      const SizedBox(height: 32),
                      Text(description, style: const TextStyle(fontSize: 16, height: 1.5, letterSpacing: 0.5)),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          const Text('PRICE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
                          const Spacer(),
                          Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _ink, width: 2))),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onCall,
                    child: Container(
                      height: 60,
                      color: _ink,
                      child: const Center(child: Text('CONTACT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 4))),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: onStar,
                  child: Container(
                    height: 60, width: 60,
                    color: _ink,
                    child: Icon(isStarred ? Icons.star : Icons.star_border, color: _accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverHeaderDelegate({required this.child});
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override double get maxExtent => 60;
  @override double get minExtent => 60;
  @override bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

