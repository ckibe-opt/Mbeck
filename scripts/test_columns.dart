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

  // Use service role to query information_schema if possible, although PostgREST usually blocks this.
  // Instead, we can use the 'rpc' to get columns if the user has a helper function, 
  // or just look at the error from a failed select on a non-existent column.
  
  final client = SupabaseClient(keys['SUPABASE_URL']!, keys['SUPABASE_SERVICE_ROLE_KEY']!);

  print('🔍 Listing columns for table: inventory');

  try {
    // Attempting a select on a fake column sometimes lists valid ones in some environments,
    // but better to try and find a way to get schema.
    // Let's try to fetch one row and if it's empty, we try an insert with a lot of dummy columns 
    // to see what is allowed.
    
    // Actually, let's try to query the shops table again but look at the keys from the sample I got earlier.
    // Wait, I already have a sample for shops. Let's do the same for inventory if I can find ANY row.
    // If not, I will try to insert a dummy row with all possible columns and see which ones hit.
    
    final testColumns = ['item_name', 'name', 'price', 'sellingPrice', 'in_stock', 'stock_quantity', 'shop_id', 'id'];
    print('Testing columns: $testColumns');
    
    for(var col in testColumns) {
      try {
        await client.from('inventory').select(col).limit(1);
        print('✅ Column "$col" exists.');
      } catch (e) {
        print('❌ Column "$col" does not exist.');
      }
    }

  } catch (e) {
    print('❌ Error: $e');
  }
}
