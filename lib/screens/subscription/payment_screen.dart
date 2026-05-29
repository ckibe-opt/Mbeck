import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/subscription_service.dart';
import '../../services/mpesa_service.dart';
import '../../theme/design_system.dart';
import '../../widgets/standard_app_bar.dart';

class PaymentScreen extends StatefulWidget {
  final String tier;
  final int amount;
  final Color planColor;
  final String? moduleId; // Optional: for module-specific payments

  const PaymentScreen({
    super.key,
    required this.tier,
    required this.amount,
    required this.planColor,
    this.moduleId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}


class _PaymentScreenState extends State<PaymentScreen> {
  final _phoneController = TextEditingController(text: '254');
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: CustomScrollView(
        slivers: [
          // Premium Hero Header
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: widget.planColor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.planColor.withValues(alpha: 0.8),
                      widget.planColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Stack(
                    children: [
                      // Decorative background circles
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 10),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  child: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Secure Checkout',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Complete your upgrade to ${widget.tier}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Main Checkout Form Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Order Summary Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: widget.planColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.workspace_premium, color: widget.planColor, size: 28),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Text(
                                'Order Summary',
                                style: AppTypography.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _buildSummaryRow('Plan', widget.tier),
                          _buildSummaryRow('Billing Cycle', widget.tier.contains('Yearly') ? 'Annually' : 'Monthly'),
                          const Divider(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: AppTypography.textTheme.headlineMedium?.copyWith(
                                  color: AppColors.gray700,
                                ),
                              ),
                              Text(
                                'KSH ${widget.amount}',
                                style: AppTypography.textTheme.displayLarge?.copyWith(
                                  color: widget.planColor,
                                  fontSize: 28,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // M-Pesa Input Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Payment Method Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppRadii.md),
                                ),
                                child: const Icon(
                                  Icons.phone_android,
                                  color: AppColors.success,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'M-Pesa Express',
                                style: AppTypography.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: AppSpacing.lg),

                          // Phone Number Input
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1),
                            decoration: InputDecoration(
                              labelText: 'M-Pesa Phone Number',
                              hintText: '254712345678',
                              prefixIcon: const Icon(Icons.phone, color: AppColors.success),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                borderSide: BorderSide(color: AppColors.gray300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                borderSide: BorderSide(color: AppColors.gray300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                borderSide: const BorderSide(color: AppColors.success, width: 2),
                              ),
                              filled: true,
                              fillColor: AppColors.gray50,
                              helperText: 'Your phone number in international format',
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(12),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your M-Pesa number';
                              }
                              if (!value.startsWith('254')) {
                                return 'Phone number must start with 254';
                              }
                              if (value.length != 12) {
                                return 'Phone number must be 12 digits (254XXXXXXXXX)';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          // Pay Now Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isProcessing ? null : _initiatePayment,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.gray300,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadii.full),
                                ),
                                elevation: 4,
                                shadowColor: AppColors.success.withValues(alpha: 0.5),
                              ),
                              child: _isProcessing
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.payment, size: 24),
                                        const SizedBox(width: AppSpacing.sm),
                                        Text(
                                          'PAY KSH ${widget.amount} NOW',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Support Contact
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.gray200.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.support_agent, color: AppColors.gray700),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Need help with payment?',
                                  style: AppTypography.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.gray800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                      const ClipboardData(text: '0701414257'),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Phone number copied!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'WhatsApp: 0701414257 (Tap to copy)',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: AppColors.gray600,
            ),
          ),
          Text(
            value,
            style: AppTypography.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(int step, String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              instruction,
              style: AppTypography.textTheme.bodySmall?.copyWith(
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initiatePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      // 1. Show waiting dialog immediately
      if (!mounted) return;
      
      // Store reference to dialog context to close it later
      BuildContext? dialogContext;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primaryGreen),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Initiating M-Pesa...',
                  style: AppTypography.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Please wait for the STK Push on your phone',
                  textAlign: TextAlign.center,
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: AppColors.gray600,
                  ),
                ),
              ],
            ),
          );
        },
      );

      // 1b. Log Pending Transaction (Linkage)
      final shopId = await AuthService.getShopId();
      if (mounted) {
        await SubscriptionService.recordMpesaPending(
          shopId: shopId,
          amount: widget.amount.toDouble(),
          accountReference: widget.moduleId != null ? 'Module-${widget.moduleId}' : 'Upgrade-${widget.tier}',
          phoneNumber: _phoneController.text.trim(),
        );
      }

      // 2. Trigger STK Push
      final result = await MpesaService.initiateSTKPush(
        phoneNumber: _phoneController.text.trim(),
        amount: widget.amount.toDouble(),
        accountReference: widget.moduleId != null ? 'Module-${widget.moduleId}' : 'Upgrade-${widget.tier}',
        transactionDesc: 'Mbeck payment',
      );

      // Close initiating dialog
      if (dialogContext != null && mounted) {
        Navigator.of(dialogContext!).pop(); 
      }

      if (result['success'] == true) {
        final checkoutReqId = result['checkoutRequestId'];
        final merchantReqId = result['merchantRequestId'];
        final customerMsg = result['customerMessage'] ?? 'STK Push sent!';

        // 2b. Update with Checkout Request ID
        if (mounted) {
           await SubscriptionService.updateCheckoutId(
            shopId: shopId,
            checkoutRequestId: checkoutReqId,
            merchantRequestId: merchantReqId ?? '',
          );
        }

        if (!mounted) return;

        // 3. Show "Check Status" Dialog
        await _showPollingDialog(checkoutReqId, customerMsg);

      } else {
        throw Exception(result['error'] ?? 'STK Push failed to start');
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Error: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showPollingDialog(String checkoutReqId, String message) async {
    bool isPolling = true;
    int polls = 0;
    const maxPolls = 20; // 5 seconds * 20 = ~100 seconds timeout

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Auto-poll loop
          if (polls == 0) {
            Future.doWhile(() async {
              if (!isPolling || !mounted) return false;
              
              await Future.delayed(const Duration(seconds: 5));
              polls++;

              final status = await MpesaService.querySTKStatus(checkoutRequestId: checkoutReqId);
              
              if (status['success'] == true) {
                // Determine actual state from M-Pesa ResultCode
                final code = status['resultCode'].toString();
                if (code == '0') {
                  // SUCCESS!
                  isPolling = false;
                  if (mounted) Navigator.of(ctx).pop(); // Close polling dialog
                  _handlePaymentSuccess(); // Proceed to success screen
                  return false;
                } else if (code != '0' && code != '1032' && code != '1037') {
                  // 1032=Cancelled, 1037=Timeout... Others might be failure
                  // But for "Pending/Processing", the API usually returns error or a specific code?
                  // Actually M-Pesa query returns errorCode if transaction not found/processing.
                  // If result code is present, transaction is final.
                  isPolling = false;
                  if (mounted) Navigator.of(ctx).pop();
                  _showErrorDialog('Transaction Failed: ${status['resultDesc']}');
                  return false;
                }
              } else {
                 // API Error or Transaction still processing (often returns error if "not found" yet)
                 // Keep polling
              }

              if (polls >= maxPolls) {
                isPolling = false;
                if (mounted) Navigator.of(ctx).pop();
                _showErrorDialog('Payment timeout. Please check your messages.');
                return false;
              }
              
              return isPolling;
            });
          }

          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Waiting for PIN...', style: AppTypography.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    isPolling = false;
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Cancel / Checked Manually'),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment Issue'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  Future<void> _handlePaymentSuccess() async {
      // Record in Supabase
      try {
        final shopId = await AuthService.getShopId();
        if (shopId != null) {
          final supabase = Supabase.instance.client;
          
          if (widget.moduleId != null) {
             // Module
             await SubscriptionService.recordPayment(
              transactionId: 'MPESA_${DateTime.now().millisecondsSinceEpoch}',
              amount: widget.amount.toDouble(),
              method: 'mpesa',
            );
          } else {
            // Tier Upgrade
             await supabase.from('shops').update({
              'subscription_tier': widget.tier,
              'subscription_status': 'ACTIVE',
              'trial_ends_at': null,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', shopId);
          }
        }
      } catch (e) {
        debugPrint('⚠️ DB Update Failed: $e');
      }

      if (!mounted) return;

      // Show Success UI
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppColors.success, size: 64),
          title: const Text('Payment Successful!'),
          content: Text('Your payment of KES ${widget.amount} was received.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Dialog
                Navigator.pop(context); // Payment Screen
                Navigator.pop(context); // Pricing Screen
              }, 
              child: const Text('CONTINUE')
            )
          ],
        ),
      );
  }
}
