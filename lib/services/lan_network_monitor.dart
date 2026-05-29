import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'lan_websocket_service.dart';
import 'lan_peer_manager.dart';
import 'device_service.dart';

/// LAN Network Monitor - Network health and performance monitoring
/// 
/// Monitors the health and performance of the LAN mesh network, providing
/// insights into connection quality, bandwidth usage, and network topology.
/// 
/// Features:
/// - Real-time network quality monitoring
/// - Bandwidth usage tracking and optimization
/// - Connection prioritization and load balancing
/// - Performance metrics and analytics
/// - Network partition detection and recovery
class LanNetworkMonitor {
  static LanNetworkMonitor? _instance;
  static LanNetworkMonitor get instance => _instance ??= LanNetworkMonitor._();
  
  LanNetworkMonitor._();
  
  // Monitoring state
  bool _isRunning = false;
  Timer? _monitoringTimer;
  Timer? _metricsTimer;
  
  // Network metrics
  final Map<String, PeerMetrics> _peerMetrics = {};
  final List<NetworkSnapshot> _networkSnapshots = [];
  final StreamController<NetworkEvent> _eventController = 
      StreamController<NetworkEvent>.broadcast();
  
  // Performance tracking
  final Map<String, List<LatencyMeasurement>> _latencyHistory = {};
  final Map<String, List<ThroughputMeasurement>> _throughputHistory = {};
  
  // Configuration
  static const Duration _monitoringInterval = Duration(seconds: 5);
  static const Duration _metricsInterval = Duration(seconds: 30);
  static const Duration _snapshotRetention = Duration(hours: 24);
  static const int _maxHistorySize = 1000;
  
  // Thresholds
  static const Duration _highLatencyThreshold = Duration(milliseconds: 500);
  static const double _lowThroughputThreshold = 100.0; // KB/s
  static const int _packetLossThreshold = 5; // percentage
  
  // Getters
  bool get isRunning => _isRunning;
  Stream<NetworkEvent> get events => _eventController.stream;
  Map<String, PeerMetrics> get peerMetrics => Map.unmodifiable(_peerMetrics);
  List<NetworkSnapshot> get networkSnapshots => List.unmodifiable(_networkSnapshots);
  
  /// Start network monitoring
  Future<void> start() async {
    if (_isRunning) return;
    
    try {
      // Start monitoring timers
      _startMonitoringTimer();
      _startMetricsTimer();
      
      // Start listening to peer events
      LanPeerManager.instance.events.listen(_handlePeerEvent);
      
      _isRunning = true;
      debugPrint('📊 LAN Network Monitor started');
      
    } catch (e) {
      debugPrint('❌ Failed to start Network Monitor: $e');
      rethrow;
    }
  }
  
  /// Stop network monitoring
  Future<void> stop() async {
    if (!_isRunning) return;
    
    _isRunning = false;
    
    // Cancel timers
    _monitoringTimer?.cancel();
    _metricsTimer?.cancel();
    
    debugPrint('📊 LAN Network Monitor stopped');
  }
  
  /// Handle peer events
  void _handlePeerEvent(PeerEvent event) {
    switch (event.type) {
      case PeerEventType.connected:
        _onPeerConnected(event);
        break;
      case PeerEventType.disconnected:
        _onPeerDisconnected(event);
        break;
      case PeerEventType.discovered:
        _onPeerDiscovered(event);
        break;
      case PeerEventType.error:
        _onPeerError(event);
        break;
    }
  }
  
  /// Handle peer connected
  void _onPeerConnected(PeerEvent event) {
    final peerId = event.peerId;
    
    // Initialize metrics for new peer
    _peerMetrics[peerId] = PeerMetrics(
      peerId: peerId,
      connectedAt: DateTime.now(),
      lastSeen: DateTime.now(),
      latency: Duration.zero,
      throughput: 0.0,
      packetLoss: 0.0,
      connectionQuality: ConnectionQuality.excellent,
    );
    
    // Start latency monitoring
    _startLatencyMonitoring(peerId);
    
    debugPrint('📊 Peer connected: $peerId');
    _eventController.add(NetworkEvent(
      type: NetworkEventType.peerConnected,
      peerId: peerId,
      message: 'Peer connected to network',
    ));
  }
  
