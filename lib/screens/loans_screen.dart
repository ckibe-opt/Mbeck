import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/credit_service.dart';
import '../services/event_service.dart';
import '../theme/design_system.dart';
import '../widgets/standard_app_bar.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  bool _loading = true;
  bool _hasConsented = false;
  CreditProfile? _profile;

  @override
  void initState() {
    super.initState();
    _checkConsent();
  }

  Future<void> _checkConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final consented = prefs.getBool('credit_consent_granted') ?? false;
    
    if (consented) {
      _hasConsented = true;
      _loadProfile();
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _grantConsent() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('credit_consent_granted', true);
    
    // Policy 3.2: Explicit Consent Audit Trail
    await EventService.emitEvent(
      eventType: 'CONSENT',
      payload: {
        'action': 'CREDIT_CONSENT_GRANTED',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );

    _hasConsented = true;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await CreditService.getCreditProfileCached();
    if (mounted) {
      setState(() {
        _profile = profile;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const StandardAppBar(title: "Partner Financing"),
      body: _loading
          ? AppSkeleton.screen()
          : (!_hasConsented 
              ? _buildConsentWall() 
              : _buildMainContent()),
    );
  }

  Widget _buildConsentWall() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.privacy_tip_outlined, size: 80, color: Colors.blue.shade700),
          const SizedBox(height: 24),
          const Text(
            "Behavioral Risk Signal Provider",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            "MbeckApp is not a lender. To view your eligibility for third-party partner financing, you must agree to share your shop's aggregated consistency and volume metrics with our lending partners.",
            style: TextStyle(fontSize: 16, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
              onPressed: _grantConsent,
              child: const Text("I AGREE TO SHARE METRICS", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Mbeck never shares your personal identity, raw transaction items, or AI vectors.",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          )
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final double score = (_profile?.score ?? 0).toDouble();
    final bool isEligible = score > 50; 
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEligibilityHeader(isEligible, score),
          const SizedBox(height: 32),
          const Text("Available Partner Offers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildLoanOfferCard(isEligible),
          
          if (!isEligible) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(child: Text("Eligibility is determined by third-party lenders. Keep recording consistent daily sales to improve your risk signal.", style: TextStyle(color: Colors.orange, fontSize: 13))),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildEligibilityHeader(bool isEligible, double score) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isEligible 
            ? [Colors.blue.shade800, Colors.blue.shade500]
            : [Colors.grey.shade700, Colors.grey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(
            "PARTNER ELIGIBILITY SIGNAL",
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            isEligible ? "HIGH" : "BUILDING",
            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
            child: Text(
              "Trust Score: ${score.toStringAsFixed(0)} / 100",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanOfferCard(bool isEligible) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.inventory_2, color: Colors.green),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Partner Stock Financing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Powered by third-party lenders", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Column(
                children: [
                  Text("⚠️ PILOT PHASE", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10)),
                  SizedBox(height: 4),
                  Text(
                    "MbeckApp is currently onboarding lending partners. Your score is being recorded but financing is not yet disbursed.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: null, // Always disabled until partners integrate
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.grey,
                ),
                child: Text(isEligible ? "AWAITING PARTNER REVIEW" : "LOCKED (Low Signal)"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
