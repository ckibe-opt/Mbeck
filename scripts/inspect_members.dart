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

  print('🔍 Inspecting shop_members schema...');

  try {
    // Attempt to select user_id from shop_members (limit 1)
    final res = await client.from('shop_members').select('id, user_id, device_id').limit(1);
    print('✅ shop_members has user_id: $res');
  } catch (e) {
    print('❌ shop_members likely MISSING user_id: $e');
  }
}
