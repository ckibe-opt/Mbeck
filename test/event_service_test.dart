import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbeck_business/services/event_service.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import 'package:mbeck_business/db/db_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mbeck_business/services/event_processor.dart';
import 'package:mbeck_business/models/event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // Initialize Flutter binding for tests
  // Initialize FFI for testing
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Mock SharedPreferences for testing (required before initializing Supabase)
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

  setUp(() async {
    // Mock SharedPreferences for testing
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
    // Ensure a clean in-memory database for each test
    await DbProvider.close();
    await DbProvider.init(databaseName: inMemoryDatabasePath); // Initialize a fresh in-memory database
    await DbProvider.deleteAllData();
  });

  tearDown(() async {
    await DbProvider.close();
  });

  group('EventService Tests', () {
    test('emitEvent creates and stores event', () async {
      final event = await EventService.emitEvent(
        eventType: 'TEST_EVENT',
        payload: {'key': 'value'},
      );

      expect(event.id, isNotEmpty);
      expect(event.eventType, 'TEST_EVENT');
      expect(event.verifyIntegrity(), isTrue);

      // Verify event is in database
      final db = await DbProvider.db;
      final rows = await db.query(
        'events',
        where: 'id = ?',
        whereArgs: [event.id],
      );

      expect(rows.length, 1);
      expect(rows.first['event_type'], 'TEST_EVENT');
    });

    test('emitEvent includes shop_id and device_id', () async {
      final event = await EventService.emitEvent(
        eventType: 'TEST_EVENT',
        payload: {'key': 'value'},
      );

      expect(event.shopId, isNotEmpty);
      expect(event.deviceId, isNotEmpty);
    });

    test('getUnsyncedEvents returns only unsynced events', () async {
      // Create synced and unsynced events
      final unsynced1 = await EventService.emitEvent(
        eventType: 'TEST_EVENT_1',
        payload: {'key': 'value1'},
      );

      final unsynced2 = await EventService.emitEvent(
        eventType: 'TEST_EVENT_2',
        payload: {'key': 'value2'},
      );

      // Mark first as synced
      await EventService.markEventSynced(unsynced1.id);

      final unsynced = await EventService.getUnsyncedEvents();

      expect(unsynced.length, 1);
      expect(unsynced.first.id, unsynced2.id);
    });

    test('getUnsyncedEvents respects limit', () async {
      // Create multiple events
      for (int i = 0; i < 10; i++) {
        await EventService.emitEvent(
          eventType: 'TEST_EVENT',
          payload: {'index': i},
        );
      }

      final unsynced = await EventService.getUnsyncedEvents(limit: 5);

      expect(unsynced.length, 5);
    });

    test('getUnsyncedEvents returns oldest first', () async {
      final event1 = await EventService.emitEvent(
        eventType: 'TEST_EVENT',
        payload: {'order': 1},
      );

      await Future.delayed(const Duration(milliseconds: 10));

      final event2 = await EventService.emitEvent(
        eventType: 'TEST_EVENT',
        payload: {'order': 2},
      );

      final unsynced = await EventService.getUnsyncedEvents();

      expect(unsynced.length, 2);
      expect(unsynced.first.id, event1.id); // Oldest first
    });

    test('markEventSynced updates sync status', () async {
      final event = await EventService.emitEvent(
        eventType: 'TEST_EVENT',
        payload: {'key': 'value'},
      );

      await EventService.markEventSynced(event.id);

      final unsynced = await EventService.getUnsyncedEvents();
      expect(unsynced.any((e) => e.id == event.id), isFalse);
    });

    test('markEventFailed increments sync attempts', () async {
      final event = await EventService.emitEvent(
        eventType: 'TEST_EVENT',
        payload: {'key': 'value'},
      );

      await EventService.markEventFailed(event.id);
      await EventService.markEventFailed(event.id);

      final db = await DbProvider.db;
      final rows = await db.query(
        'events',
        where: 'id = ?',
        whereArgs: [event.id],
      );

      expect(rows.first['sync_attempts'], 2);
      expect(rows.first['failed'], 1);
    });

    test('getEventsByType filters correctly', () async {
      await EventService.emitEvent(
        eventType: 'SALE',
        payload: {'amount': 100},
      );

      await EventService.emitEvent(
        eventType: 'EXPENSE',
        payload: {'amount': 50},
      );

      await EventService.emitEvent(
        eventType: 'SALE',
        payload: {'amount': 200},
      );

      final sales = await EventService.getEventsByType('SALE');

      expect(sales.length, 2);
      expect(sales.every((e) => e.eventType == 'SALE'), isTrue);
    });

    test('getEventCount returns correct count', () async {
      expect(await EventService.getEventCount(), 0);

      await EventService.emitEvent(
        eventType: 'TEST_EVENT',
        payload: {'key': 'value'},
      );

      expect(await EventService.getEventCount(), 1);

      await EventService.emitEvent(
        eventType: 'TEST_EVENT',
        payload: {'key': 'value2'},
      );

      expect(await EventService.getEventCount(), 2);
    });

    test('verifyEventIntegrity works', () async {
      final event = await EventService.emitEvent(
        eventType: 'TEST_EVENT',
        payload: {'key': 'value'},
      );

      expect(await EventService.verifyEventIntegrity(event.id), isTrue);
    });

    group('CRM Sync Projections', () {
      test('processEvent processes CUSTOMER_CREATE event', () async {
        final db = await DbProvider.db;
        
        // Emit customer create event
        final event = Event.create(
          eventType: 'CUSTOMER_CREATE',
          payload: {
            'name': 'CRM Customer',
            'phone': '123456789',
            'id_no': 'ID999',
            'bank_account': 'BANK999',
            'notes': 'Sync notes',
            'agent': 'Sync agent',
            'store': 'Sync store',
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          },
          shopId: 'shop-1',
          deviceId: 'other-device', // must be different to not skip event processor
        );

        // Verify customer does not exist initially
        final initial = await db.query('customer', where: 'phone = ?', whereArgs: ['123456789']);
        expect(initial.isEmpty, isTrue);

        // Process event
        final processed = await EventProcessor.processEvent(event);
        expect(processed, isTrue);

        // Verify customer was inserted
        final result = await db.query('customer', where: 'phone = ?', whereArgs: ['123456789']);
        expect(result.length, 1);
        expect(result.first['name'], 'CRM Customer');
        expect(result.first['id_no'], 'ID999');
        expect(result.first['notes'], 'Sync notes');
      });

      test('processEvent processes CUSTOMER_UPDATE event', () async {
        final db = await DbProvider.db;
        
        // 1. Manually insert a customer
        final localId = await db.insert('customer', {
          'name': 'Original Name',
          'phone': '987654321',
          'id_no': 'ID000',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });

        // 2. Process customer update event (matching by previous phone number)
        final updateEvent = Event.create(
          eventType: 'CUSTOMER_UPDATE',
          payload: {
            'previousPhone': '987654321',
            'previousName': 'Original Name',
            'name': 'Updated Name',
            'phone': '987654321-new',
            'id_no': 'ID000-new',
            'bank_account': 'BANK-new',
            'notes': 'Updated notes',
            'agent': 'Updated agent',
            'store': 'Updated store',
          },
          shopId: 'shop-1',
          deviceId: 'other-device',
        );

        final processed = await EventProcessor.processEvent(updateEvent);
        expect(processed, isTrue);

        // 3. Verify target customer is updated in place (id remains same)
        final updatedResult = await db.query('customer', where: 'id = ?', whereArgs: [localId]);
        expect(updatedResult.length, 1);
        expect(updatedResult.first['name'], 'Updated Name');
        expect(updatedResult.first['phone'], '987654321-new');
        expect(updatedResult.first['id_no'], 'ID000-new');
        expect(updatedResult.first['notes'], 'Updated notes');
      });
    });
  });
}
