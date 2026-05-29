import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop.dart';
import '../models/enterprise_metrics.dart';

/// Cloud-based enterprise analytics service
/// Fetches aggregated data across all shops from Supabase
class SupabaseEnterpriseService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch enterprise metrics for all user shops
  static Future<List<EnterpriseMetrics>> fetchEnterpriseMetrics(List<Shop> shops) async {
    final metrics = <EnterpriseMetrics>[];

    for (final shop in shops) {
      try {
        final shopMetrics = await _fetchShopMetrics(shop);
        metrics.add(shopMetrics);
      } catch (e) {
        print('⚠️ Failed to fetch cloud metrics for ${shop.businessName}: $e');
        // Create empty metrics as fallback
        metrics.add(EnterpriseMetrics(
          shop: shop,
          todaySales: 0,
          todayTxnCount: 0,
          retailRevenue: 0,
          restaurantRevenue: 0,
          servicesRevenue: 0,
          entertainmentRevenue: 0,
          lodgingRevenue: 0,
          pendingOrders: 0,
          activeSessions: 0,
          activeStays: 0,
          todayBookings: 0,
          enabledModules: ['retail'],
        ));
      }
    }

    return metrics;
  }

  /// Fetch metrics for a single shop from cloud
  static Future<EnterpriseMetrics> _fetchShopMetrics(Shop shop) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

    // Fetch today's transactions from cloud.
    // Canonical column names per migrations 001/005/006:
    //   transaction_type, module_source. Earlier code used `type`/`source_module`
    //   which silently failed on every read.
    final transactionsResponse = await _supabase
        .from('transactions')
        .select('total_amount, module_source, transaction_type')
        .eq('shop_id', shop.id)
        .gte('created_at', todayStart);

    double todaySales = 0;
    int todayTxnCount = 0;
    double retailRev = 0, restaurantRev = 0, servicesRev = 0, entertainmentRev = 0, lodgingRev = 0;

    for (final txn in transactionsResponse) {
      final txnType = txn['transaction_type'] as String?;
      // Count revenue-bearing transaction types
      if (txnType == 'sale' || txnType == 'booking' ||
          txnType == 'order' || txnType == 'session' || txnType == 'reservation') {
        final amount = (txn['total_amount'] as num?)?.toDouble() ?? 0;
        todaySales += amount;
        todayTxnCount++;

        final module = (txn['module_source'] as String?) ?? 'retail';
        switch (module) {
          case 'retail': retailRev += amount; break;
          case 'restaurant': restaurantRev += amount; break;
          case 'services': servicesRev += amount; break;
          case 'entertainment': entertainmentRev += amount; break;
          case 'lodging': lodgingRev += amount; break;
        }
      }
    }

    // Fetch active counts from cloud tables
    int pendingOrders = 0, activeSessions = 0, activeStays = 0, todayBookings = 0;

    try {
      final ordersResponse = await _supabase
          .from('restaurant_orders')
          .select('id')
          .eq('shop_id', shop.id)
          .inFilter('status', ['pending', 'preparing']);
      pendingOrders = ordersResponse.length;
    } catch (_) {}

    try {
      final sessionsResponse = await _supabase
          .from('entertainment_sessions')
          .select('id')
          .eq('shop_id', shop.id)
          .eq('status', 'active');
      activeSessions = sessionsResponse.length;
    } catch (_) {}

    try {
      final staysResponse = await _supabase
          .from('lodging_reservations')
          .select('id')
          .eq('shop_id', shop.id)
          .eq('status', 'checked_in');
      activeStays = staysResponse.length;
    } catch (_) {}

    try {
      final bookingsResponse = await _supabase
          .from('services_bookings')
          .select('id')
          .eq('shop_id', shop.id)
          .gte('start_time', todayStart);
      todayBookings = bookingsResponse.length;
    } catch (_) {}

    // Get enabled modules. The column lives on `shops`, not `shop_settings`
    // (shop_settings only carries id/shop_id/shop_name/branding/updated_at per
    // 20240428_cloud_schema_hardening.sql). The previous query always failed
    // and silently fell back to ['retail'] for every shop.
    List<String> enabledModules = ['retail'];
    try {
      final shopRow = await _supabase
          .from('shops')
          .select('enabled_modules')
          .eq('id', shop.id)
          .single();

      final raw = shopRow['enabled_modules'];
      if (raw is List) {
        enabledModules = raw.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return EnterpriseMetrics(
      shop: shop,
      todaySales: todaySales,
      todayTxnCount: todayTxnCount,
      retailRevenue: retailRev,
      restaurantRevenue: restaurantRev,
      servicesRevenue: servicesRev,
      entertainmentRevenue: entertainmentRev,
      lodgingRevenue: lodgingRev,
      pendingOrders: pendingOrders,
      activeSessions: activeSessions,
      activeStays: activeStays,
      todayBookings: todayBookings,
      enabledModules: enabledModules,
    );
  }

  /// Fetch top selling item across all shops today
  static Future<Map<String, dynamic>?> fetchTopItemAcrossShops(List<Shop> shops) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

    final shopIds = shops.map((s) => s.id).toList();

    try {
      final response = await _supabase
          .from('transaction_items')
          .select('inventory_id, quantity, inventory!inner(name)')
          .inFilter('shop_id', shopIds)
          .gte('created_at', todayStart)
          .order('quantity', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        return {
          'name': response.first['inventory']['name'],
          'quantity': response.first['quantity'],
        };
      }
    } catch (e) {
      print('⚠️ Failed to fetch top item: $e');
    }

    return null;
  }

  /// Test cloud connectivity
  static Future<bool> testConnectivity() async {
    try {
      final response = await _supabase
          .from('shops')
          .select('id')
          .limit(1);
      return response.isNotEmpty;
    } catch (e) {
      print('❌ Cloud connectivity test failed: $e');
      return false;
    }
  }
}
