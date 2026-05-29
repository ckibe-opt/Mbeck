import 'package:flutter/foundation.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import 'inventory_items.dart';

/// Cart Item Model - Represents an item in the shopping cart
/// This is an in-memory model used during transaction creation
@immutable
class CartItem {
  final InventoryItem item;
  final int quantity;
  final double discount; // Per-item discount
  final ProductVariation? selectedVariation;

  const CartItem({
    required this.item,
    required this.quantity,
    this.discount = 0.0,
    this.selectedVariation,
  });

  /// Calculate subtotal for this cart item
  double getSubtotal(String transactionType) {
    return (getUnitPrice(transactionType) * quantity) - discount;
  }

  /// Get unit price based on transaction type
  double getUnitPrice(String transactionType) {
    double basePrice = transactionType == 'outgoing'
        ? item.originalPrice
        : item.sellingPrice;
    
    if (selectedVariation != null) {
      if (transactionType == 'outgoing') {
         // Should ideally have buyPriceModifier, but for now we assume proportional or manual.
         // Let's assume priceModifier applies to selling price mainly.
         // For buying, we might just use base price or we need a better model.
         // BUT for now, let's just add the modifier to be safe/consistent? 
         // Actually, if a 1L bottle costs more to sell, it costs more to buy.
         // Let's add the modifier to both for now to prevent losses.
         basePrice += selectedVariation!.priceModifier;
      } else {
         basePrice += selectedVariation!.priceModifier;
      }
    }
    return basePrice;
  }
  
  String get displayName => selectedVariation != null 
      ? '${item.name} (${selectedVariation!.name})' 
      : item.name;

  CartItem copyWith({
    InventoryItem? item,
    int? quantity,
    double? discount,
    ProductVariation? selectedVariation,
  }) {
    return CartItem(
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      selectedVariation: selectedVariation ?? this.selectedVariation,
    );
  }

  @override
  String toString() {
    return 'CartItem(item: $displayName, qty: $quantity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem &&
        other.item.id == item.id &&
        other.quantity == quantity &&
        other.discount == discount &&
        other.selectedVariation?.id == selectedVariation?.id;
  }

  @override
  int get hashCode => 
    item.id.hashCode ^ 
    quantity.hashCode ^ 
    discount.hashCode ^ 
    selectedVariation.hashCode;
}
