import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import 'device_service.dart';
import 'lan_peer_manager.dart'; // Needed for PeerConnectionInfo? No, it's defined in lan_peer_manager.dart. Circular dep?

/// Local Cluster Service for Leader Election
/// 
/// Prevents multiple devices in the same shop from broadcasting simultaneously.
/// 
/// The first device to broadcast becomes the "leader". Other devices detect
/// the existing broadcast and enter "follower mode" (sync-only, no server).
/// 
/// If the leader goes offline, a follower can take over after a timeout.

class LocalClusterService {
  static LocalClusterService? _instance;
  static LocalClusterService get instance => _instance ??= LocalClusterService._();
  
  LocalClusterService._();
  
  // Discovery subscription
  BonsoirDiscovery? _discovery;
  StreamSubscription? _discoverySubscription;
  Timer? _monitoringTimer;
  
  // Current cluster state
  ClusterRole _role = ClusterRole.unknown;
  String? _leaderId;
  String? _leaderIp;
  DateTime? _leaderLastSeen;
  
  // Configuration
  static const String serviceType = ServiceConstants.serviceType;
  static const Duration leaderTimeout = Duration(seconds: 12);
  static const Duration heartbeatInterval = Duration(seconds: 10);
  
  // Callbacks
  VoidCallback? onBecameLeader;
  VoidCallback? onBecameFollower;
  VoidCallback? onLeaderLost;
  
  // Getters
  ClusterRole get role => _role;
  bool get isLeader => _role == ClusterRole.leader;
  bool get isFollower => _role == ClusterRole.follower;
  String? get leaderId => _leaderId;
  String? get leaderIp => _leaderIp;
  
