import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/onboarding_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../theme/design_system.dart';
import '../phone_auth_screens.dart';
import '../home_screen.dart';
import 'shop_selection_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

enum _AuthMode { create, join, login, googleSetup, googleJoinSetup }

class _SignUpScreenState extends State<SignUpScreen> with TickerProviderStateMixin {
  _AuthMode _currentMode = _AuthMode.create;
  bool _isGoogleLoading = false;
  bool _isCreatingBranch = false;
  
  // Data from Google Auth response for setup
  String? _googleFullName;
  String? _googleEmail;

  late final AnimationController _bgController;
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    
    _checkExistingSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['isCreatingBranch'] == true) {
      _isCreatingBranch = true;
    }
  }

  void _checkExistingSession() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _googleFullName = user.userMetadata?['full_name'] as String? ?? '';
      _googleEmail = user.email ?? user.phone ?? '';
      
      if (_googleEmail!.isEmpty) _googleEmail = 'Authenticated Session';
      if (_googleFullName!.isEmpty && user.phone != null) {
        _googleFullName = 'Phone User';
      }

      _currentMode = _AuthMode.googleSetup; // Default if they navigated from select shop
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final response = await SupabaseAuthService.signInWithGoogle();
      if (response?.session != null && mounted) {
        final shops = await AuthService.getUserShops();
        if (shops.isNotEmpty) {
          if (shops.length == 1) {
            await AuthService.selectShop(shops.first.id);
            await OnboardingService.completeOnboardingForJoinedShop(shops.first.id);
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            }
          } else {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const ShopSelectionScreen()),
                (route) => false,
              );
            }
          }
        } else {
          if (mounted) {
            // New User: Prompt them to complete shop setup
            final fullName = response?.user?.userMetadata?['full_name'] as String? ?? '';
            final email = response?.user?.email ?? '';
            
            setState(() {
              _googleFullName = fullName;
              _googleEmail = email;
              if (_currentMode == _AuthMode.join) {
                _currentMode = _AuthMode.googleJoinSetup;
              } else {
                _currentMode = _AuthMode.googleSetup;
              }
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_currentMode == _AuthMode.googleJoinSetup
                    ? 'Authenticated with Google. Enter shop details to join.'
                    : 'Successfully authenticated with Google. Please complete your shop setup.'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-In failed: No valid session returned.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In failed/cancelled.'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Color get _accentColor {
    switch (_currentMode) {
      case _AuthMode.create:
      case _AuthMode.googleSetup:
      case _AuthMode.login:
        return const Color(0xFF10B981); // emerald
      case _AuthMode.join:
      case _AuthMode.googleJoinSetup:
        return const Color(0xFF3B82F6); // blue
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              final t = _bgController.value;
              return Positioned.fill(
                child: CustomPaint(
                  painter: _AuroraBackgroundPainter(t, _accentColor),
                ),
              );
            },
          ),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _entranceController,
                curve: Curves.easeOut,
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _entranceController,
                  curve: Curves.easeOutCubic,
                )),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 48),
                        _buildLogo(),
                        const SizedBox(height: 36),
                        _buildSegmentedToggle(),
                        const SizedBox(height: 28),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.08),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _currentMode == _AuthMode.googleSetup
                              ? _GoogleSetupForm(
                                  key: const ValueKey('googleSetup'),
                                  accentColor: _accentColor,
                                  initialName: _googleFullName ?? '',
                                  email: _googleEmail ?? '',
                                  onCancel: () => setState(() => _currentMode = _AuthMode.create),
                                )
                              : _currentMode == _AuthMode.googleJoinSetup
                                  ? _GoogleJoinSetupForm(
                                      key: const ValueKey('googleJoinSetup'),
                                      accentColor: _accentColor,
                                      initialName: _googleFullName ?? '',
                                      email: _googleEmail ?? '',
                                      onCancel: () => setState(() => _currentMode = _AuthMode.join),
                                    )
                                  : _currentMode == _AuthMode.create
                                      ? _CreateShopForm(key: const ValueKey('create'), accentColor: _accentColor)
                                      : _currentMode == _AuthMode.join
                                          ? _JoinShopForm(key: const ValueKey('join'), accentColor: _accentColor)
                                          : _LoginForm(key: const ValueKey('login'), accentColor: _accentColor),
                        ),
                        if (_currentMode != _AuthMode.googleSetup && _currentMode != _AuthMode.googleJoinSetup) ...[
                          const SizedBox(height: 28),
                          _buildDivider(),
                          const SizedBox(height: 20),
                          _buildGoogleButton(),
                          const SizedBox(height: 16),
                          _buildPhoneAuthLink(),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Glassmorphic logo container
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _accentColor,
                _accentColor.withValues(alpha: 0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _accentColor.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.store_rounded, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          _isCreatingBranch ? 'Register Secondary Branch' : 'Welcome to Mbeck',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isCreatingBranch ? 'Setup your new enterprise environment' : 'Manage your business with ease',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedToggle() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTab('Create', Icons.add_rounded, _AuthMode.create, const Color(0xFF10B981)),
          _buildTab('Join', Icons.group_add_rounded, _AuthMode.join, const Color(0xFF3B82F6)),
          _buildTab('Log In', Icons.login_rounded, _AuthMode.login, const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, _AuthMode targetMode, Color color) {
    final isSelected = _currentMode == targetMode ||
        (targetMode == _AuthMode.create && _currentMode == _AuthMode.googleSetup) ||
        (targetMode == _AuthMode.join && _currentMode == _AuthMode.googleJoinSetup);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            if (targetMode == _AuthMode.create) {
              setState(() => _currentMode = _AuthMode.googleSetup);
            } else if (targetMode == _AuthMode.join) {
              setState(() => _currentMode = _AuthMode.googleJoinSetup);
            } else {
              setState(() => _currentMode = targetMode);
            }
          } else {
            setState(() => _currentMode = targetMode);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFFE5E7EB))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 1.5),
          ),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFFE5E7EB))),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isGoogleLoading ? null : _handleGoogleSignIn,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGoogleLoading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                // Google "G" icon
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CustomPaint(painter: _GoogleLogoPainter()),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Continue with Google',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneAuthLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account?',
          style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneNumberScreen()));
          },
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF10B981),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text(
            'Log in with Phone',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Premium Input Field
// ============================================================
class _PremiumInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helper;
  final IconData icon;
  final bool obscureText;
  final bool showToggle;
  final VoidCallback? onToggle;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Color accentColor;

  const _PremiumInput({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.accentColor,
    this.helper,
    this.obscureText = false,
    this.showToggle = false,
    this.onToggle,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF9CA3AF),
              letterSpacing: 1.5,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w500),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 48),
            suffixIcon: showToggle
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 20,
                      color: const Color(0xFF9CA3AF),
                    ),
                    onPressed: onToggle,
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accentColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              helper!,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF)),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// Premium CTA Button
// ============================================================
class _PremiumButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final Color color;
  final VoidCallback? onPressed;

  const _PremiumButton({
    required this.label,
    required this.isLoading,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.85)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              else ...[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CREATE SHOP FORM
// ============================================================
class _CreateShopForm extends StatefulWidget {
  final Color accentColor;
  const _CreateShopForm({super.key, required this.accentColor});

  @override
  State<_CreateShopForm> createState() => _CreateShopFormState();
}

class _CreateShopFormState extends State<_CreateShopForm> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _userNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showAdminPassword = false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PremiumInput(
            controller: _businessNameController,
            label: 'Business Name *',
            hint: 'e.g., Mbeck Enterprise',
            icon: Icons.business_rounded,
            accentColor: widget.accentColor,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your business name' : null,
          ),
          const SizedBox(height: 16),
          _PremiumInput(
            controller: _userNameController,
            label: 'Your Name *',
            hint: 'e.g., John Doe',
            icon: Icons.person_rounded,
            accentColor: widget.accentColor,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 16),
          _PremiumInput(
            controller: _passwordController,
            label: 'Shop Password *',
            hint: 'For all staff to join',
            helper: 'Share this with all employees',
            icon: Icons.lock_rounded,
            accentColor: widget.accentColor,
            obscureText: !_showPassword,
            showToggle: true,
            onToggle: () => setState(() => _showPassword = !_showPassword),
            validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
          ),
          const SizedBox(height: 16),
          _PremiumInput(
            controller: _adminPasswordController,
            label: 'Admin Password *',
            hint: 'For managers only',
            helper: 'Share only with trusted managers',
            icon: Icons.shield_rounded,
            accentColor: widget.accentColor,
            obscureText: !_showAdminPassword,
            showToggle: true,
            onToggle: () => setState(() => _showAdminPassword = !_showAdminPassword),
            validator: (v) => (v == null || v.length < 8) ? 'Admin password must be at least 8 characters' : null,
          ),
          const SizedBox(height: 24),
          _PremiumButton(
            label: 'Create Shop',
            isLoading: _isLoading,
            color: widget.accentColor,
            onPressed: _createShop,
          ),
        ],
      ),
    );
  }

  Future<void> _createShop() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final shop = await AuthService.createShop(
        businessName: _businessNameController.text.trim(),
        password: _passwordController.text,
        adminPassword: _adminPasswordController.text,
        userName: _userNameController.text.trim(),
      );
      if (shop != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome to ${shop.businessName}!'), backgroundColor: AppColors.success),
        );
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _adminPasswordController.dispose(); // Fixed: was missing before
    super.dispose();
  }
}

