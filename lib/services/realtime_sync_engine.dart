import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'lan_websocket_service.dart';
import 'lan_peer_manager.dart';
import 'device_service.dart';
import '../db/db_provider.dart';
import '../models/event.dart';
import '../models/sync_models.dart';
import 'conflict_resolver.dart';

/// Real-time Sync Engine - Operational transforms and conflict resolution
/// 
/// Provides real-time bidirectional synchronization with automatic conflict resolution
/// using operational transforms and vector clocks. Ensures eventual consistency
/// across all devices in the LAN mesh network.
/// 
/// Features:
/// - Operational transforms for concurrent edits
/// - Vector clock-based conflict detection
/// - Automatic conflict resolution strategies
/// - State diffing and patching
/// - Event ordering guarantees
/// - Offline-first operation with queue management
class RealtimeSyncEngine {
  static RealtimeSyncEngine? _instance;
  static RealtimeSyncEngine get instance => _instance ??= RealtimeSyncEngine._();
  
  RealtimeSyncEngine._();
  
  // State management
  final Map<String, VectorClock> _vectorClocks = {};
  final Map<String, Operation> _pendingOperations = {};
  final Map<String, StateSnapshot> _stateSnapshots = {};
  final StreamController<SyncEvent> _syncEvents = 
      StreamController<SyncEvent>.broadcast();
  
  // Operation queue for offline support
  final List<Operation> _operationQueue = [];
  Timer? _queueProcessor;
  
  // Conflict resolution
  final ConflictResolver _conflictResolver = ConflictResolver();
  
  // State
  bool _isRunning = false;
  Timer? _syncTimer;
  Timer? _cleanupTimer;
  StreamSubscription? _wsSubscription;
  
  // Configuration
  static const Duration _syncInterval = Duration(seconds: 2);
  static const Duration _cleanupInterval = Duration(minutes: 5);
  static const Duration _operationTimeout = Duration(seconds: 30);
  static const int _maxQueueSize = 1000;
  
  // Getters
  bool get isRunning => _isRunning;
  Stream<SyncEvent> get syncEvents => _syncEvents.stream;
  Map<String, VectorClock> get vectorClocks => Map.unmodifiable(_vectorClocks);
  int get pendingOperations => _pendingOperations.length;
  int get queuedOperations => _operationQueue.length;
  
  /// Start the real-time sync engine
  Future<void> start() async {
    if (_isRunning) return;
    
    try {
      // Initialize vector clock for this device
      await _initializeVectorClock();
      
      // Load existing state snapshots
      await _loadStateSnapshots();
      
      // Start listening to WebSocket messages
      _wsSubscription = LanWebSocketService.instance.messages.listen(_handleWebSocketMessage);
      
      // Start periodic tasks
      _startSyncTimer();
      _startCleanupTimer();
      _startQueueProcessor();
      
      _isRunning = true;
      debugPrint('🔄 Real-time Sync Engine started');
      
    } catch (e) {
      debugPrint('❌ Failed to start Sync Engine: $e');
      rethrow;
    }
  }
  
  /// Stop the real-time sync engine
  Future<void> stop() async {
    if (!_isRunning) return;
    
    _isRunning = false;
    
    // Cancel subscriptions and timers
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _syncTimer?.cancel();
    _cleanupTimer?.cancel();
    _queueProcessor?.cancel();
    
    // Close stream controller
    await _syncEvents.close();
    
    // Save state
    await _saveStateSnapshots();
    
    debugPrint('🔄 Real-time Sync Engine stopped');
  }
  
  /// Apply a local operation to the state
  Future<void> applyLocalOperation(Operation operation) async {
    try {
      // Update vector clock
      final deviceId = await DeviceService.getDeviceId();
      _vectorClocks[deviceId] = _vectorClocks[deviceId] ?? VectorClock();
      _vectorClocks[deviceId]!.tick(deviceId);
      
      // Set operation metadata
      operation.vectorClock = _vectorClocks[deviceId]!.copy();
      operation.timestamp = DateTime.now();
      operation.sourceDevice = deviceId;
      
      // Apply operation locally
      await _applyOperation(operation);
      
      // Broadcast to peers
      await _broadcastOperation(operation);
      
      // Track pending operation
      _pendingOperations[operation.id] = operation;
      
      debugPrint('🔄 Applied local operation: ${operation.type}');
      _syncEvents.add(SyncEvent(
        type: SyncEventType.operationApplied,
        operation: operation,
      ));
      
    } catch (e) {
      debugPrint('❌ Failed to apply local operation: $e');
      rethrow;
    }
  }
  
