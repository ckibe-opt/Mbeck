import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  // Load Env
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  final keys = <String, String>{};
  for (var line in lines) {
    var parts = line.split('=');
    if (parts.length >= 2) keys[parts[0].trim()] = parts.sublist(1).join('=').trim();
  }
  
  final supabase = SupabaseClient(keys['SUPABASE_URL']!, keys['SUPABASE_SERVICE_ROLE_KEY']!);

  // Find the most recent chain owner
  final users = await supabase.auth.admin.listUsers();
  
  // Sort by created_at desc (local sort since listUsers is paginated but we just grab page 1)
  // Actually listUsers returns User objects.
  final chainOwners = users.where((u) => u.email?.startsWith('chain_owner_') ?? false).toList();
  chainOwners.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  if (chainOwners.isEmpty) {
    print('❌ No chain owner found.');
    exit(1);
  }

  final owner = chainOwners.first;
  print('👤 Checking Chain Owner: ${owner.email} (${owner.id})');

  // Check Shops
  final shopsResponse = await supabase.from('shops').select().eq('owner_id', owner.id);
  final shops = shopsResponse as List;
  
  print('🏢 Shops Found: ${shops.length}');
  for (var s in shops) {
    print('   - ${s['business_name']} (ID: ${s['id']})');
  }

  if (shops.isEmpty) {
    print('❌ No shops linked to this owner. Insertion failed.');
  } else {
    print('✅ Chain Data Verified!');
  }
  exit(0);
}