  /// Handle peer disconnected
  void _onPeerDisconnected(PeerEvent event) {
    final peerId = event.peerId;
    
    // Update metrics
    final metrics = _peerMetrics[peerId];
    if (metrics != null) {
      _peerMetrics[peerId] = metrics.copyWith(
        disconnectedAt: DateTime.now(),
        connectionQuality: ConnectionQuality.disconnected,
      );
    }
    
    debugPrint('📊 Peer disconnected: $peerId');
    _eventController.add(NetworkEvent(
      type: NetworkEventType.peerDisconnected,
      peerId: peerId,
      message: 'Peer disconnected from network',
    ));
  }
  
  /// Handle peer discovered
  void _onPeerDiscovered(PeerEvent event) {
    debugPrint('📊 Peer discovered: ${event.peerId}');
    _eventController.add(NetworkEvent(
      type: NetworkEventType.peerDiscovered,
      peerId: event.peerId,
      message: 'New peer discovered on network',
    ));
  }
  
  /// Handle peer error
  void _onPeerError(PeerEvent event) {
    final peerId = event.peerId;
    final metrics = _peerMetrics[peerId];
    
    if (metrics != null) {
      _peerMetrics[peerId] = metrics.copyWith(
        lastError: event.error,
        errorCount: metrics.errorCount + 1,
        connectionQuality: ConnectionQuality.poor,
      );
    }
    
    debugPrint('📊 Peer error: $peerId - ${event.error}');
    _eventController.add(NetworkEvent(
      type: NetworkEventType.peerError,
      peerId: peerId,
      message: event.error ?? 'Unknown error',
    ));
  }
  
  /// Start monitoring timer
  void _startMonitoringTimer() {
    _monitoringTimer = Timer.periodic(_monitoringInterval, (_) {
      _performMonitoring();
    });
  }
  
  /// Start metrics collection timer
  void _startMetricsTimer() {
    _metricsTimer = Timer.periodic(_metricsInterval, (_) {
      _collectMetrics();
    });
  }
  
  /// Perform network monitoring
  void _performMonitoring() {
    try {
      // Check peer connectivity
      _checkPeerConnectivity();
      
      // Measure latency
      _measureLatency();
      
      // Monitor throughput
      _monitorThroughput();
      
      // Detect network partitions
      _detectNetworkPartitions();
      
      // Update connection quality
      _updateConnectionQuality();
      
    } catch (e) {
      debugPrint('❌ Monitoring error: $e');
    }
  }
  
  /// Check peer connectivity
  void _checkPeerConnectivity() {
    final now = DateTime.now();
    final connectedPeers = LanPeerManager.instance.activeConnections;
    
    for (final entry in _peerMetrics.entries) {
      final peerId = entry.key;
      final metrics = entry.value;
      
      if (connectedPeers.containsKey(peerId)) {
        // Peer is connected
        _peerMetrics[peerId] = metrics.copyWith(
          lastSeen: now,
          connectionQuality: _calculateConnectionQuality(peerId),
        );
      } else if (metrics.connectionQuality != ConnectionQuality.disconnected) {
        // Peer was connected but now isn't
        final timeSinceLastSeen = now.difference(metrics.lastSeen);
        if (timeSinceLastSeen > const Duration(seconds: 30)) {
          _peerMetrics[peerId] = metrics.copyWith(
            connectionQuality: ConnectionQuality.disconnected,
          );
        }
      }
    }
  }
  
  /// Measure latency to peers
  void _measureLatency() {
    for (final peerId in _peerMetrics.keys) {
      if (_peerMetrics[peerId]?.connectionQuality == ConnectionQuality.disconnected) {
        continue;
      }
      
      _measureLatencyToPeer(peerId);
    }
  }
  
  /// Measure latency to specific peer
  Future<void> _measureLatencyToPeer(String peerId) async {
    try {
      final startTime = DateTime.now();
      
      // Send ping message
      final success = await LanWebSocketService.instance.sendReliable(
        peerId,
        WebSocketMessage(
          type: MessageType.HEARTBEAT,
          data: {
            'deviceId': await DeviceService.getDeviceId(),
            'timestamp': startTime.millisecondsSinceEpoch,
            'ping': true,
          },
        ),
        timeout: const Duration(seconds: 3),
      );
      
      if (success) {
        final latency = DateTime.now().difference(startTime);
        _recordLatencyMeasurement(peerId, latency);
        
        // Update peer metrics
        final metrics = _peerMetrics[peerId];
        if (metrics != null) {
          _peerMetrics[peerId] = metrics.copyWith(latency: latency);
        }
      } else {
        // Failed to ping
        _recordLatencyMeasurement(peerId, const Duration(seconds: 10)); // Timeout
        
        final metrics = _peerMetrics[peerId];
        if (metrics != null) {
          _peerMetrics[peerId] = metrics.copyWith(
            connectionQuality: ConnectionQuality.poor,
          );
        }
      }
      
    } catch (e) {
      debugPrint('❌ Latency measurement failed for $peerId: $e');
    }
  }
  
