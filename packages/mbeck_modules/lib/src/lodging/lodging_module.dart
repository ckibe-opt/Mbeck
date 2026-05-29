import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/module_base.dart';
import '../core/module_feature.dart';
import '../core/module_types.dart';
import '../core/route_definition.dart';

/// Lodging module for accommodation businesses.
///
/// Designed for:
/// - Hotels & guesthouses
/// - Airbnb / short-stay rentals
/// - Hostels & dormitories
/// - Lodges & camps
///
/// Features:
/// - Room registry (types, pricing, capacity, amenities)
/// - Reservation lifecycle (pending → confirmed → checked_in → checked_out)
/// - Check-in / check-out dashboard
/// - Nightly billing with extras
/// - Room status board (available / occupied / cleaning / maintenance)
class LodgingModule extends MbeckModule {
  @override
  ModuleType get type => ModuleType.lodging;

  @override
  String get id => 'lodging';

  @override
  String get displayName => 'Lodging & Accommodation';

  @override
  IconData get icon => Icons.hotel;

  @override
  String get description =>
      'Manage rooms, reservations, check-ins and billing for hotels, guesthouses and short-stay rentals';

  @override
  String get version => '1.0.0';

  // ========== Features ==========

  @override
  List<ModuleFeature> get features => const [
    ModuleFeature(
      id: 'room_registry',
      name: 'Room Registry',
      description: 'Define rooms with types, pricing, capacity and amenities',
      defaultEnabled: true,
      iconName: 'meeting_room',
    ),
    ModuleFeature(
      id: 'reservations',
      name: 'Reservations',
      description: 'Accept and manage guest reservations with date ranges',
      defaultEnabled: true,
      iconName: 'event_note',
    ),
    ModuleFeature(
      id: 'check_in_out',
      name: 'Check-in / Check-out',
      description: 'Live dashboard showing occupied and available rooms',
      defaultEnabled: true,
      iconName: 'login',
    ),
    ModuleFeature(
      id: 'housekeeping',
      name: 'Housekeeping Status',
      description: 'Track room cleaning status after check-out',
      defaultEnabled: true,
      iconName: 'cleaning_services',
    ),
    ModuleFeature(
      id: 'extras_billing',
      name: 'Extras & Add-ons',
      description: 'Add extra charges (minibar, laundry, room service)',
      defaultEnabled: false,
      iconName: 'add_shopping_cart',
    ),
    ModuleFeature(
      id: 'guest_history',
      name: 'Guest History',
      description: 'View past stays and spending per guest',
      defaultEnabled: true,
      iconName: 'history',
    ),
  ];

  // ========== API Routes ==========

  @override
  List<RouteDefinition> get apiRoutes => [
    RouteDefinition(
      method: 'GET',
      path: '/api/v1/lodging/rooms',
      description: 'Get available rooms',
      handler: _roomsHandler,
    ),
    RouteDefinition(
      method: 'GET',
      path: '/api/v1/lodging/reservations',
      description: 'Get reservations',
      handler: _reservationsHandler,
    ),
    // Subsystem A: Folio Management
    RouteDefinition(
      method: 'POST',
      path: '/api/v1/lodging/reservations/<id>/folio',
      description: 'Create a split folio for a reservation',
      handler: _createFolioHandler,
    ),
    // Subsystem B: Group Blocking
    RouteDefinition(
      method: 'POST',
      path: '/api/v1/lodging/groups',
      description: 'Create a room block allocation',
      handler: _createGroupHandler,
    ),
    // Subsystem C: Rate Plans
    RouteDefinition(
      method: 'GET',
      path: '/api/v1/lodging/rates',
      description: 'Get active rate plans',
      handler: _ratesHandler,
    ),
    // Subsystem D: Channel Manager Hooks
    RouteDefinition(
      method: 'POST',
      path: '/api/v1/lodging/channel/sync',
      description: 'Broadcast availability state to channel manager',
      handler: _channelSyncHandler,
    ),
  ];

  static dynamic _getDb(Request request) {
    return request.context['db'];
  }

