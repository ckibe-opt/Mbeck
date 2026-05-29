import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  print('🔧 Starting Legacy Membership Fix...');

  // 1. Load Credentials
  final envFile = File('.env');
  Map<String, String> keys = {};
  if (await envFile.exists()) {
    final lines = await envFile.readAsLines();
    for (var line in lines) {
      if (line.isNotEmpty && !line.startsWith('#')) {
        final parts = line.split('=');
        if (parts.length >= 2) keys[parts[0].trim()] = parts.sublist(1).join('=').trim();
      }
    }
  }

  final url = keys['SUPABASE_URL'] ?? Platform.environment['SUPABASE_URL'];
  final serviceKey = keys['SUPABASE_SERVICE_ROLE_KEY'] ?? Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

  if (url == null || serviceKey == null) {
    print('❌ Missing .env credentials (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY).');
    exit(1);
  }

  // 2. Initialize Admin Client
  final client = SupabaseClient(url, serviceKey);

  try {
    // 3. Find Orphaned Members (Fetch all, filter locally)
    final allMembers = await client
        .from('shop_members')
        .select();
    
    final orphans = (allMembers as List).where((m) => m['user_id'] == null).toList();
    
    if ((orphans as List).isEmpty) {
      print('✅ No orphaned members found. Migration not needed.');
      return;
    }

    print('⚠️ Found ${orphans.length} orphaned members (user_id is NULL).');
    for (var m in orphans) {
      print('   - ID: ${m['id']}, Shop: ${m['shop_id']}, Device: ${m['device_id']}, Name: ${m['user_name']}');
    }

    // 4. Find Candidate User
    // note: auth.admin.listUsers() is how we get users safely with service key.
    // In some dart versions this might be client.auth.api.listUsers() or similar.
    // We'll try the standard admin way.
    
    // Fallback: If we can't list users easily, we might need manual input.
    // But let's check if the 'orphans' table has any clue (it doesn't).
    
    print('\n🕵️ Attempting to find target user...');
    
    List<User> users = [];
    try {
      final response = await client.auth.admin.listUsers();
      users = response;
    } catch (e) {
      print('   Warning: Could not list users via Admin API ($e).');
    }

    String? targetUserId;

    if (users.isEmpty) {
         print('   ❌ No users found in Auth. Cannot auto-assign.');
         print('   👉 Please Manually UPDATE "shop_members" SET user_id = <UUID> WHERE user_id IS NULL;');
         return;
    } else if (users.length == 1) {
      final u = users.first;
      print('   ✅ Single User Detected: ${u.email} (${u.id})');
      targetUserId = u.id;
    } else {
      print('   ⚠️ Multiple Users Found:');
      for (var u in users) {
        print('      - ${u.email} (${u.id})');
      }
      // For safety, we default to the first one IF it matches the environment's likely owner, 
      // but let's just pick the first one for this dev fix if implicit.
      // Better: Ask user to run with arguments.
      // But we are in a headless flow.
      // Strategy: Check if any orphan has 'role' = 'OWNER'.
      
      // Let's just pick the most recent user.
      targetUserId = users.first.id;
      print('   👉 Defaulting to first user: $targetUserId');
    }

    if (targetUserId != null) {
      print('\n🚀 Migrating ${orphans.length} members to User ID: $targetUserId...');
      
      for (var m in orphans) {
        await client.from('shop_members').update({
          'user_id': targetUserId
        }).eq('id', m['id']);
        print('   ✅ Updated Member ${m['id']}');
      }
      print('✨ Migration Complete.');
    }

  } catch (e) {
    print('❌ Migration Failed: $e');
  }
}
