import 'dart:io';
import 'package:supabase/supabase.dart';

void main(List<String> args) async {
  if (args.length < 2) {
    print('❌ Usage: dart scripts/create_test_user.dart <email> <password>');
    exit(1);
  }

  final email = args[0];
  final password = args[1];

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

  final client = SupabaseClient(keys['SUPABASE_URL']!, keys['SUPABASE_SERVICE_ROLE_KEY']!);

  print('👤 Creating User: $email ...');

  try {
    // Admin request to create user
    final res = await client.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        data: {'test_user': true}
      ),
    );

    if (res.user != null) {
      print('✅ User Created Successfully!');
      print('   ID: ${res.user!.id} (Use this for Seeding)');
    } else {
      print('❌ Failed to create user (No ID returned).');
    }
  } catch (e) {
    print('❌ Error creating user: $e');
  }
}
