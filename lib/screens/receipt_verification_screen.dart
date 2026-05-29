import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/security_service.dart';
import '../services/onboarding_service.dart';
import '../db/db_provider.dart';
import '../theme/design_system.dart';
import '../widgets/standard_app_bar.dart';
import 'retail/returns_screen.dart';
import '../widgets/interactive_help_scroll.dart';

class ReceiptVerificationScreen extends StatefulWidget {
  const ReceiptVerificationScreen({super.key});

  @override
  State<ReceiptVerificationScreen> createState() => _ReceiptVerificationScreenState();
}

class _ReceiptVerificationScreenState extends State<ReceiptVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _securityService = SecurityService();

  bool _isVerifying = false;
  List<String> _enabledModules = [];

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    final modules = await OnboardingService.getSelectedModules();
    if (mounted) {
      setState(() => _enabledModules = modules);
    }
  }

  Future<void> _verifyReceipt() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isVerifying = true);

    try {
      final double amount = double.parse(_amountController.text.trim());
      final String refCode = _refController.text.trim();

      // The ref code displayed on receipts is the LAST 6 digits of the timestamp.
      final results = await DbProvider.query(
        'txn',
        where: 'CAST(timestamp AS TEXT) LIKE ? AND totalAmount = ?',
        whereArgs: ['%$refCode', amount.toInt()],
        limit: 1,
      );

      if (results.isEmpty) {
        if (mounted) _showResultPopup(isValid: false, message: 'No matching receipt found for this reference and amount.');
        return;
      }

      final txn = results.first;
      final storedSig = txn['receiptSignature']?.toString() ?? '';
      final fullTimestamp = txn['timestamp'] as int;
      final txnDetails = txn['details']?.toString();
      final txnId = txn['id'];

      // Fetch line items for this transaction
      List<Map<String, dynamic>> lineItems = [];
      if (txnId != null) {
        lineItems = await DbProvider.queryRaw(
          '''SELECT ti.quantity, ti.unitPrice, ti.subtotal,
                    COALESCE(i.name, 'Item') AS itemName
             FROM transaction_items ti
             LEFT JOIN inventory i ON i.id = ti.itemId
             WHERE ti.transactionId = ?''',
          [txnId],
        );
      }

      if (storedSig.isEmpty) {
        if (mounted) _showResultPopup(isValid: true, transaction: txn, lineItems: lineItems, message: 'Receipt found (unsigned legacy record).');
        return;
      }

      // Verify the stored signature using the FULL timestamp and details from DB
      bool valid = false;
      for (final type in ['sale', 'incoming', 'outgoing']) {
        valid = await _securityService.verifySignature(
          timestamp: fullTimestamp,
          totalAmount: amount.toInt(),
          type: type,
          signature: storedSig,
          details: txnDetails,
        );
        if (valid) break;
      }

      if (mounted) {
        _showResultPopup(
          isValid: valid,
          transaction: txn,
          lineItems: lineItems,
          message: valid
              ? 'This receipt was verified as authentic.'
              : 'Record found but signature mismatch — receipt may have been tampered with.',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showResultPopup({
    required bool isValid,
    Map<String, dynamic>? transaction,
    List<Map<String, dynamic>>? lineItems,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isValid ? Colors.green.shade50 : Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isValid ? Icons.verified : Icons.cancel,
                      color: isValid ? Colors.green : Colors.red,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    isValid ? 'AUTHENTIC RECEIPT' : 'INVALID RECEIPT',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isValid ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Message
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isValid ? Colors.green.shade600 : Colors.red.shade600,
                    ),
                  ),

                  // Transaction details
                  if (transaction != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    _popupDetailRow(Icons.calendar_today, 'Date',
                        DateFormat.yMMMd().add_jm().format(
                            DateTime.fromMillisecondsSinceEpoch(transaction['timestamp']))),
                    _popupDetailRow(
                      Icons.shopping_bag_outlined,
                      'Type',
                      _getModuleAwareType(transaction['type']?.toString() ?? 'sale'),
                    ),
                    if (transaction['source_module'] != null)
                      _popupDetailRow(Icons.category_outlined, 'Module',
                          transaction['source_module'].toString().toUpperCase()),

                    // Line items (items purchased)
                    if (lineItems != null && lineItems.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Items Purchased',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(height: 8),
                      ...lineItems.map((item) {
                        final name = item['itemName'] ?? 'Item';
                        final qty = item['quantity'] ?? 1;
                        final subtotal = item['subtotal'] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('$name x$qty',
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              Text('KES ${NumberFormat('#,##0').format(subtotal)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                    ] else if (transaction['details'] != null && transaction['details'].toString().isNotEmpty) ...[
                      _popupDetailRow(Icons.description_outlined, 'Details',
                          transaction['details'].toString()),
                    ],

                    _popupDetailRow(Icons.payments_outlined, 'Total',
                        'KES ${NumberFormat('#,##0').format(transaction['totalAmount'])}'),
                  ],

                  const SizedBox(height: 20),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isValid ? AppColors.primaryGreen : Colors.grey.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  if (isValid && transaction != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                           Navigator.pop(ctx);
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (context) => ReturnsScreen(initialTxnId: transaction['id'].toString()),
                             ),
                           );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(color: AppColors.primaryGreen),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Push to Returns'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _popupDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text('$label:', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _getModuleAwareType(String rawType) {
    if (rawType == 'sale') {
      if (_enabledModules.contains('restaurant')) return 'ORDER';
      if (_enabledModules.contains('services')) return 'APPOINTMENT';
      return 'SALE';
    }
    return rawType.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StandardAppBar(title: 'Receipt Verification'),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Instructions
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primaryGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Enter the Reference Code and Amount from the receipt to verify its authenticity.',
                          style: AppTypography.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _refController,
                        decoration: const InputDecoration(
                          labelText: 'Reference Code',
                          prefixIcon: Icon(Icons.tag),
                          border: OutlineInputBorder(),
                          helperText: 'Enter the reference number from the receipt',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Total Amount (KES)',
                          prefixIcon: Icon(Icons.payments_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isVerifying ? null : _verifyReceipt,
                  icon: _isVerifying
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.verified_user),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('VERIFY RECEIPT'),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const InteractiveHelpScroll(contextKey: 'verify'),
        ],
      ),
    );
  }
}
