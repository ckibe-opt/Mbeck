import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class CloudStorageService {
  static const String bucketName = 'mbeck-assets';

  /// Ensure bucket exists (best effort, may fail if RLS prevents bucket creation)
  static Future<void> _ensureBucketExists() async {
    final supabase = Supabase.instance.client;
    try {
      final buckets = await supabase.storage.listBuckets();
      bool exists = false;
      for (var b in buckets) {
        if (b.name == bucketName) exists = true;
      }
      if (!exists) {
        await supabase.storage.createBucket(bucketName, const BucketOptions(public: true));
        debugPrint('☁️ Created new public bucket: $bucketName');
      }
    } catch (e) {
      debugPrint('☁️ Check bucket failed (might be permissions, ensure it exists in dashboard): $e');
    }
  }

  /// Uploads a locally compressed image file to Supabase Storage and returns the public URL.
  /// If the user is not authenticated or the network fails, it returns null.
  /// If [imagePath] is already a cloud URL, it returns it instantly.
  static Future<String?> uploadImage(String? imagePath, {required String folder}) async {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http')) return imagePath;

    final supabase = Supabase.instance.client;
    // Check if user is linked to cloud
    if (supabase.auth.currentUser == null) return imagePath; // Return local path if offline

    try {
      await _ensureBucketExists();

      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('⚠️ File not found for upload: $imagePath');
        return imagePath;
      }

      final ext = p.extension(imagePath);
      final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_${supabase.auth.currentUser!.id.substring(0, 8)}$ext';
      final storagePath = '$folder/$uniqueName';

      debugPrint('☁️ Uploading image to $bucketName/$storagePath ...');
      
      await supabase.storage.from(bucketName).upload(storagePath, file, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));

      final publicUrl = supabase.storage.from(bucketName).getPublicUrl(storagePath);
      debugPrint('✅ Upload complete! Cloud URL: $publicUrl');
      
      return publicUrl;
    } catch (e) {
      debugPrint('⚠️ Cloud image upload failed: $e');
      return imagePath; // Abort cloud URL, fallback to local path
    }
  }
}
