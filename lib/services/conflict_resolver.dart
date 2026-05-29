import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'device_service.dart';
import '../db/db_provider.dart';
import '../models/sync_models.dart';

/// Conflict Resolver - Automatic and manual conflict resolution strategies
/// 
/// Provides intelligent conflict resolution for concurrent data modifications
/// using various strategies based on data type, business rules, and timing.
/// 
/// Features:
/// - Automatic resolution strategies (last-write-wins, merge, etc.)
/// - Business rule-based resolution
/// - User notification for unresolvable conflicts
/// - Audit trail for all resolutions
/// - Configurable resolution policies per table
class ConflictResolver {
  // Resolution strategies per table
  final Map<String, ConflictResolutionStrategy> _tableStrategies = {};
  
  // Conflict history for audit
  final List<ConflictResolution> _resolutionHistory = [];
  
  // Manual resolution queue
  final List<Conflict> _manualResolutionQueue = [];
  
  ConflictResolver() {
    _initializeDefaultStrategies();
  }
  
  /// Resolve conflict between operations
  Future<ConflictResolution> resolveConflict(Conflict conflict, Operation localOperation) async {
    debugPrint('🔧 Resolving conflict: ${conflict.type} on ${conflict.table}');
    
    // Get strategy for table
    final strategy = _tableStrategies[conflict.table] ?? 
                    ConflictResolutionStrategy.lastWriteWins;
    
    ConflictResolution resolution;
    
    switch (strategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        resolution = await _resolveLastWriteWins(conflict, localOperation);
        break;
      case ConflictResolutionStrategy.firstWriteWins:
        resolution = await _resolveFirstWriteWins(conflict, localOperation);
        break;
      case ConflictResolutionStrategy.merge:
        resolution = await _resolveMerge(conflict, localOperation);
        break;
      case ConflictResolutionStrategy.businessRules:
        resolution = await _resolveBusinessRules(conflict, localOperation);
        break;
      case ConflictResolutionStrategy.manual:
        resolution = await _requireManualResolution(conflict, localOperation);
        break;
    }
    
    // Record resolution
    _recordResolution(resolution);
    
    return resolution;
  }
  
  /// Initialize default resolution strategies
  void _initializeDefaultStrategies() {
    // Inventory: last-write-wins (most recent stock count)
    _tableStrategies['inventory'] = ConflictResolutionStrategy.lastWriteWins;
    
    // Transactions: merge (combine if possible, otherwise manual)
    _tableStrategies['txn'] = ConflictResolutionStrategy.merge;
    
    // Customer data: merge (preserve latest info)
    _tableStrategies['customer'] = ConflictResolutionStrategy.merge;
    
    // Settings: business rules (based on field type)
    _tableStrategies['shop_settings'] = ConflictResolutionStrategy.businessRules;
    
    // Menu items: merge (combine updates)
    _tableStrategies['restaurant_menu'] = ConflictResolutionStrategy.merge;
    
    // Services: merge (combine availability updates)
    _tableStrategies['services_catalog'] = ConflictResolutionStrategy.merge;
    
    // Accounting: manual (requires human review)
    _tableStrategies['accounting'] = ConflictResolutionStrategy.manual;
  }
  
  /// Last-write-wins resolution
  Future<ConflictResolution> _resolveLastWriteWins(Conflict conflict, Operation localOperation) async {
    // Compare timestamps
    final remoteTime = conflict.remoteClock.getTime(conflict.remoteClock.clocks.keys.first) ?? 0;
    final localTime = localOperation.timestamp?.millisecondsSinceEpoch ?? 0;
    
    Operation resolvedOperation;
    String winner;
    
    if (remoteTime > localTime) {
      // Remote operation wins - we need the remote operation data
      resolvedOperation = _createRemoteOperation(conflict);
      winner = 'remote';
    } else {
      // Local operation wins
      resolvedOperation = localOperation;
      winner = 'local';
    }
    
    debugPrint('🔧 Last-write-wins: $winner operation selected');
    
    return ConflictResolution(
      id: _generateResolutionId(),
      conflictId: conflict.id,
      type: ConflictResolutionType.autoResolved,
      strategy: ConflictResolutionStrategy.lastWriteWins,
      resolvedOperation: resolvedOperation,
      winner: winner,
      reason: 'Last write wins based on timestamp',
    );
  }
  
