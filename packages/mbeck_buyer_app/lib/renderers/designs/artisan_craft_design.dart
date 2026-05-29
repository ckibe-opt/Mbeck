import 'package:flutter/material.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../../theme/shop_theme_extension.dart';
import '../design_registry.dart';

/// Artisan Craft — Warm, handmade, lifestyle-brand aesthetic.
/// Inspired by boutique café sites: rounded photo frames,
/// warm earth + blush tones, serif display text, textured cards.
/// Tier: Rare
class ArtisanCraftDesign extends ModuleDesign {
  // Palette — warm earth meets blush
  static const _cream = Color(0xFFFDF6EE);
  static const _warmBg = Color(0xFFFAF3EB);
  static const _cardBg = Color(0xFFFFFBF5);
  static const _espresso = Color(0xFF3E2723);
  static const _terracotta = Color(0xFFBF5B3F);
  static const _blush = Color(0xFFF2B8A0);
  static const _sage = Color(0xFF7A9E7E);
  static const _linen = Color(0xFFE8DDD3);
  static const _gold = Color(0xFFD4A84B);
  static const _textDark = Color(0xFF2C2017);
  static const _textMuted = Color(0xFF9E8E82);

  @override
  DesignMeta get meta => const DesignMeta(
    id: 'artisan_craft',
    name: 'Artisan Craft',
    description: 'Warm earth tones with handcrafted feel. Like a boutique café brand.',
    tier: DesignTier.rare,
    optimizedFor: ['retail', 'restaurant', 'services'],
    previewPrimary: Color(0xFFBF5B3F),
    previewSecondary: Color(0xFFF2B8A0),
    icon: Icons.eco,
  );

