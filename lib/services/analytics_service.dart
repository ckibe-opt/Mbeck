import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../models/permissions.dart';
import 'auth_service.dart';

class UnmetDemandItem {
  final String query;
  final int count;
  final DateTime lastSeen;

  UnmetDemandItem({
    required this.query,
    required this.count,
    required this.lastSeen,
  });

  factory UnmetDemandItem.fromJson(Map<String, dynamic> json) {
    return UnmetDemandItem(
      query: json['query_text'] ?? 'Unknown',
      count: json['demand_count'] ?? 0,
      lastSeen: DateTime.tryParse(json['last_seen_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class AnalyticsService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static bool firebaseInitialized = false;

  /// Fetch top missed opportunities (unmet demand)
  static Future<List<UnmetDemandItem>> getUnmetDemand({int limit = 5}) async {
    // RBAC Check
    final member = await AuthService.getCurrentMember();
    if (member != null && !member.hasPermission(Permissions.viewReports)) {
      debugPrint('⛔ Analytics Access Denied for ${member.userName}');
      return [];
    }

    try {
      // Return empty if offline or anon
      if (_supabase.auth.currentUser == null) return [];

      final List<dynamic> response = await _supabase
          .from('analytics_demand_unmet')
          .select()
          .limit(limit);

      return response.map((e) => UnmetDemandItem.fromJson(e)).toList();
    } catch (e) {
      debugPrint('⚠️ Analytics Fetch Failed: $e');
      return [];
    }
  }

  // ==========================================
  // Firebase Analytics API for User Retention
  // ==========================================

  /// Generic log event method. Handles uninitialized Firebase gracefully.
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!firebaseInitialized) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
      debugPrint('📊 [Analytics] Logged event: $name with parameters: $parameters');
    } catch (e) {
      debugPrint('⚠️ [Analytics] Failed to log event $name: $e');
    }
  }

  /// Set user properties for audience segmentation & cohort retention analysis.
  static Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    if (!firebaseInitialized) return;
    try {
      await FirebaseAnalytics.instance.setUserProperty(
        name: name,
        value: value,
      );
      debugPrint('📊 [Analytics] Set user property: $name = $value');
    } catch (e) {
      debugPrint('⚠️ [Analytics] Failed to set user property $name: $e');
    }
  }

  /// Core Retention Event 1: User completes checkout transaction.
  /// Used to measure retention based on transaction frequency and value.
  static Future<void> logCheckoutCompleted({
    required double totalAmount,
    required int itemsCount,
    required String paymentMethod,
    required String module, // e.g. retail, restaurant, lodging, etc.
  }) async {
    await logEvent(
      name: 'checkout_completed',
      parameters: {
        'value': totalAmount,
        'currency': 'KES',
        'items_count': itemsCount,
        'payment_method': paymentMethod,
        'module_type': module,
      },
    );
  }

  /// Core Retention Event 2: User manages modules (adoption & customizability).
  static Future<void> logModuleToggled({
    required String moduleId,
    required bool isEnabled,
  }) async {
    await logEvent(
      name: 'module_toggled',
      parameters: {
        'module_id': moduleId,
        'is_enabled': isEnabled ? 1 : 0,
      },
    );
  }

  /// Core Retention Event 3: Booking creation (for Services module).
  static Future<void> logBookingCreated({
    required double totalPrice,
    required int durationMinutes,
    required bool hasAddons,
  }) async {
    await logEvent(
      name: 'booking_created',
      parameters: {
        'value': totalPrice,
        'currency': 'KES',
        'duration_minutes': durationMinutes,
        'has_addons': hasAddons ? 1 : 0,
      },
    );
  }

  /// Core Retention Event 4: Reservation creation (for Lodging module).
  static Future<void> logReservationCreated({
    required double rate,
    required String billingUnit, // e.g., night, week, month
  }) async {
    await logEvent(
      name: 'reservation_created',
      parameters: {
        'value': rate,
        'currency': 'KES',
        'billing_unit': billingUnit,
      },
    );
  }

  /// Core Retention Event 5: Session started (for Entertainment/Play Session tracking).
  static Future<void> logSessionStarted({
    required String assetType,
    required double hourlyRate,
  }) async {
    await logEvent(
      name: 'session_started',
      parameters: {
        'asset_type': assetType,
        'hourly_rate': hourlyRate,
      },
    );
  }

  /// Core Retention Event 6: LAN Sync performance.
  /// Correlating app sync quality and speed with user churn.
  static Future<void> logLanSyncCompleted({
    required String role, // leader / follower
    required int durationMs,
    required int eventCount,
    required bool success,
  }) async {
    await logEvent(
      name: 'lan_sync_completed',
      parameters: {
        'device_role': role,
        'duration_ms': durationMs,
        'event_count': eventCount,
        'success': success ? 1 : 0,
      },
    );
  }

  /// Core Retention Event 7: Bulk customer onboarding (CSV import).
  /// Measures successful data migration.
  static Future<void> logCustomerImport({
    required int count,
    required bool success,
    String? error,
  }) async {
    await logEvent(
      name: 'customer_import',
      parameters: {
        'customer_count': count,
        'success': success ? 1 : 0,
        if (error != null) 'error_message': error.substring(0, error.length > 100 ? 100 : error.length),
      },
    );
  }
}
