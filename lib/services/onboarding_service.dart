import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'module_service.dart';
import 'analytics_service.dart';


/// Service for managing first-launch onboarding flow.
/// 
/// Handles:
/// - Checking if user has completed onboarding
/// - Saving selected business type/modules
/// - Triggering module activation
class OnboardingService {
  static const String _onboardingKey = 'onboarding_complete';
  static const String _selectedModulesKey = 'selected_modules';
  static const String _businessTypeKey = 'business_type';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Check if user has completed onboarding
  static Future<bool> isComplete() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  /// Save selected business type and mark onboarding complete
  /// 
  /// [moduleIds] - List of module IDs to activate (e.g., ['retail', 'restaurant'])
  /// [shopId] - Shop ID to activate modules for
  static Future<void> completeOnboarding({
    required List<String> moduleIds,
    required String shopId,
  }) async {
    final prefs = await _getPrefs();
    
    // Save selections
    await prefs.setStringList(_selectedModulesKey, moduleIds);
    
    // Activate each module
    for (final moduleId in moduleIds) {
      try {
        await ModuleService.activateModule(shopId, moduleId);
        debugPrint('✅ Activated module: $moduleId');
        await AnalyticsService.logModuleToggled(moduleId: moduleId, isEnabled: true);
      } catch (e) {
        print('⚠️ Failed to activate $moduleId: $e');
      }
    }
    
    // Sync enabled_modules to Supabase so other devices get the right modules
    try {
      final supabase = _getSupabaseClient();
      if (supabase != null) {
        await supabase.from('shops').update({
          'enabled_modules': moduleIds,
        }).eq('id', shopId);
        debugPrint('☁️ Synced enabled_modules to cloud: $moduleIds');
      }
    } catch (e) {
      debugPrint('⚠️ Cloud sync of modules failed (offline): $e');
    }
    
    // Mark onboarding complete
    await prefs.setBool(_onboardingKey, true);
    print('✅ Onboarding complete with modules: $moduleIds');
  }

  /// Get user's selected modules
  static Future<List<String>> getSelectedModules() async {
    final prefs = await _getPrefs();
    return prefs.getStringList(_selectedModulesKey) ?? ['retail'];
  }

  /// Get selected modules for a specific shop (from database)
  static Future<List<String>> getShopModules(String shopId) async {
    return await ModuleService.getEnabledModules(shopId);
  }

  /// Check if a specific module is enabled
  static Future<bool> hasModule(String moduleId) async {
    final modules = await getSelectedModules();
    return modules.contains(moduleId);
  }

  /// Add a module after onboarding
  static Future<void> addModule(String moduleId, String shopId) async {
    final prefs = await _getPrefs();
    final modules = await getSelectedModules();
    
    if (!modules.contains(moduleId)) {
      modules.add(moduleId);
      await prefs.setStringList(_selectedModulesKey, modules);
      await ModuleService.activateModule(shopId, moduleId);
      await AnalyticsService.logModuleToggled(moduleId: moduleId, isEnabled: true);
      
      // Sync to Supabase cloud
      try {
        await _syncModuleToCloud(moduleId, shopId, isAdding: true);
      } catch (e) {
        debugPrint('⚠️ Cloud sync failed (offline mode): $e');
      }
      
      debugPrint('✅ Added module: $moduleId');
    }
  }

  /// Remove a module
  static Future<void> removeModule(String moduleId, String shopId) async {
    final prefs = await _getPrefs();
    final modules = await getSelectedModules();
    
    modules.remove(moduleId);
    await prefs.setStringList(_selectedModulesKey, modules);
    await ModuleService.deactivateModule(shopId, moduleId);
    await AnalyticsService.logModuleToggled(moduleId: moduleId, isEnabled: false);
    
    // Sync removal to Supabase cloud
    try {
      await _syncModuleToCloud(moduleId, shopId, isAdding: false);
    } catch (e) {
      debugPrint('⚠️ Cloud sync failed (offline mode): $e');
    }
    
    debugPrint('⏸️ Removed module: $moduleId');
  }

  /// Save selected modules (used by SubscriptionService)
  static Future<void> saveSelectedModules(List<String> modules) async {
    final prefs = await _getPrefs();
    await prefs.setStringList(_selectedModulesKey, modules);
  }

  /// Auto-configure modules when joining an existing shop.
  /// 
  /// Fetches the shop's enabled_modules from Supabase, activates them locally,
  /// and marks onboarding complete — so the user skips BusinessTypeSelectorScreen.
  static Future<void> completeOnboardingForJoinedShop(String shopId) async {
    try {
      // 1. Fetch the shop's enabled_modules from Supabase
      List<String> modules = ['retail']; // fallback default
      
      final supabase = _getSupabaseClient();
      if (supabase != null) {
        final response = await supabase
            .from('shops')
            .select('enabled_modules')
            .eq('id', shopId)
            .maybeSingle();
        
        if (response != null && response['enabled_modules'] != null) {
          modules = List<String>.from(response['enabled_modules']);
          debugPrint('📦 Fetched shop modules from cloud: $modules');
        }
      }

      // 2. Save and activate modules
      await completeOnboarding(moduleIds: modules, shopId: shopId);
      
      // 3. Mark setup wizard complete so they don't get routed to QuickSetupScreen
      final prefs = await _getPrefs();
      await prefs.setBool('setup_wizard_complete', true);
      
      debugPrint('✅ Auto-configured modules for joined shop: $modules');
    } catch (e) {
      debugPrint('⚠️ Failed to auto-configure modules, using defaults: $e');
      // Fallback: at least mark onboarding complete with retail
      await completeOnboarding(moduleIds: ['retail'], shopId: shopId);
      final prefs = await _getPrefs();
      await prefs.setBool('setup_wizard_complete', true);
    }
  }

  /// Sync module change to Supabase
  static Future<void> _syncModuleToCloud(String moduleId, String shopId, {required bool isAdding}) async {
    final supabase = _getSupabaseClient();
    if (supabase == null) return;
    

    if (isAdding) {
      await supabase.from('shop_modules').upsert({
        'shop_id': shopId,
        'module_id': moduleId,
        'installed_at': DateTime.now().toIso8601String(),
        'is_active': true,
      }, onConflict: 'shop_id,module_id');
    } else {
      await supabase.from('shop_modules').update({
        'is_active': false,
      }).eq('shop_id', shopId).eq('module_id', moduleId);
    }
    
    // Update shop's enabled_modules array
    final modules = await getSelectedModules();
    await supabase.from('shops').update({
      'enabled_modules': modules,
    }).eq('id', shopId);
  }

  /// Get Supabase client
  static SupabaseClient? _getSupabaseClient() {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('⚠️ Supabase not initialized: $e');
      return null;
    }
  }


  /// Reset onboarding (for testing/development)
  static Future<void> reset() async {
    final prefs = await _getPrefs();
    await prefs.remove(_onboardingKey);
    await prefs.remove(_selectedModulesKey);
    await prefs.remove(_businessTypeKey);
    print('🔄 Onboarding reset');
  }

  /// Get business type description for display
  static String getBusinessTypeLabel(List<String> modules) {
    if (modules.length > 1) {
      return 'Multi-Business';
    }
    switch (modules.firstOrNull) {
      case 'retail':
        return 'Retail Store';
      case 'services':
        return 'Service Business';
      case 'restaurant':
        return 'Restaurant/Food';
      case 'entertainment':
        return 'Entertainment/Sessions';
      case 'lodging':
        return 'Lodging/Accommodation';
      default:
        return 'Business';
    }
  }
}