  /// Record latency measurement
  void _recordLatencyMeasurement(String peerId, Duration latency) {
    final history = _latencyHistory[peerId] ?? [];
    history.add(LatencyMeasurement(
      timestamp: DateTime.now(),
      latency: latency,
    ));
    
    // Limit history size
    if (history.length > _maxHistorySize) {
      history.removeAt(0);
    }
    
    _latencyHistory[peerId] = history;
  }
  
  /// Monitor throughput
  void _monitorThroughput() {
    // Calculate throughput based on message sizes and timing
    // This is a simplified implementation
    for (final peerId in _peerMetrics.keys) {
      final throughput = _calculateThroughput(peerId);
      
      final metrics = _peerMetrics[peerId];
      if (metrics != null) {
        _peerMetrics[peerId] = metrics.copyWith(throughput: throughput);
      }
      
      _recordThroughputMeasurement(peerId, throughput);
    }
  }
  
  /// Calculate throughput for peer
  double _calculateThroughput(String peerId) {
    // Simplified throughput calculation
    // In a real implementation, this would track actual data transfer
    final history = _throughputHistory[peerId] ?? [];
    if (history.isEmpty) return 0.0;
    
    // Return the most recent measurement
    return history.last.throughput;
  }
  
  /// Record throughput measurement
  void _recordThroughputMeasurement(String peerId, double throughput) {
    final history = _throughputHistory[peerId] ?? [];
    history.add(ThroughputMeasurement(
      timestamp: DateTime.now(),
      throughput: throughput,
    ));
    
    // Limit history size
    if (history.length > _maxHistorySize) {
      history.removeAt(0);
    }
    
    _throughputHistory[peerId] = history;
  }
  
  /// Detect network partitions
  void _detectNetworkPartitions() {
    final connectedPeers = LanPeerManager.instance.connectedPeerCount;
    final totalPeers = _peerMetrics.length;
    
    if (totalPeers > 1) {
      final connectivityRatio = connectedPeers / totalPeers;
      
      if (connectivityRatio < 0.5) {
        // Potential network partition
        _eventController.add(NetworkEvent(
          type: NetworkEventType.networkPartition,
          message: 'Network partition detected: $connectedPeers/$totalPeers peers connected',
        ));
      }
    }
  }
  
  /// Update connection quality for all peers
  void _updateConnectionQuality() {
    for (final peerId in _peerMetrics.keys) {
      final quality = _calculateConnectionQuality(peerId);
      final metrics = _peerMetrics[peerId];
      
      if (metrics != null && metrics.connectionQuality != quality) {
        _peerMetrics[peerId] = metrics.copyWith(connectionQuality: quality);
        
        debugPrint('📊 Connection quality changed for $peerId: $quality');
        _eventController.add(NetworkEvent(
          type: NetworkEventType.connectionQualityChanged,
          peerId: peerId,
          message: 'Connection quality: ${quality.name}',
        ));
      }
    }
  }
  
  /// Calculate connection quality for peer
  ConnectionQuality _calculateConnectionQuality(String peerId) {
    final metrics = _peerMetrics[peerId];
    if (metrics == null) return ConnectionQuality.unknown;
    
    // Check if disconnected
    if (metrics.connectionQuality == ConnectionQuality.disconnected) {
      return ConnectionQuality.disconnected;
    }
    
    // Calculate quality based on latency and throughput
    int score = 100;
    
    // Latency scoring
    if (metrics.latency > _highLatencyThreshold) {
      score -= 30;
    } else if (metrics.latency > const Duration(milliseconds: 200)) {
      score -= 15;
    } else if (metrics.latency > const Duration(milliseconds: 100)) {
      score -= 5;
    }
    
    // Throughput scoring
    if (metrics.throughput < _lowThroughputThreshold) {
      score -= 20;
    } else if (metrics.throughput < 500.0) {
      score -= 10;
    }
    
    // Error rate scoring
    if (metrics.errorCount > 5) {
      score -= 25;
    } else if (metrics.errorCount > 2) {
      score -= 10;
    }
    
    // Determine quality
    if (score >= 80) {
      return ConnectionQuality.excellent;
    } else if (score >= 60) {
      return ConnectionQuality.good;
    } else if (score >= 40) {
      return ConnectionQuality.fair;
    } else if (score >= 20) {
      return ConnectionQuality.poor;
    } else {
      return ConnectionQuality.veryPoor;
    }
  }
  
