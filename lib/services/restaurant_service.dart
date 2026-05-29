import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../db/db_provider.dart';
import 'event_service.dart';
import 'security_service.dart';

class RestaurantService {
  /// Completes a restaurant order.
  /// 
  /// [orderId] the ID of the order to complete.
  /// [completedBy] name of the staff member completing it.
  /// [createSaleTransaction] if true, creates a full `txn` financial record for the
  /// entire order amount. Used for auto-completing takeaway orders. If false,
  /// assumes payments were handled separately (e.g., via split_bill_screen).
  static Future<void> completeParentOrder(int orderId, String completedBy, {bool createSaleTransaction = true}) async {
    try {
      final db = await DbProvider.db;
      final orderData = await db.query('restaurant_orders', where: 'id = ?', whereArgs: [orderId], limit: 1);
      if (orderData.isEmpty) return;
      final order = orderData.first;

      int now = DateTime.now().millisecondsSinceEpoch;

      // 1. Mark order as completed
      await db.update(
        'restaurant_orders',
        {'status': 'completed', 'updated_at': now, 'completed_by': completedBy},
        where: 'id = ?',
        whereArgs: [orderId],
      );

      final orderTotal = (order['total'] as num?)?.toDouble() ?? 0;
      final orderNumber = order['order_number']?.toString() ?? '#$orderId';

      final orderItems = await db.query('restaurant_order_items', where: 'order_id = ?', whereArgs: [orderId]);
      final itemsPayload = orderItems.map((item) => {
        'name': item['menu_item_name']?.toString() ?? 'Menu Item',
        'qty': (item['quantity'] as num?)?.toInt() ?? 1,
        'price': (item['unit_price'] as num?)?.toDouble() ?? 0,
        'subtotal': ((item['quantity'] as num?)?.toInt() ?? 1) * ((item['unit_price'] as num?)?.toDouble() ?? 0),
      }).toList();

      final itemSummary = orderItems.map((item) {
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final name = item['menu_item_name']?.toString() ?? 'Item';
        return '${qty}x $name';
      }).join(', ');
      
      final saleDetails = itemSummary.isNotEmpty ? itemSummary : 'Restaurant Order $orderNumber';

      // 2. Create financial transaction if requested
      if (createSaleTransaction) {
        final signature = await SecurityService().signTransaction(
          timestamp: now,
          totalAmount: orderTotal,
          type: 'sale',
          details: 'Restaurant Order $orderNumber',
        );

        int txnId = await db.insert('txn', {
          'type': 'sale',
          'totalAmount': orderTotal,
          'details': saleDetails,
          'timestamp': now,
          'receiptSignature': signature,
          'source_module': 'restaurant',
        });

        for (final item in orderItems) {
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
          await db.insert('transaction_items', {
            'transactionId': txnId,
            'itemId': item['menu_item_id'],
            'item_name': item['menu_item_name']?.toString() ?? 'Menu Item',
            'quantity': qty,
            'unitPrice': unitPrice,
            'subtotal': qty * unitPrice,
          });
        }
        
        // Emit SALE event for the full amount
        await EventService.emitEvent(
          eventType: 'SALE',
          timestamp: now,
          payload: {
            'type': 'sale',
            'source_module': 'restaurant',
            'order_id': orderId,
            'order_number': orderNumber,
            'amount': orderTotal,
            'totalAmount': orderTotal,
            'items': itemsPayload,
            'details': saleDetails,
          },
        );
      } else {
        // Just emit ORDER_UPDATE to inform LAN about the status change
        await EventService.emitEvent(
          eventType: 'ORDER_UPDATE',
          timestamp: now,
          payload: {
            'order_id': orderId,
            'new_status': 'completed',
          },
        );
      }

      // 3. Deduct linked recipes from restaurant_inventory
      for (final item in orderItems) {
        final menuItemId = item['menu_item_id'];
        final orderQty = (item['quantity'] as num?)?.toInt() ?? 1;
        if (menuItemId == null) continue;
        
        final links = await db.query('restaurant_recipes', where: "menu_item_id = ?", whereArgs: [menuItemId]);
        for (final link in links) {
          final invId = link['restaurant_inventory_id'] as int;
          final qtyPerUse = (link['quantity_required'] as num?)?.toDouble() ?? 0;
          final deductAmount = qtyPerUse * orderQty;
          if (deductAmount <= 0) continue;
          
          await db.rawUpdate(
            'UPDATE restaurant_inventory SET stock_level = MAX(0, stock_level - ?), updated_at = ? WHERE id = ?',
            [deductAmount, now, invId],
          );
        }
      }
    } catch (e) {
      debugPrint('RestaurantService error completing order: $e');
    }
  }
}
