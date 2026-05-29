import 'package:flutter/material.dart';
import 'dart:async';
import '../services/sync_service.dart';

/// Widget that listens to app lifecycle changes and triggers sync
/// 
/// Syncs events when:
/// - App resumes from background
/// - App becomes active after being idle
/// 
/// Does NOT sync when:
/// - App is in foreground and user is active
/// - No network connectivity
class SyncLifecycleListener extends StatefulWidget {
  final Widget child;

  const SyncLifecycleListener({
    super.key,
    required this.child,
  });

  @override
  State<SyncLifecycleListener> createState() => _SyncLifecycleListenerState();
}

class _SyncLifecycleListenerState extends State<SyncLifecycleListener>
    with WidgetsBindingObserver {
  AppLifecycleState? _lastLifecycleState;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    super.dispose();
  }

  // Timer for periodic sync while app is open (every 60s)
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Start periodic sync loop
    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_lastLifecycleState == AppLifecycleState.resumed || _lastLifecycleState == null) {
        _triggerBackgroundSync();
      }
    });
    
    // Trigger initial sync on startup
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerBackgroundSync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Trigger sync when app resumes from background
    if (_lastLifecycleState == AppLifecycleState.paused &&
        state == AppLifecycleState.resumed) {
      _triggerBackgroundSync();
    }

    // Trigger sync when app becomes active after being inactive
    if (_lastLifecycleState == AppLifecycleState.inactive &&
        state == AppLifecycleState.resumed) {
      _triggerBackgroundSync();
    }

    _lastLifecycleState = state;
  }

  /// Trigger background sync (non-blocking)
  Future<void> _triggerBackgroundSync() async {
    // Don't sync if already syncing
    if (SyncService.isSyncing) {
      return;
    }

    // Sync in background (don't await - non-blocking)
    SyncService.syncEvents().then((syncedCount) {
      if (syncedCount > 0) {
        debugPrint('✅ Background sync completed: $syncedCount events synced');
      }
    }).catchError((error) {
      debugPrint('⚠️ Background sync error: $error');
      // Don't show error to user - sync is background operation
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