  /// Check if another device is already broadcasting for our shop
  /// 
  /// Returns true if we can safely become the leader.
  /// Returns false if another device is already broadcasting (we should be follower).
  Future<bool> canBecomeLeader() async {
    final myShopId = await DeviceService.getShopId();
    final myDeviceId = await DeviceService.getDeviceId();
    
    debugPrint('🔍 Checking for existing broadcasts for shop: $myShopId');
    
    // Start discovery to find existing Mbeck services
    _discovery = BonsoirDiscovery(type: serviceType);
    await _discovery!.initialize();
    
    final Completer<bool> completer = Completer();
    Timer? timeoutTimer;
    
    await _discoverySubscription?.cancel();
    _discoverySubscription = _discovery!.eventStream!.listen((event) {
      if (event is BonsoirDiscoveryServiceFoundEvent ||
          event is BonsoirDiscoveryServiceResolvedEvent) {
        final service = event.service;
        if (service != null) {
          // Check if this is from the same shop but different device
          final attributes = service.attributes;
          final serviceShopId = attributes['shopId'];
          final serviceDeviceId = attributes['deviceId'];
          
          if (serviceShopId == myShopId && serviceDeviceId != myDeviceId) {
            // Another device in our shop is already broadcasting!
            debugPrint('⚠️ Found existing leader: ${service.name} (device: $serviceDeviceId)');
            _leaderId = serviceDeviceId;
            // Extract host from resolved service if available
            if (event is BonsoirDiscoveryServiceResolvedEvent) {
              _leaderIp = event.service.host;
            }
            _leaderLastSeen = DateTime.now();
            
            if (!completer.isCompleted) {
              completer.complete(false); // Cannot become leader
            }
          }
        }
      }
    });
    
    await _discovery!.start();
    
    // Wait for discovery (2 seconds is enough for local network)
    timeoutTimer = Timer(const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        // No existing leader found in time
        completer.complete(true);
      }
    });
    
    final canLead = await completer.future;
    timeoutTimer.cancel();
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    await _discovery!.stop();
    
    if (canLead) {
      _role = ClusterRole.leader;
      _leaderId = myDeviceId;
      debugPrint('👑 No existing leader found. We can become leader.');
      onBecameLeader?.call();
    } else {
      _role = ClusterRole.follower;
      debugPrint('📡 Entering follower mode. Leader: $_leaderId');
      onBecameFollower?.call();
    }
    
    return canLead;
  }
  
  /// Start monitoring for leader heartbeats (for followers)
  /// 
  /// If the leader goes offline, we can attempt to take over.
  Future<void> startLeaderMonitoring() async {
    if (_role != ClusterRole.follower) return;
    
    debugPrint('👀 Starting leader monitoring...');
    
    // Re-use discovery to watch for leader
    _discovery = BonsoirDiscovery(type: serviceType);
    await _discovery!.initialize();
    
    final myShopId = await DeviceService.getShopId();
    
    await _discoverySubscription?.cancel();
    _discoverySubscription = _discovery!.eventStream!.listen((event) {
      if (event is BonsoirDiscoveryServiceFoundEvent ||
          event is BonsoirDiscoveryServiceResolvedEvent) {
        final service = event.service;
        if (service != null) {
          final attributes = service.attributes;
          
          if (attributes['shopId'] == myShopId && 
              attributes['deviceId'] == _leaderId) {
            // Leader heartbeat received
            _leaderLastSeen = DateTime.now();
            debugPrint('💓 Leader heartbeat received');
          }
        }
      } else if (event is BonsoirDiscoveryServiceLostEvent) {
        final service = event.service;
        final attributes = service.attributes;
        
        if (attributes['deviceId'] == _leaderId) {
          // Leader lost!
          debugPrint('⚠️ Leader service lost!');
          _handleLeaderLost();
        }
      }
    });
    
    await _discovery!.start();
    
    // Also check periodically in case we miss the "lost" event
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(leaderTimeout, (timer) {
      if (_role == ClusterRole.leader) {
        timer.cancel();
        _monitoringTimer = null;
        return;
      }
      
      if (_leaderLastSeen != null) {
        final timeSinceHeartbeat = DateTime.now().difference(_leaderLastSeen!);
        if (timeSinceHeartbeat > leaderTimeout) {
          debugPrint('⏰ Leader timeout - no heartbeat for ${timeSinceHeartbeat.inSeconds}s');
          _handleLeaderLost();
          timer.cancel();
          _monitoringTimer = null;
        }
      }
    });
  }
  
  void _handleLeaderLost() {
    _role = ClusterRole.pendingTakeover;
    _leaderId = null;
    _leaderIp = null;
    onLeaderLost?.call();
  }
  
  /// Attempt to take over as leader after current leader is lost
  Future<bool> attemptTakeover() async {
    if (_role != ClusterRole.pendingTakeover) return false;
    
    debugPrint('🔄 Attempting leader takeover...');
    return await canBecomeLeader();
  }
  
  /// Stop all monitoring and reset state
  Future<void> stop() async {
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    await _discovery?.stop();
    _discovery = null;
    _role = ClusterRole.unknown;
    _leaderId = null;
    _leaderIp = null;
    _leaderLastSeen = null;
  }

  /// Get peer connection info (stubbed or implementing basic lookup)
  PeerConnectionInfo? getPeerInfo(String peerId) {
    if (peerId == _leaderId && _leaderIp != null) {
      // Assuming default port if we know the leader
      return PeerConnectionInfo(
        ip: _leaderIp!,
        webSocketPort: 8080, // Default for now
      );
    }
    return null;
  }
}

/// Role of this device in the local cluster
enum ClusterRole {
  unknown,
  leader,
  follower,
  pendingTakeover,
}

// Needed to avoid circular dependency if PeerConnectionInfo is in lan_peer_manager.dart
// But we cannot redefine it if it is already there.
// We must import it.
// Checking imports: import 'lan_peer_manager.dart'; added.

/// Stub for PeerConnectionInfo if not imported (But it IS imported via lan_peer_manager.dart)
/// ... Actually PeerConnectionInfo is defined in lan_peer_manager.dart.
/// If I import lan_peer_manager.dart, I get it.
/// BUT lan_peer_manager.dart imports local_cluster_service.dart.
/// CIRCULAR DEPENDENCY AGAIN.
/// 
/// PeerConnectionInfo is a simple data class. I should move it to a model file or define it here if possible?
/// Or break the cycle. 
/// 
/// Best: Move PeerConnectionInfo to models or separate file.
/// Or, duplicate the class definition? No, type mismatch.
/// 
/// If I import lan_peer_manager.dart here, and lan_peer_manager.dart imports this file...
/// Dart handles circular imports fine usually.
/// 
/// I will use `PeerConnectionInfo` from `lan_peer_manager.dart`.
