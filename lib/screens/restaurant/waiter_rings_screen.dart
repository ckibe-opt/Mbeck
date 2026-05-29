import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../db/db_provider.dart';
import '../../services/event_service.dart';
import '../../services/auth_service.dart';
import '../../services/waiter_ring_service.dart';
import '../../theme/design_system.dart';
import '../../widgets/standard_app_bar.dart';
import '../../widgets/interactive_help_scroll.dart';

/// Screen showing all incoming customer waiter rings.
///
/// Each ring card has 3 actions:
///   - **Acknowledge** → Creates a restaurant order and pushes to Order Queue
///   - **Change** → Edit items before creating the order
///   - **Delete** → Remove the ring
class WaiterRingsScreen extends StatefulWidget {
  const WaiterRingsScreen({super.key});

  @override
  State<WaiterRingsScreen> createState() => _WaiterRingsScreenState();
}

class _WaiterRingsScreenState extends State<WaiterRingsScreen> {
  late StreamSubscription<List<WaiterRing>> _sub;
  List<WaiterRing> _rings = [];
  List<Map<String, dynamic>> _menuItems = [];

  @override
  void initState() {
    super.initState();
    _rings = WaiterRingService.instance.rings.toList();
    _sub = WaiterRingService.instance.ringsStream.listen((rings) {
      if (mounted) setState(() => _rings = rings.toList());
    });
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      final db = await DbProvider.db;
      final items = await db.query('restaurant_menu',
          where: 'available = ?', whereArgs: [1], orderBy: 'category, name');
      if (mounted) setState(() => _menuItems = items);
    } catch (e) {
      debugPrint('⚠️ Failed to load menu for ring edit: $e');
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  // ─── ACTIONS ─────────────────────────────────────────

  /// Acknowledge: create order from ring items → push to order queue
  Future<void> _acknowledgeAndCreateOrder(WaiterRing ring) async {
    if (ring.items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items to create order'), backgroundColor: Colors.orange),
        );
      }
      // Still acknowledge (maybe they just wanted to note it)
      WaiterRingService.instance.acknowledgeRing(ring.id);
      return;
    }

