import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  // 1. Load Keys (Manual Parsing to avoid dependency)
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
    if (parts.length >= 2) {
      // Join back in case value has =
      final key = parts[0].trim();
      final value = parts.sublist(1).join('=').trim();
      keys[key] = value;
    }
  }

  final supabaseUrl = keys['SUPABASE_URL'];
  final supabaseKey = keys['SUPABASE_SERVICE_ROLE_KEY'];

  if (supabaseUrl == null || supabaseKey == null) {
    print('❌ Error: Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
    exit(1);
  }

  // 2. Initialize
  final supabase = SupabaseClient(supabaseUrl, supabaseKey);

  print('🚀 Starting Owner Backfill...');

  try {
    // 3. Fetch All Shops (Filter in Dart to avoid API syntax issues)
    final response = await supabase.from('shops').select('id, business_name, owner_id');
    
    final shops = List<Map<String, dynamic>>.from(response as List);
    
    // Filter for NULL owner_id
    final targetShops = shops.where((s) => s['owner_id'] == null).toList();
    
    print('Found ${targetShops.length} shops needing update (out of ${shops.length} total).');

    if (targetShops.isEmpty) {
        print('✅ No backfill needed.');
        exit(0);
    }

    int successCount = 0;
    int failCount = 0;

    for (var shop in targetShops) {
      final shopId = shop['id'];
      String? ownerId;

      // Strategy A: Check if Shop ID is a valid Auth User UUID
      try {
        final userRes = await supabase.auth.admin.getUserById(shopId);
        if (userRes.user != null) {
          ownerId = userRes.user!.id;
          print('  MATCH: Shop $shopId maps to User $ownerId');
        }
      } catch (_) {
        // Not a user ID or not found
      }

      // Strategy B: If A failed, look for 'OWNER' in shop_members
      if (ownerId == null) {
         try {
           final memberRes = await supabase
              .from('shop_members')
              .select('device_id') 
              .eq('shop_id', shopId)
              .eq('role', 'OWNER')
              .maybeSingle();
            
           if (memberRes != null) {
             final candidateId = memberRes['device_id'];
             try {
                final userRes = await supabase.auth.admin.getUserById(candidateId);
                if (userRes.user != null) {
                  ownerId = candidateId;
                  print('  MATCH: Found Owner via Member Table: $ownerId');
                }
             } catch (_) {}
           }
         } catch (_) {}
      }

      // 4. Update
      if (ownerId != null) {
        await supabase
            .from('shops')
            .update({'owner_id': ownerId})
            .eq('id', shopId);
        print('  ✅ Updated Shop ${shop['business_name']}');
        successCount++;
      } else {
        print('  ⚠️ Could not find owner for Shop ${shop['business_name']} ($shopId)');
        failCount++;
      }
    }

    print('\n🏁 Backfill Complete. Updated: $successCount. Failed: $failCount.');
    exit(0);

  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