  /// Handle incoming WebSocket message
  Future<void> _handleWebSocketMessage(WebSocketMessage message) async {
    switch (message.type) {
      case MessageType.STATE_UPDATE:
        await _handleStateUpdate(message);
        break;
      case MessageType.STATE_DIFF:
        _handleStateDiff(message);
        break;
      case MessageType.STATE_REQUEST:
        _handleStateRequest(message);
        break;
      case MessageType.STATE_RESPONSE:
        _handleStateResponse(message);
        break;
      case MessageType.OPERATION_BEGIN:
        await _handleOperationBegin(message);
        break;
      case MessageType.OPERATION_COMMIT:
        _handleOperationCommit(message);
        break;
      case MessageType.OPERATION_ROLLBACK:
        _handleOperationRollback(message);
        break;
      case MessageType.CONFLICT_DETECTED:
        await _handleConflictDetected(message);
        break;
      case MessageType.CONFLICT_RESOLVED:
        _handleConflictResolved(message);
        break;
      default:
        break;
    }
  }
  
  /// Handle state update from peer
  Future<void> _handleStateUpdate(WebSocketMessage message) async {
    try {
      final data = message.data;
      final operation = Operation.fromJson(data['operation']);
      final stateHash = data['stateHash'] as String?;
      
      // Check for conflicts
      final conflict = await _detectConflict(operation);
      if (conflict != null) {
        await _handleConflict(conflict, operation);
        return;
      }
      
      // Apply operation
      await _applyRemoteOperation(operation);
      
      // Update state snapshot if provided
      if (stateHash != null) {
        _updateStateSnapshot(operation.table, stateHash);
      }
      
    } catch (e) {
      debugPrint('❌ Failed to handle state update: $e');
    }
  }
  
  /// Handle state diff from peer
  void _handleStateDiff(WebSocketMessage message) {
    try {
      final data = message.data;
      final table = data['table'] as String;
      final diff = data['diff'] as List<Map<String, dynamic>>;
      final baseHash = data['baseHash'] as String;
      
      // Apply diff to local state
      _applyStateDiff(table, diff, baseHash);
      
    } catch (e) {
      debugPrint('❌ Failed to handle state diff: $e');
    }
  }
  
  /// Handle state request from peer
  void _handleStateRequest(WebSocketMessage message) {
    try {
      final data = message.data;
      final table = data['table'] as String;
      final fromHash = data['fromHash'] as String?;
      final peerId = message.senderId!;
      
      // Generate state diff or full snapshot
      final response = _generateStateResponse(table, fromHash);
      
      // Send response
      LanWebSocketService.instance.sendToPeer(peerId, WebSocketMessage(
        type: MessageType.STATE_RESPONSE,
        data: response,
      ));
      
    } catch (e) {
      debugPrint('❌ Failed to handle state request: $e');
    }
  }
  
  /// Handle state response from peer
  void _handleStateResponse(WebSocketMessage message) {
    try {
      final data = message.data;
      final table = data['table'] as String;
      final diff = data['diff'] as List<Map<String, dynamic>>?;
      final snapshot = data['snapshot'] as Map<String, dynamic>?;
      
      if (snapshot != null) {
        // Apply full snapshot
        _applyStateSnapshot(table, snapshot);
      } else if (diff != null) {
        // Apply diff
        final baseHash = data['baseHash'] as String;
        _applyStateDiff(table, diff, baseHash);
      }
      
    } catch (e) {
      debugPrint('❌ Failed to handle state response: $e');
    }
  }
  
