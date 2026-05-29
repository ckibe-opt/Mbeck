import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/shop.dart';
import '../../models/enterprise_metrics.dart';
import '../../widgets/standard_app_bar.dart';
import '../../services/auth_service.dart';
import '../../services/onboarding_service.dart';
import '../../services/supabase_enterprise_service.dart';
import '../../services/revenuecat_service.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../paywall_screen.dart';

class ChainDashboardScreen extends StatefulWidget {
  const ChainDashboardScreen({super.key});

  @override
  State<ChainDashboardScreen> createState() => _ChainDashboardScreenState();
}


class _ChainDashboardScreenState extends State<ChainDashboardScreen> {
  List<EnterpriseMetrics> _shopMetrics = [];
  bool _isLoading = true;
  bool _isCloudMode = false;
  String? _homeShopId;
  String? _errorMessage;

  // Search, sorting, and filtering state
  String _searchQuery = '';
  String _sortBy = 'sales_desc'; // sales_desc, sales_asc, txns_desc, alphabetical, ticket_size_desc
  String _selectedModule = 'all'; // all, retail, restaurant, services, entertainment, lodging

  @override
  void initState() {
    super.initState();
    _checkTierAndFetch();
  }

  int _getGlobalSalesRank(EnterpriseMetrics metric) {
    final sorted = List<EnterpriseMetrics>.from(_shopMetrics);
    sorted.sort((a, b) => b.todaySales.compareTo(a.todaySales));
    for (int i = 0; i < sorted.length; i++) {
      if (sorted[i].shop.id == metric.shop.id) {
        return i + 1;
      }
    }
    return 1;
  }

  List<EnterpriseMetrics> get _filteredAndSortedMetrics {
    var list = List<EnterpriseMetrics>.from(_shopMetrics);
    
    // 1. Filter by search query
    if (_searchQuery.isNotEmpty) {
      list = list.where((m) => m.shop.businessName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    
    // 2. Filter by selected module
    if (_selectedModule != 'all') {
      list = list.where((m) => m.enabledModules.contains(_selectedModule)).toList();
    }
    
    // 3. Sort
    list.sort((a, b) {
      switch (_sortBy) {
        case 'sales_desc':
          return b.todaySales.compareTo(a.todaySales);
        case 'sales_asc':
          return a.todaySales.compareTo(b.todaySales);
        case 'txns_desc':
          return b.todayTxnCount.compareTo(a.todayTxnCount);
        case 'alphabetical':
          return a.shop.businessName.toLowerCase().compareTo(b.shop.businessName.toLowerCase());
        case 'ticket_size_desc':
          final avgA = a.todayTxnCount > 0 ? (a.todaySales / a.todayTxnCount) : 0.0;
          final avgB = b.todayTxnCount > 0 ? (b.todaySales / b.todayTxnCount) : 0.0;
          return avgB.compareTo(avgA);
        default:
          return b.todaySales.compareTo(a.todaySales);
      }
    });
    
    return list;
  }

  Widget _buildModuleTag(String module) {
    Color bg = const Color(0xFFF3F4F6);
    Color text = const Color(0xFF4B5563);
    String label = module.toUpperCase();

    switch (module.toLowerCase()) {
      case 'retail':
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF2563EB);
        label = 'Retail';
        break;
      case 'restaurant':
        bg = const Color(0xFFFFF7ED);
        text = const Color(0xFFEA580C);
        label = 'Restaurant';
        break;
      case 'services':
        bg = const Color(0xFFF3E8FF);
        text = const Color(0xFF7C3AED);
        label = 'Services';
        break;
      case 'entertainment':
        bg = const Color(0xFFEEF2FF);
        text = const Color(0xFF4F46E5);
        label = 'Entertainment';
        break;
      case 'lodging':
        bg = const Color(0xFFF0FDFA);
        text = const Color(0xFF0D9488);
        label = 'Lodging';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Future<void> _checkTierAndFetch() async {
    final shop = await AuthService.getCurrentShop();
    final isEnterpriseSub = await RevenueCatService.isEnterpriseSubscriber();
    final hasEnterpriseAccess = (shop?.isEnterprise ?? false) || (shop?.isOnTrial ?? false) || isEnterpriseSub;

    if (shop != null && !hasEnterpriseAccess) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const PaywallScreen(featureName: 'Enterprise Dashboard'),
          ),
        );
      }
      return;
    }
    _homeShopId = shop?.id;
    
