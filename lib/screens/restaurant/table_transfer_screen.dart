import 'package:flutter/material.dart';
import '../../db/db_provider.dart';
import '../../services/event_service.dart';
import '../../theme/design_system.dart';

class TableTransferScreen extends StatefulWidget {
  final int orderId;
  final String currentTableNumber;

  const TableTransferScreen({
    super.key,
    required this.orderId,
    required this.currentTableNumber,
  });

  @override
  State<TableTransferScreen> createState() => _TableTransferScreenState();
}

class _TableTransferScreenState extends State<TableTransferScreen> {
  List<Map<String, dynamic>> _floorPlan = [];
  Map<String, int> _activeTableOrders = {}; // Table Number -> Order ID
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _selectedTable;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    try {
      final db = await DbProvider.db;
      final floors = await db.query('restaurant_floor_plan', orderBy: 'zone ASC, table_number ASC');
      
      final activeOrders = await db.query(
        'restaurant_orders',
        where: "status NOT IN ('completed', 'cancelled') AND id != ?",
        whereArgs: [widget.orderId],
      );

      final Map<String, int> tableToOrder = {};
      for (final order in activeOrders) {
        final tb = order['table_number']?.toString();
        if (tb != null) tableToOrder[tb] = order['id'] as int;
      }

      if (mounted) {
        setState(() {
          _floorPlan = List.from(floors);
          _activeTableOrders = tableToOrder;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading floor plan for transfer: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processTransfer() async {
    if (_selectedTable == null) return;
    
    final targetTable = _selectedTable!;
    final isOccupied = _activeTableOrders.containsKey(targetTable);

    if (isOccupied) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: const Text('Merge Tables?', style: TextStyle(color: Colors.white)),
          content: Text(
            'Table $targetTable is already occupied. This will merge the current order into Table $targetTable\'s order.\n\nDo you want to continue?',
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Merge', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isProcessing = true);

    try {
      final db = await DbProvider.db;
      
      await db.transaction((txn) async {
        // Check if target has an active order (already loaded in memory, but we double-check inside txn)
        final existing = await txn.query(
          'restaurant_orders',
          where: 'table_number = ? AND status NOT IN (?, ?)',
          whereArgs: [targetTable, 'completed', 'paid'],
        );

        if (existing.isNotEmpty) {
          // HARD MERGE: Move all items to target order and update totals
          final targetOrderId = existing.first['id'];
          
          await txn.update(
            'restaurant_order_items',
            {'order_id': targetOrderId, 'updated_at': DateTime.now().millisecondsSinceEpoch},
            where: 'order_id = ?',
            whereArgs: [widget.orderId],
          );
          
          // Re-calculate target order new total
          final oldTotalQuery = await txn.query('restaurant_orders', columns: ['total'], where: 'id = ?', whereArgs: [widget.orderId]);
          final targetTotalQuery = await txn.query('restaurant_orders', columns: ['total'], where: 'id = ?', whereArgs: [targetOrderId]);
          
          final additionalAmount = oldTotalQuery.isNotEmpty ? (oldTotalQuery.first['total'] as num?)?.toDouble() ?? 0.0 : 0.0;
          final currentTargetAmount = targetTotalQuery.isNotEmpty ? (targetTotalQuery.first['total'] as num?)?.toDouble() ?? 0.0 : 0.0;
          
          await txn.update(
            'restaurant_orders',
            {'total': currentTargetAmount + additionalAmount, 'updated_at': DateTime.now().millisecondsSinceEpoch},
            where: 'id = ?',
            whereArgs: [targetOrderId],
          );
          
          // Archive the old order
          await txn.update(
            'restaurant_orders',
            {
              'status': 'merged',
              'parent_order_id': targetOrderId,
              'table_number': targetTable,
              'updated_at': DateTime.now().millisecondsSinceEpoch
            },
            where: 'id = ?',
            whereArgs: [widget.orderId],
          );
        } else {
          // Standard Transfer
          await txn.update(
            'restaurant_orders',
            {
              'table_number': targetTable,
              'updated_at': DateTime.now().millisecondsSinceEpoch
            },
            where: 'id = ?',
            whereArgs: [widget.orderId],
          );
        }
      });

      await EventService.emitEvent(
        eventType: 'TABLE_TRANSFER',
        payload: {
          'order_id': widget.orderId,
          'old_table': widget.currentTableNumber,
          'new_table': targetTable,
        },
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Table transferred successfully')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Transfer Table', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  width: double.infinity,
                  color: const Color(0xFF1F2937),
                  child: Column(
                    children: [
                      const Text('Current Location', style: TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        widget.currentTableNumber,
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Select Destination Table:', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _floorPlan.length,
                    itemBuilder: (ctx, i) {
                      final t = _floorPlan[i];
                      final tableNum = t['table_number'].toString();
                      if (tableNum == widget.currentTableNumber) return const SizedBox.shrink();

                      final isOccupied = _activeTableOrders.containsKey(tableNum);
                      final isSelected = _selectedTable == tableNum;

                      Color boxColor = const Color(0xFF374151);
                      Color textColor = Colors.white;

                      if (isSelected) {
                        boxColor = AppColors.primaryGreen;
                      } else if (isOccupied) {
                        boxColor = Colors.orange.withOpacity(0.2);
                        textColor = Colors.orange;
                      }

                      return GestureDetector(
                        onTap: () => setState(() => _selectedTable = tableNum),
                        child: Container(
                          decoration: BoxDecoration(
                            color: boxColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(tableNum, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                              if (isOccupied && !isSelected)
                                const Text('Merge', style: TextStyle(color: Colors.orange, fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  color: const Color(0xFF1F2937),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: Colors.grey[800],
                      ),
                      onPressed: (_selectedTable == null || _isProcessing) ? null : _processTransfer,
                      child: _isProcessing 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _selectedTable != null && _activeTableOrders.containsKey(_selectedTable!)
                                  ? 'Merge with $_selectedTable'
                                  : 'Transfer to ${_selectedTable ?? '...'}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
