import 'package:flutter/material.dart';
import '../../../widgets/empty_state_guide.dart';
import '../../theme/design_system.dart';
import '../../../db/db_provider.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../services/inventory_service.dart';
import '../../../widgets/interactive_help_scroll.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _purchaseOrders = [];
  List<InventoryItem> _inventoryItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final suppliers = await DbProvider.query('retail_suppliers');
      
      final db = await DbProvider.db;
      final pos = await db.rawQuery('''
        SELECT po.*, s.name as supplier_name 
        FROM retail_purchase_orders po 
        LEFT JOIN retail_suppliers s ON po.supplier_id = s.id 
        ORDER BY po.eta_date DESC
      ''');
      
      final itemsData = await InventoryService.getItems();
      final items = itemsData.map((item) => InventoryItem.fromMap(item)).toList();
      
      if (mounted) {
        setState(() {
          _suppliers = suppliers;
          _purchaseOrders = pos;
          _inventoryItems = items;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddPOModal() {
    if (_suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a supplier first before creating a Purchase Order.')));
      return;
    }
    
    int? selectedSupplierId = _suppliers.first['id'] as int;
    bool isSaving = false;
    
    // Hold temporary line items for this PO
    // Format: { 'item': InventoryItem, 'qtyCtrl': TextEditingController, 'costCtrl': TextEditingController }
    List<Map<String, dynamic>> lineItems = [];
    
    double calculateTotal() {
      double total = 0;
      for (var line in lineItems) {
        final qty = int.tryParse(line['qtyCtrl'].text) ?? 0;
        final cost = double.tryParse(line['costCtrl'].text) ?? 0.0;
        total += (qty * cost);
      }
      return total;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentTotal = calculateTotal();
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16, right: 16, top: 16,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Draft Purchase Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gray900)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedSupplierId,
                  decoration: InputDecoration(
                    labelText: 'Select Supplier',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                    filled: true,
                    fillColor: AppColors.gray50,
                  ),
                  items: _suppliers.map((s) {
                    return DropdownMenuItem<int>(
                      value: s['id'] as int,
                      child: Text(s['name']),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setModalState(() => selectedSupplierId = val);
                  },
                ),
                const SizedBox(height: 16),
                
                // Line Items Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Items to Order', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gray700)),
                    TextButton.icon(
                      onPressed: () {
                        if (_inventoryItems.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No inventory items to add.')));
                          return;
                        }
                        setModalState(() {
                          lineItems.add({
                            'item': _inventoryItems.first,
                            'qtyCtrl': TextEditingController(text: '1'),
                            'costCtrl': TextEditingController(text: _inventoryItems.first.originalPrice.toString()),
                          });
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
                const Divider(),
                
                // Line Items List
                Expanded(
                  child: lineItems.isEmpty 
                    ? Center(child: Text('No items added to PO yet.', style: TextStyle(color: AppColors.gray400)))
                    : ListView.builder(
                        itemCount: lineItems.length,
                        itemBuilder: (context, index) {
                          final line = lineItems[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.gray200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<InventoryItem>(
                                        value: line['item'],
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          labelText: 'Inventory Item',
                                          isDense: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                        ),
                                        items: _inventoryItems.map((item) {
                                          return DropdownMenuItem(
                                            value: item,
                                            child: Text(item.name, overflow: TextOverflow.ellipsis),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setModalState(() {
                                              line['item'] = val;
                                              line['costCtrl'].text = val.originalPrice.toString();
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle, color: AppColors.danger),
                                      onPressed: () {
                                        setModalState(() {
                                          final line = lineItems[index];
                                          line['qtyCtrl'].dispose();
                                          line['costCtrl'].dispose();
                                          lineItems.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: line['qtyCtrl'],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Quantity',
                                          isDense: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                        ),
                                        onChanged: (_) => setModalState((){}),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: line['costCtrl'],
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Unit Cost',
                                          isDense: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                        ),
                                        onChanged: (_) => setModalState((){}),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                ),
                
                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.gray200)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimated Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('\$${currentTotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primaryGreen)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        text: 'Save Draft PO',
                        isLoading: isSaving,
                        onPressed: lineItems.isEmpty ? null : () async {
                          if (selectedSupplierId == null) return;
                          
                          setModalState(() => isSaving = true);
                          
                          try {
                            // 1. Create the base PO
                            final poId = await DbProvider.insert('retail_purchase_orders', {
                              'supplier_id': selectedSupplierId,
                              'status': 'draft',
                              'total_cost': calculateTotal(),
                              'eta_date': DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
                              'created_at': DateTime.now().millisecondsSinceEpoch,
                              'updated_at': DateTime.now().millisecondsSinceEpoch,
                            });
                            
                            // 2. Add the line items
                            for (var line in lineItems) {
                              final qty = int.tryParse(line['qtyCtrl'].text) ?? 0;
                              final cost = double.tryParse(line['costCtrl'].text) ?? 0.0;
                              if (qty > 0) {
                                await DbProvider.insert('retail_po_items', {
                                  'po_id': poId,
                                  'inventory_id': (line['item'] as InventoryItem).id,
                                  'quantity_ordered': qty,
                                  'quantity_received': 0,
                                  'unit_cost': cost,
                                });
                              }
                            }
                            
                            if (mounted) Navigator.pop(context);
                            _loadData();
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save PO: $e')));
                          } finally {
                            setModalState(() => isSaving = false);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      ),
    ).then((_) {
      for (final line in lineItems) {
        line['qtyCtrl'].dispose();
        line['costCtrl'].dispose();
      }
    });
  }

  void _showAddSupplierModal() {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 16,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Supplier', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gray900)),
              const SizedBox(height: 16),
              CustomTextField(controller: nameCtrl, label: 'Company Name', icon: Icons.business),
              const SizedBox(height: 12),
              CustomTextField(controller: contactCtrl, label: 'Contact Person', icon: Icons.person),
              const SizedBox(height: 12),
              CustomTextField(controller: phoneCtrl, label: 'Phone', icon: Icons.phone, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              CustomTextField(controller: emailCtrl, label: 'Email', icon: Icons.email, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Save Supplier',
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  await DbProvider.insert('retail_suppliers', {
                    'name': nameCtrl.text,
                    'contact_name': contactCtrl.text,
                    'phone': phoneCtrl.text,
                    'email': emailCtrl.text,
                  });
                  if (mounted) Navigator.pop(context);
                  _loadData();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      contactCtrl.dispose();
      phoneCtrl.dispose();
      emailCtrl.dispose();
    });
  }

  Future<void> _markPOReceived(int poId) async {
    // Standard real-world logic: hitting endpoint /api/v1/retail/purchase_orders/:id/receive
    // We execute the SQLite equivalent to update inventory automatically
    try {
      await DbProvider.transaction((txn) async {
        // 1. Mark PO as received
        await txn.update('retail_purchase_orders', {'status': 'received'}, where: 'id = ?', whereArgs: [poId]);
        
        // 2. Load line items
        final items = await txn.query('retail_po_items', where: 'po_id = ?', whereArgs: [poId]);
        
        // 3. Auto-increment stock and recalculate Moving Average Cost
        double totalCost = 0;
        for (var item in items) {
          int invId = item['inventory_id'] as int;
          int newlyReceivedQty = item['quantity_ordered'] as int;
          double incomingUnitCost = (item['unit_cost'] as num).toDouble();
          totalCost += (newlyReceivedQty * incomingUnitCost);
          
          // Get current stock and cost to calculate the new moving average
          final invRows = await txn.query('inventory', where: 'id = ?', whereArgs: [invId], limit: 1);
          if (invRows.isNotEmpty) {
            final currentStockStr = invRows.first['stock']?.toString() ?? '0';
            final int currentStock = int.tryParse(currentStockStr.split('.').first) ?? 0;
            
            final double currentUnitPrice = (invRows.first['originalPrice'] as num?)?.toDouble() ?? 0.0;
            
            // Weighted Average Cost calculation
            // Only recalculate if incoming unit cost > 0 (as requested by user) and we actually received items
            double newAvgCost = currentUnitPrice;
            
            if (incomingUnitCost > 0 && newlyReceivedQty > 0) {
                // If old stock is negative, treat it as 0 for the cost calculation baseline
                final safeOldStock = currentStock < 0 ? 0 : currentStock;
                
                final totalOldValue = safeOldStock * currentUnitPrice;
                final totalNewValue = newlyReceivedQty * incomingUnitCost;
                
                final totalNewStock = safeOldStock + newlyReceivedQty;
                
                newAvgCost = totalNewStock > 0 
                    ? (totalOldValue + totalNewValue) / totalNewStock 
                    : incomingUnitCost;
            }
            
            await txn.rawUpdate(
              'UPDATE inventory SET stock = stock + ?, originalPrice = ? WHERE id = ?',
              [newlyReceivedQty, newAvgCost, invId]
            );
          }
        }
        
        // 4. Register expense transaction (accounting expects positive 'outgoing')
        await txn.insert('txn', {
          'totalAmount': totalCost,
          'type': 'outgoing',
          'source_module': 'retail',
          'details': 'PO #$poId received',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      });
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase Order Received & Logged as Expense.'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  void _showPODetails(Map<String, dynamic> po) async {
    final poId = po['id'] as int;
    final db = await DbProvider.db;
    final detailedItems = await db.rawQuery('''
      SELECT po_item.*, i.name as item_name
      FROM retail_po_items po_item
      LEFT JOIN inventory i ON po_item.inventory_id = i.id
      WHERE po_item.po_id = ?
    ''', [poId]);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('PO #$poId Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('Supplier: ${po['supplier_name'] ?? 'Unknown'}', style: TextStyle(color: AppColors.gray600)),
              const SizedBox(height: 16),
              const Divider(),
              if (detailedItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No line items found for this PO.'),
                )
              else
                ...detailedItems.map((item) {
                  final qty = item['quantity_ordered'] as int;
                  final cost = (item['unit_cost'] as num).toDouble();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item['item_name']?.toString() ?? 'Unknown Item', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Qty: $qty @ \$${cost.toStringAsFixed(2)}'),
                    trailing: Text('\$${(qty * cost).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                  );
                }).toList(),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Cost:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('\$${(po['total_cost'] as num?)?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.gray900)),
                ],
              ),
              const SizedBox(height: 24),
              PrimaryButton(text: 'Close', onPressed: () => Navigator.pop(context)),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text('Suppliers & POs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.gray900)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.gray900),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: AppColors.gray500,
          indicatorColor: AppColors.primaryGreen,
          tabs: const [
            Tab(text: 'Purchase Orders'),
            Tab(text: 'Suppliers Directory'),
          ],
        ),
      ),
      body: Stack(
        children: [
          _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  // POs Tab
                  Stack(
                    children: [
                      _purchaseOrders.isEmpty 
                          ? EmptyStateGuide(
                              icon: Icons.receipt_long,
                              title: 'No purchase orders yet',
                              subtitle: 'Create a PO to track orders from your suppliers and auto-update stock on delivery',
                              actionLabel: 'Create PO',
                              onAction: _showAddPOModal,
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _purchaseOrders.length,
                              separatorBuilder: (_,__) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final po = _purchaseOrders[index];
                                final isReceived = po['status'] == 'received';
                                return InkWell(
                                  onTap: () => _showPODetails(po),
                                  borderRadius: BorderRadius.circular(12.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.0), border: Border.all(color: AppColors.gray200)),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: isReceived ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1), shape: BoxShape.circle),
                                          child: Icon(isReceived ? Icons.check_circle : Icons.local_shipping, color: isReceived ? AppColors.success : AppColors.warning),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('PO #${po['id']} - ${po['supplier_name'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              const SizedBox(height: 4),
                                              Text('Total: \$${(po['total_cost'] as num?)?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(color: AppColors.gray600)),
                                            ],
                                          ),
                                        ),
                                        if (!isReceived)
                                          TextButton(
                                            onPressed: () => _markPOReceived(po['id'] as int),
                                            style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                                            child: const Text('Mark Received'),
                                          )
                                        else
                                          Text('Completed', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                      Positioned(
                        bottom: 24, right: 24,
                        child: FloatingActionButton(
                          backgroundColor: AppColors.primaryGreen,
                          onPressed: _showAddPOModal,
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                        
                        
                  // Suppliers Tab
                  Stack(
                    children: [
                      _suppliers.isEmpty 
                          ? EmptyStateGuide(
                              icon: Icons.business,
                              title: 'No suppliers yet',
                              subtitle: 'Add your vendors so you can create purchase orders and track deliveries',
                              actionLabel: 'Add Supplier',
                              onAction: _showAddSupplierModal,
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _suppliers.length,
                              separatorBuilder: (_,__) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final s = _suppliers[index];
                                return ListTile(
                                  tileColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0), side: BorderSide(color: AppColors.gray200)),
                                  leading: CircleAvatar(backgroundColor: AppColors.primaryLight, child: Text(s['name'].toString()[0].toUpperCase(), style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold))),
                                  title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${s['contact_name'] ?? ''} • ${s['phone'] ?? ''}'),
                                  trailing: const Icon(Icons.chevron_right, color: AppColors.gray400),
                                );
                              },
                            ),
                      Positioned(
                        bottom: 24, right: 24,
                        child: FloatingActionButton(
                          backgroundColor: AppColors.primaryGreen,
                          onPressed: _showAddSupplierModal,
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          const InteractiveHelpScroll(contextKey: 'suppliers'),
        ],
      ),
    );
  }

  // _buildEmptyState removed — replaced by EmptyStateGuide widget
}
