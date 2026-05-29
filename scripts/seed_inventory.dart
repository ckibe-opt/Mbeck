import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

void main() async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;
  
  // MATCHING DbProvider logic:
  final dbPath = join(Directory.current.path, 'shop_database_live.db');
  
  print('🌱 Seeding Inventory in: $dbPath');

  final db = await databaseFactory.openDatabase(dbPath);
  
  try {
     // Check if item 1 exists
     final exists = await db.query('inventory', where: 'id = ?', whereArgs: [1]);
     if (exists.isNotEmpty) {
       print('   Product #1 already exists.');
     } else {
       await db.insert('inventory', {
         'id': 1,
         'name': 'Test Product',
         'sellingPrice': 100.0,
         'stock': 99,
         'category': 'Test',
         'barcode': '123456'
       });
       print('   ✅ Inserted Test Product (ID=1)');
     }
  } catch (e) {
    print('❌ Seeding Error: $e');
  } finally {
    await db.close();
  }
}
