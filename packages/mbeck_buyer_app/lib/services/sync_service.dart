import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' as drift;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'database_service.dart';
import 'order_service.dart';
import '../database/app_database.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  late AppDatabase _db;
  late SupabaseClient _supabase;
  bool _isSyncing = false;

  SyncService._init() {
    _db = DatabaseService.instance.db;
    _supabase = Supabase.instance.client;
    
    // Listen to network changes
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        syncPendingReceipts();
        syncPendingOrders();
      }
    });
  }

  /// Triggers a sync of all unsynced receipts and orders
  Future<void> syncPendingReceipts() async {
    if (_isSyncing) return;
    _isSyncing = true;
    debugPrint('🔄 Sync: Starting sync...');

    try {
      // 1. Sync Receipts
      final unsyncedReceipts = await (_db.select(_db.receipts)..where((t) => t.isSynced.equals(false))).get();
      for (final receipt in unsyncedReceipts) {
        await _uploadReceipt(receipt);
      }
      
    } catch (e) {
      debugPrint('❌ Sync Error: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Triggers a sync of all unsynced orders
  Future<void> syncPendingOrders() async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    try {
      final pendingOrders = await OrderService.getPendingOrders();
      if (pendingOrders.isNotEmpty) {
        debugPrint('🔄 Sync: Found ${pendingOrders.length} pending orders');
        for (final order in pendingOrders) {
          await _uploadOrder(order);
        }
      }
    } catch (e) {
      debugPrint('❌ Order Sync Error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _uploadReceipt(Receipt receipt) async {
    try {
      // 1. Upload to Supabase 'receipts' table
      await _supabase.from('receipts').insert({
        'id': receipt.id,
        'seller_id': receipt.sellerId,
        'seller_name': receipt.sellerName,
        'items_json': receipt.itemsJson,
        'total_amount': receipt.totalAmount,
        'created_at': receipt.timestamp.toIso8601String(),
        'signature': receipt.signature,
        'module': receipt.module,
      });

      // 2. Mark as synced locally
      await (_db.update(_db.receipts)..where((t) => t.id.equals(receipt.id))).write(
        ReceiptsCompanion(isSynced: drift.Value(true)),
      );
      
      debugPrint('✅ Sync: Uploaded Receipt ${receipt.id}');
    } catch (e) {
      debugPrint('⚠️ Sync: Failed to upload receipt ${receipt.id}: $e');
    }
  }
  
  Future<void> _uploadOrder(Order order) async {
    try {
      // 1. Upload to Supabase 'orders' table
      await _supabase.from('orders').insert({
        'id': order.id,
        'shop_id': order.shopId,
        'items_json': order.itemsJson,
        'total_amount': order.totalAmount,
        'created_at': order.createdAt.toIso8601String(),
        'status': 'pending',
        'source': 'buyer_app',
        'module': order.module,
      });

      // 2. Mark as synced locally
      await OrderService.markAsSynced(order.id);
      
      debugPrint('✅ Sync: Uploaded Order ${order.id}');
    } catch (e) {
      debugPrint('⚠️ Sync: Failed to upload order ${order.id}: $e');
    }
  }
}