    try {
      final db = await DbProvider.db;
      final total = ring.total;
      final orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      
      // Fetch member outside transaction to prevent SQL deadlock
      final currentMember = await AuthService.getCurrentMember();
      final createdBy = currentMember?.userName ?? 'Unknown';

      await db.transaction((txn) async {
        // 1. Create Order
        final orderId = await txn.insert('restaurant_orders', {
          'cloud_id': const Uuid().v4(),
          'order_number': orderNumber,
          'order_type': 'dine_in',
          'table_number': ring.tableNumber,
          'customer_name': ring.customerName,
          // Persist the buyer's client_id so the active-orders endpoint can
          // filter by client_id instead of customer_name (which is unreliable).
          'client_id': ring.clientId,
          'items_json': jsonEncode(ring.items),
          'subtotal': total,
          'total': total,
          'status': 'pending',
          'notes': ring.note,
          'created_by': createdBy,
        });

        // 2. Create Order Items
        for (final item in ring.items) {
          final qty = (item['qty'] as num?)?.toInt() ?? 1;
          final price = (item['price'] as num?)?.toDouble() ?? 0;
          await txn.insert('restaurant_order_items', {
            'order_id': orderId,
            'menu_item_id': item['id'] ?? 0,
            'menu_item_name': item['name'] ?? 'Item',
            'quantity': qty,
            'unit_price': price,
            'subtotal': price * qty,
            'status': 'pending',
          });
        }
      });

      // Emit event for LAN sync
      await EventService.emitEvent(
        eventType: 'ORDER_CREATED',
        payload: {
          'order_number': orderNumber,
          'order_type': 'dine_in',
          'table_number': ring.tableNumber,
          'customer_name': ring.customerName,
          'items': ring.items,
          'total': total,
          'notes': ring.note,
          'source': 'waiter_ring',
        },
      );

      WaiterRingService.instance.acknowledgeRing(ring.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Order $orderNumber created → Order Queue'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to create order from ring: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create order: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Change: open bottom sheet to edit items, then create order
  Future<void> _showEditItemsSheet(WaiterRing ring) async {
    // Work on a mutable copy of items
    final editableItems = ring.items
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditItemsSheet(
        items: editableItems,
        menuItems: _menuItems,
      ),
    );

    if (result != null && mounted) {
      // Update ring items then create order
      WaiterRingService.instance.updateRingItems(ring.id, result);

      // Re-fetch the updated ring
      final updatedRing = WaiterRingService.instance.rings
          .firstWhere((r) => r.id == ring.id, orElse: () => ring);
      await _acknowledgeAndCreateOrder(updatedRing);
    }
  }

  /// Delete: confirm then remove ring
  Future<void> _deleteRing(WaiterRing ring) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ring?'),
        content: Text(
          'Remove ring from Table ${ring.tableNumber.isNotEmpty ? ring.tableNumber : "N/A"}?\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      WaiterRingService.instance.dismissRing(ring.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ring removed')),
        );
      }
    }
  }

  /// Clear All rings
  Future<void> _clearAllRings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Rings?'),
        content: Text('Remove all ${_rings.length} ring(s)?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      WaiterRingService.instance.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All rings cleared')),
        );
      }
    }
  }

  // ─── BUILD ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unacked = _rings.where((r) => !r.acknowledged).toList();
    final acked = _rings.where((r) => r.acknowledged).toList();

    return Scaffold(
      appBar: StandardAppBar(
        title: 'Customer Rings',
        actions: [
          if (_rings.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAllRings,
              icon: const Icon(Icons.delete_sweep, size: 18),
              label: const Text('Clear All'),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
            ),
        ],
      ),
      body: Stack(
        children: [
          _rings.isEmpty
              ? _buildEmpty()
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (unacked.isNotEmpty) ...[
                  _buildSectionHeader('New Rings', unacked.length, Colors.deepOrange),
                  const SizedBox(height: 8),
                  ...unacked.map((r) => _buildRingCard(r, isNew: true)),
                ],
                if (acked.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader('Sent to Kitchen', acked.length, Colors.grey),
                  const SizedBox(height: 8),
                  ...acked.map((r) => _buildRingCard(r, isNew: false)),
                ],
              ],
            ),
          const InteractiveHelpScroll(contextKey: 'waiter'),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No customer rings yet',
            style: AppTypography.textTheme.titleLarge?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When customers ring from Mbeck Go,\nthey\'ll appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                title == 'New Rings' ? Icons.notifications_active : Icons.check_circle,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                '$title ($count)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRingCard(WaiterRing ring, {required bool isNew}) {
    final timeAgo = _formatTimeAgo(ring.timestamp);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isNew ? 3 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isNew
            ? BorderSide(color: Colors.deepOrange.withOpacity(0.4), width: 1.5)
            : BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: table + customer + time
            Row(
              children: [
                if (isNew)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: Colors.deepOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.table_restaurant, size: 14, color: AppColors.primaryGreen),
                      const SizedBox(width: 4),
                      Text(
                        ring.tableNumber.isNotEmpty ? 'Table ${ring.tableNumber}' : 'No table',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ring.customerName.isNotEmpty && ring.customerName != 'Customer') ...[
                  const SizedBox(width: 8),
                  Text(
                    ring.customerName,
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
                const Spacer(),
                Text(timeAgo, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 10),

            // Items
            if (ring.items.isNotEmpty) ...[
              ...ring.items.take(5).map((item) {
                final name = item['name'] as String? ?? 'Item';
                final qty = item['qty'] ?? 1;
                final price = (item['price'] as num?)?.toDouble() ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${qty}x',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      ),
                      if (price > 0)
                        Text(
                          'KES ${(price * (qty as num)).toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                );
              }),
              if (ring.items.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '+${ring.items.length - 5} more items',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                  ),
                ),
            ],

            // Note
            if (ring.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note_outlined, size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ring.note,
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Total
            if (ring.total > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Total: KES ${ring.total.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],

            // Action Buttons
            const SizedBox(height: 12),
            if (isNew)
              Row(
                children: [
                  // Acknowledge → Create Order
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _acknowledgeAndCreateOrder(ring),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Accept', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Change → Edit items
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditItemsSheet(ring),
                      icon: Icon(Icons.edit, size: 16, color: Colors.blue.shade600),
                      label: Text('Change', style: TextStyle(fontSize: 12, color: Colors.blue.shade600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: BorderSide(color: Colors.blue.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete → Remove ring
                  SizedBox(
                    width: 48,
                    child: IconButton(
                      onPressed: () => _deleteRing(ring),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.red.shade400,
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green.shade400),
                        const SizedBox(width: 4),
                        Text('Sent to Kitchen', style: TextStyle(fontSize: 12, color: Colors.green.shade600)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deleteRing(ring),
                    icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
                    tooltip: 'Dismiss Ring',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─── EDIT ITEMS BOTTOM SHEET ─────────────────────────

/// A bottom sheet that lets the waiter edit ring items before creating the order.
/// - Adjust quantities with +/- buttons
/// - Remove items entirely
/// - Add new items from the restaurant menu
class _EditItemsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> menuItems;

  const _EditItemsSheet({required this.items, required this.menuItems});

  @override
  State<_EditItemsSheet> createState() => _EditItemsSheetState();
}

class _EditItemsSheetState extends State<_EditItemsSheet> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  double get _total {
    double sum = 0;
    for (final item in _items) {
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      final qty = (item['qty'] as num?)?.toInt() ?? 1;
      sum += price * qty;
    }
    return sum;
  }

  void _updateQty(int index, int delta) {
    setState(() {
      final current = (_items[index]['qty'] as num?)?.toInt() ?? 1;
      final newQty = current + delta;
      if (newQty <= 0) {
        _items.removeAt(index);
      } else {
        _items[index]['qty'] = newQty;
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _showAddItemDialog() {
    // Filter out items already in the list
    final existingNames = _items.map((e) => e['name']).toSet();
    final available = widget.menuItems
        .where((m) => !existingNames.contains(m['name']))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All menu items already added')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Menu Item'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: available.length,
            itemBuilder: (_, i) {
              final menuItem = available[i];
              return ListTile(
                title: Text(menuItem['name'] as String? ?? 'Item'),
                subtitle: Text('KES ${menuItem['price'] ?? 0}'),
                dense: true,
                trailing: const Icon(Icons.add_circle_outline, color: AppColors.primaryGreen),
                onTap: () {
                  setState(() {
                    _items.add({
                      'id': menuItem['id'],
                      'name': menuItem['name'],
                      'price': menuItem['price'],
                      'qty': 1,
                    });
                  });
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Row(
                children: [
                  const Text(
                    'Edit Order Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showAddItemDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Items list
              Expanded(
                child: _items.isEmpty
                    ? Center(
                        child: Text(
                          'No items. Tap "Add Item" to add from menu.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final item = _items[i];
                          final name = item['name'] as String? ?? 'Item';
                          final price = (item['price'] as num?)?.toDouble() ?? 0;
                          final qty = (item['qty'] as num?)?.toInt() ?? 1;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  // Item info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        Text(
                                          'KES ${(price * qty).toStringAsFixed(0)}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Qty controls
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => _updateQty(i, -1),
                                          child: Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Icon(Icons.remove, size: 18, color: Colors.red.shade400),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          child: Text(
                                            '$qty',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => _updateQty(i, 1),
                                          child: Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Icon(Icons.add, size: 18, color: AppColors.primaryGreen),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Remove
                                  IconButton(
                                    onPressed: () => _removeItem(i),
                                    icon: Icon(Icons.close, size: 18, color: Colors.red.shade400),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Footer: total + confirm
              const Divider(),
              Row(
                children: [
                  Text(
                    'Total: KES ${_total.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _items.isEmpty
                        ? null
                        : () => Navigator.pop(context, _items),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Confirm & Send'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }
}
