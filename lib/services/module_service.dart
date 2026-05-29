import 'dart:convert';
import '../db/db_provider.dart';
import 'package:mbeck_modules/mbeck_modules.dart';

/// Service for managing module activation and configuration.
/// 
/// This service handles:
/// - Querying enabled modules for a shop
/// - Activating/deactivating modules
/// - Managing feature flags
class ModuleService {
  /// Get all enabled modules for a shop
  static Future<List<String>> getEnabledModules(String shopId) async {
    try {
      final db = await DbProvider.db;
      final result = await db.query(
        'shop_modules',
        columns: ['module_id'],
        where: 'shop_id = ? AND enabled = 1',
        whereArgs: [shopId],
      );
      
      if (result.isEmpty) {
        // Default: enable retail module for backward compatibility
        return ['retail'];
      }
      
      return result.map((row) => row['module_id'] as String).toList();
    } catch (e) {
      // If table doesn't exist yet, return default
      return ['retail'];
    }
  }

  /// Get module configuration for a specific module
  static Future<Map<String, dynamic>?> getModuleConfig(
    String shopId, 
    String moduleId,
  ) async {
    try {
      final db = await DbProvider.db;
      final result = await db.query(
        'shop_modules',
        columns: ['config'],
        where: 'shop_id = ? AND module_id = ?',
        whereArgs: [shopId, moduleId],
      );
      
      if (result.isEmpty || result.first['config'] == null) {
        // Return default config from module registry
        try {
          final module = ModuleRegistry.instance.getModule(moduleId);
          return module.getDefaultConfig();
        } catch (e) {
          return null;
        }
      }
      
      // Parse stored config
      final configJson = result.first['config'] as String;
      if (configJson.isEmpty) return {};
      final decoded = jsonDecode(configJson);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get all module configs for a shop
  static Future<Map<String, Map<String, dynamic>>> getAllModuleConfigs(
    String shopId,
  ) async {
    final enabledModules = await getEnabledModules(shopId);
    final configs = <String, Map<String, dynamic>>{};
    
    for (final moduleId in enabledModules) {
      final config = await getModuleConfig(shopId, moduleId);
      if (config != null) {
        configs[moduleId] = config;
      } else {
        // Use default config
        try {
          final module = ModuleRegistry.instance.getModule(moduleId);
          configs[moduleId] = module.getDefaultConfig();
        } catch (e) {
          // Module not registered, skip
        }
      }
    }
    
    return configs;
  }

  /// Activate a module for a shop
  static Future<void> activateModule(String shopId, String moduleId) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Check if module is registered
    if (!ModuleRegistry.instance.hasModule(moduleId)) {
      throw StateError('Module $moduleId is not registered');
    }
    
    final module = ModuleRegistry.instance.getModule(moduleId);
    
    // Insert or update
    await db.insert(
      'shop_modules',
      {
        'shop_id': shopId,
        'module_id': moduleId,
        'enabled': 1,
        'installed_at': now,
        'updated_at': now,
      },
    );
    
    // Run module activation hook
    await module.onActivate(db, shopId);
    
    // Notify listeners
    ModuleRegistry.instance.notifyActivated(module, shopId);
  }
  
  /// Deactivate a module for a shop
  static Future<void> deactivateModule(String shopId, String moduleId) async {
    final db = await DbProvider.db;
    
    // Update enabled flag to 0 (keep data)
    await db.update(
      'shop_modules',
      {
        'enabled': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'shop_id = ? AND module_id = ?',
      whereArgs: [shopId, moduleId],
    );
    
    // Run deactivation hook if module is registered
    if (ModuleRegistry.instance.hasModule(moduleId)) {
      final module = ModuleRegistry.instance.getModule(moduleId);
      await module.onDeactivate(db, shopId);
      ModuleRegistry.instance.notifyDeactivated(module, shopId);
    }
  }

  /// Get enabled features for a module
  static Future<Map<String, bool>> getEnabledFeatures(
    String shopId, 
    String moduleId,
  ) async {
    try {
      final db = await DbProvider.db;
      
      // Get default features from module
      final module = ModuleRegistry.instance.getModule(moduleId);
      final defaults = <String, bool>{};
      for (final feature in module.features) {
        defaults[feature.id] = feature.defaultEnabled;
      }
      
      // Get overrides from database
      final result = await db.query(
        'module_features',
        columns: ['feature_id', 'enabled'],
        where: 'shop_id = ? AND module_id = ?',
        whereArgs: [shopId, moduleId],
      );
      
      // Apply overrides
      for (final row in result) {
        final featureId = row['feature_id'] as String;
        final enabled = (row['enabled'] as int) == 1;
        defaults[featureId] = enabled;
      }
      
      return defaults;
    } catch (e) {
      return {};
    }
  }
}
