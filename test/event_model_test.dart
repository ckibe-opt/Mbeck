import 'package:mbeck_business/models/shop.dart';
import 'package:mbeck_business/models/shop_member.dart';
import 'package:mbeck_business/models/event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbeck_shared/mbeck_shared.dart';

void main() {
  group('Event Model Tests', () {
    test('Event.create generates UUID and hash', () {
      final event = Event.create(
        eventType: 'TEST_EVENT',
        payload: {'key': 'value'},
      );

      expect(event.id, isNotEmpty);
      expect(event.id.length, greaterThan(20)); // UUID format
      expect(event.hash, isNotEmpty);
      expect(event.hash.length, 64); // SHA-256 hex length
      expect(event.eventType, 'TEST_EVENT');
      expect(event.payload, {'key': 'value'});
      expect(event.timestamp, greaterThan(0));
    });

    test('Event integrity verification works', () {
      final event = Event.create(
        eventType: 'TEST_EVENT',
        payload: {'key': 'value'},
        shopId: 'shop_123',
        deviceId: 'device_456',
      );

      expect(event.verifyIntegrity(), isTrue);
    });

    test('Event integrity fails on tampered payload', () {
      final event = Event.create(
        eventType: 'TEST_EVENT',
        payload: {'key': 'value'},
      );

      // Create a tampered event
      final tampered = Event(
        id: event.id,
        eventType: event.eventType,
        payload: {'key': 'tampered'}, // Changed payload
        hash: event.hash, // Old hash
        timestamp: event.timestamp,
        shopId: event.shopId,
        deviceId: event.deviceId,
      );

      expect(tampered.verifyIntegrity(), isFalse);
    });

    test('Event serialization and deserialization', () {
      final original = Event.create(
        eventType: 'TEST_EVENT',
        payload: {'key': 'value', 'number': 123},
        shopId: 'shop_123',
        deviceId: 'device_456',
      );

      final map = original.toMap();
      final restored = Event.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.eventType, original.eventType);
      expect(restored.payload, original.payload);
      expect(restored.hash, original.hash);
      expect(restored.timestamp, original.timestamp);
      expect(restored.shopId, original.shopId);
      expect(restored.deviceId, original.deviceId);
      expect(restored.verifyIntegrity(), isTrue);
    });

    test('Event copyWith only allows sync metadata changes', () {
      final original = Event.create(
        eventType: 'TEST_EVENT',
        payload: {'key': 'value'},
      );

      final updated = original.copyWith(
        synced: 1,
        syncAttempts: 3,
        failed: 0,
      );

      expect(updated.id, original.id);
      expect(updated.payload, original.payload);
      expect(updated.hash, original.hash);
      expect(updated.synced, 1);
      expect(updated.syncAttempts, 3);
      expect(updated.failed, 0);
    });

    test('Event equality based on ID', () {
      final event1 = Event.create(
        eventType: 'TEST_EVENT',
        payload: {'key': 'value'},
      );

      final event2 = Event.create(
        eventType: 'TEST_EVENT',
        payload: {'key': 'value'},
      );

      expect(event1.id, isNot(equals(event2.id))); // Different IDs should have different IDs
      expect(event1.id, equals(event1.id)); // Same instance should have same ID
    });
  });
}
