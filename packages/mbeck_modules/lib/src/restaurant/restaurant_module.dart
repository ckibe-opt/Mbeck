import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/module_base.dart';
import '../core/module_types.dart';
import '../core/module_feature.dart';
import '../core/route_definition.dart';

/// Restaurant module for food service businesses.
/// 
/// Features:
/// - Menu management with categories and modifiers
/// - Order types: dine-in, takeaway, delivery
/// - Kitchen display for order queue
/// - Optional table management
class RestaurantModule extends MbeckModule {
  @override
  ModuleType get type => ModuleType.restaurant;

  @override
  String get id => 'restaurant';

  @override
  String get displayName => 'Restaurant & Food';

  @override
  IconData get icon => Icons.restaurant_menu;

  @override
  String get description => 
    'Menu management, orders, and kitchen display for food service businesses';

  @override
  String get version => '1.0.0';

  // ========== Features ==========
  
  @override
  List<ModuleFeature> get features => const [
    ModuleFeature(
      id: 'menu_management',
      name: 'Menu Management',
      description: 'Add, edit, and organize menu items',
      defaultEnabled: true,
      iconName: 'menu_book',
    ),
    ModuleFeature(
      id: 'modifiers',
      name: 'Item Modifiers',
      description: 'Customizations like size, extras, special requests',
      defaultEnabled: true,
      iconName: 'tune',
    ),
    ModuleFeature(
      id: 'dine_in',
      name: 'Dine-In Orders',
      description: 'Table service for in-restaurant dining',
      defaultEnabled: true,
      iconName: 'table_restaurant',
    ),
    ModuleFeature(
      id: 'takeaway',
      name: 'Takeaway Orders',
      description: 'Pickup orders for customers',
      defaultEnabled: true,
      iconName: 'takeout_dining',
    ),
    ModuleFeature(
      id: 'delivery',
      name: 'Delivery Orders',
      description: 'Delivery service (requires address setup)',
      defaultEnabled: false,
      iconName: 'delivery_dining',
    ),
    ModuleFeature(
      id: 'kitchen_display',
      name: 'Kitchen Display',
      description: 'Real-time order queue for kitchen staff',
      defaultEnabled: true,
      iconName: 'monitor',
    ),
    ModuleFeature(
      id: 'table_management',
      name: 'Table Management',
      description: 'Visual table layout and status tracking',
      defaultEnabled: false,
      iconName: 'grid_view',
    ),
  ];

  // ========== API Routes ==========
  
  @override
  List<RouteDefinition> get apiRoutes => [
    // Menu endpoints
    RouteDefinition(
      method: 'GET',
      path: '/api/v1/restaurant/menu',
      description: 'Get menu for customers',
      handler: _menuHandler,
    ),
    // Order endpoints
    RouteDefinition(
      method: 'GET',
      path: '/api/v1/restaurant/orders',
      description: 'Get active orders (provider only)',
      handler: _ordersHandler,
    ),
    RouteDefinition(
      method: 'POST',
      path: '/api/v1/restaurant/orders/<id>/complete',
      description: 'Complete order and trigger recipe deductions',
      handler: _completeOrderHandler,
    ),
    // Subsystem A: Split Bills
    RouteDefinition(
      method: 'POST',
      path: '/api/v1/restaurant/orders/<id>/split',
      description: 'Record a split payment for an order',
      handler: _splitBillHandler,
    ),
    // Subsystem B: Course Firing
    RouteDefinition(
      method: 'POST',
      path: '/api/v1/restaurant/orders/<id>/fire_course',
      description: 'Fire a specific course to the kitchen',
      handler: _fireCourseHandler,
    ),
    // Subsystem C: Table Transfers
    RouteDefinition(
      method: 'PUT',
      path: '/api/v1/restaurant/orders/transfer',
      description: 'Transfer or merge tables',
      handler: _transferTableHandler,
    ),
    // Subsystem D: Recipe Costing
    RouteDefinition(
      method: 'GET',
      path: '/api/v1/restaurant/recipes',
      description: 'Get all recipes',
      handler: _recipesHandler,
    ),
    RouteDefinition(
      method: 'POST',
      path: '/api/v1/restaurant/recipes',
      description: 'Create a new recipe mapping',
      handler: _createRecipeHandler,
    ),
  ];

  static dynamic _getDb(Request request) {
    return request.context['db'];
  }