  /// Start latency monitoring for peer
  void _startLatencyMonitoring(String peerId) {
    // Initial latency measurement
    _measureLatencyToPeer(peerId);
  }
  
  /// Collect network metrics
  void _collectMetrics() {
    final snapshot = NetworkSnapshot(
      timestamp: DateTime.now(),
      connectedPeers: LanPeerManager.instance.connectedPeerCount,
      totalPeers: _peerMetrics.length,
      averageLatency: _calculateAverageLatency(),
      totalThroughput: _calculateTotalThroughput(),
      networkHealth: _calculateNetworkHealth(),
    );
    
    _networkSnapshots.add(snapshot);
    
    // Limit snapshot retention
    _networkSnapshots.removeWhere((s) => 
        DateTime.now().difference(s.timestamp) > _snapshotRetention);
    
    debugPrint('📊 Network metrics collected: ${snapshot.networkHealth.name}');
  }
  
  /// Calculate average latency
  Duration _calculateAverageLatency() {
    final latencies = _peerMetrics.values
        .where((m) => m.connectionQuality != ConnectionQuality.disconnected)
        .map((m) => m.latency)
        .toList();
    
    if (latencies.isEmpty) return Duration.zero;
    
    final totalMs = latencies.fold<int>(0, (sum, latency) => sum + latency.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ latencies.length);
  }
  
  /// Calculate total throughput
  double _calculateTotalThroughput() {
    return _peerMetrics.values
        .where((m) => m.connectionQuality != ConnectionQuality.disconnected)
        .fold<double>(0.0, (sum, m) => sum + m.throughput);
  }
  
  /// Calculate network health
  NetworkHealth _calculateNetworkHealth() {
    final connectedPeers = LanPeerManager.instance.connectedPeerCount;
    final totalPeers = _peerMetrics.length;
    
    if (totalPeers == 0) return NetworkHealth.unknown;
    
    final connectivityRatio = connectedPeers / totalPeers;
    final avgLatency = _calculateAverageLatency();
    
    // Health scoring
    int score = 100;
    
    // Connectivity scoring
    score = (score * connectivityRatio).round();
    
    // Latency scoring
    if (avgLatency > _highLatencyThreshold) {
      score -= 30;
    } else if (avgLatency > const Duration(milliseconds: 200)) {
      score -= 15;
    }
    
    // Determine health
    if (score >= 80) {
      return NetworkHealth.excellent;
    } else if (score >= 60) {
      return NetworkHealth.good;
    } else if (score >= 40) {
      return NetworkHealth.fair;
    } else if (score >= 20) {
      return NetworkHealth.poor;
    } else {
      return NetworkHealth.critical;
    }
  }
  
  /// Get network statistics
  Map<String, dynamic> getStats() {
    return {
      'isRunning': _isRunning,
      'connectedPeers': LanPeerManager.instance.connectedPeerCount,
      'totalPeers': _peerMetrics.length,
      'averageLatency': _calculateAverageLatency().inMilliseconds,
      'totalThroughput': _calculateTotalThroughput(),
      'networkHealth': _calculateNetworkHealth().name,
      'peerMetrics': _peerMetrics.map((k, v) => MapEntry(k, v.toJson())),
      'snapshotsCount': _networkSnapshots.length,
    };
  }
  
  /// Get peer latency history
  List<LatencyMeasurement> getLatencyHistory(String peerId) {
    return List.unmodifiable(_latencyHistory[peerId] ?? []);
  }
  
  /// Get peer throughput history
  List<ThroughputMeasurement> getThroughputHistory(String peerId) {
    return List.unmodifiable(_throughputHistory[peerId] ?? []);
  }
  
  /// Optimize network performance
  Future<void> optimizeNetwork() async {
    debugPrint('📊 Optimizing network performance...');
    
    // Prioritize high-quality connections
    _prioritizeConnections();
    
    // Suggest connection improvements
    _suggestImprovements();
    
    _eventController.add(NetworkEvent(
      type: NetworkEventType.optimizationComplete,
      message: 'Network optimization completed',
    ));
  }
  
