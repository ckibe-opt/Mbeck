import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:stream_channel/stream_channel.dart';
import 'device_service.dart';
import 'lan_websocket_service.dart';
import 'lan_sync_service.dart';
import 'local_cluster_service.dart';

/// LAN Peer Manager - Manages peer discovery and connection lifecycle
/// 
/// Coordinates peer discovery via UDP multicast and maintains WebSocket connections
/// to all discovered peers. Handles automatic reconnection and load balancing.
/// 
/// Features:
/// - Automatic peer discovery via UDP heartbeat messages
/// - WebSocket connection management with auto-reconnect
/// - Load balancing across multiple peers
/// - Health monitoring and connection recovery
/// - Network partition detection and healing
class LanPeerManager {
  static LanPeerManager? _instance;
  static LanPeerManager get instance => _instance ??= LanPeerManager._();
  
  LanPeerManager._();
  
  // Peer tracking
  final Map<String, PeerInfo> _discoveredPeers = {};
  final Map<String, DateTime> _lastSeen = {};
  final Map<String, int> _connectionAttempts = {};
  
  // Cached device info (async-resolved at start)
  String? _myDeviceId;
  String? _myShopId;
  
  // Connection management
  final Map<String, StreamChannel> _activeConnections = {};
  final StreamController<PeerEvent> _eventController = 
      StreamController<PeerEvent>.broadcast();
  
  // State management
  bool _isRunning = false;
  Timer? _discoveryTimer;
  Timer? _healthCheckTimer;
  StreamSubscription<WebSocketMessage>? _websocketSubscription;
  
  // Configuration
  static const Duration _discoveryInterval = Duration(seconds: 10);
  static const Duration _healthCheckInterval = Duration(seconds: 30);
  static const int _maxConnectionAttempts = 3;
  static const Duration _peerTimeout = Duration(minutes: 2);
  
  // Getters
  bool get isRunning => _isRunning;
  Stream<PeerEvent> get events => _eventController.stream;
  Map<String, PeerInfo> get discoveredPeers => Map.unmodifiable(_discoveredPeers);
  Map<String, StreamChannel> get activeConnections => Map.unmodifiable(_activeConnections);
  int get connectedPeerCount => _activeConnections.length;
  
  /// Start peer discovery and connection management
  Future<void> start() async {
    if (_isRunning) return;
    
    try {
      // Cache device info for synchronous handler access
      _myDeviceId = await DeviceService.getDeviceId();
      _myShopId = await DeviceService.getShopId();
      
      // Start WebSocket service
      await LanWebSocketService.instance.start();
      
      // Start listening to WebSocket messages
      await _websocketSubscription?.cancel();
      _websocketSubscription = LanWebSocketService.instance.messages.listen(_handleWebSocketMessage);
      
      // Start listening to UDP heartbeat messages
      LANSyncService.instance.startListening();
      
      // Start periodic tasks
      _startDiscovery();
      _startHealthCheck();
      
      _isRunning = true;
      debugPrint('🔗 LAN Peer Manager started');
      
    } catch (e) {
      debugPrint('❌ Failed to start Peer Manager: $e');
      rethrow;
    }
  }
  
  /// Stop peer discovery and close all connections
  Future<void> stop() async {
    if (!_isRunning) return;
    
    _isRunning = false;
    
    // Cancel timers
    _discoveryTimer?.cancel();
    _healthCheckTimer?.cancel();
    
    // Cancel subscriptions
    await _websocketSubscription?.cancel();
    _websocketSubscription = null;
    
    // Close all WebSocket connections
    for (final connection in _activeConnections.values) {
      await connection.sink.close();
    }
    _activeConnections.clear();
    
    // Stop services
    await LanWebSocketService.instance.stop();
    await LANSyncService.instance.stopListening();
    
    // Clear state
    _discoveredPeers.clear();
    _lastSeen.clear();
    _connectionAttempts.clear();
    
    debugPrint('🔗 LAN Peer Manager stopped');
  }
  
