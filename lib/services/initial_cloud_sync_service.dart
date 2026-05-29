import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../db/db_provider.dart';
import 'auth_service.dart';
import 'device_service.dart';
import 'onboarding_service.dart';

/// Initial Cloud Sync Service
/// 
/// Handles pulling existing shop data from the cloud when a new device
/// joins a shop. This ensures new devices get all inventory, orders,
/// customers, and settings from existing devices.
class InitialCloudSyncService {
  
  /// Perform initial sync from cloud for a new device
  /// This should be called when a device first joins a shop
  static Future<void> performInitialSync() async {
    try {
      debugPrint('🚀 Starting initial cloud sync...');
      
      final shop = await AuthService.getCurrentShop();
      if (shop == null) {
        debugPrint('❌ No shop found for initial sync');
        return;
      }
      
      final shopId = shop.id;
      final deviceId = await DeviceService.getDeviceId();
      final enabledModules = await OnboardingService.getSelectedModules();
      
      debugPrint('📦 Initial sync for shop: $shopId');
      debugPrint('📱 Device: $deviceId');
      debugPrint('🔧 Enabled modules: $enabledModules');
      
      // 1. Sync shop info and settings
      await _pullShopInfo(shopId);
      
      // 2. Sync inventory for all enabled modules
      if (enabledModules.contains('retail')) {
        await _pullRetailInventory(shopId);
        await _pullRetailEnterpriseSchemas(shopId);
      }
      
      if (enabledModules.contains('restaurant')) {
        await _pullRestaurantInventory(shopId);
        await _pullRestaurantMenu(shopId);
        await _pullRestaurantRecipes(shopId);
        await _pullRestaurantOrders(shopId);
      }
      
      if (enabledModules.contains('services')) {
        await _pullServicesCatalog(shopId);
        await _pullServicesBookings(shopId);
      }
      
      if (enabledModules.contains('entertainment')) {
        await _pullEntertainmentAssets(shopId);
        await _pullEntertainmentSessions(shopId);
      }
      
      if (enabledModules.contains('lodging')) {
        await _pullLodgingRooms(shopId);
        await _pullLodgingReservations(shopId);
      }
      
      // 3. Sync universal data
      await _pullCustomers(shopId);
      await _pullTransactions(shopId);
      
      debugPrint('✅ Initial cloud sync completed!');
      
    } catch (e) {
      debugPrint('❌ Initial cloud sync failed: $e');
      rethrow;
    }
  }
  
  /// Pull shop information from cloud
  static Future<void> _pullShopInfo(String shopId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('shops')
          .select()
          .eq('id', shopId)
          .maybeSingle();
      
      if (response != null) {
        // Update local shop info
        await DbProvider.update('shops', {
          'name': response['name'],
          'subscription_tier': response['subscription_tier'],
          'enabled_modules': response['enabled_modules']?.toString(),
          'settings': response['settings']?.toString(),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, where: 'id = ?', whereArgs: [shopId]);
        
        debugPrint('✅ Pulled shop info: ${response['name']}');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to pull shop info: $e');
    }
  }
  
  /// Pull retail inventory from cloud
  static Future<void> _pullRetailInventory(String shopId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('inventory')
          .select()
          .eq('shop_id', shopId);
      
      for (final item in response) {
        // Check if item already exists locally
        final existing = await DbProvider.query(
          'inventory',
          where: 'cloud_id = ?',
          whereArgs: [item['id']],
        );
        
        final itemData = {
          'cloud_id': item['id'],
          'shop_id': item['shop_id'],
          'name': item['name'],
          'category': item['category'],
          'unit_price': item['unit_price'],
          'stock_quantity': item['stock_quantity'] ?? 0,
          'description': item['description'] ?? '',
          'source_module': item['source_module'] ?? 'retail',
          'is_active': 1,
          'created_at': DateTime.parse(item['created_at']).millisecondsSinceEpoch,
          'updated_at': DateTime.parse(item['updated_at']).millisecondsSinceEpoch,
        };
        
        if (existing.isEmpty) {
          await DbProvider.insert('inventory', itemData);
        } else {
          await DbProvider.update('inventory', itemData, 
            where: 'cloud_id = ?', whereArgs: [item['id']]);
        }
      }
      
      debugPrint('✅ Pulled ${response.length} retail inventory items');
    } catch (e) {
      debugPrint('⚠️ Failed to pull retail inventory: $e');
    }
  }

