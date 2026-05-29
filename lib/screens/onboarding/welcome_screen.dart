import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ultra-premium welcome carousel with 3D glass orbs, floating bouncing
/// orbit icons, ambient glow backgrounds, and shimmer buttons.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentSlide = 0;

  // Bounce controllers for orbit icons (independent speeds)
  late AnimationController _bounce1;
  late AnimationController _bounce2;
  late AnimationController _bounce3;
  late AnimationController _shimmerCtrl;

  static const _slides = [
    _SlideData(
      theme: 'emerald',
      glowColor: Color(0xFF10B981),
      gradientColors: [Color(0xFF34D399), Color(0xFF059669)],
      title: 'Run Your Business\nLike a Pro',
      subtitle: 'Sales, inventory, orders — all in one app.\nWorks offline, syncs everywhere.',
      mainIcon: Icons.shopping_cart,
      orbit1: _OrbitIcon(icon: Icons.trending_up, color: Color(0xFF3B82F6), dx: 0.75, dy: 0.05),
      orbit2: _OrbitIcon(icon: Icons.inventory_2, color: Color(0xFF10B981), dx: 0.05, dy: 0.75),
    ),
    _SlideData(
      theme: 'indigo',
      glowColor: Color(0xFF6366F1),
      gradientColors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
      title: 'Built for Every\nBusiness Type',
      subtitle: 'Retail, restaurant, services, entertainment,\nlodging — each with specialized tools.',
      mainIcon: Icons.apps,
      orbit1: _OrbitIcon(icon: Icons.restaurant, color: Color(0xFFF97316), dx: 0.15, dy: 0.0),
      orbit2: _OrbitIcon(icon: Icons.hotel, color: Color(0xFF14B8A6), dx: 0.8, dy: 0.72),
      orbit3: _OrbitIcon(icon: Icons.calendar_month, color: Color(0xFF8B5CF6), dx: -0.05, dy: 0.45),
    ),
    _SlideData(
      theme: 'orange',
      glowColor: Color(0xFFF97316),
      gradientColors: [Color(0xFFFB923C), Color(0xFFEA580C)],
      title: 'Start Selling in\nUnder 5 Minutes',
      subtitle: 'No training needed. Load sample products,\nmake your first sale, and you\'re live.',
      mainIcon: Icons.rocket_launch,
      orbit1: _OrbitIcon(icon: Icons.timer, color: Color(0xFFF97316), dx: 0.8, dy: 0.15),
      orbit2: _OrbitIcon(icon: Icons.check_circle, color: Color(0xFF10B981), dx: 0.1, dy: 0.7),
    ),
  ];

  bool get _isLastSlide => _currentSlide == _slides.length - 1;

  @override
  void initState() {
    super.initState();
    _bounce1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _bounce2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat(reverse: true);
    _bounce3 = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500))..repeat(reverse: true);
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bounce1.dispose();
    _bounce2.dispose();
    _bounce3.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _navigateForward() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentSlide];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // ═══════ Top bar with dots + Skip ═══════
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  // Colored dots
                  Row(
                    children: const [
                      _Dot(color: Color(0xFF10B981)),
                      SizedBox(width: 6),
                      _Dot(color: Color(0xFF6366F1)),
                      SizedBox(width: 6),
                      _Dot(color: Color(0xFFF97316)),
                    ],
                  ),
                  const Spacer(),
                  // Skip button
                  GestureDetector(
                    onTap: _navigateForward,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
                        ],
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                      ),
                      child: const Text(
                        'SKIP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9CA3AF),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ═══════ Slide Content ═══════
            Expanded(
              child: Stack(
                children: [
                  // Ambient glow behind hero area
                  Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 1.2,
                      height: MediaQuery.of(context).size.height * 0.35,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: slide.glowColor.withOpacity(0.18),
                            blurRadius: 100,
                            spreadRadius: 60,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // PageView for swiping
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _currentSlide = i),
                    itemBuilder: (context, index) {
                      final s = _slides[index];
                      return _SlideContent(
                        slide: s,
                        bounce1: _bounce1,
                        bounce2: _bounce2,
                        bounce3: _bounce3,
                      );
                    },
                  ),
                ],
              ),
            ),

            // ═══════ Dot Indicators ═══════
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final isActive = i == _currentSlide;
                  final activeColor = _slides[i].glowColor;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 32 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? activeColor : const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isActive
                          ? [BoxShadow(color: activeColor.withOpacity(0.5), blurRadius: 10)]
                          : null,
                    ),
                  );
                }),
              ),
            ),

            // ═══════ Bottom Button with Shimmer ═══════
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: GestureDetector(
                onTap: () {
                  if (_isLastSlide) {
                    _navigateForward();
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: slide.glowColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: slide.glowColor.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Shimmer sweep
                        AnimatedBuilder(
                          animation: _shimmerCtrl,
                          builder: (context, _) {
                            return Positioned(
                              left: -200 + _shimmerCtrl.value * (MediaQuery.of(context).size.width + 200),
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 120,
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
                          _isLastSlide ? 'Get Started' : 'Continue',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
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

// ═══════════════════════════════════════════════════════════════
// Slide Content Widget (Glass Orb + Orbit Icons + Text)
// ═══════════════════════════════════════════════════════════════
class _SlideContent extends StatelessWidget {
  final _SlideData slide;
  final AnimationController bounce1;
  final AnimationController bounce2;
  final AnimationController bounce3;

  const _SlideContent({
    required this.slide,
    required this.bounce1,
    required this.bounce2,
    required this.bounce3,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // ── Hero 3D element area ──
          SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Main Glass Orb
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: slide.gradientColors,
                    ),
                    border: Border.all(
                      color: slide.gradientColors[0].withOpacity(0.6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: slide.gradientColors[0].withOpacity(0.25),
                        blurRadius: 60,
                        offset: const Offset(0, 25),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Glass reflection
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.40),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Icon
                      Center(
                        child: Icon(
                          slide.mainIcon,
                          size: 72,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Orbit icon 1
                _buildOrbitChip(slide.orbit1, bounce1, 280),

                // Orbit icon 2
                _buildOrbitChip(slide.orbit2, bounce2, 280),

                // Orbit icon 3 (opt)
                if (slide.orbit3 != null)
                  _buildOrbitChip(slide.orbit3!, bounce3, 280),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // ── Title ──
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 16),

          // ── Subtitle ──
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildOrbitChip(_OrbitIcon orbit, AnimationController ctrl, double areaSize) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final bounceOffset = math.sin(ctrl.value * math.pi) * 8;
        return Positioned(
          left: orbit.dx * areaSize - 24,
          top: orbit.dy * areaSize - 24 + bounceOffset,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.70),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white),
                  boxShadow: [
                    BoxShadow(
                      color: orbit.color.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(orbit.icon, size: 24, color: orbit.color),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Data Models
// ═══════════════════════════════════════════════════════════════

class _SlideData {
  final String theme;
  final Color glowColor;
  final List<Color> gradientColors;
  final String title;
  final String subtitle;
  final IconData mainIcon;
  final _OrbitIcon orbit1;
  final _OrbitIcon orbit2;
  final _OrbitIcon? orbit3;

  const _SlideData({
    required this.theme,
    required this.glowColor,
    required this.gradientColors,
    required this.title,
    required this.subtitle,
    required this.mainIcon,
    required this.orbit1,
    required this.orbit2,
    this.orbit3,
  });
}

class _OrbitIcon {
  final IconData icon;
  final Color color;
  final double dx; // normalized position 0.0 – 1.0
  final double dy;

  const _OrbitIcon({
    required this.icon,
    required this.color,
    required this.dx,
    required this.dy,
  });
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
