import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'performance_monitor.dart'; // Fixed import path
import 'device_service.dart';
import 'event_processor.dart';
import '../models/event.dart';
import '../db/db_provider.dart';
import 'lan_websocket_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'local_cluster_service.dart';
import 'lan_peer_manager.dart';

/// LAN Sync Service for Cross-Device Event Propagation
/// 
/// Enables real-time inventory synchronization between multiple staff devices
/// on the same local network. Uses UDP multicast for low-latency event announcements.
/// 
/// Flow:
/// 1. Device A makes a sale → EventService.emitEvent()
/// 2. After emit, LANSyncService.broadcastEvent() sends hash to LAN
/// 3. Device B receives hash, requests full event if missing
/// 4. EventProcessor applies the event to Device B's inventory
/// 
/// Security: Only accepts events from the same shop_id to prevent cross-shop pollution.

class LANSyncService {
  static LANSyncService? _instance;
  static LANSyncService get instance => _instance ??= LANSyncService._();
  
  LANSyncService._();
  
  // Multicast configuration
  static const String _multicastAddress = '239.255.255.250'; // Standard SSDP-like address
  static const int _multicastPort = 41420; // Custom Mbeck sync port
  
  // State
  RawDatagramSocket? _socket;
  bool _isListening = false;
  String? _myDeviceId;
  String? _myShopId;
  final Map<String, String> _peerIps = {};
  
