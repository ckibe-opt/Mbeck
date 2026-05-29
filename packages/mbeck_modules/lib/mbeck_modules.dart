/// Mbeck Module System
/// 
/// Provides a plugin architecture for business-type-specific features.
/// 
/// ## Usage
/// ```dart
/// import 'package:mbeck_modules/mbeck_modules.dart';
/// 
/// // Register modules at app startup
/// ModuleRegistry.instance.registerAll([
///   RetailModule(),
///   ServicesModule(),
/// ]);
/// 
/// // Get enabled modules for a shop
/// final modules = await ModuleRegistry.instance.getEnabledModules(shopId);
/// ```
library mbeck_modules;

// Core exports
export 'src/core/module_base.dart';
export 'src/core/module_feature.dart';
export 'src/core/module_migrations.dart';
export 'src/core/module_registry.dart';
export 'src/core/module_types.dart';
export 'src/core/route_definition.dart';

// Retail module
export 'src/retail/retail_module.dart';

// Restaurant module
export 'src/restaurant/restaurant_module.dart';

// Services module (Phase 4)
export 'src/services/services_module.dart';

// Entertainment module (Session-based businesses)
export 'src/entertainment/entertainment_module.dart';

// Lodging module (Hotels, guesthouses, Airbnb)
export 'src/lodging/lodging_module.dart';

