import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../db/db_provider.dart';
import 'event_service.dart';
import 'security_service.dart';
import 'cloud_storage_service.dart';

/// Service for managing entertainment assets and sessions.
///
/// Handles:
/// - CRUD for assets (pool tables, PS stations, swimming lanes, etc.)
/// - Session lifecycle: start → running → stop → billed
/// - Timer-based and flat-rate billing
/// - Revenue calculation per asset/category
class EntertainmentService {
  // ========== ASSET TYPES ==========

  static Future<List<Map<String, dynamic>>> getAssetTypesWithDetails() async {
    final db = await DbProvider.db;
    return await db.rawQuery('''
      SELECT at_.*,
             COUNT(DISTINCT a.id) as asset_count,
             (SELECT COUNT(*) FROM entertainment_asset_type_images WHERE asset_type_id = at_.id) as image_count
      FROM entertainment_asset_types at_
      LEFT JOIN entertainment_assets a ON a.asset_type_id = at_.id AND a.is_active = 1
      WHERE at_.is_active = 1
      GROUP BY at_.id
      ORDER BY at_.category ASC, at_.name ASC
    ''');
  }

  static Future<List<Map<String, dynamic>>> getActiveAssetTypes() async {
    final db = await DbProvider.db;
    return await db.query(
      'entertainment_asset_types',
      where: 'is_active = 1',
      orderBy: 'category ASC, name ASC',
    );
  }