  /// Pull retail enterprise schemas (POs, Returns, Audits, etc) from cloud
  static Future<void> _pullRetailEnterpriseSchemas(String shopId) async {
    final supabase = Supabase.instance.client;
    
    // Helper to pull generic tables that use 'shop_id' and 'id' as 'cloud_id'
    Future<void> pullTable(String tableName) async {
      try {
        final response = await supabase
            .from(tableName)
            .select()
            .eq('shop_id', shopId);
            
        for (final item in response) {
          final existing = await DbProvider.query(
            tableName,
            where: 'cloud_id = ?',
            whereArgs: [item['id']],
          );
          
          final itemData = Map<String, dynamic>.from(item);
          itemData['cloud_id'] = itemData.remove('id');
          
          if (existing.isEmpty) {
            await DbProvider.insert(tableName, itemData);
          } else {
            await DbProvider.update(tableName, itemData,
              where: 'cloud_id = ?', whereArgs: [item['id']]);
          }
        }
        debugPrint('✅ Pulled ${response.length} $tableName');
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST205' || e.code == '42P01') {
          debugPrint('ℹ️ $tableName not in Supabase yet, skipping');
        } else {
          debugPrint('⚠️ Failed to pull $tableName: $e');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to pull $tableName: $e');
      }
    }

    // Call helper for all retail schemas mapping purely to shop_id horizontally
    await pullTable('retail_returns');
    await pullTable('retail_suppliers');
    await pullTable('retail_purchase_orders');
    await pullTable('retail_po_items');
    await pullTable('retail_promotions');
    await pullTable('retail_stock_audits');
  }
  
