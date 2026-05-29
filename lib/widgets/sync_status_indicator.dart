import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../theme/design_system.dart';

class SyncStatusIndicator extends StatefulWidget {
  final Color? color;
  
  const SyncStatusIndicator({
    super.key, 
    this.color,
  });

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  Timer? _pollTimer;

  bool _isSyncing = false;
  int _unsyncedCount = 0;
  bool _hasNetwork = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final syncing = SyncService.isSyncing;

    // We wrap in try-catch to handle network/db jitters gracefully
    try {
      final hasNet = await SyncService.hasNetworkConnectivity();
      final status = await SyncService.getSyncStatus();
      
      if (mounted) {
        setState(() {
          _isSyncing = syncing;
          _hasNetwork = hasNet;
          _unsyncedCount = status['unsynced'] ?? 0;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _manualSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final count = await SyncService.syncEvents(force: true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0
                ? '✅ Synced $count events'
                : '☁️ All events already synced'),
            backgroundColor: AppColors.primaryGreen,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Sync failed: $e'), backgroundColor: AppColors.warning),
        );
      }
    } finally {
      await _checkStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget icon;
    String tooltip;

    if (!_hasNetwork) {
      icon = Icon(Icons.cloud_off, color: AppColors.gray500);
      tooltip = "Offline";
    } else if (_isSyncing) {
      icon = Icon(Icons.sync, color: AppColors.info);
      tooltip = "Syncing...";
    } else if (_hasError) {
      icon = Icon(Icons.cloud_queue, color: AppColors.warning);
      tooltip = "Sync Error";
    } else if (_unsyncedCount > 0) {
      icon = Stack(
        children: [
          Icon(Icons.cloud_upload, color: AppColors.warning),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
              child: Text(
                '$_unsyncedCount',
                style: AppTypography.textTheme.labelMedium?.copyWith(
                  color: AppColors.surfaceWhite,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        ],
      );
      tooltip = "$_unsyncedCount pending events";
    } else {
      icon = Icon(Icons.cloud_done, color: AppColors.primaryGreen);
      tooltip = "All synced";
    }

    return IconButton(
      icon: icon,
      onPressed: _manualSync,
      tooltip: tooltip,
    );
  }
}
