import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../widgets/empty_state_guide.dart';
import '../../theme/design_system.dart';
import '../../../db/db_provider.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/interactive_help_scroll.dart';

class ReturnsScreen extends StatefulWidget {
  final String? initialTxnId;
  const ReturnsScreen({super.key, this.initialTxnId});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _foundTxn;
  List<Map<String, dynamic>> _txnItems = [];
  Map<int, int> _returnQuantities = {};
  List<Map<String, dynamic>> _recentReturns = [];

  @override
  void initState() {
    super.initState();
    _loadRecentReturns();
    if (widget.initialTxnId != null && widget.initialTxnId!.isNotEmpty) {
      _searchController.text = widget.initialTxnId!;
      // slight delay to let the UI build before showing progress indicator
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchTransaction();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentReturns() async {
    try {
      final data = await DbProvider.queryRaw('''
        SELECT rr.*, i.name as itemName 
        FROM retail_returns rr
        LEFT JOIN inventory i ON rr.item_id = i.id
        ORDER BY rr.created_at DESC 
        LIMIT 20
      ''');
      if (mounted) {
        setState(() {
          _recentReturns = data.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading recent returns: $e');
    }
  }

  Future<void> _searchTransaction() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      // 1. Find Transaction (Using ID or Reference)
      int? txnId = int.tryParse(query);
      List<Map<String, dynamic>> txns;
      
      if (txnId != null) {
        txns = await DbProvider.query('txn', where: 'id = ?', whereArgs: [txnId]);
      } else {
        txns = await DbProvider.query('txn', where: 'sync_status = ?', whereArgs: [query]); // Hack: allow searching by sync string for demo if needed
      }

      if (txns.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction not found')),
          );
        }
        setState(() {
          _foundTxn = null;
          _txnItems = [];
        });
        return;
      }

      final txn = txns.first;

      // 2. Load line items connected to this Txn
      final items = await DbProvider.query('transaction_items', where: 'transactionId = ?', whereArgs: [txn['id']]);

      setState(() {
        _foundTxn = txn;
        _txnItems = items;
        // Initialize return quantities to 0
        _returnQuantities = { for (var item in items) item['id'] as int : 0 };
      });

    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processReturn() async {
    // Collect items to return
    final itemsToReturn = _txnItems.where((item) {
      final id = item['id'] as int;
      return (_returnQuantities[id] ?? 0) > 0;
    }).toList();

    if (itemsToReturn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected for return')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      double totalRefund = 0;
      
      // In a real app we'd call the HTTP endpoint we made:
      // await http.post... '/api/v1/retail/returns'
      
      // For this demo UI, we'll execute the SQLite logic directly 
      // matching the module's backend behavior.
      
      await DbProvider.transaction((txn) async {
        for (var item in itemsToReturn) {
          final id = item['id'] as int;
          final qtyToReturn = _returnQuantities[id]!;
          final unitPrice = (item['unitPrice'] as num).toDouble();
          final refundAmount = unitPrice * qtyToReturn;
          totalRefund += refundAmount;

          // Process return row
          await txn.insert('retail_returns', {
            'original_txn_id': _foundTxn!['id'],
            'item_id': item['itemId'],
            'quantity': qtyToReturn,
            'refund_amount': refundAmount,
            'reason_code': 'customer_return',
            'status': 'completed',
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });

          // Un-decrement stock in inventory
          if (item['itemId'] != null) {
            final invId = item['itemId'].toString();
            await txn.rawUpdate(
              'UPDATE inventory SET stock = stock + ? WHERE cloud_id = ? OR id = ?',
              [qtyToReturn, invId, int.tryParse(invId) ?? -1]
            );
          }
        }
        
        // Log the negative financial transaction
        await txn.insert('txn', {
          'totalAmount': -totalRefund,
          'type': 'refund',
          'details': 'Return processed for TXN #${_foundTxn!['id']}',
          'source_module': 'retail',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      });
      
      await _loadRecentReturns();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully refunded \$${totalRefund.toStringAsFixed(2)}'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Return Failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text('Returns & Exchanges', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.gray900)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.gray900),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search Bar
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter Receipt or TXN ID',
                          prefixIcon: const Icon(Icons.receipt_long),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppColors.gray100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        ),
                        onSubmitted: (_) => _searchTransaction(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _isLoading ? null : _searchTransaction,
                      borderRadius: BorderRadius.circular(12.0),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.search, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // Results
              if (_foundTxn != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.primaryLight.withOpacity(0.3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TXN #${_foundTxn!['id']}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                      Text(DateTime.fromMillisecondsSinceEpoch(_foundTxn!['timestamp']).toString().split('.').first, style: TextStyle(fontSize: 12, color: AppColors.gray600)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _txnItems.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.gray200),
                    itemBuilder: (context, index) {
                      final item = _txnItems[index];
                      final id = item['id'] as int;
                      final maxQty = item['quantity'] as int;
                      final currentQty = _returnQuantities[id] ?? 0;
                      final price = (item['unitPrice'] as num).toDouble();
                      
                      return Container(
                        color: currentQty > 0 ? Colors.red.shade50 : Colors.white,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['item_name']?.toString() ?? 'Item #${item['itemId']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('\$${price.toStringAsFixed(2)} x $maxQty purchased', style: TextStyle(color: AppColors.gray500, fontSize: 12)),
                                ],
                              ),
                            ),
                            // Stepper configuration
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove_circle_outline, color: currentQty > 0 ? AppColors.danger : AppColors.gray300),
                                  onPressed: currentQty > 0 ? () {
                                    setState(() => _returnQuantities[id] = currentQty - 1);
                                  } : null,
                                ),
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    currentQty.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline, color: currentQty < maxQty ? AppColors.primaryGreen : AppColors.gray300),
                                  onPressed: currentQty < maxQty ? () {
                                    setState(() => _returnQuantities[id] = currentQty + 1);
                                  } : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ] else if (!_isLoading) ...[
                Expanded(
                  child: _recentReturns.isEmpty 
                    ? const EmptyStateGuide(
                        icon: Icons.history,
                        title: 'No returns processed yet',
                        subtitle: 'Search a receipt or transaction ID above to process a customer return',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _recentReturns.length,
                        itemBuilder: (context, index) {
                          final ret = _recentReturns[index];
                          final date = DateTime.fromMillisecondsSinceEpoch(ret['created_at'] as int);
                          final itemName = ret['itemName'] ?? 'Unknown Item';
                          final qty = ret['quantity'];
                          final refund = ret['refund_amount'];
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Returned: $itemName',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gray900),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Qty: $qty • ${date.toString().substring(0, 16)}',
                                        style: TextStyle(fontSize: 12, color: AppColors.gray500),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Orig TXN: #${ret['original_txn_id']}',
                                        style: TextStyle(fontSize: 11, color: AppColors.primaryGreen),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '- KES $refund',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.danger),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                ),
              ],
            ],
          ),
          const InteractiveHelpScroll(contextKey: 'returns'),
        ],
      ),
      bottomNavigationBar: _foundTxn != null ? Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
          ]
        ),
        child: PrimaryButton(
          text: 'Process Refund',
          onPressed: _returnQuantities.values.any((q) => q > 0) ? _processReturn : null,
          isLoading: _isLoading,
        ),
      ) : null,
    );
  }
}
