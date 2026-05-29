import 'dart:async';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'shop_session_storage.dart';

/// Service for discovering Mbeck seller shops on the local network
/// Uses mDNS (Bonjour) to find shops broadcasting on same WiFi
/// 
/// Features:
/// - Connection health monitoring
/// - Automatic reconnection on disconnect
/// - Shop availability status tracking
/// - Cached fallback for offline discovery
class ShopDiscoveryService {
  static BonsoirDiscovery? _discovery;
  static final List<DiscoveredShop> _shops = [];
  static bool _isScanning = false;
  
  // Connection health monitoring
  static final Map<String, ShopConnectionStatus> _connectionStatus = {};
  static Timer? _healthCheckTimer;
  static const Duration _healthCheckInterval = Duration(seconds: 30);
  
  // Callbacks for connection events
  static Function(String shopId)? onShopDisconnected;
  static Function(String shopId)? onShopReconnected;
  
  static bool get isScanning => _isScanning;
  static List<DiscoveredShop> get discoveredShops => List.unmodifiable(_shops);
  
  /// Get connection status for a shop
  static ShopConnectionStatus? getConnectionStatus(String shopId) => _connectionStatus[shopId];
  
  /// Check if a shop is currently available
  static bool isShopAvailable(String shopId) {
    return _connectionStatus[shopId]?.isAvailable ?? false;
  }

  /// Discover nearby Mbeck seller shops on the local network
  /// Returns list of discovered shops after timeout
  static Future<List<DiscoveredShop>> discoverShops({
    Duration timeout = const Duration(seconds: 5),
    bool includeCached = true,
  }) async {
    if (_isScanning) {
      debugPrint('⚠️ Already scanning for shops');
      return _shops;
    }
    
    _shops.clear();
    _isScanning = true;
    
    try {
      // Start mDNS discovery for Mbeck POS services
      _discovery = BonsoirDiscovery(type: '_mbeck-pos._tcp');
      await _discovery!.initialize();
      
      // Listen for discovered services (Bonsoir v6 API)
      _discovery!.eventStream!.listen((event) {
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          debugPrint('🔍 Found service: ${event.service.name}');
          
          // Resolve the service to get IP address
          event.service.resolve(_discovery!.serviceResolver);
        }
        
        if (event is BonsoirDiscoveryServiceResolvedEvent) {
          final service = event.service;
          if (service.port > 0) { // Only add if port is valid
            debugPrint('✅ Resolved: ${service.name} at ${service.toJson()}');
            
            // Extract hostname from service JSON (Bonsoir v6)
            final json = service.toJson();
            final host = json['service.host'] as String? ?? '0.0.0.0';
            
            // Only add if we have a valid hostname
            if (host != '0.0.0.0' && host != 'NULL') {
              final shop = DiscoveredShop(
                name: service.name,
                ip: host,
                port: service.port,
                shopId: service.attributes?['id'],
                cloudId: service.attributes?['cloud_id'],
                version: service.attributes?['version'] ?? '1.0.0',
              );
              _shops.add(shop);
              
              // Cache the store for offline use
              if (shop.shopId != null) {
                DatabaseService.instance.cacheStore(
                  id: shop.shopId!,
                  name: shop.name,
                  ipAddress: shop.ip,
                  port: shop.port,
                );
              }
              
              debugPrint('📦 Added shop: ${service.name} at $host:${service.port}');
            } else {
              debugPrint('⚠️ Skipping shop with invalid host: $host');
            }
          } else {
            debugPrint('⚠️ Skipping unresolved service: ${service.name} (port: ${service.port})');
          }
        }
        
        if (event is BonsoirDiscoveryServiceLostEvent) {
          debugPrint('❌ Lost service: ${event.service.name}');
          _shops.removeWhere((shop) => shop.name == event.service.name);
        }
      });
      
      await _discovery!.start();
      
      // Wait for discovery timeout
      await Future.delayed(timeout);
      
      await stop();
      
      // Include cached shops if requested and mDNS found none
      if (includeCached && _shops.isEmpty) {
        debugPrint('📂 No mDNS shops found, loading from cache...');
        await _loadCachedShops();
      }
      
      debugPrint('📡 Discovery complete. Found ${_shops.length} shops');
      return _shops;
      
    } catch (e) {
      debugPrint('❌ Discovery error: $e');
      _isScanning = false;
      
      // Fallback to cached shops
      if (includeCached) {
        await _loadCachedShops();
      }
      return _shops;
    }
  }
  
  /// Load shops from local cache (for offline/fallback)
  static Future<void> _loadCachedShops() async {
    final cachedStores = await DatabaseService.instance.getCachedStores();
    for (final store in cachedStores) {
      if (store.ipAddress != null && store.port != null) {
        _shops.add(DiscoveredShop(
          name: store.name,
          ip: store.ipAddress!,
          port: store.port!,
          shopId: store.id,
          version: '1.0.0',
        ));
      }
    }
    debugPrint('📂 Loaded ${_shops.length} shops from cache');
  }
  
  /// Stop the discovery process
  static Future<void> stop() async {
    if (_discovery != null) {
      await _discovery!.stop();
      _discovery = null;
    }
    _isScanning = false;
  }
  
  /// Start health monitoring for connected shops
  static void startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      _checkAllConnections();
    });
    debugPrint('💓 Health monitoring started');
  }
  
  /// Stop health monitoring
  static void stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    debugPrint('💤 Health monitoring stopped');
  }
  
  /// Check health of all known shops
  static Future<void> _checkAllConnections() async {
    for (final shop in _shops) {
      if (shop.shopId != null) {
        await checkShopHealth(shop);
      }
    }
  }
  
  /// Check if a specific shop is reachable
  static Future<bool> checkShopHealth(DiscoveredShop shop) async {
    final shopId = shop.shopId ?? shop.name;
    final previousStatus = _connectionStatus[shopId];
    final wasAvailable = previousStatus?.isAvailable ?? false;
    
    try {
      final response = await http.get(
        Uri.parse('${shop.baseUrl}/api/v1/status'),
      ).timeout(const Duration(seconds: 5));
      
      final isAvailable = response.statusCode == 200;
      
      _connectionStatus[shopId] = ShopConnectionStatus(
        shopId: shopId,
        isAvailable: isAvailable,
        lastChecked: DateTime.now(),
        lastError: isAvailable ? null : 'HTTP ${response.statusCode}',
        consecutiveFailures: isAvailable ? 0 : (previousStatus?.consecutiveFailures ?? 0) + 1,
      );
      
      // Trigger reconnection callback if shop came back online
      if (isAvailable && !wasAvailable && previousStatus != null) {
        debugPrint('🟢 Shop reconnected: $shopId');
        onShopReconnected?.call(shopId);
      }
      
      return isAvailable;
    } catch (e) {
      _connectionStatus[shopId] = ShopConnectionStatus(
        shopId: shopId,
        isAvailable: false,
        lastChecked: DateTime.now(),
        lastError: e.toString(),
        consecutiveFailures: (previousStatus?.consecutiveFailures ?? 0) + 1,
      );
      
      // Trigger disconnect callback on first failure after being connected
      if (wasAvailable) {
        debugPrint('🔴 Shop disconnected: $shopId');
        onShopDisconnected?.call(shopId);
      }
      
      return false;
    }
  }
  
  /// Attempt to reconnect to a shop
  static Future<bool> attemptReconnect(DiscoveredShop shop) async {
    debugPrint('🔄 Attempting reconnect to ${shop.name}...');
    
    // Try to reach the shop
    final isReachable = await checkShopHealth(shop);
    
    if (isReachable) {
      // Try to restore session
      if (shop.shopId != null) {
        final hasSession = await ShopSessionStorage.hasValidSession(shop.shopId!);
        if (!hasSession) {
          debugPrint('⚠️ Shop reachable but session expired - needs re-handshake');
        }
      }
      return true;
    }
    
    return false;
  }
}