    // Try cloud first, fallback to local
    await _fetchCloudDataWithFallback();
  }

  /// Fetch cloud data with local fallback (smart merge)
  Future<void> _fetchCloudDataWithFallback() async {
    try {
      setState(() => _isLoading = true);
      _errorMessage = null;

      final shops = await AuthService.getUserShops();
      
      // Test cloud connectivity
      final hasCloudConnectivity = await SupabaseEnterpriseService.testConnectivity();
      
      if (hasCloudConnectivity) {
        // Fetch from cloud
        final cloudMetrics = await SupabaseEnterpriseService.fetchEnterpriseMetrics(shops);
        
        // Check if cloud returned meaningful data
        final hasCloudData = cloudMetrics.any((m) => m.todaySales > 0 || m.todayTxnCount > 0);
        
        if (hasCloudData) {
          // Cloud has real data — use it
          if (mounted) {
            setState(() {
              _shopMetrics = cloudMetrics;
              _isCloudMode = true;
              _isLoading = false;
            });
          }
          debugPrint('✅ Enterprise dashboard: Using cloud data for ${shops.length} shops');
        } else {
          // Cloud is reachable but has no data — fill from local
          debugPrint('⚠️ Cloud returned empty metrics, merging with local data');
          await _fetchLocalDataWithCloudFallback(shops, cloudMetrics);
        }
      } else {
        throw Exception('Cloud connectivity failed');
      }
    } catch (e) {
      debugPrint('⚠️ Cloud fetch failed, falling back to local: $e');
      // Fallback to local data
      await _fetchLocalData();
    }
  }

  /// Merge local data into cloud metrics when cloud returns empty
  Future<void> _fetchLocalDataWithCloudFallback(
    List<Shop> shops, List<EnterpriseMetrics> cloudMetrics,
  ) async {
    try {
      final mergedMetrics = <EnterpriseMetrics>[];

      for (int i = 0; i < cloudMetrics.length; i++) {
        final cloud = cloudMetrics[i];
        // If cloud has no data for this shop, try local
        if (cloud.todaySales == 0 && cloud.todayTxnCount == 0) {
          try {
            final localMetrics = await _queryShopMetricsLocal(cloud.shop);
            mergedMetrics.add(localMetrics);
          } catch (_) {
            mergedMetrics.add(cloud);
          }
        } else {
          mergedMetrics.add(cloud);
        }
      }

      // Switch back to home shop's database
      if (_homeShopId != null) {
        await DbProvider.switchToShopDatabase(_homeShopId!);
      }

      if (mounted) {
        setState(() {
          _shopMetrics = mergedMetrics;
          _isCloudMode = false;
          _isLoading = false;
          _errorMessage = 'Using local data — cloud sync pending';
        });
      }
      debugPrint('✅ Enterprise dashboard: Merged local+cloud for ${shops.length} shops');
    } catch (e) {
      debugPrint('❌ Merge failed: $e');
      await _fetchLocalData();
    }
  }

  /// Fetch local data (original method)
  Future<void> _fetchLocalData() async {
    try {
      final shops = await AuthService.getUserShops();
      final metrics = <EnterpriseMetrics>[];

      // Query each shop's database for today's sales
      for (final shop in shops) {
        try {
          final shopMetrics = await _queryShopMetricsLocal(shop);
          metrics.add(shopMetrics);
        } catch (e) {
          debugPrint('⚠️ Failed to fetch local metrics for ${shop.businessName}: $e');
          metrics.add(EnterpriseMetrics(shop: shop));
        }
      }

      // Switch back to home shop's database
      if (_homeShopId != null) {
        await DbProvider.switchToShopDatabase(_homeShopId!);
      }

      if (mounted) {
        setState(() {
          _shopMetrics = metrics;
          _isCloudMode = false;
          _isLoading = false;
          _errorMessage = 'Using local data - Cloud unavailable';
        });
      }
      debugPrint('✅ Enterprise dashboard: Using local data for ${shops.length} shops');
    } catch (e) {
      debugPrint("❌ Error fetching local chain data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load data: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading shops: $e"), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  
  /// Query a specific shop's database for today's metrics (module-aware)
  Future<EnterpriseMetrics> _queryShopMetricsLocal(Shop shop) async {
    await DbProvider.switchToShopDatabase(shop.id);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    // Total sales
    final salesResult = await DbProvider.queryRaw(
      'SELECT COALESCE(SUM(totalAmount), 0) as total, COUNT(id) as count FROM txn WHERE type = ? AND timestamp >= ?',
      ['sale', todayStart],
    );
    double todaySales = 0;
    int todayTxnCount = 0;
    if (salesResult.isNotEmpty) {
      todaySales = (salesResult.first['total'] as num?)?.toDouble() ?? 0;
      todayTxnCount = (salesResult.first['count'] as num?)?.toInt() ?? 0;
    }

    // Top item
    String? topItem;
    try {
      final topItemResult = await DbProvider.queryRaw(
        'SELECT i.name, SUM(ti.quantity) as qty FROM transaction_items ti JOIN txn t ON ti.transactionId = t.id JOIN inventory i ON ti.itemId = i.id WHERE t.type = ? AND t.timestamp >= ? GROUP BY i.name ORDER BY qty DESC LIMIT 1',
        ['sale', todayStart],
      );
      if (topItemResult.isNotEmpty) topItem = topItemResult.first['name'] as String?;
    } catch (_) {}

    // Per-module revenue from txn.source_module
    double retailRev = 0, restaurantRev = 0, servicesRev = 0, entertainmentRev = 0, lodgingRev = 0;
    try {
      final modRevResult = await DbProvider.queryRaw(
        'SELECT source_module, COALESCE(SUM(totalAmount), 0) as rev FROM txn WHERE type = ? AND timestamp >= ? GROUP BY source_module',
        ['sale', todayStart],
      );
      for (final row in modRevResult) {
        final mod = (row['source_module'] as String?) ?? 'retail';
        final rev = (row['rev'] as num?)?.toDouble() ?? 0;
        switch (mod) {
          case 'retail': retailRev = rev; break;
          case 'restaurant': restaurantRev = rev; break;
          case 'services': servicesRev = rev; break;
          case 'entertainment': entertainmentRev = rev; break;
          case 'lodging': lodgingRev = rev; break;
        }
      }
    } catch (_) {}

    // Active counts
    int pendingOrders = 0, activeSessions = 0, activeStays = 0, todayBookings = 0;
    try {
      final ordersResult = await DbProvider.queryRaw(
        "SELECT COUNT(*) as cnt FROM restaurant_orders WHERE status IN ('pending', 'preparing')", [],
      );
      pendingOrders = (ordersResult.firstOrNull?['cnt'] as int?) ?? 0;
    } catch (_) {}
    try {
      final sessResult = await DbProvider.queryRaw(
        "SELECT COUNT(*) as cnt FROM entertainment_sessions WHERE status = 'active'", [],
      );
      activeSessions = (sessResult.firstOrNull?['cnt'] as int?) ?? 0;
    } catch (_) {}
    try {
      final staysResult = await DbProvider.queryRaw(
        "SELECT COUNT(*) as cnt FROM lodging_reservations WHERE status = 'checked_in'", [],
      );
      activeStays = (staysResult.firstOrNull?['cnt'] as int?) ?? 0;
    } catch (_) {}
    try {
      final bookResult = await DbProvider.queryRaw(
        "SELECT COUNT(*) as cnt FROM services_bookings WHERE start_time >= ?",
        [todayStart],
      );
      todayBookings = (bookResult.firstOrNull?['cnt'] as int?) ?? 0;
    } catch (_) {}

    // Detect enabled modules from settings
    List<String> enabledModules = ['retail'];
    try {
      enabledModules = await OnboardingService.getSelectedModules();
    } catch (_) {}

    return EnterpriseMetrics(
      shop: shop,
      todaySales: todaySales,
      todayTxnCount: todayTxnCount,
      topItem: topItem,
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

  double get _totalDailySales =>
      _shopMetrics.fold(0.0, (sum, m) => sum + m.todaySales);

  int get _totalTxnCount =>
      _shopMetrics.fold(0, (sum, m) => sum + m.todayTxnCount);

  List<EnterpriseMetrics> get _leaderboard {
    final sorted = List<EnterpriseMetrics>.from(_shopMetrics);
    sorted.sort((a, b) => b.todaySales.compareTo(a.todaySales));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: StandardAppBar(
        title: "Enterprise Dashboard",
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business),
            tooltip: 'Create New Branch',
            onPressed: () {
              Navigator.of(context).pushNamed('/signup', arguments: {'isCreatingBranch': true});
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCloudDataWithFallback,
        child: Column(
          children: [
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: _isCloudMode ? Colors.green.shade50 : Colors.orange.shade50,
                child: Row(
                  children: [
                    Icon(
                      _isCloudMode ? Icons.cloud_done : Icons.cloud_off,
                      color: _isCloudMode ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: _isCloudMode ? Colors.green.shade800 : Colors.orange.shade800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (!_isCloudMode)
                      TextButton(
                        onPressed: _fetchCloudDataWithFallback,
                        child: const Text('Retry Cloud'),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _shopMetrics.isEmpty
                      ? _buildEmptyState()
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildHeroMetricCard(),
                            const SizedBox(height: 24),
                            _buildNativeRevenueBarChart(),
                            const SizedBox(height: 24),
                            _buildTrendingStrip(),
                            const SizedBox(height: 24),
                            _buildSearchAndFilters(),
                            const SizedBox(height: 32),
                            _buildSectionHeader(),
                            const SizedBox(height: 16),
                            ..._filteredAndSortedMetrics.map((metrics) {
                              return _buildRankedShopCard(metrics);
                            }),
                            const SizedBox(height: 40),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 64, color: AppColors.gray400),
          const SizedBox(height: 16),
          Text("No shops found", style: AppTypography.textTheme.titleMedium),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/signup', arguments: {'isCreatingBranch': true}),
            child: const Text("Create Your First Shop"),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.01),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by branch name...',
                    hintStyle: const TextStyle(color: AppColors.gray400, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: AppColors.gray400, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.gray400, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.sort, color: AppColors.gray600),
                tooltip: 'Sort Branches',
                onSelected: (value) {
                  setState(() {
                    _sortBy = value;
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'sales_desc',
                    child: Text('Sales: High to Low'),
                  ),
                  const PopupMenuItem(
                    value: 'sales_asc',
                    child: Text('Sales: Low to High'),
                  ),
                  const PopupMenuItem(
                    value: 'txns_desc',
                    child: Text('Transactions: High to Low'),
                  ),
                  const PopupMenuItem(
                    value: 'alphabetical',
                    child: Text('Alphabetical (A-Z)'),
                  ),
                  const PopupMenuItem(
                    value: 'ticket_size_desc',
                    child: Text('Avg. Ticket Size: High to Low'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip('all', 'All Modules'),
              _buildFilterChip('retail', 'Retail'),
              _buildFilterChip('restaurant', 'Restaurant'),
              _buildFilterChip('services', 'Services'),
              _buildFilterChip('entertainment', 'Entertainment'),
              _buildFilterChip('lodging', 'Lodging'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedModule == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedModule = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade200,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primaryGreen.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.gray600,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroMetricCard() {
    final formatter = NumberFormat('#,##0.00');
    final activeShops = _shopMetrics.where((m) => m.hasActivity || m.todaySales > 0).length;

    // Detect bottlenecks globally
    final totalPendingOrders = _shopMetrics.fold(0, (sum, m) => sum + m.pendingOrders);
    final zeroSalesBranches = _shopMetrics.where((m) => m.todaySales == 0).length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  "TODAY'S GLOBAL REVENUE",
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  "KES ${formatter.format(_totalDailySales)}",
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHeroBadge("$activeShops / ${_shopMetrics.length} Active", Icons.storefront, Colors.blueAccent),
                    const SizedBox(width: 12),
                    _buildHeroBadge("$_totalTxnCount Transactions", Icons.receipt_long, Colors.greenAccent),
                  ],
                ),
              ],
            ),
          ),
          if (totalPendingOrders > 0 || zeroSalesBranches > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (totalPendingOrders > 0)
                      _buildAlertChip("🔥 $totalPendingOrders Orders Pending Network-wide", Colors.orange),
                    if (totalPendingOrders > 0 && zeroSalesBranches > 0) const SizedBox(width: 8),
                    if (zeroSalesBranches > 0)
                      _buildAlertChip("⚠️ $zeroSalesBranches Branches have zero sales", Colors.redAccent),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildAlertChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildNativeRevenueBarChart() {
    double retail = 0, rest = 0, serv = 0, ent = 0, lodg = 0;
    for (final m in _shopMetrics) {
      retail += m.retailRevenue;
      rest += m.restaurantRevenue;
      serv += m.servicesRevenue;
      ent += m.entertainmentRevenue;
      lodg += m.lodgingRevenue;
    }
    final total = retail + rest + serv + ent + lodg;
    if (total == 0) return const SizedBox.shrink();

    final formatter = NumberFormat.compact();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Module Contribution", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 24,
            width: double.infinity,
            color: Colors.grey.shade200,
            child: Row(
              children: [
                if (rest > 0) Expanded(flex: (rest / total * 100).toInt(), child: Container(color: Colors.deepOrange)),
                if (retail > 0) Expanded(flex: (retail / total * 100).toInt(), child: Container(color: Colors.blue)),
                if (lodg > 0) Expanded(flex: (lodg / total * 100).toInt(), child: Container(color: Colors.teal)),
                if (serv > 0) Expanded(flex: (serv / total * 100).toInt(), child: Container(color: Colors.purple)),
                if (ent > 0) Expanded(flex: (ent / total * 100).toInt(), child: Container(color: Colors.indigo)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12, runSpacing: 8,
          children: [
            if (rest > 0) _buildLegendItem("Restaurant", rest, Colors.deepOrange, formatter),
            if (retail > 0) _buildLegendItem("Retail", retail, Colors.blue, formatter),
            if (lodg > 0) _buildLegendItem("Lodging", lodg, Colors.teal, formatter),
            if (serv > 0) _buildLegendItem("Services", serv, Colors.purple, formatter),
            if (ent > 0) _buildLegendItem("Entertainment", ent, Colors.indigo, formatter),
          ],
        )
      ],
    );
  }

  Widget _buildLegendItem(String label, double value, Color color, NumberFormat fmt) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
        const SizedBox(width: 4),
        Text(fmt.format(value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
      ],
    );
  }

  Widget _buildTrendingStrip() {
    final topItems = _shopMetrics.where((m) => m.topItem != null && m.topItem!.isNotEmpty).map((m) => m.topItem!).toSet().toList();
    if (topItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Trending Across Branches", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: topItems.map((item) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(item, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey.shade200),
                avatar: const Icon(Icons.trending_up, size: 14, color: AppColors.primaryGreen),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader([String title = "Branch Leaderboard"]) {
    String sortText = "Ranked by Sales";
    if (_sortBy == 'sales_asc') sortText = "Sales: Low to High";
    else if (_sortBy == 'txns_desc') sortText = "Ranked by Txns";
    else if (_sortBy == 'alphabetical') sortText = "Sorted Alphabetically";
    else if (_sortBy == 'ticket_size_desc') sortText = "Sorted by Avg. Ticket";

    return Row(
      children: [
        Text(title, style: AppTypography.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
          child: Text(sortText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5))),
        ),
      ],
    );
  }

  Widget _buildRankedShopCard(EnterpriseMetrics metrics) {
    final rank = _getGlobalSalesRank(metrics);
    final formatter = NumberFormat('#,##0');
    final isHome = metrics.shop.id == _homeShopId;
    
    Color rankColor = const Color(0xFF9CA3AF);
    if (rank == 1 && metrics.todaySales > 0) rankColor = const Color(0xFFFFD700);
    else if (rank == 2 && metrics.todaySales > 0) rankColor = const Color(0xFF94A3B8);
    else if (rank == 3 && metrics.todaySales > 0) rankColor = const Color(0xFFD97706);

    final avgTicket = metrics.todayTxnCount > 0 ? (metrics.todaySales / metrics.todayTxnCount) : 0.0;

    return TapScaleContainer(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHome ? const Color(0xFF10B981) : const Color(0xFFF3F4F6),
          width: isHome ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      onTap: () => _showBranchScorecardSheet(metrics, isHome),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: rankColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: rankColor.withOpacity(0.3), width: 1.5),
              ),
              child: Center(
                child: Text(
                  "#$rank",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: rankColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Branch details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          metrics.shop.businessName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (metrics.pendingOrders > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Pending",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Module tags
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: metrics.enabledModules.map((m) => _buildModuleTag(m)).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${metrics.todayTxnCount} Txns • Avg Ticket: KES ${formatter.format(avgTicket)}",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Sales details
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "KES ${formatter.format(metrics.todaySales)}",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                  ),
                ),
                if (isHome) ...[
                  const SizedBox(height: 2),
                  const Text(
                    "Current Branch",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBranchScorecardSheet(EnterpriseMetrics m, bool isHome) {
    final fmt = NumberFormat('#,##0.00');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.shop.businessName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text("Branch Scorecard", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("KES ${fmt.format(m.todaySales)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryGreen)),
                      Text("${m.todayTxnCount} Txns Today", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Metrics grid
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                _buildScoreCard("Avg. Ticket", "KES ${fmt.format(m.todayTxnCount > 0 ? m.todaySales / m.todayTxnCount : 0.0)}", Icons.receipt_long, Colors.green),
                if (m.pendingOrders > 0) _buildScoreCard("Pending Orders", m.pendingOrders.toString(), Icons.timer, Colors.orange),
                if (m.topItem != null) _buildScoreCard("Top Item", m.topItem!, Icons.star, Colors.blue),
                if (m.activeSessions > 0) _buildScoreCard("Active Sessions", m.activeSessions.toString(), Icons.videogame_asset, Colors.indigo),
                if (m.activeStays > 0) _buildScoreCard("Active Guests", m.activeStays.toString(), Icons.hotel, Colors.teal),
                if (m.todayBookings > 0) _buildScoreCard("Bookings", m.todayBookings.toString(), Icons.book_online, Colors.purple),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _switchToShop(m.shop, isHome);
              },
              icon: const Icon(Icons.login),
              label: Text(isHome ? "You are already here" : "Login & Switch to this Branch"),
              style: ElevatedButton.styleFrom(
                backgroundColor: isHome ? Colors.grey : AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: (MediaQuery.of(context).size.width - 48 - 12) / 2, // Half width minus padding
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey.shade900), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Future<void> _switchToShop(Shop shop, bool isHome) async {
    try {
      await AuthService.selectShop(shop.id);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isHome
                  ? "Switched to ${shop.businessName}"
                  : "Viewing ${shop.businessName} (Read-Only)",
            ),
            backgroundColor: isHome ? AppColors.success : AppColors.info,
          ),
        );

        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to switch shop: $e"), backgroundColor: AppColors.danger),
        );
      }
    }
  }
}

class TapScaleContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Decoration? decoration;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const TapScaleContainer({
    super.key,
    required this.child,
    required this.onTap,
    this.decoration,
    this.margin,
    this.padding,
  });

  @override
  State<TapScaleContainer> createState() => _TapScaleContainerState();
}

class _TapScaleContainerState extends State<TapScaleContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: widget.margin,
          padding: widget.padding,
          decoration: widget.decoration,
          child: widget.child,
        ),
      ),
    );
  }
}
