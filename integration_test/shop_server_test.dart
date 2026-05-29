import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import '../lib/db/db_provider.dart';
import '../lib/server/local_server.dart';
import '../lib/services/module_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mbeck_modules/mbeck_modules.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Shop Server Integration Tests', () {
    String? baseUrl;
    late int testItemId;

    setUpAll(() async {
      // 1. Initialize Supabase
      const supabaseUrl = 'https://example.supabase.co';
      const supabaseAnonKey = 'dummy-key';
      try {
        await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      } catch (e) { /* Ignore */ }

      // 2. Register Modules
      if (ModuleRegistry.instance.allModules.isEmpty) {
        ModuleRegistry.instance.registerAll([RetailModule(), RestaurantModule(), ServicesModule()]);
      }

      // 3. Seed Test Data for Checkout
      final db = await DbProvider.db;
      // Clear previous test items to be safe
      await db.delete('inventory', where: 'name = ?', whereArgs: ['Integration Test Item']);
      
      testItemId = await db.insert('inventory', {
        'name': 'Integration Test Item',
        'category': 'Test',
        'sellingPrice': 100.0,
        'originalPrice': 80.0,
        'stock': 50,
        'specification': 'Test Spec'
      });

      // 4. Start Server
      await ShopServer.start();
      await Future.delayed(const Duration(seconds: 1));
      
      final ip = ShopServer.ipAddress ?? '127.0.0.1';
      final port = ShopServer.port;
      baseUrl = 'http://$ip:$port/api/v1';
      debugPrint('🧪 Test Server running at $baseUrl');
    });

    tearDownAll(() async {
      await ShopServer.stop();
    });

    // --- Baselines ---
    test('GET /status returns 200', () async {
      final response = await http.get(Uri.parse('$baseUrl/status'));
      expect(response.statusCode, 200);
    });

    // --- Data Integrity Tests ---
    test('POST /cart/checkout validates Total Amount (Success)', () async {
      final infoResponse = await http.get(Uri.parse('$baseUrl/info'));
      final token = jsonDecode(infoResponse.body)['sessionToken'];

      // Correct Total: 100.0 * 2 = 200.0
      final response = await http.post(
        Uri.parse('$baseUrl/cart/checkout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'items': [{'id': testItemId, 'qty': 2}],
          'totalAmount': 200.0, // MATCHES
          'meta': 'Integrity Test'
        }),
      );

      expect(response.statusCode, 200);
      final json = jsonDecode(response.body);
      expect(json['success'], true);
    });

    test('POST /cart/checkout detects Total Amount Mismatch (Fail)', () async {
      final infoResponse = await http.get(Uri.parse('$baseUrl/info'));
      final token = jsonDecode(infoResponse.body)['sessionToken'];

      // Incorrect Total: 100.0 * 2 = 200.0, but we send 150.0
      final response = await http.post(
        Uri.parse('$baseUrl/cart/checkout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'items': [{'id': testItemId, 'qty': 2}],
          'totalAmount': 150.0, // MISMATCH
          'meta': 'Integrity Test Fail'
        }),
      );

      expect(response.statusCode, 400);
      final json = jsonDecode(response.body);
      expect(json['error'], 'Total amount mismatch');
    });
  });
}
