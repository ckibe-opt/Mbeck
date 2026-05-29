import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

// Test the exact server-side hash calculation process
void main() async {
  print('🧪 Testing server-side hash calculation...\n');
  
  // Simulate the exact event structure sent to server
  final event = {
    'id': '1a3c64c8-8187-4908-bc94-f246fc4c4155',
    'event_type': 'BOOKING_STATUS_CHANGE',
    'payload': {
      'booking_id': 4,
      'new_status': 'confirmed', 
      'previous_status': 'no_show'
    },
    'payload_raw': '{"booking_id":4,"new_status":"confirmed","previous_status":"no_show"}',
    'hash': '669ab8f0c25704416ed5c94bbba7c7bedb854cfb41c2f694f7a727439229a26c',
    'timestamp': 1770955270894,
    'shop_id': 'shop_1770821513844_8578',
    'device_id': 'device_1770821513622_2893'
  };
  
  // Test old server approach (what was causing the mismatch)
  print('❌ OLD Server Approach:');
  final oldPayloadRaw = jsonEncode(event['payload']); // This was the bug!
  final oldHashInput = '${event['id']}|${event['event_type']}|$oldPayloadRaw|${event['timestamp']}|${event['shop_id']}|${event['device_id']}';
  final oldHash = sha256.convert(utf8.encode(oldHashInput)).toString();
  
  print('  Payload Raw: $oldPayloadRaw');
  print('  Hash Input: $oldHashInput');
  print('  Calculated: $oldHash');
  print('  Expected: ${event['hash']}');
  print('  Match: ${oldHash == event['hash']}\n');
  
  // Test new server approach (with canonical encoding)
  print('✅ NEW Server Approach:');
  final newPayloadRaw = encodeCanonical(event['payload']); // Fixed approach
  final newHashInput = '${event['id']}|${event['event_type']}|$newPayloadRaw|${event['timestamp']}|${event['shop_id']}|${event['device_id']}';
  final newHash = sha256.convert(utf8.encode(newHashInput)).toString();
  
  print('  Payload Raw: $newPayloadRaw');
  print('  Hash Input: $newHashInput');
  print('  Calculated: $newHash');
  print('  Expected: ${event['hash']}');
  print('  Match: ${newHash == event['hash']}\n');
  
  // Test using payload_raw from event (what should happen)
  print('🎯 Using Event payload_raw:');
  final eventPayloadRaw = event['payload_raw'] as String;
  final eventHashInput = '${event['id']}|${event['event_type']}|$eventPayloadRaw|${event['timestamp']}|${event['shop_id']}|${event['device_id']}';
  final eventHash = sha256.convert(utf8.encode(eventHashInput)).toString();
  
  print('  Payload Raw: $eventPayloadRaw');
  print('  Hash Input: $eventHashInput');
  print('  Calculated: $eventHash');
  print('  Expected: ${event['hash']}');
  print('  Match: ${eventHash == event['hash']}');
}

// Canonical JSON encoding (matching the TypeScript implementation)
String encodeCanonical(dynamic obj) {
  if (obj == null || obj is! Map) {
    return jsonEncode(obj);
  }
  
  if (obj is List) {
    final list = obj as List;
    return '[' + list.map((item) => encodeCanonical(item)).join(',') + ']';
  }
  
  final map = obj as Map<String, dynamic>;
  final sortedKeys = map.keys.toList()..sort();
  final sortedMap = <String, dynamic>{};
  
  for (final key in sortedKeys) {
    sortedMap[key] = map[key];
  }
  
  return jsonEncode(sortedMap);
}