  /// First-write-wins resolution
  Future<ConflictResolution> _resolveFirstWriteWins(Conflict conflict, Operation localOperation) async {
    // Compare vector clocks to see which happened first
    final remoteHappenedFirst = conflict.localClock.happenedBefore(conflict.remoteClock);
    
    Operation resolvedOperation;
    String winner;
    
    if (remoteHappenedFirst) {
      // Remote operation happened first
      resolvedOperation = _createRemoteOperation(conflict);
      winner = 'remote';
    } else {
      // Local operation happened first or concurrent
      resolvedOperation = localOperation;
      winner = 'local';
    }
    
    debugPrint('🔧 First-write-wins: $winner operation selected');
    
    return ConflictResolution(
      id: _generateResolutionId(),
      conflictId: conflict.id,
      type: ConflictResolutionType.autoResolved,
      strategy: ConflictResolutionStrategy.firstWriteWins,
      resolvedOperation: resolvedOperation,
      winner: winner,
      reason: 'First write wins based on vector clock',
    );
  }
  
  /// Merge resolution
  Future<ConflictResolution> _resolveMerge(Conflict conflict, Operation localOperation) async {
    // Try to merge the operations
    final mergedOperation = await _mergeOperations(conflict, localOperation);
    
    if (mergedOperation != null) {
      debugPrint('🔧 Operations merged successfully');
      
      return ConflictResolution(
        id: _generateResolutionId(),
        conflictId: conflict.id,
        type: ConflictResolutionType.autoResolved,
        strategy: ConflictResolutionStrategy.merge,
        resolvedOperation: mergedOperation,
        winner: 'merged',
        reason: 'Operations merged successfully',
      );
    } else {
      // Cannot merge - require manual resolution
      return _requireManualResolution(conflict, localOperation);
    }
  }
  
  /// Business rules resolution
  Future<ConflictResolution> _resolveBusinessRules(Conflict conflict, Operation localOperation) async {
    // Apply business-specific rules
    final resolvedOperation = await _applyBusinessRules(conflict, localOperation);
    
    if (resolvedOperation != null) {
      debugPrint('🔧 Business rules applied successfully');
      
      return ConflictResolution(
        id: _generateResolutionId(),
        conflictId: conflict.id,
        type: ConflictResolutionType.autoResolved,
        strategy: ConflictResolutionStrategy.businessRules,
        resolvedOperation: resolvedOperation,
        winner: 'business_rules',
        reason: 'Business rules applied',
      );
    } else {
      // Cannot resolve with business rules
      return _requireManualResolution(conflict, localOperation);
    }
  }
  
  /// Require manual resolution
  Future<ConflictResolution> _requireManualResolution(Conflict conflict, Operation localOperation) async {
    debugPrint('🔧 Conflict requires manual resolution');
    
    // Add to manual resolution queue
    _manualResolutionQueue.add(conflict);
    
    return ConflictResolution(
      id: _generateResolutionId(),
      conflictId: conflict.id,
      type: ConflictResolutionType.requiresManualResolution,
      strategy: ConflictResolutionStrategy.manual,
      localOperation: localOperation,
      winner: 'pending',
      reason: 'Conflict requires manual resolution',
    );
  }
  
