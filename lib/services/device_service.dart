import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing shop_id and device_id
/// 
/// These identifiers are critical for event sourcing and multi-device support.
/// They must be stable and persistent across app restarts.
/// 
/// Multi-Shop Architecture:
/// - homeShopId: The shop this device "belongs to" (owner's shop)
/// - activeShopId: The shop currently being accessed (may be visiting)
/// - If activeShopId != homeShopId → Ghost Mode (read-only)
class DeviceService {
  static const String _shopIdKey = 'shop_id'; // Legacy: now "home" shop
  static const String _homeShopIdKey = 'home_shop_id';
  static const String _activeShopIdKey = 'active_shop_id';
  static const String _deviceIdKey = 'device_id';
  
  static String? _cachedHomeShopId;
  static String? _cachedActiveShopId;
  static String? _cachedDeviceId;
  
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Get or create shop_id (defaults to home shop for backward compat)
  /// This is the primary shop ID used for data operations.
  static Future<String> getShopId() async {
    // Return active shop if set, otherwise home shop
    final activeShopId = await getActiveShopId();
    if (activeShopId != null && activeShopId.isNotEmpty) {
      return activeShopId;
    }
    return await getHomeShopId();
  }

  /// Get the home shop ID (the shop this device "owns")
  static Future<String> getHomeShopId() async {
    if (_cachedHomeShopId != null) return _cachedHomeShopId!;
    
    final prefs = await _getPrefs();
    
    // Try new key first, then fall back to legacy key
    String? shopId = prefs.getString(_homeShopIdKey);
    if (shopId == null || shopId.isEmpty) {
      shopId = prefs.getString(_shopIdKey);
    }
    
    if (shopId == null || shopId.isEmpty) {
      // Generate a temporary shop_id for callers that need one,
      // but DO NOT persist it. This keeps hasStoredShopId() == false
      // so the user will be shown the SignUpScreen (Create/Join choice).
      // The ID is only persisted when createShop() or joinShop() 
      // explicitly calls setHomeShopId().
      shopId = _generateId('shop');
      _cachedHomeShopId = shopId;
      debugPrint('📱 Generated temporary home_shop_id (not persisted): $shopId');
      return shopId;
    }
    
    _cachedHomeShopId = shopId;
    return shopId;
  }

  /// Get the active shop ID (currently selected shop, may differ from home)
  static Future<String?> getActiveShopId() async {
    if (_cachedActiveShopId != null) return _cachedActiveShopId!;
    
    final prefs = await _getPrefs();
    _cachedActiveShopId = prefs.getString(_activeShopIdKey);
    return _cachedActiveShopId;
  }

  /// Set the home shop ID (when device joins/creates a shop)
  static Future<void> setHomeShopId(String newShopId) async {
    final prefs = await _getPrefs();
    await prefs.setString(_homeShopIdKey, newShopId);
    await prefs.setString(_shopIdKey, newShopId); // Backward compat
    _cachedHomeShopId = newShopId;
    debugPrint('🏠 Set home shop_id: $newShopId');
  }

  /// Set the active shop ID (when visiting/switching shops)
  /// Pass null to clear and return to home shop.
  static Future<void> setActiveShopId(String? shopId) async {
    final prefs = await _getPrefs();
    if (shopId == null || shopId.isEmpty) {
      await prefs.remove(_activeShopIdKey);
      _cachedActiveShopId = null;
      debugPrint('🏠 Cleared active shop, returning to home');
    } else {
      await prefs.setString(_activeShopIdKey, shopId);
      _cachedActiveShopId = shopId;
      debugPrint('👁️ Set active shop_id: $shopId');
    }
  }

  /// Check if currently visiting a non-home shop
  static Future<bool> isVisitingOtherShop() async {
    final homeShopId = await getHomeShopId();
    final activeShopId = await getActiveShopId();
    return activeShopId != null && activeShopId != homeShopId;
  }

  /// [LEGACY] Manually set the shop_id (Link Device)
  /// This allows the user to restore their identity from another device.
  static Future<void> setShopId(String newShopId) async {
    await setHomeShopId(newShopId);
  }

  /// Check if shop_id exists WITHOUT auto-generating
  /// Use this for authentication checks to avoid bypassing signup
  static Future<bool> hasStoredShopId() async {
    final prefs = await _getPrefs();
    final shopId = prefs.getString(_homeShopIdKey) ?? prefs.getString(_shopIdKey);
    return shopId != null && shopId.isNotEmpty;
  }

  /// Get or create device_id (unique per device)
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    
    final prefs = await _getPrefs();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null || deviceId.isEmpty) {
      // Generate new device_id (UUID format)
      deviceId = _generateId('device');
      await prefs.setString(_deviceIdKey, deviceId);
      debugPrint('📱 Generated new device_id: $deviceId');
    }
    
    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Get the database filename for a specific shop
  /// Format: shop_{id}.db for per-shop isolation
  static String getShopDatabaseName(String shopId) {
    // Sanitize shop ID for filename (remove special chars)
    final safeId = shopId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return 'shop_$safeId.db';
  }

  /// Get database name for current active shop
  static Future<String> getCurrentDatabaseName() async {
    final shopId = await getShopId();
    return getShopDatabaseName(shopId);
  }

  /// Generate a unique ID with prefix
  static String _generateId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return '${prefix}_${timestamp}_$random';
  }

  /// Clear all shop IDs (used during logout)
  static Future<void> clearAllShopIds() async {
    final prefs = await _getPrefs();
    await prefs.remove(_shopIdKey);
    await prefs.remove(_homeShopIdKey);
    await prefs.remove(_activeShopIdKey);
    _cachedHomeShopId = null;
    _cachedActiveShopId = null;
    debugPrint('🗑️ Cleared all shop IDs from device');
  }

  /// Clear cached IDs (for testing)
  static void clearCache() {
    _cachedHomeShopId = null;
    _cachedActiveShopId = null;
    _cachedDeviceId = null;
    _prefs = null;
  }
}