  static Future<Response> _roomsHandler(Request request) async {
    return Response.ok(
      '{"rooms": [], "message": "Lodging rooms endpoint"}',
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<Response> _reservationsHandler(Request request) async {
    return Response.ok(
      '{"reservations": [], "message": "Lodging reservations endpoint"}',
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<Response> _createFolioHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');

      final reservationIdStr = request.params['id'];
      if (reservationIdStr == null) return Response(400, body: '{"error": "Missing reservation ID"}');
      final reservationId = int.tryParse(reservationIdStr);

      final payload = jsonDecode(await request.readAsString());
      if (payload['name'] == null) {
        return Response(400, body: '{"error": "Folio name is required"}');
      }

      final folioId = await db.insert('lodging_folios', {
        'reservation_id': reservationId,
        'name': payload['name'],
        'billing_address': payload['billing_address'],
        'subtotal': payload['subtotal'] ?? 0.0,
        'is_master': payload['is_master'] == true ? 1 : 0,
      });

      return Response.ok(jsonEncode({'success': true, 'folio_id': folioId}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _createGroupHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');

      final payload = jsonDecode(await request.readAsString());
      if (payload['name'] == null || payload['total_rooms_allocated'] == null || payload['cutoff_date'] == null) {
        return Response(400, body: '{"error": "name, total_rooms_allocated, and cutoff_date are required"}');
      }

      final groupId = await db.insert('lodging_groups', {
        'name': payload['name'],
        'contract_name': payload['contract_name'],
        'total_rooms_allocated': payload['total_rooms_allocated'],
        'rooms_picked_up': 0,
        'cutoff_date': payload['cutoff_date'],
        'master_folio_id': payload['master_folio_id'],
      });

      return Response.ok(jsonEncode({'success': true, 'group_id': groupId}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _ratesHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');

      final rates = await db.query('lodging_rate_plans');
      return Response.ok(jsonEncode({'rates': rates}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _channelSyncHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');

      final payload = jsonDecode(await request.readAsString());
      if (payload['room_id'] == null || payload['event_type'] == null) {
        return Response(400, body: '{"error": "room_id and event_type are required"}');
      }

      final logId = await db.insert('lodging_channel_logs', {
        'room_id': payload['room_id'],
        'event_type': payload['event_type'],
        'payload': jsonEncode(payload['data'] ?? {}),
        'synced_at': DateTime.now().millisecondsSinceEpoch,
        'status': 'pending', // Would be updated by background worker
      });

      return Response.ok(jsonEncode({'success': true, 'log_id': logId, 'message': 'State queued for sync'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // ========== Screens ==========

  @override
  List<ModuleScreen> get providerScreens => [
    ModuleScreen(
      route: '/lodging/rooms',
      builder: (_) => const _PlaceholderScreen(title: 'Rooms'),
      icon: Icons.meeting_room,
      label: 'Rooms',
      isDefault: true,
    ),
    ModuleScreen(
      route: '/lodging/reservations',
      builder: (_) => const _PlaceholderScreen(title: 'Reservations'),
      icon: Icons.event_note,
      label: 'Reservations',
    ),
  ];

  @override
  List<ModuleScreen> get customerScreens => [
    ModuleScreen(
      route: '/lodging/browse',
      builder: (_) => const _PlaceholderScreen(title: 'Browse Lodging'),
      icon: Icons.hotel,
      label: 'Stays',
    ),
  ];

  // ========== Migrations ==========

  @override
  List<String> get migrationSQL => [
    '''
    CREATE TABLE IF NOT EXISTS lodging_rooms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cloud_id TEXT,
      name TEXT NOT NULL,
      room_type TEXT NOT NULL DEFAULT 'standard',
      floor TEXT,
      capacity INTEGER NOT NULL DEFAULT 2,
      rate_per_night REAL NOT NULL DEFAULT 0,
      amenities TEXT,
      description TEXT,
      image_path TEXT,
      status TEXT NOT NULL DEFAULT 'available',
      is_active INTEGER NOT NULL DEFAULT 1,
      sort_order INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS lodging_reservations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cloud_id TEXT,
      room_id INTEGER NOT NULL,
      guest_name TEXT NOT NULL,
      guest_phone TEXT,
      guest_email TEXT,
      guest_id_number TEXT,
      check_in_date INTEGER NOT NULL,
      check_out_date INTEGER NOT NULL,
      actual_check_in INTEGER,
      actual_check_out INTEGER,
      nights INTEGER NOT NULL DEFAULT 1,
      rate_per_night REAL NOT NULL DEFAULT 0,
      extras_total REAL NOT NULL DEFAULT 0,
      total_amount REAL NOT NULL DEFAULT 0,
      amount_paid REAL NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'pending',
      notes TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
      FOREIGN KEY (room_id) REFERENCES lodging_rooms (id) ON DELETE CASCADE
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_lodging_rooms_type ON lodging_rooms(room_type);',
    'CREATE INDEX IF NOT EXISTS idx_lodging_rooms_status ON lodging_rooms(status);',
    'CREATE INDEX IF NOT EXISTS idx_lodging_rooms_active ON lodging_rooms(is_active);',
    'CREATE INDEX IF NOT EXISTS idx_lodging_res_room ON lodging_reservations(room_id);',
    'CREATE INDEX IF NOT EXISTS idx_lodging_res_status ON lodging_reservations(status);',
    'CREATE INDEX IF NOT EXISTS idx_lodging_res_checkin ON lodging_reservations(check_in_date);',
    'CREATE INDEX IF NOT EXISTS idx_lodging_res_checkout ON lodging_reservations(check_out_date);',

    // Subsystem A: Folios
    '''
    CREATE TABLE IF NOT EXISTS lodging_folios (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      reservation_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      billing_address TEXT,
      subtotal REAL NOT NULL DEFAULT 0,
      is_master INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (reservation_id) REFERENCES lodging_reservations(id) ON DELETE CASCADE
    );
    ''',

    // Subsystem B: Groups
    '''
    CREATE TABLE IF NOT EXISTS lodging_groups (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      contract_name TEXT,
      total_rooms_allocated INTEGER NOT NULL,
      rooms_picked_up INTEGER NOT NULL DEFAULT 0,
      cutoff_date INTEGER NOT NULL,
      master_folio_id INTEGER
    );
    ''',

    // Subsystem C: Rates
    '''
    CREATE TABLE IF NOT EXISTS lodging_rate_plans (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      base_rate REAL NOT NULL,
      includes_breakfast INTEGER DEFAULT 0,
      is_refundable INTEGER DEFAULT 1,
      start_date INTEGER,
      end_date INTEGER
    );
    ''',

    // Subsystem D: Channel Manager Log
    '''
    CREATE TABLE IF NOT EXISTS lodging_channel_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_id INTEGER NOT NULL,
      event_type TEXT NOT NULL,
      payload TEXT NOT NULL,
      synced_at INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending'
    );
    ''',
  ];

  @override
  Future<void> onActivate(dynamic db, String shopId) async {
    for (final sql in migrationSQL) {
      try {
        await db.execute(sql);
      } catch (e) {
        debugPrint('⚠️ Lodging migration: $e');
      }
    }
    debugPrint('🏨 LodgingModule activated for shop $shopId');
  }

  @override
  Future<void> onDeactivate(dynamic db, String shopId) async {
    debugPrint('🏨 LodgingModule deactivated for shop $shopId');
  }

  @override
  Map<String, dynamic> getDefaultConfig() => {
    'features': {
      'room_registry': true,
      'reservations': true,
      'check_in_out': true,
      'housekeeping': true,
      'extras_billing': false,
      'guest_history': true,
    },
    'ui': {
      'layout': 'grid',
      'showOccupancyRate': true,
    },
    'billing': {
      'checkInTime': '14:00',
      'checkOutTime': '11:00',
      'lateFeePerHour': 0,
    },
  };

  @override
  String? validateConfig(Map<String, dynamic> config) {
    if (config['features'] == null) {
      return 'Missing features configuration';
    }
    return null;
  }
}

/// Placeholder screen used during module registration
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title - Coming Soon')),
    );
  }
}
