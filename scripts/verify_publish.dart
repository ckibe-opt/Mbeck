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

  print('🚀 Verifying Publishing Logic with Service Role...');

  const testShopId = 'test_shop_123';
  const testShopName = 'Verification Shop';

  try {
    // 1. Upsert Shop
    print('📝 Upserting shop...');
    await client.from('shops').upsert({
      'id': testShopId,
      'name': testShopName,
      'password_hash': 'mock_hash', // Required by Supabase schema
      'owner_device_id': 'mock_device', // Required by Supabase schema
      'updated_at': DateTime.now().toIso8601String(),
      'branding': {'primary': '#4CAF50'},
    });
    print('✅ Shop upserted.');

    // 2. Delete existing inventory for this shop
    print('🗑️ Deleting test inventory...');
    await client.from('inventory').delete().eq('shop_id', testShopId);

    // 3. Batch Insert Items
    print('📦 Inserting test inventory batch...');
    final items = [
      {'shop_id': testShopId, 'name': 'Test Item 1', 'sellingPrice': 100},
      {'shop_id': testShopId, 'name': 'Test Item 2', 'sellingPrice': 200},
    ];
    await client.from('inventory').insert(items);
    print('✅ Inventory inserted.');

    // 4. Verify Results
    final res = await client.from('inventory').select().eq('shop_id', testShopId);
    print('📊 Verification result: Found ${res.length} items.');
    for (var item in res) {
      print('   - ${item['name']}: ${item['sellingPrice']}');
    }

    if (res.length == 2) {
      print('🎊 CLOUD PUBLISHING INFRASTRUCTURE VERIFIED!');
    } else {
      print('❌ Verification failed: Expected 2 items, found ${res.length}');
    }

  } catch (e) {
    print('❌ Error during verification: $e');
  }
}
