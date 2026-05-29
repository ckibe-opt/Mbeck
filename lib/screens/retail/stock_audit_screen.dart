import 'package:flutter/material.dart';
import '../../../widgets/empty_state_guide.dart';
import '../../theme/design_system.dart';
import '../../../db/db_provider.dart';
import '../../../widgets/primary_button.dart';
import '../barcode_scanner_screen.dart';
import '../../../widgets/interactive_help_scroll.dart';

class StockAuditScreen extends StatefulWidget {
  const StockAuditScreen({super.key});

  @override
  State<StockAuditScreen> createState() => _StockAuditScreenState();
}

class _StockAuditScreenState extends State<StockAuditScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _inventory = [];
  final Map<int, int> _actualCounts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await DbProvider.query('inventory', orderBy: 'name ASC');
      if (mounted) {
        setState(() {
          _inventory = items;
          // Pre-fill actual counts with expected stock to start
          for (var item in items) {
            final id = item['id'] as int;
            _actualCounts[id] = (item['stock'] as num).toInt();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading inventory: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAudit() async {
    // Filter down to only items where actual count changed from expected
    final discrepancies = _inventory.where((item) {
      final id = item['id'] as int;
      final expected = (item['stock'] as num).toInt();
      final actual = _actualCounts[id] ?? expected;
      return expected != actual;
    }).toList();

    if (discrepancies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No discrepancies found. All stock matches expected levels.')));
      return;
    }

    // In a real flow, you'd maybe ask for a reason code here. Defaulting to 'general_audit'
    _showSubmitConfirmation(discrepancies);
  }

  void _showSubmitConfirmation(List<Map<String, dynamic>> discrepancies) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.warning),
            const SizedBox(height: 16),
            Text('Confirm Audit', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gray900)),
            const SizedBox(height: 8),
            Text('You are about to log discrepancies for ${discrepancies.length} items. This will permanently alter inventory levels and system valuation.', 
              textAlign: TextAlign.center, 
              style: TextStyle(color: AppColors.gray600)
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: AppColors.gray600, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PrimaryButton(
                    text: 'Commit Audit',
                    onPressed: () async {
                      Navigator.pop(context);
                      await _executeAuditToDatabase(discrepancies);
                    },
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _executeAuditToDatabase(List<Map<String, dynamic>> discrepancies) async {
    setState(() => _isLoading = true);
    try {
      await DbProvider.transaction((txn) async {
        for (var item in discrepancies) {
          final id = item['id'] as int;
          final expected = (item['stock'] as num).toInt();
          final actual = _actualCounts[id] ?? expected;
          final diff = actual - expected;

          // Log the audit record
          await txn.insert('retail_stock_audits', {
            'inventory_id': id,
            'expected_stock': expected,
            'actual_stock': actual,
            'difference': diff,
            'reason': 'routine_count',
            'performed_by': 'Admin',
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });

          // Override the inventory stock level
          await txn.update('inventory', {'stock': actual}, where: 'id = ?', whereArgs: [id]);
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audit successful. Stock synced.'), backgroundColor: AppColors.success));
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show save button if at least one count differs
    bool hasChanges = false;
    for (var item in _inventory) {
      final id = item['id'] as int;
      final expected = (item['stock'] as num).toInt();
      final actual = _actualCounts[id] ?? expected;
      if (expected != actual) {
        hasChanges = true;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text('Stock Audit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.gray900)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.gray900),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              final code = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
              );
              if (code != null) {
                final itemIndex = _inventory.indexWhere((i) => i['barcode'] == code);
                if (itemIndex != -1) {
                  final item = _inventory[itemIndex];
                  final id = item['id'] as int;
                  final current = _actualCounts[id] ?? (item['stock'] as num).toInt();
                  setState(() => _actualCounts[id] = current + 1);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanned ${item['name']}. Count: ${current + 1}')));
                } else {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barcode not found in inventory')));
                }
              }
            },
          )
        ],
      ),
      body: Stack(
        children: [
          _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _inventory.isEmpty
              ? const EmptyStateGuide(
                  icon: Icons.fact_check_outlined,
                  title: 'Ready to audit?',
                  subtitle: 'Add products to your inventory first, then come back to count your physical stock and catch discrepancies',
                )
              : Column(
                children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.primaryLight.withOpacity(0.3),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Count physical items on shelf and adjust counts using +/- buttons. ', style: TextStyle(color: AppColors.gray800))),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _inventory.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.gray200),
                  itemBuilder: (context, index) {
                    final item = _inventory[index];
                    final id = item['id'] as int;
                    final expected = (item['stock'] as num).toInt();
                    final actual = _actualCounts[id] ?? expected;
                    final isDifferent = expected != actual;
                    
                    return Container(
                      color: isDifferent ? AppColors.warning.withOpacity(0.1) : Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'] as String? ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('Expected: $expected', style: TextStyle(color: AppColors.gray500, fontSize: 12)),
                                    if (isDifferent) ...[
                                      const SizedBox(width: 8),
                                      Text('Diff: ${actual - expected > 0 ? "+" : ""}${actual - expected}', 
                                        style: TextStyle(color: actual > expected ? AppColors.success : AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Stepper configuration
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.gray50,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove, color: actual > 0 ? AppColors.gray700 : AppColors.gray300, size: 20),
                                  splashRadius: 20,
                                  onPressed: actual > 0 ? () {
                                    setState(() => _actualCounts[id] = actual - 1);
                                  } : null,
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    actual.toString(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDifferent ? AppColors.primaryGreen : AppColors.gray900),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, color: AppColors.gray700, size: 20),
                                  splashRadius: 20,
                                  onPressed: () {
                                    setState(() => _actualCounts[id] = actual + 1);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const InteractiveHelpScroll(contextKey: 'audit'),
        ],
      ),
      bottomNavigationBar: hasChanges ? Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
          ]
        ),
        child: PrimaryButton(
          text: 'Commit Audit',
          onPressed: _submitAudit,
        ),
      ) : null,
    );
  }
}
