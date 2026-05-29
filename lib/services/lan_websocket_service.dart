import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'device_service.dart';
import 'lan_sync_service.dart';

/// LAN WebSocket Service - Persistent peer-to-peer mesh network
/// 
/// Provides reliable WebSocket connections between all devices on the same LAN.
/// Each device runs a WebSocket server and connects to all discovered peers.
/// 
/// Features:
/// - Automatic peer discovery via mDNS (handled by LANSyncService)
/// - Persistent connections with auto-reconnect
/// - Message routing and broadcasting
/// - Reliable delivery with acknowledgments
/// - Hybrid UDP+WebSocket communication
class LanWebSocketService {
  static LanWebSocketService? _instance;
  static LanWebSocketService get instance => _instance ??= LanWebSocketService._();
  
  LanWebSocketService._();
  
  // Server components
  HttpServer? _server;
  int? _serverPort;
  final Map<String, StreamChannel> _connections = {};
  
  // Client connections to peers
  final Map<String, StreamChannel> _peerConnections = {};
  final Map<String, DateTime> _lastHeartbeat = {};
  
  // Message handling
  StreamController<WebSocketMessage>? _messageController;
  final Map<String, Completer<WebSocketMessage>> _pendingAcks = {};
  
  // State
  bool _isRunning = false;
  Timer? _heartbeatTimer;
  Timer? _cleanupTimer;
  
  // Getters
  bool get isRunning => _isRunning;
  int? get serverPort => _serverPort;
  Stream<WebSocketMessage> get messages {
    _messageController ??= StreamController<WebSocketMessage>.broadcast();
    return _messageController!.stream;
  }
  Map<String, StreamChannel> get peerConnections => Map.unmodifiable(_peerConnections);
  
  /// Start the WebSocket server and begin peer discovery
  Future<void> start() async {
    if (_isRunning) return;
    
    try {
      _messageController ??= StreamController<WebSocketMessage>.broadcast();
      await _startServer();
      _startHeartbeat();
      _startCleanup();
      _isRunning = true;
      
      debugPrint('🔌 LAN WebSocket Service started on port $_serverPort');
      
      // Notify LANSyncService that we're ready for connections
      LANSyncService.instance.setWebSocketPort(_serverPort!);
      
    } catch (e) {
      debugPrint('❌ Failed to start WebSocket service: $e');
      rethrow;
    }
  }
  
  /// Stop the WebSocket service and close all connections
  Future<void> stop() async {
    if (!_isRunning) return;
    
    _isRunning = false;
    _heartbeatTimer?.cancel();
    _cleanupTimer?.cancel();
    
    // Close server
    await _server?.close();
    _server = null;
    _serverPort = null;
    
    // Close all connections
    for (final connection in _connections.values) {
      await connection.sink.close();
    }
    _connections.clear();
    
    for (final connection in _peerConnections.values) {
      await connection.sink.close();
    }
    _peerConnections.clear();
    
    // Close message stream controller
    await _messageController?.close();
    _messageController = null;
    
    debugPrint('🔌 LAN WebSocket Service stopped');
  }
  
