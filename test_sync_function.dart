import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

void main() async {
  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  final supabaseUrl = dotenv.env['SUPABASE_URL']!;
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
  
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  final supabase = Supabase.instance.client;

  print('🧪 Testing sync-events Edge Function...');

  try {
    // Create a test event
    final testEvent = {
      'id': 'test-${DateTime.now().millisecondsSinceEpoch}',
      'event_type': 'TEST',
      'payload': {'message': 'Testing sync function', 'timestamp': DateTime.now().toIso8601String()},
      'payload_raw': '{"message": "Testing sync function", "timestamp": "${DateTime.now().toIso8601String()}"}',
      'hash': 'test-hash-${DateTime.now().millisecondsSinceEpoch}',
      'shop_id': 'shop_1770821513844_8578',
      'device_id': 'device_test_${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    print('📤 Sending test event...');
    print('Event ID: ${testEvent['id']}');
    print('Shop ID: ${testEvent['shop_id']}');
    print('Device ID: ${testEvent['device_id']}');

    // Invoke the function
    final res = await supabase.functions.invoke('sync-events', body: [testEvent]);
    final data = res.data;

    print('✅ Function invoked successfully!');
    print('Status: ${res.status}');
    print('Response: $data');

    // Check response structure
    if (data is Map<String, dynamic>) {
      final insertedCount = data['inserted_count'] ?? 0;
      final skippedCount = data['skipped_count'] ?? 0;
      final errors = data['errors'] as List? ?? [];
      
      print('📊 Results:');
      print('  - Inserted: $insertedCount');
      print('  - Skipped: $skippedCount');
      print('  - Errors: ${errors.length}');
      
      if (errors.isNotEmpty) {
        print('❌ Errors:');
        for (final error in errors) {
          print('    - ${error['id']}: ${error['error']}');
        }
      }
    }

  } catch (e) {
    print('❌ Error invoking function: $e');
    exit(1);
  }

  print('🎉 Test completed successfully!');
}
