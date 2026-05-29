/// Represents a toggleable feature within a module.
/// 
/// Features allow granular control over module capabilities.
/// For example, the Retail module might have:
/// - Barcode Support (enabled by default)  
/// - Stock Alerts (disabled by default)
class ModuleFeature {
  /// Unique identifier for this feature
  final String id;

  /// Display name for UI
  final String name;

  /// Description of what this feature does
  final String description;

  /// Whether this feature is enabled by default
  final bool defaultEnabled;

  /// Icon name (Material Icon)
  final String? iconName;

  const ModuleFeature({
    required this.id,
    required this.name,
    required this.description,
    this.defaultEnabled = true,
    this.iconName,
  });

  @override
  String toString() => 'ModuleFeature($id, enabled: $defaultEnabled)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModuleFeature && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
