import 'package:flutter_test/flutter_test.dart';
import 'package:mbeck_business/services/event_service.dart';
import 'package:mbeck_business/db/db_provider.dart';
import 'package:mbeck_business/customer_import.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added for SharedPreferences.setMockInitialValues
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // Initialize Flutter binding for tests
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Mock SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
    // Ensure a clean in-memory database for each test
    await DbProvider.close();
    await DbProvider.init(databaseName: inMemoryDatabasePath); // Initialize a fresh in-memory database
    await DbProvider.deleteAllData();
  });

  tearDown(() async {
    await DbProvider.close();
  });

  group('Phase 1 Integration Tests', () {
    test('Complete sale flow emits correct events', () async {
      // Simulate a sale transaction
      final saleEvent = await EventService.emitEvent(
        eventType: 'SALE',
        payload: {
          'type': 'sale',
          'totalAmount': 5000,
          'discount': 0,
          'quantity': 2,
          'itemId': 123,
          'itemName': 'Test Product',
        },
      );

      expect(saleEvent.eventType, 'SALE');
      expect(saleEvent.payload['totalAmount'], 5000);
      expect(saleEvent.verifyIntegrity(), isTrue);

      // Emit inventory change event
      final inventoryEvent = await EventService.emitEvent(
        eventType: 'INVENTORY_CHANGE',
        payload: {
          'itemId': 123,
          'change': -2,
          'previousStock': 10,
          'newStock': 8,
          'transactionEventId': saleEvent.id,
        },
      );

      expect(inventoryEvent.eventType, 'INVENTORY_CHANGE');
      expect(inventoryEvent.payload['transactionEventId'], saleEvent.id);
    });

    test('Cash count flow emits correct events', () async {
      final cashEvent = await EventService.emitEvent(
        eventType: 'CASH_COUNT',
        payload: {
          'total': 50000,
          'denominations': {
            'KSH_1000': 20,
            'KSH_500': 40,
          },
        },
      );

      expect(cashEvent.eventType, 'CASH_COUNT');
      expect(cashEvent.payload['total'], 50000);
      expect(cashEvent.payload['denominations'], isA<Map>());
    });

    test('Accounting closing with disparity emits both events', () async {
      final closingEvent = await EventService.emitEvent(
        eventType: 'ACCOUNTING_CLOSING',
        payload: {
          'cashTotal': 50000,
          'expectedTotal': 52000,
          'actualTotal': 50000,
          'disparity': -2000,
        },
      );

      expect(closingEvent.eventType, 'ACCOUNTING_CLOSING');

      // Emit disparity event
      final disparityEvent = await EventService.emitEvent(
        eventType: 'DISPARITY',
        payload: {
          'amount': 2000,
          'type': 'shortage',
          'accountingEventId': closingEvent.id,
        },
      );

      expect(disparityEvent.eventType, 'DISPARITY');
      expect(disparityEvent.payload['type'], 'shortage');
      expect(disparityEvent.payload['accountingEventId'], closingEvent.id);
    });

    test('Inventory operations emit correct events', () async {
      // Create
      final createEvent = await EventService.emitEvent(
        eventType: 'INVENTORY_CREATE',
        payload: {
          'name': 'New Product',
          'category': 'Electronics',
          'stock': 10,
        },
      );

      expect(createEvent.eventType, 'INVENTORY_CREATE');

      // Update
      final updateEvent = await EventService.emitEvent(
        eventType: 'INVENTORY_UPDATE',
        payload: {
          'itemId': 123,
          'previousStock': 10,
          'newStock': 15,
          'stockChange': 5,
        },
      );

      expect(updateEvent.eventType, 'INVENTORY_UPDATE');
      expect(updateEvent.payload['stockChange'], 5);

      // Delete
      final deleteEvent = await EventService.emitEvent(
        eventType: 'INVENTORY_DELETE',
        payload: {
          'itemId': 123,
          'itemName': 'Deleted Product',
        },
      );

      expect(deleteEvent.eventType, 'INVENTORY_DELETE');
    });

    test('All events have shop_id and device_id', () async {
      final events = [
        await EventService.emitEvent(eventType: 'SALE', payload: {}),
        await EventService.emitEvent(eventType: 'CASH_COUNT', payload: {}),
        await EventService.emitEvent(eventType: 'ACCOUNTING_CLOSING', payload: {}),
      ];

      for (final event in events) {
        expect(event.shopId, isNotEmpty);
        expect(event.deviceId, isNotEmpty);
        expect(event.shopId!.startsWith('shop_'), isTrue);
        expect(event.deviceId!.startsWith('device_'), isTrue);
      }
    });

    test('Event integrity maintained across all operations', () async {
      final events = [
        await EventService.emitEvent(
          eventType: 'SALE',
          payload: {'amount': 1000},
        ),
        await EventService.emitEvent(
          eventType: 'EXPENSE',
          payload: {'amount': 500},
        ),
        await EventService.emitEvent(
          eventType: 'INVENTORY_CHANGE',
          payload: {'change': -1},
        ),
      ];

      for (final event in events) {
        expect(event.verifyIntegrity(), isTrue);
        expect(await EventService.verifyEventIntegrity(event.id), isTrue);
      }
    });

    test('Unsynced events query works correctly', () async {
      // Create multiple events
      final event1 = await EventService.emitEvent(
        eventType: 'SALE',
        payload: {'amount': 100},
      );

      await Future.delayed(const Duration(milliseconds: 10));

      final event2 = await EventService.emitEvent(
        eventType: 'SALE',
        payload: {'amount': 200},
      );

      // Mark first as synced
      await EventService.markEventSynced(event1.id);

      final unsynced = await EventService.getUnsyncedEvents();

      expect(unsynced.length, 1);
      expect(unsynced.first.id, event2.id);
    });

    group('Phase 2 Integration Tests', () {
      test('Customer ledger entries do not contaminate other accounts when phone number is empty/null', () async {
        final db = await DbProvider.db;

        // Insert two customers with empty phone numbers or null phone numbers
        final cId1 = await db.insert('customer', {
          'name': 'Customer One',
          'phone': '',
          'store': 'Main',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });

        final cId2 = await db.insert('customer', {
          'name': 'Customer Two',
          'phone': null,
          'store': 'Main',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Add ledger entries for Customer One
        await db.insert('customer_ledger', {
          'customer_id': cId1,
          'customer_phone': '',
          'customer_name': 'Customer One',
          'type': 'owing',
          'amount': 1500.0,
          'status': 'open',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        // Add ledger entries for Customer Two
        await db.insert('customer_ledger', {
          'customer_id': cId2,
          'customer_phone': null,
          'customer_name': 'Customer Two',
          'type': 'owing',
          'amount': 2500.0,
          'status': 'open',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        // Query raw customer ledger for each ID
        final ledger1 = await db.query('customer_ledger', where: 'customer_id = ?', whereArgs: [cId1]);
        final ledger2 = await db.query('customer_ledger', where: 'customer_id = ?', whereArgs: [cId2]);

        expect(ledger1.length, 1);
        expect(ledger1.first['amount'], 1500.0);

        expect(ledger2.length, 1);
        expect(ledger2.first['amount'], 2500.0);
      });

      test('CSV Customer Import executes in batch successfully', () async {
        // Create a temporary CSV file content
        final csvContent = '''name,phone,id_no,bank_account,notes,agent,store
Alice,0711111111,1111,BankA,NoteA,AgentA,StoreA
Bob,0722222222,2222,BankB,NoteB,AgentB,StoreB
Charlie,0733333333,3333,BankC,NoteC,AgentC,StoreC
''';
        
        final tempDir = Directory.systemTemp.createTempSync();
        final file = File('${tempDir.path}/customers.csv')..writeAsStringSync(csvContent);

        try {
          final errors = await importCustomersFromCsvFile(file);
          expect(errors, isEmpty);

          final db = await DbProvider.db;
          final res = await db.query('customer', where: 'name IN (?, ?, ?)', whereArgs: ['Alice', 'Bob', 'Charlie']);
          expect(res.length, 3);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });
  });
}
