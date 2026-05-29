import 'dart:io';
import 'package:supabase/supabase.dart';

/// Automation Script to Dump Shops
void main() async {
  // 1. Load Keys
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

  try {
    final response = await supabase.from('shops').select('id, business_name');
    print('✅ Found ${response.length} shops:');
    for (var shop in response) {
      print('🛒 [${shop['id']}] Name: "${shop['business_name']}"');
    }
  } catch (e) {
    print('❌ Connection Failed: $e');
  }
}