  /// Pull restaurant menu from cloud
  static Future<void> _pullRestaurantMenu(String shopId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('restaurant_menu')
          .select()
          .eq('shop_id', shopId);
      
      for (final item in response) {
        final existing = await DbProvider.query(
          'restaurant_menu',
          where: 'cloud_id = ?',
          whereArgs: [item['id']],
        );
        
        final itemData = {
          'cloud_id': item['id'],
          'name': item['name'],
          'description': item['description'] ?? '',
          'category': item['category'] ?? '',
          'price': item['price'] ?? item['unit_price'] ?? 0,
          'available': 1,
          'created_at': DateTime.parse(item['created_at']).millisecondsSinceEpoch,
          'updated_at': DateTime.parse(item['updated_at']).millisecondsSinceEpoch,
        };
        
        if (existing.isEmpty) {
          await DbProvider.insert('restaurant_menu', itemData);
        } else {
          await DbProvider.update('restaurant_menu', itemData,
            where: 'cloud_id = ?', whereArgs: [item['id']]);
        }
      }
      
      debugPrint('✅ Pulled ${response.length} restaurant menu items');
    } catch (e) {
      debugPrint('⚠️ Failed to pull restaurant menu: $e');
    }
  }

  /// Pull isolated restaurant inventory from cloud
  static Future<void> _pullRestaurantInventory(String shopId) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('restaurant_inventory')
          .select()
          .eq('shop_id', shopId);
          
      for (final item in response) {
        final existing = await DbProvider.query(
          'restaurant_inventory',
          where: 'cloud_id = ?',
          whereArgs: [item['id']],
        );
        
        final itemData = Map<String, dynamic>.from(item);
        itemData['cloud_id'] = itemData.remove('id');
        
        if (existing.isEmpty) {
          await DbProvider.insert('restaurant_inventory', itemData);
        } else {
          await DbProvider.update('restaurant_inventory', itemData,
            where: 'cloud_id = ?', whereArgs: [item['id']]);
        }
      }
      debugPrint('✅ Pulled ${response.length} restaurant inventory items');
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') {
        debugPrint('ℹ️ restaurant_inventory not in Supabase yet, skipping');
      } else {
        debugPrint('⚠️ Failed to pull restaurant inventory: $e');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to pull restaurant inventory: $e');
    }
  }

  /// Pull restaurant recipes (ingredient mappings) from cloud
  static Future<void> _pullRestaurantRecipes(String shopId) async {
    final supabase = Supabase.instance.client;
    
    try {
      final response = await supabase
          .from('restaurant_recipes')
          .select()
          .eq('shop_id', shopId);
          
      for (final item in response) {
        final existing = await DbProvider.query(
          'restaurant_recipes',
          where: 'cloud_id = ?',
          whereArgs: [item['id']],
        );
        
        final itemData = Map<String, dynamic>.from(item);
        itemData['cloud_id'] = itemData.remove('id');
        
        if (existing.isEmpty) {
          await DbProvider.insert('restaurant_recipes', itemData);
        } else {
          await DbProvider.update('restaurant_recipes', itemData,
            where: 'cloud_id = ?', whereArgs: [item['id']]);
        }
      }
      debugPrint('✅ Pulled ${response.length} restaurant recipes');
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') {
        debugPrint('ℹ️ restaurant_recipes not in Supabase yet, skipping');
      } else {
        debugPrint('⚠️ Failed to pull restaurant recipes: $e');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to pull restaurant recipes: $e');
    }
  }

  /// Pull services catalog/staff from cloud
  static Future<void> _pullRestaurantOrders(String shopId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('restaurant_orders')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(100); // Pull last 100 orders
      
      for (final order in response) {
        final existing = await DbProvider.query(
          'restaurant_orders',
          where: 'cloud_id = ?',
          whereArgs: [order['id']],
        );
        
        final orderData = {
          'cloud_id': order['id'],
          'shop_id': order['shop_id'],
          'order_number': order['order_number'],
          'customer_name': order['customer_name'] ?? '',
          'order_type': order['order_type'] ?? 'dine_in',
          'table_number': order['table_number'] ?? '',
          'status': order['status'] ?? 'pending',
          'total': order['total'],
          'items_json': order['items_json'] ?? '{}',
          'notes': order['notes'] ?? '',
          'created_at': DateTime.parse(order['created_at']).millisecondsSinceEpoch,
          'updated_at': DateTime.parse(order['updated_at']).millisecondsSinceEpoch,
        };
        
        if (existing.isEmpty) {
          await DbProvider.insert('restaurant_orders', orderData);
        } else {
          await DbProvider.update('restaurant_orders', orderData,
            where: 'cloud_id = ?', whereArgs: [order['id']]);
        }
      }
      
      debugPrint('✅ Pulled ${response.length} restaurant orders');
    } catch (e) {
      debugPrint('⚠️ Failed to pull restaurant orders: $e');
    }
  }
  
  /// Pull services catalog from cloud
  static Future<void> _pullServicesCatalog(String shopId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('services_catalog')
          .select()
          .eq('shop_id', shopId);
      
      for (final service in response) {
        final existing = await DbProvider.query(
          'services_catalog',
          where: 'cloud_id = ?',
          whereArgs: [service['id']],
        );
        
        final serviceData = {
          'cloud_id': service['id'],
          'shop_id': service['shop_id'],
          'name': service['name'],
          'description': service['description'] ?? '',
          'category': service['category'] ?? '',
          'duration_minutes': service['duration_minutes'] ?? 30,
          'price': service['price'],
          'active': (service['active'] ?? service['is_active']) ?? 1,
          'created_at': DateTime.parse(service['created_at']).millisecondsSinceEpoch,
          'updated_at': DateTime.parse(service['updated_at']).millisecondsSinceEpoch,
        };
        
        if (existing.isEmpty) {
          await DbProvider.insert('services_catalog', serviceData);
        } else {
          await DbProvider.update('services_catalog', serviceData,
            where: 'cloud_id = ?', whereArgs: [service['id']]);
        }
      }
      
      debugPrint('✅ Pulled ${response.length} services');
    } catch (e) {
      debugPrint('⚠️ Failed to pull services catalog: $e');
    }
  }
  
  /// Pull services bookings from cloud
  static Future<void> _pullServicesBookings(String shopId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('services_bookings')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(100);
      
      for (final booking in response) {
        final existing = await DbProvider.query(
          'services_bookings',
          where: 'cloud_id = ?',
          whereArgs: [booking['id']],
        );
        
        final bookingData = {
          'cloud_id': booking['id'],
          'source_module': 'services',
          'service_id': booking['service_id'],
          'staff_id': booking['staff_id'],
          'customer_name': booking['customer_name'] ?? '',
          'customer_phone': booking['customer_phone'] ?? '',
          'customer_email': booking['customer_email'] ?? '',
          'start_time': booking['start_time'] != null 
              ? DateTime.parse(booking['start_time']).millisecondsSinceEpoch
              : null,
          'end_time': booking['end_time'] != null
              ? DateTime.parse(booking['end_time']).millisecondsSinceEpoch
              : null,
          'status': booking['status'] ?? 'pending',
          'deposit_paid': booking['deposit_paid'] ?? 0.0,
          'notes': booking['notes'] ?? '',
          'created_at': DateTime.parse(booking['created_at']).millisecondsSinceEpoch,
          'updated_at': DateTime.parse(booking['updated_at']).millisecondsSinceEpoch,
        };
        
        if (existing.isEmpty) {
          await DbProvider.insert('services_bookings', bookingData);
        } else {
          await DbProvider.update('services_bookings', bookingData,
            where: 'cloud_id = ?', whereArgs: [booking['id']]);
        }
      }
      
      debugPrint('✅ Pulled ${response.length} service bookings');
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') {
        debugPrint('ℹ️ services_bookings table not in Supabase yet, skipping');
      } else {
        debugPrint('⚠️ Failed to pull service bookings: $e');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to pull service bookings: $e');
    }
  }
  
  /// Pull customers from cloud
  static Future<void> _pullCustomers(String shopId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('customers')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(200);
      
      for (final customer in response) {
        final existing = await DbProvider.query(
          'customers',
          where: 'cloud_id = ?',
          whereArgs: [customer['id']],
        );
        
        final customerData = {
          'cloud_id': customer['id'],
          'shop_id': customer['shop_id'],
          'name': customer['name'],
          'phone': customer['phone'] ?? '',
          'email': customer['email'] ?? '',
          'address': customer['address'] ?? '',
          'notes': customer['notes'] ?? '',
          'created_at': DateTime.parse(customer['created_at']).millisecondsSinceEpoch,
          'updated_at': DateTime.parse(customer['updated_at']).millisecondsSinceEpoch,
        };
        
        if (existing.isEmpty) {
          await DbProvider.insert('customers', customerData);
        } else {
          await DbProvider.update('customers', customerData,
            where: 'cloud_id = ?', whereArgs: [customer['id']]);
        }
      }
      
      debugPrint('✅ Pulled ${response.length} customers');
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') {
        debugPrint('ℹ️ Customers table not in Supabase yet, skipping');
      } else {
        debugPrint('⚠️ Failed to pull customers: $e');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to pull customers: $e');
    }
  }
  
  /// Pull transactions from cloud
  static Future<void> _pullTransactions(String shopId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('transactions')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(100);
      
      for (final txn in response) {
        final existing = await DbProvider.query(
          'txn',
          where: 'cloud_id = ?',
          whereArgs: [txn['id']],
        );
        
        final txnData = {
          'cloud_id': txn['id'],
          'shop_id': txn['shop_id'],
          'type': txn['transaction_type'] ?? 'sale',
          'totalAmount': txn['total_amount'],
          'customerName': txn['customer_name'] ?? '',
          'payment_method': txn['payment_method'] ?? 'cash',
          'details': txn['module_data'] ?? '',
          'receiptSignature': txn['local_signature'] ?? '',
          'source_module': txn['source_module'] ?? 'retail',
          'created_at': DateTime.parse(txn['created_at']).millisecondsSinceEpoch,
        };
        
        if (existing.isEmpty) {
          await DbProvider.insert('txn', txnData);
        } else {
          await DbProvider.update('txn', txnData,
            where: 'cloud_id = ?', whereArgs: [txn['id']]);
        }
      }
      
      debugPrint('✅ Pulled ${response.length} transactions');
    } catch (e) {
      debugPrint('⚠️ Failed to pull transactions: $e');
    }
  }
  
  /// Pull entertainment assets from cloud
  static Future<void> _pullEntertainmentAssets(String shopId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('entertainment_assets')
          .select()
          .eq('shop_id', shopId)
          .eq('is_active', true);
      
      for (final asset in response) {
        final existing = await DbProvider.query(
          'entertainment_assets',
          where: 'cloud_id = ?',
          whereArgs: [asset['id']],
        );
        
        final assetData = {
          'cloud_id': asset['id'],
          'shop_id': asset['shop_id'],
          'name': asset['name'],
          'category': asset['category'] ?? '',
          'asset_type': asset['asset_type'] ?? 'hourly',
          'rate_per_hour': asset['rate_per_hour'] ?? 0.0,
          'flat_rate': asset['flat_rate'] ?? 0.0,
          'is_active': asset['is_active'] ?? 1,
          'created_at': DateTime.parse(asset['created_at']).millisecondsSinceEpoch,
          'updated_at': DateTime.parse(asset['updated_at']).millisecondsSinceEpoch,
        };
        
        if (existing.isEmpty) {
          await DbProvider.insert('entertainment_assets', assetData);
        } else {
          await DbProvider.update('entertainment_assets', assetData,
            where: 'cloud_id = ?', whereArgs: [asset['id']]);
        }
      }
      
      debugPrint('✅ Pulled ${response.length} entertainment assets');
    } catch (e) {
      debugPrint('⚠️ Failed to pull entertainment assets: $e');
    }
  }
  
  /// Pull entertainment sessions from cloud
  static Future<void> _pullEntertainmentSessions(String shopId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('entertainment_sessions')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(50);
      
      for (final session in response) {
        final existing = await DbProvider.query(
          'entertainment_sessions',
          where: 'cloud_id = ?',
          whereArgs: [session['id']],
        );
        
        final sessionData = {
          'cloud_id': session['id'],
          'shop_id': session['shop_id'],
          'asset_id': session['asset_id'],
          'customer_name': session['customer_name'] ?? '',
          'started_at': session['started_at'] != null
              ? DateTime.parse(session['started_at']).millisecondsSinceEpoch
              : null,
          'ended_at': session['ended_at'] != null
              ? DateTime.parse(session['ended_at']).millisecondsSinceEpoch
              : null,
          'billing_type': session['billing_type'] ?? 'hourly',
          'rate': session['rate'] ?? 0.0,
          'total_amount': session['total_amount'] ?? 0.0,
          'status': session['status'] ?? 'active',
          'created_at': DateTime.parse(session['created_at']).millisecondsSinceEpoch,
        };
        
        if (existing.isEmpty) {
          await DbProvider.insert('entertainment_sessions', sessionData);
        } else {
          await DbProvider.update('entertainment_sessions', sessionData,
            where: 'cloud_id = ?', whereArgs: [session['id']]);
        }
      }
      
      debugPrint('✅ Pulled ${response.length} entertainment sessions');
    } catch (e) {
      debugPrint('⚠️ Failed to pull entertainment sessions: $e');
    }
  }
  
  /// Pull lodging rooms from cloud
  static Future<void> _pullLodgingRooms(String shopId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('lodging_rooms')
          .select()
          .eq('shop_id', shopId)
          .eq('is_active', true);
      
      for (final room in response) {
        final existing = await DbProvider.query(
          'lodging_rooms',
          where: 'cloud_id = ?',
          whereArgs: [room['id']],
        );
        
        final roomData = {
          'cloud_id': room['id'],
          'shop_id': room['shop_id'],
          'name': room['name'],
          'room_type': room['room_type'] ?? 'Standard',
          'floor': room['floor'] ?? 1,
          'capacity': room['capacity'] ?? 2,
          'rate_per_night': room['rate_per_night'] ?? 0.0,
          'amenities': room['amenities'] ?? '',
          'description': room['description'] ?? '',
          'status': room['status'] ?? 'available',
          'is_active': room['is_active'] ?? 1,
          'created_at': DateTime.parse(room['created_at']).millisecondsSinceEpoch,
          'updated_at': DateTime.parse(room['updated_at']).millisecondsSinceEpoch,
        };
        
        if (existing.isEmpty) {
          await DbProvider.insert('lodging_rooms', roomData);
        } else {
          await DbProvider.update('lodging_rooms', roomData,
            where: 'cloud_id = ?', whereArgs: [room['id']]);
        }
      }
      
      debugPrint('✅ Pulled ${response.length} lodging rooms');
    } catch (e) {
      debugPrint('⚠️ Failed to pull lodging rooms: $e');
    }
  }
  
  /// Pull lodging reservations from cloud
  static Future<void> _pullLodgingReservations(String shopId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('lodging_reservations')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(50);
      
      // Cloud stores timestamptz, local SQLite stores INTEGER millis. Convert.
      int? isoToMs(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is String && v.isNotEmpty) {
          final asInt = int.tryParse(v);
          if (asInt != null) return asInt;
          try { return DateTime.parse(v).millisecondsSinceEpoch; } catch (_) { return null; }
        }
        return null;
      }

      for (final reservation in response) {
        final existing = await DbProvider.query(
          'lodging_reservations',
          where: 'cloud_id = ?',
          whereArgs: [reservation['id']],
        );

        final reservationData = {
          'cloud_id': reservation['id'],
          'shop_id': reservation['shop_id'],
          // Cloud room_id is uuid; we mirror it into a separate cloud-id column
          // and resolve the local int FK elsewhere if/when the room is pulled.
          'room_cloud_id': reservation['room_id'],
          'guest_name': reservation['guest_name'] ?? '',
          'guest_phone': reservation['guest_phone'] ?? '',
          'guest_email': reservation['guest_email'] ?? '',
          'guest_id_number': reservation['guest_id_number'] ?? '',
          'check_in_date': isoToMs(reservation['check_in_date']),
          'check_out_date': isoToMs(reservation['check_out_date']),
          'actual_check_in': isoToMs(reservation['actual_check_in']),
          'actual_check_out': isoToMs(reservation['actual_check_out']),
          'nights': reservation['nights'] ?? 1,
          'rate_per_night': reservation['rate_per_night'] ?? 0.0,
          'extras_total': reservation['extras_total'] ?? 0.0,
          'total_amount': reservation['total_amount'] ?? 0.0,
          'amount_paid': reservation['amount_paid'] ?? 0.0,
          'status': reservation['status'] ?? 'pending',
          'created_at': isoToMs(reservation['created_at']) ?? DateTime.now().millisecondsSinceEpoch,
          'updated_at': isoToMs(reservation['updated_at']) ?? DateTime.now().millisecondsSinceEpoch,
        };
        
        if (existing.isEmpty) {
          await DbProvider.insert('lodging_reservations', reservationData);
        } else {
          await DbProvider.update('lodging_reservations', reservationData,
            where: 'cloud_id = ?', whereArgs: [reservation['id']]);
        }
      }
      
      debugPrint('✅ Pulled ${response.length} lodging reservations');
    } catch (e) {
      debugPrint('⚠️ Failed to pull lodging reservations: $e');
    }
  }
}
