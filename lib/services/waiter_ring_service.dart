import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'event_service.dart';

/// A single waiter ring from a customer.
class WaiterRing {
  final String id;
  final String module;
  final String tableNumber;
  final String customerName;
  /// The buyer's persistent device/session ID — used to link the created order
  /// back to the buyer app for active-order tracking.
  final String clientId;
  final List<Map<String, dynamic>> items;
  final String note;
  final DateTime timestamp;
  bool acknowledged;

  WaiterRing({
    required this.id,
    required this.module,
    required this.tableNumber,
    required this.customerName,
    this.clientId = '',
    required this.items,
    required this.note,
    required this.timestamp,
    this.acknowledged = false,
  });

  double get total {
    double sum = 0;
    for (final item in items) {
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      final qty = (item['qty'] as num?)?.toInt() ?? 1;
      sum += price * qty;
    }
    return sum;
  }
}

/// Singleton service that manages incoming customer waiter rings.
///
/// The API server runs in a **background isolate**, so `addRing()` called there
/// is invisible to the UI isolate. This service bridges the gap by polling the
/// DB for new ORDER_PING events every 3 seconds.
class WaiterRingService {
  WaiterRingService._();
  static final WaiterRingService instance = WaiterRingService._();

  final List<WaiterRing> _rings = [];
  final Set<String> _knownIds = {};
  final Set<String> _acknowledgedIds = {};
  final _controller = StreamController<List<WaiterRing>>.broadcast();
  Timer? _pollTimer;

  /// Live stream of the current ring list.
  Stream<List<WaiterRing>> get ringsStream => _controller.stream;

  /// Current snapshot of rings.
  List<WaiterRing> get rings => List.unmodifiable(_rings);

  /// Count of unacknowledged rings.
  int get unacknowledgedCount =>
      _rings.where((r) => !r.acknowledged).length;

  /// Start polling the DB for ORDER_PING events.
  /// Call this once from the UI isolate on app startup.
  void startPolling() {
    // Load immediately
    loadFromDb();
    // Then poll every 3 seconds to pick up rings from background isolate
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      loadFromDb();
    });
    debugPrint('🔔 WaiterRingService: polling started (every 3s)');
  }

  /// Load ORDER_PING events from the DB.
  /// Merges with existing in-memory state, preserving acknowledgements.
  Future<void> loadFromDb() async {
    try {
      final events = await EventService.getEventsByType('ORDER_PING', limit: 50);
      bool changed = false;

      for (final event in events) {
        // Skip already known rings
        if (_knownIds.contains(event.id)) continue;

        final p = event.payload;
        // Only show rings from the last 8 hours
        final ts = DateTime.fromMillisecondsSinceEpoch(
          (p['timestamp'] as int?) ?? event.timestamp,
        );
        if (DateTime.now().difference(ts).inHours > 8) continue;

        final ring = WaiterRing(
          id: event.id,
          module: p['module'] as String? ?? 'restaurant',
          tableNumber: p['tableNumber'] as String? ?? '',
          customerName: p['customerName'] as String? ?? 'Customer',
          clientId: p['clientId'] as String? ?? '',
          items: _parseItems(p['items']),
          note: p['note'] as String? ?? '',
          timestamp: ts,
          acknowledged: _acknowledgedIds.contains(event.id),
        );

        _rings.insert(0, ring);
        _knownIds.add(event.id);
        changed = true;
      }

      if (changed) {
        // Sort by timestamp descending (newest first)
        _rings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _notify();
        debugPrint('🔔 WaiterRingService: loaded ${_rings.length} rings (${_knownIds.length} known)');
      }
    } catch (e) {
      debugPrint('⚠️ WaiterRingService.loadFromDb failed: $e');
    }
  }

  /// Add a new ring from an incoming ORDER_PING (foreground scenario).
  void addRing({
    required String eventId,
    required String module,
    required String tableNumber,
    required String customerName,
    String clientId = '',
    required List<dynamic> items,
    required String note,
    required int timestampMs,
  }) {
    if (_knownIds.contains(eventId)) return; // deduplicate

    final ring = WaiterRing(
      id: eventId,
      module: module,
      tableNumber: tableNumber,
      customerName: customerName,
      clientId: clientId,
      items: items.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      note: note,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
    );
    _rings.insert(0, ring);
    _knownIds.add(eventId);
    _notify();
    debugPrint('🔔 New waiter ring: Table $tableNumber ($customerName) clientId=$clientId');
  }

  /// Mark a ring as acknowledged.
  void acknowledgeRing(String ringId) {
    final idx = _rings.indexWhere((r) => r.id == ringId);
    if (idx >= 0) {
      _rings[idx].acknowledged = true;
      _acknowledgedIds.add(ringId);
      _notify();
    }
  }

  /// Dismiss / remove a ring.
  void dismissRing(String ringId) {
    _rings.removeWhere((r) => r.id == ringId);
    _acknowledgedIds.add(ringId); // prevent re-appearing on next poll
    _notify();
  }

  /// Acknowledge all rings at once.
  void acknowledgeAll() {
    for (final ring in _rings) {
      ring.acknowledged = true;
      _acknowledgedIds.add(ring.id);
    }
    _notify();
  }

  /// Clear all rings (free up space).
  void clearAll() {
    for (final ring in _rings) {
      _acknowledgedIds.add(ring.id); // prevent re-appearing on next poll
    }
    _rings.clear();
    _notify();
  }

  /// Update items for a ring (Change flow).
  void updateRingItems(String ringId, List<Map<String, dynamic>> newItems) {
    final idx = _rings.indexWhere((r) => r.id == ringId);
    if (idx >= 0) {
      // Replace the items list in-place (items is final but List is mutable)
      _rings[idx].items.clear();
      _rings[idx].items.addAll(newItems);
      _notify();
    }
  }

  void _notify() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_rings));
    }
  }

  List<Map<String, dynamic>> _parseItems(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  void dispose() {
    _pollTimer?.cancel();
    _controller.close();
  }
}
