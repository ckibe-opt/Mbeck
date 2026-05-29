import 'package:flutter/foundation.dart';

/// Represents a product variation (e.g., different sizes, volumes, or configurations)
/// 
/// Example: A Milk product might have variations:
/// - 500ml (priceModifier: 0)
/// - 1L (priceModifier: 50)
/// - 2L (priceModifier: 120)
@immutable
class ProductVariation {
  final int? id;
  final String name;          // "500ml", "1L", "Large", "XL", etc.
  final double priceModifier; // Additional price for this variation (can be negative for discounts)
  final int stock;            // Stock for this specific variation
  final String? sku;          // Optional SKU code for this variation

  const ProductVariation({
    this.id,
    required this.name,
    this.priceModifier = 0.0,
    this.stock = 0,
    this.sku,
  });

  factory ProductVariation.fromMap(Map<String, dynamic> map) {
    return ProductVariation(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      priceModifier: (map['priceModifier'] as num?)?.toDouble() ?? 
                     (map['price_modifier'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      sku: map['sku'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'priceModifier': priceModifier,
      'stock': stock,
      'sku': sku,
    };
  }

  ProductVariation copyWith({
    int? id,
    String? name,
    double? priceModifier,
    int? stock,
    String? sku,
  }) {
    return ProductVariation(
      id: id ?? this.id,
      name: name ?? this.name,
      priceModifier: priceModifier ?? this.priceModifier,
      stock: stock ?? this.stock,
      sku: sku ?? this.sku,
    );
  }

  /// Calculate the final price given a base price
  double finalPrice(double basePrice) => basePrice + priceModifier;

  @override
  String toString() {
    return 'ProductVariation(id: $id, name: $name, priceModifier: $priceModifier, stock: $stock)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductVariation &&
        other.id == id &&
        other.name == name &&
        other.priceModifier == priceModifier &&
        other.stock == stock &&
        other.sku == sku;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      priceModifier.hashCode ^
      stock.hashCode ^
      sku.hashCode;
}
