import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../db/db_provider.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/restaurant_service.dart';
import '../../services/security_service.dart';
import '../../theme/design_system.dart';

class SplitBillScreen extends StatefulWidget {
  final int orderId;
  final String currentTotalText;
  final double initiallyParsedTotal;

  const SplitBillScreen({
    super.key,
    required this.orderId,
    required this.currentTotalText,
    required this.initiallyParsedTotal,
  });

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountCtrl = TextEditingController();
  bool _isProcessing = false;
  
  // Split evenly state
  int _splitWays = 2;
  
  // Itemized split state
  List<Map<String, dynamic>> _orderItems = [];
  bool _isLoadingItems = true;
  Set<int> _selectedItemIds = {}; // item IDs

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrderItems();
  }

  Future<void> _loadOrderItems() async {
    try {
      final db = await DbProvider.db;
      final items = await db.query(
        'restaurant_order_items',
        where: 'order_id = ?',
        whereArgs: [widget.orderId],
      );
      
      if (mounted) {
        setState(() {
          _orderItems = List.from(items);
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading items for split: $e');
      if (mounted) setState(() => _isLoadingItems = false);
    }
  }

  /// Show a dialog to optionally capture the M-Pesa code before processing
  Future<void> _promptPaymentAndProcess(double amountPaid) async {
    if (amountPaid <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    if (amountPaid > widget.initiallyParsedTotal) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount cannot exceed current total')));
      return;
    }

    final mpesaCtrl = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Amount', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('KES ${amountPaid.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: mpesaCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'M-Pesa Code (optional)',
                hintText: 'e.g. SLK4J7HXRT',
                prefixIcon: const Icon(Icons.phone_android, color: AppColors.primaryGreen),
                filled: true,
                fillColor: AppColors.gray50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.gray200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.gray200),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Enter the unique M-Pesa confirmation code from the customer.', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    final mpesaRef = mpesaCtrl.text.trim();
    mpesaCtrl.dispose();

    if (confirmed == true && mounted) {
      _processSplitPayment(amountPaid, mpesaRef);
    }
  }

  void _processSplitPayment(double amountPaid, String paymentRef) async {
    setState(() => _isProcessing = true);

    try {
      final db = await DbProvider.db;
      final subTxnId = 'SPLIT-${const Uuid().v4().substring(0, 8)}';
      
      List<Map<String, Object?>> orderQueryData = [];
      bool fullyPaid = false;
      double finalTotal = 0.0;
      String finalStatus = '';
      
      await db.transaction((txn) async {
        final now = DateTime.now().millisecondsSinceEpoch;

        // 1. Log partial payment with optional payment_ref
        await txn.insert('restaurant_split_bills', {
          'order_id': widget.orderId,
          'sub_txn_id': subTxnId,
          'amount': amountPaid,
          'status': 'paid',
          'payment_ref': paymentRef.isNotEmpty ? paymentRef : null,
          'created_at': now,
        });

        // Extract real items for financial ledger breakdown
        final itemRows = await txn.query('restaurant_order_items', columns: ['menu_item_name', 'quantity'], where: 'order_id = ?', whereArgs: [widget.orderId]);
        final itemsStr = itemRows.map((e) {
          final q = (e['quantity'] as num?)?.toInt() ?? 1;
          return '${q}x ${e['menu_item_name']}';
        }).join(', ');
        final String detailedLog = itemsStr.isNotEmpty 
            ? '$itemsStr (Order #${widget.orderId}, Split)'
            : 'Order #${widget.orderId} — Split Payment';

        // 2. Insert into the main accounting ledger as a SALE!
        final signature = await SecurityService().signTransaction(
          timestamp: now,
          totalAmount: amountPaid,
          type: 'sale',
          details: detailedLog + (paymentRef.isNotEmpty ? ' (Ref: $paymentRef)' : ''),
        );

        await txn.insert('txn', {
          'type': 'sale',
          'totalAmount': amountPaid,
          'details': detailedLog + (paymentRef.isNotEmpty ? ' (Ref: $paymentRef)' : ''),
          'timestamp': now,
          'receiptSignature': signature,
          'source_module': 'restaurant',
        });

        // 3. Fetch current total
        orderQueryData = await txn.query(
          'restaurant_orders',
          columns: ['total', 'status'],
          where: 'id = ?',
          whereArgs: [widget.orderId],
        );

        if (orderQueryData.isNotEmpty) {
          final currentTotal = (orderQueryData.first['total'] as num).toDouble();
          final newTotal = currentTotal - amountPaid;
          final currentStatus = orderQueryData.first['status'] as String?;
          
          fullyPaid = newTotal <= 0.01;
          final newStatus = fullyPaid ? 'paid' : currentStatus;
          
          finalTotal = newTotal < 0 ? 0 : newTotal;
          finalStatus = newStatus ?? 'pending';

          // 4. Update order balance and status
          await txn.update(
            'restaurant_orders',
            {
              'total': finalTotal,
              'status': finalStatus,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [widget.orderId],
          );
        }
      });
      
      if (fullyPaid) {
        // We set status to 'paid', meaning the Table Map takes over until "Clear Table" is pressed.
        // We defer `RestaurantService.completeParentOrder` until the waiter actually clears the table!
        
        await EventService.emitEvent(
          eventType: 'ORDER_UPDATE',
          payload: {
            'order_id': widget.orderId,
            'split_paid': amountPaid,
            'new_total': 0.0,
            'new_status': 'paid',
            'payment_ref': paymentRef.isNotEmpty ? paymentRef : null,
          },
        );
      } else {
        // Emit event for partial update
        await EventService.emitEvent(
          eventType: 'ORDER_UPDATE',
          payload: {
            'order_id': widget.orderId,
            'split_paid': amountPaid,
            'new_total': finalTotal,
            'new_status': finalStatus,
            'payment_ref': paymentRef.isNotEmpty ? paymentRef : null,
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paymentRef.isNotEmpty 
              ? 'Payment recorded (Ref: $paymentRef)'
              : 'Partial payment recorded successfully'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        Navigator.pop(context, true); // Return true to signal refresh
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _selectedItemsTotal {
    double total = 0;
    for (var item in _orderItems) {
      if (_selectedItemIds.contains(item['id'])) {
        final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        total += price * qty;
      }
    }
    return total;
  }

  Widget _buildItemizedTab() {
    if (_isLoadingItems) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    
    if (_orderItems.isEmpty) {
      return const Center(child: Text('No items found for this order.', style: TextStyle(color: Colors.white)));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: _orderItems.length,
            itemBuilder: (context, index) {
              final item = _orderItems[index];
              final itemId = item['id'] as int;
              final name = item['menu_item_name'] ?? 'Item';
              final qty = item['quantity'] ?? 1;
              final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
              final total = price * qty;
              
              final isSelected = _selectedItemIds.contains(itemId);

              return CheckboxListTile(
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedItemIds.add(itemId);
                    } else {
                      _selectedItemIds.remove(itemId);
                    }
                  });
                },
                activeColor: AppColors.primaryGreen,
                checkColor: Colors.white,
                tileColor: isSelected ? AppColors.primaryGreen.withOpacity(0.1) : Colors.transparent,
                title: Text('$qty x $name', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('KES ${price.toStringAsFixed(0)} each', style: const TextStyle(color: Colors.grey)),
                secondary: Text('KES ${total.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1F2937),
            border: Border(top: BorderSide(color: Color(0xFF374151))),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Selected Total:', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  Text('KES ${_selectedItemsTotal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: Colors.grey[800],
                  ),
                  onPressed: (_isProcessing || _selectedItemIds.isEmpty) ? null : () => _promptPaymentAndProcess(_selectedItemsTotal),
                  child: _isProcessing 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Pay KES ${_selectedItemsTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomAmountTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Enter Partial Payment Amount', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 24),
            decoration: InputDecoration(
              prefixText: 'KES ',
              prefixStyle: const TextStyle(color: Colors.white, fontSize: 24),
              filled: true,
              fillColor: const Color(0xFF374151),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isProcessing ? null : () {
                final text = _amountCtrl.text.trim();
                if (text.isNotEmpty) {
                  final amt = double.tryParse(text) ?? 0;
                  _promptPaymentAndProcess(amt);
                }
              },
              child: _isProcessing 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Process Custom Split', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitEvenlyTab() {
    final splitAmount = widget.initiallyParsedTotal / _splitWays;
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Split Balance Evenly', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _splitWays > 2 ? () => setState(() => _splitWays--) : null,
                icon: const Icon(Icons.remove_circle_outline, size: 48, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 24),
              Text('$_splitWays Ways', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(width: 24),
              IconButton(
                onPressed: _splitWays < 20 ? () => setState(() => _splitWays++) : null,
                icon: const Icon(Icons.add_circle_outline, size: 48, color: AppColors.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Center(
            child: Text(
              'KES ${splitAmount.toStringAsFixed(0)} per person',
              style: const TextStyle(color: AppColors.primaryGreen, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isProcessing ? null : () => _promptPaymentAndProcess(splitAmount),
              child: _isProcessing 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Pay One Share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Split Bill', style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGreen,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'By Items'),
            Tab(text: 'Evenly'),
            Tab(text: 'Custom'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Outstanding Balance Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            width: double.infinity,
            color: const Color(0xFF1F2937),
            child: Column(
              children: [
                const Text('Outstanding Balance', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  widget.currentTotalText,
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildItemizedTab(),
                _buildSplitEvenlyTab(),
                _buildCustomAmountTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
