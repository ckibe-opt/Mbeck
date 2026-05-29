import 'dart:io';
import 'package:csv/csv.dart';
import 'db/db_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'models/event.dart';
import 'services/device_service.dart';
import 'services/event_processor.dart';

// 1. Helper to clean messy data
String cleanValue(dynamic value) {
  if (value == null) return '';
  String str = value.toString().trim();

  // Remove asterisks (*)
  str = str.replaceAll('*', '');
  
  // Remove commas (,) which break ID numbers like "24,675,554"
  str = str.replaceAll(',', ''); 

  // If multiple phones separated by '/', take the first one
  if (str.contains('/')) {
    str = str.split('/')[0].trim();
  }

  return str;
}

Future<List<String>> importCustomersFromCsvFile(File csvFile) async {
  try {
    final content = await csvFile.readAsString();
    final rows = const CsvToListConverter().convert(content, eol: '\n');
    if (rows.isEmpty) return ['Empty CSV file'];

    // 2. Normalize headers
    final headers = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();

    // 3. Find column indexes based on your specific CSV headers
    int? findIndex(List<String> possibleNames) {
      for (var name in possibleNames) {
        int idx = headers.indexOf(name);
        if (idx != -1) return idx;
        idx = headers.indexWhere((h) => h.contains(name));
        if (idx != -1) return idx;
      }
      return null;
    }

    // Match your specific headers
    final idxName = findIndex(['name', 'customer']);
    final idxPhone = findIndex(['phone', 'mobile']);
    final idxId = findIndex(['id_no', 'id', 'national']);
    final idxBank = findIndex(['bank_account', 'bank', 'account']);
    final idxNotes = findIndex(['notes', 'comment', 'extra']);
    final idxAgent = findIndex(['agent']);
    final idxStore = findIndex(['store', 'branch']);

    final errors = <String>[];
    final dataRows = rows.skip(1).toList();
    int importedCount = 0;

    final db = await DbProvider.db;
    final shopId = await DeviceService.getShopId();
    final deviceId = await DeviceService.getDeviceId();
    final batch = db.batch();
    final queuedRowIndices = <int>[];

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];

      String getValue(int? index) {
        if (index != null && index < row.length) {
          return cleanValue(row[index]);
        }
        return '';
      }

      final name = getValue(idxName);
      final phone = getValue(idxPhone);

      // Skip rows that don't have at least a name or phone
      if (name.isEmpty && phone.isEmpty) continue;

      final customerName = name.isEmpty ? 'Unknown' : name;
      final customerPhone = phone;
      final idNo = getValue(idxId);
      final bankAccount = getValue(idxBank);
      final notes = getValue(idxNotes);
      final agent = getValue(idxAgent);
      final store = getValue(idxStore).isEmpty ? 'Main' : getValue(idxStore);
      final createdAt = DateTime.now().millisecondsSinceEpoch;

      batch.insert('customer', {
        'name': customerName,
        'phone': customerPhone,
        'id_no': idNo,
        'bank_account': bankAccount,
        'notes': notes,
        'agent': agent,
        'store': store,
        'createdAt': createdAt,
      });

      final event = Event.create(
        eventType: 'CUSTOMER_CREATE',
        payload: {
          'name': customerName,
          'phone': customerPhone,
          'id_no': idNo,
          'bank_account': bankAccount,
          'notes': notes,
          'agent': agent,
          'store': store,
          'createdAt': createdAt,
        },
        shopId: shopId,
        deviceId: deviceId,
        timestamp: createdAt,
      );

      batch.insert('events', event.toMap());
      queuedRowIndices.add(i + 2);
    }

    if (queuedRowIndices.isNotEmpty) {
      try {
        final results = await batch.commit(continueOnError: true);
        for (int j = 0; j < queuedRowIndices.length; j++) {
          final customerRes = results[2 * j];
          final eventRes = results[2 * j + 1];
          final rowNum = queuedRowIndices[j];
          if (customerRes is DatabaseException || customerRes is Exception) {
            errors.add('Row $rowNum (Customer): $customerRes');
          } else if (eventRes is DatabaseException || eventRes is Exception) {
            errors.add('Row $rowNum (Event): $eventRes');
          } else {
            importedCount++;
          }
        }
        if (importedCount > 0) {
          EventProcessor.notify('CUSTOMER_CREATE');
        }
      } catch (e) {
        errors.add('Batch commit failed: $e');
      }
    }

    if (importedCount == 0 && errors.isEmpty) {
      return ['No valid data found. Check column headers.'];
    }

    return errors;

  } catch (e) {
    return ['File read error: $e'];
  }
}