  /// Handle incoming WebSocket messages
  void _handleWebSocketMessage(WebSocketMessage message) {
    switch (message.type) {
      case MessageType.PEER_ANNOUNCE:
        _handlePeerAnnounce(message);
        break;
      case MessageType.PEER_LEAVE:
        _handlePeerLeave(message);
        break;
      case MessageType.HEARTBEAT:
        _handleWebSocketHeartbeat(message);
        break;
      default:
        // Other message types are handled by other services
        break;
    }
  }
  
  /// Handle peer announcement via WebSocket
  void _handlePeerAnnounce(WebSocketMessage message) {
    final deviceId = message.data['deviceId'] as String?;
    final shopId = message.data['shopId'] as String?;
    
    if (deviceId == null || shopId == null) return;
    
    // Skip self
    if (deviceId == _myDeviceId) return;
    
    // Skip different shops
    if (shopId != _myShopId) return;
    
    final peerId = deviceId;
    final now = DateTime.now();
    
    // Update peer info
    _discoveredPeers[peerId] = PeerInfo(
      id: peerId,
      shopId: shopId,
      lastSeen: now,
      isConnected: _activeConnections.containsKey(peerId),
    );
    
    _lastSeen[peerId] = now;
    _connectionAttempts.remove(peerId); // Reset connection attempts
    
    debugPrint('🔗 Peer discovered via WebSocket: $peerId');
    _eventController.add(PeerEvent(
      type: PeerEventType.discovered,
      peerId: peerId,
      peerInfo: _discoveredPeers[peerId]!,
    ));
  }
  
  /// Handle peer departure via WebSocket
  void _handlePeerLeave(WebSocketMessage message) {
    final peerId = message.data['peerId'] as String?;
    if (peerId == null) return;
    
    _removePeer(peerId);
  }
  
  /// Handle WebSocket heartbeat
  void _handleWebSocketHeartbeat(WebSocketMessage message) {
    final deviceId = message.data['deviceId'] as String?;
    if (deviceId == null) return;
    
    _lastSeen[deviceId] = DateTime.now();
    
    // Update peer connection status
    final peer = _discoveredPeers[deviceId];
    if (peer != null) {
      _discoveredPeers[deviceId] = peer.copyWith(
        lastSeen: DateTime.now(),
        isConnected: _activeConnections.containsKey(deviceId),
      );
    }
  }
  
  /// Start periodic peer discovery
  void _startDiscovery() {
    _discoveryTimer = Timer.periodic(_discoveryInterval, (_) {
      _discoverPeers();
    });
  }
  
  /// Discover peers from UDP heartbeat messages
  void _discoverPeers() {
    // This is handled by LANSyncService receiving heartbeat messages
    // We'll process the discovered peers in the health check
  }
  
