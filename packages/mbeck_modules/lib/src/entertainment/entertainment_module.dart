import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/module_base.dart';
import '../core/module_feature.dart';
import '../core/module_types.dart';
import '../core/route_definition.dart';

/// Entertainment module for session-based businesses.
/// 
/// Designed for:
/// - Pool tables
/// - PlayStation / gaming rooms
/// - Swimming pools
/// - Karaoke rooms
/// - Any time-based or entry-based entertainment asset
/// 
/// Features:
/// - Asset registry (define tables, stations, lanes, rooms)
/// - Timer-based billing (per hour / per session / flat entry)
/// - Live session dashboard with running costs
/// - Walk-in queue management
/// - Asset category grouping (e.g., "Pool", "Gaming", "Swimming")
class EntertainmentModule extends MbeckModule {
  @override
  ModuleType get type => ModuleType.entertainment;

  @override
  String get id => 'entertainment';

  @override
  String get displayName => 'Entertainment & Sessions';

  @override
  IconData get icon => Icons.sports_esports;

  @override
  String get description =>
      'Manage pool tables, gaming stations, swimming pools and other session-based assets with timer billing';

  @override
  String get version => '1.0.0';

  // ========== Features ==========
  
  @override
  List<ModuleFeature> get features => const [
    ModuleFeature(
      id: 'asset_registry',
      name: 'Asset Registry',
      description: 'Define and manage entertainment assets (tables, stations, rooms)',
      defaultEnabled: true,
      iconName: 'devices',
    ),
    ModuleFeature(
      id: 'timer_billing',
      name: 'Timer Billing',
      description: 'Charge customers by duration (per hour, per 30min, etc.)',
      defaultEnabled: true,
      iconName: 'timer',
    ),
    ModuleFeature(
      id: 'flat_rate',
      name: 'Flat Rate Entry',
      description: 'Charge a fixed entry fee (e.g., swimming pool entry)',
      defaultEnabled: true,
      iconName: 'confirmation_number',
    ),
    ModuleFeature(
      id: 'live_dashboard',
      name: 'Live Sessions Dashboard',
      description: 'Real-time view of all active sessions with running costs',
      defaultEnabled: true,
      iconName: 'monitor_heart',
    ),
    ModuleFeature(
      id: 'walk_in_queue',
      name: 'Walk-in Queue',
      description: 'Manage waiting customers when assets are occupied',
      defaultEnabled: false,
      iconName: 'queue',
    ),
    ModuleFeature(
      id: 'session_history',
      name: 'Session History',
      description: 'View past sessions and revenue per asset',
      defaultEnabled: true,
      iconName: 'history',
    ),
  ];

  // ========== API Routes ==========
  
  @override
  List<RouteDefinition> get apiRoutes => [
    RouteDefinition(
      method: 'GET',
      path: '/api/v1/entertainment/assets',
      description: 'Get available entertainment assets',
      handler: _assetsHandler,
    ),
    RouteDefinition(
      method: 'GET',
      path: '/api/v1/entertainment/sessions',
      description: 'Get active sessions',
      handler: _sessionsHandler,
    ),
    // Subsystem B: Cross-Module Tabs
    RouteDefinition(
      method: 'POST',
      path: '/api/v1/entertainment/sessions/<id>/tabs',
      description: 'Link an external order to the session tab',
      handler: _linkTabHandler,
    ),
    // Subsystem C: Pause/Suspend
    RouteDefinition(
      method: 'POST',
      path: '/api/v1/entertainment/sessions/<id>/pause',
      description: 'Pause an active session timer',
      handler: _pauseSessionHandler,
    ),
    RouteDefinition(
      method: 'POST',
      path: '/api/v1/entertainment/sessions/<id>/resume',
      description: 'Resume a paused session timer',
      handler: _resumeSessionHandler,
    ),
  ];

  static dynamic _getDb(Request request) {
    return request.context['db'];
  }

