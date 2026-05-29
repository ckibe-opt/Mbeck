import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import '../db/db_provider.dart';
import '../theme/design_system.dart';

bool _isSupportedImage(String filePath) {
  final ext = path.extension(filePath).toLowerCase();
  return ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp';
}

// --- BACKGROUND TASK ---
Future<void> _zipFiles(Map<String, String> paths) async {
  final dbPath = paths['dbPath']!;
  final appDirPath = paths['appDirPath']!;
  final zipPath = paths['zipPath']!;

  final encoder = ZipFileEncoder();
  encoder.create(zipPath);

  // 1. Add Database
  final dbFile = File(dbPath);
  if (dbFile.existsSync()) {
    encoder.addFile(dbFile, 'shop_database_live.db');
  }

  // 2. Add Images (filenames only)
  final appDir = Directory(appDirPath);
  if (appDir.existsSync()) {
    final files = appDir.listSync();
    for (var file in files) {
      if (file is File && _isSupportedImage(file.path)) {
        // Add with filename only (no subdirectories)
        encoder.addFile(file, path.basename(file.path));
      }
    }
  }

  encoder.close();
}

class BackupService {

  // =========================================================
  // EXPORT: Zips DB + Images (Runs in background)
  // =========================================================
  static Future<void> exportDatabase(BuildContext context) async {
    try {
      // 1. Setup Paths
      final databasesPath = await getDatabasesPath();
      final dbPath = path.join(databasesPath, 'shop_database_live.db');
      final dbFile = File(dbPath);
      final appDir = await getApplicationDocumentsDirectory();

      if (!await dbFile.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export.'))
          );
        }
        return;
      }

      // Show Loading Dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSkeleton.box(width: 48, height: 48),
                    const SizedBox(height: 16),
                    const Text("Compressing Backup..."),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // 2. Prepare Zip Path
      await DbProvider.close();

      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final zipName = 'shop_backup_$dateStr.zip';
      final tempDir = await getTemporaryDirectory();
      final zipPath = path.join(tempDir.path, zipName);

      // 3. Run Zipping in Background Isolate
      await compute(_zipFiles, {
        'dbPath': dbPath,
        'appDirPath': appDir.path,
        'zipPath': zipPath,
      });

      // Close Loading Dialog
      if (context.mounted) {
        Navigator.pop(context); 
      }

      // 4. Share the Zip
      await Share.shareXFiles(
        [XFile(zipPath)], 
        text: 'Mpesa Shop Full Backup'
      );

      // Re-open DB for continued use
      await DbProvider.reloadDatabase();

    } catch (e) {
      // Ensure dialog is closed if error occurs
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'))
        );
      }
      
      // Try to reopen DB just in case
      await DbProvider.reloadDatabase();
    }
  }

  // =========================================================
  // IMPORT: Unzips + Restores DB (NO PATH FIXING NEEDED)
  // =========================================================
  static Future<bool> importDatabase(BuildContext context) async {
    try {
      // 1. Pick File
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'db'],
      );

      if (result == null || result.files.single.path == null) return false;
      final File selectedFile = File(result.files.single.path!);
      final isZip = selectedFile.path.toLowerCase().endsWith('.zip');

      // 2. Confirm
      if (!context.mounted) return false;
      
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Restore Backup?"),
          content: Text(
            isZip 
              ? "This is a FULL backup (Images + Data).\nAll current data will be replaced."
              : "This is an OLD backup (Data only).\nImages might be missing."
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                "RESTORE",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return false;

      // Show Loading
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSkeleton.box(width: 48, height: 48),
                    const SizedBox(height: 16),
                    const Text("Restoring Data..."),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // 3. Close & Clean Old Data
      final databasesPath = await getDatabasesPath();
      final dbPath = path.join(databasesPath, 'shop_database_live.db');
      final appDir = await getApplicationDocumentsDirectory();

      await DbProvider.close();
      await Future.delayed(const Duration(milliseconds: 300));

      // Delete old DB files
      try {
        if (await File(dbPath).exists()) await File(dbPath).delete();
        if (await File('$dbPath-wal').exists()) {
          await File('$dbPath-wal').delete();
        }
        if (await File('$dbPath-shm').exists()) {
          await File('$dbPath-shm').delete();
        }
      } catch (e) {
        debugPrint("Cleanup error: $e");
      }

      // Delete old images
      try {
        final appDirContents = appDir.listSync();
        for (var file in appDirContents) {
          if (file is File && _isSupportedImage(file.path)) {
            await file.delete();
          }
        }
      } catch (e) {
        debugPrint("Image cleanup error: $e");
      }

      // 4. Restore Logic
      if (isZip) {
        // --- ZIP RESTORE ---
        final bytes = await selectedFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        for (final file in archive) {
          if (file.isFile) {
            final filename = file.name;
            
            if (filename.endsWith('.db')) {
              // Extract DB
              File(dbPath)
                ..createSync(recursive: true)
                ..writeAsBytesSync(file.content as List<int>);
            } else if (_isSupportedImage(filename)) {
              // Extract Image to app directory (filename matches DB)
              final imagePath = path.join(appDir.path, path.basename(filename));
              File(imagePath)
                ..createSync()
                ..writeAsBytesSync(file.content as List<int>);
            }
          }
        }
      } else {
        // --- LEGACY DB ONLY RESTORE ---
        await selectedFile.copy(dbPath);
      }

      // 5. Reopen Database (migrations will run automatically)
      await DbProvider.reloadDatabase();
      
      // NOTE: No path fixing needed because we now store filenames only
      // The database migration in db_provider.dart already handles the 
      // visual_vector column, so restored backups work immediately

      // Close Loading
      if (context.mounted) {
        Navigator.pop(context);
      }

      // 6. Success & Restart
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text("Success!"),
              ],
            ),
            content: Text(
              isZip 
                ? "✅ Data and images restored successfully!"
                : "✅ Database restored (images may be missing)"
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (route) => false,
                  );
                },
                child: const Text("RELOAD APP"),
              ),
            ],
          ),
        );
      }

      return true;

    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'))
        );
      }
      
      return false;
    }
  }

  // NEW: Verify backup integrity before importing
  static Future<Map<String, dynamic>> verifyBackupIntegrity(File backupFile) async {
    try {
      final isZip = backupFile.path.toLowerCase().endsWith('.zip');
      
      if (!isZip) {
        return {
          'valid': true,
          'type': 'legacy_db',
          'has_images': false,
          'item_count': 0,
        };
      }

      // Analyze ZIP contents
      final bytes = await backupFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      bool hasDatabase = false;
      int imageCount = 0;
      
      for (final file in archive) {
        if (file.name.endsWith('.db')) hasDatabase = true;
        if (_isSupportedImage(file.name)) imageCount++;
      }

      return {
        'valid': hasDatabase,
        'type': 'full_backup',
        'has_images': imageCount > 0,
        'image_count': imageCount,
      };
      
    } catch (e) {
      return {
        'valid': false,
        'error': e.toString(),
      };
    }
  }
}
