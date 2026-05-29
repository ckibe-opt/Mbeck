import 'package:flutter/material.dart';
import '../db/db_provider.dart';
import '../services/event_service.dart';
import '../theme/design_system.dart';
import '../widgets/standard_app_bar.dart';

/// Supplies Inventory Screen — shared by Restaurant and Services modules.
/// 
/// Manages consumable stock (flour, vegetables, hair products, etc.)
/// Restock actions are recorded as expenses in the txn table for Reports.
class SuppliesScreen extends StatefulWidget {
  final String module; // 'restaurant' or 'services'

  const SuppliesScreen({super.key, required this.module});

  @override
  State<SuppliesScreen> createState() => _SuppliesScreenState();
}

class _SuppliesScreenState extends State<SuppliesScreen> {
  List<Map<String, dynamic>> _supplies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSupplies();
  }

  Future<void> _loadSupplies() async {
    setState(() => _isLoading = true);
    try {
      final db = await DbProvider.db;
      final result = await db.query(
        'supplies',
        where: 'module = ?',
        whereArgs: [widget.module],
        orderBy: 'name ASC',
      );
      if (mounted) {
        setState(() {
          _supplies = List.from(result);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading supplies: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSupplyDialog({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final categoryCtrl = TextEditingController(text: existing?['category']?.toString() ?? '');
    final costCtrl = TextEditingController(
      text: existing != null ? (existing['cost_per_unit'] as num?)?.toString() ?? '0' : '',
    );
    final minStockCtrl = TextEditingController(
      text: existing != null ? (existing['min_stock_level'] as num?)?.toString() ?? '0' : '',
    );
    String selectedUnit = existing?['unit']?.toString() ?? 'pcs';
    final units = ['pcs', 'kg', 'g', 'litres', 'ml', 'bottles', 'packets', 'boxes', 'rolls'];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Supply Item' : 'Edit Supply'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    hintText: 'e.g. Flour, Hair Gel',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryCtrl,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    hintText: widget.module == 'restaurant' 
                        ? 'e.g. Dry Goods, Produce' 
                        : 'e.g. Hair, Nails',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedUnit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: units.map((u) => DropdownMenuItem(
                    value: u,
                    child: Text(u),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedUnit = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cost Per Unit (KES)',
                    border: OutlineInputBorder(),
                    prefixText: 'KES ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minStockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Low Stock Alert Level',
                    hintText: 'Alert when below this',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final db = await DbProvider.db;
      final data = {
        'name': nameCtrl.text.trim(),
        'category': categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
        'unit': selectedUnit,
        'cost_per_unit': double.tryParse(costCtrl.text) ?? 0,
        'min_stock_level': double.tryParse(minStockCtrl.text) ?? 0,
        'module': widget.module,
        'updated_at': now,
      };

      if (existing == null) {
        data['quantity'] = 0;
        data['created_at'] = now;
        await db.insert('supplies', data);
      } else {
        await db.update('supplies', data, where: 'id = ?', whereArgs: [existing['id']]);
      }
      _loadSupplies();
    }
  }

  Future<void> _showRestockDialog(Map<String, dynamic> supply) async {
    final qtyCtrl = TextEditingController();
    final costCtrl = TextEditingController(
      text: (supply['cost_per_unit'] as num?)?.toString() ?? '0',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restock: ${supply['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current: ${_formatQty(supply)} ${supply['unit']}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Quantity to Add',
                suffixText: supply['unit']?.toString() ?? 'pcs',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Cost (KES)',
                prefixText: 'KES ',
                border: OutlineInputBorder(),
                helperText: 'Total amount spent on this restock',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Restock'),
          ),
        ],
      ),
    );

    if (result == true) {
      final addQty = double.tryParse(qtyCtrl.text) ?? 0;
      final totalCost = double.tryParse(costCtrl.text) ?? 0;
      if (addQty <= 0) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final db = await DbProvider.db;
      final currentQty = (supply['quantity'] as num?)?.toDouble() ?? 0;

      await db.transaction((txn) async {
        // 1. Update supply stock
        await txn.update(
          'supplies',
          {
            'quantity': currentQty + addQty,
            'cost_per_unit': addQty > 0 ? totalCost / addQty : supply['cost_per_unit'],
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [supply['id']],
        );

        // 2. Record as expense in txn table
        if (totalCost > 0) {
          await txn.insert('txn', {
            'type': 'outgoing',
            'totalAmount': totalCost,
            'details': 'Restock: ${supply['name']} x${addQty.toStringAsFixed(addQty == addQty.roundToDouble() ? 0 : 1)} ${supply['unit']}',
            'timestamp': now,
          });
        }
      });

      // Emit event for sync
      await EventService.emitEvent(
        eventType: 'SUPPLY_RESTOCK',
        payload: {
          'supply_id': supply['id'],
          'supply_name': supply['name'],
          'quantity_added': addQty,
          'total_cost': totalCost,
          'module': widget.module,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restocked ${supply['name']} +${addQty.toStringAsFixed(addQty == addQty.roundToDouble() ? 0 : 1)} ${supply['unit']}'
              '${totalCost > 0 ? ' (KES ${totalCost.toStringAsFixed(0)} expense recorded)' : ''}',
            ),
          ),
        );
      }
      _loadSupplies();
    }
  }

  Future<void> _showUseDialog(Map<String, dynamic> supply) async {
    final qtyCtrl = TextEditingController();
    final currentQty = (supply['quantity'] as num?)?.toDouble() ?? 0;
    final unit = supply['unit']?.toString() ?? 'pcs';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Use: ${supply['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'In stock: ${_formatQty(supply)} $unit',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Quantity Used',
                suffixText: unit,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Deduct'),
          ),
        ],
      ),
    );

    if (result == true) {
      final useQty = double.tryParse(qtyCtrl.text) ?? 0;
      if (useQty <= 0) return;

      final db = await DbProvider.db;
      final newQty = (currentQty - useQty).clamp(0.0, double.infinity);
      await db.update(
        'supplies',
        {
          'quantity': newQty,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [supply['id']],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Used ${useQty.toStringAsFixed(useQty == useQty.roundToDouble() ? 0 : 1)} $unit of ${supply['name']}',
            ),
          ),
        );
      }
      _loadSupplies();
    }
  }

  // ignore: unused_element
  Future<void> _deleteSupply(Map<String, dynamic> supply) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Supply?'),
        content: Text('Remove "${supply['name']}" from your supplies?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final db = await DbProvider.db;
      await db.delete('supplies', where: 'id = ?', whereArgs: [supply['id']]);
      _loadSupplies();
    }
  }

  String _formatQty(Map<String, dynamic> supply) {
    final qty = (supply['quantity'] as num?)?.toDouble() ?? 0;
    return qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1);
  }

  Color _stockColor(Map<String, dynamic> supply) {
    final qty = (supply['quantity'] as num?)?.toDouble() ?? 0;
    final minLevel = (supply['min_stock_level'] as num?)?.toDouble() ?? 0;
    if (qty <= 0) return Colors.red;
    if (minLevel > 0 && qty <= minLevel) return Colors.orange;
    return Colors.green;
  }

  String get _moduleLabel => widget.module == 'restaurant' ? 'Kitchen' : 'Salon';

  @override
  Widget build(BuildContext context) {
    final lowStockCount = _supplies.where((s) {
      final qty = (s['quantity'] as num?)?.toDouble() ?? 0;
      final min = (s['min_stock_level'] as num?)?.toDouble() ?? 0;
      return min > 0 && qty <= min;
    }).length;

    return Scaffold(
      appBar: StandardAppBar(
        title: '$_moduleLabel Supplies',
        actions: [
          if (lowStockCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                label: Text('$lowStockCount low', style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.orange.shade50,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _supplies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.module == 'restaurant' 
                            ? Icons.kitchen 
                            : Icons.inventory_2,
                        size: 64,
                        color: AppColors.gray300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No supplies yet',
                        style: TextStyle(color: AppColors.gray500, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.module == 'restaurant'
                            ? 'Track ingredients like flour, oil, vegetables'
                            : 'Track products like hair gel, nail polish',
                        style: TextStyle(color: AppColors.gray400, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _showSupplyDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Supply'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSupplies,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _supplies.length,
                    itemBuilder: (ctx, i) => _buildSupplyCard(_supplies[i]),
                  ),
                ),
      floatingActionButton: _supplies.isNotEmpty
          ? FloatingActionButton(
              heroTag: "supplies_fab",
              onPressed: () => _showSupplyDialog(),
              backgroundColor: AppColors.primaryGreen,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSupplyCard(Map<String, dynamic> supply) {
    final qty = (supply['quantity'] as num?)?.toDouble() ?? 0;
    final unit = supply['unit']?.toString() ?? 'pcs';
    final costPerUnit = (supply['cost_per_unit'] as num?)?.toDouble() ?? 0;
    final minLevel = (supply['min_stock_level'] as num?)?.toDouble() ?? 0;
    final category = supply['category']?.toString();
    final stockColor = _stockColor(supply);
    final isLow = minLevel > 0 && qty <= minLevel;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isLow ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isLow ? BorderSide(color: Colors.orange.shade300, width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showSupplyDialog(existing: supply),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Stock indicator
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: stockColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    qty <= 0
                        ? Icons.error_outline
                        : isLow
                            ? Icons.warning_amber
                            : Icons.check_circle_outline,
                    color: stockColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supply['name']?.toString() ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${_formatQty(supply)} $unit',
                          style: TextStyle(
                            color: stockColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (costPerUnit > 0) ...[
                          Text(
                            '  •  KES ${costPerUnit.toStringAsFixed(0)}/$unit',
                            style: TextStyle(
                              color: AppColors.gray500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (category != null && category.isNotEmpty)
                      Text(
                        category,
                        style: TextStyle(color: AppColors.gray400, fontSize: 11),
                      ),
                  ],
                ),
              ),
              // Actions
              Column(
                children: [
                  // Restock button
                  SizedBox(
                    height: 30,
                    child: OutlinedButton.icon(
                      onPressed: () => _showRestockDialog(supply),
                      icon: const Icon(Icons.add_shopping_cart, size: 14),
                      label: const Text('Restock', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        side: BorderSide(color: AppColors.primaryGreen),
                        foregroundColor: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Use / Deduct button
                  SizedBox(
                    height: 30,
                    child: OutlinedButton.icon(
                      onPressed: () => _showUseDialog(supply),
                      icon: const Icon(Icons.remove_circle_outline, size: 14),
                      label: const Text('Use', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        side: BorderSide(color: Colors.orange.shade400),
                        foregroundColor: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
