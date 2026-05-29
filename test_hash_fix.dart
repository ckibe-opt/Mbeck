import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

// Test the hash calculation fix
void main() async {
  print('🧪 Testing hash calculation fix...\n');
  
  // Sample event data from the logs
  final eventData = {
    'booking_id': 4,
    'new_status': 'confirmed', 
    'previous_status': 'no_show'
  };
  
  final eventId = '1a3c64c8-8187-4908-bc94-f246fc4c4155';
  final eventType = 'BOOKING_STATUS_CHANGE';
  final timestamp = 1770955270894;
  final shopId = 'shop_1770821513844_8578';
  final deviceId = 'device_1770821513622_2893';
  
  // Client-side canonical encoding (Dart)
  final clientCanonical = _encodeCanonical(eventData);
  final clientHashInput = '$eventId|$eventType|$clientCanonical|$timestamp|$shopId|$deviceId';
  final clientHash = sha256.convert(utf8.encode(clientHashInput)).toString();
  
  print('📱 Client-side (Dart):');
  print('  Canonical JSON: $clientCanonical');
  print('  Hash Input: $clientHashInput');
  print('  Calculated Hash: $clientHash');
  print('  Expected Hash: 669ab8f0c25704416ed5c94bbba7c7bedb854cfb41c2f694f7a727439229a26c');
  print('  Match: ${clientHash == '669ab8f0c25704416ed5c94bbba7c7bedb854cfb41c2f694f7a727439229a26c'}\n');
  
  // Server-side canonical encoding (TypeScript simulation)
  final serverCanonical = _encodeCanonicalTS(eventData);
  final serverHashInput = '$eventId|$eventType|$serverCanonical|$timestamp|$shopId|$deviceId';
  final serverHash = sha256.convert(utf8.encode(serverHashInput)).toString();
  
  print('🖥️ Server-side (TypeScript):');
  print('  Canonical JSON: $serverCanonical');
  print('  Hash Input: $serverHashInput');
  print('  Calculated Hash: $serverHash');
  print('  Match: ${serverHash == clientHash}\n');
  
  // Test the fixed server-side encoding
  final fixedCanonical = _encodeCanonicalFixed(eventData);
  final fixedHashInput = '$eventId|$eventType|$fixedCanonical|$timestamp|$shopId|$deviceId';
  final fixedHash = sha256.convert(utf8.encode(fixedHashInput)).toString();
  
  print('✅ Fixed Server-side:');
  print('  Canonical JSON: $fixedCanonical');
  print('  Hash Input: $fixedHashInput');
  print('  Calculated Hash: $fixedHash');
  print('  Match: ${fixedHash == clientHash}');
}

// Client-side canonical encoding (Dart)
String _encodeCanonical(Map<String, dynamic> map) {
  final sortedKeys = map.keys.toList()..sort();
  final sorted = <String, dynamic>{};
  
  for (final key in sortedKeys) {
    final value = map[key];
    if (value is Map<String, dynamic>) {
      sorted[key] = jsonDecode(_encodeCanonical(value));
    } else if (value is List) {
      sorted[key] = value.map((item) {
        if (item is Map<String, dynamic>) {
          return jsonDecode(_encodeCanonical(item));
        }
        return item;
      }).toList();
    } else {
      sorted[key] = value;
    }
  }
  
  return jsonEncode(sorted);
}

// Old server-side encoding (TypeScript simulation)
String _encodeCanonicalTS(Map<String, dynamic> map) {
  return jsonEncode(map); // No sorting - this was the bug
}

// Fixed server-side encoding (TypeScript simulation)
String _encodeCanonicalFixed(Map<String, dynamic> map) {
  if (map.isEmpty) return '{}';
  
  final sortedKeys = map.keys.toList()..sort();
  final sortedMap = <String, dynamic>{};
  
  for (final key in sortedKeys) {
    sortedMap[key] = map[key];
  }
  
  return jsonEncode(sortedMap);
}
