import 'package:flutter/foundation.dart';
import '../db/db_provider.dart';
import '../models/shop.dart';
import '../models/permissions.dart';
import 'auth_service.dart';
import 'revenuecat_service.dart';
import 'event_service.dart';
import 'module_scope.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'cloud_storage_service.dart';

/// Service to handle Inventory operations with RBAC enforcement
class InventoryService {
  
  /// Get all inventory items
  /// Requires [Permissions.viewInventory]
  static Future<List<Map<String, dynamic>>> getItems({
    String category = 'All',
    String searchQuery = '',
  }) async {
    // RBAC Check
    final member = await AuthService.getCurrentMember();
    if (member != null && !member.hasPermission(Permissions.viewInventory)) {
      throw Exception('Access Denied: You do not have permission to view inventory.');
    }

    final scope = await ModuleScope.current();

    String sql = 'SELECT * FROM inventory';
    List<dynamic> args = [];
    List<String> whereClauses = [];

    // Module isolation: only show items from active modules
    whereClauses.add(scope.inventoryWhere);
    args.addAll(scope.moduleArgs);

    if (category != 'All') {
      // Hierarchical filtering: Match exact category or any subcategory (Category\...)
      whereClauses.add('(category = ? OR category LIKE ?)');
      args.add(category);
      args.add('$category\\%');
    }

    if (searchQuery.isNotEmpty) {
      whereClauses.add('(name LIKE ? OR category LIKE ?)');
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }

    if (whereClauses.isNotEmpty) {
      sql += ' WHERE ${whereClauses.join(' AND ')}';
    }

    sql += ' ORDER BY name COLLATE NOCASE ASC';

    final result = await DbProvider.queryRaw(sql, args);
    debugPrint('InventoryService: Fetched ${result.length} items (modules: ${scope.activeModules})');
    return result;
  }

  /// Get distinct categories
  /// Requires [Permissions.viewInventory]
  static Future<List<String>> getCategories() async {
     // RBAC Check (Implicitly needed to see categories)
    final member = await AuthService.getCurrentMember();
    if (member != null && !member.hasPermission(Permissions.viewInventory)) {
       return []; // Or throw, but returning empty is safer for UI
    }

    final scope = await ModuleScope.current();
    final data = await DbProvider.queryRaw(
      'SELECT DISTINCT category FROM inventory WHERE ${scope.inventoryWhere} ORDER BY category',
      scope.moduleArgs,
    );
    final Set<String> catsSet = {'All'};
    for (var item in data) {
      if (item['category'] != null && item['category'].toString().isNotEmpty) {
        final String fullCat = item['category'].toString();
        // Add full category
        catsSet.add(fullCat);
        
        // Add parent paths (e.g., A\B\C -> A, A\B)
        final parts = fullCat.split('\\');
        if (parts.length > 1) {
          String currentPath = '';
          for (int i = 0; i < parts.length - 1; i++) {
            if (currentPath.isEmpty) {
              currentPath = parts[i];
            } else {
              currentPath += '\\${parts[i]}';
            }
            if (currentPath.isNotEmpty) catsSet.add(currentPath);
          }
        }
      }
    }
    final List<String> sortedCats = catsSet.toList()..sort();
    return sortedCats;
  }

  /// Add a new inventory item
  /// Requires [Permissions.addInventoryItem]
  static Future<void> addItem({
    required String name,
    required String category,
    required double sellingPrice,
    required double originalPrice,
    required int stock,
    required String imagePath,
    String? visualVector,
    String specification = '',
    String barcode = '',
    String? variationsJson,
    bool isPublished = false,
  }) async {
    // RBAC Check
    final member = await AuthService.getCurrentMember();
    if (member != null && !member.hasPermission(Permissions.addInventoryItem)) {
      throw Exception('Access Denied: You do not have permission to add items.');
    }

    // Check Limits
    final shop = await AuthService.getCurrentShop();
    if (shop != null) {
       final stats = await DbProvider.getDatabaseStats();
       final countVal = stats['total_inventory'];
       final currentCount = (countVal is int) ? countVal : int.tryParse(countVal.toString()) ?? 0;
       
       final isProSub = await RevenueCatService.isProSubscriber();
       if (!isProSub && shop.isInventoryLimitReached(currentCount)) {
          throw Exception('Inventory Limit Reached (Max ${shop.maxInventoryItems} items)');
       }
    }

    final cleanCategory = category.split('\\').map((s) => s.trim()).join('\\');
    
    // Cloud Upload Bypass (If linked to Supabase, this swaps local path for https)
    final cloudUrl = await CloudStorageService.uploadImage(imagePath, folder: 'inventory');
    final filename = (cloudUrl != null && cloudUrl.startsWith('http')) 
        ? cloudUrl 
        : (imagePath.isEmpty ? '' : path.basename(imagePath));
        
    final cloudId = const Uuid().v4();
    final sourceModule = await ModuleScope.tagForWrite();

    // Perform Write
    final newId = await DbProvider.insert('inventory', {
      'name': name,
      'category': cleanCategory,
      'sellingPrice': sellingPrice,
      'originalPrice': originalPrice,
      'stock': stock,
      'imagePath': filename,
      'visual_vector': visualVector,
      'specification': specification,
      'barcode': barcode,
      'variationsJson': variationsJson,
      'cloud_id': cloudId,
      'source_module': sourceModule,
      'is_published': isPublished ? 1 : 0,
    });

    // Emit Event
    try {
      await EventService.emitEvent(
        eventType: 'INVENTORY_CREATE',
        payload: {
          'id': newId,
          'name': name,
          'category': category,
          'sellingPrice': sellingPrice,
          'originalPrice': originalPrice,
          'stock': stock,
          'imagePath': filename,
          'hasVisualVector': visualVector != null && visualVector.isNotEmpty,
          'specification': specification,
          'barcode': barcode,
          'variationsJson': variationsJson,
          'cloud_id': cloudId,
          'source_module': sourceModule,
          'is_published': isPublished ? 1 : 0,
        },
      );
    } catch (e) {
      debugPrint('⚠️ Failed to emit inventory create event: $e');
    }
  }

