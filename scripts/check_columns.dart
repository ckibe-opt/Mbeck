import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
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

  print('🔍 Checking Schema for public_shops and public_inventory...');

  final tables = ['public_shops', 'public_inventory'];
  
  for (var table in tables) {
    try {
      // Get one row to see columns
      final res = await client.from(table).select().limit(1);
      if (res.isNotEmpty) {
        print('✅ Table "$table" columns: ${res[0].keys.toList()}');
      } else {
        print('✅ Table "$table" is empty, but exists.');
        // Try to insert a dummy row to see what happens or just check column names via a trick
        // Since I have service role key, I can try to query information_schema
        final columns = await client.rpc('get_table_columns', params: {'table_name': table});
        print('   Columns: $columns');
      }
    } catch (e) {
      print('❌ Error checking "$table": $e');
    }
  }
}
