import 'dart:io';
import 'package:flutter/material.dart';
import '../../../widgets/empty_state_guide.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../db/db_provider.dart';
import 'package:uuid/uuid.dart';
import '../../services/event_service.dart';
import '../../services/auth_service.dart';
import '../../services/device_service.dart';
import '../../models/shop.dart';
import '../../theme/design_system.dart';
import '../paywall_screen.dart';
import '../../services/revenuecat_service.dart';
import '../../config/app_config.dart';
import '../../widgets/standard_app_bar.dart';
import '../../widgets/interactive_help_scroll.dart';

/// Menu Management Screen for Restaurant Module.
/// 
/// Allows restaurant owners to:
/// - Add/edit/delete menu items
/// - Organize items by category
/// - Set prices and availability
/// - Add item images
class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  List<Map<String, dynamic>> _menuItems = [];
  List<String> _categories = ['All', 'Appetizers', 'Mains', 'Desserts', 'Drinks'];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = true;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadMenuItems();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bulkPublish(bool publish) async {
    setState(() => _isLoading = true);
    try {
      final db = await DbProvider.db;
      final publishVal = publish ? 1 : 0;
      await db.update(
        'restaurant_menu',
        {'is_published': publishVal, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      );

      // Emit a macro shop update to trigger the global sync engine
      try {
        await EventService.emitEvent(
          eventType: 'SHOP_UPDATE',
          payload: {
            'action': publish ? 'bulk_publish' : 'bulk_unpublish',
            'module': 'restaurant',
          },
        );
      } catch (e) {
        debugPrint('⚠️ Failed to emit bulk publish event: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(publish ? 'All menu items published to marketplace!' : 'All menu items removed from marketplace.')),
        );
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    _loadMenuItems();
  }


  Future<void> _loadCategories() async {
    try {
      final db = await DbProvider.db;
      final result = await db.rawQuery(
        'SELECT DISTINCT category FROM restaurant_menu ORDER BY category',
      );
      
      final cats = ['All'];
      for (final row in result) {
        final cat = row['category'] as String?;
        if (cat != null && cat.isNotEmpty && !cats.contains(cat)) {
          cats.add(cat);
        }
      }
      
      // Ensure default categories are present
      for (final defaultCat in ['Appetizers', 'Mains', 'Desserts', 'Drinks']) {
        if (!cats.contains(defaultCat)) cats.add(defaultCat);
      }
      
      if (mounted) setState(() => _categories = cats);
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadMenuItems() async {
    setState(() => _isLoading = true);

    try {
      final db = await DbProvider.db;
      
      String whereClause = 'WHERE 1=1';
      List<dynamic> args = [];
      
      if (_selectedCategory != 'All') {
        whereClause += ' AND category = ?';
        args.add(_selectedCategory);
      }
      
      if (_searchQuery.isNotEmpty) {
        whereClause += ' AND (name LIKE ? OR description LIKE ?)';
        args.add('%$_searchQuery%');
        args.add('%$_searchQuery%');
      }
      
      final result = await db.rawQuery(
        'SELECT * FROM restaurant_menu $whereClause ORDER BY sort_order, name',
        args,
      );

      if (mounted) {
        setState(() {
          _menuItems = List.from(result);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading menu items: $e');
      if (mounted) {
        setState(() {
          _menuItems = [];
          _isLoading = false;
        });
      }
    }
  }

  void _refresh() {
    _loadCategories();
    _loadMenuItems();
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
    _loadMenuItems();
  }



  Future<void> _addMenuItem() async {
    // Check menu item limit for FREE tier
    final shop = await AuthService.getCurrentShop();
    final isProSub = await RevenueCatService.isProSubscriber();
    if (shop != null && !isProSub && shop.isMenuLimitReached(_menuItems.length)) {
      if (mounted) {
        PaywallScreen.show(context, featureName: 'Menu Limit Reached (Max ${shop.maxMenuItems} items)');
      }
      return;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MenuItemFormSheet(
        availableCategories: _categories.where((c) => c != 'All').toList(),
      ),
    );

    if (result != null && mounted) {
      try {
        final db = await DbProvider.db;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final cloudId = result['cloud_id'] ?? const Uuid().v4();
        final rowId = await db.insert('restaurant_menu', {
          'cloud_id': cloudId,
          'name': result['name'],
          'description': result['description'],
          'price': result['price'],
          'category': result['category'],
          'image_path': result['imagePath'],
          'available': result['available'] ? 1 : 0,
          'prep_time_minutes': result['prepTime'],
          'is_published': result['isPublished'] ? 1 : 0,
          'created_at': timestamp,
        });
        
        // Supply links (Recipes) are now strictly handled in restaurant_recipes_screen.dart

        // Emit event for LAN sync
        await EventService.emitEvent(
          eventType: 'MENU_CREATE',
          payload: {
            'menu_item_id': rowId,
            'name': result['name'],
            'description': result['description'],
            'price': result['price'],
            'category': result['category'],
            'is_available': result['available'] ? 1 : 0,
            'prep_time_minutes': result['prepTime'],
          },
        );

        // Sync to Supabase cloud for cross-device initial sync
        await _syncMenuItemToCloud(cloudId, {
          'name': result['name'],
          'description': result['description'],
          'price': result['price'],
          'category': result['category'],
          'prep_time_minutes': result['prepTime'],
        });

        _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Menu item added!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  Future<void> _editMenuItem(Map<String, dynamic> item) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MenuItemFormSheet(
        existingItem: item,
        availableCategories: _categories.where((c) => c != 'All').toList(),
        onDelete: () async {
          try {
            final db = await DbProvider.db;
            await db.delete(
              'restaurant_menu',
              where: 'id = ?',
              whereArgs: [item['id']],
            );

            // Emit event for LAN sync
            await EventService.emitEvent(
              eventType: 'MENU_DELETE',
              payload: {
                'menu_item_id': item['id'],
                'name': item['name']?.toString(),
              },
            );

            // Delete from Supabase cloud
            await _deleteMenuItemFromCloud(item['cloud_id'] as String?);

            if (mounted) {
              Navigator.pop(ctx);
              _refresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Menu item deleted')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
              );
            }
          }
        },
      ),
    );

    if (result != null && mounted) {
      try {
        final db = await DbProvider.db;
        await db.update(
          'restaurant_menu',
          {
            'name': result['name'],
            'description': result['description'],
            'price': result['price'],
            'category': result['category'],
            'image_path': result['imagePath'],
            'available': result['available'] ? 1 : 0,
            'prep_time_minutes': result['prepTime'],
            'is_published': result['isPublished'] ? 1 : 0,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [item['id']],
        );

        // Supply links (Recipes) are now strictly handled in restaurant_recipes_screen.dart

        // Emit event for LAN sync
        await EventService.emitEvent(
          eventType: 'MENU_UPDATE',
          payload: {
            'menu_item_id': item['id'],
            'name': result['name'],
            'description': result['description'],
            'price': result['price'],
            'category': result['category'],
            'is_available': result['available'] ? 1 : 0,
            'prep_time_minutes': result['prepTime'],
          },
        );

        // Sync update to Supabase cloud
        await _syncMenuItemToCloud(item['cloud_id'] as String?, {
          'name': result['name'],
          'description': result['description'],
          'price': result['price'],
          'category': result['category'],
          'prep_time_minutes': result['prepTime'],
        });

        _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  Future<void> _toggleAvailability(Map<String, dynamic> item) async {
    try {
      final db = await DbProvider.db;
      final newAvailable = (item['available'] as int) == 1 ? 0 : 1;
      await db.update(
        'restaurant_menu',
        {'available': newAvailable, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [item['id']],
      );
      

      // Emit event for LAN sync
      await EventService.emitEvent(
        eventType: 'MENU_UPDATE',
        payload: {
          'menu_item_id': item['id'],
          'name': item['name']?.toString(),
          'is_available': newAvailable,
        },
      );

      _loadMenuItems();
    } catch (e) {
      debugPrint('Error toggling availability: $e');
    }
  }

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final isSelected = cat == _selectedCategory;
          return ChoiceChip(
            label: Text(cat == 'All' ? 'All' : cat),
            selected: isSelected,
            selectedColor: AppColors.primaryGreen,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : null,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
            onSelected: (_) => _onCategorySelected(cat),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardAppBar(
        title: 'Menu Management',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addMenuItem,
            tooltip: 'Add Item',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'publish_all') _bulkPublish(true);
              if (val == 'unpublish_all') _bulkPublish(false);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'publish_all',
                child: Row(children: [Icon(Icons.public, color: AppColors.primaryGreen, size: 20), SizedBox(width: 8), Text('Publish All Online')]),
              ),
              const PopupMenuItem(
                value: 'unpublish_all',
                child: Row(children: [Icon(Icons.cloud_off, color: Colors.red, size: 20), SizedBox(width: 8), Text('Unpublish All')]),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search menu items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          _loadMenuItems();
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                filled: true,
                fillColor: AppColors.gray50,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _loadMenuItems();
              },
            ),
          ),
          _buildCategoryBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _menuItems.isEmpty
                    ? EmptyStateGuide(
                        icon: Icons.restaurant_menu,
                        title: 'Your menu is empty',
                        subtitle: 'Add dishes and drinks — customers will see these when ordering',
                        actionLabel: 'Add Menu Item',
                        onAction: _addMenuItem,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _menuItems.length,
                        itemBuilder: (context, index) => _buildMenuItemCard(_menuItems[index]),
                      ),
          ),
        ],
      ),
      const InteractiveHelpScroll(contextKey: 'menu'),
      ],
      ),
      // floatingActionButton removed to avoid double FAB with Main Screen
    );
  }

  Widget _buildMenuItemCard(Map<String, dynamic> item) {
    final isAvailable = (item['available'] as int?) == 1;
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final prepTime = item['prep_time_minutes'] as int? ?? 15;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: _buildItemImage(item),
        title: Text(
          item['name'] ?? 'Unnamed',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: isAvailable ? null : TextDecoration.lineThrough,
            color: isAvailable ? null : AppColors.gray400,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item['description'] != null && item['description'].isNotEmpty)
              Text(
                item['description'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.gray500),
              ),
            Row(
              children: [
                Text(
                  'KES ${price.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.schedule, size: 14, color: AppColors.gray400),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    '$prepTime min',
                    style: TextStyle(fontSize: 12, color: AppColors.gray500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((item['is_published'] as int?) == 1)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.public, size: 20, color: AppColors.primaryGreen),
              ),
            IconButton(
              icon: Icon(
                isAvailable ? Icons.check_circle : Icons.cancel,
                color: isAvailable ? AppColors.success : AppColors.gray400,
              ),
              onPressed: () => _toggleAvailability(item),
              tooltip: isAvailable ? 'Mark unavailable' : 'Mark available',
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editMenuItem(item),
            ),
          ],
        ),
        onTap: () => _editMenuItem(item),
      ),
    );
  }

  Widget _buildItemImage(Map<String, dynamic> item) {
    final imagePath = item['image_path'] as String?;
    
    if (imagePath != null && imagePath.isNotEmpty) {
      return FutureBuilder<File>(
        future: _resolveImageFile(imagePath),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null && snapshot.data!.existsSync()) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                snapshot.data!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            );
          }
          return _buildPlaceholderImage();
        },
      );
    }
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.gray200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.restaurant, color: AppColors.gray400),
    );
  }

  /// Sync a menu item to Supabase cloud (upsert by cloud_id)
  Future<void> _syncMenuItemToCloud(String? cloudId, Map<String, dynamic> data) async {
    if (cloudId == null) return;
    try {
      final supabase = Supabase.instance.client;
      final shopId = await DeviceService.getShopId();
      await supabase.from('restaurant_menu').upsert({
        'id': cloudId,
        'shop_id': shopId,
        'item_name': data['name'],
        'description': data['description'],
        'price': data['price'],
        'category': data['category'],
        'preparation_time_mins': data['prep_time_minutes'],
        'updated_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
      debugPrint('☁️ Synced menu item to cloud: ${data['name']}');
    } catch (e) {
      debugPrint('⚠️ Cloud sync failed for menu item (offline): $e');
    }
  }

  /// Delete a menu item from Supabase cloud
  Future<void> _deleteMenuItemFromCloud(String? cloudId) async {
    if (cloudId == null) return;
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('restaurant_menu').delete().eq('id', cloudId);
      debugPrint('☁️ Deleted menu item from cloud: $cloudId');
    } catch (e) {
      debugPrint('⚠️ Cloud delete failed for menu item (offline): $e');
    }
  }

  Future<File> _resolveImageFile(String imagePath) async {
    final directFile = File(imagePath);
    if (await directFile.exists()) return directFile;

    final directory = await getApplicationDocumentsDirectory();
    final filename = path.basename(imagePath);
    return File(path.join(directory.path, filename));
  }
}

