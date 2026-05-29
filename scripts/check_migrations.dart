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

  print('📜 Checking Migration History...');

  try {
    // Attempt to list all tables to see what we have
    final tableRes = await client.rpc('get_tables_info'); // Another common custom RPC
    print('Tables: $tableRes');
  } catch (e) {
     print('⚠️ get_tables_info failed. Trying direct query...');
     try {
       // Querying pg_catalog via RPC isn't allowed usually, but let's see if there's a 'migrations' table
       final migRes = await client.from('_migrations').select('*');
       print('Migrations: $migRes');
     } catch (e2) {
       print('❌ No migration table found or accessible: $e2');
     }
  }
}