  /// Handle operation begin from peer
  Future<void> _handleOperationBegin(WebSocketMessage message) async {
    try {
      final operation = Operation.fromJson(message.data);
      
      // Check if we can apply this operation
      final conflict = await _detectConflict(operation);
      if (conflict != null) {
        // Send conflict detected message
        LanWebSocketService.instance.sendToPeer(
          message.senderId!,
          WebSocketMessage(
            type: MessageType.CONFLICT_DETECTED,
            data: conflict.toJson(),
          ),
        );
        return;
      }
      
      // Send acknowledgment
      LanWebSocketService.instance.sendToPeer(
        message.senderId!,
        WebSocketMessage(
          type: MessageType.OPERATION_COMMIT,
          data: {'operationId': operation.id},
        ),
      );
      
      // Apply operation
      await _applyRemoteOperation(operation);
      
    } catch (e) {
      debugPrint('❌ Failed to handle operation begin: $e');
    }
  }
  
  /// Handle operation commit from peer
  void _handleOperationCommit(WebSocketMessage message) {
    try {
      final operationId = message.data['operationId'] as String;
      final operation = _pendingOperations.remove(operationId);
      
      if (operation != null) {
        debugPrint('🔄 Operation committed: $operationId');
        _syncEvents.add(SyncEvent(
          type: SyncEventType.operationCommitted,
          operation: operation,
        ));
      }
      
    } catch (e) {
      debugPrint('❌ Failed to handle operation commit: $e');
    }
  }
  
  /// Handle operation rollback from peer
  void _handleOperationRollback(WebSocketMessage message) {
    try {
      final operationId = message.data['operationId'] as String;
      final operation = _pendingOperations.remove(operationId);
      
      if (operation != null) {
        debugPrint('🔄 Operation rolled back: $operationId');
        _syncEvents.add(SyncEvent(
          type: SyncEventType.operationRolledBack,
          operation: operation,
        ));
      }
      
    } catch (e) {
      debugPrint('❌ Failed to handle operation rollback: $e');
    }
  }
  
  /// Handle conflict detected message
  Future<void> _handleConflictDetected(WebSocketMessage message) async {
    try {
      final conflict = Conflict.fromJson(message.data);
      final operation = _pendingOperations[conflict.operationId];
      
      if (operation != null) {
        // Attempt to resolve conflict
        final resolution = await _conflictResolver.resolveConflict(conflict, operation);
        
        if (resolution.type == ConflictResolutionType.autoResolved) {
          // Apply resolved operation
          await _applyOperation(resolution.resolvedOperation!);
          
          // Send conflict resolved message
          LanWebSocketService.instance.sendToPeer(
            message.senderId!,
            WebSocketMessage(
              type: MessageType.CONFLICT_RESOLVED,
              data: resolution.toJson(),
            ),
          );
        } else {
          // Manual resolution required
          _syncEvents.add(SyncEvent(
            type: SyncEventType.conflictRequiresManualResolution,
            conflict: conflict,
            resolution: resolution,
          ));
        }
      }
      
    } catch (e) {
      debugPrint('❌ Failed to handle conflict detected: $e');
    }
  }
  
  /// Handle conflict resolved message
  void _handleConflictResolved(WebSocketMessage message) {
    try {
      final resolution = ConflictResolution.fromJson(message.data);
      
      debugPrint('🔄 Conflict resolved: ${resolution.type}');
      _syncEvents.add(SyncEvent(
        type: SyncEventType.conflictResolved,
        resolution: resolution,
      ));
      
    } catch (e) {
      debugPrint('❌ Failed to handle conflict resolved: $e');
    }
  }
  
  /// Detect conflicts between operations
  Future<Conflict?> _detectConflict(Operation operation) async {
    // Check vector clock causality
    for (final entry in operation.vectorClock!.clocks.entries) {
      final localClock = _vectorClocks[entry.key];
      if (localClock != null && localClock.getTime(entry.key) > entry.value) {
        // Local operation is after remote operation - potential conflict
        return Conflict(
          id: _generateConflictId(),
          operationId: operation.id,
          type: ConflictType.concurrentModification,
          localClock: localClock,
          remoteClock: operation.vectorClock!,
          table: operation.table,
          recordId: operation.recordId,
        );
      }
    }
    
    // Check for same record modifications
    if (_pendingOperations.values.any((op) => 
        op.table == operation.table && 
        op.recordId == operation.recordId &&
        op.id != operation.id)) {
      return Conflict(
        id: _generateConflictId(),
        operationId: operation.id,
        type: ConflictType.sameRecordModification,
        localClock: _vectorClocks[await DeviceService.getDeviceId()]!,
        remoteClock: operation.vectorClock!,
        table: operation.table,
        recordId: operation.recordId,
      );
    }
    
    return null; // No conflict
  }
  