  // Heartbeat timer for device presence
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 60);
  
  // Periodic pull timer for reliable sync
  Timer? _pullTimer;
  static const Duration _pullInterval = Duration(seconds: 15);
  
  // Dedup cache for event IDs currently being requested
  final Set<String> _pendingRequests = {};
  
  // Stream subscriptions (tracked for cleanup)
  StreamSubscription? _socketSub;
  StreamSubscription? _wsSub;
  StreamSubscription? _peerSub;
  Future<void>? _startListeningFuture;
  
  // Leader HTTP info (set externally when this device is the leader)
  String? _leaderHttpHost;
  String? _activeLeaderIp;
  
  // WebSocket port for mesh network
  int? _webSocketPort;
  
  // Callbacks
  Function(Event)? onEventReceived;
  Function(String)? onSyncError;
  /// Called when a leader offers its snapshot endpoint to us
  Function(String leaderHost)? onSnapshotOffered;
  
  // Message types
  static const String _msgTypeEventAnnounce = 'EVENT_ANNOUNCE';
  static const String _msgTypeEventRequest = 'EVENT_REQUEST';
  static const String _msgTypeEventResponse = 'EVENT_RESPONSE';
  static const String _msgTypeHeartbeat = 'HEARTBEAT';
  static const String _msgTypeSnapshotRequest = 'SNAPSHOT_REQUEST';
  static const String _msgTypeSnapshotOffer = 'SNAPSHOT_OFFER';
  
  /// Start listening for LAN sync messages
  Future<void> startListening() async {
    if (_isListening) return;
    if (_startListeningFuture != null) return _startListeningFuture!;

    final completer = Completer<void>();
    _startListeningFuture = completer.future;

    try {
      await _startListeningInternal();
      completer.complete();
    } catch (e) {
      _startListeningFuture = null;
      completer.completeError(e);
      rethrow;
    }
  }

  Future<void> _startListeningInternal() async {
    try {
      _myDeviceId = await DeviceService.getDeviceId();
      _myShopId = await DeviceService.getShopId();
      
      // Bind to any available port for receiving
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _multicastPort,
        reuseAddress: true,
        reusePort: false,
      );
      
      // Join multicast group on specific interface
      final interface = await _getBestInterface();
      if (interface != null) {
        debugPrint('📡 Joining multicast on interface: ${interface.name}');
        _socket!.joinMulticast(InternetAddress(_multicastAddress), interface);
        try {
          // Tell OS to use this specific interface for outgoing multicast UDP
          _socket!.multicastInterface = interface;
        } catch (e) {
          // Gracefully handle devices that don't support manual multicast interface selection
          if (e is UnimplementedError) {
            debugPrint('ℹ️ Platform does not support setting multicast interface manually (Common on HiOS/MIUI). Using default.');
          } else {
            debugPrint('⚠️ Could not set multicast interface: $e');
          }
          // Continue anyway, as joinMulticast was already called on the interface
        }
      } else {
        debugPrint('⚠️ No suitable network interface found, trying default multicast join...');
        _socket!.joinMulticast(InternetAddress(_multicastAddress));
      }

      _socket!.broadcastEnabled = true;
      
      // Listen for incoming datagrams AND async errors
      _socketSub = _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      }, onError: (e, stack) {
        debugPrint('⚠️ LAN Socket background error: $e');
      });
      
      // Listen for WebSocket Sync Events and Requests
      _wsSub = LanWebSocketService.instance.messages.listen((msg) {
        if (msg.type == MessageType.SYNC_EVENT) {
           _handleWebSocketSyncEvent(msg);
        } else if (msg.type == MessageType.STATE_REQUEST) {
           _handleStateRequest(msg);
        }
      });
      
      // Trigger historical delta sync ONLY on genuine new connections
      _peerSub = LanPeerManager.instance.events.listen((event) {
        if (event.type == PeerEventType.connected) {
           requestSyncFromPeer(event.peerId);
        }
      });
      
      _isListening = true;
      debugPrint('📡 LAN Sync started on $_multicastAddress:$_multicastPort');
      
      // Start periodic heartbeat
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
      _sendHeartbeat(); // Send immediately
      
      // Removed periodic HTTP reliable pull
      _pullTimer?.cancel();
      _pullTimer = null;
      
    } catch (e) {
      debugPrint('❌ Failed to start LAN sync: $e');
      onSyncError?.call('Failed to start LAN sync: $e');
      rethrow;
    }
  }
  
  /// Stop listening for LAN sync messages
  Future<void> stopListening() async {
    _socketSub?.cancel();
    _socketSub = null;
    _wsSub?.cancel();
    _wsSub = null;
    _peerSub?.cancel();
    _peerSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _pullTimer?.cancel();
    _pullTimer = null;
    _socket?.close();
    _socket = null;
    _isListening = false;
    _startListeningFuture = null;
    debugPrint('🔕 LAN Sync stopped');
  }
  
  /// Set this device as the leader, providing the HTTP host:port for snapshot serving
  void setLeaderHttpHost(String host) {
    _leaderHttpHost = host;
    debugPrint('📡 LAN Sync: Leader HTTP endpoint set to $host');
  }
  
  /// Set WebSocket port for mesh network integration
  void setWebSocketPort(int port) {
    _webSocketPort = port;
    debugPrint('🔌 LAN Sync: WebSocket port set to $port');
  }
  
  /// Broadcast an event announcement to LAN peers
  /// 
  /// Now utilizes the WebSocket Mesh for full payload delivery,
  /// replacing the UDP announce+request fallback process.
  Future<void> broadcastEvent(Event event) async {
    if (!_isListening) {
      debugPrint('⚠️ LAN Sync not active, skipping broadcast');
      return;
    }
    
    PerformanceMonitor().startTrace('LANSync.broadcastEventWS');

    try {
      final message = WebSocketMessage(
        type: MessageType.SYNC_EVENT,
        data: {
          'event': event.toMap(),
          'shopId': event.shopId,
          'deviceId': event.deviceId,
          'wsPort': _webSocketPort,
        },
      );
      
      await LanWebSocketService.instance.broadcast(message);
      
      debugPrint('📤 Broadcast WS event: ${event.eventType} (${event.id.substring(0, 8)}...)');
      PerformanceMonitor().endTrace('LANSync.broadcastEventWS');
      
    } catch (e) {
      debugPrint('❌ Failed to broadcast WS event: $e');
      PerformanceMonitor().endTrace('LANSync.broadcastEventWS', metadata: {'error': e.toString()});
    }
  }
  
  /// Handle incoming UDP datagram
  void _handleDatagram(Datagram datagram) {
    try {
      final data = utf8.decode(datagram.data);
      final message = jsonDecode(data) as Map<String, dynamic>;
      
      final type = message['type'] as String?;
      final shopId = message['shopId'] as String?;
      final deviceId = message['deviceId'] as String?;
      
      debugPrint('📥 LAN Sync: Received $type from $deviceId');
      
      // Ignore our own messages
      if (deviceId == _myDeviceId) {
        debugPrint('🔄 LAN Sync: Ignoring own message');
        return;
      }
      
      // Ignore messages from other shops (security!)
      if (shopId != _myShopId) {
        debugPrint('🚫 LAN Sync: Ignoring message from different shop: $shopId');
        return;
      }
      
      switch (type) {
        case _msgTypeEventAnnounce:
          _handleEventAnnounce(message, datagram.address);
          break;
        case _msgTypeEventRequest:
          _handleEventRequest(message, datagram.address, datagram.port);
          break;
        case _msgTypeEventResponse:
          _handleEventResponse(message, datagram.address);
          break;
        case _msgTypeHeartbeat:
          if (deviceId != null) {
            _peerIps[deviceId] = datagram.address.address;
            
            // Connect via WebSocket Mesh natively using UDP heartbeat
            final wsPort = message['webSocketPort'] as int?;
            if (wsPort != null && deviceId != _myDeviceId) {
              LanPeerManager.instance.addPeer(datagram.address.address, wsPort, deviceId);
            }
          }
          // Heartbeat — Track the active leader IP for reliable HTTP fallbacks
          if (message['isLeader'] == true && message['httpHost'] != null) {
            _activeLeaderIp = message['httpHost'] as String;
          }
          break;
        case _msgTypeSnapshotRequest:
          _handleSnapshotRequest(message, datagram.address, datagram.port);
          break;
        case _msgTypeSnapshotOffer:
          _handleSnapshotOffer(message);
          break;
        default:
          debugPrint('⚠️ Unknown LAN sync message type: $type');
      }
      
    } catch (e) {
      debugPrint('❌ Failed to handle LAN sync datagram: $e');
    }
  }
  
  /// Handle event announcement from another device
  Future<void> _handleEventAnnounce(Map<String, dynamic> message, InternetAddress source) async {
    final eventId = message['eventId'] as String?;
    final eventType = message['eventType'] as String?;
    final eventHash = message['eventHash'] as String?;
    
    if (eventId == null || eventHash == null) return;
    
    debugPrint('📥 Received event announce: $eventType ($eventId)');
    
    // Track peer address for image fetching
    _knownPeerAddresses.add(source.address);
    
    // Check if we already have this event
    final db = await DbProvider.db;
    final existing = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    
    if (existing.isNotEmpty) {
      // Already have it, verify hash matches
      final localEvent = Event.fromMap(existing.first);
      if (localEvent.hash == eventHash) {
        debugPrint('✅ Event already exists locally with matching hash');
      } else {
        debugPrint('⚠️ Event exists but hash mismatch! Local: ${localEvent.hash}, Remote: $eventHash');
      }
      return;
    }
    
    // Request full event from the sender (with dedup)
    if (_pendingRequests.contains(eventId)) {
      debugPrint('⏳ Already requesting event: $eventId');
      return;
    }
    _pendingRequests.add(eventId);
    await _requestEvent(eventId, source);
    // Remove from pending after short delay
    Future.delayed(const Duration(seconds: 10), () => _pendingRequests.remove(eventId));
  }
  
  /// Request full event data from a peer
  Future<void> _requestEvent(String eventId, InternetAddress target) async {
    if (_socket == null) return;
    
    final message = {
      'type': _msgTypeEventRequest,
      'eventId': eventId,
      'shopId': _myShopId,
      'deviceId': _myDeviceId,
    };
    
    try {
      final data = utf8.encode(jsonEncode(message));
      _socket!.send(data, target, _multicastPort);
      
      debugPrint('📨 Requested event: $eventId from ${target.address}');
    } catch (e) {
      debugPrint('⚠️ Failed to request event: $e');
    }
  }
  
  /// Handle event request from a peer
  Future<void> _handleEventRequest(Map<String, dynamic> message, InternetAddress source, int port) async {
    final eventId = message['eventId'] as String?;
    if (eventId == null) return;
    
    // Find the event in our database
    final db = await DbProvider.db;
    final rows = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    
    if (rows.isEmpty) {
      debugPrint('⚠️ Requested event not found: $eventId');
      return;
    }
    
    // Send full event data, include WebSocket port for image fetching
    final event = Event.fromMap(rows.first);
    final wsPort = LanWebSocketService.instance.serverPort;
    final response = {
      'type': _msgTypeEventResponse,
      'event': event.toMap(),
      'shopId': _myShopId,
      'deviceId': _myDeviceId,
      'wsPort': wsPort,
    };
    
    try {
      final data = utf8.encode(jsonEncode(response));
      _socket!.send(data, source, port);
      
      debugPrint('📤 Sent event response: ${event.eventType} to ${source.address} (wsPort: $wsPort)');
    } catch (e) {
      debugPrint('⚠️ Failed to send event response: $e');
    }
  }
  
  /// Handle event response (full event data) from a peer
  Future<void> _handleEventResponse(Map<String, dynamic> message, InternetAddress source) async {
    final eventData = message['event'] as Map<String, dynamic>?;
    if (eventData == null) return;
    
    try {
      PerformanceMonitor().startTrace('LANSync.handleResponse');
      final event = Event.fromMap(eventData);
      
      // Verify event integrity
      if (!event.verifyIntegrity()) {
        debugPrint('❌ Received event failed integrity check: ${event.id}');
        return;
      }
      
      // Verify shop ID matches (double-check security)
      if (event.shopId != _myShopId) {
        debugPrint('🚫 Received event from different shop: ${event.shopId}');
        return;
      }
      
      // Check if we already have it (race condition protection)
      final db = await DbProvider.db;
      final existing = await db.query(
        'events',
        where: 'id = ?',
        whereArgs: [event.id],
        limit: 1,
      );
      
      if (existing.isNotEmpty) {
        debugPrint('⚠️ Event already exists (race): ${event.id}');
        return;
      }
      
      // Process the event (EventProcessor handles insertion + side effects)
      await EventProcessor.processEvent(event);
      debugPrint('✅ Processed LAN event: ${event.eventType}');

      // Fetch images for inventory events
      final wsPort = message['wsPort'] as int?;
      if ((event.eventType == 'INVENTORY_CREATE' || event.eventType == 'INVENTORY_UPDATE') &&
          event.payload['imagePath'] != null &&
          event.payload['imagePath'].toString().isNotEmpty &&
          wsPort != null) {
        _fetchImageFromPeer(event.payload['imagePath'], source.address, wsPort);
      }
      
      onEventReceived?.call(event);
      PerformanceMonitor().endTrace('LANSync.handleResponse', metadata: {'type': event.eventType});
      
    } catch (e) {
      debugPrint('❌ Failed to process received event: $e');
      PerformanceMonitor().endTrace('LANSync.handleResponse', metadata: {'error': e.toString()});
      onSyncError?.call('Failed to process LAN event: $e');
    }
  }

  /// Handle Sync Event received over WebSocket
  Future<void> _handleWebSocketSyncEvent(WebSocketMessage message) async {
    final eventData = message.data['event'] as Map<String, dynamic>?;
    final shopId = message.data['shopId'] as String?;
    final deviceId = message.data['deviceId'] as String?;
    final wsPort = message.data['wsPort'] as int?;

    if (eventData == null || shopId == null || deviceId == null) return;

    // Ignore our own messages
    if (deviceId == _myDeviceId) return;

    // Ignore messages from other shops (security!)
    if (shopId != _myShopId) {
      debugPrint('🚫 LAN Sync: Ignoring message from different shop: $shopId');
      return;
    }

    try {
      PerformanceMonitor().startTrace('LANSync.handleWSEvent');
      final event = Event.fromMap(eventData);

      // Verify event integrity
      if (!event.verifyIntegrity()) {
        debugPrint('❌ Received WS event failed integrity check: ${event.id}');
        return;
      }

      // Check if we already have it (race condition protection)
      final db = await DbProvider.db;
      final existing = await db.query(
        'events',
        where: 'id = ?',
        whereArgs: [event.id],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        debugPrint('⚠️ WS Event already exists: ${event.id}');
        return;
      }

      // Process the event
      await EventProcessor.processEvent(event);
      debugPrint('✅ Processed LAN WS event: ${event.eventType}');

      // Fetch images for inventory events (fallback to HTTP server)
      if ((event.eventType == 'INVENTORY_CREATE' || event.eventType == 'INVENTORY_UPDATE') &&
          event.payload['imagePath'] != null &&
          event.payload['imagePath'].toString().isNotEmpty &&
          wsPort != null) {
        final peerIp = _peerIps[deviceId];
        if (peerIp != null) {
           _fetchImageFromPeer(event.payload['imagePath'], peerIp, wsPort);
        } else {
           debugPrint('⚠️ Cannot fetch image over LAN: unknown IP for device $deviceId');
        }
      }
      
      onEventReceived?.call(event);
      PerformanceMonitor().endTrace('LANSync.handleWSEvent', metadata: {'type': event.eventType});
      
    } catch (e) {
      debugPrint('❌ Failed to process WS event: $e');
      PerformanceMonitor().endTrace('LANSync.handleWSEvent', metadata: {'error': e.toString()});
      onSyncError?.call('Failed to process LAN WS event: $e');
    }
  }
  
  /// Handle a request from a peer for missing events
  Future<void> _handleStateRequest(WebSocketMessage message) async {
    final sinceTimestamp = message.data['sinceTimestamp'] as int?;
    final senderId = message.senderId;
    
    if (sinceTimestamp == null || senderId == null) return;
    
    debugPrint('📥 Received STATE_REQUEST from $senderId since $sinceTimestamp');
    
    final db = await DbProvider.db;
    // Only send OUR device's events — the peer is asking for what WE have that they don't
    final events = await db.query(
      'events',
      where: 'timestamp > ? AND device_id = ?',
      whereArgs: [sinceTimestamp, _myDeviceId],
      orderBy: 'timestamp ASC',
      limit: 200, // Reasonable cap per request
    );
    
    if (events.isEmpty) return;
    
    debugPrint('📤 Sending ${events.length} missing events to $senderId');
    
    // Burst missing events to the requesting peer
    for (final row in events) {
      final mutableEvent = Map<String, dynamic>.from(row);
      if (mutableEvent['payload'] is String) {
         mutableEvent['payload'] = jsonDecode(mutableEvent['payload'] as String);
      }
      
      final event = Event.fromMap(mutableEvent);
      
      final msg = WebSocketMessage(
        type: MessageType.SYNC_EVENT,
        data: {
          'event': event.toMap(),
          'shopId': event.shopId,
          'deviceId': event.deviceId,
          'wsPort': _webSocketPort,
        },
      );
      
      await LanWebSocketService.instance.sendToPeer(senderId, msg);
      await Future.delayed(const Duration(milliseconds: 10)); // Slight throttle
    }
  }

  /// Fetch an image file from the source device via its HTTP server
  /// Non-blocking — failures are logged but don't break sync
  Future<void> _fetchImageFromPeer(String imagePath, String peerIp, int wsPort) async {
    try {
      if (imagePath.startsWith('http')) return;

      final filename = p.basename(imagePath);
      
      // Check if file already exists locally
      final directory = await getApplicationDocumentsDirectory();
      final localFile = File(p.join(directory.path, filename));
      if (await localFile.exists()) {
        debugPrint('📸 Image already exists locally: $filename');
        return;
      }

      // Fetch via HTTP from peer's WebSocket server
      final url = 'http://$peerIp:$wsPort/images/$filename';
      debugPrint('📸 Fetching image from peer: $url');

      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 5);
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>([], (prev, element) => prev..addAll(element));
        await localFile.writeAsBytes(bytes);
        debugPrint('✅ Saved synced image: $filename (${bytes.length} bytes)');
      } else {
        debugPrint('⚠️ Image fetch failed: HTTP ${response.statusCode}');
      }
      httpClient.close();
    } catch (e) {
      debugPrint('⚠️ Image fetch failed (non-fatal): $e');
    }
  }

  /// Track known peer addresses from UDP announces
  final Set<String> _knownPeerAddresses = {};
  
  /// Fetch missing events from the leader via HTTP (Reliable Fallback for UDP)
  Future<void> _pullMissingEventsFromLeader() async {
    if (!_isListening) return;
    
    // Only Followers should pull from the Leader
    final leaderIp = _activeLeaderIp ?? LocalClusterService.instance.leaderIp;
    if (leaderIp == null || LocalClusterService.instance.isLeader) {
      return; 
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncKey = 'lan_last_pull_$_myShopId';
      final lastSyncTimestamp = prefs.getInt(lastSyncKey) ?? 0;

      final url = 'http://$leaderIp:8080/api/v1/events/sync?since=$lastSyncTimestamp';
      
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        
        final eventsList = data['events'] as List<dynamic>? ?? [];
        if (eventsList.isEmpty) {
          client.close();
          return;
        }
        
        debugPrint('📥 LAN Sync: Reliable Pull fetched ${eventsList.length} events from leader');
        
        int maxTimestamp = lastSyncTimestamp;
        int processedCount = 0;
        
        final db = await DbProvider.db;

        for (final eventJson in eventsList) {
          try {
            final eventMap = Map<String, dynamic>.from(eventJson as Map);
            
            // Skip our own events
            if (eventMap['device_id'] == _myDeviceId) continue;
            
            // Check if we already have this event
            final existing = await db.query(
              'events',
              where: 'id = ?',
              whereArgs: [eventMap['id']],
              limit: 1,
            );
            
            if (existing.isNotEmpty) continue;
            
            final event = Event.fromMap(eventMap);
            
            // Verify integrity
            if (!event.verifyIntegrity()) {
               debugPrint('❌ LAN Sync Pull: Integrity check failed for ${event.id}');
               continue;
            }
            
            // Apply event
            final applied = await EventProcessor.processEvent(event);
            if (applied) {
              processedCount++;
              debugPrint('✅ LAN Sync Pull: Applied missed event ${event.id} (${event.eventType})');
            }
            
            if (event.timestamp > maxTimestamp) {
              maxTimestamp = event.timestamp;
            }
          } catch (e) {
            debugPrint('⚠️ Error processing pulled event: $e');
          }
        }
        
        // Update checkpoint
        if (maxTimestamp > lastSyncTimestamp) {
          await prefs.setInt(lastSyncKey, maxTimestamp);
        }
        
      }
      
      client.close();
      
      // Also push our missing events to the leader
      await _pushMissingEventsToLeader(leaderIp);
      
    } catch (e) {
      // Don't clutter logs with connection timeouts if leader is occasionally unreachable
    }
  }

  /// Push missing events to the leader's HTTP API (Reliable upward fallback)
  Future<void> _pushMissingEventsToLeader(String leaderIp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPushKey = 'lan_last_push_$_myShopId';
      final lastPushTimestamp = prefs.getInt(lastPushKey) ?? 0;

      final db = await DbProvider.db;
      final events = await db.query(
        'events',
        where: 'device_id = ? AND timestamp > ?',
        whereArgs: [_myDeviceId, lastPushTimestamp],
        orderBy: 'timestamp ASC',
        limit: 100,
      );

      if (events.isEmpty) return;

      final formattedEvents = events.map((row) {
        final mutableEvent = Map<String, dynamic>.from(row);
        if (mutableEvent['payload'] is String) {
           mutableEvent['payload'] = jsonDecode(mutableEvent['payload'] as String);
        }
        return mutableEvent;
      }).toList();

      final url = 'http://$leaderIp:8080/api/v1/events/push';
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      
      // Removed: Legacy HTTP API payload push
    } catch (e) {
      // Ignore timeouts quietly
    }
  }

  /// Request missing events from a specific peer
  Future<void> requestSyncFromPeer(String peerId) async {
    final db = await DbProvider.db;
    
    // Per-peer high-water mark: find the most recent event we have FROM this specific peer
    // This correctly handles the case where our global MAX(timestamp) is from our OWN events
    // but we're missing older events from the peer that were created during a disconnect
    final result = await db.rawQuery(
      'SELECT MAX(timestamp) as max_ts FROM events WHERE device_id = ?',
      [peerId],
    );
    int lastSyncTimestamp = 0;
    
    if (result.isNotEmpty && result.first['max_ts'] != null) {
      lastSyncTimestamp = result.first['max_ts'] as int;
    }
    
    final msg = WebSocketMessage(
      type: MessageType.STATE_REQUEST,
      data: {
        'sinceTimestamp': lastSyncTimestamp,
        'deviceId': _myDeviceId,
      }
    );
    
    debugPrint('📨 Requesting missing events FROM $peerId since $lastSyncTimestamp');
    await LanWebSocketService.instance.sendToPeer(peerId, msg);
  }

  /// Broadcast ALL pending events from this device to LAN peers
  /// 
  /// Previously limited to 1-hour window. Now replays ALL local events
  /// so new devices joining get the full event history via UDP.
  Future<void> broadcastPendingEvents() async {
    final db = await DbProvider.db;
    
    // Broadcast most recent events from this device (capped at 50, last 24 hours)
    final oneDayAgo = DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
    
    final events = await db.query(
      'events',
      where: 'device_id = ? AND timestamp > ?',
      whereArgs: [_myDeviceId, oneDayAgo],
      orderBy: 'timestamp DESC',
      limit: 50,
    );
    
    // Reverse the list so that events are broadcast chronologically (oldest first within the 100 newest)
    for (final row in events.reversed) {
      final event = Event.fromMap(row);
      await broadcastEvent(event);
      await Future.delayed(const Duration(milliseconds: 20)); // Rate limit
    }
    
    debugPrint('📡 Broadcast ${events.length} pending events to LAN');
  }
  
  /// Send a periodic heartbeat to announce presence on LAN
  void _sendHeartbeat() {
    if (!_isListening || _socket == null) return;
    
    try {
      final message = {
        'type': _msgTypeHeartbeat,
        'shopId': _myShopId,
        'deviceId': _myDeviceId,
        'isLeader': _leaderHttpHost != null,
        'httpHost': _leaderHttpHost,
        'webSocketPort': _webSocketPort,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final data = utf8.encode(jsonEncode(message));
      _socket!.send(data, InternetAddress(_multicastAddress), _multicastPort);
    } catch (e) {
      debugPrint('⚠️ Heartbeat send failed: $e');
    }
  }
  
  /// Request a snapshot from the leader device
  /// 
  /// Called by follower devices when their DB is empty on first join.
  /// The leader will respond with a SNAPSHOT_OFFER containing its HTTP address.
  Future<void> requestSnapshot() async {
    if (!_isListening || _socket == null) return;
    
    final message = {
      'type': _msgTypeSnapshotRequest,
      'shopId': _myShopId,
      'deviceId': _myDeviceId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    try {
      final data = utf8.encode(jsonEncode(message));
      _socket!.send(data, InternetAddress(_multicastAddress), _multicastPort);
      debugPrint('📸 Snapshot requested from LAN leader');
    } catch (e) {
      debugPrint('⚠️ Failed to request snapshot: $e');
    }
  }
  
  /// Handle incoming snapshot request (only leader responds)
  void _handleSnapshotRequest(
      Map<String, dynamic> message, InternetAddress source, int port) {
    if (_leaderHttpHost == null) {
      // We're not the leader, ignore
      return;
    }
    
    debugPrint('📸 Received snapshot request from ${message['deviceId']}');
    
    // Respond with our HTTP address
    final response = {
      'type': _msgTypeSnapshotOffer,
      'shopId': _myShopId,
      'deviceId': _myDeviceId,
      'httpHost': _leaderHttpHost,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    try {
      final data = utf8.encode(jsonEncode(response));
      _socket!.send(data, source, port);
      
      debugPrint('📸 Sent snapshot offer to ${source.address}: $_leaderHttpHost');
    } catch (e) {
      debugPrint('⚠️ Failed to send snapshot offer: $e');
    }
  }
  
  /// Handle snapshot offer from the leader
  void _handleSnapshotOffer(Map<String, dynamic> message) {
    final httpHost = message['httpHost'] as String?;
    if (httpHost == null) return;
    
    debugPrint('📸 Received snapshot offer from leader: $httpHost');
    onSnapshotOffered?.call(httpHost);
  }
  
  bool get isListening => _isListening;

  /// Find the best network interface for multicast
  /// Prefer Wi-Fi (wlan0) and ensure it supports IPv4
  Future<NetworkInterface?> _getBestInterface() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        // Prioritize Wi-Fi interfaces
        if (interface.name.toLowerCase().contains('wlan') || 
            interface.name.toLowerCase().contains('wifi')) {
          return interface;
        }
      }
      
      // Fallback: any non-loopback interface
      for (final interface in interfaces) {
        if (!interface.name.toLowerCase().contains('lo')) {
          return interface;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to list network interfaces: $e');
    }
    return null;
  }
}
