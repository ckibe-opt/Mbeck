import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  // Load Keys
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  final keys = <String, String>{};
  for (var line in lines) {
    if (line.isNotEmpty && !line.startsWith('#')) {
      final parts = line.split('=');
      if (parts.length >= 2) keys[parts[0].trim()] = parts[1].trim();
    }
  }

  // Admin Client
  final client = SupabaseClient(keys['SUPABASE_URL']!, keys['SUPABASE_SERVICE_ROLE_KEY']!);

  print('👥 Fetching Users (Shops)...');

  try {
    // Pure Dart Supabase SDK Admin interface
    // Note: implementation depends on version. 
    // If client.auth.admin is not available, we use RLS bypass on a 'profiles' table if it exists,
    // or just assume we can insert for ANY id if RLS is bypassed by Service Key.
    
    // Let's try to query the implicit 'auth.users' via a workaround or just list a known table 'shops' if it exists.
    // Actually, for the Seeder, any UUID works if RLS checks 'shop_id'.
    // But to be useful, it must be a real user.
    
    final res = await client.auth.admin.listUsers();
    
    if (res.isEmpty) {
      print('⚠️ No users found in Supabase Auth.');
      print('   Create a user in the App or Dashboard first.');
    } else {
      print('✅ Found ${res.length} potential shops:');
      for (var user in res) {
        print('   ID: ${user.id} | Email: ${user.email}');
      }
    }
  } catch (e) {
    print('❌ Error fetching users: $e');
    print('   (Make sure Service Role Key is valid and has Auth Admin capability)');
  }
}