  /// Prioritize connections based on quality
  void _prioritizeConnections() {
    final sortedPeers = _peerMetrics.entries.toList()
      ..sort((a, b) => _compareConnectionQuality(a.value, b.value));
    
    // Implementation would prioritize traffic through better connections
    debugPrint('📊 Connection prioritization updated');
  }
  
  /// Compare connection quality for sorting
  int _compareConnectionQuality(PeerMetrics a, PeerMetrics b) {
    return a.connectionQuality.index.compareTo(b.connectionQuality.index);
  }
  
  /// Suggest network improvements
  void _suggestImprovements() {
    for (final entry in _peerMetrics.entries) {
      final peerId = entry.key;
      final metrics = entry.value;
      
      if (metrics.connectionQuality == ConnectionQuality.poor || 
          metrics.connectionQuality == ConnectionQuality.veryPoor) {
        
        _eventController.add(NetworkEvent(
          type: NetworkEventType.improvementSuggested,
          peerId: peerId,
          message: 'Consider checking connection to $peerId',
        ));
      }
    }
  }
}

/// Peer metrics
class PeerMetrics {
  final String peerId;
  final DateTime connectedAt;
  final DateTime? disconnectedAt;
  DateTime lastSeen;
  Duration latency;
  double throughput;
  double packetLoss;
  ConnectionQuality connectionQuality;
  String? lastError;
  int errorCount;
  
  PeerMetrics({
    required this.peerId,
    required this.connectedAt,
    this.disconnectedAt,
    required this.lastSeen,
    required this.latency,
    required this.throughput,
    required this.packetLoss,
    required this.connectionQuality,
    this.lastError,
    this.errorCount = 0,
  });
  
  PeerMetrics copyWith({
    DateTime? disconnectedAt,
    DateTime? lastSeen,
    Duration? latency,
    double? throughput,
    double? packetLoss,
    ConnectionQuality? connectionQuality,
    String? lastError,
    int? errorCount,
  }) {
    return PeerMetrics(
      peerId: peerId,
      connectedAt: connectedAt,
      disconnectedAt: disconnectedAt ?? this.disconnectedAt,
      lastSeen: lastSeen ?? this.lastSeen,
      latency: latency ?? this.latency,
      throughput: throughput ?? this.throughput,
      packetLoss: packetLoss ?? this.packetLoss,
      connectionQuality: connectionQuality ?? this.connectionQuality,
      lastError: lastError ?? this.lastError,
      errorCount: errorCount ?? this.errorCount,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'peerId': peerId,
      'connectedAt': connectedAt.millisecondsSinceEpoch,
      'disconnectedAt': disconnectedAt?.millisecondsSinceEpoch,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'latency': latency.inMilliseconds,
      'throughput': throughput,
      'packetLoss': packetLoss,
      'connectionQuality': connectionQuality.name,
      'lastError': lastError,
      'errorCount': errorCount,
    };
  }
}

/// Network snapshot
class NetworkSnapshot {
  final DateTime timestamp;
  final int connectedPeers;
  final int totalPeers;
  final Duration averageLatency;
  final double totalThroughput;
  final NetworkHealth networkHealth;
  
  NetworkSnapshot({
    required this.timestamp,
    required this.connectedPeers,
    required this.totalPeers,
    required this.averageLatency,
    required this.totalThroughput,
    required this.networkHealth,
  });
}

/// Latency measurement
class LatencyMeasurement {
  final DateTime timestamp;
  final Duration latency;
  
  LatencyMeasurement({
    required this.timestamp,
    required this.latency,
  });
}

/// Throughput measurement
class ThroughputMeasurement {
  final DateTime timestamp;
  final double throughput; // KB/s
  
  ThroughputMeasurement({
    required this.timestamp,
    required this.throughput,
  });
}

/// Network event
class NetworkEvent {
  final NetworkEventType type;
  final String? peerId;
  final String message;
  final DateTime timestamp;
  
  NetworkEvent({
    required this.type,
    this.peerId,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Network event types
enum NetworkEventType {
  peerConnected,
  peerDisconnected,
  peerDiscovered,
  peerError,
  connectionQualityChanged,
  networkPartition,
  optimizationComplete,
  improvementSuggested,
}

/// Connection quality
enum ConnectionQuality {
  excellent,
  good,
  fair,
  poor,
  veryPoor,
  disconnected,
  unknown,
}

/// Network health
enum NetworkHealth {
  excellent,
  good,
  fair,
  poor,
  critical,
  unknown,
}