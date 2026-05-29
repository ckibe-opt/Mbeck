import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../db/db_provider.dart';

/// Syncs broadcasting state to the Android home screen widget
/// and handles toggle taps from the widget.
class HomeWidgetService {

  /// Seed widget with the shop name from local DB at startup.
  /// This ensures the widget shows the correct name even before broadcasting.
  static Future<void> seedShopName() async {
    // Stubs out HomeWidget calls since native widgets were removed for performance.
    debugPrint('📲 Widget seeding bypassed (widgets disabled).');
  }

  /// Update the home screen widget with current server status.
  static Future<void> updateBroadcastStatus({
    required bool isRunning,
    required bool isBroadcasting,
    String? ipAddress,
    String? shopName,
  }) async {
    // Stub
  }

  /// Start listening for widget toggle taps.
  /// Call this once from main() after runApp.
  static void startListening() {
    // Stub
  }

  static Future<void> _handleUri(Uri uri) async {
    // Stub
  }

  static Future<void> _toggleBackgroundService() async {
     // Stub
  }
}
