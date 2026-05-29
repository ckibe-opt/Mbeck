import 'dart:async';
import 'package:flutter/material.dart';
import 'lodging/lodging_rates_screen.dart';
import 'lodging/lodging_folios_screen.dart';
import 'lodging/lodging_groups_screen.dart';
import 'lodging/lodging_channel_logs_screen.dart';
import 'package:intl/intl.dart';
import '../db/db_provider.dart';
import '../theme/design_system.dart';
import 'expense_screen.dart';
import 'income_screen.dart';
import 'new_transaction_screen.dart';
import 'transactions_list_screen.dart';
import 'inventory_screen.dart';
import 'retail/returns_screen.dart';
import 'retail/suppliers_screen.dart';
import 'retail/promotions_screen.dart';
import 'retail/stock_audit_screen.dart';
import 'reports_screen.dart';
import 'customers_screen.dart';
import 'accounting_screen.dart';
import 'settings_screen.dart';
import 'credit_screen.dart';
import 'loans_screen.dart';
import 'profits_screen.dart';
import 'cash_count_screen.dart';
import 'restock_analysis_screen.dart';
import 'paywall_screen.dart';
import 'subscription/pricing_screen.dart';
import 'receipt_verification_screen.dart';
import 'restaurant/menu_management_screen.dart';
import 'restaurant/order_queue_screen.dart';
import 'restaurant/restaurant_pos_screen.dart';
import 'restaurant/restaurant_recipes_screen.dart';
import 'services/service_catalog_screen.dart';
import 'services/bookings_calendar_screen.dart';
import 'services/service_rooms_screen.dart';
import 'services/service_buffers_screen.dart';
import 'services/service_addons_screen.dart';
import 'services/service_recurring_screen.dart';
import 'supplies_screen.dart';
import 'entertainment/sessions_dashboard_screen.dart';
import 'entertainment/asset_management_screen.dart';
import 'entertainment/entertainment_prepaid_screen.dart';
import 'entertainment/entertainment_tabs_screen.dart';
import 'entertainment/entertainment_pause_screen.dart';
import 'entertainment/entertainment_pricing_screen.dart';
import 'lodging/reservations_dashboard_screen.dart';
import 'lodging/room_management_screen.dart';
import 'restaurant/waiter_rings_screen.dart';
import 'restaurant/floor_plan_editor_screen.dart';
import 'restaurant/live_table_map_screen.dart';
import 'restaurant/restaurant_inventory_screen.dart';
import 'services/staff_management_screen.dart';
import 'services/shift_scheduling_screen.dart';
import 'lan_sync_diagnostic_screen.dart';
import 'placeholder_feature_screen.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/server_status_widget.dart';
import '../models/permissions.dart';
import '../widgets/permission_guard.dart';
import '../widgets/standard_app_bar.dart';
import '../services/auth_service.dart';
import '../widgets/trust_score_widget.dart'; // Phase 4 Extension

