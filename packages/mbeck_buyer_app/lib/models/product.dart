import 'dart:convert';
import 'package:mbeck_shared/src/models/product_variation.dart';

/// Product model for buyer app
class Product {
  final int id;
  final String name;
  final String? category;
  final double price;
  final double? originalPrice; // NEW: Added for discounts
  final int stock;
  final String? imagePath;
  final String? specification;
  final String? barcode;
  final String? variationsJson; // NEW: Added for variants

  Product({
    required this.id,
    required this.name,
    this.category,
    required this.price,
    this.originalPrice,
    required this.stock,
    this.imagePath,
    this.specification,
    this.barcode,
    this.variationsJson,
  });

  /// Get parsed variations list
  List<ProductVariation> get variations {
    if (variationsJson == null || variationsJson!.isEmpty) return [];
    try {
      final List decoded = jsonDecode(variationsJson!);
      return decoded.map((e) => ProductVariation.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Create from JSON (from LAN API or vector service)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String?,
      price: (json['price'] ?? json['sellingPrice'] ?? 0).toDouble(),
      originalPrice: (json['originalPrice'] as num?)?.toDouble(),
      stock: json['stock'] as int? ?? 0,
      imagePath: json['imagePath'] as String?,
      specification: json['specification'] as String?,
      barcode: json['barcode'] as String?,
      variationsJson: json['variationsJson'] as String?,
    );
  }

  /// Convert to JSON (for cart storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'originalPrice': originalPrice,
      'stock': stock,
      'imagePath': imagePath,
      'specification': specification,
      'barcode': barcode,
      'variationsJson': variationsJson,
    };
  }

  /// Check if product is in stock
  bool get isInStock => stock > 0;

  /// Check if stock is low (less than 5)
  bool get isLowStock => stock > 0 && stock < 5;

  /// Formatted price string
  String get formattedPrice => 'Ksh ${price.toStringAsFixed(2)}';

  @override
  String toString() => 'Product($id: $name, $formattedPrice, stock: $stock, variations: ${variations.length})';
}

/// Shop model for discovered shops
class Shop {
  final String name;
  final String ip;
  final int port;
  final String? shopId;
  final String? cloudId;
  final String? category;
  final String version;

  Shop({
    required this.name,
    required this.ip,
    required this.port,
    this.shopId,
    this.cloudId,
    this.category,
    this.version = '1.0.0',
  });

  /// Base URL for API requests
  String get baseUrl => 'http://$ip:$port';

  /// Status endpoint
  String get statusUrl => '$baseUrl/api/v1/status';

  /// Inventory endpoint
  String get inventoryUrl => '$baseUrl/api/v1/inventory/public';

  /// Vectors endpoint (for AI matching)
  String get vectorsUrl => '$baseUrl/api/v1/vectors';

  /// Display name for UI
  String get displayName => name.isNotEmpty ? name : 'Shop ${shopId ?? ip}';

  @override
  String toString() => 'Shop($displayName, $ip:$port)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Shop &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;
}
