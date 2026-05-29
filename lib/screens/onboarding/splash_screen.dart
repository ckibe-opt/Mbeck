import 'dart:ui';
import 'package:flutter/material.dart';

/// Ultra-premium animated splash screen with aurora mesh gradient,
/// glassmorphic 3D logo block, staggered text transitions, and sweep loader.
///
/// Shows for ~3.2s while the real start-screen future resolves in the background.
class SplashScreen extends StatefulWidget {
  /// The future that resolves to the widget the app should navigate to.
  final Future<Widget> Function() resolveDestination;

  const SplashScreen({super.key, required this.resolveDestination});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // — Animation controllers —
  late AnimationController _entranceCtrl;
  late AnimationController _orbCtrl;
  late AnimationController _phraseCtrl;
  late AnimationController _loaderCtrl;

  // — Phase state —
  bool _showContent = false;
  int _textPhase = 0; // 0 = "Mbeck", 1 = "Mbeck Business / Operating System"

  Widget? _destination;

  @override
  void initState() {
    super.initState();

    // Entrance (logo + orbs fade/scale in)
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Orb movement (slow continuous drift)
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // Text phrase switch
    _phraseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Bottom loader sweep
    _loaderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Kick off destination resolution immediately (runs in background)
    final destFuture = widget.resolveDestination();

    // 50ms — trigger entrance
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    setState(() => _showContent = true);
    _entranceCtrl.forward();

    // 1200ms — switch text phase
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _textPhase = 1);
    _phraseCtrl.forward();

    // Wait for destination + minimum splash time
    final results = await Future.wait([
      destFuture,
      Future.delayed(const Duration(milliseconds: 2000)),
    ]);
    _destination = results[0] as Widget;

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => _destination!,
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _orbCtrl.dispose();
    _phraseCtrl.dispose();
    _loaderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712), // gray-950
      body: Stack(
        children: [
          // ═══════════════════════════════════════════════════
          // LAYER 1: Animated Aurora Background
          // ═══════════════════════════════════════════════════
          _buildAuroraBackground(),

          // ═══════════════════════════════════════════════════
          // LAYER 2: Center Content (Logo + Text)
          // ═══════════════════════════════════════════════════
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGlassmorphicLogo(),
                const SizedBox(height: 48),
                _buildTextPhases(),
              ],
            ),
          ),

          // ═══════════════════════════════════════════════════
          // LAYER 3: Bottom Sweep Loader
          // ═══════════════════════════════════════════════════
          Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            child: Center(child: _buildSweepLoader()),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // Aurora mesh gradient background with 3 animated orbs
  // ────────────────────────────────────────────────────────
  Widget _buildAuroraBackground() {
    return AnimatedBuilder(
      animation: Listenable.merge([_entranceCtrl, _orbCtrl]),
      builder: (context, _) {
        final entrance = _entranceCtrl.value;
        final drift = _orbCtrl.value;

        return Stack(
          children: [
            // Emerald orb (top-right)
            Positioned(
              top: -MediaQuery.of(context).size.height * 0.15,
              right: -MediaQuery.of(context).size.width * 0.1 + drift * 20,
              child: _glowOrb(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.5,
                color: const Color(0xFF059669),
                opacity: 0.45 * entrance,
                blur: 100,
              ),
            ),
            // Indigo orb (bottom-left)
            Positioned(
              bottom: -MediaQuery.of(context).size.height * 0.1 - drift * 15,
              left: -MediaQuery.of(context).size.width * 0.2,
              child: _glowOrb(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.height * 0.4,
                color: const Color(0xFF4F46E5),
                opacity: 0.35 * entrance,
                blur: 80,
              ),
            ),
            // Purple orb (center-drift)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.2 + drift * 10,
              left: MediaQuery.of(context).size.width * 0.1,
              child: _glowOrb(
                width: MediaQuery.of(context).size.width * 0.5,
                height: MediaQuery.of(context).size.height * 0.35,
                color: const Color(0xFF7C3AED),
                opacity: 0.25 * entrance,
                blur: 120,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _glowOrb({
    required double width,
    required double height,
    required Color color,
    required double opacity,
    required double blur,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(opacity),
            blurRadius: blur,
            spreadRadius: blur * 0.5,
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // Glassmorphic 3D Logo Block
  // ────────────────────────────────────────────────────────
  Widget _buildGlassmorphicLogo() {
    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(_entranceCtrl.value);
        return Transform.scale(
          scale: 0.5 + 0.5 * t,
          child: Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - t)),
              child: child,
            ),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow pulse
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.20),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),

          // Glassmorphic frame
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 60,
                      offset: const Offset(0, 30),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Inner glass shine
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.30),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Inner emerald block with "MB"
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF34D399), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Text(
                            'MB',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -2,
                              height: 1,
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
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  // Staggered Text Phases
  // ────────────────────────────────────────────────────────
  Widget _buildTextPhases() {
    return SizedBox(
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Phase 0: "Mbeck"
          AnimatedOpacity(
            opacity: _textPhase == 0 && _showContent ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 600),
            child: AnimatedSlide(
              offset: _textPhase == 0 && _showContent
                  ? Offset.zero
                  : Offset(0, _textPhase > 0 ? -0.3 : 0.3),
              duration: const Duration(milliseconds: 600),
              child: const Text(
                'Mbeck',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // Phase 1: "Mbeck Business" + "Operating System"
          AnimatedOpacity(
            opacity: _textPhase == 1 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 600),
            child: AnimatedSlide(
              offset: _textPhase == 1
                  ? Offset.zero
                  : const Offset(0, 0.3),
              duration: const Duration(milliseconds: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFA7F3D0), // emerald-200
                        Colors.white,
                        Color(0xFFA7F3D0),
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'Mbeck Business',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'OPERATING SYSTEM',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF34D399).withOpacity(0.8),
                      letterSpacing: 3,
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

  // ────────────────────────────────────────────────────────
  // Bottom Sweep Loader
  // ────────────────────────────────────────────────────────
  Widget _buildSweepLoader() {
    return AnimatedOpacity(
      opacity: _showContent ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 800),
      child: SizedBox(
        width: 192,
        height: 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            children: [
              // Track
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Sweep bar
              AnimatedBuilder(
                animation: _loaderCtrl,
                builder: (context, _) {
                  final t = _loaderCtrl.value;
                  return Positioned(
                    left: (t - 0.3) * 192,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 96,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF10B981),
                            Color(0xFF6366F1),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