import '../widgets/demand_pulse_card.dart'; // Phase 4: Analytics
import '../services/onboarding_service.dart'; // Module-aware navigation
import '../services/module_scope.dart';
import '../services/initial_cloud_sync_service.dart';
import '../services/lan_peer_manager.dart';
import '../services/event_processor.dart';
import '../services/background_shop_service.dart';
import '../widgets/interactive_help_scroll.dart';
import '../services/revenuecat_service.dart';
import 'buyer_inbox_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<_NavItem> _navItems = [];
  List<Widget> _screens = [];
  bool _isLoading = true;
  List<String> _enabledModules = [];
  Timer? _notificationTimer;
  int _unreadMessages = 0;
  Timer? _inboxTimer;

  @override
  void initState() {
    super.initState();
    _loadModuleAwareNavigation();
    _checkAndPerformInitialSync();
    _startLanSync();
    _pollUnreadMessages();
    _inboxTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollUnreadMessages());
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _inboxTimer?.cancel();
    super.dispose();
  }

  Future<void> _startLanSync() async {
    try {
      debugPrint('🔌 Starting LAN Peer Manager...');
      await LanPeerManager.instance.start();

      // Periodically update foreground notification with peer count
      _notificationTimer?.cancel();
      _updateSyncNotification(); // Immediate first update
      _notificationTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _updateSyncNotification(),
      );
    } catch (e) {
      debugPrint('❌ Failed to start LAN Sync: $e');
    }
  }

  void _updateSyncNotification() {
    final peerCount = LanPeerManager.instance.connectedPeerCount;
    final peerText = peerCount == 0
        ? 'No other devices connected'
        : 'Syncing with $peerCount device${peerCount == 1 ? '' : 's'}';
    BackgroundShopService.updateNotification(
      title: 'Mbeck POS — LAN Sync Active',
      content: peerText,
    );
  }

  Future<void> _pollUnreadMessages() async {
    try {
      final db = await DbProvider.db;
      final result = await db.rawQuery(
        "SELECT COUNT(*) AS cnt FROM messages WHERE sender = 'buyer' AND read = 0",
      );
      final count = (result.first['cnt'] as num?)?.toInt() ?? 0;
      if (mounted && count != _unreadMessages) {
        setState(() => _unreadMessages = count);
      }
    } catch (_) {}
  }

  /// Check if this is a new device and perform initial sync if needed
  Future<void> _checkAndPerformInitialSync() async {
    try {
      // Check if this device has any local data
      final inventory = await DbProvider.query('inventory', limit: 1);
      final orders = await DbProvider.query('restaurant_orders', limit: 1);
      
      // If device has no data, it's likely a new installation
      if (inventory.isEmpty && orders.isEmpty) {
        debugPrint('🆕 New device detected, performing initial cloud sync...');
        
        // Wait a bit for the app to fully initialize
        await Future.delayed(const Duration(seconds: 2));
        
        // Perform initial sync from cloud
        await InitialCloudSyncService.performInitialSync();
        
        debugPrint('✅ Initial sync completed for new device');
        
        // Refresh the UI to show new data
        if (mounted) {
          _loadModuleAwareNavigation();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Initial sync check failed: $e');
      // Don't show error to user - this is non-critical
    }
  }

  Future<void> _loadModuleAwareNavigation() async {
    final modules = await OnboardingService.getSelectedModules();
    _enabledModules = modules;
    
    final items = <_NavItem>[];
    final screens = <Widget>[];
    
    // Fixed 3-tab navigation
    items.add(const _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Home',
    ));
    screens.add(const DashboardScreen());
    
    items.add(const _NavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      label: 'History',
    ));
    screens.add(TransactionsListScreen());
    
    items.add(const _NavItem(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
      label: 'Reports',
    ));
    screens.add(ReportsScreen());
    
    if (mounted) {
      setState(() {
        _navItems = items;
        _screens = screens;
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showAddTransactionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final actions = <Widget>[
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text('Quick Actions', style: AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
        ];

        // RETAIL: New Sale
        if (_enabledModules.contains('retail')) {
          actions.add(ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.primaryGreen.withOpacity(0.1), child: const Icon(Icons.add_shopping_cart, color: AppColors.primaryGreen)),
            title: const Text('New Sale'),
            subtitle: const Text('Sell items from inventory'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NewTransactionScreen(autoStartScanner: false))).then((_) => _refreshDashboard());
            },
          ));
        }

        // RESTAURANT: New Order
        if (_enabledModules.contains('restaurant')) {
          actions.add(ListTile(
            leading: CircleAvatar(backgroundColor: Colors.deepOrange.withOpacity(0.1), child: const Icon(Icons.restaurant, color: Colors.deepOrange)),
            title: const Text('New Order'),
            subtitle: const Text('Create a restaurant order'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantPosScreen())).then((_) => _refreshDashboard());
            },
          ));
        }

        // SERVICES: New Booking
        if (_enabledModules.contains('services')) {
          actions.add(ListTile(
            leading: CircleAvatar(backgroundColor: Colors.purple.withOpacity(0.1), child: const Icon(Icons.event_available, color: Colors.purple)),
            title: const Text('New Booking'),
            subtitle: const Text('Schedule a service appointment'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingsCalendarScreen())).then((_) => _refreshDashboard());
            },
          ));
        }

        // ENTERTAINMENT: Start Session
        if (_enabledModules.contains('entertainment')) {
          actions.add(ListTile(
            leading: CircleAvatar(backgroundColor: Colors.indigo.withOpacity(0.1), child: const Icon(Icons.sports_esports, color: Colors.indigo)),
            title: const Text('Start Session'),
            subtitle: const Text('Start an entertainment session'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionsDashboardScreen())).then((_) => _refreshDashboard());
            },
          ));
        }

        // LODGING: New Reservation
        if (_enabledModules.contains('lodging')) {
          actions.add(ListTile(
            leading: CircleAvatar(backgroundColor: Colors.teal.withOpacity(0.1), child: const Icon(Icons.hotel, color: Colors.teal)),
            title: const Text('New Reservation'),
            subtitle: const Text('Book a room for a guest'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReservationsDashboardScreen())).then((_) => _refreshDashboard());
            },
          ));
        }

        // Always: Income / Expense
        actions.addAll([
          const Divider(height: 1),
          ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.success.withOpacity(0.1), child: const Icon(Icons.arrow_downward, color: AppColors.success)),
            title: const Text('Record Income'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const IncomeScreen())).then((_) => _refreshDashboard());
            },
          ),
          ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.danger.withOpacity(0.1), child: const Icon(Icons.arrow_upward, color: AppColors.danger)),
            title: const Text('Record Expense'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseScreen())).then((_) => _refreshDashboard());
            },
          ),
        ]);

        return Wrap(children: actions);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surfaceWhite,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: AppColors.gray400,
        selectedLabelStyle: AppTypography.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.textTheme.labelMedium,
        items: _navItems.map((item) => BottomNavigationBarItem(
          icon: Icon(item.icon),
          activeIcon: Icon(item.activeIcon),
          label: item.label,
        )).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "home_fab",
        onPressed: _showAddTransactionSheet,
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _refreshDashboard() {
    // Find the DashboardScreen state and call its refresh method
    final state = context.findAncestorStateOfType<_DashboardScreenState>();
    state?._refresh();
  }
}