  static Future<Response> _assetsHandler(Request request) async {
    return Response.ok(
      '{"assets": [], "message": "Entertainment assets endpoint"}',
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<Response> _sessionsHandler(Request request) async {
    return Response.ok(
      '{"sessions": [], "message": "Active sessions endpoint"}',
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<Response> _linkTabHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');

      final sessionIdStr = request.params['id'];
      if (sessionIdStr == null) return Response(400, body: '{"error": "Missing session ID"}');
      final sessionId = int.tryParse(sessionIdStr);

      final payload = jsonDecode(await request.readAsString());
      if (payload['external_order_id'] == null || payload['amount'] == null) {
        return Response(400, body: '{"error": "external_order_id and amount are required"}');
      }

      int tabId = await db.insert('entertainment_tabs', {
        'session_id': sessionId,
        'external_order_id': payload['external_order_id'].toString(),
        'external_module': payload['external_module'] ?? 'restaurant',
        'amount': payload['amount'],
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      return Response.ok(jsonEncode({'success': true, 'tab_id': tabId}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _pauseSessionHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');

      final sessionIdStr = request.params['id'];
      if (sessionIdStr == null) return Response(400, body: '{"error": "Missing session ID"}');
      final sessionId = int.tryParse(sessionIdStr);

      await db.update(
        'entertainment_sessions',
        {
          'status': 'paused',
          'last_paused_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [sessionId, 'active']
      );

      return Response.ok(jsonEncode({'success': true}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  static Future<Response> _resumeSessionHandler(Request request) async {
    try {
      final db = _getDb(request);
      if (db == null) return Response(500, body: '{"error": "Database not initialized"}');

      final sessionIdStr = request.params['id'];
      if (sessionIdStr == null) return Response(400, body: '{"error": "Missing session ID"}');
      final sessionId = int.tryParse(sessionIdStr);

      final sessionQuery = await db.query('entertainment_sessions', where: 'id = ?', whereArgs: [sessionId]);
      if (sessionQuery.isEmpty) return Response(404, body: '{"error": "Session not found"}');
      
      final sessionMap = sessionQuery.first;
      final int lastPaused = sessionMap['last_paused_at'] as int? ?? 0;
      final int totalPaused = sessionMap['total_paused_seconds'] as int? ?? 0;
      
      int newlyPausedSeconds = 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (lastPaused > 0) {
        newlyPausedSeconds = ((now - lastPaused) / 1000).floor();
      }

      await db.update(
        'entertainment_sessions',
        {
          'status': 'active',
          'total_paused_seconds': totalPaused + newlyPausedSeconds,
          'last_paused_at': null,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [sessionId, 'paused']
      );

      return Response.ok(jsonEncode({'success': true, 'added_pause_seconds': newlyPausedSeconds}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // ========== Screens ==========
  
  @override
  List<ModuleScreen> get providerScreens => [
    ModuleScreen(
      route: '/entertainment/sessions',
      builder: (_) => const _PlaceholderScreen(title: 'Live Sessions'),
      icon: Icons.play_circle,
      label: 'Sessions',
      isDefault: true,
    ),
    ModuleScreen(
      route: '/entertainment/assets',
      builder: (_) => const _PlaceholderScreen(title: 'Manage Assets'),
      icon: Icons.devices,
      label: 'Assets',
    ),
  ];

  @override
  List<ModuleScreen> get customerScreens => [];

  // ========== Migrations ==========
  
  @override
  List<String> get migrationSQL => [
    '''
    CREATE TABLE IF NOT EXISTS entertainment_assets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cloud_id TEXT,
      name TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'general',
      asset_type TEXT NOT NULL DEFAULT 'hourly',
      rate_per_hour REAL NOT NULL DEFAULT 0,
      flat_rate REAL DEFAULT 0,
      description TEXT,
      image_path TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      sort_order INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS entertainment_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cloud_id TEXT,
      asset_id INTEGER NOT NULL,
      customer_name TEXT,
      started_at INTEGER NOT NULL,
      ended_at INTEGER,
      billing_type TEXT NOT NULL DEFAULT 'hourly',
      rate REAL NOT NULL DEFAULT 0,
      total_amount REAL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'active',
      notes TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
      FOREIGN KEY (asset_id) REFERENCES entertainment_assets (id) ON DELETE CASCADE
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_assets_category ON entertainment_assets(category);',
    'CREATE INDEX IF NOT EXISTS idx_assets_active ON entertainment_assets(is_active);',
    'CREATE INDEX IF NOT EXISTS idx_sessions_asset ON entertainment_sessions(asset_id);',
    'CREATE INDEX IF NOT EXISTS idx_sessions_status ON entertainment_sessions(status);',
    'CREATE INDEX IF NOT EXISTS idx_sessions_started ON entertainment_sessions(started_at);',

    // Subsystem A: Pre-paid auto-stop and Subsystem C: Pause Timers
    'ALTER TABLE entertainment_sessions ADD COLUMN max_duration_seconds INTEGER;',
    'ALTER TABLE entertainment_sessions ADD COLUMN total_paused_seconds INTEGER DEFAULT 0;',
    'ALTER TABLE entertainment_sessions ADD COLUMN last_paused_at INTEGER;',

    // Subsystem B: Cross-Module Tabs
    '''
    CREATE TABLE IF NOT EXISTS entertainment_tabs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id INTEGER NOT NULL,
      external_order_id TEXT NOT NULL,
      external_module TEXT NOT NULL,
      amount REAL NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (session_id) REFERENCES entertainment_sessions (id) ON DELETE CASCADE
    );
    ''',

    // Subsystem D: Dynamic Pricing Rules
    '''
    CREATE TABLE IF NOT EXISTS entertainment_pricing_rules (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      asset_id INTEGER,
      category TEXT,
      day_of_week INTEGER,
      start_time TEXT,
      end_time TEXT,
      rate_per_hour REAL NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1
    );
    ''',
  ];

  @override
  Future<void> onActivate(dynamic db, String shopId) async {
    // Run migrations to create tables
    for (final sql in migrationSQL) {
      try {
        await db.execute(sql);
      } catch (e) {
        debugPrint('⚠️ Entertainment migration: $e');
      }
    }
    debugPrint('🎮 EntertainmentModule activated for shop $shopId');
  }

  @override
  Future<void> onDeactivate(dynamic db, String shopId) async {
    debugPrint('🎮 EntertainmentModule deactivated for shop $shopId');
  }

  @override
  Map<String, dynamic> getDefaultConfig() => {
    'features': {
      'asset_registry': true,
      'timer_billing': true,
      'flat_rate': true,
      'live_dashboard': true,
      'walk_in_queue': false,
      'session_history': true,
    },
    'ui': {
      'layout': 'grid',
      'showRunningCost': true,
      'autoRefreshSeconds': 30,
    },
    'billing': {
      'roundUpMinutes': 15,
      'minimumCharge': 0,
      'gracePeriodMinutes': 5,
    },
  };

  @override
  String? validateConfig(Map<String, dynamic> config) {
    if (config['features'] == null) {
      return 'Missing features configuration';
    }
    final billing = config['billing'];
    if (billing != null) {
      final roundUp = billing['roundUpMinutes'];
      if (roundUp != null && (roundUp < 1 || roundUp > 60)) {
        return 'Round-up minutes must be between 1 and 60';
      }
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