  // Placeholder handlers - will be implemented with actual business logic
  static Future<Response> _menuHandler(Request request) async {
    return Response.ok(
      '{"menu": [], "message": "Menu endpoint - implementation pending"}',
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<Response> _ordersHandler(Request request) async {
    return Response.ok(
      '{"orders": [], "message": "Orders endpoint - implementation pending"}',
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<Response> _completeOrderHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      
      final orderIdStr = request.params['id'];
      if (orderIdStr == null) return Response(400, body: '{"error": "Missing order ID"}');
      final orderId = int.tryParse(orderIdStr);

      await db.transaction((txn) async {
        // 1. Mark order as completed
        await txn.update(
          'restaurant_orders',
          {'status': 'completed', 'updated_at': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [orderId]
        );

        // 2. Fetch all line items from the order
        final items = await txn.query(
          'restaurant_order_items',
          columns: ['menu_item_id', 'quantity'],
          where: 'order_id = ?',
          whereArgs: [orderId]
        );

        // 3. Subsystem D: Recipe Costing. Deduct underlying inventory based on recipes.
        for (final item in items) {
          final menuItemId = item['menu_item_id'];
          final orderQty = (item['quantity'] as num).toDouble();

          final recipes = await txn.query(
            'restaurant_recipes',
            columns: ['restaurant_inventory_id', 'quantity_required'],
            where: 'menu_item_id = ?',
            whereArgs: [menuItemId]
          );

          for (final recipe in recipes) {
            final invId = recipe['restaurant_inventory_id'];
            final reqQty = (recipe['quantity_required'] as num).toDouble();
            final totalDeduction = orderQty * reqQty;

            // Update underlying isolated restaurant inventory mapping
            await txn.rawUpdate(
              'UPDATE restaurant_inventory SET stock_level = stock_level - ? WHERE id = ?',
              [totalDeduction, invId]
            );
          }
        }
      });

      return Response.ok(jsonEncode({'success': true}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _splitBillHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      
      final orderIdStr = request.params['id'];
      if (orderIdStr == null) return Response(400, body: '{"error": "Missing order ID"}');
      final orderId = int.tryParse(orderIdStr);

      final payload = jsonDecode(await request.readAsString());
      if (payload['amount'] == null || payload['sub_txn_id'] == null) {
        return Response(400, body: '{"error": "amount and sub_txn_id are required"}');
      }

      final amountPaid = (payload['amount'] as num).toDouble();

      int splitId = -1;
      
      await db.transaction((txn) async {
        // 1. Log the partial payment
        splitId = await txn.insert('restaurant_split_bills', {
          'order_id': orderId,
          'sub_txn_id': payload['sub_txn_id'].toString(),
          'amount': amountPaid,
          'status': payload['status'] ?? 'paid',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        // 2. Fetch current order total
        final orderQuery = await txn.query(
          'restaurant_orders',
          columns: ['total', 'status'],
          where: 'id = ?',
          whereArgs: [orderId],
        );

        if (orderQuery.isNotEmpty) {
          final currentTotal = (orderQuery.first['total'] as num).toDouble();
          final newTotal = currentTotal - amountPaid;
          
          // 3. Update the order balance. If <= 0, the order is fully paid.
          await txn.update(
            'restaurant_orders',
            {
              'total': newTotal < 0 ? 0 : newTotal,
              'status': newTotal <= 0.01 ? 'paid' : orderQuery.first['status'], 
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [orderId],
          );
        }
      });

      return Response.ok(jsonEncode({'success': true, 'id': splitId}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _fireCourseHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');

      final orderIdStr = request.params['id'];
      if (orderIdStr == null) return Response(400, body: '{"error": "Missing order ID"}');
      final orderId = int.tryParse(orderIdStr);

      final payload = jsonDecode(await request.readAsString());
      if (payload['course'] == null) {
        return Response(400, body: '{"error": "course is required"}');
      }

      final courseId = (payload['course'] as num).toInt();

      // Update status of all items in this course to 'preparing' and set the fire time.
      int count = await db.update(
        'restaurant_order_items',
        {
          'status': 'preparing',
          'fired_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'order_id = ? AND course_id = ? AND status = ?',
        whereArgs: [orderId, courseId, 'pending']
      );

      return Response.ok(jsonEncode({'success': true, 'items_fired': count}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _transferTableHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');

      final payload = jsonDecode(await request.readAsString());
      if (payload['order_id'] == null || payload['new_table_number'] == null) {
        return Response(400, body: '{"error": "order_id and new_table_number are required"}');
      }

      final orderId = payload['order_id'];
      final newTable = payload['new_table_number'].toString();

      await db.transaction((txn) async {
        // 1. Check if the target table already has an active order
        final existing = await txn.query(
          'restaurant_orders',
          where: 'table_number = ? AND status NOT IN (?, ?)',
          whereArgs: [newTable, 'completed', 'paid'],
        );

        if (existing.isNotEmpty) {
          // Table Merge: Link the old order as a child to the existing order
          final targetOrderId = existing.first['id'];
          await txn.update(
            'restaurant_orders',
            {
              'parent_order_id': targetOrderId,
              'table_number': newTable,
              'updated_at': DateTime.now().millisecondsSinceEpoch
            },
            where: 'id = ?',
            whereArgs: [orderId]
          );
        } else {
          // Standard Transfer
          await txn.update(
            'restaurant_orders',
            {'table_number': newTable, 'updated_at': DateTime.now().millisecondsSinceEpoch},
            where: 'id = ?',
            whereArgs: [orderId]
          );
        }
      });

      return Response.ok(jsonEncode({'success': true}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _recipesHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      
      final menuItemId = request.url.queryParameters['menu_item_id'];
      
      String query = '''
        SELECT r.*, m.name as menu_item_name
        FROM restaurant_recipes r
        JOIN restaurant_menu m ON r.menu_item_id = m.id
      ''';
      List<dynamic> args = [];
      
      if (menuItemId != null) {
        query += ' WHERE r.menu_item_id = ?';
        args.add(int.parse(menuItemId));
      }
      
      final recipes = await db.rawQuery(query, args);
      return Response.ok(jsonEncode({'recipes': recipes}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _createRecipeHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');

      final payload = jsonDecode(await request.readAsString());
      if (payload['menu_item_id'] == null || payload['inventory_id'] == null || payload['quantity_required'] == null) {
        return Response(400, body: '{"error": "menu_item_id, inventory_id, and quantity_required are required"}');
      }

      final id = await db.insert('restaurant_recipes', {
        'menu_item_id': payload['menu_item_id'],
        'inventory_id': payload['inventory_id'],
        'quantity_required': payload['quantity_required']
      });

      return Response.ok(jsonEncode({'success': true, 'id': id}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // ========== Screens ==========
  
  @override
  List<ModuleScreen> get providerScreens => [
    ModuleScreen(
      route: '/restaurant/menu',
      builder: (_) => const _PlaceholderScreen(title: 'Menu Management'),
      icon: Icons.menu_book,
      label: 'Menu',
      isDefault: true,
    ),
    ModuleScreen(
      route: '/restaurant/orders',
      builder: (_) => const _PlaceholderScreen(title: 'Order Queue'),
      icon: Icons.receipt_long,
      label: 'Orders',
    ),
    ModuleScreen(
      route: '/restaurant/kitchen',
      builder: (_) => const _PlaceholderScreen(title: 'Kitchen Display'),
      icon: Icons.monitor,
      label: 'Kitchen',
    ),
  ];

  @override
  List<ModuleScreen> get customerScreens => [
    ModuleScreen(
      route: '/restaurant/browse',
      builder: (_) => const _PlaceholderScreen(title: 'Browse Menu'),
      icon: Icons.restaurant_menu,
      label: 'Menu',
      isDefault: true,
    ),
    ModuleScreen(
      route: '/restaurant/my-orders',
      builder: (_) => const _PlaceholderScreen(title: 'My Orders'),
      icon: Icons.receipt,
      label: 'My Orders',
    ),
  ];

  // ========== Database Migrations ==========
  
  @override
  List<String> get migrationSQL => [
    // Menu items table
    '''
    CREATE TABLE IF NOT EXISTS restaurant_menu (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      price REAL NOT NULL,
      category TEXT NOT NULL,
      image_path TEXT,
      available INTEGER NOT NULL DEFAULT 1,
      prep_time_minutes INTEGER DEFAULT 15,
      sort_order INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_restaurant_menu_category ON restaurant_menu(category)',
    'CREATE INDEX IF NOT EXISTS idx_restaurant_menu_available ON restaurant_menu(available)',
    
    // Modifier groups (e.g., "Size", "Extras")
    '''
    CREATE TABLE IF NOT EXISTS restaurant_modifier_groups (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      menu_item_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      min_selections INTEGER DEFAULT 0,
      max_selections INTEGER DEFAULT 1,
      sort_order INTEGER DEFAULT 0,
      FOREIGN KEY (menu_item_id) REFERENCES restaurant_menu(id) ON DELETE CASCADE
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_modifier_groups_item ON restaurant_modifier_groups(menu_item_id)',
    
    // Individual modifiers (e.g., "Large +50", "Extra Cheese +30")
    '''
    CREATE TABLE IF NOT EXISTS restaurant_modifiers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      group_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      price_adjustment REAL DEFAULT 0,
      available INTEGER NOT NULL DEFAULT 1,
      sort_order INTEGER DEFAULT 0,
      FOREIGN KEY (group_id) REFERENCES restaurant_modifier_groups(id) ON DELETE CASCADE
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_modifiers_group ON restaurant_modifiers(group_id)',
    
    // Orders table (must match db_provider.dart schema)
    '''
    CREATE TABLE IF NOT EXISTS restaurant_orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cloud_id TEXT,
      order_number TEXT NOT NULL UNIQUE,
      order_type TEXT NOT NULL DEFAULT 'dine_in',
      table_number TEXT,
      customer_name TEXT,
      customer_phone TEXT,
      items_json TEXT NOT NULL,
      subtotal REAL NOT NULL,
      tax REAL DEFAULT 0,
      total REAL NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      notes TEXT,
      source_module TEXT DEFAULT 'restaurant',
      created_by TEXT,
      preparing_by TEXT,
      ready_by TEXT,
      served_by TEXT,
      completed_by TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_restaurant_orders_status ON restaurant_orders(status)',
    'CREATE INDEX IF NOT EXISTS idx_restaurant_orders_created ON restaurant_orders(created_at)',
    
    // Order items (line items within an order)
    '''
    CREATE TABLE IF NOT EXISTS restaurant_order_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL,
      menu_item_id INTEGER,
      menu_item_name TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 1,
      unit_price REAL NOT NULL,
      subtotal REAL NOT NULL,
      modifiers_json TEXT,
      item_note TEXT,
      status TEXT DEFAULT 'pending',
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
      FOREIGN KEY (order_id) REFERENCES restaurant_orders(id) ON DELETE CASCADE
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_order_items_order ON restaurant_order_items(order_id)',
    
    // Optional: Tables for dine-in
    '''
    CREATE TABLE IF NOT EXISTS restaurant_tables (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      table_number INTEGER NOT NULL UNIQUE,
      capacity INTEGER DEFAULT 4,
      status TEXT NOT NULL DEFAULT 'available',
      current_order_id INTEGER,
      position_x REAL,
      position_y REAL
    )
    ''',
    
    // Subsystem A: Split Bills
    '''
    CREATE TABLE IF NOT EXISTS restaurant_split_bills (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL,
      sub_txn_id TEXT NOT NULL,
      amount REAL NOT NULL,
      status TEXT NOT NULL DEFAULT 'paid',
      payment_ref TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (order_id) REFERENCES restaurant_orders(id) ON DELETE CASCADE
    )
    ''',

    // Subsystem B: Course Firing
    'ALTER TABLE restaurant_order_items ADD COLUMN course INTEGER DEFAULT 1',

    // Subsystem D: Recipe Costing
    '''
    CREATE TABLE IF NOT EXISTS restaurant_recipes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      menu_item_id INTEGER NOT NULL,
      inventory_id TEXT NOT NULL,
      quantity_required REAL NOT NULL,
      FOREIGN KEY (menu_item_id) REFERENCES restaurant_menu(id) ON DELETE CASCADE
    )
    ''',
  ];

  // ========== Lifecycle Hooks ==========
  
  @override
  Future<void> onActivate(dynamic db, String shopId) async {
    // Run migrations
    for (final sql in migrationSQL) {
      try {
        await db.execute(sql);
      } catch (e) {
        // Table/index might already exist
      }
    }
    
    // Insert default menu categories if empty
    final menuCount = await db.rawQuery('SELECT COUNT(*) as count FROM restaurant_menu');
    if ((menuCount.first['count'] as int) == 0) {
      // Could seed with sample menu items here
    }
  }

  @override
  Future<void> onDeactivate(dynamic db, String shopId) async {
    // Data is preserved per design decision
    // Just log deactivation
  }

  // ========== Configuration ==========
  
  @override
  Map<String, dynamic> getDefaultConfig() => {
    'currency': 'KES',
    'defaultPrepTime': 15,
    'orderNumberPrefix': 'ORD',
    'tableCount': 10,
    'categories': ['Appetizers', 'Mains', 'Desserts', 'Drinks'],
  };

  @override
  String? validateConfig(Map<String, dynamic> config) {
    if (config['defaultPrepTime'] != null && config['defaultPrepTime'] < 1) {
      return 'Prep time must be at least 1 minute';
    }
    return null;
  }
}

/// Placeholder screen used until real implementations are built
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('Coming Soon', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
