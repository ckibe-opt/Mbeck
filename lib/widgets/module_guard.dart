import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';

/// Widget that conditionally renders its child based on module availability.
/// 
/// Use this to wrap any module-specific widget or screen section.
/// Example:
/// ```dart
/// ModuleGuard(
///   moduleId: 'restaurant',
///   child: MenuManagementScreen(),
///   fallback: Text('Restaurant module not installed'),
/// )
/// ```
class ModuleGuard extends StatefulWidget {
  /// The module ID to check (e.g., 'retail', 'restaurant', 'services')
  final String moduleId;
  
  /// Widget to show if module is enabled
  final Widget child;
  
  /// Widget to show if module is not enabled (defaults to empty)
  final Widget? fallback;

  const ModuleGuard({
    super.key,
    required this.moduleId,
    required this.child,
    this.fallback,
  });

  @override
  State<ModuleGuard> createState() => _ModuleGuardState();
}

class _ModuleGuardState extends State<ModuleGuard> {
  late Future<bool> _hasModuleFuture;

  @override
  void initState() {
    super.initState();
    _hasModuleFuture = OnboardingService.hasModule(widget.moduleId);
  }

  @override
  void didUpdateWidget(ModuleGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moduleId != widget.moduleId) {
      _hasModuleFuture = OnboardingService.hasModule(widget.moduleId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasModuleFuture,
      builder: (context, snapshot) {
        // While loading, return empty to avoid flicker
        if (!snapshot.hasData) {
          return widget.fallback ?? const SizedBox.shrink();
        }

        if (snapshot.data == true) {
          return widget.child;
        }

        return widget.fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// A streamlined guard that can be used inline in lists.
/// Returns the child only if module is installed, otherwise null.
class ModuleConditional {
  /// Check if a module is enabled synchronously from cached state
  static Future<bool> hasModule(String moduleId) async {
    return OnboardingService.hasModule(moduleId);
  }
  
  /// Build a list of widgets, filtering by module availability
  static Future<List<Widget>> filterByModule({
    required Map<String, Widget> moduleWidgets,
  }) async {
    final result = <Widget>[];
    
    for (final entry in moduleWidgets.entries) {
      if (await hasModule(entry.key)) {
        result.add(entry.value);
      }
    }
    
    return result;
  }
}

/// Provider-style widget for module-aware builds
class ModuleAwareBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, List<String> enabledModules) builder;

  const ModuleAwareBuilder({
    super.key,
    required this.builder,
  });

  @override
  State<ModuleAwareBuilder> createState() => _ModuleAwareBuilderState();
}

class _ModuleAwareBuilderState extends State<ModuleAwareBuilder> {
  late Future<List<String>> _selectedModulesFuture;

  @override
  void initState() {
    super.initState();
    _selectedModulesFuture = OnboardingService.getSelectedModules();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _selectedModulesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return widget.builder(context, snapshot.data!);
      },
    );
  }
}

/// Extension for easy conditional widget inclusion in lists
extension ModuleListExtension on List<Widget> {
  /// Add widget only if the module is in the enabled list
  void addIfModule(String moduleId, List<String> enabledModules, Widget widget) {
    if (enabledModules.contains(moduleId)) {
      add(widget);
    }
  }
}

/// Helper class for inline module checks in build methods
class ModuleHelper {
  static List<String>? _cachedModules;
  
  /// Preload modules into cache (call at app start)
  static Future<void> preload() async {
    _cachedModules = await OnboardingService.getSelectedModules();
  }
  
  /// Get cached modules (synchronous after preload)
  static List<String> get modules => _cachedModules ?? ['retail'];
  
  /// Check if module is enabled (synchronous after preload)
  static bool has(String moduleId) => modules.contains(moduleId);
  
  /// Refresh cache
  static Future<void> refresh() async {
    _cachedModules = await OnboardingService.getSelectedModules();
  }
}
