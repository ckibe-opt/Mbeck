import 'package:flutter/material.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../../theme/shop_theme_extension.dart';
import '../design_registry.dart';

/// Neon Pulse — Dark, vibrant, electric.
/// Glowing borders, pulse effects, arcade atmosphere.
/// Feels like a cyberpunk storefront.
/// Tier: Rare
class NeonPulseDesign extends ModuleDesign {
  // Neon palette
  static const _darkBg = Color(0xFF0D0D1A);
  static const _darkCard = Color(0xFF1A1A2E);
  static const _darkSurface = Color(0xFF16213E);
  static const _neonCyan = Color(0xFF00E5FF);
  static const _neonMagenta = Color(0xFFFF00FF);
  static const _neonGreen = Color(0xFF00FF87);
  static const _textWhite = Color(0xFFE8E8E8);
  static const _textMuted = Color(0xFF8888AA);

  @override
  DesignMeta get meta => const DesignMeta(
    id: 'neon_pulse',
    name: 'Neon Pulse',
    description: 'Dark, vibrant, electric. Glowing borders and arcade atmosphere.',
    tier: DesignTier.rare,
    optimizedFor: ['entertainment', 'retail'],
    previewPrimary: _neonCyan,
    previewSecondary: _neonMagenta,
    icon: Icons.electric_bolt,
    isDark: true,
  );

