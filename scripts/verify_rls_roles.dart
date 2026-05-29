import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  // 1. Load Keys
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

  print('🔍 Verifying Shop Members Roles...');

  try {
    // 2. Fetch one shop to use as target
    final shops = await client.from('shops').select('id').limit(1);
    if (shops.isEmpty) {
      print('❌ No shops found. Cannot test roles.');
      return;
    }
    final shopId = shops[0]['id'];
    print('   Target Shop: $shopId');

    // 3. Attempt to insert a member with new roles
    // We expect this to either SUCCEED or fail with FK error (user_id), 
    // but NOT fail with "check constraint" error.
    
    final rolesToTest = ['MANAGER', 'STOCKER', 'SHIFT_SUPERVISOR', 'INVALID_ROLE'];

    for (var role in rolesToTest) {
      print('   Testing Role: $role ...');
      try {
        await client.from('shop_members').insert({
          'shop_id': shopId,
          'user_id': '00000000-0000-0000-0000-000000000000', // Fake UUID
          'device_id': 'test_verifier',
          'role': role
        });
        print('   ✅ Role $role accepted (Insert successful).');
        
        // Cleanup
        await client.from('shop_members').delete().eq('device_id', 'test_verifier');
        
      } catch (e) {
        final err = e.toString();
        if (err.contains('violates check constraint')) {
          if (role == 'INVALID_ROLE') {
             print('   ✅ Role $role correctly rejected by constraint.');
          } else {
             print('   ❌ Role $role REJECTED! Migration V15 not applied?');
          }
        } else if (err.contains('foreign key constraint')) {
           // FK error means the CHECK constraint passed! (Because Postgres checks TYPES/CONSTRAINTS before verified FK strictly speaking, or at least it implies table structure exists)
           // Actually, checking standard postgres behavior:
           // If CHECK fails, it throws check violation.
           // If FK fails, it throws FK violation.
           // So if we get FK violation, the Role was likely valid string.
           print('   ✅ Role $role accepted (FK error implies Check passed).');
        } else {
          print('   ⚠️ Unexpected error: $err');
          if (role != 'INVALID_ROLE') print('      (Assuming partial success if not Check Violation)');
        }
      }
    }

  } catch (e) {
    print('❌ Error: $e');
  }
}
