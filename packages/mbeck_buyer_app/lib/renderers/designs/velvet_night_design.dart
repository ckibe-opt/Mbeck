import 'package:flutter/material.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../../theme/shop_theme_extension.dart';
import '../design_registry.dart';

/// Velvet Night — High-end luxury lounge / entertainment aesthetic.
/// Deep gradients, gold accents, and fluid transitions.
/// Tier: Ultra Rare / Exclusive
class VelvetNightDesign extends ModuleDesign {
  static const _deepSpace = Color(0xFF0D0D12);
  static const _gold = Color(0xFFC5A059);
  static const _text = Color(0xFFE5E5E7);

  @override
  DesignMeta get meta => const DesignMeta(
    id: 'velvet_night',
    name: 'Velvet Night',
    description: 'The ultimate luxury experience. Deep shadows, gold leaf typography, and elegant fluid motion.',
    tier: DesignTier.ultraRare,
    optimizedFor: ['entertainment', 'restaurant'],
    previewPrimary: Color(0xFF0D0D12),
    previewSecondary: Color(0xFFC5A059),
    icon: Icons.nightlife,
    isDark: true,
  );

  @override
  ThemeData buildTheme(ShopThemeConfig config) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _deepSpace,
      colorScheme: const ColorScheme.dark(primary: _gold, surface: _deepSpace),
      fontFamily: 'Roboto',
    );
  }

  @override
  ShopThemeExtension buildExtension(ShopThemeConfig config) {
    return const ShopThemeExtension(
      cardBorderRadius: 24, cardStyle: 'luxe', productLayout: 'list',
      contentPadding: EdgeInsets.all(20), itemSpacing: 20,
      heroStyle: 'luxe', chipBorderRadius: 12, buttonBorderRadius: 12,
      buttonStyle: 'elegant', sectionHeaderStyle: 'serif',
      animationStyle: 'slide', moduleCardStyle: 'luxe',
    );
  }

  @override
  Widget buildRetailProductCard(BuildContext context, {required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap}) {
    return _buildVelvetCard(context, item, isStarred, onStar, onTap);
  }

  @override
  Widget buildMenuItemCard(BuildContext context, {required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap, required int index}) {
    return _buildVelvetCard(context, item, isStarred, onStar, onTap);
  }

  @override
  Widget buildGenericItemCard(BuildContext context, {required String module, required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap}) {
    return _buildVelvetCard(context, item, isStarred, onStar, onTap);
  }

  Widget _buildVelvetCard(BuildContext context, Map<String, dynamic> item, bool isStarred, VoidCallback onStar, VoidCallback onTap) {
    final name = item['name'] as String? ?? 'Exclusive Item';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final imagePath = item['image_path'] as String? ?? item['image_url'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _gold.withValues(alpha: 0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            if (imagePath != null)
              Container(width: 120, height: 120, child: Image.network(imagePath, fit: BoxFit.cover)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: _text, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(color: _gold, fontWeight: FontWeight.w900)),
                        const Spacer(),
                        GestureDetector(onTap: onStar, child: Icon(isStarred ? Icons.star : Icons.star_border, color: _gold, size: 20)),
                      ],
                    ),
                  ],
                ),
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
      decoration: BoxDecoration(
        color: _deepSpace,
        border: Border(top: BorderSide(color: _gold.withValues(alpha: 0.2))),
      ),
      child: SafeArea(

        child: Row(
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(shopName, style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)), Text('Private Collection', style: TextStyle(color: _text.withValues(alpha: 0.5), fontSize: 12))])),
            FloatingActionButton.extended(onPressed: onCall, label: const Text('CALL NOW'), icon: const Icon(Icons.call), backgroundColor: _gold, foregroundColor: _deepSpace),
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
          colors: [_deepSpace, Color(0xFF161622)],
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            backgroundColor: _deepSpace,
            flexibleSpace: FlexibleSpaceBar(
              background: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('WELCOME TO', style: TextStyle(color: _gold, letterSpacing: 10, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text(shopName.toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: _text, letterSpacing: 4)),
                    const SizedBox(height: 8),
                    Container(width: 40, height: 2, color: _gold),
                  ],
                ),
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: categories.length,
                itemBuilder: (ctx, i) {
                  final cat = categories[i];
                  final active = cat == selectedCategory;
                  return GestureDetector(
                    onTap: () => onCategorySelected(cat),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 32),
                        child: Text(cat.toUpperCase(), style: TextStyle(color: active ? _gold : _text.withValues(alpha: 0.4), fontWeight: active ? FontWeight.w900 : FontWeight.normal, fontSize: 12, letterSpacing: 2)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
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
    final name = item['name'] as String? ?? 'Masterpiece';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final imagePath = item['image_path'] as String? ?? item['image_url'] as String?;
    final description = item['description'] as String? ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: _deepSpace,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (imagePath != null)
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(child: Image.network(imagePath, fit: BoxFit.cover)),
                  Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, _deepSpace.withValues(alpha: 0.8)])))),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PRIVATE COLLECTION', style: TextStyle(color: _gold, letterSpacing: 4, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text(name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _text, letterSpacing: 1)),
                const SizedBox(height: 24),
                Text(description, style: TextStyle(color: _text.withValues(alpha: 0.5), fontSize: 15, height: 1.8)),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(color: _gold, fontWeight: FontWeight.w900, fontSize: 24)),
                    const Spacer(),
                    IconButton(onPressed: onStar, icon: Icon(isStarred ? Icons.star : Icons.star_border, color: _gold)),
                  ],
                ),
                const SizedBox(height: 60),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onStar,
                    style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: _deepSpace, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(isStarred ? 'SAVED ★' : 'ACQUIRE', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                  ),
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
