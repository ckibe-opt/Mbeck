import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../db/db_provider.dart';
import 'event_processor.dart';
import 'device_service.dart';
import '../models/event.dart';

/// LAN Snapshot Client — pulls a full data snapshot from the leader device
///
/// This service is used when an employee device joins a shop on the same WiFi.
/// It connects to the leader's `/api/v1/snapshot` endpoint over HTTP, downloads
/// the full dataset, and applies it to the local database using upserts.
///
/// Flow:
/// 1. Discover leader IP + port via mDNS (already available from LocalClusterService)
/// 2. GET http://<leader_ip>:<port>/api/v1/snapshot
/// 3. Upsert all received rows into local tables
/// 4. Replay received events through EventProcessor
class LanSnapshotClient {
  /// Pull a full snapshot from the leader device and apply to local DB
  ///
  /// [leaderHost] — IP:port of the leader (e.g. "192.168.1.5:8080")
  /// Returns true if snapshot was successfully applied
  static Future<bool> pullFromLeader(String leaderHost) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('📸 Pulling snapshot from leader at $leaderHost...');

      // 1. Download snapshot via HTTP
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(
          Uri.parse('http://$leaderHost/api/v1/snapshot'));
      final response = await request.close();

      if (response.statusCode != 200) {
        debugPrint('❌ Snapshot request failed: HTTP ${response.statusCode}');
        client.close();
        return false;
      }

      final body = await response.transform(utf8.decoder).join();
      client.close();

      final snapshot = jsonDecode(body) as Map<String, dynamic>;
      final snapshotShopId = snapshot['shop_id'] as String?;
      final localShopId = await DeviceService.getShopId();

      // 2. Security check — only apply data from the same shop
      if (snapshotShopId != null && snapshotShopId != localShopId) {
        debugPrint('❌ CRITICAL: Snapshot shop_id mismatch! localShopId=$localShopId, snapshotShopId=$snapshotShopId. Aborting snapshot pull.');
        return false;
      }

      debugPrint('📸 Snapshot downloaded (${body.length} bytes). Applying...');

      // 3. Apply data to local database
      final db = await DbProvider.db;

