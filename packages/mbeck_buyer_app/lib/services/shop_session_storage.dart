import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent storage for multi-shop session tokens and metadata
/// 
/// Enables the Buyer app to maintain session tokens per shop,
/// allowing quick reconnection without re-handshake and supporting
/// multiple shop connections simultaneously.
class ShopSessionStorage {
  static const String _tokenMapKey = 'shop_session_tokens';
  static const String _shopMetadataKey = 'shop_metadata_cache';
  
  // In-memory cache
  static Map<String, _ShopSession>? _sessions;
  static Map<String, Map<String, dynamic>>? _metadataCache;
  
  /// Get session token for a specific shop
  static Future<String?> getToken(String shopId) async {
    await _loadSessions();
    final session = _sessions?[shopId];
    
    if (session == null) return null;
    
    // Check if expired
    if (session.expiresAt.isBefore(DateTime.now())) {
      debugPrint('⏰ Session expired for shop: $shopId');
      await removeSession(shopId);
      return null;
    }
    
    return session.token;
  }
  
  /// Store session token for a shop
  static Future<void> setToken({
    required String shopId,
    required String token,
    required Duration expiresIn,
  }) async {
    await _loadSessions();
    
    _sessions ??= {};
    _sessions![shopId] = _ShopSession(
      shopId: shopId,
      token: token,
      expiresAt: DateTime.now().add(expiresIn),
      createdAt: DateTime.now(),
    );
    
    await _saveSessions();
    debugPrint('💾 Session stored for shop: $shopId');
  }
  
  /// Remove session for a shop (logout/expired)
  static Future<void> removeSession(String shopId) async {
    await _loadSessions();
    _sessions?.remove(shopId);
    await _saveSessions();
    debugPrint('🗑️ Session removed for shop: $shopId');
  }
  
  /// Get cached metadata for a shop (name, theme, etc.)
  static Future<Map<String, dynamic>?> getShopMetadata(String shopId) async {
    await _loadMetadata();
    return _metadataCache?[shopId];
  }
  
  /// Cache shop metadata for offline access
  static Future<void> setShopMetadata(String shopId, Map<String, dynamic> metadata) async {
    await _loadMetadata();
    
    _metadataCache ??= {};
    _metadataCache![shopId] = {
      ...metadata,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    
    await _saveMetadata();
    debugPrint('💾 Metadata cached for shop: $shopId');
  }
  
  /// Get all cached shop IDs (for discovery list)
  static Future<List<String>> getCachedShopIds() async {
    await _loadSessions();
    return _sessions?.keys.toList() ?? [];
  }
  
  /// Check if we have a valid session for a shop
  static Future<bool> hasValidSession(String shopId) async {
    final token = await getToken(shopId);
    return token != null;
  }
  
  /// Clear all sessions (logout all)
  static Future<void> clearAll() async {
    _sessions = {};
    _metadataCache = {};
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenMapKey);
    await prefs.remove(_shopMetadataKey);
    
    debugPrint('🗑️ All sessions cleared');
  }
  
  // ===== Private Helpers =====
  
  static Future<void> _loadSessions() async {
    if (_sessions != null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_tokenMapKey);
    
    if (json != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(json);
        _sessions = data.map((key, value) => 
          MapEntry(key, _ShopSession.fromJson(value as Map<String, dynamic>))
        );
      } catch (e) {
        debugPrint('⚠️ Failed to load sessions: $e');
        _sessions = {};
      }
    } else {
      _sessions = {};
    }
  }
  
  static Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _sessions?.map((key, value) => MapEntry(key, value.toJson())) ?? {};
    await prefs.setString(_tokenMapKey, jsonEncode(data));
  }
  
  static Future<void> _loadMetadata() async {
    if (_metadataCache != null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_shopMetadataKey);
    
    if (json != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(json);
        _metadataCache = data.cast<String, Map<String, dynamic>>();
      } catch (e) {
        debugPrint('⚠️ Failed to load metadata: $e');
        _metadataCache = {};
      }
    } else {
      _metadataCache = {};
    }
  }
  
  static Future<void> _saveMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shopMetadataKey, jsonEncode(_metadataCache ?? {}));
  }
}

/// Internal class to hold session data
class _ShopSession {
  final String shopId;
  final String token;
  final DateTime expiresAt;
  final DateTime createdAt;
  
  _ShopSession({
    required this.shopId,
    required this.token,
    required this.expiresAt,
    required this.createdAt,
  });
  
  factory _ShopSession.fromJson(Map<String, dynamic> json) {
    return _ShopSession(
      shopId: json['shopId'] as String,
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'shopId': shopId,
    'token': token,
    'expiresAt': expiresAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}
