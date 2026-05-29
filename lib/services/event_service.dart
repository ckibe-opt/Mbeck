import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../db/db_provider.dart';
import 'device_service.dart';
import 'lan_sync_service.dart';
import 'event_processor.dart';

/// Event Service for managing the append-only event ledger
/// 
/// This service is responsible for:
/// - Emitting events (append-only, never modify)
/// - Ensuring event integrity (hashing)
/// - Managing event lifecycle (sync status)
/// 
/// CRITICAL: Events are immutable once created. Only sync metadata can be updated.
class EventService {
  /// Emit a new event to the ledger
  /// 
  /// This is the primary method for recording facts in the system.
  /// If event creation fails, the operation should fail.
  /// 
  /// Returns the created event, or throws if creation fails.
  static Future<Event> emitEvent({
    required String eventType,
    required Map<String, dynamic> payload,
    int? timestamp,
  }) async {
    try {
      // Get shop_id and device_id
      final shopId = await DeviceService.getShopId();
      final deviceId = await DeviceService.getDeviceId();
      
      // Create event with automatic UUID and hash
      final event = Event.create(
        eventType: eventType,
        payload: payload,
        shopId: shopId,
        deviceId: deviceId,
        timestamp: timestamp,
      );
      
      // Verify integrity before storing
      if (!event.verifyIntegrity()) {
        throw Exception('Event integrity check failed before storage');
      }
      
      // Insert into events table (append-only)
      final db = await DbProvider.db;
      await db.insert('events', event.toMap());
      
      debugPrint('📝 Event emitted: $eventType (${event.id.substring(0, 8)}...)');

      // Notify local listeners
      EventProcessor.notify(eventType);
      
      // ========== LAN SYNC ==========
      // Broadcast event to other devices on the local network
      // This is non-blocking - failures are logged but don't fail the operation
      try {
        if (LANSyncService.instance.isListening) {
          LANSyncService.instance.broadcastEvent(event);
        } else {
          debugPrint('⚠️ LAN Sync skipped: Not listening');
        }
      } catch (e) {
        debugPrint('⚠️ LAN broadcast failed (non-fatal): $e');
      }
      // ==============================
      
      return event;
    } catch (e) {
      debugPrint('❌ Failed to emit event $eventType: $e');
      rethrow;
    }
  }

  /// Get all unsynced events (for Phase 2 - sync)
  static Future<List<Event>> getUnsyncedEvents({int limit = 50}) async {
    final db = await DbProvider.db;
    final rows = await db.query(
      'events',
      where: 'synced = ? AND failed = ?',
      whereArgs: [0, 0],
      orderBy: 'timestamp ASC', // Oldest first
      limit: limit,
    );
    
    return rows.map((row) => Event.fromMap(row)).toList();
  }

  /// Get raw unsynced event rows (for background processing)
  /// Returns List<Map> to avoid JSON decoding on the main thread.
  static Future<List<Map<String, dynamic>>> getUnsyncedEventsRaw({int limit = 50}) async {
    final db = await DbProvider.db;
    return await db.query(
      'events',
      where: 'synced = ? AND failed = ?',
      whereArgs: [0, 0],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
  }


  /// Get raw unsynced event rows created by THIS device (for background processing)
  /// Prevents "Ownership Mismatch" regarding events synced via LAN.
  static Future<List<Map<String, dynamic>>> getUnsyncedOwnEventsRaw(String deviceId, {int limit = 50}) async {
    final db = await DbProvider.db;
    return await db.query(
      'events',
      where: 'synced = ? AND failed = ? AND device_id = ?',
      whereArgs: [0, 0, deviceId],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
  }

  /// Mark event as synced (only sync metadata can change)
  static Future<void> markEventSynced(String eventId) async {
    final db = await DbProvider.db;
    await db.update(
      'events',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [eventId],
    );
  }

  /// Batch mark multiple events as synced in a single transaction
  static Future<void> markEventsSyncedBatch(List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    final db = await DbProvider.db;
    await db.transaction((txn) async {
      for (final id in eventIds) {
        await txn.update(
          'events',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  /// Mark event as failed and increment sync attempts
  static Future<void> markEventFailed(String eventId) async {
    final db = await DbProvider.db;
    
    // Get current sync_attempts
    final rows = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    
    if (rows.isNotEmpty) {
      final currentAttempts = (rows.first['sync_attempts'] as int? ?? 0);
      await db.update(
        'events',
        {
          'sync_attempts': currentAttempts + 1,
          'failed': 1,
        },
        where: 'id = ?',
        whereArgs: [eventId],
      );
    }
  }

  /// Get events by type
  static Future<List<Event>> getEventsByType(String eventType, {int? limit}) async {
    final db = await DbProvider.db;
    final rows = await db.query(
      'events',
      where: 'event_type = ?',
      whereArgs: [eventType],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    return rows.map((row) => Event.fromMap(row)).toList();
  }

  /// Get event count (for statistics)
  static Future<int> getEventCount() async {
    final db = await DbProvider.db;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM events');
    return result.first['count'] as int? ?? 0;
  }

  /// Get count of unsynced events (lightweight check for lifecycle listener)
  static Future<int> getUnsyncedCount() async {
    final db = await DbProvider.db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM events WHERE synced = 0 AND failed = 0',
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Verify event integrity in database
  static Future<bool> verifyEventIntegrity(String eventId) async {
    final db = await DbProvider.db;
    final rows = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    
    if (rows.isEmpty) return false;
    
    final event = Event.fromMap(rows.first);
    return event.verifyIntegrity();
  }
}
