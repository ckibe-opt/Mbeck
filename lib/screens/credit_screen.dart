import 'package:flutter/material.dart';
import '../services/credit_service.dart';
import '../services/event_service.dart';
import '../services/auth_service.dart';
import '../theme/design_system.dart';
import '../widgets/standard_app_bar.dart';

class CreditScreen extends StatefulWidget {
  const CreditScreen({super.key});

  @override
  State<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends State<CreditScreen> {
  Future<CreditProfile>? _scoreFuture;
  bool _hasConsent = false;
  bool _checkingConsent = true;

  @override
  void initState() {
    super.initState();
    _checkConsent();
  }

  Future<void> _checkConsent() async {
    setState(() => _checkingConsent = true);
    final events = await EventService.getEventsByType('CREDIT_CONSENT_GRANTED', limit: 1);
    final revokeEvents = await EventService.getEventsByType('CREDIT_CONSENT_REVOKED', limit: 1);
    
    bool hasConsent = false;
    if (events.isNotEmpty) {
      if (revokeEvents.isEmpty) {
        hasConsent = true;
      } else {
        // Check which one is newer
        hasConsent = events.first.timestamp > revokeEvents.first.timestamp;
      }
    }

    if (mounted) {
      setState(() {
        _hasConsent = hasConsent;
        _checkingConsent = false;
      });
      if (hasConsent) {
        _loadData();
      }
    }
  }

  Future<void> _grantConsent() async {
    try {
      await EventService.emitEvent(
        eventType: 'CREDIT_CONSENT_GRANTED',
        payload: {
          'scope': 'behavioral_risk_signals',
          'version': '2.0',
        },
      );
      if (mounted) {
        setState(() => _hasConsent = true);
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error granting consent: $e'))
        );
      }
    }
  }

  void _loadData() async {
    final shop = await AuthService.getCurrentShop();
    if (shop != null) {
      // Calculate
      final profile = await CreditService.calculateScore(shop.id);
      
      // Publish immediately (Fire & Forget)
      CreditService.publishToCloud(shop.id, profile.score, profile.tier);
      
      if (mounted) {
        setState(() {
          _scoreFuture = Future.value(profile);
        });
      }
    } else {
       // Fallback for mock/test
       setState(() {
        _scoreFuture = CreditService.calculateScore('test');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: const StandardAppBar(title: 'Partner Eligibility'),
      body: _checkingConsent
          ? const Center(child: CircularProgressIndicator())
          : !_hasConsent
              ? _buildConsentRequest()
              : _scoreFuture == null
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<CreditProfile>(
        future: _scoreFuture!,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}"));
          }

          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Score Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade900, Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [AppShadows.lg],
                ),
                child: Column(
                  children: [
                    const Text(
                      "Your Trust Score",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "${data.score}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20)
                      ),
                      child: Text(
                        data.tier,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Key Metrics
              Row(
                children: [
                  Expanded(child: _buildMetric("Active Days", "${data.activeDays}/30", Icons.calendar_today)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMetric("Monthly Sales", "K${(data.monthlyVolume/1000).toStringAsFixed(1)}k", Icons.bar_chart)),
                ],
              ),
              
              const SizedBox(height: 24),

              // Offer
              Text("Available Capital", style: AppTypography.textTheme.headlineMedium),
              const SizedBox(height: 12),
              
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Partner Eligibility Signal", style: TextStyle(color: Colors.grey)),
                              Text(
                                "KSh ${data.potentialLimit.toStringAsFixed(0)}", 
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)
                              ),
                            ],
                          ),
                          Icon(
                            data.potentialLimit > 0 ? Icons.lock_open : Icons.lock, 
                            color: data.potentialLimit > 0 ? AppColors.primaryGreen : Colors.grey,
                            size: 40
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: data.potentialLimit > 0 ? () {
                            // Navigate to Partner Offers (LoansScreen)
                             Navigator.pushNamed(context, '/loans');
                          } : null,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                          child: const Text("View Partner Offers"),
                        ),
                      ),
                      if (data.potentialLimit == 0)
                        const Padding(
                          padding: EdgeInsets.only(top: 12.0),
                          child: Text(
                            "Keep selling to build your risk profile!",
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                        )
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildConsentRequest() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 80, color: AppColors.info),
          const SizedBox(height: 24),
          Text(
            "Activate Financing Insights",
            style: AppTypography.textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            "MbeckApp is a behavioral risk signal provider. To see your eligibility for partner financing, we need your consent to analyze your shop activity and share aggregated scores with third-party lenders.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gray600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            "No PII or raw transactions are shared. Only Trust Scores and volume metrics.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gray500, fontSize: 13, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _grantConsent,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("I CONSENT & ACTIVATE", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200)
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.gray600),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
