import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/module_base.dart';
import '../core/module_types.dart';
import '../core/module_feature.dart';
import '../core/route_definition.dart';

/// Services module for appointment-based businesses.
/// 
/// Designed for:
/// - Salons and spas
/// - Consultants and professionals
/// - Repair shops
/// - Any time-based service business
/// 
/// Features:
/// - Service catalog with pricing and duration
/// - Staff/provider management
/// - Online booking with availability slots
/// - Calendar view for appointments
class ServicesModule extends MbeckModule {
  @override
  ModuleType get type => ModuleType.services;

  @override
  String get id => 'services';

  @override
  String get displayName => 'Services & Bookings';

  @override
  IconData get icon => Icons.calendar_month;

  @override
  String get description => 
    'Service catalog, appointment booking, and calendar for service-based businesses';

  @override
  String get version => '1.0.0';

  // ========== Features ==========
  
  @override
  List<ModuleFeature> get features => const [
    ModuleFeature(
      id: 'service_catalog',
      name: 'Service Catalog',
      description: 'Define services with pricing and duration',
      defaultEnabled: true,
      iconName: 'list_alt',
    ),
    ModuleFeature(
      id: 'staff_management',
      name: 'Staff Management',
      description: 'Manage staff members and their availability',
      defaultEnabled: true,
      iconName: 'people',
    ),
    ModuleFeature(
      id: 'online_booking',
      name: 'Online Booking',
      description: 'Allow customers to book appointments online',
      defaultEnabled: true,
      iconName: 'event_available',
    ),
    ModuleFeature(
      id: 'calendar_view',
      name: 'Calendar View',
      description: 'Visual calendar for managing appointments',
      defaultEnabled: true,
      iconName: 'calendar_today',
    ),
    ModuleFeature(
      id: 'reminders',
      name: 'Appointment Reminders',
      description: 'Send SMS/push notifications before appointments',
      defaultEnabled: false,
      iconName: 'notifications',
    ),
    ModuleFeature(
      id: 'deposits',
      name: 'Booking Deposits',
      description: 'Require deposit payment for bookings',
      defaultEnabled: false,
      iconName: 'payments',
    ),
  ];

  // ========== API Routes ==========
  
  @override
  List<RouteDefinition> get apiRoutes => [
    // Service catalog
    RouteDefinition(
      method: 'GET',
      path: '/api/v1/services/catalog',
      description: 'Get service catalog for customers',
      handler: _catalogHandler,
    ),
    RouteDefinition(
      method: 'GET',
      path: '/api/v1/services/availability',
      description: 'Get available time slots for a service',
      handler: _availabilityHandler,
    ),
    RouteDefinition(
      method: 'POST',
      path: '/api/v1/services/book',
      description: 'Create a new booking',
      handler: _bookHandler,
    ),
    // Provider endpoints
    RouteDefinition(
      method: 'GET',
      path: '/api/v1/services/bookings',
      description: 'Get bookings (provider)',
      handler: _bookingsHandler,
    ),
    RouteDefinition(
      method: 'PUT',
      path: '/api/v1/services/bookings/<id>',
      description: 'Update booking status',
      handler: _updateBookingHandler,
    ),
    // Subsystem A: Multi-Resource Constraints (Rooms/Assets)
    RouteDefinition(
      method: 'POST',
      path: '/api/v1/services/rooms',
      description: 'Create a new service room',
      handler: _createRoomHandler,
    ),
    // Subsystem C: Service Add-ons
    RouteDefinition(
      method: 'POST',
      path: '/api/v1/services/bookings/<id>/addons',
      description: 'Append an add-on to a booking and extend its time',
      handler: _addAddonHandler,
    ),
    // Subsystem D: Recurring Appointments
    RouteDefinition(
      method: 'POST',
      path: '/api/v1/services/bookings/recurring',
      description: 'Generate bulk recurring appointments based on RRULE',
      handler: _createRecurringBookingsHandler,
    ),
  ];

