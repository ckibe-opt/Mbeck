import 'package:flutter/material.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../../widgets/standard_app_bar.dart';
import '../../widgets/interactive_help_scroll.dart';

class RestaurantInventoryScreen extends StatefulWidget {
  const RestaurantInventoryScreen({super.key});

  @override
  State<RestaurantInventoryScreen> createState() => _RestaurantInventoryScreenState();
}

class _RestaurantInventoryScreenState extends State<RestaurantInventoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final db = await DbProvider.db;
      final result = await db.query('restaurant_inventory', orderBy: 'name ASC');
      if (mounted) {
        setState(() {
          _items = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading restaurant inventory: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditSheet([Map<String, dynamic>? item]) {
    final isEditing = item != null;
    final nameCtrl = TextEditingController(text: item?['name']?.toString() ?? '');
    final unitCtrl = TextEditingController(text: item?['unit_of_measure']?.toString() ?? 'kg');
    final stockCtrl = TextEditingController(text: item != null ? (item['stock_level'] as num).toString() : '0');
    final minCtrl = TextEditingController(text: item != null ? (item['min_stock_level'] as num).toString() : '0');
    final costCtrl = TextEditingController(text: item != null ? (item['cost_per_unit'] as num).toString() : '0');
    bool isPublished = (item?['is_published'] as num?)?.toInt() == 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Ingredient' : 'New Ingredient',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (isEditing)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete Ingredient?'),
                            content: const Text('This may break recipes linked to this item.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            final db = await DbProvider.db;
                            await db.delete('restaurant_inventory', where: 'id = ?', whereArgs: [item['id']]);
                            _loadItems();
                          } catch (e) {
                            debugPrint('Error deleting item: $e');
                          }
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ingredient Name',
                  hintText: 'e.g. Tomato Paste, Whole Chicken',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unit of Measure',
                        hintText: 'e.g. kg, L, pcs',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cost Per Unit',
                        prefixText: 'KES ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: stockCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Current Stock',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Alert Min Level',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: SwitchListTile(
                  title: const Text('Publish Online (Mbeck Go)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Allow buyers to discover this item', style: TextStyle(fontSize: 12)),
                  value: isPublished,
                  activeColor: AppColors.primaryGreen,
                  onChanged: (val) => setStateSheet(() => isPublished = val),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                  child: Text(isEditing ? 'Save Changes' : 'Add Ingredient'),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    try {
                      final db = await DbProvider.db;
                      final data = {
                        'name': name,
                        'unit_of_measure': unitCtrl.text.trim(),
                        'stock_level': double.tryParse(stockCtrl.text) ?? 0.0,
                        'min_stock_level': double.tryParse(minCtrl.text) ?? 0.0,
                        'cost_per_unit': double.tryParse(costCtrl.text) ?? 0.0,
                        'is_published': isPublished ? 1 : 0,
                        'updated_at': DateTime.now().millisecondsSinceEpoch,
                      };

                      if (isEditing) {
                        await db.update('restaurant_inventory', data, where: 'id = ?', whereArgs: [item['id']]);
                      } else {
                        data['created_at'] = DateTime.now().millisecondsSinceEpoch;
                        await db.insert('restaurant_inventory', data);
                      }
                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadItems();
                      }
                    } catch (e) {
                      debugPrint('Error saving inventory: $e');
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      unitCtrl.dispose();
      stockCtrl.dispose();
      minCtrl.dispose();
      costCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: StandardAppBar(
        title: 'Kitchen Stock',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddEditSheet(),
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) {
                    final item = _items[i];
                    final stock = (item['stock_level'] as num).toDouble();
                    final min = (item['min_stock_level'] as num).toDouble();
                    final isLow = stock <= min;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      child: ListTile(
                        onTap: () => _showAddEditSheet(item),
                        leading: CircleAvatar(
                          backgroundColor: isLow ? Colors.red.shade50 : AppColors.gray100,
                          child: Icon(
                            Icons.kitchen,
                            color: isLow ? Colors.red : AppColors.gray600,
                          ),
                        ),
                        title: Text(
                          item['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${item['cost_per_unit']} KES / ${item['unit_of_measure']}',
                          style: TextStyle(color: AppColors.gray500, fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$stock ${item['unit_of_measure']}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isLow ? Colors.red : AppColors.gray900,
                              ),
                            ),
                            if (isLow)
                              const Text(
                                'LOW STOCK',
                                style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          const InteractiveHelpScroll(contextKey: 'rest_inventory'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: () => _showAddEditSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Add Raw Item'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.kitchen, size: 64, color: AppColors.gray300),
          const SizedBox(height: 16),
          const Text(
            'No Kitchen Inventory',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add raw ingredients like flour or meat\nto be deducted by your menu recipes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gray500),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _showAddEditSheet(),
            icon: const Icon(Icons.add),
            label: const Text('Add First Ingredient'),
          ),
        ],
      ),
    );
  }
}
