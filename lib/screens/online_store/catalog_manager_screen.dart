import 'package:flutter/material.dart';
import '../../db/db_provider.dart';
import '../../services/cloud_publish_service.dart';

class CatalogItem {
  final int id;
  final String name;
  final String module;
  final double price;
  final String tableName;
  bool isPublished;

  CatalogItem({
    required this.id,
    required this.name,
    required this.module,
    required this.price,
    required this.tableName,
    required this.isPublished,
  });
}

class CatalogManagerScreen extends StatefulWidget {
  const CatalogManagerScreen({super.key});

  @override
  State<CatalogManagerScreen> createState() => _CatalogManagerScreenState();
}

class _CatalogManagerScreenState extends State<CatalogManagerScreen> {
  bool _isLoading = true;
  List<CatalogItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    List<CatalogItem> temp = [];
    try {
      // 1. Retail
      try {
        final retail = await DbProvider.query('inventory');
        for (final row in retail) {
          temp.add(CatalogItem(
            id: row['id'] as int,
            name: row['name']?.toString() ?? 'Unnamed Retail Item',
            module: 'Retail',
            price: (row['sellingPrice'] as num?)?.toDouble() ?? 0.0,
            tableName: 'inventory',
            isPublished: row['is_published'] == 1,
          ));
        }
      } catch (e) {
        debugPrint('Error querying retail catalog: $e');
      }

      // 2. Restaurant
      try {
        final menu = await DbProvider.query('restaurant_menu');
        for (final row in menu) {
          temp.add(CatalogItem(
            id: row['id'] as int,
            name: row['name']?.toString() ?? 'Unnamed Menu Item',
            module: 'Restaurant',
            price: (row['price'] as num?)?.toDouble() ?? 0.0,
            tableName: 'restaurant_menu',
            isPublished: row['is_published'] == 1,
          ));
        }
      } catch (e) {
        debugPrint('Error querying restaurant catalog: $e');
      }

      // 3. Services
      try {
        final services = await DbProvider.query('services_catalog');
        for (final row in services) {
          temp.add(CatalogItem(
            id: row['id'] as int,
            name: row['name']?.toString() ?? 'Unnamed Service',
            module: 'Services',
            price: (row['price'] as num?)?.toDouble() ?? 0.0,
            tableName: 'services_catalog',
            isPublished: row['is_published'] == 1,
          ));
        }
      } catch (e) {
        debugPrint('Error querying services catalog: $e');
      }

      // 4. Lodging Room Types
      try {
        final rooms = await DbProvider.query('lodging_room_types');
        for (final row in rooms) {
          temp.add(CatalogItem(
            id: row['id'] as int,
            name: row['name']?.toString() ?? 'Unnamed Room Type',
            module: 'Lodging',
            price: (row['rate_per_night'] as num?)?.toDouble() ?? 0.0,
            tableName: 'lodging_room_types',
            isPublished: row['is_published'] == 1,
          ));
        }
      } catch (e) {
        debugPrint('Error querying lodging room types catalog: $e');
      }

      // 5. Entertainment Asset Types
      try {
        final assets = await DbProvider.query('entertainment_asset_types');
        for (final row in assets) {
          final price = (row['rate_per_hour'] as num?)?.toDouble() ?? (row['flat_rate'] as num?)?.toDouble() ?? 0.0;
          temp.add(CatalogItem(
            id: row['id'] as int,
            name: row['name']?.toString() ?? 'Unnamed Asset Type',
            module: 'Entertainment',
            price: price,
            tableName: 'entertainment_asset_types',
            isPublished: row['is_published'] == 1,
          ));
        }
      } catch (e) {
        debugPrint('Error querying entertainment asset types catalog: $e');
      }

      if (mounted) {
        setState(() {
          _items = temp;
        });
      }
    } catch (e) {
      debugPrint('Error loading catalog items: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleItemPublish(CatalogItem item, bool val) async {
    setState(() {
      item.isPublished = val;
    });

    try {
      final db = await DbProvider.db;
      await db.update(
        item.tableName,
        {'is_published': val ? 1 : 0},
        where: 'id = ?',
        whereArgs: [item.id],
      );

      // Trigger cloud publish
      await CloudPublishService.publishShopAndInventory();
    } catch (e) {
      debugPrint('Error toggling item publish state: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update catalog item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Catalog Manager'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.withOpacity(0.1),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Select which local inventory items, menus, and services should be synced to Mbeck Go.',
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(
                          child: Text(
                            'No items found in any modules.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return CheckboxListTile(
                              title: Text(item.name),
                              subtitle: Text('${item.module} • \$${item.price.toStringAsFixed(2)}'),
                              value: item.isPublished,
                              onChanged: (val) {
                                if (val != null) {
                                  _toggleItemPublish(item, val);
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
