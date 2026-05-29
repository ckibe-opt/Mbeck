import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

void main() async {
  // 1. Load Env
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  final keys = <String, String>{};
  for (var line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2) {
      keys[parts[0].trim()] = parts.sublist(1).join('=').trim();
    }
  }
  
  final supabase = SupabaseClient(keys['SUPABASE_URL']!, keys['SUPABASE_SERVICE_ROLE_KEY']!);

  print('🏗️  Building Retail Chain...');

  try {
    // 2. Create Chain Owner
    final email = 'chain_owner_${DateTime.now().millisecondsSinceEpoch}@test.mbeck';
    final password = 'password123';
    
    final authRes = await supabase.auth.admin.createUser(
      AdminUserAttributes(email: email, password: password, emailConfirm: true)
    );
    
    if (authRes.user == null) {
      print('❌ Failed to create user');
      exit(1);
    }

    final ownerId = authRes.user!.id;
    print('👤 Created Owner: $email ($ownerId)');

    // 2.5 Sign In to pass RLS Policies (auth.uid() must match owner_id)
    await supabase.auth.signInWithPassword(email: email, password: password);
    print('🔑 Signed in as Owner to satisfy RLS.');

    // 3. Create Shops
    final shop1Id = ownerId; 
    final shop2Id = const Uuid().v4(); 
    
    // Shop 1 (Nairobi)
    try {
      await supabase.from('shops').insert({
        'id': shop1Id,
        'business_name': 'Mbeck Nairobi (HQ)',
        'owner_device_id': 'cloud_generated_$ownerId',
        'owner_id': ownerId,
        'password_hash': 'dummy_hash', // Legacy field required by DB
        'subscription_tier': 'ENTERPRISE',
        'subscription_status': 'ACTIVE',
        'joined_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      print('🏢 Created Shop 1: Nairobi (HQ)');
    } catch (e) {
      print('❌ Error creating Shop 1: $e');
    }

    // Shop 2 (Mombasa)
    try {
      await supabase.from('shops').insert({
        'id': shop2Id,
        'business_name': 'Mbeck Mombasa Branch',
        'owner_device_id': 'cloud_generated_branch',
        'owner_id': ownerId, 
        'password_hash': 'dummy_hash',
        'subscription_tier': 'PRO',
        'subscription_status': 'ACTIVE',
        'joined_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      print('🏢 Created Shop 2: Mombasa Branch');
    } catch (e) {
      print('❌ Error creating Shop 2: $e');
    }
    
    // 4. Create Shop Memberships (Owner Role)
    try {
      await supabase.from('shop_members').insert([
        {
          'shop_id': shop1Id,
          'device_id': ownerId, // Linking user UUID as device_id
          'user_name': 'Chain Owner',
          'role': 'OWNER',
          'permissions': {}, // Empty Map for JSONB?
          'joined_at': DateTime.now().toIso8601String(),
          'is_active': true
        },
        {
          'shop_id': shop2Id,
          'device_id': ownerId,
          'user_name': 'Chain Owner',
          'role': 'OWNER',
          'permissions': {},
          'joined_at': DateTime.now().toIso8601String(),
          'is_active': true
        }
      ]);
      print('🔑 Assigned Owner Role to both shops.');
    } catch (e) {
      print('❌ Error assigning roles: $e');
    }

    print('\n✅ Test Data Ready!');
    print('👉 Log in with: $email / $password');
    print('👉 Go to Settings -> Enterprise Dashboard');
    exit(0);

  } catch (e) {
    print('❌ Critical Error: $e');
    exit(1);
  }
}
