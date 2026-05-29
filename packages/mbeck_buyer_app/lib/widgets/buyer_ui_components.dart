import 'package:flutter/material.dart';
import 'package:mbeck_shared/mbeck_shared.dart';

// Import design system from shared package or define locally
// For now, using similar color/spacing constants

/// Design constants for Buyer App (matching Seller App design system)
class BuyerAppColors {
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray900 = Color(0xFF111827);
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
}

class BuyerAppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
}

class BuyerAppRadii {
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double full = 999.0;
}

/// ShopDiscoveryCard - Enhanced card for shop discovery with photo, badges, and distance
class ShopDiscoveryCard extends StatelessWidget {
  final String shopName;
  final String? category;
  final String? distance;
  final bool isOnline;
  final String? photoUrl;
  final VoidCallback onTap;

  const ShopDiscoveryCard({
    super.key,
    required this.shopName,
    this.category,
    this.distance,
    this.isOnline = true,
    this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(
        horizontal: BuyerAppSpacing.md,
        vertical: BuyerAppSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BuyerAppRadii.lg),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BuyerAppRadii.lg),
        child: Container(
          height: 100,
          padding: const EdgeInsets.all(BuyerAppSpacing.md),
          child: Row(
            children: [
              // Shop Photo/Logo
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: BuyerAppColors.gray200,
                  borderRadius: BorderRadius.circular(BuyerAppRadii.md),
                  image: photoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: photoUrl == null
                    ? Icon(
                        Icons.storefront,
                        size: 32,
                        color: BuyerAppColors.gray400,
                      )
                    : null,
              ),
              const SizedBox(width: BuyerAppSpacing.md),
              
              // Shop Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shopName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: BuyerAppColors.gray900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (category != null) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: BuyerAppColors.gray200,
                          borderRadius: BorderRadius.circular(BuyerAppRadii.sm),
                        ),
                        child: Text(
                          category!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: BuyerAppColors.gray600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    
                    // Distance and Online Status Row
                    Row(
                      children: [
                        if (distance != null) ...[
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: BuyerAppColors.gray400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            distance!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: BuyerAppColors.gray600,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        OnlineStatusBadge(isOnline: isOnline),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Arrow indicator
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: BuyerAppColors.gray400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// OnlineStatusBadge - Shows shop's online/offline status
class OnlineStatusBadge extends StatelessWidget {
  final bool isOnline;
  final String? customLabel;

  const OnlineStatusBadge({
    super.key,
    this.isOnline = true,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isOnline ? BuyerAppColors.success : BuyerAppColors.gray400,
        borderRadius: BorderRadius.circular(BuyerAppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            customLabel ?? (isOnline ? 'Online' : 'Offline'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// ProductQuickView - Bottom sheet for quick product preview
class ProductQuickView extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onAddToCart;
  final VoidCallback? onViewDetails;

  const ProductQuickView({
    super.key,
    required this.item,
    required this.onAddToCart,
    this.onViewDetails,
  });

  static void show({
    required BuildContext context,
    required InventoryItem item,
    required VoidCallback onAddToCart,
    VoidCallback? onViewDetails,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ProductQuickView(
        item: item,
        onAddToCart: onAddToCart,
        onViewDetails: onViewDetails,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BuyerAppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BuyerAppRadii.lg * 2),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BuyerAppColors.gray300,
                borderRadius: BorderRadius.circular(BuyerAppRadii.full),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(BuyerAppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: BuyerAppColors.gray100,
                        borderRadius: BorderRadius.circular(BuyerAppRadii.lg),
                        image: item.imagePath != null
                            ? DecorationImage(
                                image: NetworkImage(item.imagePath!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: item.imagePath == null
                          ? Icon(
                              Icons.shopping_bag_outlined,
                              size: 64,
                              color: BuyerAppColors.gray400,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: BuyerAppSpacing.lg),
                  
                  // Product Name
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: BuyerAppColors.gray900,
                    ),
                  ),
                  const SizedBox(height: BuyerAppSpacing.sm),
                  
                  // Category
                  if (item.category != null)
                    Text(
                      item.category!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: BuyerAppColors.gray600,
                      ),
                    ),
                  const SizedBox(height: BuyerAppSpacing.md),
                  
                  // Price and Stock Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'KSH ${item.sellingPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: BuyerAppColors.primaryGreen,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: item.stock > 0
                              ? BuyerAppColors.success.withOpacity(0.1)
                              : BuyerAppColors.gray200,
                          borderRadius: BorderRadius.circular(BuyerAppRadii.full),
                        ),
                        child: Text(
                          item.stock > 0 ? '${item.stock} in stock' : 'Out of stock',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: item.stock > 0
                                ? BuyerAppColors.success
                                : BuyerAppColors.gray600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: BuyerAppSpacing.lg),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: item.stock > 0 ? onAddToCart : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BuyerAppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(BuyerAppRadii.md),
                            ),
                          ),
                          child: const Text(
                            'Add to Cart',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (onViewDetails != null) ...[
                        const SizedBox(width: BuyerAppSpacing.md),
                        OutlinedButton(
                          onPressed: onViewDetails,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            side: const BorderSide(color: BuyerAppColors.gray300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(BuyerAppRadii.md),
                            ),
                          ),
                          child: const Icon(Icons.info_outline),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// SkeletonGridItem - Skeleton loader for product grid
class SkeletonGridItem extends StatelessWidget {
  const SkeletonGridItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BuyerAppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: BuyerAppColors.gray200,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(BuyerAppRadii.lg),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(BuyerAppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title skeleton
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: BuyerAppColors.gray200,
                    borderRadius: BorderRadius.circular(BuyerAppRadii.sm),
                  ),
                ),
                const SizedBox(height: 8),
                // Price skeleton
                Container(
                  height: 14,
                  width: 80,
                  decoration: BoxDecoration(
                    color: BuyerAppColors.gray200,
                    borderRadius: BorderRadius.circular(BuyerAppRadii.sm),
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
