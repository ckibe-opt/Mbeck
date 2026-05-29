import 'package:flutter/material.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../../theme/shop_theme_extension.dart';
import '../design_registry.dart';

/// Vanguard Immersive — A "Total Takeover" signature design.
/// Architectural, high-contrast, immersive scrollytelling.
/// Tier: Ultra Rare / Exclusive
class VanguardImmersiveDesign extends ModuleDesign {
  // Palette: Deep Ink and Bone
  static const _ink = Color(0xFF121212);
  static const _bone = Color(0xFFF5F2ED);
  static const _accent = Color(0xFFD4AF37); // Muted gold
  static const _muted = Color(0xFF8E8E8E);

  @override
  DesignMeta get meta => const DesignMeta(
    id: 'vanguard_immersive',
    name: 'Vanguard Immersive',
    description: 'Immersive scrollytelling with architectural precision and high-end photography.',
    tier: DesignTier.ultraRare,
    optimizedFor: ['universal'],
    previewPrimary: Color(0xFF121212),
    previewSecondary: Color(0xFFF5F2ED),
    icon: Icons.architecture,
  );

  @override
  ThemeData buildTheme(ShopThemeConfig config) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _bone,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _ink,
        primary: _ink,
        surface: _bone,
      ),
      fontFamily: 'Roboto',
    );
  }

  @override
  ShopThemeExtension buildExtension(ShopThemeConfig config) {
    return const ShopThemeExtension(
      cardBorderRadius: 0, cardStyle: 'minimal', productLayout: 'grid',
      gridCrossAxisCount: 2, gridChildAspectRatio: 0.8,
      contentPadding: EdgeInsets.zero, itemSpacing: 0,
      heroStyle: 'immersive', chipBorderRadius: 0, buttonBorderRadius: 0,
      buttonStyle: 'sharp', sectionHeaderStyle: 'minimal',
      animationStyle: 'fade', moduleCardStyle: 'minimal',
    );
  }

  @override
  Widget buildRetailProductCard(BuildContext context, {required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap}) {
    return _buildVanguardCard(context, item, isStarred, onStar, onTap);
  }

  @override
  Widget buildMenuItemCard(BuildContext context, {required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap, required int index}) {
    return _buildVanguardCard(context, item, isStarred, onStar, onTap);
  }

  @override
  Widget buildGenericItemCard(BuildContext context, {required String module, required Map<String, dynamic> item, required bool isStarred, required VoidCallback onStar, required VoidCallback onTap}) {
    return _buildVanguardCard(context, item, isStarred, onStar, onTap);
  }

  Widget _buildVanguardCard(BuildContext context, Map<String, dynamic> item, bool isStarred, VoidCallback onStar, VoidCallback onTap) {
    final name = item['name'] as String? ?? 'Untitled';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final imagePath = item['image_path'] as String? ?? item['image_url'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(color: _bone),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: _ink.withValues(alpha: 0.05),
                      child: imagePath != null ? Image.network(imagePath, fit: BoxFit.cover) : const Center(child: Icon(Icons.photo_outlined, color: _muted)),
                    ),
                  ),
                  Positioned(
                    top: 10, right: 10,
                    child: GestureDetector(
                      onTap: onStar,
                      child: Icon(isStarred ? Icons.star : Icons.star_border, color: isStarred ? _accent : _ink, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2, color: _ink)),
                  const SizedBox(height: 4),
                  Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(fontSize: 11, color: _muted, letterSpacing: 1)),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(child: Text(shopName.toUpperCase(), style: const TextStyle(color: _bone, fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 14))),
            if (phoneNumber != null)
              IconButton(icon: const Icon(Icons.call, color: _bone), onPressed: onCall),
            if (locationAddress != null)
              IconButton(icon: const Icon(Icons.map, color: _bone), onPressed: onDirections),
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
      final name = (item is Map ? item['name'] : (item as InventoryItem).name).toString().toLowerCase();
      final matchesSearch = searchQuery.isEmpty || name.contains(searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return Container(
      color: _bone,
      child: CustomScrollView(
        slivers: [
          // Immersive Header
          SliverAppBar(
            expandedHeight: 300,
            backgroundColor: _ink,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(shopName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 8, fontSize: 16, color: _bone)),
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Placeholder for high-end atmospheric image
                  Container(color: _ink),
                  const Center(child: Icon(Icons.architecture, color: _accent, size: 80)),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, _ink.withValues(alpha: 0.8)]))),
                ],
              ),
            ),
          ),

          // Search & Category Layer
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      onChanged: onSearchChanged,
                      cursorColor: _ink,
                      decoration: InputDecoration(
                        hintText: 'FIND WHAT YOU DESIRE',
                        hintStyle: TextStyle(color: _muted.withValues(alpha: 0.5), letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.bold),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _ink, width: 2)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _accent, width: 2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: categories.length,
                      itemBuilder: (ctx, i) {
                        final cat = categories[i];
                        final active = cat == selectedCategory;
                        return GestureDetector(
                          onTap: () => onCategorySelected(cat),
                          child: Container(
                            margin: const EdgeInsets.only(right: 24),
                            child: Text(cat.toUpperCase(), style: TextStyle(color: active ? _ink : _muted, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2, decoration: active ? TextDecoration.underline : null)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // The Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                mainAxisSpacing: 1,
                crossAxisSpacing: 1,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => itemRenderer(filtered[i]),
                childCount: filtered.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
    final name = item['name'] as String? ?? 'Exclusive Collection';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final imagePath = item['image_path'] as String? ?? item['image_url'] as String?;
    final description = item['description'] as String? ?? '';

    return Container(
      color: _ink,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Dramatic Hero Image
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: imagePath != null
                    ? Image.network(imagePath, fit: BoxFit.cover)
                    : Container(color: _bone.withValues(alpha: 0.1), child: const Icon(Icons.architecture, color: _bone, size: 100)),
              ),
              Positioned(
                top: 50, right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: _bone, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('COLLECTION // 2026', style: TextStyle(color: _accent, letterSpacing: 4, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text(name.toUpperCase(), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: _bone, letterSpacing: 2, height: 1)),
                const SizedBox(height: 32),
                Container(width: 60, height: 2, color: _accent),
                const SizedBox(height: 32),
                Text(description, style: TextStyle(color: _bone.withValues(alpha: 0.7), fontSize: 16, height: 1.8, letterSpacing: 0.5)),
                const SizedBox(height: 60),
                Row(
                  children: [
                    Text('VALUATION', style: TextStyle(color: _muted, letterSpacing: 2, fontSize: 10)),
                    const Spacer(),
                    Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(color: _bone, fontSize: 24, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 80),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: onCall,
                    style: ElevatedButton.styleFrom(backgroundColor: _bone, foregroundColor: _ink, shape: const RoundedRectangleBorder()),
                    child: const Text('ENQUIRE NOW', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 4)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton(
                    onPressed: onDirections,
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: _bone), foregroundColor: _bone, shape: const RoundedRectangleBorder()),
                    child: const Text('LOCATE STUDIO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 4)),
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
