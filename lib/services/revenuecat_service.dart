import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Wraps Google Play Billing natively using RevenueCat's SDK
class RevenueCatService {
  static const String entitlementPro = 'pro';
  static const String entitlementEnterprise = 'enterprise';

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// Initializes the purchases SDK. Must be called after dotenv.load() in main.dart
  static Future<void> init() async {
    if (_initialized) return;
    try {
      if (kIsWeb) return; // Purchases flutter is not supported on web natively out-of-the-box
      
      await Purchases.setLogLevel(LogLevel.debug);

      String apiKey = '';
      if (Platform.isAndroid) {
        apiKey = dotenv.env['REVENUECAT_GOOGLE_API_KEY'] ?? '';
      } else if (Platform.isIOS) {
        apiKey = dotenv.env['REVENUECAT_APPLE_API_KEY'] ?? '';
      }

      if (apiKey.isEmpty) {
        debugPrint('⚠️ RevenueCat: REVENUECAT_GOOGLE_API_KEY is missing from .env! Billing is Disabled.');
        return;
      }

      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);
      _initialized = true;
      debugPrint('✅ RevenueCat natively connected to Google Play');
    } catch (e) {
      debugPrint('❌ RevenueCat init error: $e');
    }
  }

  /// Fetches the dynamically configured products via RevenueCat Offerings
  static Future<Offerings?> fetchOfferings() async {
    // If not initialized, wait a bit or try to init
    if (!_initialized) {
      debugPrint('⏳ RevenueCat: Waiting for background initialization...');
      // Wait up to 3 seconds for background init to complete
      for (int i = 0; i < 6; i++) {
        if (_initialized) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (!_initialized) {
      debugPrint('⚠️ RevenueCat: Still not initialized. Fetching offerings may fail.');
    }

    try {
      final offerings = await Purchases.getOfferings();
      return offerings;
    } catch (e) {
      debugPrint('❌ Error fetching Google Play offerings: $e');
      return null;
    }
  }

  /// Triggers the native Google Play sliding bottom-sheet for a Package
  static Future<bool> purchasePackage(Package package) async {
    try {
      debugPrint('🛒 Paying for ${package.identifier} via Google Play...');
      final customerInfo = await Purchases.purchasePackage(package);
      
      final isPro = customerInfo.entitlements.active.containsKey(entitlementPro);
      final isEnterprise = customerInfo.entitlements.active.containsKey(entitlementEnterprise);
      
      if (isPro || isEnterprise) {
        debugPrint('✅ Purchase successful! Premium unlocked.');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Native Purchase cancelled or failed: $e');
      return false;
    }
  }

  /// Restores previous purchases if the user reinstalls the app or changes devices
  static Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final isPro = customerInfo.entitlements.active.containsKey(entitlementPro);
      final isEnterprise = customerInfo.entitlements.active.containsKey(entitlementEnterprise);
      return isPro || isEnterprise;
    } catch (e) {
      debugPrint('❌ Native Restore error: $e');
      return false;
    }
  }

  /// Central access check: returns true if the current user has an active
  /// PRO or ENTERPRISE entitlement via Google Play / RevenueCat.
  ///
  /// Fail-closed: if SDK is not initialized or any error occurs, returns false
  /// so the paywall is always shown rather than silently granting access.
  static Future<bool> isProSubscriber() async {
    if (!_initialized) {
      debugPrint('⚠️ RevenueCat: isProSubscriber() called before init — treating as FREE.');
      return false;
    }
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final isPro = customerInfo.entitlements.active.containsKey(entitlementPro);
      final isEnterprise = customerInfo.entitlements.active.containsKey(entitlementEnterprise);
      debugPrint('💎 RevenueCat subscription check → PRO=$isPro ENTERPRISE=$isEnterprise');
      return isPro || isEnterprise;
    } catch (e) {
      debugPrint('⚠️ RevenueCat: isProSubscriber() check failed — treating as FREE: $e');
      return false; // Fail-closed
    }
  }

  /// Returns true if the user has an active ENTERPRISE entitlement on RevenueCat
  static Future<bool> isEnterpriseSubscriber() async {
    if (!_initialized) {
      debugPrint('⚠️ RevenueCat: isEnterpriseSubscriber() called before init — treating as FREE.');
      return false;
    }
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final isEnterprise = customerInfo.entitlements.active.containsKey(entitlementEnterprise);
      debugPrint('💎 RevenueCat enterprise subscription check → ENTERPRISE=$isEnterprise');
      return isEnterprise;
    } catch (e) {
      debugPrint('⚠️ RevenueCat: isEnterpriseSubscriber() check failed — treating as FREE: $e');
      return false; // Fail-closed
    }
  }
}
