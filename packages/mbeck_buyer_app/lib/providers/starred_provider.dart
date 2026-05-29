import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A starred/bookmarked item from the marketplace.
/// Allows buyers to save items they want to revisit later.
class StarredItem {
  final String id;
  final String name;
  final String module;       // 'retail', 'restaurant', 'services', etc.
  final double price;
  final String? imagePath;
  final String? category;
  final String? description;
  final String shopId;
  final String shopName;
  final DateTime starredAt;

  StarredItem({
    required this.id,
    required this.name,
    required this.module,
    required this.price,
    this.imagePath,
    this.category,
    this.description,
    required this.shopId,
    required this.shopName,
    DateTime? starredAt,
  }) : starredAt = starredAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'module': module,
    'price': price,
    'image_path': imagePath,
    'category': category,
    'description': description,
    'shop_id': shopId,
    'shop_name': shopName,
    'starred_at': starredAt.toIso8601String(),
  };

  factory StarredItem.fromJson(Map<String, dynamic> json) => StarredItem(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    module: json['module'] ?? 'retail',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    imagePath: json['image_path'],
    category: json['category'],
    description: json['description'],
    shopId: json['shop_id'] ?? '',
    shopName: json['shop_name'] ?? '',
    starredAt: json['starred_at'] != null
        ? DateTime.tryParse(json['starred_at']) ?? DateTime.now()
        : DateTime.now(),
  );
}

/// Provider for managing starred/bookmarked items.
/// Persisted locally via SharedPreferences.
class StarredProvider extends ChangeNotifier {
  static const _storageKey = 'starred_items';
  final List<StarredItem> _items = [];

  List<StarredItem> get items => List.unmodifiable(_items);
  int get count => _items.length;

  StarredProvider() {
    _load();
  }

  /// Check if an item is starred
  bool isStarred(String itemId, String shopId) {
    return _items.any((i) => i.id == itemId && i.shopId == shopId);
  }

  /// Toggle star status
  void toggle({
    required String id,
    required String name,
    required String module,
    required double price,
    String? imagePath,
    String? category,
    String? description,
    required String shopId,
    required String shopName,
  }) {
    final existing = _items.indexWhere((i) => i.id == id && i.shopId == shopId);
    if (existing >= 0) {
      _items.removeAt(existing);
    } else {
      _items.insert(0, StarredItem(
        id: id,
        name: name,
        module: module,
        price: price,
        imagePath: imagePath,
        category: category,
        description: description,
        shopId: shopId,
        shopName: shopName,
      ));
    }
    _save();
    notifyListeners();
  }

  /// Remove a starred item
  void remove(String itemId, String shopId) {
    _items.removeWhere((i) => i.id == itemId && i.shopId == shopId);
    _save();
    notifyListeners();
  }

  /// Get starred items for a specific shop
  List<StarredItem> forShop(String shopId) {
    return _items.where((i) => i.shopId == shopId).toList();
  }

  /// Get starred items for a specific module
  List<StarredItem> forModule(String module) {
    return _items.where((i) => i.module == module).toList();
  }

  /// Clear all starred items
  void clearAll() {
    _items.clear();
    _save();
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final List decoded = jsonDecode(raw);
        _items.clear();
        _items.addAll(decoded.map((e) => StarredItem.fromJson(e)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load starred items: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_items.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('⚠️ Failed to save starred items: $e');
    }
  }
}
