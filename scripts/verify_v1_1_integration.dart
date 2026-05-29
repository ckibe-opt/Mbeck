import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:convert';

void main() async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;
  final dbPath = join(Directory.current.path, 'shop_database_live.db');
  
  print('🔍 Auditing V1.1.0 Integration (Shops Table) in: $dbPath');

  final db = await databaseFactory.openDatabase(dbPath);
  
  try {
     // 0. SELF-HEALING: Apply Migration if Missing
     // Since this script runs without the App, we must emulate DbProvider's migration
     // if the table is missing.
     try {
       await db.rawQuery('SELECT count(*) FROM shops');
     } catch (e) {
       print('⚠️ Table "shops" missing. Applying Migration v20 (Self-Healing)...');
       await db.execute('''
        CREATE TABLE IF NOT EXISTS shops (
          id TEXT PRIMARY KEY,
          business_name TEXT,
          theme_config TEXT,
          trust_score REAL,
          subscription_tier TEXT,
          updated_at INTEGER
        )
      ''');
       await db.setVersion(20);
       print('✅ Migration v20 applied successfully.');
     }

     // 1. Check Table Info (Schema)
     final tableInfo = await db.rawQuery('PRAGMA table_info(shops)');
     final columns = tableInfo.map((c) => c['name'].toString()).toSet();
     
     print('   Checking Schema Columns...');
     if (columns.contains('theme_config')) {
        print('   ✅ Column "theme_config" exists.');
     } else {
        print('   ❌ Column "theme_config" MISSING!');
     }
     
     if (columns.contains('trust_score')) {
        print('   ✅ Column "trust_score" exists.');
     } else {
        print('   ❌ Column "trust_score" MISSING!');
     }

     // 2. Check Data Integrity
     final shops = await db.query('shops', limit: 3);
     if (shops.isEmpty) {
       print('   ⚠️ Table "shops" is empty. No local shop data found.');
     } else {
       for (var shop in shops) {
         print('\n   🛒 Shop ID: ${shop['id']}');
         print('      Name: ${shop['name'] ?? shop['business_name']}');
         
         // Verify Trust Score
         final score = shop['trust_score'];
         print('      Trust Score: $score (${score.runtimeType})');
         
         // Verify Theme Config
         final themeRaw = shop['theme_config'];
         if (themeRaw != null && themeRaw is String) {
           try {
             final decoded = jsonDecode(themeRaw);
             print('      Theme Config: Valid JSON (${decoded.keys.length} keys)');
           } catch (e) {
             print('      ❌ Theme Config: INVALID JSON ($e)');
           }
         } else {
           print('      Theme Config: NULL or Invalid Type ($themeRaw)');
         }
       }
     }

  } catch (e) {
    print('❌ Audit Error: $e');
  } finally {
    await db.close();
  }
}
