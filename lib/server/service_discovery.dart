
import 'package:flutter/foundation.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../services/device_service.dart';

class ShopBroadcast {
  static BonsoirBroadcast? _broadcast;
  static bool _isBroadcasting = false;
  static String? _shopName;

  static bool get isBroadcasting => _isBroadcasting;
  static String? get shopName => _shopName;

  /// Start advertising the shop service on the local network
  /// 
  /// Note: This should only be called after LocalClusterService.canBecomeLeader()
  /// confirms this device should be the broadcaster.
  static Future<void> start({
    required String shopId,
    String? cloudId,
    required String shopName,
    required int port,
  }) async {
    if (_isBroadcasting) return;
    _shopName = shopName;

    try {
      // Get device ID for cluster identification
      final deviceId = await DeviceService.getDeviceId();
      
      // 1. Define the service
      // Type must match ServiceConstants.serviceType for Buyer discovery
      final service = BonsoirService(
        name: shopName, // e.g. "Chege's Electronics"
        type: ServiceConstants.serviceType, // '_mbeck-pos._tcp'
        port: port,
        attributes: {
          'shopId': shopId,        // For cluster identification
          'deviceId': deviceId,    // For leader identification
          if (cloudId != null) 'cloudId': cloudId,
          'version': '1.0.0',
          'type': 'seller',
        },
      );

      // 2. Create the broadcast
      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.initialize();

      // 3. Start
      await _broadcast!.start();
      _isBroadcasting = true;

      debugPrint('📡 Broadcasting service: ${service.name} on port $port (device: $deviceId)');

    } catch (e) {
      debugPrint('❌ Failed to start broadcast: $e');
      _isBroadcasting = false;
      _broadcast = null;
    }
  }

  /// Stop advertising
  static Future<void> stop() async {
    if (_broadcast != null) {
      await _broadcast!.stop();
      _broadcast = null;
    }
    _isBroadcasting = false;
    _shopName = null;
    debugPrint('🔕 Broadcast stopped');
  }
}
