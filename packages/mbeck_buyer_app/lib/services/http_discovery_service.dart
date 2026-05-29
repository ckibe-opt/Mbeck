import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'shop_discovery_service.dart';

/// HTTP-based shop discovery service (fallback for Windows where mDNS is unreliable)
class HttpDiscoveryService {
  /// Scan local subnet for Mbeck seller shops
  /// Returns list of discovered shops via HTTP discovery endpoint
  static Future<List<DiscoveredShop>> discoverShops({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final shops = <DiscoveredShop>[];
    final localIp = await _getLocalIp();
    
    if (localIp == null) {
      debugPrint('❌ Could not determine local IP address');
      return shops;
    }
    
    debugPrint('📡 HTTP Discovery: Scanning subnet based on $localIp');
    
    // Extract subnet (e.g., 192.168.1.x from 192.168.1.100)
    final subnet = localIp.substring(0, localIp.lastIndexOf('.'));
    
    // Scan range 1-254 in parallel
    final futures = <Future<DiscoveredShop?>>[];
    for (int i = 1; i <= 254; i++) {
      final ip = '$subnet.$i';
      futures.add(_checkShop(ip));
    }
    
    // Wait for all with timeout
    try {
      final results = await Future.wait(futures)
          .timeout(timeout, onTimeout: () => List.filled(futures.length, null));
      
      // Filter null and add to list
      for (final shop in results) {
        if (shop != null) {
          shops.add(shop);
          debugPrint('✅ Found shop via HTTP: ${shop.name} at ${shop.ip}:${shop.port}');
        }
      }
    } catch (e) {
      debugPrint('❌ HTTP discovery error: $e');
    }
    
    debugPrint('📡 HTTP Discovery complete. Found ${shops.length} shops');
    return shops;
  }
  
  /// Check if IP has Mbeck seller app running
  static Future<DiscoveredShop?> _checkShop(String ip) async {
    try {
      // Try discovery endpoint on default port 8080
      final response = await http
          .get(Uri.parse('http://$ip:8080/api/v1/discover'))
          .timeout(const Duration(milliseconds: 500));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DiscoveredShop(
          name: data['name'] ?? 'Unknown Shop',
          ip: ip,
          port: data['port'] ?? 8080,
          shopId: data['shopId'],
          cloudId: data['cloudId'],
          version: data['version'] ?? '1.0.0',
        );
      }
    } catch (e) {
      // Ignore - shop not found at this IP
      // Don't log to avoid spam (254 IPs)
    }
    return null;
  }
  
  /// Get local IP address of this device
  static Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          // Look for IPv4 address on local network
          if (addr.type == InternetAddressType.IPv4 && 
              !addr.isLoopback &&
              (addr.address.startsWith('192.168.') || 
               addr.address.startsWith('10.') ||
               addr.address.startsWith('172.'))) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting local IP: $e');
    }
    return null;
  }
}