      await db.transaction((txn) async {
        // Core tables
        await _upsertRows(txn, 'shop_settings', snapshot['shop_settings'] ?? []);
        await _upsertRows(txn, 'shops', snapshot['shops'] ?? []);
        await _upsertRows(txn, 'shop_modules', snapshot['shop_modules'] ?? []);
        await _upsertRows(txn, 'module_features', snapshot['module_features'] ?? []);
        await _upsertRows(txn, 'inventory', snapshot['inventory'] ?? []);
        await _upsertRows(txn, 'inventory_vectors', snapshot['inventory_vectors'] ?? []);
        await _upsertRows(txn, 'visual_collisions', snapshot['visual_collisions'] ?? []);
        await _upsertRows(txn, 'customer', snapshot['customers'] ?? []);
        await _upsertRows(txn, 'txn', snapshot['transactions'] ?? []);
        await _upsertRows(txn, 'transaction_items', snapshot['transaction_items'] ?? []);

        // Retail Modules
        await _upsertRows(txn, 'retail_returns', snapshot['retail_returns'] ?? []);
        await _upsertRows(txn, 'retail_suppliers', snapshot['retail_suppliers'] ?? []);
        await _upsertRows(txn, 'retail_purchase_orders', snapshot['retail_purchase_orders'] ?? []);
        await _upsertRows(txn, 'retail_po_items', snapshot['retail_po_items'] ?? []);
        await _upsertRows(txn, 'retail_promotions', snapshot['retail_promotions'] ?? []);
        await _upsertRows(txn, 'retail_stock_audits', snapshot['retail_stock_audits'] ?? []);

        // Restaurant
        await _upsertRows(txn, 'restaurant_floor_plan', snapshot['restaurant_floor_plan'] ?? []);
        await _upsertRows(txn, 'restaurant_inventory', snapshot['restaurant_inventory'] ?? []);
        await _upsertRows(txn, 'restaurant_menu', snapshot['restaurant_menu'] ?? []);
        await _upsertRows(txn, 'restaurant_orders', snapshot['restaurant_orders'] ?? []);
        await _upsertRows(txn, 'restaurant_order_items', snapshot['restaurant_order_items'] ?? []);
        await _upsertRows(txn, 'restaurant_recipes', snapshot['restaurant_recipes'] ?? []);

        // Services
        await _upsertRows(txn, 'services_catalog', snapshot['services_catalog'] ?? []);
        await _upsertRows(txn, 'services_staff', snapshot['services_staff'] ?? []);
        await _upsertRows(txn, 'services_bookings', snapshot['services_bookings'] ?? []);
        await _upsertRows(txn, 'service_categories', snapshot['service_categories'] ?? []);
        await _upsertRows(txn, 'services_staff_shifts', snapshot['services_staff_shifts'] ?? []);
        await _upsertRows(txn, 'services_addons', snapshot['services_addons'] ?? []);
        await _upsertRows(txn, 'services_rooms', snapshot['services_rooms'] ?? []);

        // Entertainment
        await _upsertRows(txn, 'entertainment_assets', snapshot['entertainment_assets'] ?? []);
        await _upsertRows(txn, 'entertainment_sessions', snapshot['entertainment_sessions'] ?? []);
        await _upsertRows(txn, 'entertainment_asset_types', snapshot['entertainment_asset_types'] ?? []);
        await _upsertRows(txn, 'entertainment_asset_type_images', snapshot['entertainment_asset_type_images'] ?? []);

        // Lodging
        await _upsertRows(txn, 'lodging_rooms', snapshot['lodging_rooms'] ?? []);
        await _upsertRows(txn, 'lodging_reservations', snapshot['lodging_reservations'] ?? []);
        await _upsertRows(txn, 'lodging_room_types', snapshot['lodging_room_types'] ?? []);
        await _upsertRows(txn, 'lodging_room_type_images', snapshot['lodging_room_type_images'] ?? []);

        // Supplies
        await _upsertRows(txn, 'supplies', snapshot['supplies'] ?? []);
        await _upsertRows(txn, 'supply_links', snapshot['supply_links'] ?? []);
      });

      // 4. Replay events through EventProcessor (outside transaction for safety)
      final eventsList = snapshot['events'] as List<dynamic>? ?? [];
      int eventsApplied = 0;

      for (final eventJson in eventsList) {
        try {
          final eventMap = Map<String, dynamic>.from(eventJson as Map);

          // Check if we already have this event
          final existing = await db.rawQuery(
              'SELECT id FROM events WHERE id = ?', [eventMap['id']]);
          if (existing.isNotEmpty) continue; // Already have it, skip

          // Insert the event record
          await db.insert('events', eventMap);

          // Apply the event's effect to local state
          final event = Event.fromMap(eventMap);
          await EventProcessor.applyEffect(event);
          eventsApplied++;
        } catch (e) {
          debugPrint('⚠️ Failed to apply event: $e');
          // Continue with other events — don't fail the whole snapshot
        }
      }

      stopwatch.stop();
      debugPrint('📸 Snapshot applied successfully in ${stopwatch.elapsedMilliseconds}ms. '
          'Events replayed: $eventsApplied/${eventsList.length}');

      // 5. Sync Images
      await _syncImagesFromLeader(leaderHost, snapshot);

