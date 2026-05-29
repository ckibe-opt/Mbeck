import 'package:mbeck_business/models/shop.dart';
import 'package:mbeck_business/models/shop_member.dart';
import 'package:mbeck_business/models/event.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import 'package:mbeck_business/services/event_processor.dart';
import 'package:mbeck_business/services/performance_monitor.dart';
import 'package:mbeck_business/db/db_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added import

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Mock Platform Channels
    SharedPreferences.setMockInitialValues({
      'device_id': 'device_local_123',
      'shop_id': 'shop_123',
      'cached_member_data': jsonEncode({
        'id': 1,
        'shop_id': 'shop_123',
        'device_id': 'device_local_123',
        'user_name': 'Test Owner',
        'role': 'OWNER',
        'permissions': {},
        'joined_at': DateTime.now().toIso8601String(),
        'is_active': true,
      }),
      'cached_shop_data': jsonEncode({
        'id': 'shop_123',
        'name': 'Test Shop',
        'owner_device_id': 'device_local_123',
        'owner_id': 'user_123',
        'subscription_tier': 'PRO',
        'subscription_status': 'ACTIVE',
        'joined_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'theme_config': {},
        'trust_score': 100.0,
      }),
    });
    
    const MethodChannel('plugins.flutter.io/path_provider').setMockMethodCallHandler((c) async => '.');
    const MethodChannel('dev.fluttercommunity.plus/network_info').setMockMethodCallHandler((c) async => '127.0.0.1');

    // Mock FlutterSecureStorage
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage').setMockMethodCallHandler((MethodCall methodCall) async {
      return null;
    });

    // Initialize FFI for DB
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Initialize In-Memory DB
    await DbProvider.init(databaseName: sqflite.inMemoryDatabasePath);

    // Initialize Mock Supabase (to prevent AssertionError in AuthService)
    try {
      await Supabase.initialize(
        url: 'https://example.com',
        anonKey: 'example',
        debug: false,
      );
    } catch (_) {
      // Ignore if already initialized
    }
  });

  tearDownAll(() async {
    await DbProvider.close();
  });

  test('Sync Processing Performance', () async {
    // 1. Create a "Remote" Event
    final remoteEvent = Event(
      id: 'evt_remote_999',
      eventType: 'INVENTORY_UPDATE',
      payload: {
        'name': 'Test Item', // Will trigger update by name
        'sellingPrice': 600.0,
        'originalPrice': 450.0,
      },
      hash: 'abc123hash',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      shopId: 'shop_123',
      deviceId: 'device_remote_456', // Distinct from local
    );

    // Seed DB with the item to be updated
    final db = await DbProvider.db;
    await db.insert('inventory', {
      'name': 'Test Item',
      'category': 'Test',
      'sellingPrice': 500.0,
      'stock': 10,
    });

    // 2. Measure Processing Time
    final stopwatch = Stopwatch()..start();
    final success = await EventProcessor.processEvent(remoteEvent);
    stopwatch.stop();

    expect(success, isTrue);
    print('Event Processing Time: ${stopwatch.elapsedMilliseconds}ms');

    // 3. Verify Trace
    final report = PerformanceMonitor().getReport();
    print('Sync Report: $report');
    
    expect(report.containsKey('EventProcessor.processEvent'), isTrue);
    
    final metrics = report['EventProcessor.processEvent'];
    expect(metrics['count'], 1);
  });
}
