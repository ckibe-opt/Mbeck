import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/onboarding_service.dart';
import '../../services/auth_service.dart';
import 'quick_setup_screen.dart';

/// Ultra-premium business type selector with neumorphic cards,
/// dramatic lift shadows, animated selection rings, and glassmorphic bottom bar.
class BusinessTypeSelectorScreen extends StatefulWidget {
  const BusinessTypeSelectorScreen({super.key});

  @override
  State<BusinessTypeSelectorScreen> createState() => _BusinessTypeSelectorScreenState();
}

class _BusinessTypeSelectorScreenState extends State<BusinessTypeSelectorScreen>
    with TickerProviderStateMixin {
  final Set<String> _selected = {};
  bool _isLoading = false;
  late AnimationController _staggerCtrl;
  late AnimationController _shimmerCtrl;

  static const _options = [
    _BizOption(
      id: 'retail',
      title: 'Retail Store',
      desc: 'Sell products, track inventory & AI barcode scanning',
      icon: Icons.storefront,
      color: Color(0xFF10B981),
      softBg: Color(0xFFECFDF5),
    ),
    _BizOption(
      id: 'services',
      title: 'Service Business',
      desc: 'Manage appointments, customer bookings & schedules',
      icon: Icons.calendar_month,
      color: Color(0xFF3B82F6),
      softBg: Color(0xFFEFF6FF),
    ),
    _BizOption(
      id: 'restaurant',
      title: 'Restaurant / Cafe',
      desc: 'Take custom orders, manage tables & kitchen queue',
      icon: Icons.restaurant,
      color: Color(0xFFF97316),
      softBg: Color(0xFFFFF7ED),
    ),
    _BizOption(
      id: 'entertainment',
      title: 'Gaming / Entertainment',
      desc: 'Pool tables, gaming stations, session timer billing',
      icon: Icons.sports_esports,
      color: Color(0xFF8B5CF6),
      softBg: Color(0xFFF5F3FF),
    ),
    _BizOption(
      id: 'lodging',
      title: 'Lodging / Hotels',
      desc: 'Guesthouses, Airbnb, room reservations & check-in',
      icon: Icons.hotel,
      color: Color(0xFF14B8A6),
      softBg: Color(0xFFF0FDFA),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one business type')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final shopId = await AuthService.getShopId();
      await OnboardingService.completeOnboarding(
        moduleIds: _selected.toList(),
        shopId: shopId ?? 'default_shop',
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const QuickSetupScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Setup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ═══════ Top decorative blob ═══════
            Stack(
              children: [
                Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFEEF2FF), Colors.transparent],
                    ),
                  ),
                ),
              ],
            ),

            // ═══════ Header ═══════
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Step badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: const Text(
                      'STEP 2 OF 3',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4338CA),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'What type of business\nare you running?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pick all that apply — you can change this later.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ═══════ Super Premium Cards ═══════
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                itemCount: _options.length,
                itemBuilder: (context, index) {
                  final opt = _options[index];
                  final isSelected = _selected.contains(opt.id);
                  final delay = index / _options.length;

                  return AnimatedBuilder(
                    animation: _staggerCtrl,
                    builder: (context, child) {
                      final progress = ((_staggerCtrl.value - delay) / (1 - delay)).clamp(0.0, 1.0);
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - progress)),
                        child: Opacity(opacity: progress, child: child),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            isSelected ? _selected.remove(opt.id) : _selected.add(opt.id);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          transform: Matrix4.identity()
                            ..translate(0.0, isSelected ? -2.0 : 0.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected ? opt.color : const Color(0xFFF3F4F6),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: opt.color.withOpacity(0.15),
                                      blurRadius: 30,
                                      offset: const Offset(0, 12),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 20,
                                    ),
                                  ],
                          ),
                          child: Stack(
                            children: [
                              // Subtle background tint on selection
                              if (isSelected)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: opt.color.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                ),

                              // Card content
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Neumorphic icon block
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: opt.softBg,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Icon(opt.icon, size: 28, color: opt.color),
                                    ),
                                    const SizedBox(width: 14),

                                    // Text
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            opt.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF111827),
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            opt.desc,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF6B7280),
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Animated circular checkbox
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isSelected ? opt.color : Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? opt.color : const Color(0xFFD1D5DB),
                                          width: 2,
                                        ),
                                      ),
                                      child: AnimatedScale(
                                        scale: isSelected ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeOutBack,
                                        child: const Icon(Icons.check, size: 18, color: Colors.white),
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
                  );
                },
              ),
            ),

            // ═══════ Bottom Action Bar (Glassmorphic) ═══════
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.80),
                    border: const Border(top: BorderSide(color: Colors.white)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Selection count
                        AnimatedCrossFade(
                          firstChild: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${_selected.length} Type${_selected.length > 1 ? 's' : ''} Selected',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4F46E5),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          secondChild: const SizedBox.shrink(),
                          crossFadeState: _selected.isNotEmpty
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: const Duration(milliseconds: 200),
                        ),

                        // Continue button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: GestureDetector(
                            onTap: _selected.isEmpty || _isLoading ? null : _completeOnboarding,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: _selected.isNotEmpty
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _selected.isNotEmpty
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF4F46E5).withOpacity(0.35),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Shimmer
                                    if (_selected.isNotEmpty)
                                      AnimatedBuilder(
                                        animation: _shimmerCtrl,
                                        builder: (context, _) {
                                          return Positioned(
                                            left: -200 + _shimmerCtrl.value * (MediaQuery.of(context).size.width + 200),
                                            top: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 100,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.white.withOpacity(0.2),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation(Colors.white),
                                            ),
                                          )
                                        : Text(
                                            'Continue',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                              color: _selected.isNotEmpty
                                                  ? Colors.white
                                                  : const Color(0xFF9CA3AF),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _BizOption {
  final String id;
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final Color softBg;

  const _BizOption({
    required this.id,
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.softBg,
  });
}
