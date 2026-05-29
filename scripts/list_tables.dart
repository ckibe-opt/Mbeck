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

  print('🔍 Listing all accessible tables in Supabase...');

  final tables = ['shops', 'public_shops', 'inventory', 'public_inventory', 'events'];
  
  for (var table in tables) {
    try {
      final res = await client.from(table).select().limit(1);
      print('✅ Table "$table" exists. Found ${res.length} rows.');
    } catch (e) {
      print('❌ Table "$table" does not exist or access denied: $e');
    }
  }
}
