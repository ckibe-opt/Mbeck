import 'onboarding_service.dart';

/// Centralized module scoping utility.
/// 
/// Provides SQL WHERE clauses and helpers to filter data by the currently
/// active module(s). All read queries on shared tables (inventory, txn)
/// should use this to enforce module isolation.
/// 
/// Usage:
///   final scope = await ModuleScope.current();
///   final sql = 'SELECT * FROM inventory WHERE ${scope.inventoryWhere}';
///   final args = scope.moduleArgs;
class ModuleScope {
  final List<String> activeModules;

  ModuleScope(this.activeModules);

  /// Get scope for currently active modules
  static Future<ModuleScope> current() async {
    final modules = await OnboardingService.getSelectedModules();
    return ModuleScope(modules);
  }

  /// SQL WHERE clause for filtering inventory by source_module.
  /// Returns e.g. "source_module IN (?, ?)" or "1=1" if no filtering needed.
  String get inventoryWhere {
    if (activeModules.isEmpty) return '1=1';
    final placeholders = List.filled(activeModules.length, '?').join(', ');
    return "source_module IN ($placeholders)";
  }

  /// SQL WHERE clause for filtering txn by source_module.
  String get txnWhere {
    if (activeModules.isEmpty) return '1=1';
    final placeholders = List.filled(activeModules.length, '?').join(', ');
    return "source_module IN ($placeholders)";
  }

  /// Arguments list matching the WHERE placeholders.
  List<String> get moduleArgs => List.from(activeModules);

  /// Whether a specific module is currently active.
  bool has(String moduleId) => activeModules.contains(moduleId);

  /// The primary module (first in list). Used for tagging new writes.
  String get primary => activeModules.isNotEmpty ? activeModules.first : 'retail';

  /// Get the appropriate source_module tag for a write operation.
  /// If the caller knows which module context they're in, pass it explicitly.
  /// Otherwise falls back to the primary active module.
  static Future<String> tagForWrite([String? explicitModule]) async {
    if (explicitModule != null) return explicitModule;
    final modules = await OnboardingService.getSelectedModules();
    return modules.isNotEmpty ? modules.first : 'retail';
  }
}
