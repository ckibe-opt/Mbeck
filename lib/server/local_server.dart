
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'routes/api_router.dart';
import 'service_discovery.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../db/db_provider.dart';
import '../services/device_service.dart';
import '../services/local_cluster_service.dart';
import '../services/lan_sync_service.dart';
import '../services/lan_snapshot_client.dart';
import '../services/auth_service.dart';
import '../services/performance_monitor.dart';

class ShopServer {
  static HttpServer? _server;
  static String? _ipAddress;
  static int _port = 8080;
  static bool _isFollower = false;
  static bool _isStarting = false;

  static bool get isRunning => _server != null;
  static String? get ipAddress => _ipAddress;
  static int get port => _port;
  static bool get isFollower => _isFollower;
  static bool get isLeader => isRunning && !_isFollower;

  /// Starts the local HTTP server
  /// 
  /// Performs leader election before broadcasting to prevent dual-broadcast conflicts.
  /// If another device is already broadcasting for this shop, we enter Follower Mode.
  static Future<void> start() async {
    if (_server != null || _isStarting) return; // Already running or starting
    _isStarting = true;
    
    // ========== LEADER ELECTION ==========
    // Check if another device is already broadcasting for this shop
    final canLead = await LocalClusterService.instance.canBecomeLeader();
    
    if (!canLead) {
      // Another device is the leader - enter Follower Mode
      _isFollower = true;
      debugPrint('📡 Entering Follower Mode. Leader: ${LocalClusterService.instance.leaderId}');
      debugPrint('   Leader IP: ${LocalClusterService.instance.leaderIp}');
      
      // Start monitoring the leader for failover
      await LocalClusterService.instance.startLeaderMonitoring();
      LocalClusterService.instance.onLeaderLost = () {
        debugPrint('⚠️ Leader lost! Attempting takeover...');
        // Could auto-attempt takeover here, but for now just notify
      };
      
      // ========== LAN SYNC (Follower) ==========
      // Followers MUST also listen for LAN events to receive data from leader
      await LANSyncService.instance.startListening();
      await LANSyncService.instance.broadcastPendingEvents();
      debugPrint('📡 Follower LAN Sync active — listening for events');
      
      // Auto-pull snapshot from leader if our DB is empty (first join)
      final needsSnap = await LanSnapshotClient.needsSnapshot();
      if (needsSnap) {
        final leaderIp = LocalClusterService.instance.leaderIp;
        if (leaderIp != null) {
          debugPrint('📸 DB empty — pulling snapshot from leader at $leaderIp:8080');
          final success = await LanSnapshotClient.pullFromLeader('$leaderIp:8080');
          debugPrint(success
              ? '✅ Snapshot applied successfully!'
              : '⚠️ Snapshot pull failed, will retry on next heartbeat');
        } else {
          // No leader IP yet — register callback for when we discover it
          LANSyncService.instance.onSnapshotOffered = (leaderHost) async {
            debugPrint('📸 Leader discovered at $leaderHost — pulling snapshot...');
            await LanSnapshotClient.pullFromLeader(leaderHost);
            LANSyncService.instance.onSnapshotOffered = null; // One-shot
          };
          // Actively request snapshot from leader via multicast
          await LANSyncService.instance.requestSnapshot();
        }
      }
      // ==========================================
      
      _isStarting = false;
      return; // Don't start HTTP server or mDNS broadcast
    }

    try {
      // 1. Get Local IP Address
      final info = NetworkInfo();
      _ipAddress = await info.getWifiIP();

      // Fallback: If NetworkInfo fails (common on Hotspots), check network interfaces directly
      if (_ipAddress == null) {
        try {
          final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
          for (var interface in interfaces) {
            // Filter out loopback and common non-usable interfaces if necessary
            // On Hotspot, the interface is often named 'ap0', 'wlan0', or similar.
            for (var addr in interface.addresses) {
              if (!addr.isLoopback) {
                _ipAddress = addr.address;
                debugPrint('Found IP via interface ${interface.name}: $_ipAddress');
                break;
              }
            }
            if (_ipAddress != null) break;
          }
        } catch (e) {
          debugPrint('Error getting network interfaces: $e');
        }
      }

      if (_ipAddress == null) {
        debugPrint('⚠️ Could not find IP. Falling back to localhost (127.0.0.1).');
        _ipAddress = '127.0.0.1'; // Absolute fallback
      }

      // 2. Initialize Router
      final apiRouter = ApiRouter();
      
      // 3. Create Handler Pipeline (Logger -> Router)
      final handler = const Pipeline()
          .addMiddleware(logRequests())
          .addMiddleware((innerHandler) {
            return (request) async {
              final traceName = 'API:${request.method}:${request.url.path}';
              PerformanceMonitor().startTrace(traceName);
              try {
                final response = await innerHandler(request);
                PerformanceMonitor().endTrace(traceName, metadata: {'status': response.statusCode});
                return response;
              } catch (e) {
                PerformanceMonitor().endTrace(traceName, metadata: {'error': e.toString()});
                rethrow;
              }
            };
          })
          .addHandler(apiRouter.handler);

      // 4. Bind Server
      // binding to '0.0.0.0' allows access from other devices on the network
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port, shared: true);
      
      debugPrint('🚀 Server running on http://$_ipAddress:$_port');
      debugPrint('Checking health at: http://$_ipAddress:$_port/api/v1/status');

      // 5. Start Service Discovery (mDNS) - ONLY IF WE'RE THE LEADER
      final shopId = await DeviceService.getShopId();
      final shortId = shopId.length > 5 ? shopId.substring(0, 5) : shopId;
      
      String? cloudId;
      try {
        cloudId = Supabase.instance.client.auth.currentUser?.id;
      } catch (_) {
        // Supabase is not initialized (e.g. during offline test environment)
      }

      // Try to fetch real shop name from LOCAL database first (Offline-First)
      String broadcastName = "Mbeck Shop $shortId";
      try {
        final db = await DbProvider.db;
        final result = await db.rawQuery('SELECT shop_name FROM shop_settings LIMIT 1');
        if (result.isNotEmpty && result.first['shop_name'] != null) {
          broadcastName = result.first['shop_name'] as String;
          debugPrint('✅ Broadcasting shop name from local DB: $broadcastName');
        } else {
          // Fallback: Use cached AuthService data
          final shop = await AuthService.getCurrentShop();
          if (shop != null) {
            broadcastName = shop.businessName;
            debugPrint('⚠️ Local DB empty, broadcasting from AuthService cache: $broadcastName');
            
            // Self-repair: Sync to DB now
            AuthService.getCurrentShop().then((s) {
                if (s != null) AuthService.selectShop(s.id); // Trigger sync logic (safe?) 
                // actually we can't call private method. But selectShop is heavy.
                // Just let the fallback work for now, selectShop was already updated to sync.
            });
          }
        }
      } catch (e) {
        debugPrint('⚠️ Failed to fetch shop name from local DB: $e');
        // Fallback on error
        final shop = await AuthService.getCurrentShop();
        if (shop != null) broadcastName = shop.businessName;
      }

      await ShopBroadcast.start(
        shopId: shopId,
        cloudId: cloudId,
        shopName: broadcastName, 
        port: _port
      );
      
      // ========== LAN SYNC ==========
      // Start listening for events from other devices on LAN
      await LANSyncService.instance.startListening();
      // Tell LANSyncService we're the leader so it responds to snapshot requests  
      LANSyncService.instance.setLeaderHttpHost('$_ipAddress:$_port');
      // Broadcast any pending events to sync with new peers
      await LANSyncService.instance.broadcastPendingEvents();
      // ==============================
      
      _isFollower = false;
      debugPrint('👑 This device is the cluster LEADER');

    } catch (e) {
      debugPrint('❌ Failed to start server: $e');
      _server = null;
      rethrow;
    } finally {
      _isStarting = false;
    }
  }

  /// Stops the server
  static Future<void> stop() async {
    // Stop LAN sync first
    await LANSyncService.instance.stopListening();
    
    await LocalClusterService.instance.stop();
    
    if (_server != null) {
      await ShopBroadcast.stop(); // Stop broadcasting first
      await _server!.close(force: true);
      _server = null;
      debugPrint('🛑 Server stopped.');
    }
    _isFollower = false;
  }
}
