import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sync_service.dart';
import 'auth_service.dart';

/// Background Sync Service
/// Manages periodic cloud synchronization for module data
class BackgroundSyncService {
  static Timer? _syncTimer;
  static bool _isSyncing = false;
  static const Duration _syncInterval = Duration(hours: 1);

  /// Start periodic background sync (call after user logs in)
  static void startPeriodicSync() {
    // Cancel any existing timer
    stopPeriodicSync();
    
    debugPrint('🔄 Starting background sync (interval: ${_syncInterval.inMinutes} min)');
    
    // Initial sync after 5 seconds
    Future.delayed(const Duration(seconds: 5), () => _performSync());
    
    // Periodic sync
    _syncTimer = Timer.periodic(_syncInterval, (_) => _performSync());
  }

  /// Stop periodic sync (call on logout)
  static void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('⏹️ Background sync stopped');
  }

  /// Perform a sync operation
  static Future<void> _performSync() async {
    if (_isSyncing) {
      debugPrint('⏳ Sync already in progress, skipping...');
      return;
    }

    _isSyncing = true;
    try {
      // Check if user has PRO access
      final shop = await AuthService.getCurrentShop();
      if (shop == null || !shop.hasProAccess) {
        debugPrint('📡 Background sync skipped (requires PRO)');
        return;
      }

      debugPrint('🔄 Background sync starting (Event Sourcing)...');
      final synced = await SyncService.syncEvents(force: true);
      debugPrint('✅ Background sync complete: $synced events synced');
    } catch (e) {
      debugPrint('❌ Background sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Manual trigger for sync (e.g., from settings button)
  static Future<Map<String, dynamic>> syncNow() async {
    if (_isSyncing) {
      return {
        'success': false,
        'message': 'Sync already in progress',
      };
    }

    try {
      _isSyncing = true;
      final synced = await SyncService.syncEvents(force: true);
      return {
        'success': true,
        'synced': synced,
        'message': '$synced events synced to cloud',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Sync failed: $e',
      };
    } finally {
      _isSyncing = false;
    }
  }

  /// Check if sync is currently running
  static bool get isSyncing => _isSyncing;

  /// Check if periodic sync is active
  static bool get isPeriodicSyncActive => _syncTimer != null;
}