// ============================================================
// MENU ITEM FORM DIALOG
// ============================================================

class _MenuItemFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existingItem;
  final List<String> availableCategories;
  final VoidCallback? onDelete;

  const _MenuItemFormSheet({
    this.existingItem,
    required this.availableCategories,
    this.onDelete,
  });

  @override
  State<_MenuItemFormSheet> createState() => _MenuItemFormSheetState();
}

class _MenuItemFormSheetState extends State<_MenuItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _prepTimeCtrl = TextEditingController(text: '15');
  
  String _selectedCategory = 'Mains';
  String? _imagePath;
  bool _isAvailable = true;
  bool _isPublished = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _nameCtrl.text = item['name'] ?? '';
      _descCtrl.text = item['description'] ?? '';
      _priceCtrl.text = (item['price'] as num?)?.toString() ?? '';
      _prepTimeCtrl.text = (item['prep_time_minutes'] ?? 15).toString();
      _selectedCategory = item['category'] ?? 'Mains';
      _imagePath = item['image_path'];
      _isAvailable = (item['available'] as int?) == 1;
      _isPublished = (item['is_published'] as int?) == 1;
    }
    
    if (!widget.availableCategories.contains(_selectedCategory)) {
      _selectedCategory = widget.availableCategories.isNotEmpty 
          ? widget.availableCategories.first 
          : 'Mains';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _prepTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Take Photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;

    final XFile? photo = await _picker.pickImage(
      source: source,
      imageQuality: 50, maxWidth: 512, maxHeight: 512,
    );
    
    if (photo != null) {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'menu_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await File(photo.path).copy('${directory.path}/$fileName');
      setState(() => _imagePath = savedImage.path);
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop({
        'cloud_id': const Uuid().v4(),
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text) ?? 0.0,
        'category': _selectedCategory,
        'imagePath': _imagePath,
        'available': _isAvailable,
        'prepTime': int.tryParse(_prepTimeCtrl.text) ?? 15,
        'isPublished': _isPublished,
      });
    }
  }
  
  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.gray200,
      child: const Center(
        child: Icon(Icons.add_a_photo, color: AppColors.gray400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingItem != null;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Edit Menu Item' : 'New Menu Item',
                style: AppTypography.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: AppColors.gray300),
                  ),
                  child: _imagePath != null && _imagePath!.isNotEmpty && File(_imagePath!).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          child: Image.file(
                            File(_imagePath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                          ),
                        )
                      : _buildImagePlaceholder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Name field
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'e.g., Chicken Tikka',
                  prefixIcon: const Icon(Icons.fastfood),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v?.trim().isEmpty ?? true ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              
              // Description field
              TextFormField(
                controller: _descCtrl,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief description of the dish',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              
              // Price and Prep time row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _priceCtrl,
                      decoration: InputDecoration(
                        labelText: 'Price (KES) *',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        if (double.tryParse(v!) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _prepTimeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Prep(m)',
                        prefixIcon: const Icon(Icons.schedule, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category — chip selector with inline "+ New"
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Category', style: AppTypography.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // Existing + default categories as chips
                      ...{
                        // merge defaults with existing, deduped
                        'Starters', 'Mains', 'Grills', 'Sides',
                        'Desserts', 'Drinks', 'Specials',
                        ...widget.availableCategories,
                      }.map((cat) {
                        final sel = _selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: sel,
                          selectedColor: AppColors.primaryGreen,
                          labelStyle: TextStyle(
                            color: sel ? Colors.white : AppColors.gray700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedCategory = cat),
                        );
                      }),
                      // ＋ New category chip
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 14, color: AppColors.primaryGreen),
                        label: const Text('New', style: TextStyle(color: AppColors.primaryGreen, fontSize: 12)),
                        backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                        side: BorderSide(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                        onPressed: () async {
                          final ctrl = TextEditingController();
                          final name = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('New Category'),
                              content: TextField(
                                controller: ctrl,
                                autofocus: true,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. Breakfast',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryGreen,
                                      foregroundColor: Colors.white),
                                  child: const Text('Add'),
                                ),
                              ],
                            ),
                          );
                          ctrl.dispose();
                          if (name != null && name.isNotEmpty && mounted) {
                            setState(() => _selectedCategory = name);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Availability toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Available for Order', style: AppTypography.textTheme.bodyLarge),
                subtitle: Text(
                  _isAvailable ? 'Customers can order this' : 'Hidden from menu',
                  style: TextStyle(fontSize: 12, color: AppColors.gray500),
                ),
                value: _isAvailable,
                onChanged: (val) => setState(() => _isAvailable = val),
                activeThumbColor: AppColors.primaryGreen,
                activeTrackColor: AppColors.primaryGreen.withValues(alpha: 0.3),
              ),
              
              const SizedBox(height: 12),
              
              // Marketplace toggle
              if (AppConfig.showMbeckGoFeatures) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Publish to Marketplace', style: AppTypography.textTheme.bodyLarge),
                  subtitle: Text(
                    _isPublished ? 'Visible in the Mbeck Go app' : 'Only visible in-store',
                    style: TextStyle(fontSize: 12, color: AppColors.gray500),
                  ),
                  value: _isPublished,
                  onChanged: (val) => setState(() => _isPublished = val),
                  activeThumbColor: AppColors.primaryGreen,
                  activeTrackColor: AppColors.primaryGreen.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
              ],
              const Text('Recipes Configurator has been decoupled to the Recipes board.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              
              if (isEditing && widget.onDelete != null) ...[
                const Divider(height: 32),
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Item?'),
                        content: const Text('This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              widget.onDelete!();
                            },
                            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete, color: AppColors.danger),
                  label: const Text('Delete Menu Item', style: TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(isEditing ? 'Save Changes' : 'Add Item'),
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
