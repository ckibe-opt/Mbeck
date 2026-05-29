import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import '../lib/server/local_server.dart'; // Adjust path if needed
import '../lib/db/db_provider.dart';
import '../lib/models/inventory_items.dart'; // Adjust path if needed
import 'package:mbeck_modules/mbeck_modules.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Data Integrity & Contract Tests', () {
    String? baseUrl;
    late DbProvider dbProvider;

    setUpAll(() async {
      // 1. Init Supabase (Mock)
      try {
        await Supabase.initialize(
          url: 'https://example.supabase.co',
          anonKey: 'dummy',
        );
      } catch (_) {}

      // 2. Init DB & Modules
      await DbProvider.db; // Trigger init
      
      if (ModuleRegistry.instance.allModules.isEmpty) {
        ModuleRegistry.instance.registerAll([RetailModule()]);
      }

      // 3. Start Server
      await ShopServer.start();
      await Future.delayed(const Duration(seconds: 1));
      
      final ip = ShopServer.ipAddress ?? '127.0.0.1';
      baseUrl = 'http://$ip:${ShopServer.port}/api/v1';

      // 4. Seed Data
      await DbProvider.insert('inventory', {
        'name': 'Test Item Integrity',
        'sellingPrice': 100.0,
        'originalPrice': 120.0,
        'stock': 50,
        'variationsJson': '[{"name":"Size:L","priceModifier":10,"stock":5}]',
        'category': 'Test',
      });
    });

    tearDownAll(() async {
      await ShopServer.stop();
    });

    // --- CONTRACT TEST 1: INVENTORY SCHEMA ---
    test('GET /inventory/public respects schema contract', () async {
      final response = await http.get(Uri.parse('$baseUrl/inventory/public'));
      expect(response.statusCode, 200);

      final json = jsonDecode(response.body);
      final List data = json['data'];
      expect(data, isNotEmpty);

      final item = data.firstWhere((e) => e['name'] == 'Test Item Integrity');
      
      // Verify Schema Fields
      expect(item['price'], 100.0);
      expect(item['originalPrice'], 120.0, reason: 'Missing originalPrice in API response');
      expect(item['variationsJson'], isNotNull, reason: 'Missing variationsJson');
      
      // Verify Variations Structure (if parsed by client, but API returns string)
      // The API returns the raw JSON string or parsed object? 
      // Based on InventoryController, it likely returns whatever is in toMap().
      // Let's verify it's present.
    });

    // --- CONTRACT TEST 2: CHECKOUT VALIDATION ---
    test('POST /cart/checkout enforces Total Amount Integrity', () async {
      // Get an item ID
      final items = await DbProvider.query('inventory', where: 'name = ?', whereArgs: ['Test Item Integrity']);
      final itemId = items.first['id'];

      // Construct Payload with WRONG total
      final payload = {
        'items': [
          {'itemId': itemId, 'qty': 1, 'price': 100.0, 'name': 'Test Item Integrity'}
        ],
        'totalAmount': 50.0, // <--- DELIBERATE MISMATCH (Should be 100)
        'meta': 'test check'
      };

      // We need a session token? 
      // ShopServer might be open or require auth. 
      // Check ApiAuthMiddleware. usually /cart/checkout is protected.
      // Let's get a token first.
      final infoRes = await http.get(Uri.parse('$baseUrl/info'));
      final token = jsonDecode(infoRes.body)['sessionToken'];

      final response = await http.post(
        Uri.parse('$baseUrl/cart/checkout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(payload),
      );

      // SHOULD FAIL
      expect(response.statusCode, 400, reason: 'Server accepted invalid total amount');
      expect(response.body, contains('Total amount mismatch')); 
      // Note: If server logic doesn't check this yet, this test will fail (which is good!)
    });

    test('POST /cart/checkout enforces Stock Limits', () async {
      final items = await DbProvider.query('inventory', where: 'name = ?', whereArgs: ['Test Item Integrity']);
      final itemId = items.first['id'];

      // Construct Payload with quantity > stock (50)
      final payload = {
        'items': [
          {'itemId': itemId, 'qty': 1000, 'price': 100.0, 'name': 'Test Item Integrity'}
        ],
        'totalAmount': 100000.0, 
        'meta': 'stock check'
      };

      final infoRes = await http.get(Uri.parse('$baseUrl/info'));
      final token = jsonDecode(infoRes.body)['sessionToken'];

      final response = await http.post(
        Uri.parse('$baseUrl/cart/checkout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(payload),
      );

      print('Checkout Response: ${response.statusCode} - ${response.body}');
      expect(response.statusCode, 400, reason: 'Server accepted out-of-stock order. Response: ${response.body}');
      expect(response.body, contains('Stock'));
    });
  });
}
