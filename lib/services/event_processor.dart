import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../db/db_provider.dart';
import 'device_service.dart';
import 'auth_service.dart';
import 'performance_monitor.dart'; // Fixed import path
import 'package:supabase_flutter/supabase_flutter.dart';

/// Processor for applying remote events to the local database
/// 
/// This allows the app to reconstruct state from events synced from other devices.
class EventProcessor {
  /// Stream of successfully processed event types
  static final StreamController<String> _eventStream = StreamController.broadcast();
  static Stream<String> get events => _eventStream.stream;

  /// Manually notify listeners of an event (used for local events)
  static void notify(String eventType) {
    debugPrint('🔔 EventProcessor: Manual notification: $eventType');
    _eventStream.add(eventType);
  }

  // Cached values to avoid repeated async lookups per event
  static String? _cachedDeviceId;
  static String? _cachedRole;
  static DateTime? _cacheTime;
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Apply a remote event to the local database
  /// returns true if applied, false if skipped/failed
  static Future<bool> processEvent(Event event) async {
    PerformanceMonitor().startTrace('EventProcessor.processEvent');
    try {
      // Refresh cache if stale
      final now = DateTime.now();
      if (_cacheTime == null || now.difference(_cacheTime!) > _cacheTtl) {
        _cachedDeviceId = await DeviceService.getDeviceId();
        final member = await AuthService.getCurrentMember();
        _cachedRole = member?.role;
        _cacheTime = now;
      }

      // 1. Skip domain logic for our own events (caller already applied it)
      // BUT notify the stream so UI can refresh if needed
      if (event.deviceId == _cachedDeviceId) {
        debugPrint('🏠 EventProcessor: Skipping local event application, but notifying listeners: ${event.eventType}');
        _eventStream.add(event.eventType);
        return false; 
      }

      // 1.5 Defense-in-Depth: Verify user has permission to receive this event type
      if (!_isEventAuthorizedForRole(event.eventType, _cachedRole)) {
        debugPrint('🚫 Blocked unauthorized event: ${event.eventType} for role: $_cachedRole');
        return false;
      }

      // 2. Check if already processed (idempotency check)
      // We assume if it's in the events table with 'synced=1', we handled it.
      // But we need to insert it into events table anyway to maintain the Ledger.
      final db = await DbProvider.db;
      final existing = await db.query('events', where: 'id = ?', whereArgs: [event.id]);
      if (existing.isNotEmpty) {
        return false; // Already have this event
      }

      // 3. Insert into Ledger (Events Table)
      // We mark it as 'synced=1' because it came FROM the cloud.
      // Use INSERT OR IGNORE to gracefully handle race conditions where
      // duplicate SYNC_EVENTs arrive near-simultaneously.
      final eventMap = event.toMap();
      eventMap['synced'] = 1;
      final columns = eventMap.keys.join(', ');
      final placeholders = eventMap.keys.map((_) => '?').join(', ');
      await db.rawInsert(
        'INSERT OR IGNORE INTO events ($columns) VALUES ($placeholders)',
        eventMap.values.toList(),
      );

      // 4. Update Domain Models (Projector)
      await applyEffect(event);
      
      PerformanceMonitor().endTrace('EventProcessor.processEvent', metadata: {'type': event.eventType});
      
    // Notify listeners (UI) that data has changed
    debugPrint('🔔 EventProcessor: Emitting event to stream: ${event.eventType}');
    _eventStream.add(event.eventType);
    
    return true;
    } catch (e) {
      debugPrint('❌ Error processing remote event ${event.id}: $e');
      PerformanceMonitor().endTrace('EventProcessor.processEvent', metadata: {'error': e.toString()});
      return false;
    }
  }

  /// Check if a role is authorized to receive a specific event type
  /// Matches the filtering logic in SyncService for consistency
  static bool _isEventAuthorizedForRole(String eventType, String? role) {
    if (role == null) return eventType == 'SALE'; // No role = sales only

    switch (role.toUpperCase()) {
      case 'OWNER':
      case 'MANAGER':
        return true; // Owners/Managers see everything
      
      case 'CASHIER':
      case 'STAFF':
        // Staff see sales, inventory, customers, restaurant, services, entertainment, lodging, settings
        return [
          'SALE',
          'INVENTORY_CHANGE',
          'INVENTORY_CREATE',
          'INVENTORY_UPDATE',
          'INVENTORY_DELETE',
          'CUSTOMER_CREATE',
          'CUSTOMER_UPDATE',
          'ORDER_CREATED',
          'ORDER_STATUS_CHANGE',
          'ORDER_UPDATE',
          'TABLE_TRANSFER',
          'MENU_CREATE',
          'MENU_UPDATE',
          'MENU_DELETE',
          'SETTINGS_UPDATE',
          'SERVICE_CREATE',
          'SERVICE_UPDATE',
          'SERVICE_DELETE',
          'BOOKING_CREATED',
          'BOOKING_STATUS_CHANGE',
          'ENTERTAINMENT_ASSET_CREATE',
          'ENTERTAINMENT_ASSET_UPDATE',
          'ENTERTAINMENT_SESSION_START',
          'ENTERTAINMENT_SESSION_COMPLETE',
          'LODGING_ROOM_CREATE',
          'LODGING_ROOM_UPDATE',
          'LODGING_ROOM_DELETE',
          'LODGING_RESERVATION_CREATE',
          'LODGING_RESERVATION_STATUS',
          'LODGING_CHECK_IN',
          'LODGING_CHECK_OUT',
          'FLOOR_PLAN_UPDATE',
          'TEST_LAN_SYNC', // Added for LAN sync testing
        ].contains(eventType);
      
      default:
        return eventType == 'SALE'; // Unknown roles = minimal access
    }
  }

