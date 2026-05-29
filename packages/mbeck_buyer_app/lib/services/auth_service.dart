import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;

import 'database_service.dart';
import '../database/app_database.dart';

class AuthService {
  static const String _deviceIdKey = 'buyer_device_id';
  static const String _rateLimitKey = 'buyer_auth_rate_limit_until';
  static const int _backoffMinutes = 15;

  /// Initialize auth for the Buyer app.
  /// Uses anonymous Supabase auth — no email/password needed.
  /// Gracefully skips if offline or rate-limited; the app works without it.
  static Future<void> init() async {
    final supabase = Supabase.instance.client;
    final db = DatabaseService.instance.db;

    User? user = supabase.auth.currentUser;

    if (user != null) {
      debugPrint('✅ Buyer: Already logged in (${user.id})');
      await _ensureLocalProfile(db, user);
      return;
    }

    // Check rate-limit backoff
    final prefs = await SharedPreferences.getInstance();
    final backoffUntil = prefs.getInt(_rateLimitKey) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < backoffUntil) {
      final remaining = ((backoffUntil - DateTime.now().millisecondsSinceEpoch) / 60000).ceil();
      debugPrint('⏳ Buyer auth on cooldown (${remaining}m). App works offline.');
      return;
    }

    debugPrint('� Buyer: No session, attempting anonymous auth...');
    try {
      final response = await supabase.auth.signInAnonymously();
      user = response.user;
      if (user != null) {
        debugPrint('✅ Buyer: Anonymous auth successful (${user.id})');
        await _ensureLocalProfile(db, user);
      }
    } on AuthException catch (e) {
      if (e.statusCode == '429' || e.message.toLowerCase().contains('rate limit')) {
        final until = DateTime.now().millisecondsSinceEpoch + (_backoffMinutes * 60 * 1000);
        await prefs.setInt(_rateLimitKey, until);
        debugPrint('⚠️ Buyer auth rate limited. Backing off ${_backoffMinutes}m. App works offline.');
      } else {
        debugPrint('⚠️ Buyer auth error: ${e.message}. App works offline.');
      }
    } catch (e) {
      debugPrint('⚠️ Buyer auth unavailable: $e. App works offline.');
    }
  }

  /// Get the current device ID (for local identification, not auth).
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = 'buyer_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  static Future<void> _ensureLocalProfile(AppDatabase db, User user) async {
    try {
      final exists = await (db.select(db.userProfile)..where((t) => t.id.equals(user.id))).getSingleOrNull();
      if (exists == null) {
        await db.into(db.userProfile).insert(
          UserProfileCompanion(
            id: drift.Value(user.id),
            phoneNumber: drift.Value(user.email ?? 'anonymous'),
            walletBalance: const drift.Value(0.0),
            creditScore: const drift.Value(null),
          ),
        );
        debugPrint('✅ Local Profile Created for ${user.id}');
      }
    } catch (e) {
      debugPrint('⚠️ Profile creation skipped: $e');
    }
  }
}
