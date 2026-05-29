import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/design_system.dart';
import '../../services/auth_service.dart';
import '../../services/onboarding_service.dart';
import '../../db/db_provider.dart';
import '../home_screen.dart';
// Module-specific screens for setup step routing
import '../inventory_screen.dart';
import '../new_transaction_screen.dart';
import '../restaurant/menu_management_screen.dart';
import '../restaurant/restaurant_pos_screen.dart';
import '../services/service_catalog_screen.dart';
import '../services/bookings_calendar_screen.dart';
import '../entertainment/asset_management_screen.dart';
import '../entertainment/sessions_dashboard_screen.dart';
import '../lodging/room_management_screen.dart';
import '../lodging/reservations_dashboard_screen.dart';
import '../retail/suppliers_screen.dart';
import '../retail/promotions_screen.dart';

/// Ultra-premium quick setup wizard with indigo mesh gradient header,
/// glowing emerald progress bar, and floating 3D checklist cards.
class QuickSetupScreen extends StatefulWidget {
  const QuickSetupScreen({super.key});

  @override
  State<QuickSetupScreen> createState() => _QuickSetupScreenState();
}

class _QuickSetupScreenState extends State<QuickSetupScreen>
    with TickerProviderStateMixin {
  List<_SetupStep> _steps = [];
  bool _isLoading = true;
  String _primaryModule = 'retail';
  late AnimationController _celebrationController;
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _loadSteps();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════
  // Business Logic (PRESERVED from original)
  // ═══════════════════════════════════════════════

  Future<void> _loadSteps() async {
    final modules = await OnboardingService.getSelectedModules();
    final steps = <_SetupStep>[];

    // Determine primary module (same priority as step title selection)
    if (modules.contains('restaurant')) {
      _primaryModule = 'restaurant';
    } else if (modules.contains('services')) {
      _primaryModule = 'services';
    } else if (modules.contains('entertainment')) {
      _primaryModule = 'entertainment';
    } else if (modules.contains('lodging')) {
      _primaryModule = 'lodging';
    } else {
      _primaryModule = 'retail';
    }

    // Step 1: Currency (all types) — auto-detect
    steps.add(_SetupStep(
      id: 'currency',
      title: 'Set your currency',
      subtitle: 'KES (Kenyan Shilling)',
      icon: Icons.attach_money,
      color: const Color(0xFF10B981),
      isAutoComplete: true,
    ));

    // Step 2: Add first item (adapts to module)
    if (_primaryModule == 'restaurant') {
      steps.add(_SetupStep(id: 'add_item', title: 'Add your first menu item', subtitle: 'Create a dish or drink for your menu', icon: Icons.restaurant_menu, color: const Color(0xFFFF9800)));
    } else if (_primaryModule == 'services') {
      steps.add(_SetupStep(id: 'add_item', title: 'Add your first service', subtitle: 'Create a service you offer customers', icon: Icons.calendar_month, color: const Color(0xFF2196F3)));
    } else if (_primaryModule == 'entertainment') {
      steps.add(_SetupStep(id: 'add_item', title: 'Add your first game or asset', subtitle: 'Register a pool table, console, or station', icon: Icons.sports_esports, color: const Color(0xFF9C27B0)));
    } else if (_primaryModule == 'lodging') {
      steps.add(_SetupStep(id: 'add_item', title: 'Add your first room', subtitle: 'Register a room or accommodation unit', icon: Icons.hotel, color: const Color(0xFF00695C)));
    } else {
      steps.add(_SetupStep(id: 'add_item', title: 'Stock your first shelf', subtitle: 'Add a product to start building your digital store', icon: Icons.add_shopping_cart, color: const Color(0xFF4CAF50)));
    }

    // Retail-only: Supply chain & promotions (outcome-driven steps)
    if (_primaryModule == 'retail') {
      steps.add(_SetupStep(
        id: 'add_supplier',
        title: 'Connect to a supplier',
        subtitle: 'Never run out of stock \u2014 track who brings your goods',
        icon: Icons.local_shipping,
        color: const Color(0xFF1E88E5),
      ));
      steps.add(_SetupStep(
        id: 'create_promo',
        title: 'Launch a grand-opening deal',
        subtitle: 'Attract your first customers with a discount',
        icon: Icons.card_giftcard,
        color: const Color(0xFFE91E63),
      ));
    }

    // Step 3: Make a test sale/action
    if (_primaryModule == 'restaurant') {
      steps.add(_SetupStep(id: 'test_sale', title: 'Take a test order', subtitle: 'Try the order flow with your menu', icon: Icons.receipt_long, color: const Color(0xFFFF9800)));
    } else if (_primaryModule == 'services') {
      steps.add(_SetupStep(id: 'test_sale', title: 'Book a test appointment', subtitle: 'Try the booking calendar', icon: Icons.event_available, color: const Color(0xFF2196F3)));
    } else if (_primaryModule == 'entertainment') {
      steps.add(_SetupStep(id: 'test_sale', title: 'Start a test session', subtitle: 'Try the timer billing flow', icon: Icons.play_circle, color: const Color(0xFF9C27B0)));
    } else if (_primaryModule == 'lodging') {
      steps.add(_SetupStep(id: 'test_sale', title: 'Make a test reservation', subtitle: 'Try the check-in flow', icon: Icons.bookmark_add, color: const Color(0xFF00695C)));
    } else {
      steps.add(_SetupStep(id: 'test_sale', title: 'Ring up your first customer', subtitle: 'Try a checkout using your new product and promo', icon: Icons.point_of_sale, color: const Color(0xFF4CAF50)));
    }

    // Invite team (optional) — smart permissions: explain value first
    steps.add(_SetupStep(id: 'invite_team', title: 'Bring your team aboard', subtitle: 'Let them run the register while you manage the business', icon: Icons.group_add, color: const Color(0xFF667EEA), isOptional: true));

    await _checkStepCompletion(steps);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_wizard_complete', true);

    if (mounted) setState(() { _steps = steps; _isLoading = false; });
  }

  Future<void> _checkStepCompletion(List<_SetupStep> steps) async {
    final prefs = await SharedPreferences.getInstance();
    for (final step in steps) {
      if (step.isAutoComplete) { step.isCompleted = true; continue; }
      if (prefs.getBool('setup_${step.id}_done') == true) { step.isCompleted = true; continue; }
      if (step.id == 'add_item') {
        try {
          final tableName = _primaryModule == 'restaurant' ? 'restaurant_menu' : 
                            _primaryModule == 'services' ? 'services_catalog' : 
                            _primaryModule == 'entertainment' ? 'entertainment_assets' : 
                            _primaryModule == 'lodging' ? 'lodging_rooms' : 'inventory';
          final items = await DbProvider.query(tableName, limit: 1);
          if (items.isNotEmpty) { step.isCompleted = true; await prefs.setBool('setup_add_item_done', true); }
        } catch (_) {}
      }
      if (step.id == 'test_sale') {
        try {
          final tableName = _primaryModule == 'restaurant' ? 'restaurant_orders' : 
                            _primaryModule == 'services' ? 'services_bookings' : 
                            _primaryModule == 'entertainment' ? 'entertainment_sessions' : 
                            _primaryModule == 'lodging' ? 'lodging_reservations' : 'txn';
          final txns = await DbProvider.query(tableName, limit: 1);
          if (txns.isNotEmpty) { step.isCompleted = true; await prefs.setBool('setup_test_sale_done', true); }
        } catch (_) {}
      }
      if (step.id == 'add_supplier') {
        try {
          final suppliers = await DbProvider.query('suppliers', limit: 1);
          if (suppliers.isNotEmpty) { step.isCompleted = true; await prefs.setBool('setup_add_supplier_done', true); }
        } catch (_) {}
      }
      if (step.id == 'create_promo') {
        try {
          final promos = await DbProvider.query('promotions', limit: 1);
          if (promos.isNotEmpty) { step.isCompleted = true; await prefs.setBool('setup_create_promo_done', true); }
        } catch (_) {}
      }
    }
  }

  int get _completedCount => _steps.where((s) => s.isCompleted).length;
  double get _progress => _steps.isEmpty ? 0 : _completedCount / _steps.length;
  bool get _allDone => _steps.isNotEmpty && _completedCount == _steps.length;
  String get _progressPercent => '${(_progress * 100).toInt()}%';

  Future<void> _completeAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_wizard_complete', true);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _onStepTap(_SetupStep step) async {
    if (step.isCompleted) return;

    if (step.id == 'invite_team') {
      final shopId = await AuthService.getShopId();
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Share Your Shop ID'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Share this ID with your employees so they can join:'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.gray100, borderRadius: BorderRadius.circular(AppRadii.md)),
                  child: SelectableText(shopId ?? 'Not available', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'monospace'), textAlign: TextAlign.center),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () { Navigator.pop(ctx); _markStepDone('invite_team'); }, child: const Text('Done')),
            ],
          ),
        );
      }
      return;
    }


    // Route to the correct module-specific screen
    Widget? targetScreen;

    if (step.id == 'add_item') {
      switch (_primaryModule) {
        case 'restaurant':     targetScreen = const MenuManagementScreen(); break;
        case 'services':       targetScreen = const ServiceCatalogScreen(); break;
        case 'entertainment':  targetScreen = const AssetManagementScreen(); break;
        case 'lodging':        targetScreen = const RoomManagementScreen(); break;
        default:               targetScreen = const InventoryScreen(); break;
      }
    } else if (step.id == 'add_supplier') {
      targetScreen = const SuppliersScreen();
    } else if (step.id == 'create_promo') {
      targetScreen = const PromotionsScreen();
    } else if (step.id == 'test_sale') {
      switch (_primaryModule) {
        case 'restaurant':     targetScreen = const RestaurantPosScreen(); break;
        case 'services':       targetScreen = const BookingsCalendarScreen(); break;
        case 'entertainment':  targetScreen = const SessionsDashboardScreen(); break;
        case 'lodging':        targetScreen = const ReservationsDashboardScreen(); break;
        default:               targetScreen = const NewTransactionScreen(); break;
      }
    }

    if (targetScreen != null && mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen!));
      _refreshSteps();
    }
  }

  Future<void> _markStepDone(String stepId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_${stepId}_done', true);
    _refreshSteps();
  }

  Future<void> _refreshSteps() async {
    await _checkStepCompletion(_steps);
    if (mounted) {
      setState(() {});
      if (_allDone) {
        _celebrationController.forward();
        await Future.delayed(const Duration(milliseconds: 1200));
        await _completeAndNavigate();
      }
    }
  }

  // ═══════════════════════════════════════════════
  // Premium UI Build
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F4F5),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F5),
      body: Column(
        children: [
          // ═══════ Premium Header ═══════
          _buildMeshGradientHeader(),

          // ═══════ Floating Checklist Cards ═══════
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                final step = _steps[index];
                final isCurrent = !step.isCompleted &&
                    (index == 0 || _steps[index - 1].isCompleted);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildStepCard(step, isCurrent),
                );
              },
            ),
          ),

          // ═══════ Bottom Action Bar ═══════
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ────────────────────────────────────
  // Deep Indigo Mesh Gradient Header
  // ────────────────────────────────────
  Widget _buildMeshGradientHeader() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF312E81), // indigo-900
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        children: [
          // Mesh gradient orbs
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 200,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.60),
                    blurRadius: 80,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: -30,
            child: Container(
              width: 160,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.40),
                    blurRadius: 80,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                children: [
                  // Final Step badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.20)),
                    ),
                    child: const Text(
                      'FINAL STEP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    "Let's set you up!",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hey \uD83D\uDC4B Let\'s get your store ready to sell!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFC7D2FE),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ═══════ Glowing Progress Bar ═══════
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.20)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$_progressPercent Complete',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '$_completedCount of ${_steps.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFC7D2FE),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Glowing bar
                            Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1B4B).withOpacity(0.50),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.black.withOpacity(0.10)),
                              ),
                              child: Stack(
                                children: [
                                  AnimatedFractionallySizedBox(
                                    duration: const Duration(milliseconds: 800),
                                    curve: Curves.easeOutCubic,
                                    widthFactor: _progress.clamp(0.02, 1.0),
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF34D399), Color(0xFF6EE7B7)],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF34D399).withOpacity(0.60),
                                            blurRadius: 15,
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          // Shine highlight at the end
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 20,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.white.withOpacity(0.40),
                                                  ],
                                                ),
                                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────
  // Floating 3D Checklist Card
  // ────────────────────────────────────
  Widget _buildStepCard(_SetupStep step, bool isCurrent) {
    return GestureDetector(
      onTap: step.isCompleted ? null : () => _onStepTap(step),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..scale(step.isCompleted ? 0.96 : 1.0),
        decoration: BoxDecoration(
          color: step.isCompleted
              ? Colors.white.withOpacity(0.60)
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isCurrent
              ? Border.all(color: const Color(0xFF6366F1), width: 2)
              : Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ]
              : step.isCompleted
                  ? [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)]
                  : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon block
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: step.isCompleted
                      ? const Color(0xFFECFDF5)
                      : isCurrent
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  step.isCompleted ? Icons.check : step.icon,
                  size: 24,
                  color: step.isCompleted
                      ? const Color(0xFF10B981)
                      : isCurrent
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: step.isCompleted
                                  ? const Color(0xFF9CA3AF)
                                  : isCurrent
                                      ? const Color(0xFF312E81)
                                      : const Color(0xFF111827),
                              decoration: step.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (step.isOptional)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFC7D2FE)),
                            ),
                            child: const Text(
                              'Optional',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6366F1),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      step.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: step.isCompleted
                            ? const Color(0xFFD1D5DB)
                            : const Color(0xFF6B7280),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow for current step
              if (!step.isCompleted && isCurrent)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF4F46E5)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────
  // Bottom Action Bar
  // ────────────────────────────────────
  Widget _buildBottomBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.90),
            border: const Border(top: BorderSide(color: Colors.white)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Skip
                GestureDetector(
                  onTap: _completeAndNavigate,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Main button
                Expanded(
                  child: GestureDetector(
                    onTap: _completeAndNavigate,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 52,
                      decoration: BoxDecoration(
                        color: _allDone
                            ? const Color(0xFF10B981)
                            : const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (_allDone
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF111827))
                                .withOpacity(0.30),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_allDone)
                              AnimatedBuilder(
                                animation: _shimmerCtrl,
                                builder: (context, _) {
                                  return Positioned(
                                    left: -150 + _shimmerCtrl.value * (MediaQuery.of(context).size.width + 150),
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 100,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.white.withOpacity(0.25),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            Text(
                              _allDone ? 'Finish Setup 🚀' : 'Complete Actions',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Data Model
// ═══════════════════════════════════════════════
class _SetupStep {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isAutoComplete;
  final bool isOptional;
  bool isCompleted;

  _SetupStep({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isAutoComplete = false,
    this.isOptional = false,
    this.isCompleted = false,
  });
}

