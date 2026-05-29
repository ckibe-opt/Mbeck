import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  print('🔄 Applying Migration V28 (Add Shop Branding)...');

  // Load Keys
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  final keys = <String, String>{};
  for (var line in lines) {
    if (line.isNotEmpty && !line.startsWith('#')) {
      final parts = line.split('=');
      if (parts.length == 2) keys[parts[0].trim()] = parts[1].trim();
    }
  }

  final url = keys['SUPABASE_URL'];
  final key = keys['SUPABASE_SERVICE_ROLE_KEY'];

  if (url == null || key == null) {
    print('❌ Missing Keys');
    exit(1);
  }

  final client = SupabaseClient(url, key);

  final sql = """
  DO \$\$
  BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name = 'shops' AND column_name = 'branding'
    ) THEN
      ALTER TABLE shops ADD COLUMN branding JSONB DEFAULT '{}'::jsonb;
    END IF;
  END \$\$;
  """;

  try {
    // Attempting to run via RPC 'exec_sql' which is a common pattern for admin tools
    // If this function doesn't exist on the server, this will fail.
    await client.rpc('exec_sql', params: {'sql_query': sql});
    print('✅ Migration V28 Applied Successfully via RPC.');
  } catch (e) {
    print('⚠️ RPC Execution failed: $e');
    print('---------------------------------------------------');
    print('❌ AUTO-MIGRATION FAILED.');
    print('Reason: The generic "exec_sql" RPC function is likely not installed on your Supabase instance.');
    print('');
    print('👉 ACTION REQUIRED:');
    print('Please copy the contents of "migrations/migration_v28_add_shop_branding.sql"');
    print('and run it manually in your Supabase Dashboard > SQL Editor.');
    print('---------------------------------------------------');
    exit(1);
  }
}
