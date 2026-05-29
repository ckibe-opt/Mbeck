import 'package:flutter/foundation.dart';

@immutable
class BatchTransactionItem {
  final int itemId;
  final String itemName;
  final int quantity;
  final int unitPrice;
  final int discount;
  final int subtotal;

  const BatchTransactionItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'discount': discount,
      'subtotal': subtotal,
    };
  }
}