  static dynamic _getDb(Request request) {
    return request.context['db'];
  }

  // Placeholder handlers
  static Future<Response> _catalogHandler(Request request) async {
    return Response.ok('{"catalog": []}', headers: {'Content-Type': 'application/json'});
  }

  static Future<Response> _availabilityHandler(Request request) async {
    return Response.ok('{"slots": []}', headers: {'Content-Type': 'application/json'});
  }

  static Future<Response> _bookHandler(Request request) async {
    return Response(501, body: 'Booking not implemented');
  }

  static Future<Response> _bookingsHandler(Request request) async {
    return Response.ok('{"bookings": []}', headers: {'Content-Type': 'application/json'});
  }

  static Future<Response> _updateBookingHandler(Request request) async {
    return Response(501, body: 'Update not implemented');
  }

  static Future<Response> _createRoomHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      final payload = jsonDecode(await request.readAsString());
      if (payload['name'] == null) return Response(400, body: '{"error": "Room name required"}');
      
      int roomId = await db.insert('services_rooms', {
        'name': payload['name'],
        'capacity': payload['capacity'] ?? 1,
        'active': 1,
      });
      return Response.ok(jsonEncode({'success': true, 'room_id': roomId}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _addAddonHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      final bookingIdStr = request.params['id'];
      if (bookingIdStr == null) return Response(400, body: '{"error": "Missing booking ID"}');
      final bookingId = int.tryParse(bookingIdStr);

      final payload = jsonDecode(await request.readAsString());
      int addedDuration = payload['duration_minutes'] ?? 0;

      // 1. Insert add-on
      await db.insert('services_booking_addons', {
        'booking_id': bookingId,
        'addon_name': payload['name'],
        'price': payload['price'] ?? 0.0,
        'duration_minutes': addedDuration,
      });

      // 2. Extend booking end_time
      if (addedDuration > 0) {
        final bookingQuery = await db.query('services_bookings', where: 'id = ?', whereArgs: [bookingId]);
        if (bookingQuery.isNotEmpty) {
          final int currentEnd = bookingQuery.first['end_time'];
          int extMillis = addedDuration * 60 * 1000;
          await db.update('services_bookings', {'end_time': currentEnd + extMillis}, where: 'id = ?', whereArgs: [bookingId]);
        }
      }
      return Response.ok(jsonEncode({'success': true, 'message': 'Add-on applied and time extended'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _createRecurringBookingsHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');
      final payload = jsonDecode(await request.readAsString());
      if (payload['rrule'] == null || payload['occurrences'] == null) {
        return Response(400, body: '{"error": "rrule and occurrences required"}');
      }

      // Normally RRULE would be parsed to generate timestamps. Mocking generation for now.
      int count = payload['occurrences'];
      int baseParentId = payload['parent_booking_id'] ?? 0;

      return Response.ok(jsonEncode({'success': true, 'generated_instances': count, 'parent_id': baseParentId}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // ========== Screens ==========
  
  @override
  List<ModuleScreen> get providerScreens => [
    ModuleScreen(
      route: '/services/catalog',
      builder: (_) => const _PlaceholderScreen(title: 'Service Catalog'),
      icon: Icons.list_alt,
      label: 'Services',
      isDefault: true,
    ),
    ModuleScreen(
      route: '/services/calendar',
      builder: (_) => const _PlaceholderScreen(title: 'Bookings Calendar'),
      icon: Icons.calendar_month,
      label: 'Calendar',
    ),
    ModuleScreen(
      route: '/services/staff',
      builder: (_) => const _PlaceholderScreen(title: 'Staff Management'),
      icon: Icons.people,
      label: 'Staff',
    ),
  ];

  @override
  List<ModuleScreen> get customerScreens => [
    ModuleScreen(
      route: '/services/browse',
      builder: (_) => const _PlaceholderScreen(title: 'Browse Services'),
      icon: Icons.spa,
      label: 'Services',
      isDefault: true,
    ),
    ModuleScreen(
      route: '/services/book',
      builder: (_) => const _PlaceholderScreen(title: 'Book Appointment'),
      icon: Icons.event_available,
      label: 'Book',
    ),
    ModuleScreen(
      route: '/services/my-bookings',
      builder: (_) => const _PlaceholderScreen(title: 'My Bookings'),
      icon: Icons.calendar_today,
      label: 'Bookings',
    ),
  ];

  // ========== Database ==========
  
  @override
  List<String> get migrationSQL => [
    // Services catalog table
    '''
    CREATE TABLE IF NOT EXISTS services_catalog (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      duration_minutes INTEGER NOT NULL DEFAULT 30,
      price REAL NOT NULL,
      category TEXT,
      staff_ids TEXT,
      active INTEGER NOT NULL DEFAULT 1,
      image_path TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
    )
    ''',
    
    // Staff table
    '''
    CREATE TABLE IF NOT EXISTS services_staff (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      role TEXT,
      phone TEXT,
      email TEXT,
      available_days TEXT DEFAULT '1,2,3,4,5',
      work_hours_start TEXT DEFAULT '09:00',
      work_hours_end TEXT DEFAULT '17:00',
      break_start TEXT,
      break_end TEXT,
      active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
    )
    ''',
    
    // Bookings table
    '''
    CREATE TABLE IF NOT EXISTS services_bookings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      service_id INTEGER NOT NULL,
      staff_id INTEGER,
      customer_name TEXT NOT NULL,
      customer_phone TEXT,
      customer_email TEXT,
      start_time INTEGER NOT NULL,
      end_time INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      notes TEXT,
      deposit_paid REAL DEFAULT 0,
      room_id INTEGER,
      rrule TEXT,
      parent_booking_id INTEGER,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
      FOREIGN KEY (service_id) REFERENCES services_catalog(id),
      FOREIGN KEY (staff_id) REFERENCES services_staff(id),
      FOREIGN KEY (room_id) REFERENCES services_rooms(id)
    )
    ''',
    
    // Subsystem B: Buffer / Cleanup Times
    '''
    ALTER TABLE services_catalog ADD COLUMN buffer_minutes INTEGER DEFAULT 0;
    ''',

    // Subsystem A: Multi-Resource Constraints
    '''
    CREATE TABLE IF NOT EXISTS services_rooms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      capacity INTEGER NOT NULL DEFAULT 1,
      active INTEGER NOT NULL DEFAULT 1
    )
    ''',

    // Subsystem C: Service Add-ons
    '''
    CREATE TABLE IF NOT EXISTS services_booking_addons (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      booking_id INTEGER NOT NULL,
      addon_name TEXT NOT NULL,
      price REAL NOT NULL,
      duration_minutes INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (booking_id) REFERENCES services_bookings(id) ON DELETE CASCADE
    )
    ''',
    
    // Indexes
    '''
    CREATE INDEX IF NOT EXISTS idx_bookings_start_time ON services_bookings(start_time)
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_bookings_status ON services_bookings(status)
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_bookings_staff ON services_bookings(staff_id)
    ''',
  ];

  // ========== Lifecycle ==========
  
  @override
  Future<void> onActivate(dynamic db, String shopId) async {
    debugPrint('✅ ServicesModule activated for shop $shopId');
  }

  @override
  Future<void> onDeactivate(dynamic db, String shopId) async {
    debugPrint('⏸️ ServicesModule deactivated for shop $shopId');
  }

  @override
  Map<String, dynamic> getDefaultConfig() => {
    'default_duration': 30,
    'booking_lead_time_hours': 2,
    'max_advance_booking_days': 30,
    'require_phone': true,
    'allow_cancellation': true,
    'cancellation_hours_before': 24,
  };

  @override
  String? validateConfig(Map<String, dynamic> config) {
    if (!config.containsKey('default_duration')) {
      return 'Missing required key: default_duration';
    }
    return null; // Valid
  }
}

// Placeholder widget for screens
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