      return true;
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint('❌ Snapshot pull failed: $e\n$stack');
      return false;
    }
  }

  /// Iterates through all synchronized inventory models and issues HTTP downloads 
  /// for missing native image files from the leader.
  static Future<void> _syncImagesFromLeader(String leaderHost, Map<String, dynamic> snapshot) async {
    try {
      final Set<String> imagesToFetch = {};
      
      void extractImages(List<dynamic>? rows, String imageField) {
        if (rows == null) return;
        for (final row in rows) {
          final val = row[imageField];
          if (val != null && val is String && val.isNotEmpty && !val.startsWith('http')) {
            imagesToFetch.add(val);
          }
        }
      }

      extractImages(snapshot['inventory'], 'imagePath');
      extractImages(snapshot['restaurant_menu'], 'image_path');
      extractImages(snapshot['services_catalog'], 'image_path');
      extractImages(snapshot['entertainment_assets'], 'image_path');
      extractImages(snapshot['lodging_room_types'], 'image_path');
      
      extractImages(snapshot['service_categories'], 'image_path');
      extractImages(snapshot['entertainment_asset_type_images'], 'image_path');
      extractImages(snapshot['lodging_room_type_images'], 'image_path');
      
      // Also theme_config 
      final shops = snapshot['shops'] as List<dynamic>?;
      if (shops != null) {
        for (final s in shops) {
          final config = s['theme_config'];
          if (config != null && config is String) {
            try {
              final json = jsonDecode(config);
              final cover = json['cover_image_url'];
              if (cover != null && cover is String && cover.isNotEmpty && !cover.startsWith('http')) {
                imagesToFetch.add(cover);
              }
            } catch (_) {}
          }
        }
      }

      if (imagesToFetch.isEmpty) return;
      
      debugPrint('📸 Found ${imagesToFetch.length} images to sync from leader. Downloading...');
      
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final directory = await getApplicationDocumentsDirectory(); 
      
      int successCount = 0;
      for (final img in imagesToFetch) {
        try {
          final sanitized = path.basename(img);
          final request = await client.getUrl(Uri.parse('http://$leaderHost/api/v1/images/$sanitized'));
          final response = await request.close();
          if (response.statusCode == 200) {
             final bytes = await consolidateHttpClientResponseBytes(response);
             final file = File(path.join(directory.path, sanitized));
             await file.writeAsBytes(bytes);
             successCount++;
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching image $img: $e');
        }
      }
      client.close();
      debugPrint('📸 Synced $successCount/${imagesToFetch.length} images successfully.');
    } catch (e) {
      debugPrint('⚠️ Error during image sync: $e');
    }
  }

  /// Check if local database is essentially empty (needs snapshot)
  static Future<bool> needsSnapshot() async {
    try {
      final db = await DbProvider.db;
      final inventoryCount = await db.rawQuery('SELECT COUNT(*) as cnt FROM inventory');
      final eventCount = await db.rawQuery('SELECT COUNT(*) as cnt FROM events');

      final items = (inventoryCount.first['cnt'] as int?) ?? 0;
      final events = (eventCount.first['cnt'] as int?) ?? 0;

      // If we have very few items AND very few events, we probably need a snapshot
      return items < 2 && events < 5;
    } catch (e) {
      debugPrint('⚠️ Error checking snapshot need: $e');
      return true; // If we can't check, assume we need one
    }
  }

  /// Upsert a list of row maps into a table using INSERT OR REPLACE
  static Future<void> _upsertRows(
      dynamic txn, String table, List<dynamic> rows) async {
    if (rows.isEmpty) return;

    final batch = txn.batch();
    int count = 0;
    for (final row in rows) {
      try {
        final map = Map<String, dynamic>.from(row as Map);
        // Use raw SQL for INSERT OR REPLACE to handle both inserts and updates
        final columns = map.keys.toList();
        final placeholders = columns.map((_) => '?').join(', ');
        final columnList = columns.join(', ');
        final values = columns.map((c) => map[c]).toList();

        batch.rawInsert(
          'INSERT OR REPLACE INTO $table ($columnList) VALUES ($placeholders)',
          values,
        );
        count++;
      } catch (e) {
        // Individual row failure shouldn't stop the whole import
        if (count == 0) {
          debugPrint('⚠️ Batch prep failed for $table: $e');
        }
      }
    }

    if (count > 0) {
      await batch.commit(noResult: true);
      debugPrint('  📦 $table: $count rows applied via Batch');
    }
  }
}
