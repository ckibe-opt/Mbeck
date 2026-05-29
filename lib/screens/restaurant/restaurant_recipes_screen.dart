import 'package:flutter/material.dart';
import '../../../widgets/empty_state_guide.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';

class RestaurantRecipesScreen extends StatefulWidget {
  const RestaurantRecipesScreen({super.key});

  @override
  State<RestaurantRecipesScreen> createState() => _RestaurantRecipesScreenState();
}

class _RestaurantRecipesScreenState extends State<RestaurantRecipesScreen> {
  List<Map<String, dynamic>> _menuItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMenuWithRecipes();
  }

  Future<void> _loadMenuWithRecipes() async {
    try {
      final db = await DbProvider.db;
      final items = await db.query('restaurant_menu', orderBy: 'category ASC, name ASC');
      
      final List<Map<String, dynamic>> loaded = [];
      for (final item in items) {
        final links = await db.rawQuery('''
          SELECT r.*, i.name, i.unit_of_measure 
          FROM restaurant_recipes r
          JOIN restaurant_inventory i ON r.restaurant_inventory_id = i.id
          WHERE r.menu_item_id = ?
        ''', [item['id']]);
        
        loaded.add({
          ...item,
          'recipes': List.from(links),
        });
      }

      if (mounted) {
        setState(() {
          _menuItems = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recipes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openRecipeConfigurator(Map<String, dynamic> menuItem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecipeConfiguratorSheet(
        menuItem: menuItem,
        onSave: () {
          Navigator.pop(ctx);
          _loadMenuWithRecipes(); // Refresh the master list when done
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('Recipe Configurator', style: TextStyle(color: AppColors.gray900, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _menuItems.isEmpty
              ? const EmptyStateGuide(
                  icon: Icons.restaurant_menu,
                  title: 'No recipes configured',
                  subtitle: 'Add items in the Menu Manager first, then come back to link ingredients for auto-deducting stock per order',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _menuItems.length,
                  itemBuilder: (context, index) {
                    final item = _menuItems[index];
                    final recipes = item['recipes'] as List;
                    final hasRecipes = recipes.isNotEmpty;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: hasRecipes ? AppColors.primaryGreen.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          child: Icon(Icons.egg_alt_outlined, color: hasRecipes ? AppColors.primaryGreen : Colors.orange),
                        ),
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(
                          hasRecipes ? '${recipes.length} ingredients linked' : 'No ingredients linked',
                          style: TextStyle(color: hasRecipes ? AppColors.gray600 : Colors.orange, fontWeight: hasRecipes ? FontWeight.normal : FontWeight.bold),
                        ),
                        trailing: OutlinedButton(
                          onPressed: () => _openRecipeConfigurator(item),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primaryGreen.withOpacity(0.5)),
                            foregroundColor: AppColors.primaryGreen,
                          ),
                          child: const Text('Configure'),
                        ),
                      ),
                    );
                  },
                ),
          const InteractiveHelpScroll(contextKey: 'recipe'),
        ],
      ),
    );
  }
}

class _RecipeConfiguratorSheet extends StatefulWidget {
  final Map<String, dynamic> menuItem;
  final VoidCallback onSave;

  const _RecipeConfiguratorSheet({required this.menuItem, required this.onSave});

  @override
  State<_RecipeConfiguratorSheet> createState() => _RecipeConfiguratorSheetState();
}

class _RecipeConfiguratorSheetState extends State<_RecipeConfiguratorSheet> {
  List<Map<String, dynamic>> _availableSupplies = [];
  List<Map<String, dynamic>> _linkedSupplies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = await DbProvider.db;
      final inventoryItems = await db.query('restaurant_inventory', orderBy: 'name ASC');
      
      final links = await db.query(
        'restaurant_recipes',
        where: "menu_item_id = ?",
        whereArgs: [widget.menuItem['id']],
      );

      final List<Map<String, dynamic>> linked = [];
      for (final link in links) {
        final inventoryId = link['restaurant_inventory_id'] as int;
        final invItem = inventoryItems.firstWhere((s) => s['id'] == inventoryId, orElse: () => <String, dynamic>{});
        if (invItem.isNotEmpty) {
          linked.add({
            'inventory_id': inventoryId,
            'inventory_name': invItem['name'],
            'unit': invItem['unit_of_measure'],
            'quantity_required': (link['quantity_required'] as num).toDouble(),
          });
        }
      }

      if (mounted) {
        setState(() {
          _availableSupplies = List.from(inventoryItems);
          _linkedSupplies = linked;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recipe configurator: $e');
    }
  }

  Future<void> _save() async {
    try {
      final db = await DbProvider.db;
      final menuItemId = widget.menuItem['id'];
      
      await db.transaction((txn) async {
        await txn.delete('restaurant_recipes', where: "menu_item_id = ?", whereArgs: [menuItemId]);
        for (final link in _linkedSupplies) {
          await txn.insert('restaurant_recipes', {
            'menu_item_id': menuItemId,
            'restaurant_inventory_id': link['inventory_id'],
            'quantity_required': link['quantity_required'],
          });
        }
      });
      
      widget.onSave();
    } catch (e) {
      debugPrint('Error saving recipes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bill of Materials (BOM)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(widget.menuItem['name'], style: TextStyle(color: AppColors.primaryGreen, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('These ingredients will auto-deduct from Kitchen Stock when this meal is served.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(height: 32),
            
            if (_linkedSupplies.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No ingredients linked yet.', style: TextStyle(color: AppColors.gray400, fontStyle: FontStyle.italic))),
              )
            else
              ..._linkedSupplies.asMap().entries.map((entry) {
                  final i = entry.key;
                  final link = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(child: Text('${link['inventory_name']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: TextField(
                            controller: TextEditingController(text: link['quantity_required'].toString()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              suffixText: link['unit'],
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (v) => _linkedSupplies[i]['quantity_required'] = double.tryParse(v) ?? 1,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red.shade300),
                          onPressed: () => setState(() => _linkedSupplies.removeAt(i)),
                        ),
                      ],
                    ),
                  );
              }),
              
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Ingredient Link'),
                onPressed: () {
                  final linkedIds = _linkedSupplies.map((l) => l['inventory_id']).toSet();
                  final available = _availableSupplies.where((s) => !linkedIds.contains(s['id'])).toList();
                  if (available.isEmpty) return;
                  
                  showDialog(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: const Text('Select Raw Ingredient'),
                      children: available.map((s) => SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() => _linkedSupplies.add({
                            'inventory_id': s['id'],
                            'inventory_name': s['name'],
                            'unit': s['unit_of_measure'],
                            'quantity_required': 1.0,
                          }));
                        },
                        child: Text('${s['name']} (${s['unit_of_measure']})'),
                      )).toList(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _save,
              child: const Text('Save BOM Configuration', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