  /// The Projector: updates materialized views (Tables) based on event
  static Future<void> applyEffect(Event event) async {
    final payload = event.payload;

    switch (event.eventType) {
      // === Financial Events ===
      case 'SALE':
      case 'INCOME':
      case 'EXPENSE':
      case 'CASH_COUNT_ENTRY':
        await _processTransaction(event.eventType, payload, event.timestamp, cloudId: event.id);
        break;
        
      // === Inventory Events ===
      case 'INVENTORY_CHANGE':
        await _processStockChange(payload);
        break;
      case 'INVENTORY_CREATE':
        await _processInventoryCreate(payload);
        break;
      case 'INVENTORY_UPDATE':
         await _processInventoryUpdate(payload);
         break;
      case 'INVENTORY_DELETE':
         await _processInventoryDelete(payload);
         break;

      // === Restaurant Order Events ===
      case 'ORDER_CREATED':
        await _processOrderCreated(payload);
        break;
      case 'ORDER_STATUS_CHANGE':
        await _processOrderStatusChange(payload, event.timestamp);
        break;
      case 'ORDER_UPDATE':
        await _processOrderUpdate(payload, event.timestamp);
        break;
      case 'TABLE_TRANSFER':
        await _processTableTransfer(payload, event.timestamp);
        break;

      // === Menu Events ===
      case 'MENU_CREATE':
        await _processMenuCreate(payload);
        break;
      case 'MENU_UPDATE':
        await _processMenuUpdate(payload);
        break;
      case 'MENU_DELETE':
        await _processMenuDelete(payload);
        break;

      // === Settings Events ===
      case 'SETTINGS_UPDATE':
        await _processSettingsUpdate(payload);
        break;

      // === Service Events ===
      case 'SERVICE_CREATE':
        await _processServiceCreate(payload);
        break;
      case 'SERVICE_UPDATE':
        await _processServiceUpdate(payload);
        break;
      case 'SERVICE_DELETE':
        await _processServiceDelete(payload);
        break;

      // === Booking Events ===
      case 'BOOKING_CREATED':
        await _processBookingCreated(payload);
        break;
      case 'BOOKING_STATUS_CHANGE':
        await _processBookingStatusChange(payload);
        break;

      // === Entertainment Events ===
      case 'ENTERTAINMENT_ASSET_CREATE':
        await _processEntertainmentAssetCreate(payload);
        break;
      case 'ENTERTAINMENT_ASSET_UPDATE':
        await _processEntertainmentAssetUpdate(payload);
        break;
      case 'ENTERTAINMENT_SESSION_START':
        await _processEntertainmentSessionStart(payload);
        break;
      case 'ENTERTAINMENT_SESSION_COMPLETE':
        await _processEntertainmentSessionComplete(payload, event.timestamp);
        break;

      // === Lodging Events ===
      case 'LODGING_ROOM_CREATE':
        await _processLodgingRoomCreate(payload);
        break;
      case 'LODGING_ROOM_UPDATE':
        await _processLodgingRoomUpdate(payload);
        break;
      case 'LODGING_ROOM_DELETE':
        await _processLodgingRoomDelete(payload);
        break;
      case 'LODGING_RESERVATION_CREATE':
        await _processLodgingReservationCreate(payload);
        break;
      case 'LODGING_RESERVATION_STATUS':
        await _processLodgingReservationStatus(payload);
        break;
      case 'LODGING_CHECK_IN':
        await _processLodgingCheckIn(payload);
        break;
      case 'LODGING_CHECK_OUT':
        await _processLodgingCheckOut(payload, event.timestamp);
        break;

      // === Floor Plan Events ===
      case 'FLOOR_PLAN_UPDATE':
        await _processFloorPlanUpdate(payload);
        break;

      // === CRM/Customer Events ===
      case 'CUSTOMER_CREATE':
        await _processCustomerCreate(payload);
        break;
      case 'CUSTOMER_UPDATE':
        await _processCustomerUpdate(payload);
        break;

      default:
        debugPrint('⚠️ Unknown event type for processing: ${event.eventType}');
    }
  }

  static Future<void> _processInventoryDelete(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    // Match by name or ID
    if (payload['itemId'] != null) {
      await db.delete('inventory', where: 'id = ?', whereArgs: [payload['itemId']]);
    } else if (payload['itemName'] != null) {
      await db.delete('inventory', where: 'name = ?', whereArgs: [payload['itemName']]);
    }
  }
  