  /// Start HTTP server with WebSocket upgrade support
  Future<void> _startServer() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0); // Random port
    _serverPort = _server!.port;
    
    _server!.listen((HttpRequest request) {
      if (request.uri.path == '/ws' && 
          WebSocketTransformer.isUpgradeRequest(request)) {
        _handleWebSocketUpgrade(request);
      } else if (request.uri.path.startsWith('/images/')) {
        _handleImageRequest(request);
      } else {
        request.response.statusCode = 404;
        request.response.close();
      }
    });
  }

  /// Serve an image file to a peer device for LAN sync
  Future<void> _handleImageRequest(HttpRequest request) async {
    try {
      final filename = request.uri.pathSegments.last;
      final directory = await getApplicationDocumentsDirectory();
      final file = File(path.join(directory.path, filename));
      
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add(bytes);
        await request.response.close();
        debugPrint('📸 Served image: $filename (${bytes.length} bytes)');
      } else {
        request.response.statusCode = 404;
        await request.response.close();
      }
    } catch (e) {
      debugPrint('❌ Failed to serve image: $e');
      request.response.statusCode = 500;
      await request.response.close();
    }
  }
  
  /// Handle WebSocket upgrade from incoming peer connections
  void _handleWebSocketUpgrade(HttpRequest request) {
    WebSocketTransformer.upgrade(request).then((WebSocket webSocket) {
      final channel = StreamChannel(webSocket, webSocket);
      final peerId = request.headers.value('x-peer-id') ?? 'unknown';
      
      debugPrint('🔌 Peer connected: $peerId');
      
      _connections[peerId] = channel;
      
      channel.stream.listen(
        (data) => _handleIncomingMessage(peerId, data),
        onDone: () => _handlePeerDisconnect(peerId),
        onError: (error) => debugPrint('❌ WebSocket error for $peerId: $error'),
      );
      
      // Send welcome message
      Future.wait([
        DeviceService.getDeviceId(),
        DeviceService.getShopId(),
      ]).then((results) {
        final deviceId = results[0];
        final shopId = results[1];
        
        if (deviceId != null && shopId != null) {
          sendToPeer(peerId, WebSocketMessage(
            type: MessageType.PEER_ANNOUNCE,
            data: {
              'deviceId': deviceId,
              'shopId': shopId,
            },
          ));
        }
      });
    });
  }
  
  /// Connect to a peer device
  Future<bool> connectToPeer(String peerIp, int peerPort, String peerId) async {
    if (_peerConnections.containsKey(peerId)) {
      debugPrint('🔌 Already connected to peer: $peerId');
      return true;
    }
    
    try {
      final uri = Uri.parse('ws://$peerIp:$peerPort/ws');
      final deviceId = await DeviceService.getDeviceId();
      
      // Custom headers are tricky with IOWebSocketChannel.connect directly if it doesn't support them in some versions
      // But typically it initiates a connection. 
      // Safe way: use WebSocket.connect then wrap
      final webSocket = await WebSocket.connect(
        uri.toString(),
        headers: {'x-peer-id': deviceId},
      );
      
      final channel = StreamChannel(webSocket, webSocket);
      
      _peerConnections[peerId] = channel;
      _lastHeartbeat[peerId] = DateTime.now();
      
      debugPrint('🔌 Connected to peer: $peerId at $peerIp:$peerPort');
      
      channel.stream.listen(
        (data) => _handleIncomingMessage(peerId, data),
        onDone: () => _handlePeerDisconnect(peerId),
        onError: (error) => _handlePeerError(peerId, error),
      );
      
      return true;
    } catch (e) {
      debugPrint('❌ Failed to connect to peer $peerId: $e');
      return false;
    }
  }
  
  /// Disconnect from a peer
  Future<void> disconnectFromPeer(String peerId) async {
    final connection = _peerConnections.remove(peerId);
    if (connection != null) {
      await connection.sink.close();
      _lastHeartbeat.remove(peerId);
      debugPrint('🔌 Disconnected from peer: $peerId');
    }
  }
  
  /// Broadcast message to all connected peers
  /// 
  /// IMPORTANT: Deduplicates peers that have both inbound and outbound connections.
  /// Without this, every message is received twice by peers.
  Future<void> broadcast(WebSocketMessage message) async {
    final data = jsonEncode(message.toJson());
    
    // Build deduplicated map: prefer outbound (_peerConnections) over inbound (_connections)
    final Map<String, StreamChannel> dedupedPeers = {};
    for (final entry in _connections.entries) {
      dedupedPeers[entry.key] = entry.value;
    }
    for (final entry in _peerConnections.entries) {
      dedupedPeers[entry.key] = entry.value; // Overwrites inbound if both exist
    }
    
    for (final entry in dedupedPeers.entries) {
      try {
        entry.value.sink.add(data);
      } catch (e) {
        debugPrint('⚠️ Error broadcasting to peer ${entry.key}: $e');
      }
    }
  }
  
  /// Send message to specific peer
  Future<void> sendToPeer(String peerId, WebSocketMessage message) async {
    final data = jsonEncode(message.toJson());
    
    // Try both connection types
    final connection = _peerConnections[peerId] ?? _connections[peerId];
    if (connection != null) {
      try {
        connection.sink.add(data);
        debugPrint('📤 Sent message to peer $peerId: ${message.type}');
      } catch (e) {
        debugPrint('❌ Error sending to peer $peerId: $e');
      }
    } else {
      debugPrint('❌ No connection to peer: $peerId');
    }
  }
  
  /// Send reliable message with acknowledgment
  Future<bool> sendReliable(String peerId, WebSocketMessage message, {Duration timeout = const Duration(seconds: 5)}) async {
    final messageId = _generateMessageId();
    message.messageId = messageId;
    message.requiresAck = true;
    
    final completer = Completer<WebSocketMessage>();
    _pendingAcks[messageId] = completer;
    
    await sendToPeer(peerId, message);
    
    // Wait for acknowledgment
    try {
      await completer.future.timeout(timeout);
      _pendingAcks.remove(messageId);
      return true;
    } catch (e) {
      _pendingAcks.remove(messageId);
      debugPrint('❌ Reliable message timeout for $messageId');
      return false;
    }
  }
  
  /// Handle incoming message from peer
  void _handleIncomingMessage(String peerId, dynamic data) {
    try {
      // WebSocketChannel stream matches the underlying WebSocket
      // For IOWebSocketChannel(WebSocket), it's typically String or List<int>
      // We assume String (text frame). If it's List<int>, decode it.
      String jsonStr;
      if (data is String) {
        jsonStr = data;
      } else if (data is List<int>) {
        jsonStr = utf8.decode(data);
      } else {
        debugPrint('❌ Unknown data type from peer $peerId: ${data.runtimeType}');
        return;
      }

      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('❌ Invalid message format from peer $peerId');
        return;
      }
      
      final message = WebSocketMessage.fromJson(decoded);
      message.senderId = peerId;
      
      debugPrint('📥 Received message from $peerId: ${message.type}');
      
      // Update heartbeat
      _lastHeartbeat[peerId] = DateTime.now();
      
      // Handle acknowledgments
      if (message.type == MessageType.ACKNOWLEDGMENT) {
        final ackId = message.data['messageId'] as String?;
        if (ackId != null && _pendingAcks.containsKey(ackId)) {
          _pendingAcks[ackId]?.complete(message);
        }
        return;
      }
      
      // Send acknowledgment for reliable messages
      if (message.requiresAck && message.messageId != null) {
        sendToPeer(peerId, WebSocketMessage(
          type: MessageType.ACKNOWLEDGMENT,
          data: {'messageId': message.messageId},
        ));
      }
      
      // Forward to message stream
      _messageController?.add(message);
      
    } catch (e) {
      debugPrint('❌ Failed to parse message from $peerId: $e');
    }
  }
  
  /// Handle peer disconnection
  void _handlePeerDisconnect(String peerId) {
    debugPrint('🔌 Peer disconnected: $peerId');
    
    _connections.remove(peerId);
    _peerConnections.remove(peerId);
    _lastHeartbeat.remove(peerId);
    
    // Notify about peer departure
    _messageController?.add(WebSocketMessage(
      type: MessageType.PEER_LEAVE,
      data: {'peerId': peerId},
    ));
  }
  
  /// Handle peer connection error
  void _handlePeerError(String peerId, dynamic error) {
    debugPrint('❌ Peer connection error $peerId: $error');
    _handlePeerDisconnect(peerId);
  }
  
  /// Send heartbeat to all peers
  Future<void> _sendHeartbeat() async {
    final message = WebSocketMessage(
      type: MessageType.HEARTBEAT,
      data: {
        'deviceId': await DeviceService.getDeviceId(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    
    broadcast(message);
  }
  
  /// Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendHeartbeat());
  }
  
  /// Start cleanup timer for stale connections
  void _startCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) => _cleanupStaleConnections());
  }
  
  /// Remove stale connections and peers
  void _cleanupStaleConnections() {
    final now = DateTime.now();
    final stalePeers = <String>[];
    
    for (final entry in _lastHeartbeat.entries) {
      if (now.difference(entry.value).inMinutes > 2) {
        stalePeers.add(entry.key);
      }
    }
    
    for (final peerId in stalePeers) {
      debugPrint('🧹 Removing stale peer: $peerId');
      _handlePeerDisconnect(peerId);
    }
  }
  
  /// Generate unique message ID
  String _generateMessageId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_pendingAcks.length}';
  }
  
  /// Get connection statistics
  Map<String, dynamic> getStats() {
    return {
      'isRunning': _isRunning,
      'serverPort': _serverPort,
      'incomingConnections': _connections.length,
      'outgoingConnections': _peerConnections.length,
      'pendingAcks': _pendingAcks.length,
      'lastHeartbeats': _lastHeartbeat.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch)),
    };
  }
}

/// WebSocket Message structure
class WebSocketMessage {
  MessageType type;
  Map<String, dynamic> data;
  String? messageId;
  String? senderId;
  bool requiresAck;
  DateTime timestamp;
  
  WebSocketMessage({
    required this.type,
    required this.data,
    this.messageId,
    this.senderId,
    this.requiresAck = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'data': data,
      'messageId': messageId,
      'senderId': senderId,
      'requiresAck': requiresAck,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
  
  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: MessageType.values.firstWhere((e) => e.name == json['type'], orElse: () => MessageType.ERROR),
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      messageId: json['messageId'],
      senderId: json['senderId'],
      requiresAck: json['requiresAck'] ?? false,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
    );
  }
}

/// Message types for WebSocket communication
enum MessageType {
  PEER_ANNOUNCE,
  PEER_LEAVE,
  STATE_UPDATE,
  STATE_DIFF,
  STATE_REQUEST,
  STATE_RESPONSE,
  OPERATION_BEGIN,
  OPERATION_COMMIT,
  OPERATION_ROLLBACK,
  CONFLICT_DETECTED,
  CONFLICT_RESOLVED,
  HEARTBEAT,
  SYNC_EVENT,
  ACKNOWLEDGMENT,
  ERROR,
}
