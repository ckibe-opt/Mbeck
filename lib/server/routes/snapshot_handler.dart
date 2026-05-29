import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:flutter/foundation.dart';
import '../../db/db_provider.dart';
import '../../services/device_service.dart';
import '../../services/onboarding_service.dart';

/// Snapshot Handler for LAN Data Replication
///
/// Serves a full JSON snapshot of all shop data to employee devices joining
/// the local network. This enables offline-first data cloning without internet.
///
/// GET /api/v1/snapshot
///
/// Security: Only serves data for the current shop_id. The caller must be on
/// the same LAN and know the shop_id (obtained via mDNS discovery).
class SnapshotHandler {
  /// Handle GET /api/v1/snapshot
  ///
  /// Returns a JSON object with all shop data organized by table/module.
  /// Employee devices call this once on first join to replicate the owner's data.
  static Future<Response> handleSnapshot(Request request) async {
    final stopwatch = Stopwatch()..start();

    try {
      final db = await DbProvider.db;
      final shopId = await DeviceService.getShopId();
      final modules = await OnboardingService.getSelectedModules();

      debugPrint('📸 Snapshot requested — building full shop data export...');

      // --- Core Tables (always included) ---
      final shopSettings = await _safeQuery(db, 'SELECT * FROM shop_settings LIMIT 1');
      final shops = await _safeQuery(db, 'SELECT * FROM shops LIMIT 1');
      final inventory = await _safeQuery(db,
          'SELECT id, cloud_id, name, category, sellingPrice, originalPrice, stock, imagePath, specification, barcode, variationsJson FROM inventory');
      final transactions = await _safeQuery(db,
          'SELECT id, cloud_id, customerId, itemId, type, totalAmount, details, timestamp, receiptSignature FROM txn ORDER BY timestamp DESC LIMIT 500');
      final transactionItems = await _safeQuery(db,
          'SELECT * FROM transaction_items');
      final customers = await _safeQuery(db,
          'SELECT * FROM customer');
      final shopModules = await _safeQuery(db,
          'SELECT * FROM shop_modules');
      final moduleFeatures = await _safeQuery(db,
          'SELECT * FROM module_features');
      final inventoryVectors = await _safeQuery(db,
          'SELECT * FROM inventory_vectors');
      final visualCollisions = await _safeQuery(db,
          'SELECT * FROM visual_collisions');

      // --- Module-specific tables ---
      
      // Retail
      List<Map<String, dynamic>> retailReturns = [];
      List<Map<String, dynamic>> retailSuppliers = [];
      List<Map<String, dynamic>> retailPurchaseOrders = [];
      List<Map<String, dynamic>> retailPoItems = [];
      List<Map<String, dynamic>> retailPromotions = [];
      List<Map<String, dynamic>> retailStockAudits = [];
      if (modules.contains('retail')) {
        retailReturns = await _safeQuery(db, 'SELECT * FROM retail_returns');
        retailSuppliers = await _safeQuery(db, 'SELECT * FROM retail_suppliers');
        retailPurchaseOrders = await _safeQuery(db, 'SELECT * FROM retail_purchase_orders');
        retailPoItems = await _safeQuery(db, 'SELECT * FROM retail_po_items');
        retailPromotions = await _safeQuery(db, 'SELECT * FROM retail_promotions');
        retailStockAudits = await _safeQuery(db, 'SELECT * FROM retail_stock_audits');
      }

      // Restaurant
      List<Map<String, dynamic>> restaurantFloorPlan = [];
      List<Map<String, dynamic>> restaurantInventory = [];
      List<Map<String, dynamic>> restaurantMenu = [];
      List<Map<String, dynamic>> restaurantOrders = [];
      List<Map<String, dynamic>> restaurantOrderItems = [];
      List<Map<String, dynamic>> restaurantRecipes = [];
      if (modules.contains('restaurant')) {
        restaurantFloorPlan = await _safeQuery(db, 'SELECT * FROM restaurant_floor_plan');
        restaurantInventory = await _safeQuery(db, 'SELECT * FROM restaurant_inventory');
        restaurantMenu = await _safeQuery(db, 'SELECT * FROM restaurant_menu');
        restaurantOrders = await _safeQuery(db, 'SELECT * FROM restaurant_orders');
        restaurantRecipes = await _safeQuery(db, 'SELECT * FROM restaurant_recipes');
        restaurantOrderItems = await _safeQuery(db,
            'SELECT * FROM restaurant_order_items');
      }

      // Services
      List<Map<String, dynamic>> servicesCatalog = [];
      List<Map<String, dynamic>> servicesStaff = [];
      List<Map<String, dynamic>> servicesBookings = [];
      List<Map<String, dynamic>> serviceCategories = [];
      List<Map<String, dynamic>> servicesStaffShifts = [];
      List<Map<String, dynamic>> servicesAddons = [];
      List<Map<String, dynamic>> servicesRooms = [];
      if (modules.contains('services')) {
        servicesCatalog = await _safeQuery(db, 'SELECT * FROM services_catalog');
        servicesStaff = await _safeQuery(db, 'SELECT * FROM services_staff');
        servicesBookings = await _safeQuery(db,
            'SELECT * FROM services_bookings ORDER BY start_time DESC LIMIT 200');
        serviceCategories = await _safeQuery(db, 'SELECT * FROM service_categories');
        servicesStaffShifts = await _safeQuery(db, 'SELECT * FROM services_staff_shifts');
        servicesAddons = await _safeQuery(db, 'SELECT * FROM services_addons');
        servicesRooms = await _safeQuery(db, 'SELECT * FROM services_rooms');
      }

      // Entertainment
      List<Map<String, dynamic>> entertainmentAssets = [];
      List<Map<String, dynamic>> entertainmentSessions = [];
      List<Map<String, dynamic>> entertainmentAssetTypes = [];
      List<Map<String, dynamic>> entertainmentAssetTypeImages = [];
      if (modules.contains('entertainment')) {
        entertainmentAssets = await _safeQuery(db, 'SELECT * FROM entertainment_assets');
        entertainmentSessions = await _safeQuery(db,
            'SELECT * FROM entertainment_sessions ORDER BY created_at DESC LIMIT 200');
        entertainmentAssetTypes = await _safeQuery(db, 'SELECT * FROM entertainment_asset_types');
        entertainmentAssetTypeImages = await _safeQuery(db, 'SELECT * FROM entertainment_asset_type_images');
      }

      // Lodging
      List<Map<String, dynamic>> lodgingRooms = [];
      List<Map<String, dynamic>> lodgingReservations = [];
      List<Map<String, dynamic>> lodgingRoomTypes = [];
      List<Map<String, dynamic>> lodgingRoomTypeImages = [];
      if (modules.contains('lodging')) {
        lodgingRooms = await _safeQuery(db, 'SELECT * FROM lodging_rooms');
        lodgingReservations = await _safeQuery(db,
            'SELECT * FROM lodging_reservations ORDER BY created_at DESC LIMIT 200');
        lodgingRoomTypes = await _safeQuery(db, 'SELECT * FROM lodging_room_types');
        lodgingRoomTypeImages = await _safeQuery(db, 'SELECT * FROM lodging_room_type_images');
      }

      // Supplies (shared across modules)
      final supplies = await _safeQuery(db, 'SELECT * FROM supplies');
      final supplyLinks = await _safeQuery(db, 'SELECT * FROM supply_links');

      // --- Events (last 1000 for replay) ---
      final events = await _safeQuery(db,
          'SELECT * FROM events ORDER BY timestamp DESC LIMIT 1000');

      // --- Build snapshot ---
      final snapshot = {
        'version': 1,
        'shop_id': shopId,
        'modules': modules,
        'generated_at': DateTime.now().millisecondsSinceEpoch,

        // Core
        'shop_settings': shopSettings,
        'shops': shops,
        'shop_modules': shopModules,
        'inventory': inventory,
        'transactions': transactions,
        'transaction_items': transactionItems,
        'customers': customers,
        'module_features': moduleFeatures,
        'inventory_vectors': inventoryVectors,
        'visual_collisions': visualCollisions,
        
        // Retail
        'retail_returns': retailReturns,
        'retail_suppliers': retailSuppliers,
        'retail_purchase_orders': retailPurchaseOrders,
        'retail_po_items': retailPoItems,
        'retail_promotions': retailPromotions,
        'retail_stock_audits': retailStockAudits,

        // Restaurant
        'restaurant_floor_plan': restaurantFloorPlan,
        'restaurant_inventory': restaurantInventory,
        'restaurant_menu': restaurantMenu,
        'restaurant_orders': restaurantOrders,
        'restaurant_order_items': restaurantOrderItems,
        'restaurant_recipes': restaurantRecipes,

        // Services
        'services_catalog': servicesCatalog,
        'services_staff': servicesStaff,
        'services_bookings': servicesBookings,
        'service_categories': serviceCategories,
        'services_staff_shifts': servicesStaffShifts,
        'services_addons': servicesAddons,
        'services_rooms': servicesRooms,

        // Entertainment
        'entertainment_assets': entertainmentAssets,
        'entertainment_sessions': entertainmentSessions,
        'entertainment_asset_types': entertainmentAssetTypes,
        'entertainment_asset_type_images': entertainmentAssetTypeImages,

        // Lodging
        'lodging_rooms': lodgingRooms,
        'lodging_reservations': lodgingReservations,
        'lodging_room_types': lodgingRoomTypes,
        'lodging_room_type_images': lodgingRoomTypeImages,

        // Supplies (shared across modules)
        'supplies': supplies,
        'supply_links': supplyLinks,

        // Events for replay
        'events': events,
      };

      stopwatch.stop();
      final totalRows = inventory.length + transactions.length +
          retailReturns.length + retailSuppliers.length + retailPurchaseOrders.length +
          retailPoItems.length + retailPromotions.length + retailStockAudits.length +
          restaurantInventory.length + restaurantMenu.length + restaurantOrders.length + restaurantRecipes.length +
          servicesCatalog.length + servicesStaff.length +
          servicesBookings.length + entertainmentAssets.length +
          lodgingRooms.length + supplies.length + events.length +
          moduleFeatures.length + inventoryVectors.length + visualCollisions.length +
          serviceCategories.length + servicesStaffShifts.length + servicesAddons.length + servicesRooms.length +
          entertainmentAssetTypes.length + entertainmentAssetTypeImages.length +
          lodgingRoomTypes.length + lodgingRoomTypeImages.length;

      debugPrint('📸 Snapshot built: $totalRows rows across ${modules.length} modules '
          'in ${stopwatch.elapsedMilliseconds}ms');

      return Response.ok(
        jsonEncode(snapshot),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'X-Snapshot-Rows': '$totalRows',
          'X-Snapshot-Time-Ms': '${stopwatch.elapsedMilliseconds}',
        },
      );
    } catch (e, stack) {
      debugPrint('❌ Snapshot generation failed: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({
          'error': 'Snapshot generation failed',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Safely query a table — returns empty list if table doesn't exist
  static Future<List<Map<String, dynamic>>> _safeQuery(
      dynamic db, String sql) async {
    try {
      final results = await db.rawQuery(sql);
      // Convert to regular maps (sqflite returns unmodifiable maps)
      return results
          .map<Map<String, dynamic>>(
              (row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Snapshot query skipped (table may not exist): $e');
      return [];
    }
  }
}
