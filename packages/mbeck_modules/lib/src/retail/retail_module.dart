import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/module_base.dart';
import '../core/module_feature.dart';
import '../core/module_types.dart';
import '../core/route_definition.dart';

/// Retail module for product-based businesses.
class RetailModule extends MbeckModule {
  @override
  ModuleType get type => ModuleType.retail;

  @override
  String get id => 'retail';

  @override
  String get displayName => 'Retail & Inventory';

  @override
  IconData get icon => Icons.shopping_bag;

  @override
  String get description =>
      'Manage products, purchase orders, promotions, returns, and inventory levels';

  @override
  String get version => '1.1.0';

  @override
  List<ModuleFeature> get features => const [
        ModuleFeature(
          id: 'ai_scanner',
          name: 'AI Visual Scanner',
          description: 'Recognize products by camera using machine learning',
          defaultEnabled: true,
          iconName: 'camera_alt',
        ),
        ModuleFeature(
          id: 'barcode',
          name: 'Barcode Support',
          description: 'Scan traditional barcodes and QR codes',
          defaultEnabled: true,
          iconName: 'qr_code_scanner',
        ),
        ModuleFeature(
          id: 'stock_alerts',
          name: 'Low Stock Alerts',
          description: 'Get notified when items are running low',
          defaultEnabled: false,
          iconName: 'notifications_active',
        ),
        ModuleFeature(
          id: 'categories',
          name: 'Product Categories',
          description: 'Organize products into categories',
          defaultEnabled: true,
          iconName: 'category',
        ),
        ModuleFeature(
          id: 'purchase_orders',
          name: 'Purchase Orders & Suppliers',
          description: 'Manage vendors and receive stock via POs',
          defaultEnabled: true,
          iconName: 'local_shipping',
        ),
        ModuleFeature(
          id: 'returns_exchanges',
          name: 'Returns & Exchanges',
          description: 'Process customer returns and restock inventory',
          defaultEnabled: true,
          iconName: 'assignment_return',
        ),
        ModuleFeature(
          id: 'promotions',
          name: 'Promotions Engine',
          description: 'Create dynamic discounts and BOGO offers',
          defaultEnabled: false,
          iconName: 'local_offer',
        ),
        ModuleFeature(
          id: 'stock_audits',
          name: 'Stock Audits',
          description: 'Reconcile physical stock vs system counts',
          defaultEnabled: false,
          iconName: 'fact_check',
        ),
      ];

  @override
  List<RouteDefinition> get apiRoutes => [
        // Subsystem A: Returns & Exchanges
        RouteDefinition(
          method: 'POST',
          path: '/api/v1/retail/returns',
          description: 'Process a return or exchange',
          handler: _processReturnHandler,
        ),
        // Subsystem B: Purchase Orders & Suppliers
        RouteDefinition(
          method: 'GET',
          path: '/api/v1/retail/suppliers',
          description: 'List suppliers',
          handler: _suppliersHandler,
        ),
        RouteDefinition(
          method: 'POST',
          path: '/api/v1/retail/suppliers',
          description: 'Create a supplier',
          handler: _createSupplierHandler,
        ),
        RouteDefinition(
          method: 'GET',
          path: '/api/v1/retail/purchase_orders',
          description: 'List purchase orders',
          handler: _purchaseOrdersHandler,
        ),
        RouteDefinition(
          method: 'POST',
          path: '/api/v1/retail/purchase_orders',
          description: 'Create a purchase order',
          handler: _createPurchaseOrderHandler,
        ),
        RouteDefinition(
          method: 'POST',
          path: '/api/v1/retail/purchase_orders/:id/receive',
          description: 'Receive items from a PO and update stock',
          handler: _receivePurchaseOrderHandler,
        ),
        // Subsystem C: Promotions
        RouteDefinition(
          method: 'GET',
          path: '/api/v1/retail/promotions',
          description: 'List active promotions',
          handler: _promotionsHandler,
        ),
        RouteDefinition(
          method: 'POST',
          path: '/api/v1/retail/promotions',
          description: 'Create a promotion',
          handler: _createPromotionHandler,
        ),
        // Subsystem D: Stock Audits
        RouteDefinition(
          method: 'POST',
          path: '/api/v1/retail/inventory/audit',
          description: 'Submit a physical stock audit',
          handler: _stockAuditHandler,
        ),
      ];



