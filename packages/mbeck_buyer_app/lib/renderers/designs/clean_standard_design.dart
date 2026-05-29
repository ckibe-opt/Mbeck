import 'package:flutter/material.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../../theme/shop_theme_extension.dart';
import '../design_registry.dart';

/// Clean Standard — A premium, editorial design.
/// Inspired by modern e-commerce sites: generous whitespace,
/// crisp typography, subtle shadows, image-first cards.
/// Tier: Standard (free)
class CleanStandardDesign extends ModuleDesign {
  @override
  DesignMeta get meta => const DesignMeta(
    id: 'clean_standard',
    name: 'Clean Standard',
    description: 'Crisp, modern editorial feel. Image-first cards with generous whitespace.',
    tier: DesignTier.decent,
    optimizedFor: ['retail', 'restaurant', 'services', 'entertainment', 'lodging'],
    previewPrimary: Color(0xFF1B1B1B),
    previewSecondary: Color(0xFF4CAF50),
    icon: Icons.auto_awesome_mosaic,
  );

  @override
  ThemeData buildTheme(ShopThemeConfig config) {
    final primary = config.primaryColor;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: config.secondaryColor,
        surface: Colors.white,
        onSurface: const Color(0xFF1A1A1A),
      ),
      fontFamily: 'Roboto',
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: const Color(0xFF1A1A1A), letterSpacing: -0.3),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
      ),
    );
  }

  @override
  ShopThemeExtension buildExtension(ShopThemeConfig config) {
    return const ShopThemeExtension(
      cardBorderRadius: 16, cardStyle: 'elevated', productLayout: 'grid',
      gridCrossAxisCount: 2, gridChildAspectRatio: 0.68,
      contentPadding: EdgeInsets.all(16), itemSpacing: 14,
      heroStyle: 'minimal', chipBorderRadius: 20, buttonBorderRadius: 12,
      buttonStyle: 'rounded', sectionHeaderStyle: 'editorial',
      animationStyle: 'fade', moduleCardStyle: 'standard',
    );
  }

  // ── Retail ──────────────────────────────────────────
  @override
  Widget buildRetailProductCard(BuildContext context, {
    required Map<String, dynamic> item,
    required bool isStarred,
    required VoidCallback onStar,
    required VoidCallback onTap,
  }) {
    final name = item['name'] as String? ?? 'Unknown';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final imageUrl = item['image_url'] as String? ?? item['image_path'] as String?;
    final stock = item['stock'] as int? ?? 0;
    final category = item['category'] as String? ?? '';
    final isOutOfStock = stock <= 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image — full-bleed with overlay elements
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFFF5F5F5),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                            errorBuilder: (_, __, ___) => _placeholder(Icons.shopping_bag_outlined))
                        : _placeholder(Icons.shopping_bag_outlined),
                  ),
                  // Gradient vignette at bottom for text readability
                  Positioned(bottom: 0, left: 0, right: 0, height: 40,
                    child: Container(decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        colors: [Colors.black.withValues(alpha: 0.15), Colors.transparent]),
                    )),
                  ),
                  if (isOutOfStock)
                    Container(
                      color: Colors.white.withValues(alpha: 0.75),
                      child: const Center(child: Text('SOLD OUT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFFB71C1C), letterSpacing: 2))),
                    ),
                  // Star button — top right, frosted glass
                  Positioned(top: 8, right: 8,
                    child: GestureDetector(
                      onTap: onStar,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isStarred ? const Color(0xFFFFF3E0) : Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                        ),
                        child: Icon(
                          isStarred ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isStarred ? const Color(0xFFE53935) : const Color(0xFF9E9E9E),
                        ),
                      ),
                    ),
                  ),
                  // Low stock badge
                  if (stock > 0 && stock <= 5)
                    Positioned(top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6F00),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$stock left', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            ),
            // Info section — clean typography
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category.isNotEmpty)
                      Padding(padding: const EdgeInsets.only(bottom: 2),
                        child: Text(category.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 1)),
                      ),
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1A1A), height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Text('KES ${price.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Theme.of(context).colorScheme.primary)),
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
  Widget buildRetailHero(BuildContext context, {
    required int itemCount,
    required int categoryCount,
    required String shopName,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.storefront_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(shopName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF1A1A1A), letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text('$itemCount handpicked items  •  $categoryCount collections', style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ])),
      ]),
    );
  }

  // ── Restaurant ─────────────────────────────────────
  @override
  Widget buildMenuItemCard(BuildContext context, {
    required Map<String, dynamic> item,
    required bool isStarred,
    required VoidCallback onStar,
    required VoidCallback onTap,
    required int index,
  }) {
    final name = item['name'] as String? ?? 'Unknown';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final description = item['description'] as String? ?? '';
    final prepTime = item['prep_time_minutes'] as int? ?? 15;
    final imagePath = item['image_path'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 120,
          child: Row(children: [
            // Image
            SizedBox(
              width: 120,
              child: Stack(fit: StackFit.expand, children: [
                Container(
                  color: const Color(0xFFF5F5F5),
                  child: imagePath != null && imagePath.isNotEmpty
                      ? Image.network(imagePath, fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                          errorBuilder: (_, __, ___) => _placeholder(Icons.restaurant))
                      : _placeholder(Icons.restaurant),
                ),
                // Star
                Positioned(top: 6, left: 6,
                  child: GestureDetector(onTap: onStar,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isStarred ? const Color(0xFFFFF3E0) : Colors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
                      ),
                      child: Icon(isStarred ? Icons.favorite : Icons.favorite_border, size: 15, color: isStarred ? const Color(0xFFE53935) : Colors.grey),
                    ),
                  ),
                ),
              ]),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1A1A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (description.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 3),
                      child: Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  const Spacer(),
                  Row(children: [
                    Text('KES ${price.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Theme.of(context).colorScheme.primary)),
                    const Spacer(),
                    Icon(Icons.schedule, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 3),
                    Text('~${prepTime} min', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget buildMenuHero(BuildContext context, {required int itemCount, required int categoryCount}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.restaurant_menu, color: Theme.of(context).colorScheme.primary, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Menu', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: const Color(0xFF1A1A1A), letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text('$itemCount dishes  •  $categoryCount sections', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ])),
      ]),
    );
  }

  // ── Generic ────────────────────────────────────────
  @override
  Widget buildGenericItemCard(BuildContext context, {
    required String module,
    required Map<String, dynamic> item,
    required bool isStarred,
    required VoidCallback onStar,
    required VoidCallback onTap,
  }) {
    final name = item['name'] as String? ?? 'Unknown';
    final price = (item['price'] as num?)?.toDouble() ?? item['rate_per_night'] as num? ?? 0;
    final description = item['description'] as String? ?? '';
    final imagePath = item['image_path'] as String? ?? item['image_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 3))],
      ),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: imagePath != null && imagePath.isNotEmpty
                  ? Image.network(imagePath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder(Icons.image_outlined))
                  : _placeholder(Icons.image_outlined),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1A1A))),
              if (description.isNotEmpty)
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('KES ${price.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Theme.of(context).colorScheme.primary)),
            ])),
            GestureDetector(onTap: onStar,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isStarred ? const Color(0xFFFFF3E0) : const Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(isStarred ? Icons.favorite : Icons.favorite_border, size: 18, color: isStarred ? const Color(0xFFE53935) : Colors.grey),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Shared ─────────────────────────────────────────
  @override
  Widget buildCategoryNav(BuildContext context, {
    required List<String> categories,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: categories.length,
        itemBuilder: (ctx, i) {
          final cat = categories[i];
          final isActive = cat == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isActive ? Colors.transparent : const Color(0xFFE0E0E0)),
                  boxShadow: isActive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))] : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isActive) ...[
                    const Icon(Icons.check, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(cat, style: TextStyle(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                    color: isActive ? Colors.white : const Color(0xFF616161),
                  )),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget buildContactBar(BuildContext context, {
    required String shopName,
    String? phoneNumber,
    String? locationAddress,
    required VoidCallback onCall,
    required VoidCallback onDirections,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(shopName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1A1A))),
            if (locationAddress != null)
              Text(locationAddress, style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          if (phoneNumber != null)
            _contactBtn(Icons.call, const Color(0xFF43A047), onCall),
          if (locationAddress != null)
            Padding(padding: const EdgeInsets.only(left: 8),
              child: _contactBtn(Icons.directions, Theme.of(context).colorScheme.primary, onDirections)),
        ]),
      ),
    );
  }

  Widget _contactBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  @override
  Widget buildSearchBar(BuildContext context, {
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    String hint = 'Search...',
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(icon: Icon(Icons.clear, color: Colors.grey.shade400), onPressed: () { controller.clear(); onChanged(''); })
              : null,
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: onChanged,
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(item['name'] ?? 'Item', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                IconButton(icon: Icon(isStarred ? Icons.favorite : Icons.favorite_border, color: isStarred ? Colors.red : Colors.grey), onPressed: onStar),
              ],
            ),
            const SizedBox(height: 8),
            Text('KES ${item['price'] ?? 0}', style: TextStyle(fontSize: 18, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (item['description'] != null) Text(item['description'], style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            Row(
              children: [
                if (phoneNumber != null) Expanded(child: FilledButton.icon(onPressed: onCall, icon: const Icon(Icons.call), label: const Text('Call'))),
                if (phoneNumber != null && locationAddress != null) const SizedBox(width: 12),
                if (locationAddress != null) Expanded(child: OutlinedButton.icon(onPressed: onDirections, icon: const Icon(Icons.directions), label: const Text('Directions'))),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _placeholder(IconData icon) {
    return Center(child: Icon(icon, size: 36, color: const Color(0xFFD0D0D0)));
  }
}
