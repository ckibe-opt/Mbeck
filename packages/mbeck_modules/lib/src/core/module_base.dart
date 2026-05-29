import 'package:flutter/material.dart';

import 'module_feature.dart';
import 'module_types.dart';
import 'route_definition.dart';

/// Represents a screen provided by a module.
class ModuleScreen {
  /// Route path for navigation
  final String route;

  /// Widget builder for this screen
  final Widget Function(BuildContext context) builder;

  /// Icon for navigation/menu
  final IconData icon;

  /// Display label
  final String label;

  /// Whether this is the default screen for the module
  final bool isDefault;

  const ModuleScreen({
    required this.route,
    required this.builder,
    required this.icon,
    required this.label,
    this.isDefault = false,
  });
}

/// Abstract base class for all Mbeck modules.
/// 
/// Modules extend the core platform with business-type-specific logic.
/// Each module provides:
/// - Data models and services
/// - API endpoints
/// - Provider and Customer UI screens
/// - Database migrations
/// 
/// ## Example
/// ```dart
/// class RetailModule extends MbeckModule {
///   @override
///   ModuleType get type => ModuleType.retail;
///   
///   @override
///   String get id => 'retail';
///   
///   // ... implement other members
/// }
/// ```
abstract class MbeckModule {
  /// The type of business this module supports
  ModuleType get type;

  /// Unique identifier (matches ModuleType.id)
  String get id;

  /// Human-readable display name
  String get displayName;

  /// Icon for UI display
  IconData get icon;

  /// Description of this module's capabilities
  String get description;

  /// Version string (semver)
  String get version;

  /// Features this module provides
  List<ModuleFeature> get features;

  /// API routes to register on the seller HTTP server
  List<RouteDefinition> get apiRoutes;

  /// Provider-side screens (for Seller App)
  List<ModuleScreen> get providerScreens;

  /// Customer-side screens (for Buyer App)
  List<ModuleScreen> get customerScreens;

  /// SQL statements for database migrations
  /// Each string is a complete SQL statement
  List<String> get migrationSQL;

  /// Database connection injected by the host app.
  /// Used by module API routes to access the SQLite instance.
  dynamic dbConnection;

  /// Called when module is activated for a shop
  /// 
  /// [db] - Database connection
  /// [shopId] - ID of the shop activating this module
  Future<void> onActivate(dynamic db, String shopId) async {
    dbConnection = db;
  }

  /// Called when module is deactivated for a shop
  /// 
  /// [db] - Database connection
  /// [shopId] - ID of the shop deactivating this module
  Future<void> onDeactivate(dynamic db, String shopId) async {
    dbConnection = null;
  }

  /// Get the default configuration for this module
  Map<String, dynamic> getDefaultConfig();

  /// Validate a configuration object
  /// 
  /// Returns null if valid, error message if invalid
  String? validateConfig(Map<String, dynamic> config);

  @override
  String toString() => 'MbeckModule($id v$version)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MbeckModule && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
