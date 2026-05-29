import 'package:flutter/material.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../../theme/shop_theme_extension.dart';
import '../design_registry.dart';

/// Serenity — Soft, ethereal, and calming.
/// Organic gradients, floating cards, and pastel accents.
/// Tier: Ultra Rare / Exclusive
class SerenityDesign extends ModuleDesign {
  static const _sky = Color(0xFFE0F2F1);
  static const _mint = Color(0xFFB2DFDB);
  static const _text = Color(0xFF004D40);
  static const _accent = Color(0xFF00796B);

  @override
  DesignMeta get meta => const DesignMeta(
    id: 'serenity',
    name: 'Serenity',
    description: 'Ethereal and calming. Soft gradients and floating imagery create a sense of peace and luxury.',
    tier: DesignTier.ultraRare,
    optimizedFor: ['lodging', 'services', 'restaurant'],
    previewPrimary: Color(0xFFE0F2F1),
    previewSecondary: Color(0xFFB2DFDB),
    icon: Icons.spa,
  );

  @override
  ThemeData buildTheme(ShopThemeConfig config) {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _sky,
      colorScheme: ColorScheme.fromSeed(seedColor: _mint, surface: _sky),
      fontFamily: 'Roboto',
    );
  }

  @override
  ShopThemeExtension buildExtension(ShopThemeConfig config) {
    return const ShopThemeExtension(
      cardBorderRadius: 40, cardStyle: 'floating', productLayout: 'grid',
      gridCrossAxisCount: 2, gridChildAspectRatio: 0.75,
      contentPadding: EdgeInsets.all(20), itemSpacing: 20,
      heroStyle: 'soft', chipBorderRadius: 20, buttonBorderRadius: 20,
      buttonStyle: 'pill', sectionHeaderStyle: 'serif',
      animationStyle: 'fade', moduleCardStyle: 'floating',
    );
  }

  @override
  Widget buildRetailProductCard(BuildContext context, {required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap}) {
    return _buildSerenityCard(context, item, isStarred, onStar, onTap);
  }

  @override
  Widget buildMenuItemCard(BuildContext context, {required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap, required int index}) {
    return _buildSerenityCard(context, item, isStarred, onStar, onTap);
  }

  @override
  Widget buildGenericItemCard(BuildContext context, {required String module, required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap}) {
    return _buildSerenityCard(context, item, isStarred, onStar, onTap);
  }

  Widget _buildSerenityCard(BuildContext context, Map<String, dynamic> item, bool isStarred, VoidCallback onStar, VoidCallback onTap) {
    final name = item['name'] as String? ?? 'Soft Bliss';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final imagePath = item['image_path'] as String? ?? item['image_url'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: _text.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(child: imagePath != null ? Image.network(imagePath, fit: BoxFit.cover) : Container(color: _mint)),
                  Positioned(top: 12, right: 12, child: GestureDetector(onTap: onStar, child: CircleAvatar(backgroundColor: Colors.white, radius: 16, child: Icon(isStarred ? Icons.favorite : Icons.favorite_border, color: _accent, size: 16)))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(name, style: const TextStyle(color: _text, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center, maxLines: 1),
                  const SizedBox(height: 4),
                  Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(color: _accent, fontSize: 12)),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(child: Text(shopName, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 18))),
            FloatingActionButton.small(onPressed: onDirections, backgroundColor: _sky, elevation: 0, child: const Icon(Icons.location_on, color: _accent)),
            const SizedBox(width: 8),
            FloatingActionButton.small(onPressed: onCall, backgroundColor: _accent, elevation: 0, child: const Icon(Icons.call, color: Colors.white)),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_sky, Colors.white],
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
              child: Column(
                children: [
                  Text('DISCOVER SERENITY', style: TextStyle(color: _accent, letterSpacing: 6, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(shopName, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w200, color: _text, letterSpacing: -1), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
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
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: active ? _accent : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Center(
                        child: Text(cat, style: TextStyle(color: active ? Colors.white : _text, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => itemRenderer(filtered[i]),
                childCount: filtered.length,
              ),
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
    final name = item['name'] as String? ?? 'Soft Bliss';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final imagePath = item['image_path'] as String? ?? item['image_url'] as String?;
    final description = item['description'] as String? ?? '';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, _sky]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(60)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(40),
        children: [
          if (imagePath != null)
            Center(
              child: Container(
                width: 240, height: 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(120),
                  image: DecorationImage(image: Image.network(imagePath).image, fit: BoxFit.cover),
                  boxShadow: [BoxShadow(color: _mint.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 20))],
                ),
              ),
            ),
          const SizedBox(height: 40),
          Text('ETHEREAL FIND', style: TextStyle(color: _accent, letterSpacing: 4, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w200, color: _text, letterSpacing: -1), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Text(description, style: TextStyle(color: _text.withValues(alpha: 0.6), fontSize: 16, height: 1.8), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(30)),
              child: Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(color: _accent, fontWeight: FontWeight.w900, fontSize: 20)),
            ),
          ),
          const SizedBox(height: 60),
          Row(
            children: [
              Expanded(
                child: FloatingActionButton.extended(
                  onPressed: onCall,
                  label: const Text('CONNECT'),
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 16),
              FloatingActionButton(
                onPressed: onStar,
                backgroundColor: Colors.white,
                foregroundColor: _accent,
                elevation: 0,
                child: Icon(isStarred ? Icons.favorite : Icons.favorite_border),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