// ============================================================
// GOOGLE SETUP FORM
// ============================================================
class _GoogleSetupForm extends StatefulWidget {
  final Color accentColor;
  final String initialName;
  final String email;
  final VoidCallback onCancel;

  const _GoogleSetupForm({
    super.key,
    required this.accentColor,
    required this.initialName,
    required this.email,
    required this.onCancel,
  });

  @override
  State<_GoogleSetupForm> createState() => _GoogleSetupFormState();
}

class _GoogleSetupFormState extends State<_GoogleSetupForm> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  late final TextEditingController _userNameController;
  final _passwordController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showAdminPassword = false;

  @override
  void initState() {
    super.initState();
    _userNameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createShop() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final shop = await AuthService.createShop(
        businessName: _businessNameController.text.trim(),
        password: _passwordController.text,
        adminPassword: _adminPasswordController.text,
        userName: _userNameController.text.trim(),
      );
      if (shop != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome to ${shop.businessName}!'), backgroundColor: AppColors.success),
        );
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              border: Border.all(color: const Color(0xFFBBF7D0)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google account connected',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF065F46)),
                      ),
                      Text(
                        widget.email,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _PremiumInput(
            controller: _businessNameController,
            label: 'Business Name *',
            hint: 'e.g., Mbeck Enterprise',
            icon: Icons.business_rounded,
            accentColor: widget.accentColor,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your business name' : null,
          ),
          const SizedBox(height: 16),
          _PremiumInput(
            controller: _userNameController,
            label: 'Your Name *',
            hint: 'e.g., John Doe',
            icon: Icons.person_rounded,
            accentColor: widget.accentColor,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 16),
          _PremiumInput(
            controller: _passwordController,
            label: 'Shop Password *',
            hint: 'For all staff to join',
            helper: 'Share this with all employees',
            icon: Icons.lock_rounded,
            accentColor: widget.accentColor,
            obscureText: !_showPassword,
            showToggle: true,
            onToggle: () => setState(() => _showPassword = !_showPassword),
            validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
          ),
          const SizedBox(height: 16),
          _PremiumInput(
            controller: _adminPasswordController,
            label: 'Admin Password *',
            hint: 'For managers only',
            helper: 'Share only with trusted managers',
            icon: Icons.shield_rounded,
            accentColor: widget.accentColor,
            obscureText: !_showAdminPassword,
            showToggle: true,
            onToggle: () => setState(() => _showAdminPassword = !_showAdminPassword),
            validator: (v) => (v == null || v.length < 8) ? 'Admin password must be at least 8 characters' : null,
          ),
          const SizedBox(height: 24),
          _PremiumButton(
            label: 'Complete Setup',
            isLoading: _isLoading,
            color: widget.accentColor,
            onPressed: _createShop,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Cancel Request', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// JOIN SHOP FORM
// ============================================================
class _JoinShopForm extends StatefulWidget {
  final Color accentColor;
  const _JoinShopForm({super.key, required this.accentColor});

  @override
  State<_JoinShopForm> createState() => _JoinShopFormState();
}

class _JoinShopFormState extends State<_JoinShopForm> {
  final _formKey = GlobalKey<FormState>();
  final _shopIdController = TextEditingController();
  final _userNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _joinAsManager = false;
  bool _showPassword = false;
  bool _showAdminPassword = false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PremiumInput(
            controller: _shopIdController,
            label: 'Shop ID *',
            hint: 'e.g., shop_1234567890_5678',
            icon: Icons.store_rounded,
            accentColor: widget.accentColor,
            keyboardType: TextInputType.text,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter shop ID' : null,
          ),
          const SizedBox(height: 16),
          _PremiumInput(
            controller: _userNameController,
            label: 'Your Name *',
            hint: 'e.g., Jane Smith',
            icon: Icons.person_rounded,
            accentColor: widget.accentColor,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 16),
          _PremiumInput(
            controller: _passwordController,
            label: 'Shop Password *',
            hint: 'Enter shop password',
            icon: Icons.lock_rounded,
            accentColor: widget.accentColor,
            obscureText: !_showPassword,
            showToggle: true,
            onToggle: () => setState(() => _showPassword = !_showPassword),
            validator: (v) => (v == null || v.isEmpty) ? 'Please enter shop password' : null,
          ),
          const SizedBox(height: 20),

          // Role selection
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'JOIN AS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF9CA3AF),
                letterSpacing: 1.5,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _RoleCard(
                  title: 'Manager',
                  subtitle: 'Full operations access',
                  icon: Icons.shield_rounded,
                  isSelected: _joinAsManager,
                  selectedColor: const Color(0xFF10B981),
                  onTap: () => setState(() => _joinAsManager = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoleCard(
                  title: 'Employee',
                  subtitle: 'Basic access',
                  icon: Icons.person_rounded,
                  isSelected: !_joinAsManager,
                  selectedColor: const Color(0xFF3B82F6),
                  onTap: () => setState(() => _joinAsManager = false),
                ),
              ),
            ],
          ),

          // Admin password (conditional)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _joinAsManager
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _PremiumInput(
                      controller: _adminPasswordController,
                      label: 'Admin Password *',
                      hint: 'Enter admin password',
                      helper: 'Required for manager access',
                      icon: Icons.vpn_key_rounded,
                      accentColor: widget.accentColor,
                      obscureText: !_showAdminPassword,
                      showToggle: true,
                      onToggle: () => setState(() => _showAdminPassword = !_showAdminPassword),
                      validator: (v) =>
                          (_joinAsManager && (v == null || v.isEmpty)) ? 'Please enter admin password' : null,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),
          _PremiumButton(
            label: 'Join Shop',
            isLoading: _isLoading,
            color: widget.accentColor,
            onPressed: _joinShop,
          ),
        ],
      ),
    );
  }

  Future<void> _joinShop() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final shopId = _shopIdController.text.trim();
      final shop = await AuthService.joinShop(
        shopId: shopId,
        password: _passwordController.text,
        adminPassword: _joinAsManager ? _adminPasswordController.text : null,
        userName: _userNameController.text.trim(),
        joinAsManager: _joinAsManager,
      );
      if (shop != null && mounted) {
        await OnboardingService.completeOnboardingForJoinedShop(shopId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome to ${shop.businessName}!'), backgroundColor: AppColors.success),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _shopIdController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }
}

// ============================================================
// GOOGLE JOIN SETUP FORM
// ============================================================
class _GoogleJoinSetupForm extends StatefulWidget {
  final Color accentColor;
  final String initialName;
  final String email;
  final VoidCallback onCancel;

  const _GoogleJoinSetupForm({
    super.key,
    required this.accentColor,
    required this.initialName,
    required this.email,
    required this.onCancel,
  });

  @override
  State<_GoogleJoinSetupForm> createState() => _GoogleJoinSetupFormState();
}

class _GoogleJoinSetupFormState extends State<_GoogleJoinSetupForm> {
  final _formKey = GlobalKey<FormState>();
  final _shopIdController = TextEditingController();
  late final TextEditingController _userNameController;
  final _passwordController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _joinAsManager = false;
  bool _showPassword = false;
  bool _showAdminPassword = false;

  @override
  void initState() {
    super.initState();
    _userNameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _shopIdController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _joinShop() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final shopId = _shopIdController.text.trim();
      final shop = await AuthService.joinShop(
        shopId: shopId,
        password: _passwordController.text,
        adminPassword: _joinAsManager ? _adminPasswordController.text : null,
        userName: _userNameController.text.trim(),
        joinAsManager: _joinAsManager,
      );
      if (shop != null && mounted) {
        await OnboardingService.completeOnboardingForJoinedShop(shopId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome to ${shop.businessName}!'), backgroundColor: AppColors.success),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.accentColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.g_mobiledata_rounded, size: 32, color: widget.accentColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.email.isNotEmpty && widget.email.contains('+') ? 'Signed in via Phone' : 'Signed in securely',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6B7280)),
                      ),
                      Text(
                        widget.email,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _PremiumInput(
            controller: _shopIdController,
            label: 'Shop ID *',
            hint: 'e.g., shop_1234567890_5678',
            icon: Icons.store_rounded,
            accentColor: widget.accentColor,
            keyboardType: TextInputType.text,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter shop ID' : null,
          ),
          const SizedBox(height: 16),
          _PremiumInput(
            controller: _userNameController,
            label: 'Your Name *',
            hint: 'e.g., Jane Smith',
            icon: Icons.person_rounded,
            accentColor: widget.accentColor,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 16),
          _PremiumInput(
            controller: _passwordController,
            label: 'Shop Password *',
            hint: 'Enter shop password',
            icon: Icons.lock_rounded,
            accentColor: widget.accentColor,
            obscureText: !_showPassword,
            showToggle: true,
            onToggle: () => setState(() => _showPassword = !_showPassword),
            validator: (v) => (v == null || v.isEmpty) ? 'Please enter shop password' : null,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'JOIN AS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF9CA3AF),
                letterSpacing: 1.5,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _RoleCard(
                  title: 'Manager',
                  subtitle: 'Full operations access',
                  icon: Icons.shield_rounded,
                  isSelected: _joinAsManager,
                  selectedColor: const Color(0xFF10B981),
                  onTap: () => setState(() => _joinAsManager = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoleCard(
                  title: 'Employee',
                  subtitle: 'Basic access',
                  icon: Icons.person_rounded,
                  isSelected: !_joinAsManager,
                  selectedColor: const Color(0xFF3B82F6),
                  onTap: () => setState(() => _joinAsManager = false),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _joinAsManager
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _PremiumInput(
                      controller: _adminPasswordController,
                      label: 'Admin Password *',
                      hint: 'Enter admin password',
                      helper: 'Required for manager access',
                      icon: Icons.vpn_key_rounded,
                      accentColor: widget.accentColor,
                      obscureText: !_showAdminPassword,
                      showToggle: true,
                      onToggle: () => setState(() => _showAdminPassword = !_showAdminPassword),
                      validator: (v) =>
                          (_joinAsManager && (v == null || v.isEmpty)) ? 'Please enter admin password' : null,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          _PremiumButton(
            label: 'Join Shop',
            isLoading: _isLoading,
            color: widget.accentColor,
            onPressed: _joinShop,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF9CA3AF)),
            child: const Text('Cancel & Start Over', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LOGIN FORM
// ============================================================
class _LoginForm extends StatefulWidget {
  final Color accentColor;
  const _LoginForm({super.key, required this.accentColor});

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _shopIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PremiumInput(
            controller: _shopIdController,
            label: 'Shop ID *',
            hint: 'e.g., shop_1234567890_5678',
            icon: Icons.store_rounded,
            accentColor: widget.accentColor,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter shop ID' : null,
          ),
          const SizedBox(height: 16),
          _PremiumInput(
            controller: _passwordController,
            label: 'Password *',
            hint: 'Enter shop or admin password',
            icon: Icons.lock_rounded,
            accentColor: widget.accentColor,
            obscureText: !_showPassword,
            showToggle: true,
            onToggle: () => setState(() => _showPassword = !_showPassword),
            validator: (v) => (v == null || v.isEmpty) ? 'Please enter password' : null,
          ),
          const SizedBox(height: 24),
          _PremiumButton(
            label: 'Log In',
            isLoading: _isLoading,
            color: widget.accentColor,
            onPressed: _loginToShop,
          ),
        ],
      ),
    );
  }

  Future<void> _loginToShop() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final shopId = _shopIdController.text.trim();
      final shop = await AuthService.login(shopId: shopId, password: _passwordController.text);
      if (shop != null && mounted) {
        await OnboardingService.completeOnboardingForJoinedShop(shopId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome back to ${shop.businessName}!'), backgroundColor: AppColors.success),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _shopIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// ============================================================
// Role Card (for Join)
// ============================================================
class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? selectedColor : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: selectedColor.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? selectedColor.withValues(alpha: 0.12) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 24, color: isSelected ? selectedColor : const Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isSelected ? selectedColor : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Aurora Background Painter
// ============================================================
class _AuroraBackgroundPainter extends CustomPainter {
  final double t;
  final Color accent;

  _AuroraBackgroundPainter(this.t, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Base gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0.06),
          accent.withValues(alpha: 0.02),
          const Color(0xFFF8FAFB),
        ],
        stops: const [0.0, 0.35, 0.7],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Floating orb 1
    final orb1 = Paint()
      ..color = accent.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    canvas.drawCircle(
      Offset(size.width * (0.2 + 0.15 * sin(t * 2 * pi)), size.height * 0.15),
      80,
      orb1,
    );

    // Floating orb 2
    final orb2 = Paint()
      ..color = accent.withValues(alpha: 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    canvas.drawCircle(
      Offset(size.width * (0.8 - 0.1 * cos(t * 2 * pi)), size.height * 0.08),
      60,
      orb2,
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraBackgroundPainter old) => old.t != t || old.accent != accent;
}

// ============================================================
// Google Logo Painter
// ============================================================
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Blue
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -0.5, 1.5, true, bluePaint);

    // Green
    final greenPaint = Paint()..color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 1.0, 1.2, true, greenPaint);

    // Yellow
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 2.2, 1.0, true, yellowPaint);

    // Red
    final redPaint = Paint()..color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.7, 1.2, true, redPaint);

    // White center cutout
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.55, whitePaint);

    // Blue bar (right extension)
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 1, center.dy - radius * 0.15, radius * 1.1, radius * 0.3),
      bluePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 1, center.dy - radius * 0.15, radius * 0.55, radius * 0.3),
      whitePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