  /// Merge two operations
  Future<Operation?> _mergeOperations(Conflict conflict, Operation localOperation) async {
    try {
      switch (conflict.table) {
        case 'inventory':
          return await _mergeInventoryOperations(conflict, localOperation);
        case 'transactions':
          return await _mergeTransactionOperations(conflict, localOperation);
        case 'customer':
          return await _mergeCustomerOperations(conflict, localOperation);
        case 'restaurant_menu':
          return await _mergeMenuOperations(conflict, localOperation);
        case 'services_catalog':
          return await _mergeServiceOperations(conflict, localOperation);
        default:
          return null; // Cannot merge unknown table types
      }
    } catch (e) {
      debugPrint('❌ Failed to merge operations: $e');
      return null;
    }
  }
  
  /// Merge inventory operations
  Future<Operation?> _mergeInventoryOperations(Conflict conflict, Operation localOperation) async {
    // For inventory, we can merge stock counts and update timestamps
    final remoteOp = _createRemoteOperation(conflict);
    
    if (localOperation.type == OperationType.update && 
        remoteOp.type == OperationType.update) {
      
      final mergedData = Map<String, dynamic>.from(localOperation.data);
      
      // Merge stock count (use the most recent)
      final localStock = localOperation.data['stock'] as int? ?? 0;
      final remoteStock = remoteOp.data['stock'] as int? ?? 0;
      
      // For stock, we typically want the most recent (which should be the higher value if sales occurred)
      mergedData['stock'] = remoteStock > localStock ? remoteStock : localStock;
      
      // Merge other fields intelligently
      mergedData['updated_at'] = DateTime.now().toIso8601String();
      mergedData['last_sync_device'] = await DeviceService.getDeviceId();
      
      // Keep the most recent price
      final localPrice = localOperation.data['price'] as double? ?? 0.0;
      final remotePrice = remoteOp.data['price'] as double? ?? 0.0;
      if (remotePrice > 0 && remotePrice != localPrice) {
        mergedData['price'] = remotePrice;
      }
      
      return Operation(
        id: _generateOperationId(),
        type: OperationType.update,
        table: 'inventory',
        recordId: localOperation.recordId,
        data: mergedData,
        timestamp: DateTime.now(),
        sourceDevice: await DeviceService.getDeviceId(),
      );
    }
    
    return null;
  }
  
  /// Merge transaction operations
  Future<Operation?> _mergeTransactionOperations(Conflict conflict, Operation localOperation) async {
    // Transactions are generally immutable - if there's a conflict, 
    // we need to verify which one is valid
    final remoteOp = _createRemoteOperation(conflict);
    
    // Check if transactions are duplicates (same amount, same time)
    final localAmount = localOperation.data['total_amount'] as double? ?? 0.0;
    final remoteAmount = remoteOp.data['total_amount'] as double? ?? 0.0;
    
    if (localAmount == remoteAmount) {
      // Likely duplicate - keep the local one
      return localOperation;
    }
    
    // Different amounts - this needs manual review
    return null;
  }
  
  /// Merge customer operations
  Future<Operation?> _mergeCustomerOperations(Conflict conflict, Operation localOperation) async {
    final remoteOp = _createRemoteOperation(conflict);
    
    if (localOperation.type == OperationType.update && 
        remoteOp.type == OperationType.update) {
      
      final mergedData = Map<String, dynamic>.from(localOperation.data);
      
      // Merge customer data - keep most recent non-null values
      final fields = ['name', 'phone', 'email', 'address'];
      
      for (final field in fields) {
        final localValue = localOperation.data[field];
        final remoteValue = remoteOp.data[field];
        
        if (remoteValue != null && remoteValue.toString().isNotEmpty) {
          mergedData[field] = remoteValue;
        }
      }
      
      mergedData['updated_at'] = DateTime.now().toIso8601String();
      mergedData['last_sync_device'] = await DeviceService.getDeviceId();
      
      return Operation(
        id: _generateOperationId(),
        type: OperationType.update,
        table: 'customer',
        recordId: localOperation.recordId,
        data: mergedData,
        timestamp: DateTime.now(),
        sourceDevice: await DeviceService.getDeviceId(),
      );
    }
    
    return null;
  }
  