  @override
  ThemeData buildTheme(ShopThemeConfig config) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _warmBg,
      colorScheme: const ColorScheme.light(
        primary: _terracotta,
        secondary: _sage,
        surface: _cardBg,
        onSurface: _textDark,
      ),
      fontFamily: 'Roboto',
      cardTheme: CardThemeData(
        elevation: 0,
        color: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: _cream,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w300,
          fontSize: 22,
          color: _espresso,
          letterSpacing: 1.5,
        ),
        iconTheme: IconThemeData(color: _espresso),
      ),
    );
  }

  @override
  ShopThemeExtension buildExtension(ShopThemeConfig config) {
    return const ShopThemeExtension(
      cardBorderRadius: 20, cardStyle: 'artisan', productLayout: 'grid',
      gridCrossAxisCount: 2, gridChildAspectRatio: 0.72,
      contentPadding: EdgeInsets.all(16), itemSpacing: 14,
      heroStyle: 'artisan', chipBorderRadius: 24, buttonBorderRadius: 24,
      buttonStyle: 'pill', sectionHeaderStyle: 'serif',
      animationStyle: 'fade', moduleCardStyle: 'artisan',
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
    final isOutOfStock = stock <= 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _linen, width: 1.5),
          boxShadow: [BoxShadow(color: const Color(0xFF8D6E63).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image — with rounded inner frame
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Stack(
                  children: [
                    // The photo inside a rounded frame (polaroid style)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox.expand(
                        child: Container(
                          color: _linen,
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(imageUrl, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _artisanPlaceholder())
                              : _artisanPlaceholder(),
                        ),
                      ),
                    ),
                    if (isOutOfStock)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            color: _cream.withValues(alpha: 0.8),
                            child: Center(
                              child: Transform.rotate(angle: -0.15,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: _terracotta, width: 1.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('SOLD OUT', style: TextStyle(color: _terracotta, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 2)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Star — organic circle
                    Positioned(top: 4, right: 4,
                      child: GestureDetector(onTap: onStar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isStarred ? const Color(0xFFFFF8E1) : _cardBg.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            border: Border.all(color: isStarred ? _gold : _linen),
                          ),
                          child: Icon(isStarred ? Icons.favorite : Icons.favorite_border, size: 16, color: isStarred ? _terracotta : _textMuted),
                        ),
                      ),
                    ),
                    // Low stock — handwritten feel
                    if (stock > 0 && stock <= 5)
                      Positioned(bottom: 4, left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _terracotta.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Only $stock left', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Name & price — warm typography
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _textDark, height: 1.2, letterSpacing: 0.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _sage.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _sage)),
                      ),
                    ]),
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
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _linen),
        boxShadow: [BoxShadow(color: _espresso.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        // Decorative icon with organic border
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _terracotta.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _blush.withValues(alpha: 0.5)),
          ),
          child: const Icon(Icons.storefront_rounded, color: _terracotta, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(shopName, style: const TextStyle(fontWeight: FontWeight.w300, fontSize: 18, color: _espresso, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Row(children: [
            _dot(),
            Text(' $itemCount curated items', style: const TextStyle(fontSize: 12, color: _textMuted)),
            const Text('  ·  ', style: TextStyle(color: _blush)),
            Text('$categoryCount collections', style: const TextStyle(fontSize: 12, color: _textMuted)),
          ]),
        ])),
      ]),
    );
  }

  Widget _dot() => Container(width: 4, height: 4, margin: const EdgeInsets.only(right: 6), decoration: const BoxDecoration(color: _terracotta, shape: BoxShape.circle));

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

    // Alternating warm accent colors
    final accents = [_terracotta, _sage, _gold, const Color(0xFF8D6E63)];
    final accent = accents[index % accents.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _linen),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 130,
          child: Row(children: [
            // Photo — rounded inner frame
            Container(
              width: 120,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: Stack(fit: StackFit.expand, children: [
                Container(
                  color: _linen,
                  child: imagePath != null && imagePath.isNotEmpty
                      ? Image.network(imagePath, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _artisanPlaceholder())
                      : _artisanPlaceholder(),
                ),
                // Star
                Positioned(top: 4, left: 4,
                  child: GestureDetector(onTap: onStar,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isStarred ? const Color(0xFFFFF8E1) : _cardBg.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(color: isStarred ? _gold : _linen),
                      ),
                      child: Icon(isStarred ? Icons.favorite : Icons.favorite_border, size: 14, color: isStarred ? _terracotta : _textMuted),
                    ),
                  ),
                ),
              ]),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Decorative accent line
                  Container(width: 24, height: 2, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(1))),
                  const SizedBox(height: 6),
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: _textDark, letterSpacing: 0.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (description.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 3),
                      child: Text(description, style: const TextStyle(fontSize: 12, color: _textMuted, fontStyle: FontStyle.italic, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  const Spacer(),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _sage.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _sage)),
                    ),
                    const Spacer(),
                    Icon(Icons.schedule, size: 13, color: _textMuted),
                    const SizedBox(width: 3),
                    Text('~$prepTime min', style: const TextStyle(fontSize: 11, color: _textMuted)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _linen),
        boxShadow: [BoxShadow(color: _espresso.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _terracotta.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _blush.withValues(alpha: 0.5)),
          ),
          child: const Icon(Icons.restaurant_menu, color: _terracotta, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Our Menu', style: TextStyle(fontWeight: FontWeight.w300, fontSize: 18, color: _espresso, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Row(children: [
            _dot(),
            Text('$itemCount dishes', style: const TextStyle(fontSize: 12, color: _textMuted)),
            const Text('  ·  ', style: TextStyle(color: _blush)),
            Text('$categoryCount sections', style: const TextStyle(fontSize: 12, color: _textMuted)),
          ]),
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
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _linen),
      ),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: _linen, borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: imagePath != null && imagePath.isNotEmpty
                  ? Image.network(imagePath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _artisanPlaceholder())
                  : _artisanPlaceholder(),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: _textDark)),
              if (description.isNotEmpty)
                Text(description, style: const TextStyle(fontSize: 12, color: _textMuted, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _sage.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(fontWeight: FontWeight.w700, color: _sage, fontSize: 12)),
              ),
            ])),
            GestureDetector(onTap: onStar,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isStarred ? const Color(0xFFFFF8E1) : _cream,
                  shape: BoxShape.circle,
                  border: Border.all(color: isStarred ? _gold : _linen),
                ),
                child: Icon(isStarred ? Icons.favorite : Icons.favorite_border, size: 18, color: isStarred ? _terracotta : _textMuted),
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
                  color: isActive ? _terracotta : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isActive ? _terracotta : _linen, width: 1.5),
                ),
                child: Text(cat, style: TextStyle(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                  color: isActive ? Colors.white : _textMuted,
                  letterSpacing: 0.3,
                )),
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
        color: _cream,
        border: Border(top: BorderSide(color: _linen, width: 1.5)),
        boxShadow: [BoxShadow(color: _espresso.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(shopName, style: const TextStyle(fontWeight: FontWeight.w300, fontSize: 16, color: _espresso, letterSpacing: 1)),
            if (locationAddress != null)
              Text(locationAddress, style: const TextStyle(fontSize: 12, color: _textMuted, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          if (phoneNumber != null)
            GestureDetector(onTap: onCall,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _sage.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: _sage.withValues(alpha: 0.3))),
                child: const Icon(Icons.call, color: _sage, size: 20),
              ),
            ),
          if (locationAddress != null)
            Padding(padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(onTap: onDirections,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _terracotta.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: _terracotta.withValues(alpha: 0.3))),
                  child: const Icon(Icons.directions, color: _terracotta, size: 20),
                ),
              ),
            ),
        ]),
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
        style: const TextStyle(fontSize: 15, color: _textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _textMuted, fontStyle: FontStyle.italic),
          prefixIcon: const Icon(Icons.search, color: _textMuted),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, color: _textMuted), onPressed: () { controller.clear(); onChanged(''); })
              : null,
          filled: true,
          fillColor: _cream,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: _linen)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: _linen)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: _terracotta)),
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
    final name = item['name'] as String? ?? 'Handcrafted Item';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final imagePath = item['image_path'] as String? ?? item['image_url'] as String?;
    final description = item['description'] as String? ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: _warmBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          if (imagePath != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _linen)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(imagePath, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 32),
          Text('ARTISAN STORY', style: TextStyle(color: _terracotta, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 10)),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: _espresso, letterSpacing: 0.5)),
          const SizedBox(height: 20),
          Text(description, style: TextStyle(color: _textDark.withValues(alpha: 0.7), fontSize: 15, height: 1.6)),
          const SizedBox(height: 32),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: _sage.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(color: _sage, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const Spacer(),
              IconButton(onPressed: onStar, icon: Icon(isStarred ? Icons.favorite : Icons.favorite_border, color: _terracotta)),
            ],
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onCall,
                  style: ElevatedButton.styleFrom(backgroundColor: _terracotta, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: const Text('GET IN TOUCH', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(onPressed: onDirections, icon: const Icon(Icons.map), style: IconButton.styleFrom(padding: const EdgeInsets.all(16))),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _artisanPlaceholder() {
    return Container(
      color: _linen,
      child: Center(child: Icon(Icons.eco, size: 28, color: _terracotta.withValues(alpha: 0.25))),
    );
  }
}

