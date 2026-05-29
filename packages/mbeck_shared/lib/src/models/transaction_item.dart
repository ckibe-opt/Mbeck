import 'package:flutter/foundation.dart';

/// Transaction Item Model - Represents a single line item in a transaction
/// 
/// This model represents the normalized structure for transaction line items.
/// A transaction header can contain multiple transaction items.
@immutable
class TransactionItem {
  final int? id;
  final int transactionId; // Foreign key to transaction_headers (txn table)
  final int itemId; // Foreign key to inventory
  final int quantity;
  final int unitPrice;
  final int subtotal; // quantity * unitPrice (calculated)
  final int discount; // Optional discount per line item

  const TransactionItem({
    this.id,
    required this.transactionId,
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.discount = 0,
  });

  factory TransactionItem.fromMap(Map<String, dynamic> m) => TransactionItem(
        id: m['id'] as int?,
        transactionId: m['transactionId'] as int? ?? m['transaction_id'] as int? ?? 0,
        itemId: m['itemId'] as int? ?? m['item_id'] as int? ?? m['itemId'] as int? ?? 0,
        quantity: m['quantity'] as int? ?? 0,
        unitPrice: m['unitPrice'] as int? ?? m['unit_price'] as int? ?? 0,
        subtotal: m['subtotal'] as int? ?? 0,
        discount: m['discount'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'transactionId': transactionId,
        'itemId': itemId,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'subtotal': subtotal,
        'discount': discount,
      };

  /// Calculate subtotal from quantity and unitPrice
  int get calculatedSubtotal => (quantity * unitPrice) - discount;

  TransactionItem copyWith({
    int? id,
    int? transactionId,
    int? itemId,
    int? quantity,
    int? unitPrice,
    int? subtotal,
    int? discount,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
    );
  }

  @override
  String toString() {
    return 'TransactionItem(id: $id, transactionId: $transactionId, itemId: $itemId, qty: $quantity, unitPrice: $unitPrice, subtotal: $subtotal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TransactionItem &&
        other.id == id &&
        other.transactionId == transactionId &&
        other.itemId == itemId &&
        other.quantity == quantity &&
        other.unitPrice == unitPrice &&
        other.subtotal == subtotal &&
        other.discount == discount;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      transactionId.hashCode ^
      itemId.hashCode ^
      quantity.hashCode ^
      unitPrice.hashCode ^
      subtotal.hashCode ^
      discount.hashCode;
}