  /// Merge menu operations
  Future<Operation?> _mergeMenuOperations(Conflict conflict, Operation localOperation) async {
    final remoteOp = _createRemoteOperation(conflict);
    
    if (localOperation.type == OperationType.update && 
        remoteOp.type == OperationType.update) {
      
      final mergedData = Map<String, dynamic>.from(localOperation.data);
      
      // Merge menu item data
      final localPrice = localOperation.data['price'] as double? ?? 0.0;
      final remotePrice = remoteOp.data['price'] as double? ?? 0.0;
      
      // Use the most recent price (non-zero)
      if (remotePrice > 0) {
        mergedData['price'] = remotePrice;
      }
      
      // Merge availability
      final localAvailable = localOperation.data['available'] as bool? ?? true;
      final remoteAvailable = remoteOp.data['available'] as bool? ?? true;
      mergedData['available'] = remoteAvailable; // Most recent availability
      
      // Merge other fields
      mergedData['updated_at'] = DateTime.now().toIso8601String();
      mergedData['last_sync_device'] = await DeviceService.getDeviceId();
      
      return Operation(
        id: _generateOperationId(),
        type: OperationType.update,
        table: 'restaurant_menu',
        recordId: localOperation.recordId,
        data: mergedData,
        timestamp: DateTime.now(),
        sourceDevice: await DeviceService.getDeviceId(),
      );
    }
    
    return null;
  }
  
  /// Merge service operations
  Future<Operation?> _mergeServiceOperations(Conflict conflict, Operation localOperation) async {
    final remoteOp = _createRemoteOperation(conflict);
    
    if (localOperation.type == OperationType.update && 
        remoteOp.type == OperationType.update) {
      
      final mergedData = Map<String, dynamic>.from(localOperation.data);
      
      // Merge service data
      final localPrice = localOperation.data['price'] as double? ?? 0.0;
      final remotePrice = remoteOp.data['price'] as double? ?? 0.0;
      
      if (remotePrice > 0) {
        mergedData['price'] = remotePrice;
      }
      
      // Merge availability
      final localAvailable = localOperation.data['available'] as bool? ?? true;
      final remoteAvailable = remoteOp.data['available'] as bool? ?? true;
      mergedData['available'] = remoteAvailable;
      
      mergedData['updated_at'] = DateTime.now().toIso8601String();
      mergedData['last_sync_device'] = await DeviceService.getDeviceId();
      
      return Operation(
        id: _generateOperationId(),
        type: OperationType.update,
        table: 'services_catalog',
        recordId: localOperation.recordId,
        data: mergedData,
        timestamp: DateTime.now(),
        sourceDevice: await DeviceService.getDeviceId(),
      );
    }
    
    return null;
  }
  
  /// Apply business rules
  Future<Operation?> _applyBusinessRules(Conflict conflict, Operation localOperation) async {
    switch (conflict.table) {
      case 'shop_settings':
        return await _applyShopSettingsRules(conflict, localOperation);
      default:
        return null;
    }
  }
  
  /// Apply shop settings business rules
  Future<Operation?> _applyShopSettingsRules(Conflict conflict, Operation localOperation) async {
    final remoteOp = _createRemoteOperation(conflict);
    
    if (localOperation.type == OperationType.update && 
        remoteOp.type == OperationType.update) {
      
      final mergedData = Map<String, dynamic>.from(localOperation.data);
      
      // Business rules for shop settings
      final localBusinessName = localOperation.data['business_name'] as String?;
      final remoteBusinessName = remoteOp.data['business_name'] as String?;
      
      // Business name: if one is empty, use the other
      if (remoteBusinessName != null && remoteBusinessName.isNotEmpty) {
        mergedData['business_name'] = remoteBusinessName;
      }
      
      // Currency: don't change once set
      final localCurrency = localOperation.data['currency'] as String?;
      if (localCurrency != null && localCurrency.isNotEmpty) {
        mergedData['currency'] = localCurrency; // Keep local currency
      }
      
      // Tax rates: use the most recent
      final localTaxRate = localOperation.data['tax_rate'] as double?;
      final remoteTaxRate = remoteOp.data['tax_rate'] as double?;
      if (remoteTaxRate != null && remoteTaxRate >= 0) {
        mergedData['tax_rate'] = remoteTaxRate;
      }
      
      mergedData['updated_at'] = DateTime.now().toIso8601String();
      mergedData['last_sync_device'] = await DeviceService.getDeviceId();
      
      return Operation(
        id: _generateOperationId(),
        type: OperationType.update,
        table: 'shop_settings',
        recordId: localOperation.recordId,
        data: mergedData,
        timestamp: DateTime.now(),
        sourceDevice: await DeviceService.getDeviceId(),
      );
    }
    
    return null;
  }
  