/// Navigation item model for dynamic nav bar
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int todaysItemsSold = 0;
  double todaysSalesTotal = 0.0;
  List<Map<String, dynamic>> _recentTransactions = [];
  String _shopName = '';
  double _trustScore = 0.0;
  List<String> _enabledModules = [];
  String _activeModule = ''; // Module switcher state
  bool _isDashboardLoading = true;
  late PageController _pageController;
  int _unreadMessages = 0;
  Timer? _inboxPollTimer;

  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initDashboard();
    _pollUnreadMessages();
    _inboxPollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollUnreadMessages());
    
    // Listen for remote events (LAN/Cloud) and refresh UI
    _eventSubscription = EventProcessor.events.listen((eventType) {
      if (mounted) {
        debugPrint('🔄 Dashboard: Received event $eventType, refreshing...');
        _refresh();
      }
    });
  }

  /// Load all dashboard data before showing content.
  Future<void> _initDashboard() async {
    final modules = await OnboardingService.getSelectedModules();
    _enabledModules = modules;
    _activeModule = modules.isNotEmpty ? modules.first : '';
    debugPrint('🏠 Dashboard: Active modules = $modules');
    
    await _loadShopInfo();
    await _loadSummary();
    await _loadRecentTransactions();
    
    if (mounted) {
      setState(() {
        _isDashboardLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _inboxPollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _refresh() {
    _loadSummary();
    _loadRecentTransactions();
    _loadShopInfo();
    _pollUnreadMessages();
  }

  /// Opens the inbox only for PRO/ENTERPRISE subscribers.
  /// Free users see the PaywallScreen instead.
  Future<void> _openInbox() async {
    final isPro = await RevenueCatService.isProSubscriber();
    final shop = await AuthService.getCurrentShop();
    
    if (!mounted) return;
    
    // Check RevenueCat OR local DB shop tier (handles Enterprise & custom billing)
    if (!isPro && !(shop?.hasProAccess ?? false)) {
      PaywallScreen.show(context, featureName: 'Buyer Inbox & Messaging');
      return;
    }
    _navigateTo(const BuyerInboxScreen());
  }

  Future<void> _pollUnreadMessages() async {
    try {
      final db = await DbProvider.db;
      final result = await db.rawQuery(
        "SELECT COUNT(*) AS cnt FROM messages WHERE sender = 'buyer' AND read = 0",
      );
      final count = (result.first['cnt'] as num?)?.toInt() ?? 0;
      if (mounted && count != _unreadMessages) {
        setState(() => _unreadMessages = count);
      }
    } catch (_) {}
  }

  Future<void> _loadShopInfo() async {
    final shop = await AuthService.getCurrentShop();
    if (mounted && shop != null) {
      _shopName = shop.businessName;
      _trustScore = shop.trustScore;
    }
  }

  Future<void> _loadRecentTransactions() async {
    try {
      final scope = await ModuleScope.current();
      final txns = await DbProvider.queryRaw(
        'SELECT * FROM txn WHERE ${scope.txnWhere} ORDER BY timestamp DESC LIMIT 5',
        scope.moduleArgs,
      );
      if (mounted) {
        setState(() {
          _recentTransactions = txns.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading recent transactions: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading recent transactions.")));
      }
    }
  }

  Future<void> _loadSummary() async {
    // Add a micro-delay to let the UI settle before heavy queries
    await Future.delayed(const Duration(milliseconds: 100));
    
    final now = DateTime.now();
    // Calculate start of day in LOCAL time then convert to epoch
    final localStartOfDay = DateTime(now.year, now.month, now.day);
    final startOfDay = localStartOfDay.millisecondsSinceEpoch;

    final scope = await ModuleScope.current();
    debugPrint('🔍 Dashboard: Querying sales. ModuleScope: ${scope.moduleArgs} (where: ${scope.txnWhere})');
    
    final rows = await DbProvider.queryRaw(
      'SELECT * FROM txn WHERE timestamp >= ? AND type = ? AND ${scope.txnWhere}',
      [startOfDay, 'sale', ...scope.moduleArgs],
    );

    debugPrint('🔍 Dashboard: Found ${rows.length} sales today.');

    // Sum up the raw cent values - DO NOT normalize here
    double total = 0;
    for (final r in rows) {
      debugPrint('   -> Sale: ${r['totalAmount']} (Module: ${r['source_module']})');
      total += (r['totalAmount'] as num? ?? 0.0);
    }
    
    // Check total txn count for debugging
    final allTxns = await DbProvider.query('txn');
    debugPrint('🔍 DEBUG: Total ${allTxns.length} txns in DB (unfiltered).');

    if (mounted) {
      setState(() {
        todaysItemsSold = rows.length;
        // Store the raw total in cents - AnimatedMetricCard will handle formatting
        todaysSalesTotal = total;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDashboardLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
            // ── Fixed Header (never duplicated) ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Branding + Settings
                  Row(
                    children: [
                      Text(
                        'Mbeck Business',
                        style: AppTypography.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.gray900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        ' .',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: AppColors.gray100,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: Icon(Icons.settings_outlined, size: 16, color: AppColors.gray600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Inbox badge
                      Material(
                        color: _unreadMessages > 0 ? AppColors.danger.withOpacity(0.1) : AppColors.gray100,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _openInbox()
                          .then((_) => _pollUnreadMessages()),
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(Icons.inbox_outlined, size: 16,
                                    color: _unreadMessages > 0 ? AppColors.danger : AppColors.gray600),
                                if (_unreadMessages > 0)
                                  Positioned(
                                    top: -4, right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: AppColors.danger,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '$_unreadMessages',
                                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Shop name
                  if (_shopName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _shopName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: AppColors.gray400,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Networking & Sync Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                      // 1. LAN Sync Indicator
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LANSyncDiagnosticScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.gray200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: LanPeerManager.instance.connectedPeerCount > 0
                                      ? AppColors.primaryGreen
                                      : AppColors.gray400,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'LAN',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gray600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 2. Server Status (Online/Offline)
                      const ServerStatusWidget(),
                      const SizedBox(width: 8),
                      // 3. Cloud Push
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gray200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const SyncStatusIndicator(color: AppColors.gray600),
                      ),
                    ],
                  ),
                  ),
                  if (_enabledModules.length > 1) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _enabledModules.map((mod) {
                          final isActive = mod == _activeModule;
                          final modColor = _moduleColor(mod);
                          final modLabel = _moduleLabel(mod);
                          final modIcon = _moduleIcon(mod);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _activeModule = mod);
                                if (_pageController.hasClients) {
                                  _pageController.animateToPage(
                                    _enabledModules.indexOf(mod),
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                                _refresh();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isActive ? modColor : modColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: isActive ? [BoxShadow(color: modColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))] : [],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(modIcon, size: 14, color: isActive ? Colors.white : modColor),
                                    const SizedBox(width: 5),
                                    Text(
                                      modLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: isActive ? Colors.white : modColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Swipeable Body (or single scrollable body) ──
            Expanded(
              child: _enabledModules.length > 1
                  ? PageView.builder(
                      controller: _pageController,
                      itemCount: _enabledModules.length,
                      onPageChanged: (index) {
                        final newModule = _enabledModules[index];
                        if (_activeModule != newModule) {
                          setState(() => _activeModule = newModule);
                          _refresh();
                        }
                      },
                      itemBuilder: (context, index) {
                        return _buildBodyContent();
                      },
                    )
                  : _buildBodyContent(),
            ),
          ],
        ),
            InteractiveHelpScroll(contextKey: _activeModule),
          ],
        ),
      ),
    );
  }

  /// Scrollable body content (metrics, grid, transactions).
  /// Lives inside each PageView page or standalone when single module.
  Widget _buildBodyContent() {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      color: AppColors.primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DemandPulseCard(),
              const SizedBox(height: 16),

              // Trust Score card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.gray100),
                  boxShadow: const [AppShadows.sm],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: TrustScoreWidget(score: _trustScore, size: 28),
                  title: Text('Trust Score & Capital', style: AppTypography.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Text('View your reputation and loan limits', style: TextStyle(fontSize: 12, color: AppColors.gray500)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.gray400),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreditScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildPerformanceSection(),
              const SizedBox(height: 24),
              _buildOperationsGrid(),
              const SizedBox(height: 24),
              _buildRecentTransactions(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: color ?? AppColors.gray500,
        ),
      ),
    );
  }

  Widget _buildPerformanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Today's Pulse"),
        Row(
          children: [
            // Revenue gradient card
            Expanded(
              child: PermissionGuard(
                permission: Permissions.viewProfitMargins,
                fallback: Container(
                  height: 112,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    border: Border.all(color: AppColors.gray300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.lock_outline, color: AppColors.gray400, size: 24),
                      Text('Restricted', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray400)),
                    ],
                  ),
                ),
                child: Container(
                  height: 112,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF16A34A), Color(0xFF0D9488)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.monetization_on_outlined, size: 16, color: Colors.green.shade200),
                          const SizedBox(width: 6),
                          Text(
                            'REVENUE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Colors.green.shade200,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('KES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade200)),
                          const SizedBox(height: 2),
                          AnimatedMetricCard(
                            label: '',
                            value: todaysSalesTotal,
                            icon: Icons.attach_money,
                            color: Colors.white,
                            isCurrency: true,
                            compact: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Items Sold card
            Expanded(
              child: Container(
                height: 112,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.gray100),
                  boxShadow: const [AppShadows.sm],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 16, color: AppColors.gray400),
                        const SizedBox(width: 6),
                        Text(
                          'SOLD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                    AnimatedMetricCard(
                      label: '',
                      value: todaysItemsSold.toDouble(),
                      icon: Icons.shopping_bag_outlined,
                      color: AppColors.gray900,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOperationsGrid() {
    // ── Core cards (always visible) ──
    final List<Widget> coreCards = [
      _buildActionCard('Customers', Icons.people_outline, AppColors.info,
          () => _navigateTo(const CustomersScreen())),
      PermissionGuard(
        permission: Permissions.manageAccounting,
        fallback: _buildLockedCard('Accounting', Icons.account_balance_wallet_outlined, AppColors.warning),
        child: _buildActionCard('Accounting', Icons.account_balance_wallet_outlined,
            AppColors.warning, () => _navigateTo(AccountingScreen())),
      ),
      PermissionGuard(
        permission: Permissions.manageAccounting,
        fallback: _buildLockedCard('Cash', Icons.calculate_outlined, AppColors.primaryGreen),
        child: _buildActionCard('Cash', Icons.calculate_outlined,
            AppColors.primaryGreen, () => _navigateTo(CashCountScreen())),
      ),
      _buildActionCard('Verify', Icons.verified_user_outlined, AppColors.primaryGreen,
          () => _navigateTo(const ReceiptVerificationScreen())),
      _buildActionCard('Inbox', Icons.inbox_outlined, AppColors.info,
          () => _openInbox()),
    ];

    // ── Module-scoped cards (based on _activeModule) ──
    final List<Widget> moduleCards = _buildModuleCards();

    // ── More / utility cards ──
    final List<Widget> moreCards = [
      PermissionGuard(
        permission: Permissions.viewProfitMargins,
        fallback: _buildLockedCard('Trust', Icons.verified_outlined, AppColors.success),
        child: _buildActionCard('Trust', Icons.verified_outlined,
            AppColors.success, () => _navigateTo(const CreditScreen())),
      ),
      PermissionGuard(
        permission: Permissions.viewProfitMargins,
        fallback: _buildLockedCard('Loans', Icons.monetization_on_outlined, AppColors.primaryLight),
        child: _buildActionCard('Loans', Icons.monetization_on_outlined,
            AppColors.primaryLight, () => _navigateTo(const LoansScreen())),
      ),
      _buildActionCard('Plans', Icons.workspace_premium, Colors.deepPurple,
          () => _navigateTo(const PricingScreen())),
    ];

    final moduleTitle = '${_moduleLabel(_activeModule)} Tools';
    final moduleColor = _moduleColor(_activeModule);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Core section
        _buildSectionHeader('Core'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
          children: coreCards,
        ),
        // Module-scoped section
        if (moduleCards.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSectionHeader(moduleTitle.toUpperCase(), color: moduleColor),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
            children: moduleCards,
          ),
        ],
        if (moduleCards.isEmpty && _activeModule.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSectionHeader(moduleTitle.toUpperCase(), color: moduleColor),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.gray400),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No specialized tools yet. Use the + button to create transactions.',
                    style: TextStyle(fontSize: 12, color: AppColors.gray500, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
        // More section
        const SizedBox(height: 20),
        _buildSectionHeader('More'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
          children: moreCards,
        ),
      ],
    );
  }

  /// Returns cards for the currently active module
  List<Widget> _buildModuleCards() {
    switch (_activeModule) {
      case 'retail':
        return [
          _buildActionCard('Stock', Icons.inventory_2_outlined, AppColors.gray700,
              () => _navigateTo(InventoryScreen())),
          PermissionGuard(
            permission: Permissions.viewProfitMargins,
            fallback: _buildLockedCard('Restock', Icons.inventory, Colors.orange),
            child: _buildActionCard('Restock', Icons.inventory,
                Colors.orange, () => _navigateTo(const RestockAnalysisScreen())),
          ),
          PermissionGuard(
            permission: Permissions.viewProfitMargins,
            fallback: _buildLockedCard('Profits', Icons.trending_up, AppColors.success),
            child: _buildActionCard('Profits', Icons.trending_up,
                AppColors.success, () => _navigateTo(ProfitsScreen())),
          ),
          _buildActionCard('Returns', Icons.assignment_return_outlined, Colors.deepOrange,
              () => _navigateTo(const ReturnsScreen())),
          _buildActionCard('Suppliers', Icons.local_shipping_outlined, Colors.indigo,
              () => _navigateTo(const SuppliersScreen())),
          _buildActionCard('Promos', Icons.local_offer_outlined, Colors.purple,
              () => _navigateTo(const PromotionsScreen())),
          _buildActionCard('Stock Audit', Icons.fact_check_outlined, Colors.teal,
              () => _navigateTo(const StockAuditScreen())),
        ];
      case 'restaurant':
        return [
          _buildActionCard('Menu', Icons.menu_book, Colors.deepOrange,
              () => _navigateTo(const MenuManagementScreen())),
          _buildActionCard('Recipes', Icons.egg_alt_outlined, Colors.brown,
              () => _navigateTo(const RestaurantRecipesScreen())),
          _buildActionCard('Kitchen\nStock', Icons.kitchen, Colors.blueGrey,
              () => _navigateTo(const RestaurantInventoryScreen())),
          _buildActionCard('Orders', Icons.receipt_long, Colors.teal,
              () => _navigateTo(const OrderQueueScreen())),
          _buildActionCard('Table Map', Icons.map_outlined, const Color(0xFF0891B2),
              () => _navigateTo(const LiveTableMapScreen())),
          _buildActionCard('Floor Plan', Icons.grid_view, const Color(0xFF6366F1),
              () => _navigateTo(const FloorPlanEditorScreen())),
          _buildActionCard('Pings', Icons.notifications_active, Colors.amber,
              () => _navigateTo(const WaiterRingsScreen())),
        ];
      case 'services':
        return [
          _buildActionCard('Services', Icons.spa, Colors.purple,
              () => _navigateTo(const ServiceCatalogScreen())),
          _buildActionCard('Calendar', Icons.calendar_month, Colors.indigo,
              () => _navigateTo(const BookingsCalendarScreen())),
          _buildActionCard('Staff', Icons.people, Colors.blue,
              () => _navigateTo(const StaffManagementScreen())),
          _buildActionCard('Supplies', Icons.inventory_2, Colors.brown,
              () => _navigateTo(const SuppliesScreen(module: 'services'))),
          _buildActionCard('Rooms', Icons.meeting_room, Colors.teal,
              () => _navigateTo(const ServiceRoomsScreen())),
          _buildActionCard('Buffers', Icons.timer_outlined, Colors.amber,
              () => _navigateTo(const ServiceBuffersScreen())),
          _buildActionCard('Add-ons', Icons.library_add_check, Colors.deepOrange,
              () => _navigateTo(const ServiceAddonsScreen())),
          _buildActionCard('Recur', Icons.event_repeat, Colors.green,
              () => _navigateTo(const ServiceRecurringScreen())),
          _buildActionCard('Shifts', Icons.schedule, Colors.blueGrey,
              () => _navigateTo(const ShiftSchedulingScreen())),
        ];
      case 'lodging':
        return [
          _buildActionCard('Lodging', Icons.hotel, const Color(0xFF0891B2),
              () => _navigateTo(const ReservationsDashboardScreen())),
          _buildActionCard('Rooms', Icons.meeting_room, const Color(0xFF06B6D4),
              () => _navigateTo(const RoomManagementScreen())),
          _buildActionCard('Folios', Icons.account_balance_wallet, Colors.green,
              () => _navigateTo(const LodgingFoliosScreen())),
          _buildActionCard('Groups', Icons.group_work, Colors.blue,
              () => _navigateTo(const LodgingGroupsScreen())),
          _buildActionCard('Rates', Icons.price_change, Colors.purple,
              () => _navigateTo(const LodgingRatesScreen())),
          _buildActionCard('Sync', Icons.sync_alt, Colors.orange,
              () => _navigateTo(const LodgingChannelLogsScreen())),
        ];
      case 'entertainment':
        return [
          _buildActionCard('Assets', Icons.sports_esports, Colors.deepPurple,
              () => _navigateTo(const AssetManagementScreen())),
          _buildActionCard('Sessions', Icons.play_circle, Colors.indigo,
              () => _navigateTo(const SessionsDashboardScreen())),
          _buildActionCard('Pre-paid', Icons.timer_off_outlined, Colors.red,
              () => _navigateTo(const EntertainmentPrepaidScreen())),
          _buildActionCard('Tabs', Icons.local_bar, Colors.amber,
              () => _navigateTo(const EntertainmentTabsScreen())),
          _buildActionCard('Pause', Icons.pause_circle_outline, Colors.cyan,
              () => _navigateTo(const EntertainmentPauseScreen())),
          _buildActionCard('Pricing', Icons.auto_graph, Colors.green,
              () => _navigateTo(const EntertainmentPricingScreen())),
        ];
    default:
      return [];
  }
}

  /// Module display label
  String _moduleLabel(String module) {
    switch (module) {
      case 'retail': return 'Retail';
      case 'restaurant': return 'Food';
      case 'services': return 'Services';
      case 'lodging': return 'Housing';
      case 'entertainment': return 'Gaming';
      default: return module;
    }
  }

  /// Module brand color
  Color _moduleColor(String module) {
    switch (module) {
      case 'retail': return AppColors.gray900;
      case 'restaurant': return Colors.deepOrange;
      case 'services': return Colors.purple;
      case 'lodging': return Colors.teal;
      case 'entertainment': return Colors.indigo;
      default: return AppColors.gray600;
    }
  }

  /// Module icon
  IconData _moduleIcon(String module) {
    switch (module) {
      case 'retail': return Icons.shopping_bag_outlined;
      case 'restaurant': return Icons.restaurant_outlined;
      case 'services': return Icons.spa_outlined;
      case 'lodging': return Icons.hotel_outlined;
      case 'entertainment': return Icons.sports_esports_outlined;
      default: return Icons.extension_outlined;
    }
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  Widget _buildRecentTransactions() {
    if (_recentTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.gray100),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.gray300),
              const SizedBox(height: 8),
              Text('No recent transactions', style: TextStyle(fontSize: 13, color: AppColors.gray400, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSectionHeader('Recent')),
            GestureDetector(
              onTap: () {
                // Navigate to History tab (index 1)
                final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                homeState?._onItemTapped(1);
              },
              child: Text(
                'SEE ALL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ],
        ),
        ...List.generate(_recentTransactions.length, (index) {
          final txn = _recentTransactions[index];
          final amount = (txn['totalAmount'] as num? ?? 0.0);
          final type = txn['type'] as String? ?? 'unknown';
          final date = DateTime.fromMillisecondsSinceEpoch(txn['timestamp']);
          final sourceModule = txn['source_module']?.toString() ?? 'retail';

          final isCredit = ['sale', 'incoming'].contains(type);
          final formattedAmount = NumberFormat('#,##0.00').format(amount);

          IconData icon;
          Color color;
          String typeLabel = type.toUpperCase();
          
          if (type == 'sale') {
            switch (sourceModule) {
              case 'restaurant':
                icon = Icons.restaurant_outlined;
                color = Colors.deepOrange;
                typeLabel = 'RESTAURANT';
                break;
              case 'services':
                icon = Icons.spa_outlined;
                color = Colors.purple;
                typeLabel = 'BOOKING';
                break;
              case 'lodging':
                icon = Icons.hotel_outlined;
                color = Colors.teal;
                typeLabel = 'LODGING';
                break;
              case 'entertainment':
                icon = Icons.sports_esports_outlined;
                color = Colors.indigo;
                typeLabel = 'SESSION';
                break;
              case 'retail':
              default:
                icon = Icons.shopping_bag_outlined;
                color = AppColors.primaryGreen;
                typeLabel = 'RETAIL';
                break;
            }
          } else {
            switch (type) {
              case 'incoming':
                icon = Icons.arrow_downward;
                color = AppColors.success;
                break;
              case 'outgoing':
                icon = Icons.arrow_upward;
                color = AppColors.danger;
                break;
              default:
                icon = Icons.receipt_long_outlined;
                color = AppColors.gray500;
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: AppColors.gray100),
              boxShadow: const [AppShadows.sm],
            ),
            child: Row(
              children: [
                // Icon circle
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.1),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              txn['details']?.toString().isNotEmpty == true
                                  ? txn['details'].toString()
                                  : typeLabel.length > 1 ? '${typeLabel[0].toUpperCase()}${typeLabel.substring(1).toLowerCase()}' : typeLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gray900,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${isCredit ? '+' : '-'}KES $formattedAmount',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isCredit ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _relativeTime(date),
                            style: TextStyle(fontSize: 12, color: AppColors.gray500, fontWeight: FontWeight.w500),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('·', style: TextStyle(color: AppColors.gray300)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLockedCard(String title, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.gray200),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gray100,
            ),
            child: Icon(Icons.lock_outline, color: AppColors.gray400, size: 18),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
                color: AppColors.gray400,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _refresh());
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: AppColors.gray100),
            boxShadow: const [AppShadows.sm],
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.1),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    color: AppColors.gray700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// AnimatedMetricCard implementation from UX_Design.md
class AnimatedMetricCard extends StatefulWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final bool isCurrency;
  final bool compact;

  const AnimatedMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isCurrency = false,
    this.compact = false,
  });

  @override
  State<AnimatedMetricCard> createState() => _AnimatedMetricCardState();
}

class _AnimatedMetricCardState extends State<AnimatedMetricCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.normal,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: AppAnimations.standardCurve));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedMetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _animation = Tween<double>(begin: oldWidget.value, end: widget.value)
          .animate(CurvedAnimation(
              parent: _controller, curve: AppAnimations.standardCurve));
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Compact mode: just the animated number, no container
    if (widget.compact) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final displayValue = _animation.value;
          return Text(
            widget.isCurrency
                ? NumberFormat('#,##0').format(displayValue)
                : NumberFormat('#,##0').format(displayValue.toInt()),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: widget.color,
              height: 1,
            ),
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.color.withValues(alpha: 0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [AppShadows.md],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: widget.color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTypography.textTheme.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final displayValue = _animation.value;
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.isCurrency
                      ? 'KSH ${NumberFormat('#,##0.00').format(displayValue)}'
                      : NumberFormat('#,##0').format(displayValue.toInt()),
                  style: AppTypography.textTheme.displayLarge?.copyWith(
                    color: widget.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