  static Future<int> createAssetType({
    required String name,
    required String category,
    required String billingType,
    required double ratePerHour,
    double flatRate = 0,
    String? description,
    bool isPublished = false,
  }) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final id = await db.insert('entertainment_asset_types', {
      'cloud_id': const Uuid().v4(),
      'name': name,
      'category': category,
      'asset_type': billingType,
      'rate_per_hour': ratePerHour,
      'flat_rate': flatRate,
      'description': description,
      'is_published': isPublished ? 1 : 0,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    EventService.emitEvent(
      eventType: 'ENTERTAINMENT_ASSET_TYPE_CREATE',
      payload: {'asset_type_id': id, 'name': name, 'category': category},
    );

    debugPrint('🎮 Created asset type: $name ($category)');
    return id;
  }

  static Future<void> updateAssetType(int id, Map<String, dynamic> updates) async {
    final db = await DbProvider.db;
    updates['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.update('entertainment_asset_types', updates, where: 'id = ?', whereArgs: [id]);

    EventService.emitEvent(
      eventType: 'ENTERTAINMENT_ASSET_TYPE_UPDATE',
      payload: {'asset_type_id': id, ...updates},
    );
  }

  static Future<List<Map<String, dynamic>>> getAssetTypeImages(int typeId) async {
    final db = await DbProvider.db;
    return await db.query(
      'entertainment_asset_type_images',
      where: 'asset_type_id = ?',
      whereArgs: [typeId],
      orderBy: 'sort_order ASC',
    );
  }

  static Future<void> saveAssetTypeImages(int typeId, List<String> imagePaths) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Delete old images
    await db.delete('entertainment_asset_type_images',
        where: 'asset_type_id = ?', whereArgs: [typeId]);

    for (int i = 0; i < imagePaths.length; i++) {
      final cloudUrl = await CloudStorageService.uploadImage(imagePaths[i], folder: 'entertainment');
      final finalPath = (cloudUrl != null && cloudUrl.startsWith('http')) ? cloudUrl : imagePaths[i];
      
      await db.insert('entertainment_asset_type_images', {
        'asset_type_id': typeId,
        'image_path': finalPath,
        'sort_order': i,
        'created_at': now,
      });
    }
  }

  /// Batch-create multiple assets from a type
  static Future<int> batchCreateAssets({
    required int assetTypeId,
    required int startNumber,
    required int endNumber,
    String prefix = '',
  }) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final types = await db.query('entertainment_asset_types',
        where: 'id = ?', whereArgs: [assetTypeId]);
    if (types.isEmpty) throw Exception('Asset type not found');
    final type = types.first;

    final typeName = type['name'] as String;
    final namePrefix = prefix.isNotEmpty ? prefix : typeName;

    int created = 0;
    await db.transaction((txn) async {
      for (int num = startNumber; num <= endNumber; num++) {
        final name = '$namePrefix $num';
        await txn.insert('entertainment_assets', {
          'cloud_id': const Uuid().v4(),
          'name': name,
          'category': type['category'],
          'asset_type': type['asset_type'],
          'asset_type_id': assetTypeId,
          'rate_per_hour': type['rate_per_hour'],
          'flat_rate': type['flat_rate'],
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
        created++;
      }
    });

    EventService.emitEvent(
      eventType: 'ENTERTAINMENT_ASSETS_BATCH_CREATE',
      payload: {
        'asset_type_id': assetTypeId,
        'type_name': typeName,
        'start': startNumber,
        'end': endNumber,
        'count': created,
      },
    );

    debugPrint('🎮 Batch created $created assets: $namePrefix $startNumber-$endNumber ($typeName)');
    return created;
  }

  // ========== ASSET MANAGEMENT ==========

  /// Get all assets, optionally filtered by category
  static Future<List<Map<String, dynamic>>> getAssets({
    String? category,
    int? assetTypeId,
    bool activeOnly = true,
  }) async {
    final db = await DbProvider.db;
    String where = '';
    List<dynamic> whereArgs = [];

    if (activeOnly) {
      where = 'a.is_active = 1';
    }
    if (assetTypeId != null) {
      where += where.isNotEmpty ? ' AND a.asset_type_id = ?' : 'a.asset_type_id = ?';
      whereArgs.add(assetTypeId);
    } else if (category != null && category != 'All') {
      where += where.isNotEmpty ? ' AND a.category = ?' : 'a.category = ?';
      whereArgs.add(category);
    }

    return await db.rawQuery('''
      SELECT a.*,
             at_.name as type_name,
             at_.is_published as type_is_published,
             (SELECT image_path FROM entertainment_asset_type_images
              WHERE asset_type_id = a.asset_type_id ORDER BY sort_order ASC LIMIT 1) as type_image
      FROM entertainment_assets a
      LEFT JOIN entertainment_asset_types at_ ON a.asset_type_id = at_.id
      ${where.isNotEmpty ? 'WHERE $where' : ''}
      ORDER BY a.category ASC, a.sort_order ASC, a.name ASC
    ''', whereArgs);
  }

  /// Get all unique asset categories
  static Future<List<String>> getCategories() async {
    final db = await DbProvider.db;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM entertainment_asset_types WHERE is_active = 1 ORDER BY category ASC',
    );
    if (result.isEmpty) {
      // Fallback to assets table for non-migrated data
      final fallback = await db.rawQuery(
        'SELECT DISTINCT category FROM entertainment_assets WHERE is_active = 1 ORDER BY category ASC',
      );
      return fallback.map((r) => r['category'] as String).toList();
    }
    return result.map((r) => r['category'] as String).toList();
  }

  /// Create a new asset
  static Future<int> createAsset({
    required String name,
    required String category,
    required String assetType, // 'hourly' or 'flat'
    required double ratePerHour,
    double flatRate = 0,
    String? description,
    String? imagePath,
    int? assetTypeId,
  }) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cloudId = const Uuid().v4();

    final cloudUrl = await CloudStorageService.uploadImage(imagePath, folder: 'entertainment');
    final finalPath = (cloudUrl != null && cloudUrl.startsWith('http')) ? cloudUrl : imagePath;

    final id = await db.insert('entertainment_assets', {
      'cloud_id': cloudId,
      'source_module': 'entertainment',
      'name': name,
      'category': category,
      'asset_type': assetType,
      'asset_type_id': assetTypeId,
      'rate_per_hour': ratePerHour,
      'flat_rate': flatRate,
      'description': description,
      'image_path': finalPath,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    // Emit event for LAN sync
    EventService.emitEvent(
      eventType: 'ENTERTAINMENT_ASSET_CREATE',
      payload: {
        'cloud_id': cloudId,
        'source_module': 'entertainment',
        'id': id,
        'name': name,
        'category': category,
        'asset_type': assetType,
        'rate_per_hour': ratePerHour,
        'flat_rate': flatRate,
      },
    );

    debugPrint('🎮 Created asset: $name ($category)');
    return id;
  }

  /// Update an existing asset
  static Future<void> updateAsset(int id, Map<String, dynamic> updates) async {
    final db = await DbProvider.db;
    updates['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    if (updates.containsKey('image_path') && updates['image_path'] != null) {
      final cloudUrl = await CloudStorageService.uploadImage(updates['image_path'], folder: 'entertainment');
      updates['image_path'] = (cloudUrl != null && cloudUrl.startsWith('http')) ? cloudUrl : updates['image_path'];
    }

    await db.update('entertainment_assets', updates,
        where: 'id = ?', whereArgs: [id]);

    EventService.emitEvent(
      eventType: 'ENTERTAINMENT_ASSET_UPDATE',
      payload: {'asset_id': id, ...updates},
    );
  }

  /// Soft-delete an asset (set is_active = 0)
  static Future<void> deactivateAsset(int id) async {
    await updateAsset(id, {'is_active': 0});
  }

  static Future<void> toggleAssetPublished(int id, bool published) async {
    await updateAsset(id, {'is_published': published ? 1 : 0});
  }

  static Future<void> toggleAssetTypePublished(int id, bool published) async {
    await updateAssetType(id, {'is_published': published ? 1 : 0});
  }

  // ========== SESSION MANAGEMENT ==========

  /// Start a new session on an asset
  static Future<int> startSession({
    required int assetId,
    String? customerName,
    String? notes,
  }) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Get asset info for billing
    final asset = await db.query('entertainment_assets',
        where: 'id = ?', whereArgs: [assetId]);
    if (asset.isEmpty) throw Exception('Asset not found');

    final assetData = asset.first;
    final billingType = assetData['asset_type'] as String;
    final rate = billingType == 'flat'
        ? (assetData['flat_rate'] as num).toDouble()
        : (assetData['rate_per_hour'] as num).toDouble();

    final id = await db.insert('entertainment_sessions', {
      'cloud_id': const Uuid().v4(),
      'source_module': 'entertainment',
      'asset_id': assetId,
      'customer_name': customerName,
      'started_at': now,
      'billing_type': billingType,
      'rate': rate,
      'total_amount': billingType == 'flat' ? rate : 0,
      'status': 'active',
      'notes': notes,
      'created_at': now,
    });

    // Emit event for LAN sync
    EventService.emitEvent(
      eventType: 'ENTERTAINMENT_SESSION_START',
      payload: {
        'source_module': 'entertainment',
        'session_id': id,
        'asset_id': assetId,
        'asset_name': assetData['name'],
        'customer_name': customerName,
        'billing_type': billingType,
        'rate': rate,
        'started_at': now,
      },
    );

    debugPrint('▶️ Session #$id started on asset $assetId');
    return id;
  }

  /// Stop an active session and calculate final bill
  static Future<Map<String, dynamic>> stopSession(int sessionId) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Get session
    final sessions = await db.query('entertainment_sessions',
        where: 'id = ?', whereArgs: [sessionId]);
    if (sessions.isEmpty) throw Exception('Session not found');

    final session = sessions.first;
    if (session['status'] != 'active' && session['status'] != 'paused') {
      throw Exception('Session is not active or paused');
    }

    final startedAt = session['started_at'] as int;
    final billingType = session['billing_type'] as String;
    final rate = (session['rate'] as num).toDouble();
    
    final totalPausedSec = session['total_paused_seconds'] as int? ?? 0;
    final lastPausedAt = session['last_paused_at'] as int?;
    
    int currentPausedSec = totalPausedSec;
    if (session['status'] == 'paused' && lastPausedAt != null) {
      currentPausedSec += ((now - lastPausedAt) / 1000).floor();
    }
    final currentPausedMs = currentPausedSec * 1000;

    double totalAmount;
    if (billingType == 'flat') {
      totalAmount = rate;
    } else {
      // Calculate duration in hours (round up to nearest 15 min by default)
      final durationMs = (now - startedAt) - currentPausedMs;
      final durationMinutes = (durationMs > 0 ? durationMs : 0) / 60000;
      final billableMinutes = _roundUpMinutes(durationMinutes, 15);
      final billableHours = billableMinutes / 60;
      totalAmount = billableHours * rate;
    }

    // Update session
    await db.update(
      'entertainment_sessions',
      {
        'ended_at': now,
        'total_amount': totalAmount,
        'status': 'completed',
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    // Record as a sale transaction for unified reporting
    final assetId = session['asset_id'] as int;
    final assetRows = await db.query('entertainment_assets',
        where: 'id = ?', whereArgs: [assetId]);
    final assetName =
        assetRows.isNotEmpty ? assetRows.first['name'] as String : 'Unknown';

    final totalActiveMs = (now - startedAt) - currentPausedMs;
    final durationMin = ((totalActiveMs > 0 ? totalActiveMs : 0) / 60000).round();
    final details = 'Session: $assetName (${durationMin}min)';

    final signature = await SecurityService().signTransaction(
      timestamp: now,
      totalAmount: totalAmount,
      type: 'sale',
      details: details,
    );

    await db.insert('txn', {
      'type': 'sale',
      'totalAmount': totalAmount.round(),
      'details': details,
      'timestamp': now,
      'receiptSignature': signature,
      'source_module': 'entertainment',
    });

    // Emit event for LAN sync
    EventService.emitEvent(
      eventType: 'ENTERTAINMENT_SESSION_COMPLETE',
      payload: {
        'session_id': sessionId,
        'asset_id': assetId,
        'asset_name': assetName,
        'duration_minutes': durationMin,
        'total_amount': totalAmount,
        'source_module': 'entertainment',
      },
    );

    debugPrint(
        '⏹️ Session #$sessionId completed: KSH ${totalAmount.toStringAsFixed(0)} ($durationMin min)');

    return {
      'session_id': sessionId,
      'asset_name': assetName,
      'duration_minutes': durationMin,
      'total_amount': totalAmount,
    };
  }

  /// Get all active sessions with asset info
  static Future<List<Map<String, dynamic>>> getActiveSessions() async {
    final db = await DbProvider.db;
    return await db.rawQuery('''
      SELECT s.*, a.name as asset_name, a.category as asset_category, a.image_path as asset_image
      FROM entertainment_sessions s
      JOIN entertainment_assets a ON s.asset_id = a.id
      WHERE s.status IN ('active', 'paused')
      ORDER BY s.started_at ASC
    ''');
  }

  /// Get session history (completed sessions), optionally for a specific asset
  static Future<List<Map<String, dynamic>>> getSessionHistory({
    int? assetId,
    int? limit,
  }) async {
    final db = await DbProvider.db;
    String sql = '''
      SELECT s.*, a.name as asset_name, a.category as asset_category
      FROM entertainment_sessions s
      JOIN entertainment_assets a ON s.asset_id = a.id
      WHERE s.status = 'completed'
    ''';

    List<dynamic> args = [];
    if (assetId != null) {
      sql += ' AND s.asset_id = ?';
      args.add(assetId);
    }

    sql += ' ORDER BY s.ended_at DESC';

    if (limit != null) {
      sql += ' LIMIT ?';
      args.add(limit);
    }

    return await db.rawQuery(sql, args);
  }

  /// Get asset status overview with aggregated active session counts.
  /// Each row = one asset + how many people are currently using it.
  static Future<List<Map<String, dynamic>>> getAssetStatusBoard() async {
    final db = await DbProvider.db;
    return await db.rawQuery('''
      SELECT 
        a.*,
        COALESCE(agg.active_count, 0) as active_count,
        agg.earliest_start,
        agg.total_running_rate
      FROM entertainment_assets a
      LEFT JOIN (
        SELECT 
          asset_id,
          COUNT(*) as active_count,
          MIN(started_at) as earliest_start,
          SUM(rate) as total_running_rate
        FROM entertainment_sessions
        WHERE status IN ('active', 'paused')
        GROUP BY asset_id
      ) agg ON agg.asset_id = a.id
      WHERE a.is_active = 1
      ORDER BY a.category ASC, a.sort_order ASC, a.name ASC
    ''');
  }

  /// Get all active sessions for a specific asset (for drill-down view)
  static Future<List<Map<String, dynamic>>> getActiveSessionsForAsset(int assetId) async {
    final db = await DbProvider.db;
    return await db.rawQuery('''
      SELECT s.*, a.name as asset_name, a.category as asset_category
      FROM entertainment_sessions s
      JOIN entertainment_assets a ON s.asset_id = a.id
      WHERE s.asset_id = ? AND s.status IN ('active', 'paused')
      ORDER BY s.started_at ASC
    ''', [assetId]);
  }

  /// Stop all active sessions on an asset at once (e.g., pool closing time)
  static Future<List<Map<String, dynamic>>> stopAllSessionsForAsset(int assetId) async {
    final db = await DbProvider.db;
    final activeSessions = await db.rawQuery(
        'SELECT * FROM entertainment_sessions WHERE asset_id = ? AND status IN (\'active\', \'paused\')', [assetId]);
    
    final results = <Map<String, dynamic>>[];
    for (final session in activeSessions) {
      final result = await stopSession(session['id'] as int);
      results.add(result);
    }
    return results;
  }

  /// Get today's revenue from entertainment sessions
  static Future<double> getTodayRevenue() async {
    final db = await DbProvider.db;
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as revenue
      FROM entertainment_sessions
      WHERE status = 'completed' AND ended_at >= ?
    ''', [startOfDay]);

    return (result.first['revenue'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get revenue breakdown by category for today
  static Future<Map<String, double>> getTodayRevenueByCategory() async {
    final db = await DbProvider.db;
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final result = await db.rawQuery('''
      SELECT a.category, COALESCE(SUM(s.total_amount), 0) as revenue
      FROM entertainment_sessions s
      JOIN entertainment_assets a ON s.asset_id = a.id
      WHERE s.status = 'completed' AND s.ended_at >= ?
      GROUP BY a.category
    ''', [startOfDay]);

    final breakdown = <String, double>{};
    for (final row in result) {
      breakdown[row['category'] as String] =
          (row['revenue'] as num).toDouble();
    }
    return breakdown;
  }

  // ========== HELPERS ==========

  /// Round minutes up to nearest increment (e.g., 15 min blocks)
  static double _roundUpMinutes(double minutes, int increment) {
    if (minutes <= 0) return increment.toDouble();
    return (minutes / increment).ceil() * increment.toDouble();
  }

  /// Calculate running cost for a live session
  static double calculateRunningCost({
    required int startedAtMs,
    required String billingType,
    required double rate,
    int pausedMs = 0,
  }) {
    if (billingType == 'flat') return rate;

    final now = DateTime.now().millisecondsSinceEpoch;
    final durationMs = (now - startedAtMs) - pausedMs;
    final durationHours = (durationMs > 0 ? durationMs : 0) / 3600000;
    return durationHours * rate;
  }

  /// Format duration from milliseconds to readable string
  static String formatDuration(int startedAtMs, {int pausedMs = 0}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final durationMs = (now - startedAtMs) - pausedMs;
    final minutes = ((durationMs > 0 ? durationMs : 0) / 60000).floor();
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours > 0) {
      return '${hours}h ${remainingMinutes}m';
    }
    return '${minutes}m';
  }
}
