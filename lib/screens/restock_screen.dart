
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/db_provider.dart';
import '../widgets/standard_app_bar.dart';
import '../services/security_service.dart';
import '../services/event_service.dart';
// ============================================================================
// OPTIMIZED RESTOCK SCREEN (restock_screen.dart)
// ============================================================================

class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  final _amountCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  final _securityService = SecurityService();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);
    
    try {
      final amount = int.parse(_amountCtrl.text.replaceAll(',', ''));
      final now = DateTime.now().millisecondsSinceEpoch;
      final details = 'Restock: ${_detailsCtrl.text.trim()}';
      
      final signature = await _securityService.signTransaction(
        timestamp: now,
        totalAmount: amount,
        type: 'outgoing',
        details: details,
      );

      // Emit event for consistency
      await EventService.emitEvent(
        eventType: 'EXPENSE',
        payload: {
          'type': 'outgoing',
          'amount': amount,
          'details': details,
          'receiptSignature': signature,
        },
        timestamp: now,
      );

      await DbProvider.insert('txn', {
        'type': 'outgoing', // Consistent with reports
        'totalAmount': amount,
        'details': details,
        'timestamp': now,
        'receiptSignature': signature,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restock expense recorded'),
            backgroundColor: Colors.green,
          )
        );
        Navigator.pop(context, true); // Signal success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StandardAppBar(
        title: 'Record Restock Expense',
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Record expenses for stock purchases, supplier payments, etc.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Amount Spent',
                prefixText: 'KSH ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)
                ),
                prefixIcon: const Icon(Icons.money_off),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                if ((int.tryParse(value) ?? 0) <= 0) {
                  return 'Amount must be greater than zero';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            
            TextFormField(
              controller: _detailsCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Details (e.g. Cables, Airtime, Supplies)',
                hintText: 'What did you buy?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)
                ),
                prefixIcon: const Icon(Icons.receipt_long),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter details';
                }
                return null;
              },
            ),
            const SizedBox(height: 40),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)
                ),
              ),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Icon(Icons.hourglass_empty, color: Colors.white, size: 20),
                  )
                : const Text(
                    'SAVE EXPENSE', 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 16
                    )
                  ),
            )
          ],
        ),
      ),
    );
  }
}