  @override
  ThemeData buildTheme(ShopThemeConfig config) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBg,
      colorScheme: const ColorScheme.dark(
        primary: _neonCyan,
        secondary: _neonMagenta,
        surface: _darkCard,
        onSurface: _textWhite,
      ),
      fontFamily: 'Roboto',
      cardTheme: CardThemeData(
        elevation: 0,
        color: _darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: _neonCyan.withOpacity(0.2)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: _darkBg,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w900,
          fontSize: 22,
          color: _neonCyan,
          letterSpacing: 2,
        ),
        iconTheme: IconThemeData(color: _neonCyan),
      ),
    );
  }

  @override
  ShopThemeExtension buildExtension(ShopThemeConfig config) {
    return const ShopThemeExtension(
      cardBorderRadius: 8,
      cardStyle: 'neon',
      productLayout: 'grid',
      gridCrossAxisCount: 2,
      gridChildAspectRatio: 0.75,
      contentPadding: EdgeInsets.all(14),
      itemSpacing: 10,
      heroStyle: 'neon',
      chipBorderRadius: 4,
      buttonBorderRadius: 6,
      buttonStyle: 'sharp',
      sectionHeaderStyle: 'glow',
      animationStyle: 'slide',
      moduleCardStyle: 'neon',
    );
  }

  // ── Retail ────────────────────────────────────────

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
          color: _darkCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _neonCyan.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(color: _neonCyan.withOpacity(0.08), blurRadius: 12, spreadRadius: 1),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image with neon accent
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: _darkSurface,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildNeonIcon(Icons.shopping_bag_outlined))
                        : _buildNeonIcon(Icons.shopping_bag_outlined),
                  ),
                  // Gradient overlay for text readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, _darkBg.withOpacity(0.6)],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  if (isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        color: _darkBg.withOpacity(0.7),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red, width: 1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('SOLD OUT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 2)),
                          ),
                        ),
                      ),
                    ),
                  // Star — neon glow
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: onStar,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _darkCard.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: isStarred ? _neonMagenta.withOpacity(0.6) : _neonCyan.withOpacity(0.3)),
                          boxShadow: isStarred
                              ? [BoxShadow(color: _neonMagenta.withOpacity(0.3), blurRadius: 8)]
                              : null,
                        ),
                        child: Icon(
                          isStarred ? Icons.star : Icons.star_border,
                          size: 16,
                          color: isStarred ? _neonMagenta : _neonCyan.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  if (stock > 0 && stock <= 5)
                    Positioned(
                      bottom: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _darkCard.withOpacity(0.8),
                          border: Border.all(color: Colors.red.withOpacity(0.6)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('$stock LEFT', style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                ],
              ),
            ),
            // Info — neon style
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: _textWhite,
                      letterSpacing: 1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Neon price tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: _neonGreen.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [BoxShadow(color: _neonGreen.withOpacity(0.1), blurRadius: 6)],
                    ),
                    child: Text(
                      CurrencyFormatter.formatWithCurrency(price),
                      style: const TextStyle(
                        color: _neonGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeonIcon(IconData icon) {
    return Center(
      child: Icon(icon, size: 40, color: _neonCyan.withOpacity(0.3),
        shadows: [Shadow(color: _neonCyan.withOpacity(0.3), blurRadius: 12)]),
    );
  }

  @override
  Widget buildRetailHero(BuildContext context, {
    required int itemCount,
    required int categoryCount,
    required String shopName,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_neonCyan.withOpacity(0.15), _neonMagenta.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _neonCyan.withOpacity(0.4), width: 1),
        boxShadow: [BoxShadow(color: _neonCyan.withOpacity(0.15), blurRadius: 16, spreadRadius: 2)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: _neonCyan.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.storefront, color: _neonCyan, size: 28,
              shadows: [Shadow(color: _neonCyan.withOpacity(0.5), blurRadius: 8)]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shopName.toUpperCase(),
                  style: const TextStyle(
                    color: _neonCyan,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 2,
                    shadows: [Shadow(color: _neonCyan, blurRadius: 6)],
                  ),
                ),
                const SizedBox(height: 4),
                Text('$itemCount ITEMS  //  $categoryCount CATEGORIES',
                  style: TextStyle(color: _textMuted, fontSize: 12, letterSpacing: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Restaurant ────────────────────────────────────

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

    final accentColors = [_neonCyan, _neonMagenta, _neonGreen, const Color(0xFFFF6B6B), const Color(0xFFFFD93D)];
    final accent = accentColors[index % accentColors.length];

    return Container(
      decoration: BoxDecoration(
        color: _darkCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.06), blurRadius: 10)],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 110,
          child: Row(
            children: [
              // Image with neon accent strip
              SizedBox(
                width: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: _darkSurface,
                      child: imagePath != null && imagePath.isNotEmpty
                          ? Image.network(imagePath, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.restaurant, size: 36, color: accent.withOpacity(0.4)))
                          : Icon(Icons.restaurant, size: 36, color: accent.withOpacity(0.4)),
                    ),
                    // Neon accent strip at bottom
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(height: 2,
                        decoration: BoxDecoration(color: accent.withOpacity(0.6), boxShadow: [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 4)])),
                    ),
                    Positioned(
                      top: 4, left: 4,
                      child: GestureDetector(
                        onTap: onStar,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _darkCard.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isStarred ? _neonMagenta.withOpacity(0.5) : accent.withOpacity(0.3)),
                          ),
                          child: Icon(isStarred ? Icons.star : Icons.star_border, size: 14, color: isStarred ? _neonMagenta : _textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _textWhite, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(description, style: const TextStyle(fontSize: 11, color: _textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(border: Border.all(color: _neonGreen.withOpacity(0.4)), borderRadius: BorderRadius.circular(4)),
                            child: Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _neonGreen)),
                          ),
                          const Spacer(),
                          Text('${prepTime}m', style: TextStyle(fontSize: 11, color: _textMuted, letterSpacing: 0.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget buildMenuHero(BuildContext context, {required int itemCount, required int categoryCount}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_neonCyan.withOpacity(0.12), _neonMagenta.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _neonCyan.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: _neonCyan.withOpacity(0.1), blurRadius: 12)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border.all(color: _neonCyan.withOpacity(0.4)), borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.restaurant_menu, color: _neonCyan, size: 26, shadows: [Shadow(color: _neonCyan, blurRadius: 6)]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MENU', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 3)),
                const SizedBox(height: 4),
                Text('$itemCount ITEMS  //  $categoryCount SECTIONS', style: TextStyle(color: _textMuted, fontSize: 11, letterSpacing: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Generic ───────────────────────────────────────

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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _darkCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _neonCyan.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _darkSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _neonCyan.withOpacity(0.2)),
                ),
                clipBehavior: Clip.antiAlias,
                child: imagePath != null && imagePath.isNotEmpty
                    ? Image.network(imagePath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildNeonIcon(Icons.image_outlined))
                    : _buildNeonIcon(Icons.image_outlined),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _textWhite, letterSpacing: 0.5)),
                    if (description.isNotEmpty)
                      Text(description, style: const TextStyle(fontSize: 11, color: _textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(border: Border.all(color: _neonGreen.withOpacity(0.4)), borderRadius: BorderRadius.circular(4)),
                      child: Text(CurrencyFormatter.formatWithCurrency(price), style: const TextStyle(fontWeight: FontWeight.bold, color: _neonGreen, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onStar,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(color: isStarred ? _neonMagenta.withOpacity(0.5) : _neonCyan.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: isStarred ? [BoxShadow(color: _neonMagenta.withOpacity(0.2), blurRadius: 6)] : null,
                  ),
                  child: Icon(isStarred ? Icons.star : Icons.star_border, size: 18, color: isStarred ? _neonMagenta : _textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared ────────────────────────────────────────

  @override
  Widget buildCategoryNav(BuildContext context, {
    required List<String> categories,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isSelected = cat == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onSelect(cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? _neonCyan.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isSelected ? _neonCyan.withOpacity(0.6) : _neonCyan.withOpacity(0.15)),
                  boxShadow: isSelected ? [BoxShadow(color: _neonCyan.withOpacity(0.15), blurRadius: 6)] : null,
                ),
                child: Text(
                  cat.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? _neonCyan : _textMuted,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
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
        color: _darkCard,
        border: Border(top: BorderSide(color: _neonCyan.withOpacity(0.3), width: 1)),
        boxShadow: [BoxShadow(color: _neonCyan.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(shopName.toUpperCase(), style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)),
                  if (locationAddress != null)
                    Text(locationAddress, style: const TextStyle(color: _textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (phoneNumber != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: _neonGreen.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: IconButton(icon: Icon(Icons.call, color: _neonGreen, size: 20, shadows: [Shadow(color: _neonGreen, blurRadius: 4)]), onPressed: onCall),
              ),
            if (locationAddress != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: _neonCyan.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: IconButton(icon: Icon(Icons.directions, color: _neonCyan, size: 20, shadows: [Shadow(color: _neonCyan, blurRadius: 4)]), onPressed: onDirections),
              ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: _textWhite, letterSpacing: 0.5),
        decoration: InputDecoration(
          hintText: hint.toUpperCase(),
          hintStyle: TextStyle(color: _textMuted, letterSpacing: 1, fontSize: 12),
          prefixIcon: Icon(Icons.search, color: _neonCyan.withOpacity(0.6)),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(icon: Icon(Icons.clear, color: _textMuted), onPressed: () { controller.clear(); onChanged(''); })
              : null,
          filled: true,
          fillColor: _darkCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: _neonCyan.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: _neonCyan.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: _neonCyan.withOpacity(0.6)),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
      decoration: BoxDecoration(
        color: _darkCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: _neonCyan.withOpacity(0.5), width: 2)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text((item['name'] ?? 'Item').toString().toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _neonCyan, letterSpacing: 1.5))),
                IconButton(icon: Icon(isStarred ? Icons.star : Icons.star_border, color: isStarred ? _neonMagenta : _textMuted), onPressed: onStar),
              ],
            ),
            const SizedBox(height: 8),
            Text('KES ${item['price'] ?? 0}', style: const TextStyle(fontSize: 18, color: _neonGreen, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (item['description'] != null) Text(item['description'], style: const TextStyle(color: _textMuted)),
            const SizedBox(height: 24),
            Row(
              children: [
                if (phoneNumber != null) Expanded(child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _neonMagenta.withOpacity(0.2), foregroundColor: _neonMagenta, side: BorderSide(color: _neonMagenta.withOpacity(0.5))),
                  onPressed: onCall, icon: const Icon(Icons.call), label: const Text('CALL'))),
                if (phoneNumber != null && locationAddress != null) const SizedBox(width: 12),
                if (locationAddress != null) Expanded(child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: _neonCyan, side: BorderSide(color: _neonCyan.withOpacity(0.5))),
                  onPressed: onDirections, icon: const Icon(Icons.directions), label: const Text('DIRECTIONS'))),
              ],
            )
          ],
        ),
      ),
    );
  }
}
