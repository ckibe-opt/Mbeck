import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/revenuecat_service.dart';
import '../../services/auth_service.dart';
import '../../services/subscription_service.dart';
import '../../models/shop.dart';
import '../../theme/design_system.dart';
import '../../widgets/standard_app_bar.dart';
import 'payment_screen.dart';
import '../paywall_screen.dart';
import '../../models/permissions.dart';
import '../../models/shop_member.dart';


class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  Shop? _currentShop;
  // ignore: unused_field
  ShopMember? _currentMember;
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _isYearly = false;
  Offerings? _offerings;

  @override
  void initState() {
    super.initState();
    _loadShopInfo();
  }

  Future<void> _loadShopInfo({bool force = false}) async {
    if (mounted) setState(() => _isLoading = true);
    final shop = await AuthService.getCurrentShop(forceRefresh: force);
    final member = await AuthService.getCurrentMember();
    final offerings = await RevenueCatService.fetchOfferings();
    
    // Check permission: Only Owners/Managers can manage subscriptions
    final hasPermission = member?.hasPermission(Permissions.manageSubscription) ?? false;
    final isManager = member?.role.toUpperCase() == 'MANAGER';
    final isOwner = member?.role.toUpperCase() == 'OWNER';
    
    if (mounted) {
      setState(() {
        _currentShop = shop;
        _currentMember = member;
        _offerings = offerings;
        _hasPermission = hasPermission || isManager || isOwner;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : !_hasPermission
              ? _buildPermissionDenied()
              : SafeArea(
                  top: false,
                  child: CustomScrollView(
                    slivers: [
                      // Premium Hero Header
                      SliverAppBar(
                        expandedHeight: 280,
                        pinned: true,
                        backgroundColor: AppColors.primaryDark,
                        elevation: 0,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Abstract shapes for depth
                                Positioned(
                                  top: -50,
                                  right: -50,
                                  child: Container(
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.05),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -100,
                                  left: -50,
                                  child: Container(
                                    width: 300,
                                    height: 300,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.05),
                                    ),
                                  ),
                                ),
                                SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          const SizedBox(height: 10),
                                          Center(
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white.withValues(alpha: 0.1),
                                                border: Border.all(
                                                  color: Colors.white.withValues(alpha: 0.2),
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.rocket_launch_rounded,
                                                color: Colors.white,
                                                size: 32,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Unlock Full Power',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 30,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -1.2,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'All modules included. Scale your business with the ultimate point-of-sale suite.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 15,
                                              height: 1.3,
                                              color: Colors.white,
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
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),

                      // Top Content
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Billing Toggle
                              _buildBillingToggle(),
                            ],
                          ),
                        ),
                      ),

                      // Horizontal Pricing Cards
                      SliverToBoxAdapter(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // FREE Plan
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.82,
                                  child: _buildPricingCard(
                                    tier: 'FREE',
                                    price: 0,
                                    period: 'Forever',
                                    description: 'Full-featured POS - Free forever',
                                    features: [
                                      'Up to 50 inventory items',
                                      'Unlimited transactions',
                                      '1 team member (owner)',
                                      'WhatsApp receipts',
                                      'Local reports & analytics',
                                      'Offline mode',
                                      'Buyer app connectivity',
                                    ],
                                    limitations: [
                                      'No cloud backup',
                                      'No multi-device sync',
                                      'No remote access',
                                    ],
                                    isCurrentPlan: _currentShop?.subscriptionTier == 'FREE',
                                    color: AppColors.gray600,
                                  ),
                                ),

                                const SizedBox(width: AppSpacing.lg),

                                // PRO Plan
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.82,
                                  child: Builder(
                                    builder: (context) {
                                      final proOff = _offerings?.all['pro'];
                                      final p = _isYearly ? proOff?.annual : proOff?.monthly;
                                      return _buildPricingCard(
                                        tier: 'PRO',
                                        price: SubscriptionService.getTierPrice('PRO', isYearly: _isYearly).toInt(),
                                        priceString: p?.storeProduct.priceString,
                                        package: p,
                                        period: _isYearly ? 'year' : 'month',
                                        description: 'Unlimited growth + cloud features',
                                        features: [
                                          'Everything in FREE, plus:',
                                          'Unlimited inventory items',
                                          'Up to 3 team members',
                                          'Cloud backup & restore',
                                          'Multi-device sync',
                                          'Remote inventory access (Soon)',
                                          'Consolidated analytics',
                                          'Data export/import',
                                          'All business modules included',
                                          'Email support',
                                        ],
                                        isPopular: true,
                                        isCurrentPlan: _currentShop?.subscriptionTier.startsWith('PRO') == true,
                                        color: AppColors.primaryGreen,
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(width: AppSpacing.lg),

                                // ENTERPRISE Plan
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.82,
                                  child: Builder(
                                    builder: (context) {
                                      final entOff = _offerings?.all['enterprise'];
                                      final p = _isYearly ? entOff?.annual : entOff?.monthly;
                                      return _buildPricingCard(
                                        tier: 'ENTERPRISE',
                                        price: SubscriptionService.getTierPrice('ENTERPRISE', isYearly: _isYearly).toInt(),
                                        priceString: p?.storeProduct.priceString,
                                        package: p,
                                        period: _isYearly ? 'year' : 'month',
                                        description: 'Multi-location & all modules included',
                                        features: [
                                          'Everything in PRO, plus:',
                                          'Unlimited team members',
                                          'Unlimited locations (Soon)',
                                          'Cross-location transfers (Soon)',
                                          'Consolidated analytics',
                                          'Advanced API access (Soon)',
                                          'Priority WhatsApp support',
                                          'Bulk operations',
                                        ],
                                        isCurrentPlan: _currentShop?.subscriptionTier.startsWith('ENTERPRISE') == true,
                                        color: Colors.purple,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // FAQ Section
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 32, AppSpacing.lg, 80),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Text(
                                  'Frequently Asked Questions',
                                  style: AppTypography.textTheme.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _buildFAQ('Can I switch plans later?',
                                  'Yes! You can upgrade or downgrade at any time. Changes take effect immediately.'),
                              _buildFAQ('What happens after my trial?',
                                  'Your account will automatically switch to the FREE plan. No credit card required.'),
                              _buildFAQ('How do I pay?',
                                  'We accept M-Pesa payments. Simply select a plan and follow the payment instructions.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBillingToggle() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.full),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToggleButton(
              title: 'Monthly',
              isSelected: !_isYearly,
              onTap: () => setState(() => _isYearly = false),
              activeColor: AppColors.gray800,
            ),
            _buildToggleButton(
              title: 'Yearly (Save 16%)',
              isSelected: _isYearly,
              onTap: () => setState(() => _isYearly = true),
              activeColor: AppColors.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton({required String title, required bool isSelected, required VoidCallback onTap, required Color activeColor}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.standardCurve,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.full),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.gray500,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildPricingCard({
    required String tier,
    required int price,
    String? priceString,
    Package? package,
    required String period,
    required String description,
    required List<String> features,
    List<String>? limitations,
    bool isPopular = false,
    bool isCurrentPlan = false,
    required Color color,
  }) {
    // Generate a complementary gradient based on the primary color
    final gradient = LinearGradient(
      colors: [
        color,
        HSLColor.fromColor(color).withLightness(HSLColor.fromColor(color).lightness * 0.8).toColor()
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: isPopular ? color.withOpacity(0.5) : AppColors.gray200,
          width: isPopular ? 2 : 1,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: isPopular ? gradient : null,
              color: isPopular ? null : AppColors.gray50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      tier,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: isPopular ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppRadii.full),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'DEFAULT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isCurrentPlan)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.info,
                          borderRadius: BorderRadius.circular(AppRadii.full),
                        ),
                        child: const Text(
                          'YOUR PLAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: isPopular ? Colors.white.withOpacity(0.9) : AppColors.gray600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (priceString != null)
                        Text(
                          priceString,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                            color: isPopular ? Colors.white : color,
                          ),
                        )
                      else ...[
                        Text(
                          'KES',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isPopular ? Colors.white.withOpacity(0.9) : AppColors.gray500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$price',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                            height: 1.0,
                            color: isPopular ? Colors.white : color,
                          ),
                        ),
                      ],
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '/$period',
                        style: AppTypography.textTheme.bodyLarge?.copyWith(
                          color: isPopular ? Colors.white.withOpacity(0.8) : AppColors.gray500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Features
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: color,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: AppTypography.textTheme.bodyMedium?.copyWith(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                if (limitations != null && limitations.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  ...limitations.map((limitation) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.remove_circle_outline_rounded,
                              color: AppColors.gray400,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                limitation,
                                style: AppTypography.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.gray500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
                const SizedBox(height: AppSpacing.lg),

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: isPopular && !isCurrentPlan
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadii.xl),
                            gradient: gradient,
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          )
                        : null,
                    child: ElevatedButton(
                      onPressed: isCurrentPlan
                          ? null
                          : () {
                              if (tier == 'FREE') {
                                _showDowngradeDialog();
                              } else if (package != null) {
                                _purchasePackage(package, _isYearly ? '$tier Yearly' : tier);
                              } else {
                                // Fallback offline payment layer
                                _selectPlan(tier, price, color);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: isPopular && !isCurrentPlan ? Colors.transparent : (isCurrentPlan ? AppColors.gray100 : color),
                        foregroundColor: isCurrentPlan ? AppColors.gray500 : Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                        ),
                      ),
                      child: Text(
                        isCurrentPlan
                            ? 'Current Plan'
                            : (tier == 'FREE' ? 'Downgrade to Free' : 'Upgrade to $tier'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQ(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ExpansionTile(
        title: Text(
          question,
          style: AppTypography.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Text(
              answer,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.gray700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectPlan(String tier, int price, Color color) {
    if (tier == 'FREE') {
      // Show downgrade confirmation
      _showDowngradeDialog();
    } else {
      // Navigate to payment screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            tier: _isYearly ? '$tier Yearly' : tier,
            amount: price,
            planColor: color,
          ),
        ),
      ).then((_) => _loadShopInfo(force: true)); // Refresh shop info after payment
    }
  }

  void _showDowngradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Downgrade to FREE'),
        content: const Text(
          'Are you sure you want to downgrade? You will lose access to:\n\n'
          '• WhatsApp receipts\n'
          '• Cloud sync\n'
          '• Advanced reports\n'
          '• Export/Import data\n\n'
          'Your data will be preserved, but some features will be locked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Downgrade feature coming soon'),
                  backgroundColor: AppColors.info,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('DOWNGRADE'),
          ),
        ],
      ),
    );
  }

  Future<void> _purchasePackage(Package package, String targetTier) async {
    setState(() => _isLoading = true);
    final success = await RevenueCatService.purchasePackage(package);
    if (success) {
      try {
        final shopId = await AuthService.getShopId();
        if (shopId != null) {
          final supabase = Supabase.instance.client;
          await supabase.from('shops').update({
            'subscription_tier': targetTier,
            'subscription_status': 'ACTIVE',
            'trial_ends_at': null,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', shopId);
        }
      } catch (e) {
        debugPrint('⚠️ RevenueCat Backend Update Failed: $e');
      }
      await _loadShopInfo(force: true); // Refresh state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan Upgraded Successfully! 🎉'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: AppColors.gray400,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Access Restricted',
              style: AppTypography.textTheme.headlineLarge?.copyWith(
                color: AppColors.gray800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Only Owners and Managers can manage subscriptions.',
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                color: AppColors.gray600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Contact your shop owner if you need to change the subscription plan.',
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
