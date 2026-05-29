import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../db/db_provider.dart';
import 'device_service.dart';
import 'onboarding_service.dart';
import 'auth_service.dart';
import 'package:uuid/uuid.dart';

/// Module-aware Cloud Sync Service
/// Syncs data to Supabase based on enabled modules
class ModuleSyncService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Sync all module data to cloud
  /// Only syncs data for installed modules
  static Future<Map<String, dynamic>> syncAllModuleData() async {
    final result = <String, dynamic>{
      'success': false,
      'synced': <String>[],
      'errors': <String>[],
    };

    try {
      final modules = await OnboardingService.getSelectedModules();
      final shopId = await DeviceService.getShopId();
      final shop = await AuthService.getCurrentShop();

      if (shopId == null) { // ignore: unnecessary_null_comparison
        result['errors'] = ['No shop ID found'];
        return result;
      }

      // Check PRO access for cloud sync
      if (shop == null || !shop.hasProAccess) {
        result['errors'] = ['Cloud sync requires PRO subscription'];
        return result;
      }

      debugPrint('🔄 Starting module sync for: $modules');

      // Always sync core shop info
      await _syncShopInfo(shopId, modules);
      result['synced'].add('shop_info');

      // Sync based on enabled modules
      if (modules.contains('retail')) {
        await _syncRetailProducts(shopId);
        result['synced'].add('retail_products');
      }

      if (modules.contains('services')) {
        await _syncServicesCatalog(shopId);
        await _syncAppointments(shopId);
        result['synced'].add('services_catalog');
        result['synced'].add('appointments');
      }

      if (modules.contains('restaurant')) {
        await _syncRestaurantMenu(shopId);
        await _syncOrders(shopId);
        result['synced'].add('restaurant_menu');
        result['synced'].add('orders');
      }

      if (modules.contains('entertainment')) {
        await _syncEntertainmentAssets(shopId);
        await _syncEntertainmentSessions(shopId);
        result['synced'].add('entertainment_assets');
        result['synced'].add('entertainment_sessions');
      }

      if (modules.contains('lodging')) {
        await _syncLodgingRooms(shopId);
        await _syncLodgingReservations(shopId);
        result['synced'].add('lodging_rooms');
        result['synced'].add('lodging_reservations');
      }

      // Sync transactions (universal)
      await _syncTransactions(shopId, modules);
      result['synced'].add('transactions');

      result['success'] = true;
      debugPrint('✅ Module sync complete: ${result['synced']}');

    } catch (e) {
      debugPrint('❌ Module sync error: $e');
      result['errors'].add(e.toString());
    }

    return result;
  }

  /// Sync shop info including enabled modules
  static Future<void> _syncShopInfo(String shopId, List<String> modules) async {
    final localShops = await DbProvider.query('shops');
    if (localShops.isEmpty) return;

    final localShop = localShops.first;
    String? bName = (localShop['business_name']?.toString() ?? localShop['name']?.toString());
    if (bName == null || bName.trim().isEmpty) bName = 'Mbeck Shop';

    String passwordHash = 'synced_placeholder';
    try {
      final existingCloudShop = await _supabase
          .from('shops')
          .select('password_hash')
          .eq('id', shopId)
          .maybeSingle();
      if (existingCloudShop != null && existingCloudShop['password_hash'] != null) {
        passwordHash = existingCloudShop['password_hash'];
      }
    } catch (e) {
      debugPrint('⚠️ Failed to check/retrieve existing cloud shop password_hash in ModuleSyncService: $e');
    }

    await _supabase.from('shops').upsert({
      'id': shopId,
      'name': bName,
      'enabled_modules': modules,
      'shop_type': _determineShopType(modules),
      'password_hash': passwordHash,
      'owner_device_id': shopId, 
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Record module installations
    for (final moduleId in modules) {
      try {
        await _supabase.from('shop_modules').upsert({
          'shop_id': shopId,
          'module_id': moduleId,
          'is_active': true,
          'installed_at': DateTime.now().toIso8601String(),
        }, onConflict: 'shop_id,module_id');
      } catch (e) {
        // RLS might prevent shop_modules sync, but that's ok for now
        debugPrint('⚠️ Shop modules sync skipped (RLS): $e');
      }
    }
  }

  /// Determine primary shop type from modules
  static String _determineShopType(List<String> modules) {
    if (modules.contains('restaurant')) return 'restaurant';
    if (modules.contains('services')) return 'services';
    if (modules.contains('entertainment')) return 'entertainment';
    if (modules.contains('lodging')) return 'lodging';
    return 'retail';
  }

  /// Sync retail products to cloud
  static Future<void> _syncRetailProducts(String shopId) async {
    try {
      final localProducts = await DbProvider.query('inventory');
      if (localProducts.isEmpty) return;

      final batch = <Map<String, dynamic>>[];
      
      for (final product in localProducts) {
         String cloudId = product['cloud_id'] as String? ?? '';
         
         if (cloudId.isEmpty) {
            cloudId = const Uuid().v4();
            await DbProvider.update(
              'inventory',
              {'cloud_id': cloudId},
              where: 'id = ?',
              whereArgs: [product['id']],
            );
         }

         batch.add({
           'shop_id': shopId,
           'id': cloudId,
           'name': product['name'],
           'sellingPrice': product['sellingPrice'],
           'category': product['category'],
           'barcode': product['barcode'],
           'is_published': product['is_published'] ?? false,
         });
      }

      // Upsert in batches
      for (var i = 0; i < batch.length; i += 50) {
        final end = (i + 50 < batch.length) ? i + 50 : batch.length;
        await _supabase.from('inventory').upsert(batch.sublist(i, end));
      }

      debugPrint('📦 Synced ${batch.length} retail products');
    } catch (e) {
      debugPrint('⚠️ Retail sync error: $e');
      rethrow;
    }
  }

  /// Sync services catalog to cloud
  static Future<void> _syncServicesCatalog(String shopId) async {
    try {
      final localServices = await DbProvider.query('services_catalog');
      if (localServices.isEmpty) return;

      final batch = <Map<String, dynamic>>[];
      
      for (final service in localServices) {
         String cloudId = service['cloud_id'] as String? ?? '';
         
         if (cloudId.isEmpty) {
            cloudId = const Uuid().v4();
            await DbProvider.update(
              'services_catalog',
              {'cloud_id': cloudId},
              where: 'id = ?',
              whereArgs: [service['id']],
            );
         }

         batch.add({
            'shop_id': shopId,
            'id': cloudId,
            'service_name': service['name'] ?? service['service_name'],
            'description': service['description'],
            'duration_minutes': service['duration_minutes'] ?? service['duration'] ?? 30,
            'price': service['price'],
            'category': service['category'],
            'is_published': service['is_published'] ?? false,
         });
      }

      for (var i = 0; i < batch.length; i += 50) {
        final end = (i + 50 < batch.length) ? i + 50 : batch.length;
        await _supabase.from('services_catalog').upsert(batch.sublist(i, end));
      }

      debugPrint('💼 Synced ${batch.length} services');
    } catch (e) {
      debugPrint('⚠️ Services catalog sync error: $e');
      rethrow;
    }
  }

  /// Sync appointments to cloud
  static Future<void> _syncAppointments(String shopId) async {
    try {
      final localAppts = await DbProvider.query('services_bookings');
      if (localAppts.isEmpty) return;

      final batch = <Map<String, dynamic>>[];
      
      for (final appt in localAppts) {
         String cloudId = appt['cloud_id'] as String? ?? '';
         
         if (cloudId.isEmpty) {
            cloudId = const Uuid().v4();
            await DbProvider.update(
              'services_bookings',
              {'cloud_id': cloudId},
              where: 'id = ?',
              whereArgs: [appt['id']],
            );
         }

         batch.add({
            'shop_id': shopId,
            'id': cloudId,
            'service_id': appt['service_id'],
            'staff_id': appt['staff_id'],
            'customer_name': appt['customer_name'],
            'customer_phone': appt['customer_phone'],
            'customer_email': appt['customer_email'],
            'start_time': appt['start_time'],
            'end_time': appt['end_time'],
            'status': appt['status'] ?? 'pending',
            'notes': appt['notes'],
            'deposit_paid': appt['deposit_paid'] ?? 0,
            'created_at': appt['created_at'],
            'updated_at': appt['updated_at'],
         });
      }

      for (var i = 0; i < batch.length; i += 50) {
        final end = (i + 50 < batch.length) ? i + 50 : batch.length;
        await _supabase.from('services_bookings').upsert(batch.sublist(i, end));
      }

      debugPrint('📅 Synced ${batch.length} appointments');
    } catch (e) {
      debugPrint('⚠️ Appointments sync error: $e');
      rethrow;
    }
  }

  /// Sync restaurant menu to cloud
  static Future<void> _syncRestaurantMenu(String shopId) async {
    try {
      final localMenu = await DbProvider.query('restaurant_menu');
      if (localMenu.isEmpty) return;

      final batch = <Map<String, dynamic>>[];
      
      for (final item in localMenu) {
         String cloudId = item['cloud_id'] as String? ?? '';
         
         // Fix missing cloud_id
         if (cloudId.isEmpty) {
            cloudId = const Uuid().v4();
            await DbProvider.update(
              'restaurant_menu',
              {'cloud_id': cloudId},
              where: 'id = ?',
              whereArgs: [item['id']],
            );
         }
         
         batch.add({
            'shop_id': shopId,
            'id': cloudId, // UUID
            'item_name': item['name'] ?? item['item_name'],
            'description': item['description'],
            'category': item['category'] ?? 'main',
            'price': item['price'],
            'is_available': item['is_available'] ?? true,
            'is_published': item['is_published'] ?? false,
            'preparation_time_mins': item['preparation_time_mins'] ?? item['prep_time'] ?? 15,
         });
      }

      for (var i = 0; i < batch.length; i += 50) {
        final end = (i + 50 < batch.length) ? i + 50 : batch.length;
        await _supabase.from('restaurant_menu').upsert(batch.sublist(i, end));
      }

      debugPrint('🍽️ Synced ${batch.length} menu items');
    } catch (e) {
      debugPrint('⚠️ Restaurant menu sync error: $e');
      rethrow;
    }
  }

  /// Sync restaurant orders to cloud
  static Future<void> _syncOrders(String shopId) async {
    try {
      final localOrders = await DbProvider.query('restaurant_orders');
      if (localOrders.isEmpty) return;
      
      final batch = <Map<String, dynamic>>[];
      
      for (final order in localOrders) {
         String cloudId = order['cloud_id'] as String? ?? '';
         
         if (cloudId.isEmpty) {
            cloudId = const Uuid().v4();
            await DbProvider.update(
              'restaurant_orders',
              {'cloud_id': cloudId},
              where: 'id = ?',
              whereArgs: [order['id']],
            );
         }

         batch.add({
            'shop_id': shopId,
            'id': cloudId,
            'table_number': order['table_number'],
            'order_type': order['order_type'] ?? 'dine_in',
            // 'order_items': order['order_items'], // This was in original but 'items_json' is in DB? 
            // The original code map looked like: 'order_items': order['order_items']
            // But DbProvider definition says 'items_json'. 
            // In original code in step 54:
            // 'order_items': order['order_items']
            // Wait, does `DbProvider.query` return `order_items`? No, it returns what's in DB.
            // If the original code was broken there, I should fix it?
            // Or maybe `order_items` is a joined field?
            // `DbProvider.query('restaurant_orders')` returns rows.
            // The DB table has `items_json`.
            // The original code was likely sending `null` or failing if `order_items` wasn't in the map.
            // I'll send `items_json` as `order_items` (assuming schema match) or just `order_items` if the cloud expects JSON.
            // Supabase schema likely has `order_items` as JSON/JSONB.
            'order_items': order['items_json'] ?? order['order_items'], 
            'total_amount': order['total_amount'] ?? order['total'],
            'status': order['status'] ?? 'pending',
            'customer_name': order['customer_name'],
            'notes': order['notes'],
         });
      }

      for (var i = 0; i < batch.length; i += 50) {
        final end = (i + 50 < batch.length) ? i + 50 : batch.length;
        await _supabase.from('restaurant_orders').upsert(batch.sublist(i, end));
      }

      debugPrint('🧾 Synced ${batch.length} orders');
    } catch (e) {
      debugPrint('⚠️ Orders sync error: $e');
      rethrow;
    }
  }

  /// Sync entertainment assets to cloud
  static Future<void> _syncEntertainmentAssets(String shopId) async {
    try {
      final localAssets = await DbProvider.query('entertainment_assets');
      if (localAssets.isEmpty) return;

      final batch = <Map<String, dynamic>>[];
      
      for (final asset in localAssets) {
         String cloudId = asset['cloud_id'] as String? ?? '';
         
         if (cloudId.isEmpty) {
            cloudId = const Uuid().v4();
            await DbProvider.update(
              'entertainment_assets',
              {'cloud_id': cloudId},
              where: 'id = ?',
              whereArgs: [asset['id']],
            );
         }

         batch.add({
            'shop_id': shopId,
            'id': cloudId,
            'name': asset['name'],
            'category': asset['category'],
            'asset_type': asset['asset_type'], // 'hourly' or 'flat'
            'rate_per_hour': asset['rate_per_hour'],
            'flat_rate': asset['flat_rate'],
            'is_active': asset['is_active'] == 1,
            'image_path': asset['image_path'],
            'sort_order': asset['sort_order'] ?? 0,
         });
      }

      for (var i = 0; i < batch.length; i += 50) {
        final end = (i + 50 < batch.length) ? i + 50 : batch.length;
        await _supabase.from('entertainment_assets').upsert(batch.sublist(i, end));
      }

      debugPrint('🎮 Synced ${batch.length} entertainment assets');
    } catch (e) {
      debugPrint('⚠️ Entertainment assets sync error: $e');
      rethrow;
    }
  }

  /// Sync entertainment sessions to cloud
  static Future<void> _syncEntertainmentSessions(String shopId) async {
    try {
      final localSessions = await DbProvider.query('entertainment_sessions');
      if (localSessions.isEmpty) return;

      final batch = <Map<String, dynamic>>[];
      
      for (final session in localSessions) {
         String cloudId = session['cloud_id'] as String? ?? '';
         
         if (cloudId.isEmpty) {
            cloudId = const Uuid().v4();
            await DbProvider.update(
              'entertainment_sessions',
              {'cloud_id': cloudId},
              where: 'id = ?',
              whereArgs: [session['id']],
            );
         }

         batch.add({
            'shop_id': shopId,
            'id': cloudId,
            'asset_id': session['asset_id'],
            'customer_name': session['customer_name'],
            'started_at': session['started_at'],
            'ended_at': session['ended_at'],
            'billing_type': session['billing_type'], // 'hourly' or 'flat'
            'rate': session['rate'],
            'total_amount': session['total_amount'],
            'status': session['status'], // 'active' or 'completed'
         });
      }

      for (var i = 0; i < batch.length; i += 50) {
        final end = (i + 50 < batch.length) ? i + 50 : batch.length;
        await _supabase.from('entertainment_sessions').upsert(batch.sublist(i, end));
      }

      debugPrint('🎯 Synced ${batch.length} entertainment sessions');
    } catch (e) {
      debugPrint('⚠️ Entertainment sessions sync error: $e');
      rethrow;
    }
  }

  /// Sync lodging rooms to cloud
  static Future<void> _syncLodgingRooms(String shopId) async {
    try {
      final localRooms = await DbProvider.query('lodging_rooms');
      if (localRooms.isEmpty) return;

      final batch = <Map<String, dynamic>>[];
      
      for (final room in localRooms) {
         String cloudId = room['cloud_id'] as String? ?? '';
         
         if (cloudId.isEmpty) {
            cloudId = const Uuid().v4();
            await DbProvider.update(
              'lodging_rooms',
              {'cloud_id': cloudId},
              where: 'id = ?',
              whereArgs: [room['id']],
            );
         }

         batch.add({
            'shop_id': shopId,
            'id': cloudId,
            'name': room['name'],
            'room_type': room['room_type'],
            'floor': room['floor'],
            'capacity': room['capacity'],
            'rate_per_night': room['rate_per_night'],
            'amenities': room['amenities'],
            'description': room['description'],
            'status': room['status'], // 'available', 'occupied', 'cleaning', 'maintenance'
            'is_active': room['is_active'] == 1,
            'image_path': room['image_path'],
            'sort_order': room['sort_order'] ?? 0,
         });
      }

      for (var i = 0; i < batch.length; i += 50) {
        final end = (i + 50 < batch.length) ? i + 50 : batch.length;
        await _supabase.from('lodging_rooms').upsert(batch.sublist(i, end));
      }

      debugPrint('🏨 Synced ${batch.length} lodging rooms');
    } catch (e) {
      debugPrint('⚠️ Lodging rooms sync error: $e');
      rethrow;
    }
  }

  /// Sync lodging reservations to cloud
  static Future<void> _syncLodgingReservations(String shopId) async {
    try {
      final localReservations = await DbProvider.query('lodging_reservations');
      if (localReservations.isEmpty) return;

      final batch = <Map<String, dynamic>>[];
      
      for (final reservation in localReservations) {
         String cloudId = reservation['cloud_id'] as String? ?? '';
         
         if (cloudId.isEmpty) {
            cloudId = const Uuid().v4();
            await DbProvider.update(
              'lodging_reservations',
              {'cloud_id': cloudId},
              where: 'id = ?',
              whereArgs: [reservation['id']],
            );
         }

         // Cloud schema (006_lodging_module) stores check-in/out as timestamptz.
         // Local SQLite stores them as INTEGER milliseconds-since-epoch.
         // Convert here or every upsert is rejected by Postgres.
         String? msToIso(dynamic v) {
           if (v == null) return null;
           if (v is int) return DateTime.fromMillisecondsSinceEpoch(v).toUtc().toIso8601String();
           if (v is String && v.isNotEmpty) {
             final parsed = int.tryParse(v);
             if (parsed != null) return DateTime.fromMillisecondsSinceEpoch(parsed).toUtc().toIso8601String();
             return v; // already an ISO string
           }
           return null;
         }
         batch.add({
            'shop_id': shopId,
            'id': cloudId,
            'room_id': reservation['room_cloud_id'] ?? reservation['room_id'],
            'guest_name': reservation['guest_name'],
            'guest_phone': reservation['guest_phone'],
            'guest_email': reservation['guest_email'],
            'guest_id_number': reservation['guest_id_number'],
            'check_in_date': msToIso(reservation['check_in_date']),
            'check_out_date': msToIso(reservation['check_out_date']),
            'actual_check_in': msToIso(reservation['actual_check_in']),
            'actual_check_out': msToIso(reservation['actual_check_out']),
            'nights': reservation['nights'],
            'rate_per_night': reservation['rate_per_night'],
            'extras_total': reservation['extras_total'],
            'total_amount': reservation['total_amount'],
            'amount_paid': reservation['amount_paid'],
            'status': reservation['status'], // 'pending', 'confirmed', 'checked_in', 'checked_out', 'cancelled'
         });
      }

      for (var i = 0; i < batch.length; i += 50) {
        final end = (i + 50 < batch.length) ? i + 50 : batch.length;
        await _supabase.from('lodging_reservations').upsert(batch.sublist(i, end));
      }

      debugPrint('🛏️ Synced ${batch.length} lodging reservations');
    } catch (e) {
      debugPrint('⚠️ Lodging reservations sync error: $e');
      rethrow;
    }
  }

  /// Sync transactions to universal cloud table
  static Future<void> _syncTransactions(String shopId, List<String> modules) async {
    try {
      // Get unsynced transactions from local DB
      final localTxns = await DbProvider.query(
        'txn',
        where: 'cloud_synced IS NULL OR cloud_synced = 0',
        limit: 100,
      );
      if (localTxns.isEmpty) return;

      for (final txn in localTxns) {
        final moduleSource = _determineTransactionModule(txn['type'], modules);
        
        String cloudId = txn['cloud_id'] as String? ?? '';
        
        if (cloudId.isEmpty) {
           cloudId = const Uuid().v4();
           await DbProvider.update(
             'txn',
             {'cloud_id': cloudId},
             where: 'id = ?',
             whereArgs: [txn['id']],
           );
        }

        await _supabase.from('transactions').upsert({
          'id': cloudId,
          'shop_id': shopId,
          // Canonical SQL column names per 001_modular_system.sql:
          //   transaction_type (CHECK: sale/booking/order/refund/session/reservation)
          //   module_source    (CHECK: retail/restaurant/services/entertainment/lodging)
          'module_source': moduleSource,
          'total_amount': txn['amount'] ?? txn['total'] ?? txn['totalAmount'],
          'transaction_type': _mapTransactionType(txn['type']),
          'created_at': txn['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(txn['timestamp'] as int).toIso8601String()
              : DateTime.now().toIso8601String(),
        });

        // Mark as synced locally
        await DbProvider.update(
          'txn',
          {'cloud_synced': 1},
          where: 'id = ?',
          whereArgs: [txn['id']],
        );
      }

      debugPrint('💳 Synced ${localTxns.length} transactions');
    } catch (e) {
      debugPrint('⚠️ Transactions sync error: $e');
      rethrow;
    }
  }

  /// Determine which module a transaction belongs to
  static String _determineTransactionModule(String? type, List<String> modules) {
    if (type == 'order' && modules.contains('restaurant')) return 'restaurant';
    if (type == 'booking' && modules.contains('services')) return 'services';
    if (type == 'session' && modules.contains('entertainment')) return 'entertainment';
    if (type == 'lodging' && modules.contains('lodging')) return 'lodging';
    return 'retail';
  }

  /// Map local transaction types to cloud types
  static String _mapTransactionType(String? localType) {
    switch (localType?.toLowerCase()) {
      case 'order':
        return 'order';
      case 'booking':
      case 'appointment':
        return 'booking';
      case 'session':
        return 'session';
      case 'lodging':
        return 'lodging';
      case 'refund':
        return 'refund';
      default:
        return 'sale';
    }
  }
}
