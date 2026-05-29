
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../db/db_provider.dart';
import '../../services/event_service.dart';
import '../../services/event_processor.dart';
import '../../services/device_service.dart';
import '../../services/security_service.dart';
import '../middleware/api_auth_middleware.dart';
import '../../services/auth_service.dart';
import '../../services/checkout_sync_service.dart';
import '../../services/module_service.dart';
import '../../services/onboarding_service.dart';
import 'package:mbeck_modules/mbeck_modules.dart';
import '../../services/performance_monitor.dart';
import '../../services/waiter_ring_service.dart';
import '../../models/event.dart'; // Added for Event class
import 'snapshot_handler.dart';

class ApiRouter {
  // Define the router
  final Router _router = Router();

  ApiRouter() {
    _initRoutes();
  }

  // Expose the router handler
  Handler get handler => _router.call;

  void _initRoutes() {
    // 1. Health Check (public)
    _router.get('/api/v1/status', _statusHandler);

    // 2. Public Inventory (public - for browsing)
    _router.get('/api/v1/inventory/public', _publicInventoryHandler);

    // 3. Services booking endpoints (public)
    _router.get('/api/v1/services/availability', _servicesAvailabilityHandler);
    _router.post('/api/v1/services/book', _servicesBookingHandler);

    // 4. Discovery endpoint (public - for HTTP-based shop discovery)
    _router.get('/api/v1/discover', _discoveryHandler);
    
    // 5. Image serving endpoint (public)
    _router.get('/api/v1/images/<filename>', _imagesHandler);
    
    // 6. Theme endpoint (public - Offline Support)
    _router.get('/api/v1/theme', _themeHandler);

    // 6b. Shop cover image endpoint (public)
    _router.get('/api/v1/shop-image', _shopImageHandler);

    // 7. Checkout endpoint - PROTECTED with auth + rate limiting
    _router.post('/api/v1/cart/checkout', 
      Pipeline()
        .addMiddleware(ApiAuthMiddleware.requireAuth(checkRate: true))
        .addMiddleware(ApiAuthMiddleware.blockObservers())
        .addHandler(_checkoutHandler)
    );

    // 8. Info/Handshake endpoint (public - generates session token)
    _router.get('/api/v1/info', _infoHandler);

    // 9. Real-time Checkout Sync (public for polling)
    _router.get('/api/v1/checkout/sync', _checkoutSyncHandler);

    // 10. Receipt ACK (public)
    _router.post('/api/v1/checkout/ack', _checkoutAckHandler);

    // 13. Performance Metrics (debug)
    _router.get('/api/v1/performance', _performanceHandler);

    // 14. Entertainment assets (public - for buyer browsing)
    _router.get('/api/v1/entertainment/assets', _entertainmentAssetsHandler);

    // 15. Lodging rooms (public - for buyer browsing)
    _router.get('/api/v1/lodging/rooms', _lodgingRoomsHandler);

    // 15b. Lodging room types with images (public - for buyer browsing)
    _router.get('/api/v1/lodging/room-types', _lodgingRoomTypesHandler);

    // 16. Order ping - buyer signals they have an order ready
    _router.post('/api/v1/order/ping', _orderPingHandler);

    // 16b. Restaurant order routes (buyer → seller local sync)
    _router.post('/api/v1/restaurant/orders', _restaurantOrdersPostHandler);
    _router.get('/api/v1/restaurant/orders/status', _restaurantOrdersStatusHandler);

    // 17. Receipt fetch by transaction ID or signature
    _router.get('/api/v1/receipt/<txnId>', _receiptHandler);

    // 17b. Fetch all receipts for the current buyer
    _router.get('/api/v1/receipts', 
      Pipeline()
        .addMiddleware(ApiAuthMiddleware.requireAuth())
        .addHandler(_buyerReceiptsHandler)
    );

    // 17c. Fetch active orders for the current buyer
    _router.get('/api/v1/orders/active', 
      Pipeline()
        .addMiddleware(ApiAuthMiddleware.requireAuth())
        .addHandler(_activeOrdersHandler)
    );

    // 18. Services staff list (public)
    _router.get('/api/v1/services/staff', _servicesStaffHandler);

    // 19. LAN Snapshot — full DB snapshot for employee data replication
    _router.get('/api/v1/snapshot', SnapshotHandler.handleSnapshot);

    // 20. LAN Event Sync - fetch missing events since timestamp
    _router.get('/api/v1/events/sync', _eventSyncHandler);

    // 21. LAN Event Push - accept missing events from followers
    _router.post('/api/v1/events/push', _eventPushHandler);

    // 22. Lodging reservation (buyer → seller)
    _router.post('/api/v1/lodging/book', _lodgingBookHandler);
    _router.get('/api/v1/lodging/reservations', _lodgingReservationsHandler);

    // 23. Entertainment session booking (buyer → seller)
    _router.post('/api/v1/entertainment/book', _entertainmentBookHandler);

    // 24. Messaging API (buyer ↔ seller)
    _router.get('/api/v1/messages', _messagesGetHandler);
    _router.post('/api/v1/messages', _messagesPostHandler);
    _router.patch('/api/v1/messages/read', _messagesMarkReadHandler);

    // 11. Module Routes
    // Automatically register API routes from all available modules
    debugPrint('🔌 Registering module routes...');
    final Set<String> registeredPaths = {};
    for (final module in ModuleRegistry.instance.allModules) {
      if (module.apiRoutes.isNotEmpty) {
        debugPrint('  + Module: ${module.id} (${module.apiRoutes.length} routes)');
        for (final route in module.apiRoutes) {
          debugPrint('    - ${route.method} ${route.path}');
          if (route.path == '/api/v1/restaurant/menu') {
             debugPrint('    ! Overriding placeholder handler for ${route.path}');
             _router.add(route.method, route.path, _restaurantMenuHandler);
          } else if (route.path == '/api/v1/services/catalog') {
             debugPrint('    ! Overriding handler for ${route.path} to serve Inventory (Catalog)');
             _router.add(route.method, route.path, _serviceCatalogHandler);
          } else {
             // Inject the database connection into the request context
             _router.add(route.method, route.path, (Request request) async {
               final db = await DbProvider.db;
               final injectedRequest = request.change(context: {'db': db});
               return await route.handler(injectedRequest);
             });
          }
          registeredPaths.add(route.path);
        }
      }
    }

    // 12. Fallback routes — if module registry was empty (e.g. background isolate
    // didn't register modules), ensure critical customer-facing endpoints still work
    if (!registeredPaths.contains('/api/v1/restaurant/menu')) {
      debugPrint('⚠️ Restaurant menu route not registered by modules, adding fallback');
      _router.get('/api/v1/restaurant/menu', _restaurantMenuHandler);
    }
    if (!registeredPaths.contains('/api/v1/services/catalog')) {
      debugPrint('⚠️ Services catalog route not registered by modules, adding fallback');
      _router.get('/api/v1/services/catalog', _serviceCatalogHandler);
    }
  }

  // --- Handlers ---

