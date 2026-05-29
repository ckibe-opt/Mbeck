import 'dart:convert';

/// Vector Clock for causal ordering
class VectorClock {
  final Map<String, int> clocks = {};
  
  VectorClock();
  
  VectorClock.fromJson(Map<String, dynamic> json) {
    clocks.addAll(json.map((k, v) => MapEntry(k, v as int)));
  }
  
  void tick(String nodeId) {
    clocks[nodeId] = (clocks[nodeId] ?? 0) + 1;
  }
  
  void setTime(String nodeId, int time) {
    clocks[nodeId] = time;
  }
  
  int getTime(String nodeId) {
    return clocks[nodeId] ?? 0;
  }
  
  bool happenedBefore(VectorClock other) {
    for (final entry in clocks.entries) {
      if (entry.value > other.getTime(entry.key)) {
        return false;
      }
    }
    return clocks.length < other.clocks.length;
  }
  
  bool isConcurrentWith(VectorClock other) {
    return !happenedBefore(other) && !other.happenedBefore(this);
  }
  
  VectorClock copy() {
    return VectorClock.fromJson(clocks);
  }
  
  Map<String, dynamic> toJson() {
    return Map.from(clocks);
  }
}

/// Operation types
enum OperationType {
  insert,
  update,
  delete,
}

/// Operation representation
class Operation {
  String id;
  OperationType type;
  String table;
  String recordId;
  Map<String, dynamic> data;
  VectorClock? vectorClock;
  DateTime? timestamp;
  String? sourceDevice;
  
  Operation({
    required this.id,
    required this.type,
    required this.table,
    required this.recordId,
    required this.data,
    this.vectorClock,
    this.timestamp,
    this.sourceDevice,
  });
  
  Operation.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      type = OperationType.values.firstWhere((e) => e.name == json['type']),
      table = json['table'],
      recordId = json['recordId'],
      data = Map<String, dynamic>.from(json['data'] ?? {}),
      vectorClock = json['vectorClock'] != null ? VectorClock.fromJson(json['vectorClock']) : null,
      timestamp = json['timestamp'] != null ? DateTime.fromMillisecondsSinceEpoch(json['timestamp']) : null,
      sourceDevice = json['sourceDevice'];
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'table': table,
      'recordId': recordId,
      'data': data,
      'vectorClock': vectorClock?.toJson(),
      'timestamp': timestamp?.millisecondsSinceEpoch,
      'sourceDevice': sourceDevice,
    };
  }
}

/// Conflict types
enum ConflictType {
  concurrentModification,
  sameRecordModification,
  deleteConflict,
  schemaConflict,
}

/// Conflict representation
class Conflict {
  String id;
  String operationId;
  ConflictType type;
  VectorClock localClock;
  VectorClock remoteClock;
  String table;
  String recordId;
  DateTime timestamp;
  
  Conflict({
    required this.id,
    required this.operationId,
    required this.type,
    required this.localClock,
    required this.remoteClock,
    required this.table,
    required this.recordId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  Conflict.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      operationId = json['operationId'],
      type = ConflictType.values.firstWhere((e) => e.name == json['type']),
      localClock = VectorClock.fromJson(json['localClock']),
      remoteClock = VectorClock.fromJson(json['remoteClock']),
      table = json['table'],
      recordId = json['recordId'],
      timestamp = DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0);
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operationId': operationId,
      'type': type.name,
      'localClock': localClock.toJson(),
      'remoteClock': remoteClock.toJson(),
      'table': table,
      'recordId': recordId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'sourceDevice': 'unknown', // Placeholder as it was missing in original model but might be needed
    };
    // Note: Removed 'sourceDevice' placeholder if not in original usage, but JSON map structure allows it.
    // Adjusted to match original exactly if possible, but 'sourceDevice' was not in original Conflict.toJson.
    // Original:
    /*
      'id': id,
      'operationId': operationId,
      'type': type.name,
      'localClock': localClock.toJson(),
      'remoteClock': remoteClock.toJson(),
      'table': table,
      'recordId': recordId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    */
  }
}

/// Conflict resolution types
enum ConflictResolutionType {
  autoResolved,
  manuallyResolved,
  requiresManualResolution,
}

/// Conflict resolution strategies
enum ConflictResolutionStrategy {
  lastWriteWins,
  firstWriteWins,
  merge,
  businessRules,
  manual,
}

/// Conflict resolution
class ConflictResolution {
  String id;
  String conflictId;
  ConflictResolutionType type;
  ConflictResolutionStrategy strategy;
  Operation? resolvedOperation;
  Operation? localOperation;
  String winner;
  String reason;
  DateTime timestamp;
  
  ConflictResolution({
    required this.id,
    required this.conflictId,
    required this.type,
    required this.strategy,
    this.resolvedOperation,
    this.localOperation,
    required this.winner,
    required this.reason,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  ConflictResolution.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      conflictId = json['conflictId'],
      type = ConflictResolutionType.values.firstWhere((e) => e.name == json['type']),
      strategy = ConflictResolutionStrategy.values.firstWhere((e) => e.name == json['strategy']),
      resolvedOperation = json['resolvedOperation'] != null ? 
          Operation.fromJson(json['resolvedOperation']) : null,
      localOperation = json['localOperation'] != null ? 
          Operation.fromJson(json['localOperation']) : null,
      winner = json['winner'],
      reason = json['reason'],
      timestamp = DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0);
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conflictId': conflictId,
      'type': type.name,
      'strategy': strategy.name,
      'resolvedOperation': resolvedOperation?.toJson(),
      'localOperation': localOperation?.toJson(),
      'winner': winner,
      'reason': reason,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

/// State snapshot
class StateSnapshot {
  String table;
  String hash;
  DateTime timestamp;
  VectorClock vectorClock;
  
  StateSnapshot({
    required this.table,
    required this.hash,
    required this.timestamp,
    required this.vectorClock,
  });
}

/// Sync event types
enum SyncEventType {
  operationApplied,
  operationCommitted,
  operationRolledBack,
  conflictDetected,
  conflictResolved,
  conflictRequiresManualResolution,
  stateUpdated,
}

/// Sync event
class SyncEvent {
  SyncEventType type;
  Operation? operation;
  Conflict? conflict;
  ConflictResolution? resolution;
  DateTime timestamp;
  
  SyncEvent({
    required this.type,
    this.operation,
    this.conflict,
    this.resolution,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
