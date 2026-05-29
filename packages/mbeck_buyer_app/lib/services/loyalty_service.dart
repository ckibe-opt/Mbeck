
import 'package:mbeck_go/database/app_database.dart';
import 'package:collection/collection.dart';

class LoyaltyData {
  final String shopId;
  final String shopName;
  final int totalSpend;
  final int visitCount;
  final int points;

  LoyaltyData({
    required this.shopId,
    required this.shopName,
    required this.totalSpend,
    required this.visitCount,
    required this.points,
  });
  
  String get tier {
    if (points > 5000) return 'Gold';
    if (points > 1000) return 'Silver';
    return 'Bronze';
  }
}

class LoyaltyService {
  static final LoyaltyService instance = LoyaltyService._();
  LoyaltyService._();

  /// Calculate loyalty data from a list of receipts
  List<LoyaltyData> calculateDeepLoyalty(List<Receipt> receipts) {
    if (receipts.isEmpty) return [];

    // Group by Seller ID
    final groupByShop = groupBy(receipts, (Receipt r) => r.sellerId);
    
    final List<LoyaltyData> allShops = [];

    groupByShop.forEach((shopId, shopReceipts) {
      if (shopReceipts.isEmpty) return;
      
      final shopName = shopReceipts.first.sellerName;
      final totalSpend = shopReceipts.fold<int>(0, (sum, r) => sum + r.totalAmount);
      final visitCount = shopReceipts.length;
      
      // Math: Points = (Total Spend / 10) + (Visits * 50)
      // "Hard but achievable"
      final points = (totalSpend / 10).floor() + (visitCount * 50);
      
      allShops.add(LoyaltyData(
        shopId: shopId,
        shopName: shopName,
        totalSpend: totalSpend,
        visitCount: visitCount,
        points: points,
      ));
    });

    // We want unique shops for the carousel.
    // Spec: "2 most spent on shops and 3 most frequented shops"
    
    // Sort by Spend (Desc)
    final bySpend = List<LoyaltyData>.from(allShops)
      ..sort((a, b) => b.totalSpend.compareTo(a.totalSpend));
    
    // Take Top 2
    final topSpenders = bySpend.take(2).toList();
    
    // Sort by Frequency (Desc)
    final byFreq = List<LoyaltyData>.from(allShops)
      ..sort((a, b) => b.visitCount.compareTo(a.visitCount));
      
    // Take Top 3 (excluding those already in top spenders to avoid duplicates in carousel?)
    // The prompt implies a combined list, or specific slots. 
    // "What it will show are the 2 most spent on shops and 3 most frequented shops."
    // If a shop is in both, usually it's better to show it once. 
    // I will use a Set to ensure uniqueness.
    
    final Set<LoyaltyData> carouselItems = {};
    carouselItems.addAll(topSpenders);
    
    for (var item in byFreq) {
      if (carouselItems.length >= 5) break; 
      // The requirement asks for 2 spenders + 3 frequent. Total 5 max.
      // If we simply add frequent ones, we might just fill up with duplicates.
      // Let's add them. Set prevents duplicates.
      carouselItems.add(item);
    }
    
    // Convert back to list and maybe sort by points for display?
    // Or keep the order: Spenders first, then Frequent.
    return carouselItems.toList();
  }
}
