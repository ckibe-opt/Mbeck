import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'device_service.dart';
import 'onboarding_service.dart';

/// Subscription Service for Supabase Billing Integration
/// Tracks subscriptions, modules, and billing in the cloud
class SubscriptionService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Tier pricing (KES per month)
  static const Map<String, double> tierPricing = {
    'FREE': 0.0,
    'PRO': 300.0,
    'ENTERPRISE': 1499.0,
  };

  /// Tier pricing (KES per year) - usually 10x monthly (2 months free)
  static const Map<String, double> tierPricingYearly = {
    'FREE': 0.0,
    'PRO': 3000.0,
    'ENTERPRISE': 14990.0,
  };

  /// Module add-on pricing (KES per month, on top of tier price)
  static const Map<String, double> modulePricing = {
    'retail': 0.0, // Base module, always free
    'services': 299.0,
    'restaurant': 499.0,
  };

  /// Module add-on pricing (KES per year)
  static const Map<String, double> modulePricingYearly = {
    'retail': 0.0,
    'services': 2990.0,
    'restaurant': 4990.0,
  };

  /// Check if a tier allows access to a given module
  static bool canAccessModule(String tier, String moduleId) {
    if (moduleId == 'retail') return true; // Always available
    if (tier.startsWith('ENTERPRISE')) return true; // All modules included
    if (tier.startsWith('PRO')) return true; // Pro can install with add-on pricing
    return false; // Free cannot install paid modules
  }

  /// Check if a tier allows adding multiple shops
  static bool canAddShop(String tier) {
    return tier.startsWith('ENTERPRISE');
  }

  /// Get tier base price
  static double getTierPrice(String tier, {bool isYearly = false}) {
    return (isYearly ? tierPricingYearly[tier] : tierPricing[tier]) ?? 0.0;
  }

  /// Get current subscription from Supabase
  static Future<Subscription?> getCurrentSubscription() async {
    try {
      final shopId = await DeviceService.getShopId();
      if (shopId == null) return null; // ignore: unnecessary_null_comparison

      final response = await _supabase
          .from('subscriptions')
          .select()
          .eq('shop_id', shopId)
          .maybeSingle();

      if (response == null) return null;
      return Subscription.fromMap(response);
    } catch (e) {
      debugPrint('❌ Error fetching subscription: $e');
      return null;
    }
  }

  /// Create or update subscription when modules change
  static Future<bool> updateSubscription(List<String> modules) async {
    try {
      final shopId = await DeviceService.getShopId();
      if (shopId == null) return false; // ignore: unnecessary_null_comparison

      final totalCost = _calculateTotal(modules);
      final now = DateTime.now();
      final cycleStart = DateTime(now.year, now.month, 1);
      final cycleEnd = DateTime(now.year, now.month + 1, 0);

      await _supabase.from('subscriptions').upsert({
        'shop_id': shopId,
        'modules': modules,
        'total_monthly_cost': totalCost,
        'billing_cycle_start': cycleStart.toIso8601String().split('T')[0],
        'billing_cycle_end': cycleEnd.toIso8601String().split('T')[0],
        'payment_status': totalCost > 0 ? 'pending' : 'free',
      }, onConflict: 'shop_id');

      debugPrint('💳 Subscription updated: $modules, cost: KES $totalCost');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating subscription: $e');
      return false;
    }
  }

  /// Add a new module to subscription
  static Future<Map<String, dynamic>> addModule(String moduleId) async {
    final result = <String, dynamic>{
      'success': false,
      'message': '',
    };

    try {
      final shopId = await DeviceService.getShopId();
      if (shopId == null) { // ignore: unnecessary_null_comparison
        result['message'] = 'Shop not found';
        return result;
      }

      // Get current modules
      final currentModules = await OnboardingService.getSelectedModules();
      if (currentModules.contains(moduleId)) {
        result['message'] = 'Module already installed';
        result['success'] = true;
        return result;
      }

      // Calculate new total
      final newModules = [...currentModules, moduleId];
      final modulePrice = modulePricing[moduleId] ?? 0.0;
      final newTotal = _calculateTotal(newModules);

      // Record in Supabase shop_modules
      await _supabase.from('shop_modules').upsert({
        'shop_id': shopId,
        'module_id': moduleId,
        'installed_at': DateTime.now().toIso8601String(),
        'module_version': '1.0.0',
        'is_active': true,
      }, onConflict: 'shop_id,module_id');

      // Update shops table
      await _supabase.from('shops').update({
        'enabled_modules': newModules,
      }).eq('id', shopId);

      // Update subscription
      await updateSubscription(newModules);

      // Update local storage
      await OnboardingService.saveSelectedModules(newModules);

      result['success'] = true;
      result['message'] = 'Module added successfully';
      result['modulePrice'] = modulePrice;
      result['newTotal'] = newTotal;
      result['paymentRequired'] = modulePrice > 0;

      debugPrint('✅ Module $moduleId added. Price: KES $modulePrice');

      // If payment required, trigger payment flow
      if (modulePrice > 0) {
        result['paymentUrl'] = 'mpesa://pay?amount=$modulePrice';
      }

      return result;
    } catch (e) {
      debugPrint('❌ Error adding module: $e');
      result['message'] = e.toString();
      return result;
    }
  }

  /// Remove a module from subscription
  static Future<bool> removeModule(String moduleId) async {
    try {
      if (moduleId == 'retail') {
        debugPrint('⚠️ Cannot remove base retail module');
        return false;
      }

      final shopId = await DeviceService.getShopId();
      if (shopId == null) return false; // ignore: unnecessary_null_comparison

      // Get current modules
      final currentModules = await OnboardingService.getSelectedModules();
      final newModules = currentModules.where((m) => m != moduleId).toList();

      // Deactivate in shop_modules
      await _supabase.from('shop_modules').update({
        'is_active': false,
      }).eq('shop_id', shopId).eq('module_id', moduleId);

      // Update shops table
      await _supabase.from('shops').update({
        'enabled_modules': newModules,
      }).eq('id', shopId);

      // Update subscription
      await updateSubscription(newModules);

      // Update local storage
      await OnboardingService.saveSelectedModules(newModules);

      debugPrint('✅ Module $moduleId removed');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing module: $e');
      return false;
    }
  }

  /// Record payment completion
  static Future<bool> recordPayment({
    required String transactionId,
    required double amount,
    required String method, // 'mpesa' or 'card'
  }) async {
    try {
      final shopId = await DeviceService.getShopId();
      if (shopId == null) return false; // ignore: unnecessary_null_comparison

      // Update subscription payment status
      await _supabase.from('subscriptions').update({
        'payment_status': 'paid',
        'payment_method': method,
      }).eq('shop_id', shopId);

      debugPrint('💰 Payment recorded: $transactionId ($method)');
      return true;
    } catch (e) {
      debugPrint('❌ Error recording payment: $e');
      return false;
    }
  }

  /// Calculate total monthly cost (tier base + module add-ons)
  static double _calculateTotal(List<String> modules, {String tier = 'PRO', bool isYearly = false}) {
    final tierMap = isYearly ? tierPricingYearly : tierPricing;
    final moduleMap = isYearly ? modulePricingYearly : modulePricing;

    final tierBase = tierMap[tier] ?? 0.0;
    if (tier == 'ENTERPRISE') return tierMap['ENTERPRISE']!; // All-inclusive
    final moduleTotal = modules.fold(0.0, (sum, moduleId) => sum + (moduleMap[moduleId] ?? 0.0));
    return tierBase + moduleTotal;
  }

  /// Get module price
  static double getModulePrice(String moduleId, {bool isYearly = false}) {
    return (isYearly ? modulePricingYearly[moduleId] : modulePricing[moduleId]) ?? 0.0;
  }

  /// Record pending M-Pesa transaction (Before STK Push)
  static Future<void> recordMpesaPending({
    required String? shopId,
    required double amount,
    required String accountReference,
    required String phoneNumber,
  }) async {
    try {
      await _supabase.from('mpesa_transactions').insert({
        'shop_id': shopId, // Can be null if not logged in? usually should exist
        'amount': amount,
        'account_reference': accountReference,
        'phone_number': phoneNumber,
        'status': 'pending',
        'result_code': -1,
        'result_desc': 'Initiating...',
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('⏳ Pre-logging M-Pesa transaction for $phoneNumber');
    } catch (e) {
      debugPrint('⚠️ Error pre-logging M-Pesa: $e');
    }
  }

  /// Update pending transaction with Checkout Request ID (After STK Push)
  static Future<void> updateCheckoutId({
    required String? shopId,
    required String checkoutRequestId,
    required String merchantRequestId,
  }) async {
    try {
      if (shopId == null) return;
      
      // Update the most recent pending transaction for this shop
      await _supabase
          .from('mpesa_transactions')
          .update({
            'checkout_request_id': checkoutRequestId,
            'merchant_request_id': merchantRequestId,
            'result_desc': 'STK Push Sent',
          })
          .eq('shop_id', shopId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(1);
          
      debugPrint('✅ Linked CheckoutID $checkoutRequestId to pending transaction');
    } catch (e) {
      debugPrint('⚠️ Error updating CheckoutID: $e');
    }
  }
}

/// Subscription model
class Subscription {
  final String id;
  final String shopId;
  final List<String> modules;
  final double totalMonthlyCost;
  final DateTime? billingCycleStart;
  final DateTime? billingCycleEnd;
  final String paymentStatus;
  final String? paymentMethod;

  Subscription({
    required this.id,
    required this.shopId,
    required this.modules,
    required this.totalMonthlyCost,
    this.billingCycleStart,
    this.billingCycleEnd,
    required this.paymentStatus,
    this.paymentMethod,
  });

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id']?.toString() ?? '',
      shopId: map['shop_id'] ?? '',
      modules: List<String>.from(map['modules'] ?? []),
      totalMonthlyCost: (map['total_monthly_cost'] ?? 0).toDouble(),
      billingCycleStart: map['billing_cycle_start'] != null
          ? DateTime.tryParse(map['billing_cycle_start'])
          : null,
      billingCycleEnd: map['billing_cycle_end'] != null
          ? DateTime.tryParse(map['billing_cycle_end'])
          : null,
      paymentStatus: map['payment_status'] ?? 'free',
      paymentMethod: map['payment_method'],
    );
  }

  bool get isPaid => paymentStatus == 'paid' || paymentStatus == 'free';
  bool get isFree => totalMonthlyCost == 0;
  bool get requiresPayment => paymentStatus == 'pending' && totalMonthlyCost > 0;
}
