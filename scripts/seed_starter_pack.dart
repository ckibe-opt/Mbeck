import 'dart:io';
import 'dart:convert';
import 'package:supabase/supabase.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

// Mbeck "Micro-Kiosk" Starter Pack
// These are the top 20 items found in almost every generic African kiosk.
const List<Map<String, dynamic>> STARTER_PACK = [
  {'name': 'Coca-Cola 500ml', 'category': 'Drinks', 'sellingPrice': 70, 'stock': 24},
  {'name': 'Bread (Festive/Supa Loaf)', 'category': 'Food', 'sellingPrice': 85, 'stock': 10},
  {'name': 'Milk 500ml', 'category': 'Dairy', 'sellingPrice': 65, 'stock': 12},
  {'name': 'Sugar 1kg', 'category': 'Pantry', 'sellingPrice': 220, 'stock': 5},
  {'name': 'Cooking Oil 1L', 'category': 'Pantry', 'sellingPrice': 350, 'stock': 3},
  {'name': 'Maize Flour 2kg', 'category': 'Food', 'sellingPrice': 210, 'stock': 5},
  {'name': 'Safaricom Airtime 50', 'category': 'Airtime', 'sellingPrice': 50, 'stock': 100},
  {'name': 'Safaricom Airtime 100', 'category': 'Airtime', 'sellingPrice': 100, 'stock': 100},
  {'name': 'Royco Cubes', 'category': 'Spices', 'sellingPrice': 10, 'stock': 50},
  {'name': 'Salt 500g', 'category': 'Pantry', 'sellingPrice': 30, 'stock': 10},
];

void main(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Usage: dart scripts/seed_starter_pack.dart <target_shop_id>');
    exit(1);
  }

  final targetShopId = args[0];
  print('🚀 Preparing to seed Starter Pack for Shop: $targetShopId');

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

  print('📦 Seeding 10 items (Pilot)...');

  final eventsToInsert = <Map<String, dynamic>>[];
  final inventoryToInsert = <Map<String, dynamic>>[];
  final uuid = Uuid();
  final timestamp = DateTime.now().millisecondsSinceEpoch;

  for (final item in STARTER_PACK) {
    // 1. Prepare Inventory Payload
    final payload = {
      'name': item['name'],
      'category': item['category'],
      'sellingPrice': item['sellingPrice'],
      'originalPrice': 0, // Default
      'stock': item['stock'],
      'imagePath': '',
    };
    
    // 2. Create Event (Valid Hash)
    final eventId = uuid.v4();
    final eventType = 'INVENTORY_CREATE';
    final deviceId = 'system_seeder_v1';
    
    final rawString = _encodeCanonical(payload);
    final hashInput = '$eventId|$eventType|$rawString|$timestamp|$targetShopId|$deviceId';
    final hash = sha256.convert(utf8.encode(hashInput)).toString();

    eventsToInsert.add({
      'id': eventId,
      'event_type': eventType,
      'payload': payload, // Supabase handles JSON conversion
      'payload_raw': rawString,
      'hash': hash,
      'timestamp': timestamp,
      'shop_id': targetShopId,
      'device_id': deviceId,
      'synced': 1, // Already in cloud
      'sync_attempts': 0,
      'failed': 0,
    });

    inventoryToInsert.add({
      ...item,
      'shop_id': targetShopId,
      'specification': 'Standard',
      'barcode': '',
      'imagePath': '',
    });
  }

  try {
    // 3. Insert Events (The Source of Truth)
    await client.from('events').insert(eventsToInsert);
    print('✅ Inserted ${eventsToInsert.length} EVENTS.');
    
  // 4. Manual Upsert (since unique constraint might be missing on Cloud)
    // await client.from('inventory').upsert(inventoryToInsert, onConflict: 'shop_id, name');
    
    int insertedCount = 0;
    int updatedCount = 0;

    for (var item in inventoryToInsert) {
      final name = item['name'];
      
      // Check existence
      final existing = await client
          .from('inventory')
          .select('id')
          .eq('shop_id', targetShopId)
          .eq('name', name)
          .maybeSingle();

      if (existing == null) {
        // Insert
        await client.from('inventory').insert(item);
        insertedCount++;
      } else {
        // Update (Optional, just stock or price)
        await client
            .from('inventory')
            .update({
              'stock': item['stock'],
              'sellingPrice': item['sellingPrice']
            })
            .eq('id', existing['id']);
        updatedCount++;
      }
    }

    print('✅ Inventory Sync: Inserted $insertedCount, Updated $updatedCount.');
    print('📲 The Seller App will now PULL these items automatically!');
  } catch (e) {
    print('❌ Error seeding data: $e');
  }
}

/// Start Canonical Encoding Helper (Copied from Event.dart)
String _encodeCanonical(Map<String, dynamic> map) {
  final sortedKeys = map.keys.toList()..sort();
  final sorted = <String, dynamic>{};
  for (final key in sortedKeys) {
    final value = map[key];
    if (value is Map<String, dynamic>) {
       // Recursive not needed for this simple payload but good practice
       sorted[key] = value; 
    } else {
      sorted[key] = value;
    }
  }
  return jsonEncode(sorted);
}
// End Helper