  static Future<void> _processTransaction(
    String type, 
    Map<String, dynamic> payload,
    int timestamp, {
    String? cloudId,
  }) async {
    final db = await DbProvider.db;
    
    // Insert into txn table
    final sourceModule = payload['source_module'] as String? ?? payload['source'] as String? ?? 'retail';
    final txnId = await db.insert('txn', {
      'type': type == 'SALE' ? 'sale' : 
              (type == 'EXPENSE' ? 'outgoing' : 
              (type == 'CASH_COUNT_ENTRY' ? 'cash_count' : 'income')),
      'totalAmount': payload['totalAmount'] ?? payload['amount'],
      'details': payload['details'] ?? '',
      'timestamp': timestamp,
      'receiptSignature': payload['receiptSignature'],
      'source_module': sourceModule,
      'cloud_id': cloudId,
    });

    // Handle items
    if (payload['items'] != null && payload['items'] is List) {
      final items = payload['items'] as List;
      for (final item in items) {
        int itemId = item['itemId'] ?? 0;
        
        // If itemId is 0 or null, we might try to find it by name (Phase 5 improvement)
        if (itemId == 0 && item['name'] != null) {
           final matches = await db.query(
             'inventory', 
             where: 'name = ?', 
             whereArgs: [item['name']],
             limit: 1
           );
           if (matches.isNotEmpty) {
             itemId = matches.first['id'] as int;
           }
        }

        await db.insert('transaction_items', {
          'transactionId': txnId,
          'itemId': itemId,
          'quantity': item['qty'] ?? 1,
          'unitPrice': item['price'] ?? 0,
          'subtotal': item['subtotal'] ?? 0,
          'discount': item['discount'] ?? 0,
        });
      }
    }
  }
  
  static Future<void> _processStockChange(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final itemId = payload['itemId'];
    final change = payload['change'] as int;
    
    // Simple ID match (risky, but best effort)
    if (itemId != null) {
      await db.rawUpdate(
        'UPDATE inventory SET stock = stock + ? WHERE id = ?',
        [change, itemId]
      );
    } else if (payload['itemName'] != null) {
       // Fallback by name
      await db.rawUpdate(
        'UPDATE inventory SET stock = stock + ? WHERE name = ?',
        [change, payload['itemName']]
      );
    }
  }
  
  static Future<void> _processInventoryCreate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    // Insert new item
    // check if name exists
    final exists = await db.query('inventory', where: 'name = ?', whereArgs: [payload['name']]);
    if (exists.isNotEmpty) return; // Skip duplicate

