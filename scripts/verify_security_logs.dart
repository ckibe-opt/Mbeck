import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

void main() async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;
  final dbPath = join(Directory.current.path, 'shop_database_live.db');
  
  print('🛡️ Auditing Security Log in: $dbPath');

  final db = await databaseFactory.openDatabase(dbPath);
  
  try {
     final violations = await db.query(
       'events', 
       where: 'event_type = ?',
       whereArgs: ['SECURITY_VIOLATION'],
       orderBy: 'timestamp DESC'
     );
     
     if (violations.isEmpty) {
       print('✅ No Security Violations found in the Ledger.');
     } else {
       print('🚨 SECURITY VIOLATIONS FOUND (${violations.length}):');
       for (var v in violations) {
         print('   - [${v['timestamp']}] ${v['payload_raw']}');
       }
     }
     
     // Also verify standard sales exist to prove DB read works
     final sales = await db.query('events', where: 'event_type = ?', whereArgs: ['SALE']);
     print('ℹ️  Valid Sale Events present: ${sales.length}');

  } catch (e) {
    print('❌ Audit Error: $e');
  } finally {
    await db.close();
  }
}
