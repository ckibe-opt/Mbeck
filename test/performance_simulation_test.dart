import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:mbeck_business/server/routes/api_router.dart';
import 'package:mbeck_business/services/performance_monitor.dart';
import 'package:mbeck_business/db/db_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Mock Platform Channels
    SharedPreferences.setMockInitialValues({});
    const MethodChannel('plugins.flutter.io/path_provider').setMockMethodCallHandler((c) async => '.');
    
    // Mock FlutterSecureStorage
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage').setMockMethodCallHandler((MethodCall methodCall) async {
      return null;
    });
    
    // Initialize FFI for DB
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Initialize In-Memory DB
    await DbProvider.init(databaseName: sqflite.inMemoryDatabasePath);
    
    // Seed DB
    final db = await DbProvider.db;
    await db.insert('inventory', {
      'name': 'Test Burger',
      'category': 'Food',
      'sellingPrice': 500,
      'stock': 10,
      'specification': 'Delicious',
    });
  });

  tearDownAll(() async {
    await DbProvider.close();
  });

  test('Performance Simulation Loop', () async {
    final router = ApiRouter();
    
    // Manually construct the pipeline with instrumentation middleware
    final handler = const Pipeline()
        .addMiddleware((innerHandler) {
          return (request) async {
            final traceName = 'API:${request.method}:${request.url.path}';
            PerformanceMonitor().startTrace(traceName);
            try {
              final response = await innerHandler(request);
              PerformanceMonitor().endTrace(traceName, metadata: {'status': response.statusCode});
              return response;
            } catch (e) {
              PerformanceMonitor().endTrace(traceName, metadata: {'error': e.toString()});
              rethrow;
            }
          };
        })
        .addHandler(router.handler);

    // 1. Warmup
    final req1 = Request('GET', Uri.parse('http://localhost/api/v1/status'));
    await handler(req1);

    // 2. Load Testing (Simulated) - 10 iterations
    final stopwatch = Stopwatch()..start();
    for (int i = 0; i < 10; i++) {
        final req = Request('GET', Uri.parse('http://localhost/api/v1/restaurant/menu'));
        await handler(req);
    }
    stopwatch.stop();
    print('Total duration for 10 menu requests: ${stopwatch.elapsedMilliseconds}ms');

    // 3. Checkout Simulation
    final checkoutPayload = jsonEncode({
      'items': [{'id': 1, 'qty': 1}],
      'meta': 'SimulatedBuyer'
    });
    
    final reqCheckout = Request(
        'POST', 
        Uri.parse('http://localhost/api/v1/cart/checkout'),
        body: checkoutPayload,
        headers: {'content-type': 'application/json'}
    );
    
    try {
        final res = await handler(reqCheckout);
        print('Checkout Status: ${res.statusCode}');
        if (res.statusCode != 200) {
            print('Checkout Error Body: ${await res.readAsString()}');
        }
    } catch (e) {
        print('Checkout Exception: $e');
    }

    // 4. Generate Report
    final report = PerformanceMonitor().getReport();
    print('PERFORMANCE REPORT JSONING START');
    print(jsonEncode(report));
    print('PERFORMANCE REPORT JSONING END');
    
    expect(report.containsKey('API:GET:api/v1/restaurant/menu'), isTrue);
  });
}
