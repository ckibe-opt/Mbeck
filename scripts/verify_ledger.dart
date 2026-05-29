import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

void main() async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;
  final dbPath = join(Directory.current.path, 'shop_database_live.db');
  
  print('📚 Verifying Ledger in: $dbPath');

  final db = await databaseFactory.openDatabase(dbPath);
  
  try {
     final events = await db.query(
       'events', 
       orderBy: 'timestamp DESC',
       limit: 1
     );
     
     if (events.isNotEmpty) {
       final e = events.first;
       print('✅ Latest Event Found:');
       print('   Type: ${e['event_type']}');
       print('   ID: ${e['id']}');
       print('   Hash: ${e['hash']}');
       print('   Synced: ${e['synced']}');
       
       if (e['event_type'] == 'SALE') {
         print('   🎉 CONFIRMED: Sale recorded in Ledger.');
       } else {
         print('   ⚠️ Warning: Latest event is not a SALE. It is ${e['event_type']}');
       }
     } else {
       print('❌ Error: Events table is empty!');
     }
  } catch (e) {
    print('❌ Verification Error: $e');
  } finally {
    await db.close();
  }
}
