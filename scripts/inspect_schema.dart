import 'dart:io';
import 'package:supabase/supabase.dart';

void main(List<String> arguments) async {
  // 1. Load Keys
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  final keys = <String, String>{};
  for (var line in lines) {
    if (line.isNotEmpty && !line.startsWith('#')) {
      final parts = line.split('=');
      if (parts.length >= 2) keys[parts[0].trim()] = parts.sublist(1).join('=').trim();
    }
  }

  final client = SupabaseClient(keys['SUPABASE_URL']!, keys['SUPABASE_SERVICE_ROLE_KEY']!);

  final tableName = arguments.isNotEmpty ? arguments[0] : 'shops';
  print('🔍 Inspecting $tableName Schema...');

  try {
    // Check Table - Select ALL to find hidden columns
    final res = await client.from(tableName).select('*').limit(1);
    
    print('✅ $tableName Schema OK.');
    if (res.isNotEmpty) {
      print('   Columns: ${res[0].keys.toList()}');
      print('   Sample: ${res[0]}');
    } else {
      print('   (Table is empty)');
    }

  } catch (e) {
    print('❌ Error checking schema: $e');
    print('   If error says column does not exist, then Migration V21 was NOT applied.');
  }
}