    await db.insert('inventory', {
      'name': payload['name'],
      'category': payload['category'],
      'sellingPrice': payload['sellingPrice'],
      'originalPrice': payload['originalPrice'],
      'stock': payload['stock'] ?? 0,
      'imagePath': payload['imagePath'],
      'specification': payload['specification'] ?? '',
      'barcode': payload['barcode'] ?? '',
      'variationsJson': payload['variationsJson'],
      'source_module': payload['source_module'] ?? 'retail',
    });
    debugPrint('📦 Synced new inventory item: ${payload['name']}');
  }
  
  static Future<void> _processInventoryUpdate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    
    // Match by previousName (from the update event), fall back to newName
    final matchName = payload['previousName'] ?? payload['newName'] ?? payload['name'];
    if (matchName == null) {
      debugPrint('⚠️ Inventory update event has no name to match on');
      return;
    }

    // Build update map with ALL fields that may have changed
    final updateData = <String, dynamic>{};
    
    // Name change
    if (payload['newName'] != null) updateData['name'] = payload['newName'];
    
    // Core fields
    if (payload['newSellingPrice'] != null) updateData['sellingPrice'] = payload['newSellingPrice'];
    if (payload['newOriginalPrice'] != null) updateData['originalPrice'] = payload['newOriginalPrice'];
    if (payload['newStock'] != null) updateData['stock'] = payload['newStock'];
    if (payload['category'] != null) updateData['category'] = payload['category'];
    if (payload['imagePath'] != null) updateData['imagePath'] = payload['imagePath'];
    if (payload['specification'] != null) updateData['specification'] = payload['specification'];
    if (payload['barcode'] != null) updateData['barcode'] = payload['barcode'];
    if (payload.containsKey('variationsJson')) updateData['variationsJson'] = payload['variationsJson'];

    if (updateData.isEmpty) {
      debugPrint('⚠️ Inventory update event has no fields to update');
      return;
    }

    await db.update(
      'inventory',
      updateData,
      where: 'name = ?',
      whereArgs: [matchName],
    );
    debugPrint('📦 Synced inventory update for: $matchName (${updateData.keys.join(', ')})');
  }

  // ============================================================
  // RESTAURANT ORDER HANDLERS
  // ============================================================

  static Future<void> _processOrderCreated(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    
    // Check idempotency by order_number
    final orderNumber = payload['order_number'];
    if (orderNumber != null) {
      final existing = await db.query(
        'restaurant_orders',
        where: 'order_number = ?',
        whereArgs: [orderNumber],
        limit: 1,
      );
      if (existing.isNotEmpty) return; // Already have this order
    }

    await db.transaction((txn) async {
      final orderId = await txn.insert('restaurant_orders', {
        'cloud_id': payload['cloud_id'],
        'source_module': payload['source_module'] ?? 'restaurant',
        'order_number': payload['order_number'],
        'order_type': payload['order_type'] ?? 'takeaway',
        'table_number': payload['table_number'],
        'customer_name': payload['customer_name'],
        'customer_phone': payload['customer_phone'],
        'items_json': payload['items_json'],
        'subtotal': payload['subtotal'] ?? payload['total'],
        'total': payload['total'] ?? 0,
        'total_amount': payload['total'] ?? 0,
        'status': payload['status'] ?? 'pending',
        'notes': payload['notes'],
        'client_id': payload['client_id'],
        'created_at': payload['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
        'updated_at': payload['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
      });

      // Insert order items
      final items = payload['items'];
      if (items is List) {
        for (final item in items) {
          await txn.insert('restaurant_order_items', {
            'order_id': orderId,
            'menu_item_id': item['menu_item_id'],
            'menu_item_name': item['menu_item_name'] ?? item['name'],
            'quantity': item['quantity'] ?? item['qty'] ?? 1,
            'unit_price': item['unit_price'] ?? item['price'],
            'subtotal': item['subtotal'] ?? 0,
            'item_note': item['item_note'],
            'status': 'pending',
            'created_at': payload['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
            'updated_at': payload['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    });

    // ========== AUTO-GENERATE FLOOR PLAN TABLE ==========
    // If the order has a table_number not yet in the floor plan, create it
    final tableNumber = payload['table_number'] as String?;
    if (tableNumber != null && tableNumber.isNotEmpty && payload['order_type'] == 'dine_in') {
      try {
        final existingTable = await db.query('restaurant_floor_plan',
            where: 'table_number = ?', whereArgs: [tableNumber], limit: 1);
        if (existingTable.isEmpty) {
          // Count existing tables to stagger position
          final tableCount = (await db.rawQuery('SELECT COUNT(*) as cnt FROM restaurant_floor_plan')).first['cnt'] as int? ?? 0;
          final row = tableCount ~/ 5;
          final col = tableCount % 5;
          await db.insert('restaurant_floor_plan', {
            'table_number': tableNumber,
            'shape': 'round',
            'seats': 4,
            'x': 0.1 + (col * 0.18),  // Spread across canvas
            'y': 0.1 + (row * 0.18),
            'zone': 'Main Hall',
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
          debugPrint('🍽️ Auto-created floor plan table: $tableNumber');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to auto-create floor plan table (non-fatal): $e');
      }
    }
    // ====================================================

    debugPrint('📋 Synced order: ${payload['order_number']}');
  }

  static Future<void> _processOrderStatusChange(Map<String, dynamic> payload, int eventTimestamp) async {
    final db = await DbProvider.db;
    final orderId = payload['order_id'];
    final orderNumber = payload['order_number'];
    final newStatus = payload['new_status'];
    final staffName = payload['staff_name'] as String?;

    if (newStatus == null) return;

    // Try matching by order_number first (more reliable across devices), then by id
    final existing = await db.query(
      'restaurant_orders',
      where: orderNumber != null ? 'order_number = ?' : 'id = ?',
      whereArgs: [orderNumber ?? orderId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final order = existing.first;
      final currentUpdatedAt = order['updated_at'] as int? ?? 0;
      
      // CRDT-style conflict resolution: Ignore stale events
      if (eventTimestamp < currentUpdatedAt) {
        debugPrint('⏳ Ignored STALE order status change to $newStatus (Event: $eventTimestamp, DB: $currentUpdatedAt)');
        return;
      }
    }

    // Build update map with status + staff attribution
    final Map<String, dynamic> updateData = {
      'status': newStatus,
      'updated_at': eventTimestamp,
    };

    // Map staff name to the correct tracking column based on status
    if (staffName != null && staffName.isNotEmpty) {
      switch (newStatus) {
        case 'preparing':
          updateData['preparing_by'] = staffName;
          break;
        case 'ready':
          updateData['ready_by'] = staffName;
          break;
        case 'served':
          updateData['served_by'] = staffName;
          break;
      }
    }

    if (orderNumber != null) {
      await db.update(
        'restaurant_orders',
        updateData,
        where: 'order_number = ?',
        whereArgs: [orderNumber],
      );
      // Also update item-level status
      final orders = await db.query('restaurant_orders',
          where: 'order_number = ?', whereArgs: [orderNumber], limit: 1);
      if (orders.isNotEmpty) {
        final localOrderId = orders.first['id'] as int;
        final Map<String, dynamic> itemUpdate = {'status': newStatus, 'updated_at': eventTimestamp};
        if (staffName != null && staffName.isNotEmpty) {
          if (newStatus == 'preparing') itemUpdate['preparing_by'] = staffName;
          if (newStatus == 'ready') itemUpdate['ready_by'] = staffName;
          if (newStatus == 'served') itemUpdate['served_by'] = staffName;
        }
        await db.update('restaurant_order_items', itemUpdate,
            where: 'order_id = ?', whereArgs: [localOrderId]);
      }
    } else if (orderId != null) {
      await db.update(
        'restaurant_orders',
        updateData,
        where: 'id = ?',
        whereArgs: [orderId],
      );
    }

    // ========== CLOUD SYNC: Push live tracking to Supabase ==========
    try {
      final cloudId = existing.isNotEmpty ? existing.first['cloud_id'] as String? : payload['cloud_id'] as String?;
      if (cloudId != null && cloudId.isNotEmpty) {
        final supabase = Supabase.instance.client;
        if (supabase.auth.currentUser != null) {
          await supabase.from('restaurant_orders').update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', cloudId);
          debugPrint('☁️ Synced order status to Supabase (cloud_id: $cloudId)');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Cloud sync order status failed (non-fatal): $e');
    }
    // ================================================================

    debugPrint('📋 Synced order status → $newStatus by ${staffName ?? 'unknown'} (order: ${orderNumber ?? orderId})');
  }

  static Future<void> _processOrderUpdate(Map<String, dynamic> payload, int eventTimestamp) async {
    final db = await DbProvider.db;
    final orderId = payload['order_id'];
    if (orderId == null) return;
    
    final Map<String, dynamic> updateData = {'updated_at': eventTimestamp};
    
    if (payload['new_status'] != null) updateData['status'] = payload['new_status'];
    if (payload['new_total'] != null) updateData['total'] = payload['new_total'];
    
    if (updateData.length > 1) { // More than just updated_at
      await db.update('restaurant_orders', updateData, where: 'id = ?', whereArgs: [orderId]);
    }
    debugPrint('📋 Synced order update for order $orderId');
  }

  static Future<void> _processTableTransfer(Map<String, dynamic> payload, int eventTimestamp) async {
    final db = await DbProvider.db;
    final orderId = payload['order_id'];
    final newTable = payload['new_table'];
    
    if (orderId == null || newTable == null) return;
    
    // Check if target table already has an active order
    final existing = await db.query(
      'restaurant_orders',
      where: 'table_number = ? AND status NOT IN (?, ?)',
      whereArgs: [newTable, 'completed', 'paid'],
    );
    
    if (existing.isNotEmpty) {
      // It's a merge
      final targetOrderId = existing.first['id'];
      
      await db.transaction((txn) async {
        await txn.update(
          'restaurant_order_items',
          {'order_id': targetOrderId, 'updated_at': eventTimestamp},
          where: 'order_id = ?',
          whereArgs: [orderId],
        );
        
        final oldTotalQuery = await txn.query('restaurant_orders', columns: ['total'], where: 'id = ?', whereArgs: [orderId]);
        final targetTotalQuery = await txn.query('restaurant_orders', columns: ['total'], where: 'id = ?', whereArgs: [targetOrderId]);
        
        final additionalAmount = oldTotalQuery.isNotEmpty ? (oldTotalQuery.first['total'] as num?)?.toDouble() ?? 0.0 : 0.0;
        final currentTargetAmount = targetTotalQuery.isNotEmpty ? (targetTotalQuery.first['total'] as num?)?.toDouble() ?? 0.0 : 0.0;
        
        await txn.update(
          'restaurant_orders',
          {'total': currentTargetAmount + additionalAmount, 'updated_at': eventTimestamp},
          where: 'id = ?',
          whereArgs: [targetOrderId],
        );
        
        await txn.update(
          'restaurant_orders',
          {
            'status': 'merged',
            'parent_order_id': targetOrderId,
            'table_number': newTable,
            'updated_at': eventTimestamp
          },
          where: 'id = ?',
          whereArgs: [orderId],
        );
      });
    } else {
      // Standard transfer
      await db.update(
        'restaurant_orders',
        {
          'table_number': newTable,
          'updated_at': eventTimestamp
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
    }
    debugPrint('🔄 Synced table transfer for order $orderId to table $newTable');
  }

  // ============================================================
  // MENU HANDLERS
  // ============================================================

  static Future<void> _processMenuCreate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    // Idempotency: skip if item with same name exists
    final name = payload['name'];
    if (name != null) {
      final existing = await db.query('restaurant_menu', where: 'name = ?', whereArgs: [name], limit: 1);
      if (existing.isNotEmpty) return;
    }

    await db.insert('restaurant_menu', {
      'name': payload['name'],
      'description': payload['description'],
      'price': payload['price'],
      'category': payload['category'],
      'available': payload['is_available'] ?? payload['available'] ?? 1,
      'prep_time_minutes': payload['prep_time_minutes'],
      'image_path': payload['image_path'], // Will be null on receiving device (no file sync)
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
    debugPrint('🍽️ Synced menu item: $name');
  }

  static Future<void> _processMenuUpdate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final name = payload['name'];
    final updateData = <String, dynamic>{'updated_at': DateTime.now().millisecondsSinceEpoch};
    
    if (payload['price'] != null) updateData['price'] = payload['price'];
    if (payload['description'] != null) updateData['description'] = payload['description'];
    if (payload['category'] != null) updateData['category'] = payload['category'];
    if (payload['is_available'] != null) updateData['available'] = payload['is_available'];
    if (payload['available'] != null) updateData['available'] = payload['available'];
    if (payload['prep_time_minutes'] != null) updateData['prep_time_minutes'] = payload['prep_time_minutes'];

    if (payload['menu_item_id'] != null) {
      await db.update('restaurant_menu', updateData, where: 'id = ?', whereArgs: [payload['menu_item_id']]);
    } else if (name != null) {
      await db.update('restaurant_menu', updateData, where: 'name = ?', whereArgs: [name]);
    }
    debugPrint('🍽️ Synced menu update: $name');
  }

  static Future<void> _processMenuDelete(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    if (payload['menu_item_id'] != null) {
      await db.delete('restaurant_menu', where: 'id = ?', whereArgs: [payload['menu_item_id']]);
    } else if (payload['name'] != null) {
      await db.delete('restaurant_menu', where: 'name = ?', whereArgs: [payload['name']]);
    }
    debugPrint('🍽️ Synced menu delete: ${payload['name']}');
  }

  // ============================================================
  // SETTINGS HANDLER
  // ============================================================

  static Future<void> _processSettingsUpdate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final shopId = payload['shop_id'];
    if (shopId == null) return;

    final updateData = <String, dynamic>{};
    // Only update fields that were explicitly sent
    for (final key in ['shopName', 'description', 'theme_primary_color', 
                        'theme_accent_color', 'theme_font', 'logo_path',
                        'address', 'phone', 'business_hours']) {
      if (payload.containsKey(key)) updateData[key] = payload[key];
    }
    if (updateData.isEmpty) return;

    await db.update('shops', updateData, where: 'id = ?', whereArgs: [shopId]);
    debugPrint('⚙️ Synced settings update for shop: $shopId');
  }

  // ============================================================
  // SERVICE HANDLERS
  // ============================================================

  static Future<void> _processServiceCreate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final name = payload['name'];
    if (name != null) {
      final existing = await db.query('services_catalog', where: 'name = ?', whereArgs: [name], limit: 1);
      if (existing.isNotEmpty) return;
    }
    await db.insert('services_catalog', {
      'cloud_id': payload['cloud_id'],
      'source_module': payload['source_module'] ?? 'services',
      'name': payload['name'],
      'description': payload['description'],
      'price': payload['price'],
      'duration_minutes': payload['duration_minutes'],
      'category': payload['category'],
      'is_active': payload['is_active'] ?? 1,
    });
    debugPrint('🔧 Synced service: $name');
  }

  static Future<void> _processServiceUpdate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final updateData = <String, dynamic>{};
    for (final key in ['name', 'description', 'price', 'duration_minutes', 'category', 'is_active']) {
      if (payload.containsKey(key)) updateData[key] = payload[key];
    }
    if (updateData.isEmpty) return;

    if (payload['service_id'] != null) {
      await db.update('services_catalog', updateData, where: 'id = ?', whereArgs: [payload['service_id']]);
    } else if (payload['name'] != null) {
      await db.update('services_catalog', updateData, where: 'name = ?', whereArgs: [payload['name']]);
    }
    debugPrint('🔧 Synced service update: ${payload['name']}');
  }

  static Future<void> _processServiceDelete(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    if (payload['service_id'] != null) {
      await db.delete('services_catalog', where: 'id = ?', whereArgs: [payload['service_id']]);
    } else if (payload['name'] != null) {
      await db.delete('services_catalog', where: 'name = ?', whereArgs: [payload['name']]);
    }
    debugPrint('🔧 Synced service delete: ${payload['name']}');
  }

  // ============================================================
  // BOOKING HANDLERS
  // ============================================================

  static Future<void> _processBookingCreated(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    // Idempotency by cloud_id
    final cloudId = payload['cloud_id'];
    if (cloudId != null) {
      final existing = await db.query('services_bookings', where: 'cloud_id = ?', whereArgs: [cloudId], limit: 1);
      if (existing.isNotEmpty) return;
    }
    final startTime = payload['start_time'] ?? payload['scheduled_at'] ?? DateTime.now().millisecondsSinceEpoch;
    final durationMs = ((payload['duration_minutes'] as int?) ?? 30) * 60 * 1000;
    await db.insert('services_bookings', {
      'cloud_id': cloudId,
      'source_module': payload['source_module'] ?? 'services',
      'service_id': payload['service_id'],
      'customer_name': payload['customer_name'],
      'customer_phone': payload['customer_phone'],
      'start_time': startTime,
      'end_time': payload['end_time'] ?? (startTime + durationMs),
      'status': payload['status'] ?? 'pending',
      'notes': payload['notes'],
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
    debugPrint('📅 Synced booking: $cloudId');
  }

  static Future<void> _processBookingStatusChange(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final newStatus = payload['new_status'];
    if (newStatus == null) return;

    // Update booking status
    if (payload['booking_ref'] != null) {
      await db.update('services_bookings', {'status': newStatus}, where: 'booking_ref = ?', whereArgs: [payload['booking_ref']]);
    } else if (payload['booking_id'] != null) {
      await db.update('services_bookings', {'status': newStatus}, where: 'id = ?', whereArgs: [payload['booking_id']]);
    }
    
    // Create transaction when booking is completed
    if (newStatus == 'completed') {
      await _createTransactionFromBooking(payload);
    }
    
    debugPrint('📅 Synced booking status → $newStatus');
  }

  /// Create a transaction record from a completed booking
  static Future<void> _createTransactionFromBooking(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    
    // Get booking details
    final bookingId = payload['booking_id'];
    if (bookingId == null) return;
    
    final bookings = await db.query('services_bookings', where: 'id = ?', whereArgs: [bookingId]);
    if (bookings.isEmpty) return;
    
    final booking = bookings.first;
    final price = booking['deposit_paid'] as double? ?? 0.0;
    final serviceId = booking['service_id'];
    
    // Create transaction record in the actual txn table
    await db.insert('txn', {
      'totalAmount': price,
      'source_module': 'services',
      'type': 'sale',
      'details': 'Service Booking #$bookingId (service $serviceId)',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    debugPrint('💰 Created transaction: KES ${price.toStringAsFixed(0)} for booking #$bookingId');
  }

  // ============================================================
  // ENTERTAINMENT HANDLERS
  // ============================================================

  static Future<void> _processEntertainmentAssetCreate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final name = payload['name'];
    if (name != null) {
      final existing = await db.query('entertainment_assets', where: 'name = ?', whereArgs: [name], limit: 1);
      if (existing.isNotEmpty) return;
    }
    await db.insert('entertainment_assets', {
      'cloud_id': payload['cloud_id'],
      'source_module': payload['source_module'] ?? 'entertainment',
      'name': payload['name'],
      'category': payload['category'],
      'asset_type': payload['asset_type'] ?? 'hourly',
      'rate_per_hour': payload['rate_per_hour'] ?? 0,
      'flat_rate': payload['flat_rate'] ?? 0,
      'is_active': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
    debugPrint('🎮 Synced entertainment asset: $name');
  }

  static Future<void> _processEntertainmentAssetUpdate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final assetId = payload['asset_id'];
    if (assetId == null) return;

    final updateData = <String, dynamic>{'updated_at': DateTime.now().millisecondsSinceEpoch};
    for (final key in ['name', 'category', 'asset_type', 'rate_per_hour', 'flat_rate', 'is_active', 'description']) {
      if (payload.containsKey(key)) updateData[key] = payload[key];
    }
    await db.update('entertainment_assets', updateData, where: 'id = ?', whereArgs: [assetId]);
    debugPrint('🎮 Synced entertainment asset update: $assetId');
  }

  static Future<void> _processEntertainmentSessionStart(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final sessionId = payload['session_id'];
    // Idempotency: check if session already exists by started_at + asset_id
    final assetId = payload['asset_id'];
    final startedAt = payload['started_at'];
    if (assetId != null && startedAt != null) {
      final existing = await db.query('entertainment_sessions',
          where: 'asset_id = ? AND started_at = ? AND status = ?',
          whereArgs: [assetId, startedAt, 'active'], limit: 1);
      if (existing.isNotEmpty) return;
    }

    await db.insert('entertainment_sessions', {
      'cloud_id': payload['cloud_id'],
      'source_module': payload['source_module'] ?? 'entertainment',
      'asset_id': assetId,
      'customer_name': payload['customer_name'],
      'client_id': payload['client_id'],
      'started_at': startedAt,
      'billing_type': payload['billing_type'] ?? 'hourly',
      'rate': payload['rate'] ?? 0,
      'total_amount': payload['billing_type'] == 'flat' ? (payload['rate'] ?? 0) : 0,
      'status': 'active',
      'notes': payload['notes'] ?? '',
      'created_at': startedAt ?? DateTime.now().millisecondsSinceEpoch,
    });
    debugPrint('🎮 Synced session start on asset $assetId (session $sessionId)');
  }

  static Future<void> _processEntertainmentSessionComplete(Map<String, dynamic> payload, int timestamp) async {
    final db = await DbProvider.db;
    final assetId = payload['asset_id'];
    final totalAmount = payload['total_amount'] ?? 0;

    // Find and complete the active session for this asset (oldest first)
    if (assetId != null) {
      final activeSessions = await db.query('entertainment_sessions',
          where: 'asset_id = ? AND status = ?',
          whereArgs: [assetId, 'active'],
          orderBy: 'started_at ASC', limit: 1);
      if (activeSessions.isNotEmpty) {
        final sid = activeSessions.first['id'] as int;
        await db.update('entertainment_sessions', {
          'ended_at': timestamp,
          'total_amount': totalAmount,
          'status': 'completed',
        }, where: 'id = ?', whereArgs: [sid]);
      }
    }
    debugPrint('🎮 Synced session complete on asset $assetId');
  }

  // ============================================================
  // FLOOR PLAN HANDLER
  // ============================================================

  static Future<void> _processFloorPlanUpdate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final tables = payload['tables'];
    if (tables is! List) return;

    await db.transaction((txn) async {
      // Full-state replacement: clear existing and insert all
      await txn.delete('restaurant_floor_plan');
      for (final t in tables) {
        await txn.insert('restaurant_floor_plan', {
          'table_number': t['table_number'],
          'label': t['label'],
          'shape': t['shape'] ?? 'round',
          'seats': t['seats'] ?? 4,
          'x': t['x'] ?? 0.5,
          'y': t['y'] ?? 0.5,
          'zone': t['zone'] ?? 'Main Hall',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
    debugPrint('🗺️ Synced floor plan: ${tables.length} tables');
  }

  // ============================================================
  // LODGING HANDLERS
  // ============================================================

  static Future<void> _processLodgingRoomCreate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final name = payload['name'];
    if (name != null) {
      final existing = await db.query('lodging_rooms', where: 'name = ?', whereArgs: [name], limit: 1);
      if (existing.isNotEmpty) return;
    }
    await db.insert('lodging_rooms', {
      'cloud_id': payload['cloud_id'],
      'source_module': payload['source_module'] ?? 'lodging',
      'name': name,
      'room_type': payload['room_type'],
      'status': 'available',
      'is_active': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
    debugPrint('🏨 Synced lodging room: $name');
  }

  static Future<void> _processLodgingRoomUpdate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final roomId = payload['room_id'];
    if (roomId == null) return;

    final updateData = <String, dynamic>{'updated_at': DateTime.now().millisecondsSinceEpoch};
    for (final key in ['name', 'room_type', 'status', 'rate_per_night', 'capacity', 'floor', 'amenities', 'description', 'is_active']) {
      if (payload.containsKey(key)) updateData[key] = payload[key];
    }
    await db.update('lodging_rooms', updateData, where: 'id = ?', whereArgs: [roomId]);
    debugPrint('🏨 Synced lodging room update: $roomId');
  }

  static Future<void> _processLodgingRoomDelete(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final roomId = payload['room_id'];
    if (roomId != null) {
      await db.delete('lodging_rooms', where: 'id = ?', whereArgs: [roomId]);
    }
    debugPrint('🏨 Synced lodging room delete: $roomId');
  }

  static Future<void> _processLodgingReservationCreate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    // Idempotency: check by room_id + check_in + guest_name
    final roomId = payload['room_id'];
    final checkIn = payload['check_in'];
    final guestName = payload['guest_name'];
    if (roomId != null && checkIn != null && guestName != null) {
      final existing = await db.query('lodging_reservations',
          where: 'room_id = ? AND check_in_date = ? AND guest_name = ?',
          whereArgs: [roomId, checkIn, guestName], limit: 1);
      if (existing.isNotEmpty) return;
    }

    await db.insert('lodging_reservations', {
      'cloud_id': payload['cloud_id'],
      'source_module': payload['source_module'] ?? 'lodging',
      'room_id': roomId,
      'guest_name': guestName,
      'guest_phone': payload['guest_phone'],
      'guest_email': payload['guest_email'],
      'check_in_date': checkIn,
      'check_out_date': payload['check_out'],
      'nights': payload['nights'],
      'rate_per_night': payload['rate_per_night'] ?? 0,
      'total_amount': payload['total_amount'] ?? 0,
      'amount_paid': 0,
      'status': 'pending',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
    debugPrint('🏨 Synced reservation for $guestName');
  }

  static Future<void> _processLodgingReservationStatus(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final reservationId = payload['reservation_id'];
    final status = payload['status'];
    if (reservationId == null || status == null) return;

    await db.update('lodging_reservations', {
      'status': status,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [reservationId]);
    debugPrint('🏨 Synced reservation status → $status');
  }

  static Future<void> _processLodgingCheckIn(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final reservationId = payload['reservation_id'];
    final roomId = payload['room_id'];
    if (reservationId == null) return;

    await db.update('lodging_reservations', {
      'status': 'checked_in',
      'actual_check_in': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [reservationId]);

    if (roomId != null) {
      await db.update('lodging_rooms', {'status': 'occupied', 'updated_at': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?', whereArgs: [roomId]);
    }
    debugPrint('🏨 Synced check-in: reservation $reservationId');
  }

  static Future<void> _processLodgingCheckOut(Map<String, dynamic> payload, int timestamp) async {
    final db = await DbProvider.db;
    final reservationId = payload['reservation_id'];
    final roomId = payload['room_id'];
    if (reservationId == null) return;

    await db.update('lodging_reservations', {
      'status': 'checked_out',
      'actual_check_out': timestamp,
      'updated_at': timestamp,
    }, where: 'id = ?', whereArgs: [reservationId]);

    if (roomId != null) {
      await db.update('lodging_rooms', {'status': 'cleaning', 'updated_at': timestamp},
          where: 'id = ?', whereArgs: [roomId]);
    }
    debugPrint('🏨 Synced check-out: reservation $reservationId');
  }

  static Future<void> _processCustomerCreate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    final phone = payload['phone'];
    final name = payload['name'];
    
    List<Map<String, dynamic>> existing = [];
    if (phone != null && phone.toString().isNotEmpty) {
      existing = await db.query(
        'customer',
        where: 'phone = ?',
        whereArgs: [phone],
        limit: 1,
      );
    } else if (name != null && name.toString().isNotEmpty) {
      existing = await db.query(
        'customer',
        where: 'name = ?',
        whereArgs: [name],
        limit: 1,
      );
    }
    
    if (existing.isNotEmpty) {
      debugPrint('👤 Synced customer create: customer already exists with phone/name, skipping insert.');
      return;
    }
    
    await db.insert('customer', {
      'name': name ?? 'Unknown',
      'phone': phone,
      'id_no': payload['id_no'],
      'bank_account': payload['bank_account'],
      'notes': payload['notes'],
      'agent': payload['agent'],
      'store': payload['store'],
      'createdAt': payload['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
    });
    debugPrint('👤 Synced new customer: $name');
  }

  static Future<void> _processCustomerUpdate(Map<String, dynamic> payload) async {
    final db = await DbProvider.db;
    
    // Attempt lookup by previousPhone, then current phone, then previousName, then current name
    final phoneToMatch = payload['previousPhone'] ?? payload['phone'];
    final nameToMatch = payload['previousName'] ?? payload['name'];
    
    List<Map<String, dynamic>> existing = [];
    if (phoneToMatch != null && phoneToMatch.toString().isNotEmpty) {
      existing = await db.query(
        'customer',
        where: 'phone = ?',
        whereArgs: [phoneToMatch],
        limit: 1,
      );
    }
    
    if (existing.isEmpty && nameToMatch != null && nameToMatch.toString().isNotEmpty) {
      existing = await db.query(
        'customer',
        where: 'name = ?',
        whereArgs: [nameToMatch],
        limit: 1,
      );
    }
    
    if (existing.isNotEmpty) {
      final localId = existing.first['id'] as int;
      await db.update(
        'customer',
        {
          'name': payload['name'] ?? existing.first['name'],
          'phone': payload['phone'] ?? existing.first['phone'],
          'id_no': payload['id_no'] ?? existing.first['id_no'],
          'bank_account': payload['bank_account'] ?? existing.first['bank_account'],
          'notes': payload['notes'] ?? existing.first['notes'],
          'agent': payload['agent'] ?? existing.first['agent'],
          'store': payload['store'] ?? existing.first['store'],
        },
        where: 'id = ?',
        whereArgs: [localId],
      );
      debugPrint('👤 Synced customer update for id $localId (${payload['name']})');
    } else {
      // Create new customer if not found
      await db.insert('customer', {
        'name': payload['name'] ?? 'Unknown',
        'phone': payload['phone'],
        'id_no': payload['id_no'],
        'bank_account': payload['bank_account'],
        'notes': payload['notes'],
        'agent': payload['agent'],
        'store': payload['store'],
        'createdAt': payload['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('👤 Synced customer update created new record (${payload['name']})');
    }
  }
}
