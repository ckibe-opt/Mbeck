import 'package:flutter/material.dart';
import '../db/db_provider.dart';
import '../services/event_service.dart';
import '../theme/design_system.dart';
import '../services/security_service.dart';

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  _IncomeScreenState createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final _detailsController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  final _securityService = SecurityService();

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveIncome() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final totalAmount = double.parse(_amountController.text);
      final now = DateTime.now().millisecondsSinceEpoch;

      String finalDetails = _detailsController.text.trim();
      if (finalDetails.isEmpty) finalDetails = 'Income Transaction';

      final signature = await _securityService.signTransaction(
        timestamp: now,
        totalAmount: totalAmount.toInt(),
        type: 'incoming',
        details: finalDetails,
      );

      final eventPayload = {
        'type': 'incoming',
        'amount': totalAmount,
        'items': [],
        'receiptSignature': signature,
        'details': finalDetails,
        'totalAmount': totalAmount,
        'itemId': null,
        'itemName': finalDetails,
      };

      await EventService.emitEvent(
        eventType: 'INCOME',
        payload: eventPayload,
        timestamp: now,
      );

      await DbProvider.insert('txn', {
        'type': 'incoming',
        'totalAmount': totalAmount,
        'details': finalDetails,
        'timestamp': now,
        'receiptSignature': signature,
      });

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Income recorded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountText = _amountController.text;
    final parsedAmount = double.tryParse(amountText);
    final amountPreview = parsedAmount != null ? 'KES ${parsedAmount.toStringAsFixed(0)}' : 'KES 0';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // ─── App Bar ─────────────────────
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF6B7280), size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text('Record Income', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5)),
                  ],
                ),
              ),
            ),
          ),
          // ─── Content ─────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Amount preview
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Text('AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF9CA3AF), letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text(amountPreview, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF10B981), height: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Amount field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF3F4F6)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
                    ),
                    child: TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                        prefixText: 'KES ',
                        prefixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter an amount';
                        if (double.tryParse(value) == null) return 'Please enter a valid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Details field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF3F4F6)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
                    ),
                    child: TextFormField(
                      controller: _detailsController,
                      decoration: InputDecoration(
                        labelText: 'Details (Optional)',
                        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                        hintText: 'e.g. "Rent payment" or "Salary"',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFD1D5DB)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ─── Save Button ─────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: GestureDetector(
                onTap: _isSaving ? null : _saveIncome,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _isSaving ? const Color(0xFF9CA3AF) : const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _isSaving ? null : [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_isSaving ? Icons.hourglass_empty : Icons.check_circle_outline, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(_isSaving ? 'SAVING...' : 'SAVE INCOME', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
