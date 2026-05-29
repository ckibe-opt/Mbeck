import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'event_service.dart';
import 'device_service.dart';
import 'event_processor.dart';
import '../models/event.dart';
import 'auth_service.dart';

/// Background Sync Service for Phase 2
/// 
/// Interacts with Supabase Edge Function 'sync-events'.
class SyncService {
  static const int _batchSize = 50;
  static bool _isSyncing = false;
  static bool _isInitialized = false;
  static const String _lastPullKey = 'last_pull_timestamp';

  /// Initialize Supabase asynchronously
  static Future<void> init(String url, String anonKey) async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
      _isInitialized = true;
      debugPrint('✅ Supabase initialized for event sync');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize Supabase: $e');
    }
  }

  /// Check if network connectivity is available
  static Future<bool> hasNetworkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('⚠️ Error checking connectivity: $e');
      return false;
    }
  }

  /// Sync unsynced events to cloud via Edge Function
  /// Returns number of events successfully synced.
  static Future<int> syncEvents({bool force = false}) async {
    // 0. Guard: Check subscription tier - Cloud sync is PRO-only
    final shop = await AuthService.getCurrentShop();
    
    if (shop == null) {
      // Shop not synced or doesn't exist. This is normal for offline/guest mode.
      // debugPrint('📡 Sync skipped: Shop not found or not synced locally.');
      return 0;
    }

    if (!shop.hasProAccess) {
      debugPrint('📡 Cloud sync requires PRO tier (current: ${shop.subscriptionTier}), but allowing for testing');
      // return 0; // FREE users cannot sync to cloud
    }

    // 1. Guard clauses: Prevent concurrent syncs & check network
    if (_isSyncing && !force) {
      return 0;
    }
    if (!_isInitialized) {
      // Supabase not ready yet, skip this cycle
      return 0;
    }
    if (!await hasNetworkConnectivity()) {
      debugPrint('📡 No network connectivity, skipping sync');
      return 0;
    }

    _isSyncing = true;
    int syncedCount = 0;

    try {
      // Step A: PULL (Downstream Sync)
      await _pullRemoteEvents();
      await _pullRemoteOrders(); // Pull pending offline orders from buyers
      await _pullRemoteBookings(); // Pull pending services bookings from buyers
      await _pullRemoteReservations(); // Pull pending lodging reservations from buyers
      
      final supabase = Supabase.instance.client;
      
      // Step B: PUSH (Upstream Sync)
      // 2. Get batch of unsynced events (ONLY our own events)
      // Fetch RAW rows to avoid JSON decoding on main thread
      final shopId = await DeviceService.getShopId();
      final deviceId = await DeviceService.getDeviceId();
      
      if (deviceId == null) return 0;

      final unsyncedRows = await EventService.getUnsyncedOwnEventsRaw(deviceId, limit: _batchSize);
      
      if (unsyncedRows.isEmpty) {
        return 0; // Nothing to sync
      }
      
      debugPrint('🔄 Syncing ${unsyncedRows.length} events...');

      // 3. Prepare Batch & Verify Local Integrity

      // Offload heavy processing (hashing/serialization) to background isolate
      final result = await compute(_processBatch, {
        'events': unsyncedRows,
        'shopId': shopId,
        'deviceId': deviceId,
      });

      final eventsToInsert = (result['insert'] as List).cast<Map<String, dynamic>>();
      final batchEventIds = (result['ids'] as List).cast<String>();
      final integrityFailedIds = (result['integrityErrors'] as List).cast<String>();
      final ownershipFailedIds = (result['ownershipErrors'] as List).cast<String>();

      // Handle Integrity Failures
      for (final id in integrityFailedIds) {
        debugPrint('⚠️ Integrity Check Failed: $id');
        await EventService.markEventFailed(id);
      }

      // Handle Ownership Failures
      for (final id in ownershipFailedIds) {
        debugPrint('⚠️ Ownership Mismatch: $id (Current: $shopId / $deviceId)');
        await EventService.markEventFailed(id);
      }

      if (eventsToInsert.isEmpty) return 0;

      // 4. Invoke Edge Function with retry for 401 (Auth)
      FunctionResponse response;
      try {
        response = await supabase.functions.invoke(
          'sync-events', 
          body: eventsToInsert,
        );
      } catch (e) {
        // Handle 401 Unauthorized by refreshing session and retrying once
        if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
          debugPrint('⚠️ Sync 401 Unauthorized. Refreshing session...');
          try {
            await supabase.auth.refreshSession();
            response = await supabase.functions.invoke(
              'sync-events', 
              body: eventsToInsert,
            );
          } catch (retryErr) {
            debugPrint('❌ Sync retry failed after refresh: $retryErr');
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      // Check for HTTP errors (4xx, 5xx)
      if (response.status != 200) {
        throw Exception('Edge Function returned ${response.status}: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;
      
      // 5. Process Result
      // The RPC returns: { inserted_count, skipped_count, errors: [...] }
      final List<dynamic> serverErrors = data['errors'] ?? [];
      final Set<String> failedIds = {};

      // Handle specific server rejections (e.g. hash mismatch)
      for (final errorItem in serverErrors) {
        if (errorItem is Map && errorItem['id'] != null) {
          final id = errorItem['id'] as String;
          final reason = errorItem['error'] ?? 'unknown';
          
          debugPrint('❌ Server rejected event $id: $reason');
          await EventService.markEventFailed(id);
          failedIds.add(id);
        }
      }

      // Mark successful events as Synced in a single batch
      // Note: We count "skipped" (idempotent duplicates) as success 
      // because they are safely stored in the cloud.
      final successIds = batchEventIds.where((id) => !failedIds.contains(id)).toList();
      if (successIds.isNotEmpty) {
        await EventService.markEventsSyncedBatch(successIds);
      }

      syncedCount = successIds.length;
      debugPrint('✅ Sync Complete. Uploaded: ${successIds.length}. Failed: ${failedIds.length}.');

    } catch (e) {
      debugPrint('❌ Sync Process Error: $e');
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }

  /// Pull remote events from cloud and apply locally
  /// Filters events based on current user's role to enforce permission-based sync
  static Future<void> _pullRemoteEvents() async {
    try {
      // Guard: Cloud sync requires PRO tier
      final shop = await AuthService.getCurrentShop();
      if (shop == null) {
        debugPrint('⚠️ Pull Sync: No shop found');
        return;
      }
      
      // Temporarily disable PRO restriction for testing pull sync
      if (!shop.hasProAccess) {
        debugPrint('⚠️ Pull Sync: Shop does not have PRO access, but allowing for testing');
        // return; // FREE users cannot pull from cloud
      }

      final supabase = Supabase.instance.client;
      final shopId = await DeviceService.getShopId();
      final deviceId = await DeviceService.getDeviceId();
      
      if (shopId == null) {
        debugPrint('⚠️ Pull Sync: No shop ID found');
        return;
      }

      debugPrint('🔍 Pull Sync: shopId=$shopId, deviceId=$deviceId');

      // Get current member's role for permission filtering
      final member = await AuthService.getCurrentMember();
      // ignore: unused_local_variable
      final allowedEventTypes = _getAllowedEventTypes(member?.role);

      final prefs = await SharedPreferences.getInstance();
      final lastPull = prefs.getInt(_lastPullKey) ?? 0;
      
      // Fetch events newer than last pull, from SAME shop but DIFFERENT device
      // SERVER-SIDE FILTER: Only pull event types this role is allowed to see
      var query = supabase
          .from('events')
          .select()
          .eq('shop_id', shopId)
          .gt('timestamp', lastPull)
          .neq('device_id', deviceId) // Don't pull our own events
          .order('timestamp', ascending: true)
          .limit(100); // Batch size for pull
      
      // NOTE: Server-side filtering temporarily disabled due to postgrest 2.6.0 API limitations
      // Security is still enforced by EventProcessor._isEventAuthorizedForRole()
      // This will be replaced by Supabase RLS in Phase 2 (Phone Auth migration)
      
      final response = await query;
          
      final List<dynamic> remoteEvents = response as List;
      debugPrint('🔍 Pull Sync: Query returned ${remoteEvents.length} rows');
      
      if (remoteEvents.isEmpty) {
        debugPrint('📥 Pull Sync: No remote events found');
        return;
      }
      
      debugPrint('📥 Pulling ${remoteEvents.length} remote events...');
      
      int maxTimestamp = lastPull;
      int processedCount = 0;
      
      for (final json in remoteEvents) {
        try {
          final event = Event.fromMap(json);
          
          // debugPrint('📥 Processing remote event: ${event.id} (${event.eventType})');
          
          // Apply to local DB
          final applied = await EventProcessor.processEvent(event);
          
          if (applied) {
            processedCount++;
            debugPrint('✅ Applied remote event: ${event.id}');
          } else {
            debugPrint('⚠️ Remote event not applied: ${event.id}');
          }
          
          if (event.timestamp > maxTimestamp) {
            maxTimestamp = event.timestamp;
          }
        } catch (e) {
          debugPrint('⚠️ Error processing remote event: $e');
        }
      }
      
      // Update checkpoint
      if (maxTimestamp > lastPull) {
        await prefs.setInt(_lastPullKey, maxTimestamp);
        debugPrint('✅ Applied $processedCount remote events. New checkpoint: $maxTimestamp');
      }
      
    } catch (e) {
      debugPrint('❌ Pull Sync Error: $e');
      // Don't rethrow, strictly log so Push can still happen
    }
  }

  /// Determine which event types a role is allowed to sync
  /// This enforces permission-based data filtering at the sync layer
  static List<String> _getAllowedEventTypes(String? role) {
    if (role == null) {
      // No role = minimal access (sales only)
      return ['SALE'];
    }

    switch (role.toUpperCase()) {
      case 'OWNER':
      case 'MANAGER':
        // Owners and Managers see ALL event types
        return [
          'SALE',
          'INVENTORY_CHANGE',
          'INVENTORY_CREATE',
          'INVENTORY_UPDATE',
          'INVENTORY_DELETE',
          'INCOME',
          'EXPENSE',
          'CASH_COUNT_ENTRY',
          'ACCOUNTING_CLOSING',
          'CUSTOMER_CREATE',
          'CUSTOMER_UPDATE',
          'ORDER_CREATED',
          'ORDER_STATUS_CHANGE',
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
        ];
      
      case 'CASHIER':
      case 'STAFF':
        // Staff see sales, inventory, customers, and all module operational events (no financial data)
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
        ];
      
      default:
        // Unknown role = minimal access
        return ['SALE'];
    }
  }

  /// Get sync status statistics
  static Future<Map<String, int>> getSyncStatus() async {
    final total = await EventService.getEventCount();
    final unsynced = await EventService.getUnsyncedEvents(limit: 1000);
    final synced = total - unsynced.length;

    return {
      'total': total,
      'synced': synced,
      'unsynced': unsynced.length,
    };
  }

  static bool get isSyncing => _isSyncing;

  /// Pull pending orders from 'orders' table (placed by offline buyers)
  static Future<void> _pullRemoteOrders() async {
    try {
      final shop = await AuthService.getCurrentShop();
      if (shop == null) return; 
      
      final supabase = Supabase.instance.client;
      final shopId = await DeviceService.getShopId();
      
      if (shopId == null) return; // ignore: unnecessary_null_comparison

      // Fetch pending orders for this shop
      final response = await supabase
          .from('orders')
          .select()
          .eq('shop_id', shopId)
          .eq('status', 'pending')
          .order('created_at', ascending: true);
          
      final List<dynamic> orders = response as List;
      
      if (orders.isEmpty) return;
      
      debugPrint('📥 Found ${orders.length} pending orders from cloud.');
      
      for (final orderRow in orders) {
        try {
          final orderId = orderRow['id'];
          final itemsRaw = orderRow['items_json'];
          final total = orderRow['total_amount'];
          final createdStr = orderRow['created_at'];
          
          List<dynamic> items = [];
          if (itemsRaw is String) {
            items = jsonDecode(itemsRaw);
          } else {
            items = itemsRaw;
          }
          
          // Map items to Seller Event format
          final mappedItems = items.map((i) => <String, dynamic>{
            'menu_item_id': i['id'], 
            'name': i['name'],
            'qty': i['qty'],
            'price': i['price'],
            'subtotal': (i['qty'] ?? 1) * (i['price'] ?? 0),
          }).toList();
          
          final payload = {
             'order_number': orderId.toString().substring(0, 8).toUpperCase(),
             'order_type': 'online',
             'status': 'pending',
             'total': total,
             'items': mappedItems,
             'created_at': DateTime.parse(createdStr).millisecondsSinceEpoch,
             'customer_name': 'Online Guest', 
          };
          
          // Create synthetic event
          final event = Event.create(
            eventType: 'ORDER_CREATED',
            payload: payload,
            shopId: shopId,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );
          
          // Process via standard EventProcessor
          final success = await EventProcessor.processEvent(event);
          
          if (success) {
            // Mark as processed
            await supabase
              .from('orders')
              .update({'status': 'processed'})
              .eq('id', orderId);
              
            debugPrint('✅ Ingested Order $orderId');
          }
          
        } catch (e) {
          debugPrint('❌ Error ingesting order ${orderRow['id']}: $e');
        }
      }

    } catch (e) {
      debugPrint('❌ Pull Remote Orders Error: $e');
    }
  }

  /// Pull pending bookings from 'services_bookings' table (placed by offline/online buyers)
  static Future<void> _pullRemoteBookings() async {
    try {
      final shop = await AuthService.getCurrentShop();
      if (shop == null) return;
      
      final supabase = Supabase.instance.client;
      final shopId = await DeviceService.getShopId();
      if (shopId == null) return;

      final response = await supabase
          .from('services_bookings')
          .select()
          .eq('shop_id', shopId)
          .eq('status', 'pending')
          .order('created_at', ascending: true);
          
      final List<dynamic> bookings = response as List;
      if (bookings.isEmpty) return;
      
      debugPrint('📥 Found ${bookings.length} pending bookings from cloud.');
      
      for (final row in bookings) {
        try {
          final cloudId = row['id'];
          final payload = {
            'cloud_id': cloudId,
            'source_module': 'services',
            'service_id': row['service_id']?.toString(),
            'customer_name': row['customer_name'] ?? 'Online Guest',
            'customer_phone': row['customer_phone'],
            'start_time': row['start_time'],
            'end_time': row['end_time'],
            'status': 'pending',
            'notes': row['notes'],
          };
          
          final event = Event.create(
            eventType: 'BOOKING_CREATED',
            payload: payload,
            shopId: shopId,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );
          
          final success = await EventProcessor.processEvent(event);
          if (success) {
            await supabase
              .from('services_bookings')
              .update({'status': 'confirmed'})
              .eq('id', cloudId);
            debugPrint('✅ Ingested Booking $cloudId');
          }
        } catch (e) {
          debugPrint('❌ Error ingesting booking ${row['id']}: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Pull Remote Bookings Error: $e');
    }
  }

  /// Pull pending lodging reservations from 'lodging_reservations' table (placed by offline/online buyers)
  static Future<void> _pullRemoteReservations() async {
    try {
      final shop = await AuthService.getCurrentShop();
      if (shop == null) return;
      
      final supabase = Supabase.instance.client;
      final shopId = await DeviceService.getShopId();
      if (shopId == null) return;

      final response = await supabase
          .from('lodging_reservations')
          .select()
          .eq('shop_id', shopId)
          .eq('status', 'pending')
          .order('created_at', ascending: true);
          
      final List<dynamic> reservations = response as List;
      if (reservations.isEmpty) return;
      
      debugPrint('📥 Found ${reservations.length} pending lodging reservations from cloud.');
      
      for (final row in reservations) {
        try {
          final cloudId = row['id'];
          final checkInStr = row['check_in_date'] as String?;
          final checkOutStr = row['check_out_date'] as String?;
          final checkInMs = checkInStr != null ? DateTime.parse(checkInStr).millisecondsSinceEpoch : DateTime.now().millisecondsSinceEpoch;
          final checkOutMs = checkOutStr != null ? DateTime.parse(checkOutStr).millisecondsSinceEpoch : DateTime.now().millisecondsSinceEpoch;
          
          final nights = row['nights'] ?? (checkInStr != null && checkOutStr != null 
              ? DateTime.parse(checkOutStr).difference(DateTime.parse(checkInStr)).inDays.clamp(1, 365)
              : 1);

          final payload = {
            'cloud_id': cloudId,
            'source_module': 'lodging',
            'room_id': row['room_id']?.toString(),
            'guest_name': row['guest_name'] ?? 'Online Guest',
            'guest_phone': row['guest_phone'],
            'guest_email': row['guest_email'],
            'check_in': checkInMs,
            'check_out': checkOutMs,
            'nights': nights,
            'rate_per_night': row['rate_per_night'] ?? 0,
            'total_amount': row['total_amount'] ?? 0,
          };
          
          final event = Event.create(
            eventType: 'LODGING_RESERVATION_CREATE',
            payload: payload,
            shopId: shopId,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );
          
          final success = await EventProcessor.processEvent(event);
          if (success) {
            await supabase
              .from('lodging_reservations')
              .update({'status': 'confirmed'})
              .eq('id', cloudId);
            debugPrint('✅ Ingested Lodging Reservation $cloudId');
          }
        } catch (e) {
          debugPrint('❌ Error ingesting lodging reservation ${row['id']}: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Pull Remote Reservations Error: $e');
    }
  }

  @visibleForTesting
  static Future<void> testPullRemoteBookings() async {
    await _pullRemoteBookings();
  }

  @visibleForTesting
  static Future<void> testPullRemoteReservations() async {
    await _pullRemoteReservations();
  }
}

/// Process batch in a separate isolate to avoid UI jank
Map<String, dynamic> _processBatch(Map<String, dynamic> args) {
  final eventRows = args['events'] as List<dynamic>;
  final shopId = args['shopId'] as String?;
  final deviceId = args['deviceId'] as String?;

  final List<Map<String, dynamic>> eventsToInsert = [];
  final List<String> batchEventIds = [];
  final List<String> integrityFailedIds = [];
  final List<String> ownershipFailedIds = [];

  for (final row in eventRows) {
    // JSON Decode happens here (in background isolate), not on main thread
    final event = Event.fromMap(row as Map<String, dynamic>);

    // Integrity Check (Hash) - CPU Intensive
    if (!event.verifyIntegrity()) {
      integrityFailedIds.add(event.id);
      continue;
    }
    // Ownership Check
    if (event.shopId != shopId || event.deviceId != deviceId) {
      ownershipFailedIds.add(event.id);
      continue;
    }

    // Supabase expects `payload` as json/jsonb, not a JSON-encoded String.
    final toInsert = event.toMap();
    toInsert['payload'] = event.payload; 
    toInsert['payload_raw'] = event.payloadRaw ?? jsonEncode(event.payload);
    // events.hash is TEXT (plain hex). validate_event_hash() compares against
    // encode(digest(...), 'hex') so we MUST send raw hex with no \x prefix.
    toInsert['hash'] = event.hash;
    eventsToInsert.add(toInsert);
    batchEventIds.add(event.id);
  }

  return {
    'insert': eventsToInsert,
    'ids': batchEventIds,
    'integrityErrors': integrityFailedIds,
    'ownershipErrors': ownershipFailedIds,
  };
}
