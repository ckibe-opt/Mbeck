import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sync_service.dart';
import 'device_service.dart';
import 'event_processor.dart';

/// Real-time sync service for instant updates across devices
/// Listens to Supabase real-time subscriptions and triggers local sync
class RealtimeService {
  static bool _isInitialized = false;
  static RealtimeChannel? _eventsChannel;
  static RealtimeChannel? _ordersChannel;

  /// Initialize real-time subscriptions
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      final supabase = Supabase.instance.client;
      final shopId = await DeviceService.getShopId();
      
      if (shopId == null) {
        debugPrint('⚠️ Realtime: No shop ID found, skipping initialization');
        return;
      }

      debugPrint('🔔 Initializing real-time subscriptions for shop: $shopId');

      // Subscribe to events table changes
      _eventsChannel = supabase.channel('events_changes_$shopId');
      
      _eventsChannel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'events',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'shop_id',
          value: shopId,
        ),
        callback: (payload) {
          debugPrint('🔔 Real-time: New event detected');
          _handleRealtimeEvent(payload);
        },
      ).subscribe();

      // Subscribe to orders table changes (for restaurant module)
      _ordersChannel = supabase.channel('orders_changes_$shopId');
      
      _ordersChannel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'shop_id',
          value: shopId,
        ),
        callback: (payload) {
          debugPrint('🔔 Real-time: New order detected');
          _handleRealtimeOrder(payload);
        },
      ).subscribe();

      _isInitialized = true;
      debugPrint('✅ Real-time subscriptions initialized');
      
    } catch (e) {
      debugPrint('❌ Failed to initialize real-time service: $e');
    }
  }

  /// Handle real-time event changes
  static Future<void> _handleRealtimeEvent(PostgresChangePayload payload) async {
    try {
      final newRecord = payload.newRecord;
      if (newRecord == null) return;

      final deviceId = newRecord['device_id'] as String?;
      final currentDeviceId = await DeviceService.getDeviceId();
      
      // Ignore our own events to prevent infinite loops
      if (deviceId == currentDeviceId) {
        debugPrint('🔔 Real-time: Ignoring own event');
        return;
      }

      debugPrint('🔔 Real-time: Processing remote event ${newRecord['id']}');
      
      // Trigger a pull sync to get the latest events
      _triggerPullSync();
      
    } catch (e) {
      debugPrint('❌ Error handling real-time event: $e');
    }
  }

  /// Handle real-time order changes
  static void _handleRealtimeOrder(PostgresChangePayload payload) {
    try {
      final newRecord = payload.newRecord;
      if (newRecord == null) return;

      debugPrint('🔔 Real-time: Processing remote order ${newRecord['id']}');
      
      // Emit locally to pre-alert KDS before pull sync completes
      EventProcessor.notify('ORDER_CREATED');
      
      // Trigger a pull sync to get the latest orders
      _triggerPullSync();
      
    } catch (e) {
      debugPrint('❌ Error handling real-time order: $e');
    }
  }

  static Timer? _debounceTimer;

  /// Trigger a pull sync with debounce to avoid excessive calls
  static void _triggerPullSync() {
    // Cancel previous timer if active
    _debounceTimer?.cancel();
    
    // Start new timer
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        debugPrint('🔄 Real-time: Triggering pull sync');
        await SyncService.syncEvents(force: true);
      } catch (e) {
        debugPrint('❌ Real-time pull sync failed: $e');
      }
    });
  }

  /// Cleanup subscriptions
  static Future<void> dispose() async {
    try {
      _debounceTimer?.cancel();
      await _eventsChannel?.unsubscribe();
      await _ordersChannel?.unsubscribe();
      _eventsChannel = null;
      _ordersChannel = null;
      _isInitialized = false;
      debugPrint('✅ Real-time subscriptions disposed');
    } catch (e) {
      debugPrint('❌ Error disposing real-time service: $e');
    }
  }

  /// Get real-time connection status
  static bool get isConnected => _isInitialized;
}