/// Represents a discovered Mbeck seller shop on the network
class DiscoveredShop {
  final String name;
  final String ip;
  final int port;
  final String? shopId;
  final String? cloudId;
  final String version;
  
  // Preview info (fetched from /api/v1/info after discovery)
  String? businessType;
  List<String>? enabledModules;
  String? shopImageUrl;
  Map<String, dynamic>? theme;
  
  DiscoveredShop({
    required this.name,
    required this.ip,
    required this.port,
    this.shopId,
    this.cloudId,
    this.version = '1.0.0',
    this.businessType,
    this.enabledModules,
    this.shopImageUrl,
    this.theme,
  });
  
  /// Base URL for API requests
  String get baseUrl => 'http://$ip:$port';
  
  /// Status endpoint
  String get statusUrl => '$baseUrl/api/v1/status';
  
  /// Vectors endpoint
  String get vectorsUrl => '$baseUrl/api/v1/vectors';
  
  @override
  String toString() => 'DiscoveredShop($name, $ip:$port, shopId: $shopId)';
}

/// Connection status for a shop
class ShopConnectionStatus {
  final String shopId;
  final bool isAvailable;
  final DateTime lastChecked;
  final String? lastError;
  final int consecutiveFailures;
  
  ShopConnectionStatus({
    required this.shopId,
    required this.isAvailable,
    required this.lastChecked,
    this.lastError,
    this.consecutiveFailures = 0,
  });
  
  /// Whether the shop should be considered offline (multiple failures)
  bool get isOffline => consecutiveFailures >= 3;
  
  @override
  String toString() => 'ShopConnectionStatus($shopId, available: $isAvailable, failures: $consecutiveFailures)';
}
