import '../models/shop.dart';

/// Enterprise metrics for a single shop (cloud-based)
class EnterpriseMetrics {
  final Shop shop;
  final double todaySales;
  final int todayTxnCount;
  final String? topItem;
  // Module-specific revenue
  final double retailRevenue;
  final double restaurantRevenue;
  final double servicesRevenue;
  final double entertainmentRevenue;
  final double lodgingRevenue;
  // Active counts
  final int pendingOrders;
  final int activeSessions;
  final int activeStays;
  final int todayBookings;
  final List<String> enabledModules;

  EnterpriseMetrics({
    required this.shop,
    this.todaySales = 0,
    this.todayTxnCount = 0,
    this.topItem,
    this.retailRevenue = 0,
    this.restaurantRevenue = 0,
    this.servicesRevenue = 0,
    this.entertainmentRevenue = 0,
    this.lodgingRevenue = 0,
    this.pendingOrders = 0,
    this.activeSessions = 0,
    this.activeStays = 0,
    this.todayBookings = 0,
    this.enabledModules = const [],
  });

  /// Get total revenue across all modules
  double get totalRevenue => 
      retailRevenue + restaurantRevenue + servicesRevenue + 
      entertainmentRevenue + lodgingRevenue;

  /// Check if shop has any active operations
  bool get hasActivity => 
      todayTxnCount > 0 || pendingOrders > 0 || 
      activeSessions > 0 || activeStays > 0 || todayBookings > 0;

  /// Get module-specific activity status
  bool get hasRetailActivity => retailRevenue > 0;
  bool get hasRestaurantActivity => restaurantRevenue > 0 || pendingOrders > 0;
  bool get hasServicesActivity => servicesRevenue > 0 || todayBookings > 0;
  bool get hasEntertainmentActivity => entertainmentRevenue > 0 || activeSessions > 0;
  bool get hasLodgingActivity => lodgingRevenue > 0 || activeStays > 0;

  /// Get formatted sales amount
  String get formattedSales {
    if (todaySales >= 1000000) {
      return '${(todaySales / 1000000).toStringAsFixed(1)}M';
    } else if (todaySales >= 1000) {
      return '${(todaySales / 1000).toStringAsFixed(1)}K';
    }
    return todaySales.toStringAsFixed(0);
  }

  /// Get primary module (highest revenue)
  String get primaryModule {
    final revenues = {
      'retail': retailRevenue,
      'restaurant': restaurantRevenue,
      'services': servicesRevenue,
      'entertainment': entertainmentRevenue,
      'lodging': lodgingRevenue,
    };
    
    return revenues.entries
        .where((e) => e.value > 0)
        .reduce((a, b) => a.value > b.value ? a : b)
        .key
        .toString();
  }

  /// Convert to map for JSON serialization
  Map<String, dynamic> toMap() {
    return {
      'shop': shop.toMap(),
      'todaySales': todaySales,
      'todayTxnCount': todayTxnCount,
      'topItem': topItem,
      'retailRevenue': retailRevenue,
      'restaurantRevenue': restaurantRevenue,
      'servicesRevenue': servicesRevenue,
      'entertainmentRevenue': entertainmentRevenue,
      'lodgingRevenue': lodgingRevenue,
      'pendingOrders': pendingOrders,
      'activeSessions': activeSessions,
      'activeStays': activeStays,
      'todayBookings': todayBookings,
      'enabledModules': enabledModules,
    };
  }

  /// Create from map
  factory EnterpriseMetrics.fromMap(Map<String, dynamic> map) {
    return EnterpriseMetrics(
      shop: Shop.fromMap(map['shop']),
      todaySales: (map['todaySales'] as num?)?.toDouble() ?? 0,
      todayTxnCount: (map['todayTxnCount'] as num?)?.toInt() ?? 0,
      topItem: map['topItem'] as String?,
      retailRevenue: (map['retailRevenue'] as num?)?.toDouble() ?? 0,
      restaurantRevenue: (map['restaurantRevenue'] as num?)?.toDouble() ?? 0,
      servicesRevenue: (map['servicesRevenue'] as num?)?.toDouble() ?? 0,
      entertainmentRevenue: (map['entertainmentRevenue'] as num?)?.toDouble() ?? 0,
      lodgingRevenue: (map['lodgingRevenue'] as num?)?.toDouble() ?? 0,
      pendingOrders: (map['pendingOrders'] as num?)?.toInt() ?? 0,
      activeSessions: (map['activeSessions'] as num?)?.toInt() ?? 0,
      activeStays: (map['activeStays'] as num?)?.toInt() ?? 0,
      todayBookings: (map['todayBookings'] as num?)?.toInt() ?? 0,
      enabledModules: List<String>.from(map['enabledModules'] ?? []),
    );
  }

  @override
  String toString() {
    return 'EnterpriseMetrics(shop: ${shop.businessName}, sales: $formattedSales, transactions: $todayTxnCount)';
  }
}