  /// Create remote operation from conflict
  Operation _createRemoteOperation(Conflict conflict) {
    // This would typically fetch the actual remote operation data
    // For now, create a placeholder
    return Operation(
      id: 'remote_${conflict.id}',
      type: OperationType.update, // Default to update
      table: conflict.table,
      recordId: conflict.recordId,
      data: {}, // Would contain actual remote data
      timestamp: DateTime.now(),
      sourceDevice: 'remote',
    );
  }
  
  /// Record resolution for audit
  void _recordResolution(ConflictResolution resolution) {
    _resolutionHistory.add(resolution);
    
    // Limit history size
    if (_resolutionHistory.length > 1000) {
      _resolutionHistory.removeRange(0, _resolutionHistory.length - 1000);
    }
    
    debugPrint('🔧 Conflict resolution recorded: ${resolution.type}');
  }
  
  /// Get manual resolution queue
  List<Conflict> get manualResolutionQueue => List.unmodifiable(_manualResolutionQueue);
  
  /// Resolve conflict manually
  Future<void> resolveManually(String conflictId, Operation resolvedOperation) async {
    final conflict = _manualResolutionQueue.firstWhere((c) => c.id == conflictId);
    _manualResolutionQueue.remove(conflict);
    
    final resolution = ConflictResolution(
      id: _generateResolutionId(),
      conflictId: conflictId,
      type: ConflictResolutionType.manuallyResolved,
      strategy: ConflictResolutionStrategy.manual,
      resolvedOperation: resolvedOperation,
      winner: 'manual',
      reason: 'Manually resolved by user',
    );
    
    _recordResolution(resolution);
    
    debugPrint('🔧 Conflict manually resolved: $conflictId');
  }
  
  /// Set resolution strategy for table
  void setTableStrategy(String table, ConflictResolutionStrategy strategy) {
    _tableStrategies[table] = strategy;
    debugPrint('🔧 Set resolution strategy for $table: $strategy');
  }
  
  /// Get resolution strategy for table
  ConflictResolutionStrategy? getTableStrategy(String table) {
    return _tableStrategies[table];
  }
  
  /// Get resolution history
  List<ConflictResolution> getResolutionHistory() {
    return List.unmodifiable(_resolutionHistory);
  }
  
  /// Get resolution statistics
  Map<String, dynamic> getStats() {
    final autoResolved = _resolutionHistory.where((r) => 
        r.type == ConflictResolutionType.autoResolved).length;
    final manualResolved = _resolutionHistory.where((r) => 
        r.type == ConflictResolutionType.manuallyResolved).length;
    final pendingManual = _manualResolutionQueue.length;
    
    return {
      'totalResolutions': _resolutionHistory.length,
      'autoResolved': autoResolved,
      'manualResolved': manualResolved,
      'pendingManual': pendingManual,
      'tableStrategies': _tableStrategies.map((k, v) => MapEntry(k, v.name)),
    };
  }
  
  /// Generate resolution ID
  String _generateResolutionId() {
    return 'res_${DateTime.now().millisecondsSinceEpoch}_${_resolutionHistory.length}';
  }
  
  /// Generate operation ID
  String _generateOperationId() {
    return 'op_${DateTime.now().millisecondsSinceEpoch}';
  }
}