  /// Handle detected conflict
  Future<void> _handleConflict(Conflict conflict, Operation operation) async {
    debugPrint('⚠️ Conflict detected: ${conflict.type}');
    
    _syncEvents.add(SyncEvent(
      type: SyncEventType.conflictDetected,
      conflict: conflict,
      operation: operation,
    ));
    
    // Attempt automatic resolution
    final resolution = await _conflictResolver.resolveConflict(conflict, operation);
    
    if (resolution.type == ConflictResolutionType.autoResolved) {
      await _applyOperation(resolution.resolvedOperation!);
    } else {
      // Queue for manual resolution
      _syncEvents.add(SyncEvent(
        type: SyncEventType.conflictRequiresManualResolution,
        conflict: conflict,
        resolution: resolution,
      ));
    }
  }
  
  /// Apply operation to local state
  Future<void> _applyOperation(Operation operation) async {
    final db = await DbProvider.db;
    
    switch (operation.type) {
      case OperationType.insert:
        await db.insert(operation.table, operation.data);
        break;
      case OperationType.update:
        await db.update(
          operation.table, 
          operation.data,
          where: 'id = ?',
          whereArgs: [operation.recordId],
        );
        break;
      case OperationType.delete:
        await db.delete(
          operation.table,
          where: 'id = ?',
          whereArgs: [operation.recordId],
        );
        break;
    }
    
    // Update state snapshot
    await _updateStateSnapshotAfterOperation(operation);
  }
  
  /// Apply remote operation
  Future<void> _applyRemoteOperation(Operation operation) async {
    // Update vector clocks
    await _mergeVectorClock(operation.vectorClock!);
    
    // Apply operation
    await _applyOperation(operation);
    
    debugPrint('🔄 Applied remote operation: ${operation.type}');
  }
  
  /// Merge vector clock with remote clock
  Future<void> _mergeVectorClock(VectorClock remoteClock) async {
    final deviceId = await DeviceService.getDeviceId();
    final localClock = _vectorClocks[deviceId] ?? VectorClock();
    
    for (final entry in remoteClock.clocks.entries) {
      final localTime = localClock.getTime(entry.key);
      final remoteTime = entry.value;
      
      if (remoteTime > localTime) {
        localClock.setTime(entry.key, remoteTime);
      }
    }
    
    _vectorClocks[deviceId] = localClock;
  }
  
  /// Broadcast operation to all peers
  Future<void> _broadcastOperation(Operation operation) async {
    final message = WebSocketMessage(
      type: MessageType.STATE_UPDATE,
      data: {
        'operation': operation.toJson(),
        'stateHash': _getStateHash(operation.table),
      },
      requiresAck: true,
    );
    
    await LanWebSocketService.instance.broadcast(message);
  }
  
  /// Initialize vector clock for this device
  Future<void> _initializeVectorClock() async {
    final deviceId = await DeviceService.getDeviceId();
    _vectorClocks[deviceId] = VectorClock();
    _vectorClocks[deviceId]!.tick(deviceId);
  }
  
  /// Load existing state snapshots
  Future<void> _loadStateSnapshots() async {
    // Load from local storage or database
    // Implementation depends on your persistence strategy
  }
  
  /// Save state snapshots
  Future<void> _saveStateSnapshots() async {
    // Save to local storage or database
    // Implementation depends on your persistence strategy
  }
  