  /// Start health monitoring of peers
  void _startHealthCheck() {
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      _performHealthCheck();
    });
  }
  
  /// Perform health check on all peers
  void _performHealthCheck() {
    final now = DateTime.now();
    final stalePeers = <String>[];
    
    for (final entry in _lastSeen.entries) {
      if (now.difference(entry.value) > _peerTimeout) {
        stalePeers.add(entry.key);
      }
    }
    
    // Remove stale peers
    for (final peerId in stalePeers) {
      debugPrint('🧹 Removing stale peer: $peerId');
      _removePeer(peerId);
    }
    
    // Try to connect to disconnected peers
    for (final peerId in _discoveredPeers.keys) {
      if (!_activeConnections.containsKey(peerId)) {
        _attemptConnection(peerId);
      }
    }
  }
  

  
  /// Attempt to connect to a peer
  Future<void> _attemptConnection(String peerId) async {
    final attempts = _connectionAttempts[peerId] ?? 0;
    if (attempts >= _maxConnectionAttempts) {
      debugPrint('🔗 Max connection attempts reached for $peerId');
      return;
    }
    
    _connectionAttempts[peerId] = attempts + 1;
    
    try {
      // Get peer info from LocalClusterService or heartbeat
      final peerInfo = await _getPeerConnectionInfo(peerId);
      if (peerInfo == null) {
        debugPrint('🔗 No connection info available for $peerId');
        return;
      }
      
      final success = await LanWebSocketService.instance.connectToPeer(
        peerInfo.ip,
        peerInfo.webSocketPort,
        peerId,
      );
      
      if (success) {
        _activeConnections[peerId] = 
            LanWebSocketService.instance.peerConnections[peerId]!;
        _connectionAttempts.remove(peerId);
        
        debugPrint('🔗 Connected to peer: $peerId');
        _eventController.add(PeerEvent(
          type: PeerEventType.connected,
          peerId: peerId,
          peerInfo: _discoveredPeers[peerId]!,
        ));
      }
      
    } catch (e) {
      debugPrint('🔗 Connection attempt failed for $peerId: $e');
    }
  }
  
  /// Get peer connection information
  Future<PeerConnectionInfo?> _getPeerConnectionInfo(String peerId) async {
    // Try to get from LocalClusterService first
    final clusterPeer = LocalClusterService.instance.getPeerInfo(peerId);
    if (clusterPeer != null) {
      return PeerConnectionInfo(
        ip: clusterPeer.ip,
        webSocketPort: clusterPeer.webSocketPort ?? 8080, // Default port
      );
    }
    
    // Fallback: try to discover from recent heartbeat messages
    // This would require enhancing LANSyncService to track heartbeat senders
    return null;
  }
  
  /// Remove a peer from tracking
  void _removePeer(String peerId) {
    final connection = _activeConnections.remove(peerId);
    if (connection != null) {
      connection.sink.close();
    }
    
    _discoveredPeers.remove(peerId);
    _lastSeen.remove(peerId);
    _connectionAttempts.remove(peerId);
    
    debugPrint('🔗 Peer removed: $peerId');
    _eventController.add(PeerEvent(
      type: PeerEventType.disconnected,
      peerId: peerId,
    ));
  }
  
  /// Get peer statistics
  Map<String, dynamic> getStats() {
    return {
      'isRunning': _isRunning,
      'discoveredPeers': _discoveredPeers.length,
      'connectedPeers': _activeConnections.length,
      'connectionAttempts': _connectionAttempts,
      'lastSeen': _lastSeen.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch)),
    };
  }
  
  /// Manually add a peer (for testing or direct connection)
  Future<bool> addPeer(String ip, int webSocketPort, String peerId) async {
    // Skip if already connected — prevents connected event spam on every heartbeat
    if (_activeConnections.containsKey(peerId)) {
      _lastSeen[peerId] = DateTime.now(); // Keep health check happy
      return true;
    }
    
    final success = await LanWebSocketService.instance.connectToPeer(ip, webSocketPort, peerId);
    if (success) {
      _activeConnections[peerId] = LanWebSocketService.instance.peerConnections[peerId]!;
      _discoveredPeers[peerId] = PeerInfo(
        id: peerId,
        shopId: (await DeviceService.getShopId())!,
        lastSeen: DateTime.now(),
        isConnected: true,
      );
      _lastSeen[peerId] = DateTime.now();
      
      debugPrint('🔗 Connected to manually added peer: $peerId');
      _eventController.add(PeerEvent(
        type: PeerEventType.connected,
        peerId: peerId,
        peerInfo: _discoveredPeers[peerId]!,
      ));
    }
    return success;
  }
}

/// Peer information
class PeerInfo {
  final String id;
  final String shopId;
  final DateTime lastSeen;
  final bool isConnected;
  
  PeerInfo({
    required this.id,
    required this.shopId,
    required this.lastSeen,
    required this.isConnected,
  });
  
  PeerInfo copyWith({
    String? id,
    String? shopId,
    DateTime? lastSeen,
    bool? isConnected,
  }) {
    return PeerInfo(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      lastSeen: lastSeen ?? this.lastSeen,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

/// Peer connection information
class PeerConnectionInfo {
  final String ip;
  final int webSocketPort;
  
  PeerConnectionInfo({
    required this.ip,
    required this.webSocketPort,
  });
}

/// Peer event types
enum PeerEventType {
  discovered,
  connected,
  disconnected,
  error,
}

/// Peer event
class PeerEvent {
  final PeerEventType type;
  final String peerId;
  final PeerInfo? peerInfo;
  final String? error;
  final DateTime timestamp;
  
  PeerEvent({
    required this.type,
    required this.peerId,
    this.peerInfo,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}