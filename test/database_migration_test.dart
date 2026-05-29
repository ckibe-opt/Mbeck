import 'package:flutter_test/flutter_test.dart';
import 'package:mbeck_business/db/db_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart'; // Added for join
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart'; // Added for getDatabasesPath

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'read') {
        return 'test-key-32-chars-long-123456789012'; // Return a mock key
      }
      return null;
    });
    
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Ensure a clean in-memory database for each test
    await DbProvider.close(); // Close any existing database connection
    await DbProvider.init(databaseName: inMemoryDatabasePath); // Initialize a fresh in-memory database
    await DbProvider.deleteAllData();
  });

  tearDown(() async {
    await DbProvider.close();
  });

  group('Database Migration Tests', () {
    test('events table is created on init', () async {
      final db = await DbProvider.db;

      // Check if events table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='events'"
      );

      expect(tables.length, 1);
    });

    test('events table has correct schema', () async {
      final db = await DbProvider.db;

      final columns = await db.rawQuery('PRAGMA table_info(events)');
      final columnNames = columns.map((c) => c['name'] as String).toList();

      expect(columnNames, contains('id'));
      expect(columnNames, contains('event_type'));
      expect(columnNames, contains('payload'));
      expect(columnNames, contains('hash'));
      expect(columnNames, contains('timestamp'));
      expect(columnNames, contains('shop_id'));
      expect(columnNames, contains('device_id'));
      expect(columnNames, contains('synced'));
      expect(columnNames, contains('sync_attempts'));
      expect(columnNames, contains('failed'));
    });

    test('events table indexes are created', () async {
      final db = await DbProvider.db;

      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='events'"
      );

      final indexNames = indexes.map((i) => i['name'] as String).toList();

      expect(indexNames, contains('idx_events_timestamp'));
      expect(indexNames, contains('idx_events_type'));
      expect(indexNames, contains('idx_events_synced'));
    });

    test('can insert event into events table', () async {
      // Use unique ID for this test
      final uniqueId = 'test-uuid-' + DateTime.now().millisecondsSinceEpoch.toString();
      final db = await DbProvider.db;

      await db.insert('events', {
        'id': uniqueId,
        'event_type': 'TEST_EVENT',
        'payload': '{"key":"value"}',
        'hash': 'test-hash',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'shop_id': 'shop_123',
        'device_id': 'device_456',
        'synced': 0,
        'sync_attempts': 0,
        'failed': 0,
      });

      final rows = await db.query('events', where: 'id = ?', whereArgs: [uniqueId]);
      expect(rows.length, 1);
      expect(rows.first['event_type'], 'TEST_EVENT');
    });
  });
}
