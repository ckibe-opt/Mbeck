import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mbeck_business/server/local_server.dart';
import 'package:mbeck_business/services/performance_monitor.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Mock PathProvider
    const MethodChannel('plugins.flutter.io/path_provider').setMockMethodCallHandler((MethodCall methodCall) async {
      return '.';
    });
    
    // Mock NetworkInfo
    const MethodChannel('dev.fluttercommunity.plus/network_info').setMockMethodCallHandler((MethodCall methodCall) async {
      return '127.0.0.1';
    });
    
    // Mock Bonsoir
    const MethodChannel('fr.skyost.bonsoir').setMockMethodCallHandler((MethodCall methodCall) async {
      return null;
    });

    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Start the server
    await ShopServer.start();
  });

  tearDownAll(() async {
    await ShopServer.stop();
  });

  test('Performance baseline analysis', () async {
    // 1. Warm up
    final client = http.Client();
    final baseUrl = 'http://localhost:8080';
    
    // 2. Test Auth/Status flow (simulated)
    final stopwatch = Stopwatch()..start();
    final response = await client.get(Uri.parse('$baseUrl/api/v1/status'));
    stopwatch.stop();
    
    expect(response.statusCode, 200);
    print('Baseline Status Request: ${stopwatch.elapsedMilliseconds}ms');
    
    // 3. Test Inventory/Menu flow
    final menuStopwatch = Stopwatch()..start();
    final menuResponse = await client.get(Uri.parse('$baseUrl/api/v1/restaurant/menu'));
    menuStopwatch.stop();
    
    expect(menuResponse.statusCode, 200);
    print('Baseline Menu Request: ${menuStopwatch.elapsedMilliseconds}ms');

    // 4. Retrieve Performance Report from Server
    final reportResponse = await client.get(Uri.parse('$baseUrl/api/v1/performance'));
    expect(reportResponse.statusCode, 200);
    
    final report = jsonDecode(reportResponse.body);
    print('Optimization Report:');
    print(const JsonEncoder.withIndent('  ').convert(report));
    
    // Verify traces exist
    final durations = report as Map<String, dynamic>;
    bool hasStatusTrace = durations.keys.any((k) => k.contains('status'));
    expect(hasStatusTrace, isTrue);

    client.close();
  });
}
