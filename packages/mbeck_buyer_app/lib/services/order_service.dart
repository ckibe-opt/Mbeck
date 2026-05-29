import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'database_service.dart';
import 'shop_api_service.dart';
import '../providers/cart_provider.dart';

class OrderService {
  static const Uuid _uuid = Uuid();

  /// Create an order from the current cart
  /// 
  /// Tries to submit online first. If it fails due to network issues,
  /// saves it locally as PendingSync.
  static Future<Map<String, dynamic>> createOrder({
    required String shopId,
    required List<CartItem> items,
    required double totalAmount,
    required ShopApiService apiService,
    String? module,
  }) async {
    final orderId = _uuid.v4();
    
    // Full items JSON for offline storage — includes variation AND modifiers
    final itemsJson = jsonEncode(items.map((i) => {
      'id': i.item.id,
      'name': i.item.name,
      'qty': i.quantity,
      'price': i.effectivePrice,
      'total': i.total,
      'variation_id': i.selectedVariation?.id,
      'variation_name': i.selectedVariation?.name,
      'modifiers': i.selectedModifiers ?? [],
    }).toList());

    // 1. Try Online Submission
    try {
      final orderData = items.map((i) => {
        'id': i.item.id,
        'qty': i.quantity,
        'variation_id': i.selectedVariation?.id,
      }).toList();

      final result = await apiService.checkout(orderData);
      
      // If successful, save as COMPLETED (for history)
      await _saveOrder(
        id: orderId,
        shopId: shopId,
        total: totalAmount,
        items: itemsJson,
        status: 2, // Completed
        module: module,
      );
      
      return {'success': true, 'offline': false, 'data': result};
      
    } catch (e) {
      // 2. Fallback to Offline
      // We only fallback if it's a network/timeout error. 
      final isNetworkError = e.toString().toLowerCase().contains('connection') || 
                             e.toString().toLowerCase().contains('socket') ||
                             e.toString().toLowerCase().contains('timeout') ||
                             e.toString().toLowerCase().contains('clientexception');

      if (isNetworkError) {
        debugPrint('⚠️ Online checkout failed: $e');
        debugPrint('💾 Saving order offline...');
        
        await _saveOrder(
          id: orderId,
          shopId: shopId,
          total: totalAmount,
          items: itemsJson,
          status: 0, // PendingSync
          module: module,
        );

        return {
          'success': true, 
          'offline': true, 
          'message': 'Order saved offline. Will sync when online.',
          'orderId': orderId,
        };
      } else {
        rethrow; // Re-throw logic errors (e.g. "Shop Rejected: Out of Stock")
      }
    }
  }

  static Future<void> _saveOrder({
    required String id,
    required String shopId,
    required double total,
    required String items,
    required int status,
    String? module,
  }) async {
    final db = DatabaseService.instance.db;
    await db.into(db.orders).insert(OrdersCompanion(
      id: Value(id),
      shopId: Value(shopId),
      totalAmount: Value(total),
      status: Value(status),
      itemsJson: Value(items),
      createdAt: Value(DateTime.now()),
      module: Value(module),
    ));
  }
  
  /// Get pending orders to sync
  static Future<List<Order>> getPendingOrders() async {
    final db = DatabaseService.instance.db;
    return (db.select(db.orders)..where((t) => t.status.equals(0))).get();
  }
  
  /// Mark order as synced
  static Future<void> markAsSynced(String orderId) async {
    final db = DatabaseService.instance.db;
    await (db.update(db.orders)..where((t) => t.id.equals(orderId))).write(
      const OrdersCompanion(status: Value(1)),
    );
  }
}
