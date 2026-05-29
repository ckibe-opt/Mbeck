// ============================================================================
// OPTIMIZED SETTINGS SCREEN (settings_screen.dart)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../db/db_provider.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/onboarding_service.dart';
import '../services/background_sync_service.dart';
import '../models/permissions.dart';
import '../models/shop_member.dart';
import '../theme/design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'paywall_screen.dart';
import '../services/revenuecat_service.dart';

import 'import_screen.dart';
import 'team_management_screen.dart';
import 'auth/signup_screen.dart';
import 'backup_management_screen.dart';
import 'shop_appearance_screen.dart';
import 'online_store/online_store_dashboard.dart';
import 'wifi_connection_screen.dart';
import 'subscription/pricing_screen.dart';
import 'enterprise/chain_dashboard_screen.dart';
import 'lan_sync_diagnostic_screen.dart';
import 'data_share_screen.dart';
import 'online_analytics_screen.dart';
import '../models/shop.dart';
import '../config/app_config.dart';
import 'customers_screen.dart';
import 'inventory_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  int customerCount = 0;
  int txnCount = 0;
  int inventoryCount = 0;
  bool _isProcessing = false;
  bool _isLoadingStats = true;
  bool _isSyncing = false;
  Map<String, int>? _syncStatus;
  Shop? _currentShop;
  bool _canAccessEnterprise = false;
  List<String> _enabledModules = ['retail'];
  User? _currentUser;
  bool _isLinking = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
    _loadSyncStatus();
    _loadShopInfo();
    _checkRole();
    _loadModules();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _toggleGoogleLink() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ You must be logged in to cloud services to link a Google account.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final isLinked = AuthService.isGoogleLinked(_currentUser);

    if (isLinked) {
      // Unlink confirmation
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unlink Google Account?'),
          content: const Text(
            'Are you sure you want to unlink your Google account? You will not be able to log in using Google unless you link another method or link it again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Unlink'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        setState(() => _isLinking = true);
        try {
          await AuthService.unlinkGoogleAccount();
          await _loadCurrentUser();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Google account unlinked successfully.'),
                backgroundColor: AppColors.primaryGreen,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cannot Unlink'),
                content: Text(e.toString().replaceAll('Exception:', '').trim()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isLinking = false);
          }
        }
      }
    } else {
      // Link action
      setState(() => _isLinking = true);
      try {
        await AuthService.linkGoogleAccount();
        await _loadCurrentUser();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Google account linked successfully.'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Linking failed: ${e.toString().replaceAll('Exception:', '').trim()}'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLinking = false);
        }
      }
    }
  }



  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadModules() async {
    final modules = await OnboardingService.getSelectedModules();
    debugPrint('⚙️ Settings: Active modules = $modules');
    if (mounted) {
      setState(() => _enabledModules = modules);
    }
  }

  ShopMember? _currentMember;
  bool _isOwner = false;

  Future<void> _checkRole() async {
    final member = await AuthService.getCurrentMember();
    final isObserver = await AuthService.isGhostMode();
    if (mounted) {
      setState(() {
        _currentMember = member;
        _isOwner = member?.role == 'OWNER';
      });
      await _updateEnterpriseAccess(isObserver);
    }
  }

  Future<void> _updateEnterpriseAccess(bool isObserver) async {
    final isEnterpriseSub = await RevenueCatService.isEnterpriseSubscriber();
    if (mounted) {
      setState(() {
        _canAccessEnterprise = (_currentShop?.isEnterprise ?? false) || isEnterpriseSub;
      });
    }
  }

  Future<void> _loadShopInfo() async {
    final shop = await AuthService.getCurrentShop();
    final isObserver = await AuthService.isGhostMode();
    if (mounted) {
      setState(() {
        _currentShop = shop;
      });
      await _updateEnterpriseAccess(isObserver);
    }
  }
  
  Future<void> _loadSyncStatus() async {
    final status = await SyncService.getSyncStatus();
    if (mounted) {
      setState(() {
        _syncStatus = status;
      });
    }
  }
  
  Future<void> _triggerManualSync() async {
    if (_isSyncing) return;
    
    setState(() => _isSyncing = true);
    
    try {
      final syncedCount = await SyncService.syncEvents(force: true);
      final moduleResult = await BackgroundSyncService.syncNow();
      final moduleSynced = moduleResult['synced'] as List? ?? [];
      
      if (mounted) {
        final totalSynced = syncedCount + moduleSynced.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              totalSynced > 0
                  ? '✅ Synced: $syncedCount events + ${moduleSynced.length} data types'
                  : 'ℹ️ No data to sync or no network connection',
            ),
            backgroundColor: totalSynced > 0 ? AppColors.primaryGreen : AppColors.info,
          ),
        );
        await _loadSyncStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  
  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    
    try {
      final customerResults = await DbProvider.query('customer');
      customerCount = customerResults.length;
      
      if (_enabledModules.contains('services')) {
        try {
          final services = await DbProvider.query('services_catalog');
          inventoryCount = services.length;
        } catch (_) {
          inventoryCount = 0;
        }
      } else if (_enabledModules.contains('restaurant')) {
        try {
          final menu = await DbProvider.query('restaurant_menu');
          inventoryCount = menu.length;
        } catch (_) {
          inventoryCount = 0;
        }
      } else if (_enabledModules.contains('entertainment')) {
        try {
          final assets = await DbProvider.queryRaw(
            'SELECT COUNT(*) as cnt FROM entertainment_assets WHERE is_active = 1', []);
          inventoryCount = (assets.first['cnt'] as int?) ?? 0;
        } catch (_) {
          inventoryCount = 0;
        }
      } else if (_enabledModules.contains('lodging')) {
        try {
          final rooms = await DbProvider.queryRaw(
            'SELECT COUNT(*) as cnt FROM lodging_rooms WHERE is_active = 1', []);
          inventoryCount = (rooms.first['cnt'] as int?) ?? 0;
        } catch (_) {
          inventoryCount = 0;
        }
      } else {
        final inventory = await DbProvider.query('inventory');
        inventoryCount = inventory.length;
      }
      
      if (_enabledModules.contains('services')) {
        try {
          final appts = await DbProvider.query('services_bookings');
          txnCount = appts.length;
        } catch (_) {
          txnCount = 0;
        }
      } else if (_enabledModules.contains('restaurant')) {
        final orders = await DbProvider.query('txn');
        txnCount = orders.length;
      } else if (_enabledModules.contains('entertainment')) {
        try {
          final sessions = await DbProvider.queryRaw(
            "SELECT COUNT(*) as cnt FROM entertainment_sessions WHERE status = 'completed'", []);
          txnCount = (sessions.first['cnt'] as int?) ?? 0;
        } catch (_) {
          txnCount = 0;
        }
      } else if (_enabledModules.contains('lodging')) {
        try {
          final reservations = await DbProvider.queryRaw(
            'SELECT COUNT(*) as cnt FROM lodging_reservations', []);
          txnCount = (reservations.first['cnt'] as int?) ?? 0;
        } catch (_) {
          txnCount = 0;
        }
      } else {
        final txns = await DbProvider.query('txn');
        txnCount = txns.length;
      }
      
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e'))
        );
      }
    }
  }
  
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text(
          'You will need to sign in again or join a shop to continue using the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.logout();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignUpScreen()),
          (route) => false,
        );
      }
    }
  }
  
  Future<void> _runBackupOperation(
    Future<void> Function(BuildContext) operation
  ) async {
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);
    try {
      await operation(context);
      if (mounted) _loadStats();
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          // App Bar
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: Colors.white,
            elevation: 0.5,
            shadowColor: Colors.black12,
            title: const Text(
              'Data & Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.3),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6B7280)),
                onPressed: _isLoadingStats ? null : _loadStats,
                tooltip: 'Refresh Stats',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(110),
              child: Column(
                children: [
                  // (Cashier View toggle removed)
                  
                  // Tab bar
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF4F46E5),
                      unselectedLabelColor: const Color(0xFF9CA3AF),
                      indicatorColor: const Color(0xFF4F46E5),
                      indicatorWeight: 2.5,
                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      tabs: const [
                        Tab(text: 'GENERAL'),
                        Tab(text: 'NETWORK'),
                        Tab(text: 'ACCOUNT'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildGeneralTab(),
            _buildNetworkTab(),
            _buildAccountTab(),
          ],
        ),
      ),
    );
  }



  // ═══════════════════════════════════════
  // TAB 1: General
  // ═══════════════════════════════════════
  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clickable Stats
          _sectionLabel('Database Statistics'),
          _buildClickableStats(),
          const SizedBox(height: 20),

          // Marketplace & Growth
          if (AppConfig.showMbeckGoFeatures) ...[
            _sectionLabel('Marketplace & Growth'),
            _buildSettingsGroup([
               _settingsRow(
                icon: Icons.public_rounded,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
                title: 'Mbeck Go Analytics',
                subtitle: 'Track your online shop & item views',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ),
                onTap: () async {
                  final isPro = await RevenueCatService.isProSubscriber();
                  final hasAccess = isPro || (_currentShop?.hasProAccess ?? false);
                  if (!context.mounted) return;
                  if (!hasAccess) {
                    PaywallScreen.show(context, featureName: 'Mbeck Go Analytics');
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OnlineAnalyticsScreen()));
                },
              ),
            ]),
            const SizedBox(height: 20),
          ],

          // Storefront & Chain
          if (AppConfig.showMbeckGoFeatures || _canAccessEnterprise) ...[
            _sectionLabel('Storefront & Chain'),
            _buildSettingsGroup([
              if (AppConfig.showMbeckGoFeatures) ...[
                _settingsRow(
                  icon: Icons.storefront_outlined,
                  iconBg: const Color(0xFFE0F2F1),
                  iconColor: const Color(0xFF00796B),
                  title: 'Online Store Dashboard',
                  subtitle: 'Configure live status, branding, modules, and catalog',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OnlineStoreDashboard()));
                  },
                ),
                _settingsRow(
                  icon: Icons.palette_outlined,
                  iconBg: const Color(0xFFF3E8FF),
                  iconColor: const Color(0xFF9333EA),
                  title: 'Storefront Appearance',
                  subtitle: 'Customize colors & theme for Buyers',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                  onTap: () async {
                    final isPro = await RevenueCatService.isProSubscriber();
                    final hasAccess = isPro || (_currentShop?.hasProAccess ?? false);
                    if (!context.mounted) return;
                    if (!hasAccess) {
                      PaywallScreen.show(context, featureName: 'Storefront Appearance');
                      return;
                    }
                    if (_currentMember?.hasPermission(Permissions.changeSettings) == true) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopAppearanceScreen()));
                    }
                  },
                ),
              ],
              if (_canAccessEnterprise)
                _settingsRow(
                  icon: Icons.domain_rounded,
                  iconBg: const Color(0xFFE0E7FF),
                  iconColor: const Color(0xFF4F46E5),
                  title: 'Enterprise Dashboard',
                  subtitle: 'Manage multiple shops & chains',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChainDashboardScreen())),
                ),
            ]),
            const SizedBox(height: 80),
          ],
        ],
      ),
    );
  }

  Widget _buildClickableStats() {
    // Module-aware labels
    String itemLabel = 'Products';
    IconData itemIcon = Icons.inventory_2_outlined;
    Color itemColor = const Color(0xFF9333EA);
    
    String activityLabel = 'Activity';
    IconData activityIcon = Icons.receipt_long_outlined;
    Color activityColor = const Color(0xFF059669);

    if (_enabledModules.contains('services')) {
      itemLabel = 'Services';
      itemIcon = Icons.design_services_outlined;
    } else if (_enabledModules.contains('restaurant')) {
      itemLabel = 'Menu';
      itemIcon = Icons.restaurant_menu_outlined;
    } else if (_enabledModules.contains('entertainment')) {
      itemLabel = 'Assets';
      itemIcon = Icons.sports_esports_outlined;
    } else if (_enabledModules.contains('lodging')) {
      itemLabel = 'Rooms';
      itemIcon = Icons.hotel_outlined;
    }

    if (_enabledModules.contains('services')) {
      activityLabel = 'Bookings';
      activityIcon = Icons.calendar_today_outlined;
    } else if (_enabledModules.contains('restaurant')) {
      activityLabel = 'Orders';
      activityIcon = Icons.receipt_outlined;
    } else if (_enabledModules.contains('entertainment')) {
      activityLabel = 'Sessions';
      activityIcon = Icons.timer_outlined;
    } else if (_enabledModules.contains('lodging')) {
      activityLabel = 'Reservations';
      activityIcon = Icons.event_note_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: _isLoadingStats
          ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : Row(
              children: [
                _clickableStat('Customers', '$customerCount', Icons.people_outline, const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
                Container(width: 1, height: 48, color: const Color(0xFFF3F4F6)),
                _clickableStat(itemLabel, '$inventoryCount', itemIcon, itemColor, const Color(0xFFFAF5FF)),
                Container(width: 1, height: 48, color: const Color(0xFFF3F4F6)),
                _clickableStat(activityLabel, '$txnCount', activityIcon, activityColor, const Color(0xFFECFDF5)),
              ],
            ),
    );
  }

  Widget _clickableStat(String label, String value, IconData icon, Color color, Color bgColor) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (label == 'Customers') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen()));
            } else if (inventoryCount >= 0 && (label == 'Products' || label == 'Menu' || label == 'Services' || label == 'Assets' || label == 'Rooms')) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryScreen()));
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // TAB 2: Network
  // ═══════════════════════════════════════
  Widget _buildNetworkTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Connections'),
          _buildSettingsGroup([
            _settingsRow(
              icon: Icons.wifi_tethering_rounded,
              iconBg: const Color(0xFFDBEAFE),
              iconColor: const Color(0xFF2563EB),
              title: 'WiFi Connection QR',
              subtitle: 'Direct buyer connection (offline)',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WifiConnectionScreen())),
            ),
            _settingsRow(
              icon: Icons.sync_rounded,
              iconBg: const Color(0xFFE0E7FF),
              iconColor: const Color(0xFF4F46E5),
              title: 'LAN Sync Diagnostic',
              subtitle: 'Test offline synchronization',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LANSyncDiagnosticScreen())),
            ),
            _settingsRow(
              icon: Icons.download_rounded,
              iconBg: const Color(0xFFCCFBF1),
              iconColor: const Color(0xFF0D9488),
              title: 'Receive Data',
              subtitle: 'Pull shop data from nearby device',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataShareScreen(isReceiveMode: true))),
            ),
            _settingsRow(
              icon: Icons.cloud_sync_rounded,
              iconBg: const Color(0xFFDBEAFE),
              iconColor: const Color(0xFF2563EB),
              title: 'Cloud Backup Events',
              subtitle: _syncStatus != null
                  ? '${_syncStatus!['synced']}/${_syncStatus!['total']} events synced'
                  : 'Sync events to cloud storage',
              subtitleColor: _syncStatus != null ? const Color(0xFF059669) : null,
              trailing: _isSyncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
              onTap: _isSyncing ? null : _triggerManualSync,
            ),
            _settingsRow(
              icon: Icons.backup_rounded,
              iconBg: const Color(0xFFDBEAFE),
              iconColor: const Color(0xFF2563EB),
              title: 'Manual SQLite Backup',
              subtitle: 'Manage local data backups',
              onTap: () async {
                final isPro = await RevenueCatService.isProSubscriber();
                final hasAccess = isPro || (_currentShop?.hasProAccess ?? false);
                if (!context.mounted) return;
                if (hasAccess) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupManagementScreen()));
                } else {
                  PaywallScreen.show(context, featureName: 'Cloud Backup & Restore');
                }
              },
            ),

            // Import CSV
            _settingsRow(
              icon: Icons.upload_file_outlined,
              iconBg: const Color(0xFFCCFBF1),
              iconColor: const Color(0xFF0D9488),
              title: 'Import Customers from CSV',
              subtitle: (_currentMember?.hasPermission(Permissions.importData) ?? true)
                  ? 'Bulk-add customers from a file'
                  : 'Restricted — requires permission',
              onTap: (_currentMember?.hasPermission(Permissions.importData) ?? true)
                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportScreen())).then((_) => _loadStats())
                  : null,
            ),
          ]),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // TAB 3: Account
  // ═══════════════════════════════════════
  Widget _buildAccountTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Subscription & Team'),
          _buildSettingsGroup([
            _settingsRow(
              icon: Icons.auto_awesome_rounded,
              iconBg: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              title: _currentShop?.subscriptionTier == null
                  ? 'Subscription Status'
                  : '${_currentShop!.subscriptionTier} Plan',
              titleTrailing: _currentShop?.subscriptionTier != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
                    )
                  : null,
              subtitle: 'View plans & manage billing',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PricingScreen())).then((_) => _loadShopInfo()),
            ),
            _settingsRow(
              icon: Icons.people_outline_rounded,
              iconBg: const Color(0xFFF3E8FF),
              iconColor: const Color(0xFF9333EA),
              title: 'Team Members',
              subtitle: (_currentMember?.hasPermission(Permissions.viewTeamMembers) ?? true)
                  ? 'Manage staff roles and permissions'
                  : 'Restricted — requires permission',
              onTap: (_currentMember?.hasPermission(Permissions.viewTeamMembers) ?? true)
                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamManagementScreen()))
                  : null,
            ),
          ]),
          const SizedBox(height: 20),

          _sectionLabel('Profile & System'),
          _buildSettingsGroup([
            // Current Business Type (non-navigable info)
            _settingsRow(
              icon: Icons.business_outlined,
              iconBg: const Color(0xFFE0E7FF),
              iconColor: const Color(0xFF4F46E5),
              title: 'Current Business Type',
              subtitle: _enabledModules.map((m) {
                switch (m) {
                  case 'retail': return 'Retail Store';
                  case 'services': return 'Service Business';
                  case 'restaurant': return 'Restaurant/Food';
                  case 'entertainment': return 'Entertainment/Sessions';
                  case 'lodging': return 'Lodging/Hotel';
                  default: return m;
                }
              }).join(', '),
              showChevron: false,
            ),
            _settingsRow(
              icon: Icons.refresh_rounded,
              iconBg: const Color(0xFFFFF7ED),
              iconColor: const Color(0xFFF97316),
              title: 'Change Business Type',
              subtitle: 'Re-run setup to change modules',
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Change Business Type?'),
                    content: const Text(
                      'This will reset your app to the onboarding screen. Your data is safe - only the active modules will change.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.orange),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  await OnboardingService.reset();
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
            ),
            _settingsRow(
              icon: Icons.link_rounded,
              iconBg: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF3B82F6),
              title: AuthService.isGoogleLinked(_currentUser) ? 'Google Account Connected' : 'Link Google Account',
              subtitle: AuthService.isGoogleLinked(_currentUser)
                  ? 'Linked as ${AuthService.getGoogleLinkedEmail(_currentUser) ?? "Google Account"}'
                  : 'Enable sign-in with Google',
              trailing: _isLinking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _isLinking ? null : _toggleGoogleLink,
            ),
            _settingsRow(
              icon: Icons.logout_rounded,
              iconBg: const Color(0xFFFEE2E2),
              iconColor: const Color(0xFFEF4444),
              title: 'Sign Out',
              titleColor: const Color(0xFFEF4444),
              chevronColor: const Color(0xFFFCA5A5),
              onTap: _signOut,
            ),
          ]),
          
          const SizedBox(height: 20),

          // App info
          _sectionLabel('Application Info'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.gray600, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('App Version', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
                    const Text('2.1.0', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  ],
                ),
                Divider(height: 20, color: const Color(0xFFF3F4F6)),
                Row(
                  children: [
                    Icon(Icons.storage_outlined, color: AppColors.gray600, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Database Version', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
                    const Text('v13 (Latest)', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // Shared UI Components
  // ═══════════════════════════════════════
  Widget _buildComingSoonTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
      child: const Text('SOON', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF9CA3AF), letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, indent: 60, endIndent: 0, color: const Color(0xFFF9FAFB)),
          ],
        ],
      ),
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? subtitleColor,
    Color? titleColor,
    Color? chevronColor,
    Widget? titleTrailing,
    Widget? trailing,
    bool showChevron = true,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: titleColor ?? const Color(0xFF111827)),
                          ),
                        ),
                        if (titleTrailing != null) ...[const SizedBox(width: 6), titleTrailing],
                      ],
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11, color: subtitleColor ?? const Color(0xFF9CA3AF)),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing
              else if (showChevron)
                Icon(Icons.chevron_right_rounded, size: 20, color: chevronColor ?? const Color(0xFFD1D5DB)),
            ],
          ),
        ),
      ),
    );
  }
}