  /// Update an existing item
  /// Requires [Permissions.editInventoryItem]
  static Future<void> updateItem({
    required int id,
    required Map<String, dynamic> oldItem, // For event log diffing
    required String name,
    required String category,
    required double sellingPrice,
    required double originalPrice,
    required int stock,
    required String imagePath,
    String? visualVector,
    String specification = '',
    String barcode = '',
    String? variationsJson,
    bool isPublished = false,
  }) async {
    // RBAC Check
    final member = await AuthService.getCurrentMember();
    if (member != null && !member.hasPermission(Permissions.editInventoryItem)) {
      throw Exception('Access Denied: You do not have permission to edit items.');
    }

    final cleanCategory = category.split('\\').map((s) => s.trim()).join('\\');

    // Cloud Upload Bypass (If linked to Supabase, this swaps local path for https)
    final cloudUrl = await CloudStorageService.uploadImage(imagePath, folder: 'inventory');
    final filename = (cloudUrl != null && cloudUrl.startsWith('http')) 
        ? cloudUrl 
        : (imagePath.isEmpty ? '' : path.basename(imagePath));

    final previousStock = oldItem['stock'] as int? ?? 0;
    final stockChange = stock - previousStock;
    final cloudId = oldItem['cloud_id'] as String?;
    final sourceModule = oldItem['source_module'] as String? ?? await ModuleScope.tagForWrite();

    // Emit Event
    try {
      await EventService.emitEvent(
        eventType: 'INVENTORY_UPDATE',
        payload: {
          'id': id,
          'itemId': id,
          'previousName': oldItem['name'],
          'newName': name,
          'category': category,
          'previousSellingPrice': oldItem['sellingPrice'],
          'newSellingPrice': sellingPrice,
          'previousOriginalPrice': oldItem['originalPrice'],
          'newOriginalPrice': originalPrice,
          'previousStock': previousStock,
          'newStock': stock,
          'stockChange': stockChange,
          'imagePath': filename,
          'hasVisualVector': visualVector != null && visualVector.isNotEmpty,
          'specification': specification,
          'barcode': barcode,
          'variationsJson': variationsJson,
          'cloud_id': cloudId,
          'source_module': sourceModule,
        },
      );
    } catch (e) {
       debugPrint('⚠️ Failed to emit inventory update event: $e');
    }

    // Perform Write
    await DbProvider.update(
      'inventory',
      {
        'name': name,
        'category': cleanCategory,
        'sellingPrice': sellingPrice,
        'originalPrice': originalPrice,
        'stock': stock,
        'imagePath': filename,
        'visual_vector': visualVector,
        'specification': specification,
        'barcode': barcode,
        'variationsJson': variationsJson,
        'cloud_id': cloudId,
        'source_module': sourceModule,
        'is_published': isPublished ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete an item
  /// Requires [Permissions.deleteInventoryItem]
  static Future<void> deleteItem(Map<String, dynamic> item) async {
    // RBAC Check
    final member = await AuthService.getCurrentMember();
    if (member != null && !member.hasPermission(Permissions.deleteInventoryItem)) {
      throw Exception('Access Denied: You do not have permission to delete items.');
    }

    // Emit Event
    try {
      await EventService.emitEvent(
        eventType: 'INVENTORY_DELETE',
        payload: {
          'id': item['id'],
          'itemId': item['id'],
          'itemName': item['name'],
          'previousStock': item['stock'],
          'cloud_id': item['cloud_id'],
          'source_module': item['source_module'],
        },
      );
    } catch (e) {
      debugPrint('⚠️ Failed to emit inventory delete event: $e');
    }

    // Perform Write
    await DbProvider.delete('inventory', where: 'id = ?', whereArgs: [item['id']]);
  }

  /// Bulk publish/unpublish all items in current module to the marketplace
  /// Requires [Permissions.editInventoryItem]
  static Future<void> bulkPublish(bool publish) async {
    final member = await AuthService.getCurrentMember();
    if (member != null && !member.hasPermission(Permissions.editInventoryItem)) {
      throw Exception('Access Denied: You do not have permission to edit items.');
    }
    
    final scope = await ModuleScope.current();
    final db = await DbProvider.db;
    
    // Convert to 1 or 0
    final publishVal = publish ? 1 : 0;
    
    // Update locally based on active module scope
    await db.rawUpdate(
      'UPDATE inventory SET is_published = ? WHERE ${scope.inventoryWhere}',
      [publishVal, ...scope.moduleArgs],
    );

    // Emit a macro shop update to trigger the global sync engine
    try {
      await EventService.emitEvent(
        eventType: 'SHOP_UPDATE',
        payload: {
          'action': publish ? 'bulk_publish' : 'bulk_unpublish',
          'module': scope.activeModules.isNotEmpty ? scope.activeModules.first : 'unknown',
        },
      );
    } catch (e) {
      debugPrint('⚠️ Failed to emit bulk publish event: $e');
    }
  }
}