  Future<Response> _statusHandler(Request request) async {
    return Response.ok(
      jsonEncode({
        'status': 'online',
        'service': 'Mbeck Shop Server',
        'version': '1.0.0',
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _publicInventoryHandler(Request request) async {
    try {
      final db = await DbProvider.db;
      
      // Get server host from request headers
      final host = request.headers['host'] ?? 'localhost:8080';
      
      // Get all inventory items from database
      final items = await db.rawQuery('''
        SELECT id, name, category, sellingPrice, originalPrice, stock, imagePath, specification, variationsJson
        FROM inventory
        WHERE stock > 0
        ORDER BY name ASC
      ''');
      
      // Transform to API format with full image URLs
      final List<Map<String, dynamic>> inventoryData = items.map((item) {
        final imagePath = item['imagePath'] as String?;
        final imageUrl = imagePath != null && imagePath.isNotEmpty
            ? 'http://$host/api/v1/images/$imagePath'
            : null;
        
        return {
          'id': item['id'],
          'name': item['name'],
          'sellingPrice': item['sellingPrice'],
          'originalPrice': item['originalPrice'],
          'stock': item['stock'],
          'category': item['category'],
          'specification': item['specification'],
          'variations_json': item['variationsJson'], // Send variations
          'imagePath': imageUrl,
        };
      }).toList();
      
      return Response.ok(
        jsonEncode({
          'data': inventoryData,
          'count': inventoryData.length,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'error': 'Failed to fetch inventory',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }


  
  /// Discovery endpoint for HTTP-based shop discovery (Windows fallback)
  Future<Response> _discoveryHandler(Request request) async {
    try {
      final db = await DbProvider.db;
      
      // Get shop ID from shared preferences or generate temp one
      String shopId = 'shop_${DateTime.now().millisecondsSinceEpoch}';
      String shopName = 'Mbeck Shop';
      
      // Try to get actual shop info from DB
      try {
        final result = await db.rawQuery('SELECT shop_id, shop_name FROM shop_settings LIMIT 1');
        if (result.isNotEmpty) {
          shopId = result.first['shop_id'] as String? ?? shopId;
          shopName = result.first['shop_name'] as String? ?? shopName;
        } else {
            // Fallback to cache
            final shop = await AuthService.getCurrentShop();
            if (shop != null) {
                shopId = shop.id;
                shopName = shop.businessName;
            }
        }
      } catch (e) {
        // Table might not exist, use defaults
        debugPrint('Could not fetch shop settings: $e');
        // Fallback to cache
        final shop = await AuthService.getCurrentShop();
        if (shop != null) {
            shopId = shop.id;
            shopName = shop.businessName;
        }
      }
      
      // Get enabled modules for richer shop cards in the marketplace feed
      List<String> enabledModules = await OnboardingService.getSelectedModules();
      final businessType = enabledModules.isNotEmpty ? enabledModules.first : 'retail';

      return Response.ok(
        jsonEncode({
          'name': shopName,
          'port': 8080,
          'shopId': shopId,
          'type': 'seller',
          'version': '1.0.0',
          'timestamp': DateTime.now().toIso8601String(),
          'enabledModules': enabledModules,
          'businessType': businessType,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'error': 'Discovery failed',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  
  /// Theme endpoint for offline support
  /// Reads from shops.theme_config (same table _saveTheme writes to)
  Future<Response> _themeHandler(Request request) async {
    try {
      final db = await DbProvider.db;
      
      // Primary source: shops.theme_config (where ShopAppearanceScreen saves)
      final shopResult = await db.rawQuery('SELECT theme_config FROM shops LIMIT 1');
      if (shopResult.isNotEmpty && shopResult.first['theme_config'] != null) {
        final raw = shopResult.first['theme_config'];
        final body = raw is String ? raw : jsonEncode(raw);
        return Response.ok(body, headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        });
      }

      // Fallback: shop_settings.branding (legacy)
      final settingsResult = await db.rawQuery('SELECT branding FROM shop_settings LIMIT 1');
      if (settingsResult.isNotEmpty && settingsResult.first['branding'] != null) {
        final raw = settingsResult.first['branding'];
        final body = raw is String ? raw : jsonEncode(raw);
        return Response.ok(body, headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        });
      }
      
      return Response.ok(
        jsonEncode({'style_preset': 'standard'}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      debugPrint('⚠️ Error fetching theme: $e');
      return Response.ok(
        jsonEncode({'style_preset': 'standard'}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    }
  }
  
  /// Serve product images over HTTP
  Future<Response> _imagesHandler(Request request, String filename) async {
    try {
      // Sanitize filename to prevent directory traversal attacks
      final sanitized = path.basename(filename);
      
      // Get documents directory where images are stored
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = path.join(directory.path, sanitized);
      final file = File(imagePath);
      
      // Check if file exists
      if (!await file.exists()) {
        debugPrint('🖼️ Image not found: $imagePath');
        return Response.notFound(
          jsonEncode({'error': 'Image not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      // Determine content type based on extension
      String contentType = 'image/jpeg';
      final ext = path.extension(sanitized).toLowerCase();
      if (ext == '.png') {
        contentType = 'image/png';
      } else if (ext == '.jpg' || ext == '.jpeg') {
        contentType = 'image/jpeg';
      } else if (ext == '.webp') {
        contentType = 'image/webp';
      }
      
      final length = await file.length();
      debugPrint('🖼️ Serving image: $sanitized ($length bytes) via stream');
      
      return Response.ok(
        file.openRead(),
        headers: {
          'Content-Type': contentType,
          'Content-Length': '$length',
          'Access-Control-Allow-Origin': '*',
          'Cache-Control': 'public, max-age=3600', // Cache for 1 hour
        },
      );
    } catch (e) {
      debugPrint('⚠️ Error serving image: $e');
      return Response.internalServerError(
        body: jsonEncode({
          'error': 'Failed to serve image',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Info/Handshake Handler: Returns shop info AND session token
  /// 
  /// The session token should be stored by the Buyer App and sent
  /// in the Authorization header for protected endpoints like checkout.
  /// 
  /// Also returns enabled modules and their configurations for
  /// dynamic UI adaptation on the customer side.
  Future<Response> _infoHandler(Request request) async {
    try {
      final db = await DbProvider.db;
      String shopName = 'Mbeck Shop';
      String shopId = await DeviceService.getShopId();
      
      try {
        final result = await db.rawQuery('SELECT shop_name FROM shop_settings LIMIT 1');
        if (result.isNotEmpty) {
          shopName = result.first['shop_name'] as String? ?? shopName;
        } else {
           // Fallback
           final shop = await AuthService.getCurrentShop();
           if (shop != null) shopName = shop.businessName;
        }
      } catch (e) {
        // use default
        // Fallback
        final shop = await AuthService.getCurrentShop();
        if (shop != null) shopName = shop.businessName;
      }

      // Generate session token for this client
      final clientIp = request.headers['x-forwarded-for'] ?? 
                       request.context['shelf.io.connection_info']?.toString() ??
                       'unknown';
      final sessionToken = ApiAuthMiddleware.generateToken(
        clientId: request.headers['x-client-id'],
        clientIp: clientIp,
        role: 'buyer', // Default role. Enterprise detection would set 'observer'
      );

      // Get enabled modules from OnboardingService (source of truth for seller's selection)
      // Fall back to ModuleService database if onboarding not complete
      List<String> enabledModules = await OnboardingService.getSelectedModules();
      if (enabledModules.isEmpty) {
        enabledModules = await ModuleService.getEnabledModules(shopId);
      }
      final moduleConfigs = await ModuleService.getAllModuleConfigs(shopId);
      
      // Determine primary business type
      final businessType = enabledModules.isNotEmpty ? enabledModules.first : 'retail';
      debugPrint('📡 Info API: Returning modules=$enabledModules, businessType=$businessType');

      // Get shop image and theme
      String? shopImageUrl;
      Map<String, dynamic>? themeJson;
      try {
        final host = request.headers['host'] ?? 'localhost:8080';
        final shopData = await db.rawQuery('SELECT theme_config FROM shops LIMIT 1');
        if (shopData.isNotEmpty && shopData.first['theme_config'] != null) {
          themeJson = jsonDecode(shopData.first['theme_config'] as String);
          final coverUrl = themeJson?['cover_image_url'] as String?;
          if (coverUrl != null && coverUrl.isNotEmpty) {
            shopImageUrl = coverUrl.startsWith('http') ? coverUrl : 'http://$host/api/v1/images/$coverUrl';
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching shop image/theme: $e');
      }

      return Response.ok(
        jsonEncode({
          'name': shopName,
          'shopId': shopId,
          'currency': 'KES',
          'version': '1.0.0',
          'sessionToken': sessionToken,
          'tokenExpiresIn': ApiAuthMiddleware.tokenExpiryHours * 3600, // seconds
          // Module system extensions
          'businessType': businessType,
          'enabledModules': enabledModules,
          'moduleConfigs': moduleConfigs,
          'moduleVersion': '1.0.0',
          // Shop branding
          'shopImageUrl': shopImageUrl,
          'theme': themeJson,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// Checkout Handler: The core commerce transaction
  /// 
  /// Expects JSON:
  /// {
  ///   "items": [
  ///     {"id": 1, "qty": 2},
  ///     {"id": 5, "qty": 1}
  ///   ],
  ///   "meta": "BuyerApp/1.0"
  /// }
  Future<Response> _checkoutHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final payload = jsonDecode(body);
      final List<dynamic> items = payload['items'];
      
      if (items.isEmpty) {
        return Response.badRequest(body: jsonEncode({'error': 'Cart is empty'})); 
      }

      final db = await DbProvider.db;
      double totalAmount = 0.0;
      List<Map<String, dynamic>> processedItems = [];

      // 1. Validate Stock & Calculate Totals
      final double clientTotal = (payload['totalAmount'] as num?)?.toDouble() ?? 0.0;

      List<Map<String, dynamic>> retailProcessedItems = [];
      List<Map<String, dynamic>> restaurantProcessedItems = [];

      for (var item in items) {
        final id = item['id'];
        final qty = (item['qty'] as num?)?.toInt() ?? 0;
        final itemNote = item['item_note'] ?? ''; // Contains variations and modifiers
        
        // Fetch current price & stock from Retail Inventory
        final List<Map<String, dynamic>> stockCheck = await db.query(
          'inventory',
          columns: ['id', 'name', 'stock', 'sellingPrice'],
          where: 'id = ?',
          whereArgs: [id],
        );

        if (stockCheck.isEmpty) {
          // Fallback: Check if it's a Restaurant Menu item
          final List<Map<String, dynamic>> menuCheck = await db.query(
            'restaurant_menu',
            columns: ['id', 'name', 'price'],
            where: 'id = ?',
            whereArgs: [id],
          );
          
          if (menuCheck.isNotEmpty) {
            final product = menuCheck.first;
            final price = (product['price'] as num?)?.toDouble() ?? 0.0;
            double lineTotal = price * qty;
            totalAmount += lineTotal;
            
            restaurantProcessedItems.add({
               'menu_item_id': id,
               'menu_item_name': product['name'],
               'quantity': qty,
               'unit_price': price,
               'subtotal': lineTotal,
               'item_note': itemNote,
            });
            continue; // Move to next item
          } else {
            return Response.badRequest(body: jsonEncode({'error': 'Item #$id not found'}));
          }
        }

        final product = stockCheck.first;
        final currentStock = (product['stock'] as num?)?.toInt() ?? 0;
        final price = (product['sellingPrice'] as num?)?.toDouble() ?? 0.0;

        debugPrint('🛒 Checkout Check: Item ${product["name"]} (ID $id) - ReqQty: $qty, Stock: $currentStock');

        if (currentStock < qty) {
          debugPrint('❌ Insufficient stock!');
          return Response.badRequest(
            body: jsonEncode({
              'error': 'Insufficient stock for ${product['name']}',
              'available': currentStock
            })
          );
        }

        double lineTotal = price * qty;
        totalAmount += lineTotal;
        
        retailProcessedItems.add({
          'itemId': id,
          'name': product['name'],
          'qty': qty,
          'price': price,
          'subtotal': lineTotal,
          'item_note': itemNote,
        });
      }

      // Verify Total Amount Integrity
      if ((totalAmount - clientTotal).abs() > 0.01) {
        debugPrint('❌ Total Amount Mismatch! Client: $clientTotal, Server: $totalAmount');
        return Response.badRequest(
          body: jsonEncode({
            'error': 'Total amount mismatch',
            'serverTotal': totalAmount,
            'clientTotal': clientTotal
          })
        );
      }

      // 2. Generate Signature using SecurityService (Centralized Logic)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final clientId = request.headers['x-client-id'] ?? 'UnknownClient';
      final detailsString = 'Sale via API from ${request.headers['user-agent'] ?? 'Unknown'}, Client: $clientId';

      final signature = await SecurityService().signTransaction(
        timestamp: timestamp,
        totalAmount: totalAmount,
        type: 'SALE',
        details: detailsString,
      );

      // 3. Emit Transaction Event (Append-Only Ledger)
      // Combine for the financial receipt
      List<Map<String, dynamic>> allProcessedItems = [];
      allProcessedItems.addAll(retailProcessedItems);
      allProcessedItems.addAll(restaurantProcessedItems.map((i) => {
         'itemId': i['menu_item_id'], 'name': i['menu_item_name'], 'qty': i['quantity'], 'price': i['unit_price'], 'subtotal': i['subtotal']
      }));

      final eventPayload = {
        'amount': totalAmount,
        'items': allProcessedItems,
        'timestamp': timestamp,
        'receiptSignature': signature,
        'source': 'API',
        'details': detailsString
      };

      final event = await EventService.emitEvent(
        eventType: 'SALE',
        payload: eventPayload,
        timestamp: timestamp
      );

      // 4. Apply to Local Stores immediately
      await EventProcessor.applyEffect(event);

      // 4b. If there are Restaurant items, alert the KDS!
      if (restaurantProcessedItems.isNotEmpty) {
         final orderNumber = 'ORD-${timestamp.toString().substring(5)}';
         final orderPayload = {
           'source_module': 'restaurant',
           'order_number': orderNumber,
           'order_type': payload['order_type'] ?? 'takeaway', // Default to takeaway
           'table_number': payload['table_number'],
           'customer_name': payload['customer_name'] ?? 'Mbeck Go User',
           'items': restaurantProcessedItems,
           'subtotal': restaurantProcessedItems.fold(0.0, (sum, i) => sum + (i['subtotal'] as double)),
           'total': restaurantProcessedItems.fold(0.0, (sum, i) => sum + (i['subtotal'] as double)),
           'status': 'pending', // Send straight to Kitchen KDS
           'created_at': timestamp,
         };
         
         final orderEvent = await EventService.emitEvent(
           eventType: 'ORDER_CREATED', 
           payload: orderPayload, 
           timestamp: timestamp
         );
         await EventProcessor.applyEffect(orderEvent);
      }

      // 5. Persist client_id so buyer can retrieve their own receipts
      try {
        await db.rawUpdate(
          'UPDATE txn SET client_id = ? WHERE cloud_id = ?',
          [clientId, event.id],
        );
      } catch (e) {
        debugPrint('⚠️ Could not persist client_id on txn: $e');
      }

      debugPrint('✅ API Checkout Success: ${event.id} for $totalAmount');

      return Response.ok(
        jsonEncode({
          'success': true,
          'transactionId': event.id,
          'signature': signature,
          'timestamp': timestamp,
          'total': totalAmount,
          'items': allProcessedItems.length
        }),
        headers: {'Content-Type': 'application/json'}
      );

    } catch (e) {
      debugPrint('❌ Checkout Failed: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Transaction failed', 'details': e.toString()})
      );
    }
  }

  Future<Response> _checkoutSyncHandler(Request request) async {
    final sync = CheckoutSyncService();
    // Normalize receipt to the compressed format expected by the buyer's
    // ReceiptService.saveScannedReceipt(): {s, t, d, sig, items[]}
    Map<String, dynamic>? normalizedReceipt;
    final raw = sync.lastReceipt;
    if (raw != null) {
      normalizedReceipt = {
        's': raw['shopId'] ?? raw['s'],
        't': raw['total'] ?? raw['t'],
        'd': raw['timestamp'] ?? raw['d'],
        'sig': raw['signature'] ?? raw['sig'],
        'items': raw['items'] ?? [],
      };
    }
    return Response.ok(
      jsonEncode({
        'status': sync.status.name,
        'receipt': normalizedReceipt,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }

  Future<Response> _checkoutAckHandler(Request request) async {
    CheckoutSyncService().updateStatus(CheckoutStatus.acknowledged);
    return Response.ok(
      jsonEncode({'success': true}),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }

  /// Handler to serve restaurant menu directly from restaurant_menu table
  Future<Response> _restaurantMenuHandler(Request request) async {
    try {
      final db = await DbProvider.db;
      final host = request.headers['host'] ?? 'localhost:8080';
      
      // Fetch directly from restaurant_menu (the module's own table)
      final items = await db.rawQuery('''
        SELECT id, name, description, price, category, image_path, 
               available, prep_time_minutes
        FROM restaurant_menu 
        WHERE available = 1
        ORDER BY category, sort_order, name
      ''');
      
      final menuItems = items.map((item) {
         final imagePath = item['image_path'] as String?;
         final imageUrl = imagePath != null && imagePath.isNotEmpty
             ? 'http://$host/api/v1/images/${path.basename(imagePath)}'
             : null;
             
         return {
           'id': item['id'],
           'name': item['name'],
           'description': item['description'] ?? '',
           'price': item['price'],
           'category': item['category'],
           'image_path': imageUrl,
           'available': item['available'],
           'prep_time_minutes': item['prep_time_minutes'] ?? 15,
         };
      }).toList();
      
      return Response.ok(
        jsonEncode({
          'menu': menuItems,
          'count': menuItems.length
        }),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// Handler to serve services catalog (fallback)
  Future<Response> _serviceCatalogHandler(Request request) async {
    try {
      final db = await DbProvider.db;
      final host = request.headers['host'] ?? 'localhost:8080';
      
      // Fetch services from services_catalog table
      // After migration v24, column is `is_active`
      final items = await db.rawQuery('''
        SELECT sc.id, sc.name, sc.category, sc.price, sc.duration_minutes, 
               sc.description, sc.image_path, sc.is_active
        FROM services_catalog sc
        WHERE sc.is_active = 1
        ORDER BY sc.category, sc.name
      ''');
      
      final services = items.map((item) {
         final imagePath = item['image_path'] as String?;
         final imageUrl = imagePath != null && imagePath.isNotEmpty
             ? 'http://$host/api/v1/images/${path.basename(imagePath)}'
             : null;
             
         return {
           'id': item['id'],
           'name': item['name'],
           'description': item['description'] ?? '',
           'price': item['price'],
           'category': item['category'],
           'duration_minutes': item['duration_minutes'] ?? 30,
           'image_path': imageUrl,
           'active': (item['is_active'] as int) == 1 ? 1 : 0,
         };
      }).toList();
      
      return Response.ok(
        jsonEncode({
          'catalog': services,
          'count': services.length
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// Services availability — returns open time slots for a service on a given date.
  /// GET /api/v1/services/availability?service_id=X&date=YYYY-MM-DD
  Future<Response> _servicesAvailabilityHandler(Request request) async {
    try {
      final params = request.requestedUri.queryParameters;
      final serviceId = params['service_id'];
      final dateStr = params['date'];
      if (serviceId == null || dateStr == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Missing service_id or date'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final db = await DbProvider.db;

      // Fetch service duration + buffer
      final svc = await db.rawQuery(
        'SELECT duration_minutes, buffer_minutes FROM services_catalog WHERE id = ? AND is_active = 1',
        [int.tryParse(serviceId) ?? 0],
      );
      if (svc.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Service not found'}),
            headers: {'Content-Type': 'application/json'});
      }
      final duration = (svc.first['duration_minutes'] as num?)?.toInt() ?? 30;
      final buffer = (svc.first['buffer_minutes'] as num?)?.toInt() ?? 0;
      final slotMinutes = duration + buffer;

      // Parse YYYY-MM-DD
      final parts = dateStr.split('-');
      if (parts.length < 3) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Invalid date format. Use YYYY-MM-DD'}),
        );
      }
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      final dayStartMs = DateTime(year, month, day, 9, 0).millisecondsSinceEpoch;
      final dayEndMs = DateTime(year, month, day, 17, 0).millisecondsSinceEpoch;

      // Existing confirmed bookings for this service on this day
      final existing = await db.rawQuery('''
        SELECT start_time, end_time FROM services_bookings
        WHERE service_id = ? AND status NOT IN ('cancelled')
          AND start_time >= ? AND start_time < ?
      ''', [serviceId, dayStartMs, dayEndMs]);

      // Generate candidate slots every slotMinutes from 09:00–17:00
      final List<String> available = [];
      var cursor = DateTime(year, month, day, 9, 0);
      final endOfDay = DateTime(year, month, day, 17, 0);

      while (cursor.isBefore(endOfDay)) {
        final slotEnd = cursor.add(Duration(minutes: slotMinutes));
        if (slotEnd.isAfter(endOfDay)) break;

        final slotStartMs = cursor.millisecondsSinceEpoch;
        final slotEndMs = slotEnd.millisecondsSinceEpoch;

        final overlaps = existing.any((b) {
          final bStart = (b['start_time'] as num?)?.toInt() ?? 0;
          final bEnd = (b['end_time'] as num?)?.toInt() ?? 0;
          return bStart < slotEndMs && bEnd > slotStartMs;
        });

        if (!overlaps) {
          available.add(
            '${cursor.hour.toString().padLeft(2, '0')}:${cursor.minute.toString().padLeft(2, '0')}',
          );
        }
        cursor = cursor.add(Duration(minutes: slotMinutes));
      }

      return Response.ok(
        jsonEncode({'slots': available, 'date': dateStr, 'service_id': serviceId}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      debugPrint('⚠️ _servicesAvailabilityHandler error: $e');
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// Services booking — accepts a new appointment from the buyer app.
  /// POST /api/v1/services/book
  /// Body JSON: {service_id, customer_name, customer_phone, start_time (ms), end_time (ms), notes}
  Future<Response> _servicesBookingHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final payload = jsonDecode(body) as Map<String, dynamic>;

      final serviceId = payload['service_id'];
      final customerName = payload['customer_name'] as String? ?? 'Customer';
      final customerPhone = payload['customer_phone'] as String? ?? '';
      final startTimeMs = (payload['start_time'] as num?)?.toInt();
      final endTimeMs = (payload['end_time'] as num?)?.toInt();
      final notes = payload['notes'] as String? ?? '';

      if (serviceId == null || startTimeMs == null || endTimeMs == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Missing required fields: service_id, start_time, end_time'}),
        );
      }

      final db = await DbProvider.db;

      // Conflict check
      final conflicts = await db.rawQuery('''
        SELECT id FROM services_bookings
        WHERE service_id = ? AND status NOT IN ('cancelled')
          AND start_time < ? AND end_time > ?
      ''', [serviceId, endTimeMs, startTimeMs]);

      if (conflicts.isNotEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'This time slot is no longer available. Please choose another.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final cloudId = Uuid().v4();
      
      final bookingPayload = {
        'cloud_id': cloudId,
        'source_module': 'services',
        'service_id': serviceId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'start_time': startTimeMs,
        'end_time': endTimeMs,
        'status': 'pending',
        'notes': notes,
      };

      // Emit event so the whole shop system is updated
      final bookingEvent = await EventService.emitEvent(
        eventType: 'BOOKING_CREATED', 
        payload: bookingPayload, 
        timestamp: now
      );
      
      // Process event locally to insert into services_bookings
      await EventProcessor.applyEffect(bookingEvent);

      // Query auto-generated ID to return
      final result = await db.query(
        'services_bookings',
        columns: ['id'],
        where: 'cloud_id = ?',
        whereArgs: [cloudId],
        limit: 1,
      );
      final bookingId = result.isNotEmpty ? result.first['id'] as int : -1;

      debugPrint('📅 Buyer booking created: #$bookingId for service $serviceId by $customerName');

      return Response.ok(
        jsonEncode({'success': true, 'booking_id': bookingId}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      debugPrint('⚠️ _servicesBookingHandler error: $e');
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// Serve the shop cover/banner image
  Future<Response> _shopImageHandler(Request request) async {
    try {
      final db = await DbProvider.db;
      final shopData = await db.rawQuery('SELECT theme_config FROM shops LIMIT 1');
      
      if (shopData.isNotEmpty && shopData.first['theme_config'] != null) {
        final themeJson = jsonDecode(shopData.first['theme_config'] as String);
        final coverImageUrl = themeJson['cover_image_url'] as String?;
        
        if (coverImageUrl != null && coverImageUrl.isNotEmpty && !coverImageUrl.startsWith('http')) {
          // It's a local filename — serve the file
          final directory = await getApplicationDocumentsDirectory();
          final imagePath = path.join(directory.path, path.basename(coverImageUrl));
          final file = File(imagePath);
          
          if (await file.exists()) {
            final length = await file.length();
            final ext = path.extension(imagePath).toLowerCase();
            String contentType = 'image/jpeg';
            if (ext == '.png') contentType = 'image/png';
            if (ext == '.webp') contentType = 'image/webp';
            
            return Response.ok(file.openRead(), headers: {
              'Content-Type': contentType,
              'Content-Length': '$length',
              'Access-Control-Allow-Origin': '*',
              'Cache-Control': 'public, max-age=3600',
            });
          }
        }
      }
      
      return Response.notFound(
        jsonEncode({'error': 'No shop image set'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('⚠️ Error serving shop image: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _performanceHandler(Request request) async {
    return Response.ok(
      jsonEncode(PerformanceMonitor().getReport()),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }

  /// Entertainment assets endpoint - public browsing for buyer app
  Future<Response> _entertainmentAssetsHandler(Request request) async {
    try {
      final db = await DbProvider.db;
      final assets = await db.rawQuery('''
        SELECT ea.id, ea.name, ea.category, ea.asset_type, ea.rate_per_hour, 
               ea.flat_rate, ea.description, ea.is_active,
               (SELECT COUNT(*) FROM entertainment_sessions es 
                WHERE es.asset_id = ea.id AND es.status = 'active') as active_sessions
        FROM entertainment_assets ea
        WHERE ea.is_active = 1
        ORDER BY ea.category, ea.sort_order, ea.name
      ''');

      return Response.ok(
        jsonEncode({'assets': assets, 'count': assets.length}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Lodging rooms endpoint - public browsing for buyer app
  /// Supports optional ?typeId=X filter to get rooms of a specific type
  Future<Response> _lodgingRoomsHandler(Request request) async {
    try {
      final db = await DbProvider.db;
      final host = request.headers['host'] ?? 'localhost:8080';
      final typeId = request.requestedUri.queryParameters['typeId'];

      String query;
      List<dynamic> args;
      if (typeId != null) {
        query = '''
          SELECT lr.id, lr.name, lr.room_type, lr.room_type_id, lr.floor, lr.capacity, 
                 lr.rate_per_night, lr.amenities, lr.description, lr.status, 
                 lr.is_active, lr.image_path
          FROM lodging_rooms lr
          WHERE lr.is_active = 1 AND lr.room_type_id = ?
          ORDER BY lr.sort_order, lr.name
        ''';
        args = [int.tryParse(typeId) ?? 0];
      } else {
        query = '''
          SELECT lr.id, lr.name, lr.room_type, lr.room_type_id, lr.floor, lr.capacity, 
                 lr.rate_per_night, lr.amenities, lr.description, lr.status, 
                 lr.is_active, lr.image_path
          FROM lodging_rooms lr
          WHERE lr.is_active = 1
          ORDER BY lr.sort_order, lr.name
        ''';
        args = [];
      }

      final rooms = await db.rawQuery(query, args);

      // Add full image URLs
      final enrichedRooms = rooms.map((room) {
        final imagePath = room['image_path'] as String?;
        final imageUrl = (imagePath != null && imagePath.isNotEmpty)
            ? 'http://$host/api/v1/images/${path.basename(imagePath)}'
            : null;
        return <String, dynamic>{
          ...room,
          'image_url': imageUrl,
        };
      }).toList();

      return Response.ok(
        jsonEncode({'rooms': enrichedRooms, 'count': enrichedRooms.length}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Lodging room types endpoint - returns room types with images and availability
  /// Used by buyer app to show room type catalog with image galleries
  Future<Response> _lodgingRoomTypesHandler(Request request) async {
    try {
      final db = await DbProvider.db;
      final host = request.headers['host'] ?? 'localhost:8080';

      // Fetch room types with available/total room counts
      final types = await db.rawQuery('''
        SELECT rt.id, rt.name, rt.description, rt.capacity, 
               rt.rate_per_night, rt.amenities, rt.is_active,
               (SELECT COUNT(*) FROM lodging_rooms lr 
                WHERE lr.room_type_id = rt.id AND lr.is_active = 1) as total_rooms,
               (SELECT COUNT(*) FROM lodging_rooms lr 
                WHERE lr.room_type_id = rt.id AND lr.is_active = 1 
                AND lr.status = 'available') as available_rooms
        FROM lodging_room_types rt
        WHERE rt.is_active = 1
        ORDER BY rt.name
      ''');

      // Fetch images for each room type
      final enrichedTypes = <Map<String, dynamic>>[];
      for (final type in types) {
        final typeId = type['id'];
        final images = await db.rawQuery('''
          SELECT id, image_path, caption, sort_order
          FROM lodging_room_type_images
          WHERE room_type_id = ?
          ORDER BY sort_order
        ''', [typeId]);

        final imageList = images.map((img) {
          final imgPath = img['image_path'] as String?;
          final imgUrl = (imgPath != null && imgPath.isNotEmpty)
              ? 'http://$host/api/v1/images/${path.basename(imgPath)}'
              : null;
          return <String, dynamic>{
            'id': img['id'],
            'url': imgUrl,
            'caption': img['caption'],
          };
        }).toList();

        enrichedTypes.add({
          'id': type['id'],
          'name': type['name'],
          'description': type['description'],
          'capacity': type['capacity'],
          'rate_per_night': type['rate_per_night'],
          'amenities': type['amenities'],
          'total_rooms': type['total_rooms'],
          'available_rooms': type['available_rooms'],
          'images': imageList,
        });
      }

      return Response.ok(
        jsonEncode({'roomTypes': enrichedTypes, 'count': enrichedTypes.length}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Order ping - buyer signals they have selected items and are ready
  /// Body: {"items": [...], "tableNumber": "5", "customerName": "John", "module": "restaurant", "note": "no onions"}
  Future<Response> _orderPingHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final payload = jsonDecode(body) as Map<String, dynamic>;
      
      final module = payload['module'] as String? ?? 'restaurant';
      final tableNumber = payload['tableNumber'] as String? ?? '';
      final customerName = payload['customerName'] as String? ?? 'Customer';
      // clientId identifies the buyer device — used to match the created order
      // back to the buyer for active-order tracking.
      final clientId = payload['clientId'] as String?
          ?? request.headers['x-client-id']
          ?? '';
      final items = payload['items'] as List<dynamic>? ?? [];
      final note = payload['note'] as String? ?? '';
      
      // Store the ping in a lightweight in-memory queue or DB
      // For now, emit as an event that the seller app can listen to
      final pingPayload = {
        'module': module,
        'tableNumber': tableNumber,
        'customerName': customerName,
        'clientId': clientId,
        'items': items,
        'note': note,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'source': 'buyer_app',
      };
      
      await EventService.emitEvent(
        eventType: 'ORDER_PING',
        payload: pingPayload,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      
      // Push ring into live in-memory queue for real-time UI updates
      WaiterRingService.instance.addRing(
        eventId: '${DateTime.now().millisecondsSinceEpoch}',
        module: module,
        tableNumber: tableNumber,
        customerName: customerName,
        clientId: clientId,
        items: items,
        note: note,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );
      
      return Response.ok(
        jsonEncode({'success': true, 'message': 'Order ping sent to staff'}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handles local restaurant order placements from the buyer app.
  /// POST /api/v1/restaurant/orders
  Future<Response> _restaurantOrdersPostHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final payload = jsonDecode(body) as Map<String, dynamic>;
      
      final clientId = request.headers['x-client-id'] ?? payload['client_id'] ?? '';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final orderNumber = 'ORD-${timestamp.toString().substring(5)}';
      
      final orderPayload = {
        'source_module': 'restaurant',
        'order_number': orderNumber,
        'order_type': payload['order_type'] ?? 'takeaway',
        'table_number': payload['table_number']?.toString(),
        'customer_name': payload['customer_name'] ?? 'Mbeck Go User',
        'customer_phone': payload['customer_phone'] ?? '',
        'items_json': jsonEncode(payload['items']),
        'items': payload['items'],
        'subtotal': payload['grand_total'],
        'total': payload['grand_total'],
        'status': 'pending',
        'notes': payload['customer_note'] ?? '',
        'created_at': timestamp,
        'client_id': clientId,
      };

      // Emit event so the kitchen queue and all follow terminals sync
      final orderEvent = await EventService.emitEvent(
        eventType: 'ORDER_CREATED', 
        payload: orderPayload, 
        timestamp: timestamp
      );
      
      // Process event locally to insert into restaurant_orders and restaurant_order_items
      await EventProcessor.applyEffect(orderEvent);

      return Response.ok(
        jsonEncode({
          'success': true, 
          'order_number': orderNumber, 
          'message': 'Order placed successfully'
        }),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      debugPrint('⚠️ _restaurantOrdersPostHandler error: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Fetches active restaurant orders or specific order statuses.
  /// GET /api/v1/restaurant/orders/status
  Future<Response> _restaurantOrdersStatusHandler(Request request) async {
    try {
      final db = await DbProvider.db;
      final queryParams = request.requestedUri.queryParameters;
      final orderNumber = queryParams['order_number'];
      final clientId = request.headers['x-client-id'] ?? queryParams['client_id'];

      List<Map<String, dynamic>> orders;
      if (orderNumber != null) {
        orders = await db.rawQuery('''
          SELECT id, order_number, table_number, status, order_type, total, total_amount, created_at, preparing_by, ready_by, served_by
          FROM restaurant_orders
          WHERE order_number = ?
        ''', [orderNumber]);
      } else if (clientId != null) {
        orders = await db.rawQuery('''
          SELECT id, order_number, table_number, status, order_type, total, total_amount, created_at, preparing_by, ready_by, served_by
          FROM restaurant_orders
          WHERE client_id = ? AND status NOT IN ('completed', 'cancelled')
          ORDER BY created_at DESC
        ''', [clientId]);
      } else {
        return Response.badRequest(
          body: jsonEncode({'error': 'Missing client ID or order number'}),
          headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
        );
      }

      return Response.ok(
        jsonEncode({
          'orders': orders,
          'count': orders.length,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      debugPrint('⚠️ _restaurantOrdersStatusHandler error: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Receipt endpoint - fetch receipt by transaction ID
  Future<Response> _receiptHandler(Request request, String txnId) async {
    try {
      final db = await DbProvider.db;
      
      // Search by ID, signature, or cloud_id (UUID)
      final results = await db.rawQuery('''
        SELECT id, type, totalAmount, details, timestamp, receiptSignature, source_module
        FROM txn 
        WHERE id = ? OR receiptSignature = ? OR cloud_id = ?
        LIMIT 1
      ''', [int.tryParse(txnId) ?? -1, txnId, txnId]);
      
      if (results.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Receipt not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      final txn = results.first;
      final shop = await AuthService.getCurrentShop();
      
      return Response.ok(
        jsonEncode({
          'receipt': {
            'transactionId': txn['id'],
            'type': txn['type'],
            'amount': txn['totalAmount'],
            'details': txn['details'],
            'timestamp': txn['timestamp'],
            'signature': txn['receiptSignature'],
            'sourceModule': txn['source_module'],
            'shopName': shop?.businessName ?? 'Shop',
            'shopId': shop?.id ?? '',
            'currency': 'KES',
          },
        }),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Active Orders (Live Tracking for Buyer App)
  Future<Response> _activeOrdersHandler(Request request) async {
    try {
      final clientId = request.headers['x-client-id'];
      if (clientId == null) return Response.badRequest(body: jsonEncode({'error': 'Missing client ID'}));

      final db = await DbProvider.db;
      
      // Fetch active restaurant orders for this client using the persisted client_id column
      final orders = await db.rawQuery('''
        SELECT id, order_number, table_number, status, order_type, total_amount, created_at, preparing_by, ready_by 
        FROM restaurant_orders 
        WHERE client_id = ? AND status NOT IN ('completed', 'cancelled')
        ORDER BY created_at DESC
      ''', [clientId]);

      return Response.ok(
        jsonEncode({
          'orders': orders,
          'count': orders.length,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Buyer Receipts (History for Buyer App)
  Future<Response> _buyerReceiptsHandler(Request request) async {
    try {
      final clientId = request.headers['x-client-id'];
      if (clientId == null) return Response.badRequest(body: jsonEncode({'error': 'Missing client ID'}));

      final db = await DbProvider.db;
      final shop = await AuthService.getCurrentShop();
      
      // Query using the dedicated client_id column (populated by _checkoutHandler).
      final receipts = await db.rawQuery('''
        SELECT id as transactionId, type, totalAmount as amount, details, timestamp, receiptSignature as signature, source_module as sourceModule
        FROM txn 
        WHERE client_id = ?
        ORDER BY timestamp DESC
        LIMIT 50
      ''', [clientId]);

      final mappedReceipts = receipts.map((r) => {
        ...r,
        'shopName': shop?.businessName ?? 'Shop',
        'currency': 'KES',
      }).toList();

      return Response.ok(
        jsonEncode({
          'receipts': mappedReceipts,
          'count': mappedReceipts.length,
        }),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Services staff list - public for buyer app booking
  Future<Response> _servicesStaffHandler(Request request) async {
    try {
      final db = await DbProvider.db;
      final staff = await db.rawQuery('''
        SELECT id, name, role, available_days, work_hours_start, work_hours_end
        FROM services_staff
        WHERE active = 1
        ORDER BY name
      ''');

      return Response.ok(
        jsonEncode({'staff': staff, 'count': staff.length}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
  /// LAN Event Sync - Employee devices periodically pull missing events from leader
  Future<Response> _eventSyncHandler(Request request) async {
    try {
      final sinceParam = request.requestedUri.queryParameters['since'];
      final since = int.tryParse(sinceParam ?? '0') ?? 0;
      
      final db = await DbProvider.db;
      final events = await db.rawQuery('''
        SELECT * FROM events 
        WHERE timestamp > ? 
        ORDER BY timestamp ASC 
        LIMIT 500
      ''', [since]);
      
      final formattedEvents = events.map((eventMap) {
        final mutableEvent = Map<String, dynamic>.from(eventMap);
        if (mutableEvent['payload'] is String) {
           mutableEvent['payload'] = jsonDecode(mutableEvent['payload'] as String);
        }
        return mutableEvent;
      }).toList();

      return Response.ok(
        jsonEncode({
          'events': formattedEvents,
          'count': formattedEvents.length,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      debugPrint('⚠️ Error in event sync handler: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// LAN Event Push - Employee devices periodically push missing events to leader
  Future<Response> _eventPushHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final eventsList = data['events'] as List<dynamic>? ?? [];
      
      if (eventsList.isEmpty) {
         return Response.ok(jsonEncode({'success': true}));
      }

      int processedCount = 0;
      for (final eventJson in eventsList) {
         try {
            final eventMap = Map<String, dynamic>.from(eventJson as Map);
            final event = Event.fromMap(eventMap);
            if (event.verifyIntegrity()) {
               final applied = await EventProcessor.processEvent(event);
               if (applied) processedCount++;
            }
         } catch(e) { /* ignore single event error */ }
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'processed': processedCount,
        }),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      debugPrint('⚠️ Error in event push handler: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // ─── GAP 4: LODGING RESERVATION ────────────────────────────────────────────

  /// Accepts a room reservation from the buyer app.
  /// POST /api/v1/lodging/book
  /// Body: {room_id, guest_name, guest_phone, check_in_date (YYYY-MM-DD),
  ///        check_out_date (YYYY-MM-DD), notes}
  Future<Response> _lodgingBookHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final p = jsonDecode(body) as Map<String, dynamic>;

      final roomId = (p['room_id'] as num?)?.toInt();
      final guestName = p['guest_name'] as String? ?? 'Guest';
      final guestPhone = p['guest_phone'] as String? ?? '';
      final checkInStr = p['check_in_date'] as String?;
      final checkOutStr = p['check_out_date'] as String?;
      final notes = p['notes'] as String? ?? '';
      final clientId = request.headers['x-client-id'] ?? '';

      if (roomId == null || checkInStr == null || checkOutStr == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Missing required fields: room_id, check_in_date, check_out_date'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      DateTime checkIn, checkOut;
      try {
        checkIn = DateTime.parse(checkInStr);
        checkOut = DateTime.parse(checkOutStr);
      } catch (_) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Invalid date format. Use YYYY-MM-DD'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (!checkOut.isAfter(checkIn)) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Check-out date must be after check-in date'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final nights = checkOut.difference(checkIn).inDays;
      final db = await DbProvider.db;

      // Fetch room + rate
      final roomResult = await db.rawQuery(
        'SELECT lr.id, lr.status, lrt.rate_per_night FROM lodging_rooms lr '
        'LEFT JOIN lodging_room_types lrt ON lr.room_type_id = lrt.id '
        'WHERE lr.id = ?',
        [roomId],
      );
      if (roomResult.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Room not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      final room = roomResult.first;
      if ((room['status'] as String?) != 'available') {
        return Response.badRequest(
          body: jsonEncode({'error': 'Room is not available'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Conflict check: overlapping confirmed reservations
      final checkInMs = checkIn.millisecondsSinceEpoch;
      final checkOutMs = checkOut.millisecondsSinceEpoch;
      final conflicts = await db.rawQuery('''
        SELECT id FROM lodging_reservations
        WHERE room_id = ? AND status NOT IN ('cancelled', 'checked_out')
          AND check_in_date < ? AND check_out_date > ?
      ''', [roomId, checkOutMs, checkInMs]);
      if (conflicts.isNotEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Room is already booked for those dates'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final rate = (room['rate_per_night'] as num?)?.toDouble() ?? 0;
      final totalAmount = rate * nights;
      final now = DateTime.now().millisecondsSinceEpoch;

      final reservationId = await db.insert('lodging_reservations', {
        'cloud_id': Uuid().v4(),
        'room_id': roomId,
        'guest_name': guestName,
        'guest_phone': guestPhone,
        'check_in_date': checkInMs,
        'check_out_date': checkOutMs,
        'nights': nights,
        'rate_per_night': rate,
        'extras_total': 0.0,
        'total_amount': totalAmount,
        'amount_paid': 0.0,
        'status': 'pending',
        'notes': notes,
        'client_id': clientId,
        'source_module': 'lodging',
        'created_at': now,
        'updated_at': now,
      });

      // Mark room as reserved
      await db.update(
        'lodging_rooms',
        {'status': 'reserved', 'updated_at': now},
        where: 'id = ?',
        whereArgs: [roomId],
      );

      debugPrint('🏨 Buyer reservation created: #$reservationId room $roomId by $guestName');

      return Response.ok(
        jsonEncode({'success': true, 'reservation_id': reservationId, 'total_amount': totalAmount}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      debugPrint('⚠️ _lodgingBookHandler error: $e');
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// Fetch all lodging reservations for a client.
  /// GET /api/v1/lodging/reservations
  Future<Response> _lodgingReservationsHandler(Request request) async {
    try {
      final clientId = request.headers['x-client-id'];
      if (clientId == null || clientId.isEmpty) {
        return Response.badRequest(body: jsonEncode({'error': 'Missing x-client-id header'}));
      }
      final db = await DbProvider.db;
      final reservations = await db.rawQuery('''
        SELECT lr.id, lr.room_id, lr.guest_name, lr.guest_phone, lr.check_in_date, 
               lr.check_out_date, lr.nights, lr.rate_per_night, lr.total_amount, 
               lr.amount_paid, lr.status, lr.notes, lr.created_at,
               room.name as room_name, room.room_type, room.image_path as room_image_path
        FROM lodging_reservations lr
        LEFT JOIN lodging_rooms room ON lr.room_id = room.id
        WHERE lr.client_id = ?
        ORDER BY lr.created_at DESC
      ''', [clientId]);

      final host = request.headers['host'] ?? 'localhost:8080';
      final enrichedReservations = reservations.map((res) {
        final imagePath = res['room_image_path'] as String?;
        final imageUrl = (imagePath != null && imagePath.isNotEmpty)
            ? 'http://$host/api/v1/images/${path.basename(imagePath)}'
            : null;
        return <String, dynamic>{
          ...res,
          'room': {
            'id': res['room_id'],
            'name': res['room_name'],
            'room_type': res['room_type'],
            'image_url': imageUrl,
          }
        };
      }).toList();

      return Response.ok(
        jsonEncode({'reservations': enrichedReservations}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // ─── GAP 4: ENTERTAINMENT BOOKING ──────────────────────────────────────────

  /// Starts an entertainment session from the buyer app.
  /// POST /api/v1/entertainment/book
  /// Body: {asset_id, customer_name, notes}
  Future<Response> _entertainmentBookHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final p = jsonDecode(body) as Map<String, dynamic>;

      final assetId = (p['asset_id'] as num?)?.toInt();
      final customerName = p['customer_name'] as String? ?? 'Customer';
      final notes = p['notes'] as String? ?? '';
      final clientId = request.headers['x-client-id'] ?? '';

      if (assetId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Missing required field: asset_id'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final db = await DbProvider.db;

      // Confirm asset exists and is not already in an active session
      final assetResult = await db.rawQuery(
        'SELECT id, asset_type, rate_per_hour, flat_rate FROM entertainment_assets WHERE id = ? AND is_active = 1',
        [assetId],
      );
      if (assetResult.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Asset not found'}));
      }

      final activeSessions = await db.rawQuery(
        "SELECT id FROM entertainment_sessions WHERE asset_id = ? AND status IN ('active', 'paused')",
        [assetId],
      );
      if (activeSessions.isNotEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'This asset is currently in use. Please choose another.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final asset = assetResult.first;
      final billingType = asset['asset_type'] as String? ?? 'hourly';
      final rate = billingType == 'flat'
          ? (asset['flat_rate'] as num?)?.toDouble() ?? 0
          : (asset['rate_per_hour'] as num?)?.toDouble() ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final cloudId = Uuid().v4();
      
      final sessionPayload = {
        'cloud_id': cloudId,
        'source_module': 'entertainment',
        'asset_id': assetId,
        'customer_name': customerName,
        'client_id': clientId,
        'started_at': now,
        'billing_type': billingType,
        'rate': rate,
        'status': 'active',
        'notes': notes,
      };

      // Emit event
      final sessionEvent = await EventService.emitEvent(
        eventType: 'ENTERTAINMENT_SESSION_START', 
        payload: sessionPayload, 
        timestamp: now
      );
      
      // Process event locally
      await EventProcessor.applyEffect(sessionEvent);

      // Query auto-generated ID to return
      final result = await db.query(
        'entertainment_sessions',
        columns: ['id'],
        where: 'cloud_id = ?',
        whereArgs: [cloudId],
        limit: 1,
      );
      final sessionId = result.isNotEmpty ? result.first['id'] as int : -1;

      debugPrint('🎮 Buyer entertainment session started: #$sessionId asset $assetId by $customerName');

      return Response.ok(
        jsonEncode({'success': true, 'session_id': sessionId}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      debugPrint('⚠️ _entertainmentBookHandler error: $e');
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // ─── GAP 5: MESSAGING ──────────────────────────────────────────────────────



  /// GET /api/v1/messages — fetch all messages for a client
  /// Requires x-client-id header. Returns messages ordered newest-first.
  Future<Response> _messagesGetHandler(Request request) async {
    try {
      final clientId = request.headers['x-client-id'];
      if (clientId == null || clientId.isEmpty) {
        return Response.badRequest(body: jsonEncode({'error': 'Missing x-client-id header'}));
      }
      final db = await DbProvider.db;
      final rows = await db.rawQuery(
        'SELECT id, sender, content, timestamp, read FROM messages WHERE client_id = ? ORDER BY timestamp ASC',
        [clientId],
      );
      return Response.ok(
        jsonEncode({'messages': rows, 'count': rows.length}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// POST /api/v1/messages — send a message (buyer → shop)
  /// Body: {content}. Requires x-client-id header.
  Future<Response> _messagesPostHandler(Request request) async {
    try {
      final clientId = request.headers['x-client-id'];
      if (clientId == null || clientId.isEmpty) {
        return Response.badRequest(body: jsonEncode({'error': 'Missing x-client-id header'}));
      }
      final body = await request.readAsString();
      final p = jsonDecode(body) as Map<String, dynamic>;
      final content = p['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        return Response.badRequest(body: jsonEncode({'error': 'Message content cannot be empty'}));
      }
      final db = await DbProvider.db;
      final id = await db.insert('messages', {
        'client_id': clientId,
        'sender': 'buyer',
        'content': content.trim(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'read': 0,
      });
      debugPrint('💬 New buyer message #$id from $clientId');
      return Response.ok(
        jsonEncode({'success': true, 'message_id': id}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// PATCH /api/v1/messages/read — mark all shop messages to this client as read
  /// Requires x-client-id header.
  Future<Response> _messagesMarkReadHandler(Request request) async {
    try {
      final clientId = request.headers['x-client-id'];
      if (clientId == null || clientId.isEmpty) {
        return Response.badRequest(body: jsonEncode({'error': 'Missing x-client-id header'}));
      }
      final db = await DbProvider.db;
      await db.rawUpdate(
        "UPDATE messages SET read = 1 WHERE client_id = ? AND sender = 'shop' AND read = 0",
        [clientId],
      );
      return Response.ok(
        jsonEncode({'success': true}),
        headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }
}
