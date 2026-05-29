import 'dart:io';
import 'package:supabase/supabase.dart';

/// Universal Migration Runner for Mbeck
/// Usage: dart scripts/migrate.dart migrations/migration_vXX.sql
void main(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Usage: dart scripts/migrate.dart <path_to_sql_file>');
    exit(1);
  }

  final filePath = args[0];
  final file = File(filePath);
  if (!await file.exists()) {
    print('❌ Error: File not found: $filePath');
    exit(1);
  }

  print('📂 Reading Migration: $filePath');
  final sql = await file.readAsString();

  // Load Keys
  final envFile = File('.env');
  if (!await envFile.exists()) {
    print('❌ Error: .env file not found.');
    exit(1);
  }
  
  final lines = await envFile.readAsLines();
  final keys = <String, String>{};
  for (var line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length == 2) {
      keys[parts[0].trim()] = parts[1].trim();
    }
  }

  final url = keys['SUPABASE_URL'];
  final serviceKey = keys['SUPABASE_SERVICE_ROLE_KEY'];

  if (url == null || serviceKey == null) {
    print('❌ Error: Missing env keys');
    exit(1);
  }

  print('🔌 Connecting to Supabase...');
  final supabase = SupabaseClient(url, serviceKey);

  print('🚀 Executing Migration via exec_sql RPC...');
  try {
    await supabase.rpc('exec_sql', params: {'sql_query': sql});
    print('✅ Migration Applied Successfully!');
  } catch (e) {
    print('❌ Migration Failed: $e');
    print('\nTip: If "exec_sql" is missing, you must install it manually first:');
    print('''
CREATE OR REPLACE FUNCTION exec_sql(sql_query text)
RETURNS void AS \$\$
BEGIN
  EXECUTE sql_query;
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;
    ''');
    exit(1);
  }
}
