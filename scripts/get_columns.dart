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

  print('🔍 Fetching column list for inventory...');

  try {
    // We can't use rpc if it's not defined, so we try a select with dummy.
    // Or we look for common names.
    // Actually, we can just try to insert one and catch the error which usually lists columns.
    // But better, let's try a select with "*" and see if we can get anything from PostgREST metadata if available.
    // Another way: query the first row and look at keys, but Table is empty.
    
    // Let's try to insert a mostly empty row and see what it says
    await client.from('inventory').insert({'shop_id': 'dummy'});
    print('✅ Insert actually worked? That means only shop_id is required.');
  } catch (e) {
    print('ℹ️ Insert failed (as expected), checking error for column hints...');
    print('   Error: $e');
  }
}
