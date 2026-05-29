import 'module_base.dart';
import 'module_types.dart';

/// Callback for module lifecycle events
typedef ModuleEventCallback = void Function(MbeckModule module, String shopId);

/// Central registry for all available modules.
/// 
/// The registry manages module registration, activation status,
/// and provides access to module instances.
/// 
/// ## Usage
/// ```dart
/// // At app startup
/// ModuleRegistry.instance.registerAll([
///   RetailModule(),
///   ServicesModule(),
/// ]);
/// 
/// // Check if module is available
/// if (ModuleRegistry.instance.hasModule('retail')) {
///   final retail = ModuleRegistry.instance.getModule('retail');
/// }
/// ```
class ModuleRegistry {
  ModuleRegistry._();

  static final ModuleRegistry _instance = ModuleRegistry._();

  /// Singleton instance
  static ModuleRegistry get instance => _instance;

  final Map<String, MbeckModule> _modules = {};

  /// Callbacks for when a module is activated
  final List<ModuleEventCallback> _activationCallbacks = [];

  /// Callbacks for when a module is deactivated
  final List<ModuleEventCallback> _deactivationCallbacks = [];

  /// Register a single module
  void register(MbeckModule module) {
    if (_modules.containsKey(module.id)) {
      throw StateError('Module ${module.id} is already registered');
    }
    _modules[module.id] = module;
  }

  /// Register multiple modules at once
  void registerAll(List<MbeckModule> modules) {
    for (final module in modules) {
      register(module);
    }
  }

  /// Check if a module is registered
  bool hasModule(String moduleId) => _modules.containsKey(moduleId);

  /// Get a module by ID
  /// 
  /// Throws if module is not registered
  MbeckModule getModule(String moduleId) {
    final module = _modules[moduleId];
    if (module == null) {
      throw StateError('Module $moduleId is not registered');
    }
    return module;
  }

  /// Get a module by type
  MbeckModule? getModuleByType(ModuleType type) {
    for (final module in _modules.values) {
      if (module.type == type) return module;
    }
    return null;
  }

  /// Get all registered modules
  List<MbeckModule> get allModules => _modules.values.toList();

  /// Get all registered module IDs
  List<String> get allModuleIds => _modules.keys.toList();

  /// Add a callback for module activation
  void addActivationListener(ModuleEventCallback callback) {
    _activationCallbacks.add(callback);
  }

  /// Add a callback for module deactivation
  void addDeactivationListener(ModuleEventCallback callback) {
    _deactivationCallbacks.add(callback);
  }

  /// Notify listeners that a module was activated
  void notifyActivated(MbeckModule module, String shopId) {
    for (final callback in _activationCallbacks) {
      callback(module, shopId);
    }
  }

  /// Notify listeners that a module was deactivated
  void notifyDeactivated(MbeckModule module, String shopId) {
    for (final callback in _deactivationCallbacks) {
      callback(module, shopId);
    }
  }

  /// Clear all registered modules (useful for testing)
  void clear() {
    _modules.clear();
    _activationCallbacks.clear();
    _deactivationCallbacks.clear();
  }

  /// Get module price (for subscription billing)
  double getModulePrice(String moduleId) {
    switch (moduleId) {
      case 'retail':
        return 0.0; // Base module, free
      case 'services':
        return 299.0; // KES 299/month
      case 'restaurant':
        return 499.0; // KES 499/month
      case 'entertainment':
        return 399.0; // KES 399/month
      case 'lodging':
        return 499.0; // KES 499/month
      default:
        return 0.0;
    }
  }

  /// Calculate total monthly cost for a set of modules
  double calculateTotalCost(List<String> moduleIds) {
    return moduleIds.fold(0.0, (sum, id) => sum + getModulePrice(id));
  }
}