  static dynamic _getDb(Request request) {
    return request.context['db'];
  }

// Subsystem A: Returns & Exchanges
  static Future<Response> _processReturnHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      
      final payload = jsonDecode(await request.readAsString());
      if (payload['item_id'] == null || payload['quantity'] == null || payload['refund_amount'] == null) {
        return Response(400, body: '{"error": "item_id, quantity, and refund_amount are required"}');
      }

      final itemId = payload['item_id'];
      final qty = (payload['quantity'] as num).toInt();
      
      // Verify item exists
      final item = await db.query('inventory', where: 'id = ?', whereArgs: [itemId]);
      if (item.isEmpty) return Response.notFound(jsonEncode({'error': 'Item not found'}));

      int returnId = -1;
      await db.transaction((txn) async {
        // Log the return
        returnId = await txn.insert('retail_returns', {
          'original_txn_id': payload['original_txn_id'],
          'item_id': itemId,
          'quantity': qty,
          'refund_amount': payload['refund_amount'],
          'reason_code': payload['reason_code'],
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        // Restock inventory
        await txn.rawUpdate('''
          UPDATE inventory 
          SET stock = stock + ? 
          WHERE id = ?
        ''', [qty, itemId]);
      });

      return Response.ok(jsonEncode({'id': returnId, 'success': true}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // --- Subsystem B: Purchase Orders & Suppliers ---
  
  static Future<Response> _suppliersHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      final suppliers = await db.query('retail_suppliers', orderBy: 'name ASC');
      return Response.ok(jsonEncode({'suppliers': suppliers}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _createSupplierHandler(Request request) async {
    try {
      final payload = jsonDecode(await request.readAsString());
      if (payload['name'] == null) return Response(400, body: '{"error": "Supplier name is required"}');
      
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      final id = await db.insert('retail_suppliers', {
        'name': payload['name'],
        'contact_name': payload['contact_name'],
        'email': payload['email'],
        'phone': payload['phone'],
        'address': payload['address'],
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      return Response.ok(jsonEncode({'id': id, 'success': true}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _purchaseOrdersHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      // Fetch POs with supplier names
      final pos = await db.rawQuery('''
        SELECT po.*, s.name as supplier_name 
        FROM retail_purchase_orders po
        LEFT JOIN retail_suppliers s ON po.supplier_id = s.id
        ORDER BY po.created_at DESC
      ''');
      
      // Fetch items for each PO
      final results = [];
      for (var po in pos) {
        final items = await db.rawQuery('''
          SELECT i.*, inv.name as inventory_name 
          FROM retail_po_items i
          LEFT JOIN inventory inv ON i.inventory_id = inv.id
          WHERE i.po_id = ?
        ''', [po['id']]);
        
        final poMap = Map<String, dynamic>.from(po);
        poMap['items'] = items;
        results.add(poMap);
      }
      
      return Response.ok(jsonEncode({'purchase_orders': results}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _createPurchaseOrderHandler(Request request) async {
    try {
      final payload = jsonDecode(await request.readAsString());
      if (payload['supplier_id'] == null || payload['items'] == null) {
        return Response(400, body: '{"error": "supplier_id and items array are required"}');
      }
      
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      int poId = -1;
      
      await db.transaction((txn) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        poId = await txn.insert('retail_purchase_orders', {
          'supplier_id': payload['supplier_id'],
          'status': 'draft',
          'eta_date': payload['eta_date'],
          'created_at': now,
          'updated_at': now,
        });
        
        double totalCost = 0;
        final items = payload['items'] as List;
        for (var item in items) {
          final qty = (item['quantity'] as num).toInt();
          final cost = (item['unit_cost'] as num).toDouble();
          totalCost += (qty * cost);
          
          await txn.insert('retail_po_items', {
            'po_id': poId,
            'inventory_id': item['inventory_id'],
            'quantity_ordered': qty,
            'unit_cost': cost,
          });
        }
        
        await txn.update('retail_purchase_orders', {'total_cost': totalCost}, where: 'id = ?', whereArgs: [poId]);
      });
      
      return Response.ok(jsonEncode({'id': poId, 'success': true}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _receivePurchaseOrderHandler(Request request) async {
    try {
      final idStr = request.params['id'];
      if (idStr == null) return Response(400, body: '{"error": "Missing PO ID"}');
      final poId = int.tryParse(idStr);
      
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      final po = await db.query('retail_purchase_orders', where: 'id = ?', whereArgs: [poId]);
      if (po.isEmpty) return Response.notFound(jsonEncode({'error': 'PO not found'}));
      if (po.first['status'] == 'received') return Response(400, body: '{"error": "PO already received"}');
      
      await db.transaction((txn) async {
        // Mark PO as received
        await txn.update('retail_purchase_orders', 
          {'status': 'received', 'updated_at': DateTime.now().millisecondsSinceEpoch}, 
          where: 'id = ?', whereArgs: [poId]
        );
        
        // Receive items and increment inventory
        final items = await txn.query('retail_po_items', where: 'po_id = ?', whereArgs: [poId]);
        for (var item in items) {
          // Mark item as received
          await txn.update('retail_po_items', 
            {'quantity_received': item['quantity_ordered']}, 
            where: 'id = ?', whereArgs: [item['id']]
          );
          
          // Increment actual stock
          await txn.rawUpdate('''
            UPDATE inventory 
            SET stock = stock + ? 
            WHERE id = ?
          ''', [item['quantity_ordered'], item['inventory_id']]);
        }
      });
      
      return Response.ok(jsonEncode({'success': true, 'message': 'PO received and stock updated'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // --- Subsystem C: Promotions ---
  static Future<Response> _promotionsHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      final now = DateTime.now().millisecondsSinceEpoch;
      // Fetch active promotions
      final promos = await db.rawQuery('''
        SELECT * FROM retail_promotions 
        WHERE is_active = 1 
        AND (start_date IS NULL OR start_date <= ?)
        AND (end_date IS NULL OR end_date >= ?)
      ''', [now, now]);
      return Response.ok(jsonEncode({'promotions': promos}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _createPromotionHandler(Request request) async {
    try {
      final payload = jsonDecode(await request.readAsString());
      if (payload['name'] == null || payload['type'] == null || payload['discount_value'] == null) {
        return Response(400, body: '{"error": "name, type, and discount_value are required"}');
      }
      
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      final id = await db.insert('retail_promotions', {
        'name': payload['name'],
        'type': payload['type'],
        'target_item_id': payload['target_item_id'],
        'target_category': payload['target_category'],
        'discount_value': payload['discount_value'],
        'min_spend': payload['min_spend'] ?? 0,
        'start_date': payload['start_date'],
        'end_date': payload['end_date'],
        'is_active': payload['is_active'] ?? 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      return Response.ok(jsonEncode({'id': id, 'success': true}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }
  
  // --- Subsystem D: Stock Audits ---
  static Future<Response> _stockAuditHandler(Request request) async {
    try {
      final payload = jsonDecode(await request.readAsString());
      if (payload['inventory_id'] == null || payload['actual_stock'] == null) {
        return Response(400, body: '{"error": "inventory_id and actual_stock are required"}');
      }
      
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      final itemId = payload['inventory_id'];
      final actualStock = (payload['actual_stock'] as num).toInt();
      
      final item = await db.query('inventory', where: 'id = ?', whereArgs: [itemId]);
      if (item.isEmpty) return Response.notFound(jsonEncode({'error': 'Item not found'}));
      
      final expectedStock = (item.first['stock'] as num?)?.toInt() ?? 0;
      final difference = actualStock - expectedStock;
      
      int auditId = -1;
      await db.transaction((txn) async {
        // Log audit
        auditId = await txn.insert('retail_stock_audits', {
          'inventory_id': itemId,
          'expected_stock': expectedStock,
          'actual_stock': actualStock,
          'difference': difference,
          'reason': payload['reason'],
          'performed_by': payload['performed_by'],
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        // Set absolute actual stock value
        if (difference != 0) {
          await txn.update('inventory', {'stock': actualStock}, where: 'id = ?', whereArgs: [itemId]);
        }
      });
      
      return Response.ok(jsonEncode({'id': auditId, 'success': true}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  @override
  List<ModuleScreen> get providerScreens => [];

  @override
  List<ModuleScreen> get customerScreens => [];

  @override
  List<String> get migrationSQL => [
        // Legacy Inventory Table
        '''
        CREATE TABLE IF NOT EXISTS inventory (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          category TEXT,
          specification TEXT,
          barcode TEXT,
          sellingPrice REAL NOT NULL DEFAULT 0,
          originalPrice REAL DEFAULT 0,
          stock INTEGER DEFAULT 0,
          imagePath TEXT,
          image_path TEXT,
          visual_vector TEXT,
          variationsJson TEXT,
          cloud_id TEXT,
          source_module TEXT DEFAULT 'retail',
          created_at INTEGER,
          updated_at INTEGER
        );
        ''',
        '''CREATE INDEX IF NOT EXISTS idx_inventory_category ON inventory(category);''',
        '''CREATE INDEX IF NOT EXISTS idx_inventory_barcode ON inventory(barcode);''',
        
        // Subsystem A: Returns
        '''
        CREATE TABLE IF NOT EXISTS retail_returns (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          original_txn_id TEXT,
          item_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          refund_amount REAL NOT NULL,
          reason_code TEXT,
          status TEXT DEFAULT 'completed',
          cloud_id TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        );
        ''',

        // Subsystem B: Purchase Orders & Suppliers
        '''
        CREATE TABLE IF NOT EXISTS retail_suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          contact_name TEXT,
          email TEXT,
          phone TEXT,
          address TEXT,
          cloud_id TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        );
        ''',
        '''
        CREATE TABLE IF NOT EXISTS retail_purchase_orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL,
          status TEXT DEFAULT 'draft',
          total_cost REAL DEFAULT 0,
          eta_date INTEGER,
          cloud_id TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          FOREIGN KEY (supplier_id) REFERENCES retail_suppliers(id)
        );
        ''',
        '''
        CREATE TABLE IF NOT EXISTS retail_po_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          po_id INTEGER NOT NULL,
          inventory_id INTEGER NOT NULL,
          quantity_ordered INTEGER NOT NULL,
          quantity_received INTEGER DEFAULT 0,
          unit_cost REAL NOT NULL,
          FOREIGN KEY (po_id) REFERENCES retail_purchase_orders(id),
          FOREIGN KEY (inventory_id) REFERENCES inventory(id)
        );
        ''',

        // Subsystem C: Promotions
        '''
        CREATE TABLE IF NOT EXISTS retail_promotions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          target_item_id INTEGER,
          target_category TEXT,
          discount_value REAL NOT NULL,
          min_spend REAL DEFAULT 0,
          start_date INTEGER,
          end_date INTEGER,
          is_active INTEGER DEFAULT 1,
          cloud_id TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        );
        ''',

        // Subsystem D: Stock Audits
        '''
        CREATE TABLE IF NOT EXISTS retail_stock_audits (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          inventory_id INTEGER NOT NULL,
          expected_stock INTEGER NOT NULL,
          actual_stock INTEGER NOT NULL,
          difference INTEGER NOT NULL,
          reason TEXT,
          performed_by TEXT,
          cloud_id TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          FOREIGN KEY (inventory_id) REFERENCES inventory(id)
        );
        ''',
      ];

  @override
  Future<void> onActivate(dynamic db, String shopId) async {
    for (final sql in migrationSQL) {
      try {
        await db.execute(sql);
      } catch (e) {
        debugPrint('⚠️ Retail migration: $e');
      }
    }
    debugPrint('🛍️ RetailModule activated for shop $shopId');
  }

  @override
  Future<void> onDeactivate(dynamic db, String shopId) async {
    debugPrint('🛍️ RetailModule deactivated for shop $shopId');
  }

  @override
  Map<String, dynamic> getDefaultConfig() => {
        'features': {
          'ai_scanner': true,
          'barcode': true,
          'stock_alerts': false,
          'categories': true,
          'purchase_orders': true,
          'returns_exchanges': true,
          'promotions': false,
          'stock_audits': false,
        },
        'ui': {
          'layout': 'grid',
          'showStock': true,
          'showCategories': true,
        },
        'scanner': {
          'mode': 'ai',
          'confidenceThreshold': 0.7,
        },
      };

  @override
  String? validateConfig(Map<String, dynamic> config) {
    if (config['features'] == null) {
      return 'Missing features configuration';
    }
    return null;
  }
}
