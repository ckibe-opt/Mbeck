import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Global Search Service for Buyer App
/// Enables cross-shop discovery of products, services, and menu items
class GlobalSearchService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Unified search result model
  static SearchResult _mapToResult(Map<String, dynamic> data, String type) {
    return SearchResult(
      id: data['id']?.toString() ?? '',
      shopId: data['shop_id'] ?? '',
      shopName: data['shops']?['name'] ?? 'Unknown Shop',
      itemName: data['name'] ?? data['service_name'] ?? data['item_name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? data['sellingPrice'] ?? 0).toDouble(),
      type: type,
      category: data['category'] ?? '',
      imageUrl: data['image_url'],
      isAvailable: data['is_available'] ?? true,
      extraData: {
        if (data['duration_minutes'] != null) 'duration': data['duration_minutes'],
        if (data['preparation_time_mins'] != null) 'prepTime': data['preparation_time_mins'],
        if (data['stock_level'] != null) 'stock': data['stock_level'],
      },
    );
  }

  /// Search retail products across all published shops
  static Future<List<SearchResult>> searchProducts(String query) async {
    try {
      if (query.trim().isEmpty) return [];

      final response = await _supabase
          .from('inventory')
          .select('*, shops!inner(name)')
          .ilike('name', '%$query%')
          .eq('is_published', true)
          .limit(50);

      return (response as List)
          .map((r) => _mapToResult(r, 'product'))
          .toList();
    } catch (e) {
      debugPrint('❌ Product search error: $e');
      return [];
    }
  }

  /// Search services across all published service providers
  static Future<List<SearchResult>> searchServices(String query) async {
    try {
      if (query.trim().isEmpty) return [];

      final response = await _supabase
          .from('services_catalog')
          .select('*, shops!inner(name)')
          .ilike('service_name', '%$query%')
          .eq('is_published', true)
          .limit(50);

      return (response as List)
          .map((r) => _mapToResult(r, 'service'))
          .toList();
    } catch (e) {
      debugPrint('❌ Service search error: $e');
      return [];
    }
  }

  /// Search restaurant menu items across all published restaurants
  static Future<List<SearchResult>> searchMenuItems(String query) async {
    try {
      if (query.trim().isEmpty) return [];

      final response = await _supabase
          .from('restaurant_menu')
          .select('*, shops!inner(name)')
          .ilike('item_name', '%$query%')
          .eq('is_published', true)
          .eq('is_available', true)
          .limit(50);

      return (response as List)
          .map((r) => _mapToResult(r, 'menu_item'))
          .toList();
    } catch (e) {
      debugPrint('❌ Menu search error: $e');
      return [];
    }
  }

  /// Unified search across all modules
  static Future<List<SearchResult>> searchAll(String query) async {
    if (query.trim().length < 2) return [];

    try {
      // Run all searches in parallel
      final results = await Future.wait([
        searchProducts(query),
        searchServices(query),
        searchMenuItems(query),
      ]);

      // Combine and sort by relevance (name match priority)
      final allResults = [
        ...results[0],
        ...results[1],
        ...results[2],
      ];

      // Sort: exact matches first, then by name
      allResults.sort((a, b) {
        final aExact = a.itemName.toLowerCase() == query.toLowerCase();
        final bExact = b.itemName.toLowerCase() == query.toLowerCase();
        if (aExact && !bExact) return -1;
        if (bExact && !aExact) return 1;
        return a.itemName.compareTo(b.itemName);
      });

      return allResults;
    } catch (e) {
      debugPrint('❌ Global search error: $e');
      return [];
    }
  }

  /// Get nearby shops by module type
  static Future<List<ShopInfo>> getShopsByModule(String moduleType) async {
    try {
      final response = await _supabase
          .from('shops')
          .select('id, name, shop_type, enabled_modules')
          .contains('enabled_modules', [moduleType])
          .limit(50);

      return (response as List)
          .map((s) => ShopInfo(
                id: s['id'],
                name: s['name'],
                shopType: s['shop_type'],
                enabledModules: List<String>.from(s['enabled_modules'] ?? []),
              ))
          .toList();
    } catch (e) {
      debugPrint('❌ Shops by module error: $e');
      return [];
    }
  }

  /// Get featured items from a specific shop
  static Future<List<SearchResult>> getShopCatalog(String shopId, String moduleType) async {
    try {
      List<SearchResult> results = [];

      switch (moduleType) {
        case 'retail':
          final products = await _supabase
              .from('inventory')
              .select('*, shops!inner(name)')
              .eq('shop_id', shopId)
              .eq('is_published', true)
              .limit(100);
          results = (products as List).map((r) => _mapToResult(r, 'product')).toList();
          break;

        case 'services':
          final services = await _supabase
              .from('services_catalog')
              .select('*, shops!inner(name)')
              .eq('shop_id', shopId)
              .eq('is_published', true)
              .limit(100);
          results = (services as List).map((r) => _mapToResult(r, 'service')).toList();
          break;

        case 'restaurant':
          final menu = await _supabase
              .from('restaurant_menu')
              .select('*, shops!inner(name)')
              .eq('shop_id', shopId)
              .eq('is_published', true)
              .eq('is_available', true)
              .limit(100);
          results = (menu as List).map((r) => _mapToResult(r, 'menu_item')).toList();
          break;
      }

      return results;
    } catch (e) {
      debugPrint('❌ Shop catalog error: $e');
      return [];
    }
  }
}

/// Unified search result model
class SearchResult {
  final String id;
  final String shopId;
  final String shopName;
  final String itemName;
  final String description;
  final double price;
  final String type; // 'product', 'service', 'menu_item'
  final String category;
  final String? imageUrl;
  final bool isAvailable;
  final Map<String, dynamic> extraData;

  SearchResult({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.itemName,
    required this.description,
    required this.price,
    required this.type,
    this.category = '',
    this.imageUrl,
    this.isAvailable = true,
    this.extraData = const {},
  });

  String get formattedPrice => 'KES ${price.toStringAsFixed(0)}';

  String get typeLabel {
    switch (type) {
      case 'product':
        return 'Product';
      case 'service':
        return 'Service';
      case 'menu_item':
        return 'Menu Item';
      default:
        return 'Item';
    }
  }
}

/// Shop info model
class ShopInfo {
  final String id;
  final String name;
  final String shopType;
  final List<String> enabledModules;

  ShopInfo({
    required this.id,
    required this.name,
    required this.shopType,
    required this.enabledModules,
  });

  bool hasModule(String module) => enabledModules.contains(module);
}