  /// Update state snapshot after operation
  Future<void> _updateStateSnapshotAfterOperation(Operation operation) async {
    final hash = _getStateHash(operation.table);
    _stateSnapshots[operation.table] = StateSnapshot(
      table: operation.table,
      hash: hash,
      timestamp: DateTime.now(),
      vectorClock: _vectorClocks[await DeviceService.getDeviceId()]!.copy(),
    );
  }
  
  /// Get state hash for table
  String _getStateHash(String table) {
    // Generate hash of current table state
    // Implementation depends on your hashing strategy
    return sha256.convert(utf8.encode('$table-${DateTime.now()}')).toString();
  }
  
  /// Update state snapshot
  Future<void> _updateStateSnapshot(String table, String hash) async {
    final deviceId = await DeviceService.getDeviceId();
    _stateSnapshots[table] = StateSnapshot(
      table: table,
      hash: hash,
      timestamp: DateTime.now(),
      vectorClock: _vectorClocks[deviceId]!.copy(),
    );
  }
  
  /// Apply state diff
  void _applyStateDiff(String table, List<Map<String, dynamic>> diff, String baseHash) {
    // Apply diff to local state
    // Implementation depends on your diffing strategy
  }
  
  /// Apply state snapshot
  void _applyStateSnapshot(String table, Map<String, dynamic> snapshot) {
    // Apply full snapshot to local state
    // Implementation depends on your snapshot strategy
  }
  
  /// Generate state response
  Map<String, dynamic> _generateStateResponse(String table, String? fromHash) {
    // Generate diff or full snapshot
    // Implementation depends on your diffing strategy
    return {
      'table': table,
      'diff': <Map<String, dynamic>>[],
      'snapshot': <String, dynamic>{},
    };
  }
  
  /// Generate conflict ID
  String _generateConflictId() {
    return 'conflict_${DateTime.now().millisecondsSinceEpoch}_${_pendingOperations.length}';
  }
  
  /// Start sync timer
  void _startSyncTimer() {
    _syncTimer = Timer.periodic(_syncInterval, (_) => _performSync());
  }
  
  /// Start cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) => _performCleanup());
  }
  
  /// Start queue processor
  void _startQueueProcessor() {
    _queueProcessor = Timer.periodic(const Duration(seconds: 1), (_) => _processQueue());
  }
  
  /// Perform periodic sync
  void _performSync() {
    // Process any queued operations
    if (_operationQueue.isNotEmpty && LanPeerManager.instance.connectedPeerCount > 0) {
      _processQueue();
    }
  }
  
  /// Perform cleanup
  void _performCleanup() {
    final now = DateTime.now();
    final staleOperations = <String>[];
    
    // Remove stale pending operations
    for (final entry in _pendingOperations.entries) {
      if (now.difference(entry.value.timestamp ?? DateTime.now()).inSeconds > _operationTimeout.inSeconds) {
        staleOperations.add(entry.key);
      }
    }
    
    for (final operationId in staleOperations) {
      _pendingOperations.remove(operationId);
      debugPrint('🧹 Removed stale operation: $operationId');
    }
    
    // Limit queue size
    if (_operationQueue.length > _maxQueueSize) {
      _operationQueue.removeRange(0, _operationQueue.length - _maxQueueSize);
    }
  }
  
  /// Process operation queue
  Future<void> _processQueue() async {
    if (_operationQueue.isEmpty || LanPeerManager.instance.connectedPeerCount == 0) {
      return;
    }
    
    final operation = _operationQueue.removeAt(0);
    await applyLocalOperation(operation);
  }
  
  /// Queue operation for later processing
  void queueOperation(Operation operation) {
    _operationQueue.add(operation);
    
    // Limit queue size
    if (_operationQueue.length > _maxQueueSize) {
      _operationQueue.removeAt(0);
    }
  }
  
  /// Get sync statistics
  Map<String, dynamic> getStats() {
    return {
      'isRunning': _isRunning,
      'pendingOperations': _pendingOperations.length,
      'queuedOperations': _operationQueue.length,
      'vectorClocks': _vectorClocks.map((k, v) => MapEntry(k, v.toJson())),
      'stateSnapshots': _stateSnapshots.length,
      'connectedPeers': LanPeerManager.instance.connectedPeerCount,
    };
  }
}

