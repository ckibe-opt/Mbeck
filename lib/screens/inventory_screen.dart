import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/empty_state_guide.dart';
import '../db/db_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../theme/design_system.dart';
import '../models/permissions.dart';
import '../widgets/permission_guard.dart';
import '../widgets/standard_app_bar.dart';
import '../services/auth_service.dart';
import '../models/shop.dart';
import 'paywall_screen.dart';
import '../services/revenuecat_service.dart';
import '../config/app_config.dart';
import '../services/inventory_service.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import 'dart:convert';
import 'barcode_scanner_screen.dart';


class InventoryScreen extends StatefulWidget {
  final bool isPicker;
  final String? initialAddItemName; // New: For Quick Add from Analytics

  const InventoryScreen({super.key, this.isPicker = false, this.initialAddItemName});

  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _items = [];
  List<String> _categories = ['All'];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = true;
  bool _lowStockFilter = false;
  int _lowStockCount = 0;
  double _totalStockValue = 0;

  final TextEditingController _searchCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _init();
    
    // Auto-open Add Dialog if requested
    if (widget.initialAddItemName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addNormalItem(initialName: widget.initialAddItemName);
      });
    }
  }

  Future<void> _init() async {
    _loadCategories();
    _loadItems();
  }

  Future<void> _bulkPublish(bool publish) async {
    setState(() => _isLoading = true);
    try {
       await InventoryService.bulkPublish(publish);
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(publish ? 'All items published to marketplace!' : 'All items removed from marketplace.')),
         );
       }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    _loadItems();
  }

  Future<bool> _checkInventoryLimit() async {
    final shop = await AuthService.getCurrentShop();
    if (shop == null) return false; 

    final stats = await DbProvider.getDatabaseStats();
    // Safely cast or parse the count
    final countVal = stats['total_inventory'];
    final currentCount = (countVal is int) ? countVal : int.tryParse(countVal.toString()) ?? 0;

    final isProSub = await RevenueCatService.isProSubscriber();
    if (!isProSub && shop.isInventoryLimitReached(currentCount)) {
       if (mounted) {
         PaywallScreen.show(context, featureName: 'Inventory Limit Reached (Max ${shop.maxInventoryItems} items)');
       }
       return true;
    }
    return false;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Handle both old (full path) and new (filename only) image paths
  Future<File> _resolveImageFile(String imagePath) async {
    final directFile = File(imagePath);
    if (await directFile.exists()) return directFile;

    final directory = await getApplicationDocumentsDirectory();
    final filename = path.basename(imagePath);
    return File(path.join(directory.path, filename));
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await InventoryService.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (e) {
      debugPrint('Error loading categories (likely permission): $e');
    }
  }


  Future<void> _loadItems() async {
    setState(() => _isLoading = true);

    try {
      final data = await InventoryService.getItems(
        category: _selectedCategory,
        searchQuery: _searchQuery,
      );

      // Calculate stats
      int lowCount = 0;
      double totalValue = 0;
      for (final item in data) {
        final stock = (item['stock'] as num?)?.toInt() ?? 0;
        final price = (item['sellingPrice'] as num?)?.toDouble() ?? 0;
        totalValue += stock * price;
        if (stock <= 5) lowCount++;
      }

      // Apply low-stock filter if active
      final filtered = _lowStockFilter
          ? data.where((item) => ((item['stock'] as num?)?.toInt() ?? 0) <= 5).toList()
          : data;

      if (mounted) {
        setState(() {
          _items = List.from(filtered);
          _lowStockCount = lowCount;
          _totalStockValue = totalValue;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading items: $e');
      if (mounted) {
        setState(() {
          _items = [];
          _isLoading = false;
        });
        // Optional: Show snackbar if it's a permission error
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Access Denied: $e')));
      }
    }
  }

  void _refresh() {
    _loadCategories();
    _loadItems();
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
    _loadItems();
  }

  void _onItemAction(Map<String, dynamic> item) {
    if (widget.isPicker) {
      Navigator.pop(context, item);
    } else {
      _editItem(item);
    }
  }

  Future<XFile?> _pickImageWithSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Take Photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return null;
    return _picker.pickImage(source: source, imageQuality: 50, maxWidth: 512, maxHeight: 512);
  }

  Future<void> _addNormalItem({String? initialName}) async {
    // Check permission
    final member = await AuthService.getCurrentMember();
    if (member != null && !member.hasPermission(Permissions.addInventoryItem)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to add items'), backgroundColor: AppColors.danger),
        );
      }
      return;
    }

    if (await _checkInventoryLimit()) return;
    
    // If we have a specific name (from analytics), just open the form without photo first
    // Or if the user cancelled the camera, do we still want to show the form?
    // Let's stick to the plan: Click button -> Camera -> Form.
    // BUT if initialName is provided (from analytics shortcut), we might want to skip camera or just show form.
    // For now, if initialName is provided, we skip camera to be safe/quick.
    
    String initialPath = '';
    
    if (initialName == null) {
      final XFile? photo = await _pickImageWithSource();
      
      if (photo != null) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_no_ai.jpg';
        final savedImage = await File(photo.path).copy('${directory.path}/$fileName');
        initialPath = savedImage.path;
      } else {
        // User cancelled camera. Do we abort or show text-only form? 
        // Existing "Manual" flow allowed text-only. 
        // Let's allow text-only fallback if they cancel camera, so they aren't blocked.
      }
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ItemFormDialog(
        initialImagePath: initialPath,
        initialName: initialName,
        skipInitialAI: true,
        availableCategories: _categories.where((c) => c != 'All').toList(),
        onSave: (name, category, selling, original, stock, finalPath, visualVector, spec, barcode, variationsJson, isPublished) async {
          try {
            await InventoryService.addItem(
              name: name,
              category: category, 
              sellingPrice: selling, 
              originalPrice: original, 
              stock: stock, 
              imagePath: finalPath,
              visualVector: visualVector,
              specification: spec,
              barcode: barcode,
              variationsJson: variationsJson,
              isPublished: isPublished,
            );
            if (!mounted) return;
            _refresh();
            Navigator.pop(ctx);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
          }
        },
      ),
    );
  }

  Future<void> _addItem() async {
    // Check permission
    final member = await AuthService.getCurrentMember();
    if (member != null && !member.hasPermission(Permissions.addInventoryItem)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to add items'), backgroundColor: AppColors.danger),
        );
      }
      return;
    }

    if (await _checkInventoryLimit()) return;

    final XFile? photo = await _pickImageWithSource();
    if (photo == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedImage = await File(photo.path).copy('${directory.path}/$fileName');

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ItemFormDialog(
        initialImagePath: savedImage.path,
        availableCategories: _categories.where((c) => c != 'All').toList(),
        onSave: (name, category, selling, original, stock, finalPath, visualVector, spec, barcode, variationsJson, isPublished) async {
          try {
            await InventoryService.addItem(
              name: name,
              category: category, 
              sellingPrice: selling, 
              originalPrice: original, 
              stock: stock, 
              imagePath: finalPath,
              visualVector: visualVector,
              specification: spec,
              barcode: barcode,
              variationsJson: variationsJson,
              isPublished: isPublished,
            );
            if (!mounted) return;
            _refresh();
            Navigator.pop(ctx);
          } catch (e) {
             if (!mounted) return;
             ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
          }
        },
      ),
    );
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    // Check permission before allowing edit
    final member = await AuthService.getCurrentMember();
    final hasPermission = member?.hasPermission(Permissions.editInventoryItem) ?? false;
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to edit inventory items'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ItemFormDialog(
        initialImagePath: item['imagePath'] ?? '',
        existingItem: item,
        availableCategories: _categories.where((c) => c != 'All').toList(),
        onDelete: () async {
          try {
            await InventoryService.deleteItem(item);
            
            if (item['imagePath'] != null) {
              final file = await _resolveImageFile(item['imagePath']);
              if (await file.exists()) await file.delete();
            }

            if (!mounted) return;
            _refresh();
            Navigator.pop(ctx);
          } catch (e) {
             if (!mounted) return;
             ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
          }
        },
        onSave: (name, category, selling, original, stock, finalPath, visualVector, spec, barcode, variationsJson, isPublished) async {
          try {
             await InventoryService.updateItem(
               id: item['id'],
               oldItem: item,
               name: name,
               category: category,
               sellingPrice: selling,
               originalPrice: original,
               stock: stock,
               imagePath: finalPath,
               visualVector: visualVector ?? item['visual_vector'],
               specification: spec,
               barcode: barcode,
               variationsJson: variationsJson,
               isPublished: isPublished,
             );
             if (!mounted) return;
             _refresh();
             Navigator.pop(ctx);
          } catch (e) {
             if (!mounted) return;
             ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
          }
        },
      ),
    );
  }

  void _showImageZoom(String imagePath) async {
    final file = await _resolveImageFile(imagePath);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: file.existsSync()
                  ? Image.file(file, fit: BoxFit.contain)
                  : Container(
                      color: AppColors.gray200,
                      child: const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 50)),
                    ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: _categories.contains(_selectedCategory)
            ? _selectedCategory
            : 'All',
        isExpanded: true, // Allow dropdown to take full width
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
          filled: true,
          fillColor: AppColors.gray100,
          prefixIcon: const Icon(Icons.filter_list, color: AppColors.primaryGreen),
        ),
        items: _categories.map((cat) {
          if (cat == 'All') return const DropdownMenuItem(value: 'All', child: Text('All Categories', style: TextStyle(fontWeight: FontWeight.bold)));
          
          final parts = cat.split('\\');
          final indent = '  ' * (parts.length - 1);
          final prefix = parts.length > 1 ? '\u2514\u2500 ' : '';
          final displayName = '$indent$prefix${parts.last}';

          return DropdownMenuItem(
            value: cat,
            child: Tooltip(
              message: cat.split('\\').join(' \u203a '),
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: parts.length == 1 ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) _onCategorySelected(val);
        },
      ),
    );
  }

  Widget _buildStatsBar() {
    if (_isLoading) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          _statPill(
            icon: Icons.inventory_2_outlined,
            label: '${_items.length} items',
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 12),
          _statPill(
            icon: Icons.attach_money,
            label: 'KSH ${_totalStockValue.toStringAsFixed(0)}',
            color: Colors.blue,
          ),
          const Spacer(),
          if (_lowStockCount > 0)
            GestureDetector(
              onTap: () {
                setState(() => _lowStockFilter = !_lowStockFilter);
                _loadItems();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _lowStockFilter ? Colors.red.shade600 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: _lowStockFilter ? Colors.white : Colors.red.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_lowStockCount Low',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _lowStockFilter ? Colors.white : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statPill({required IconData icon, required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardAppBar(
        title: widget.isPicker ? 'Select Product' : 'Inventory (Variations)',
        actions: [
          if (!widget.isPicker) ...[
            IconButton(
              icon: const Icon(Icons.add_a_photo_outlined),
              onPressed: _addNormalItem,
              tooltip: 'Add item with photo (No AI)',
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
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          _loadItems();
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                filled: true,
                fillColor: AppColors.gray50,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _loadItems();
              },
            ),
          ),
          _buildCategoryBar(),
          // Stats bar
          _buildStatsBar(),
          Expanded(
            child: _isLoading
                ? AppSkeleton.screen()
                : _items.isEmpty
                    ? EmptyStateGuide(
                        icon: Icons.inventory_2_outlined,
                        title: 'Your shelves are empty',
                        subtitle: 'Tap + to add your first product — scan a barcode or type a name',
                        actionLabel: 'Add Product',
                        onAction: _addNormalItem,
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) => _buildItemCard(_items[index]),
                      ),
          ),
        ],
      ),
      floatingActionButton: widget.isPicker
          ? null
          : FloatingActionButton(
              heroTag: null,
              onPressed: _addItem,
              child: const Icon(Icons.camera_alt),
            ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final stock = (item['stock'] as num?)?.toInt() ?? 0;
    final isLowStock = stock <= 5;
    final isWarnStock = stock > 5 && stock <= 10;

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onItemAction(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GestureDetector(
                onLongPress: () {
                  if (item['imagePath'] != null) _showImageZoom(item['imagePath']);
                },
                onTap: () => _onItemAction(item),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FutureBuilder<File>(
                      future: _resolveImageFile(item['imagePath'] ?? ''),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null && snapshot.data!.existsSync()) {
                          return Image.file(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            cacheWidth: 300,
                            errorBuilder: (c, e, s) => Container(
                              color: AppColors.gray200,
                              child: const Icon(Icons.broken_image),
                            ),
                          );
                        }
                        return Container(
                          color: AppColors.gray300,
                          child: const Icon(Icons.image),
                        );
                      },
                    ),
                    if (item['visual_vector'] != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 12,
                            color: AppColors.surfaceWhite,
                          ),
                        ),
                      ),
                    // Stock badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isLowStock
                              ? Colors.red.shade600
                              : isWarnStock
                                  ? Colors.orange.shade600
                                  : Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$stock',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Published Badge overlay
                    if (item['is_published'] == 1)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                          child: const Icon(Icons.public, size: 14, color: AppColors.primaryGreen),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'],
                    style: AppTypography.textTheme.headlineMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'KSH ${item['sellingPrice']}',
                          style: AppTypography.textTheme.labelLarge?.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isLowStock)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Low',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemFormDialog extends StatefulWidget {
  final String initialImagePath;
  final Map<String, dynamic>? existingItem;
  final List<String> availableCategories;
  final Function(String, String, double, double, int, String, String?, String, String, String?, bool) onSave;
  final String? initialName;
  final VoidCallback? onDelete;
  final bool skipInitialAI;

  const _ItemFormDialog({
    required this.initialImagePath,
    required this.onSave,
    required this.availableCategories,
    this.existingItem,
    this.initialName,
    this.onDelete,
    this.skipInitialAI = false,
  });

  @override
  __ItemFormDialogState createState() => __ItemFormDialogState();
}

class __ItemFormDialogState extends State<_ItemFormDialog> {
  final _nameCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  final _specCtrl = TextEditingController(); // New Specification
  final _barcodeCtrl = TextEditingController(); // New Barcode
  final _sellCtrl = TextEditingController();
  final _buyCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '1');
  // final _variationsCtrl = TextEditingController(); // Replaced with proper list
  List<ProductVariation> _variations = [];
  late String _currentImagePath;
  bool _isProcessingAI = false;
  bool _isPublished = false;
  // ignore: unused_field
  final ImagePicker _picker = ImagePicker();
  
  late bool _hasInitialImage;


  final FocusNode _nameFocus = FocusNode();
  final FocusNode _catFocus = FocusNode();
  final FocusNode _sellFocus = FocusNode();

  bool _nameError = false;
  bool _catError = false;
  bool _sellError = false;

  // Category picker state  moved to class level to survive sheet rebuilds
  final _newCatCtrl = TextEditingController();

  @override
  void dispose() {
    _nameFocus.dispose();
    _catFocus.dispose();
    _sellFocus.dispose();
    _newCatCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.initialImagePath;
    _hasInitialImage = widget.initialImagePath.isNotEmpty;

    if (widget.existingItem != null) {
      _nameCtrl.text = widget.existingItem!['name'];
      _catCtrl.text = widget.existingItem!['category'] ?? 'General';
      _sellCtrl.text = widget.existingItem!['sellingPrice'].toString();
      _buyCtrl.text = widget.existingItem!['originalPrice'].toString();
      _sellCtrl.text = widget.existingItem!['sellingPrice'].toString();
      _buyCtrl.text = widget.existingItem!['originalPrice'].toString();
      _stockCtrl.text = widget.existingItem!['stock'].toString();
      _specCtrl.text = widget.existingItem!['specification'] ?? '';
      _barcodeCtrl.text = widget.existingItem!['barcode'] ?? '';
      // Parse existing variations
      if (widget.existingItem!['variationsJson'] != null && 
          widget.existingItem!['variationsJson'].isNotEmpty) {
        try {
           final List<dynamic> list = jsonDecode(widget.existingItem!['variationsJson']);
           _variations = list.map((m) => ProductVariation.fromMap(m)).toList();
        } catch (e) {
           debugPrint('Error parsing variations: $e');
        }
      }
      
      if (widget.existingItem!['isPublished'] != null) {
          _isPublished = widget.existingItem!['isPublished'];
      } else if (widget.existingItem!['is_published'] != null) {
          _isPublished = (widget.existingItem!['is_published'] as num).toInt() == 1;
      }
    } else if (widget.initialName != null) {
      _nameCtrl.text = widget.initialName!;
    }
  }

  Future<File> _resolveImageFile(String imagePath) async {
    final directFile = File(imagePath);
    if (await directFile.exists()) return directFile;

    final directory = await getApplicationDocumentsDirectory();
    final filename = path.basename(imagePath);
    return File(path.join(directory.path, filename));
  }


  /// Shows an always-on-page Dialog (solves keyboard-dismiss inside BottomSheet+Dialog).
  /// Tree UX: each existing node has an inline [+] to add a direct child.
  /// Predictive suggestions shown while typing based on the same-depth pool.
  void _showCategoryPicker(BuildContext ctx) {
    final categories = widget.availableCategories;

    // Build full tree map from flat category list
    Map<String, List<String>> buildTree(List<String> cats) {
      final Map<String, List<String>> tree = {'': []};
      for (final cat in cats) {
        final parts = cat.split('\\');
        for (int depth = 0; depth < parts.length; depth++) {
          final nodePath = parts.sublist(0, depth + 1).join('\\');
          final parentPath =
              depth == 0 ? '' : parts.sublist(0, depth).join('\\');
          tree.putIfAbsent(parentPath, () => []);
          if (!tree[parentPath]!.contains(nodePath)) {
            tree[parentPath]!.add(nodePath);
          }
          tree.putIfAbsent(nodePath, () => []);
        }
      }
      return tree;
    }

    final tree = buildTree(categories);

    showDialog<void>(
      context: ctx,
      barrierDismissible: true,
      builder: (dlgCtx) {
        // Local state managed inside StatefulBuilder
        List<String> navStack = [''];
        final newCatCtrl = TextEditingController();
        // Tracks which node has its + field open (only one at a time)
        String? addingChildOf; // null = none, '' = new top-level
        final addChildCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (ctx2, setDlg) {
            final currentPath = navStack.last;
            final children =
                List<String>.from(tree[currentPath] ?? []);
            children.sort();

            String leafName(String p) =>
                p.isEmpty ? '' : p.split('\\').last;

            String breadcrumb = currentPath.isEmpty
                ? 'Select Category'
                : currentPath.split('\\').join(' � ');

            // All node names at the same depth as addingChildOf, for autocomplete
            List<String> suggestions(String parentPath) {
              final siblings = tree[parentPath] ?? [];
              return siblings
                  .map((s) => leafName(s))
                  .where((n) => n.isNotEmpty)
                  .toList();
            }

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // -- Header --
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        if (navStack.length > 1)
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios,
                                size: 18, color: Colors.white),
                            onPressed: () => setDlg(() {
                              navStack.removeLast();
                              addingChildOf = null;
                              addChildCtrl.clear();
                            }),
                            tooltip: 'Back',
                          ),
                        Expanded(
                          child: Text(breadcrumb,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                        ),
                        TextButton.icon(
                            icon: Icon(
                              _catCtrl.text.isNotEmpty
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                              size: 18, color: Colors.white),
                            label: Text(
                              _catCtrl.text.isNotEmpty
                                  ? 'Use: ${_catCtrl.text.split('\\').last}'
                                  : currentPath.isNotEmpty ? 'Use this' : 'Done',
                              style: const TextStyle(color: Colors.white),
                            ),
                            onPressed: () {
                              if (currentPath.isNotEmpty) {
                                setState(() => _catCtrl.text = currentPath);
                              }
                              Navigator.pop(dlgCtx);
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(dlgCtx),
                        ),
                      ],
                    ),
                  ),
                  // -- Tree list --
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Existing children
                          ...children.map((child) {
                            final hasKids =
                                (tree[child] ?? []).isNotEmpty;
                            final isSelected = _catCtrl.text == child;
                            final isAddingHere = addingChildOf == child;

                            return Column(
                              children: [
                                ListTile(
                                  leading: Icon(
                                    hasKids
                                        ? Icons.folder_open
                                        : Icons.label_outline,
                                    color: isSelected
                                        ? AppColors.primaryGreen
                                        : (hasKids
                                            ? Colors.amber.shade700
                                            : Colors.grey),
                                  ),
                                  title: Text(
                                    leafName(child),
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? AppColors.primaryGreen
                                          : null,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // + child button
                                      IconButton(
                                        icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 18,
                                            color: AppColors.primaryGreen),
                                        tooltip: 'Add subcategory',
                                        onPressed: () => setDlg(() {
                                          addingChildOf = isAddingHere
                                              ? null
                                              : child;
                                          addChildCtrl.clear();
                                        }),
                                      ),
                                      if (hasKids)
                                        const Icon(Icons.chevron_right,
                                            color: Colors.grey)
                                      else if (isSelected)
                                        const Icon(Icons.check,
                                            color: AppColors.primaryGreen,
                                            size: 18),
                                    ],
                                  ),
                                  onTap: () {
                                    if (hasKids) {
                                      setDlg(() {
                                        navStack.add(child);
                                        addingChildOf = null;
                                        addChildCtrl.clear();
                                      });
                                    } else {
                                      setState(
                                          () => _catCtrl.text = child);
                                      Navigator.pop(dlgCtx);
                                    }
                                  },
                                  onLongPress: () {
                                    setState(() => _catCtrl.text = child);
                                    Navigator.pop(dlgCtx);
                                  },
                                ),
                                // Inline add-child field
                                if (isAddingHere)
                                  _buildInlineAddField(
                                    ctrl: addChildCtrl,
                                    parentPath: child,
                                    existingSuggestions:
                                        suggestions(child),
                                    onAdd: (name) {
                                      final newFull = '$child\\$name';
                                      tree.putIfAbsent(child, () => []);
                                      if (!tree[child]!
                                          .contains(newFull)) {
                                        tree[child]!.add(newFull);
                                      }
                                      tree.putIfAbsent(newFull, () => []);
                                      // Navigate INTO the new node so the
                                      // user can keep adding children
                                      // without closing the dialog.
                                      setDlg(() {
                                        navStack.add(newFull);
                                        addingChildOf = null;
                                        addChildCtrl.clear();
                                      });
                                      setState(
                                          () => _catCtrl.text = newFull);
                                    },
                                    setDlg: setDlg,
                                    onCancel: () => setDlg(
                                        () => addingChildOf = null),
                                  ),
                              ],
                            );
                          }),

                          const Divider(height: 1),

                          // -- Add new root/sibling --
                          if (addingChildOf != '')
                            ListTile(
                              leading: const Icon(Icons.add,
                                  color: AppColors.primaryGreen),
                              title: Text(
                                currentPath.isEmpty
                                    ? 'New top-level category'
                                    : 'New category inside "${leafName(currentPath)}"',
                                style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w500),
                              ),
                              onTap: () => setDlg(() {
                                addingChildOf = '';
                                newCatCtrl.clear();
                              }),
                            )
                          else
                            _buildInlineAddField(
                              ctrl: newCatCtrl,
                              parentPath: currentPath,
                              existingSuggestions:
                                  suggestions(currentPath),
                              onAdd: (name) {
                                final newFull = currentPath.isEmpty
                                    ? name
                                    : '$currentPath\\$name';
                                tree.putIfAbsent(
                                    currentPath, () => []);
                                if (!tree[currentPath]!
                                    .contains(newFull)) {
                                  tree[currentPath]!.add(newFull);
                                }
                                tree.putIfAbsent(newFull, () => []);
                                // Navigate INTO the new node so the
                                // user can keep adding children
                                // without closing the dialog.
                                setDlg(() {
                                  navStack.add(newFull);
                                  addingChildOf = null;
                                  newCatCtrl.clear();
                                });
                                setState(
                                    () => _catCtrl.text = newFull);
                              },
                              setDlg: setDlg,
                              onCancel: () => setDlg(
                                  () => addingChildOf = null),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Builds the inline "add new node" text field with autocomplete suggestions.
  Widget _buildInlineAddField({
    required TextEditingController ctrl,
    required String parentPath,
    required List<String> existingSuggestions,
    required void Function(String name) onAdd,
    required StateSetter setDlg,
    required VoidCallback onCancel,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: parentPath.isEmpty
                        ? 'e.g. Electronics'
                        : 'e.g. Phones',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setDlg(() {}), // rebuild for suggestions
                  onSubmitted: (v) {
                    final name = v.trim();
                    if (name.isNotEmpty) onAdd(name);
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                onPressed: () {
                  final name = ctrl.text.trim();
                  if (name.isNotEmpty) onAdd(name);
                },
                child: const Text('Add'),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onCancel,
              ),
            ],
          ),
          // Predictive suggestions
          if (ctrl.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: existingSuggestions
                  .where((s) => s
                      .toLowerCase()
                      .contains(ctrl.text.toLowerCase()))
                  .take(5)
                  .map((s) => ActionChip(
                        label: Text(s,
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor:
                            AppColors.primaryGreen.withValues(alpha: 0.08),
                        side: BorderSide(
                            color: AppColors.primaryGreen
                                .withValues(alpha: 0.3)),
                        onPressed: () => onAdd(s),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingItem != null;

    return WillPopScope(
      onWillPop: () async => !_isProcessingAI,
      child: AlertDialog(
        title: Text(isEditing ? 'Edit Item' : 'New Item'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              if (_hasInitialImage)
                FutureBuilder<File>(
                  future: _resolveImageFile(_currentImagePath),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null && snapshot.data!.existsSync()) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        child: Image.file(
                          snapshot.data!,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      );
                    }
                    return Container(
                      height: 100,
                      color: AppColors.gray200,
                      child: Center(
                        child: Text(
                          'Loading image�',
                          style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.gray500),
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Center(
                    child: Text(
                      'Add item manually',
                      style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.gray500),
                    ),
                  ),
                ),
              if (_isProcessingAI) ...[
                const SizedBox(height: 24),
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "AI is analyzing product features...",
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: AppColors.primaryGreen, 
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              AbsorbPointer(
                absorbing: _isProcessingAI,
                child: Column(
                  children: [
                    if (isEditing) ...[
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      focusNode: _nameFocus,
                      onChanged: (_) {
                        if (_nameError) setState(() => _nameError = false);
                      },
                      decoration: InputDecoration(
                        labelText: 'Item Name *',
                        border: const OutlineInputBorder(),
                        errorText: _nameError ? 'Item name is required' : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _specCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Specification (e.g. Size, Weight)',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _barcodeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Barcode',
                        prefixIcon: const Icon(Icons.qr_code),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.camera_alt, color: AppColors.primaryGreen),
                          tooltip: 'Scan barcode',
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BarcodeScannerScreen(
                                  instruction: 'Scan product barcode',
                                ),
                              ),
                            );
                            if (result != null && result is String) {
                              setState(() => _barcodeCtrl.text = result);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Category picker � shows breadcrumb path below leaf name
                    GestureDetector(
                      onTap: () {
                        if (_catError) setState(() => _catError = false);
                        _catFocus.requestFocus();
                        _showCategoryPicker(context);
                      },
                      child: Focus(
                        focusNode: _catFocus,
                        child: InputDecorator(
                          isFocused: _catFocus.hasFocus,
                          decoration: InputDecoration(
                            labelText: 'Category *',
                            prefixIcon: const Icon(Icons.category_outlined),
                            border: const OutlineInputBorder(),
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                            errorText: _catError ? 'Category is required' : null,
                            helperText: _catCtrl.text.contains('\\')
                                ? _catCtrl.text.split('\\').join(' � ')
                                : _catCtrl.text.isEmpty ? 'Tap to select or create a category' : null,
                            helperMaxLines: 2,
                          ),
                          child: Text(
                          _catCtrl.text.isEmpty
                              ? 'Select category�'
                              : _catCtrl.text.split('\\').last,
                          style: TextStyle(
                            fontSize: 16,
                            color: _catCtrl.text.isEmpty ? Colors.grey.shade500 : null,
                          ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _sellCtrl,
                            focusNode: _sellFocus,
                            onChanged: (_) {
                              if (_sellError) setState(() => _sellError = false);
                            },
                            decoration: InputDecoration(
                              labelText: 'Selling *',
                              border: const OutlineInputBorder(),
                              errorText: _sellError ? 'Required' : null,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _buyCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Buying',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _stockCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (AppConfig.showMbeckGoFeatures) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(color: AppColors.gray200),
                        ),
                        child: SwitchListTile(
                          title: const Text('Publish Online (Mbeck Go)', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Allow buyers to discover this item', style: TextStyle(fontSize: 12)),
                          value: _isPublished,
                          activeColor: AppColors.primaryGreen,
                          onChanged: (val) => setState(() => _isPublished = val),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildVariationsSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
        actions: [
          if (isEditing && !_isProcessingAI)
            PermissionGuard(
              permission: Permissions.deleteInventoryItem,
              fallback: const SizedBox.shrink(), // Hide delete button if no permission
              child: TextButton(
                onPressed: widget.onDelete,
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          TextButton(
            onPressed: _isProcessingAI ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isProcessingAI
                ? null
                : () async {
                    bool valid = true;
                    
                    if (_nameCtrl.text.trim().isEmpty) {
                      setState(() => _nameError = true);
                      if (valid) _nameFocus.requestFocus();
                      valid = false;
                    }
                    
                    if (_catCtrl.text.trim().isEmpty || _catCtrl.text == 'Select category�') {
                      setState(() => _catError = true);
                      if (valid) _catFocus.requestFocus();
                      valid = false;
                    }
                    
                    if (_sellCtrl.text.trim().isEmpty) {
                      setState(() => _sellError = true);
                      if (valid) _sellFocus.requestFocus();
                      valid = false;
                    }

                    if (!valid) return;

                    setState(() => _isProcessingAI = true);
                    String? vector;
                    String finalPath = _currentImagePath;
                    
                    // AI removed � vector is always null
                    if (!isEditing && !_hasInitialImage) {
                      finalPath = '';
                    }

                    widget.onSave(
                      _nameCtrl.text,
                      _catCtrl.text,
                      double.tryParse(_sellCtrl.text) ?? 0,
                      double.tryParse(_buyCtrl.text) ?? 0,
                      int.tryParse(_stockCtrl.text) ?? 0,
                      finalPath,
                      vector,
                      _specCtrl.text,
                      _barcodeCtrl.text,
                      _variations.isNotEmpty ? jsonEncode(_variations.map((v) => v.toMap()).toList()) : null,
                      _isPublished,
                    );
                    
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildVariationsSection() {
    // Preset groups: each group adds multiple variants to the list (additive, not replace)
    final presets = {
      'Bags': ['� kg', '� kg', '1 kg', '2 kg', '5 kg'],
      'Volume': ['250 ml', '500 ml', '1 L', '2 L', '5 L'],
      'Sizes': ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
      'Pack': ['Single', '3-Pack', '6-Pack', 'Dozen'],
      'S/M/L': ['Small', 'Medium', 'Large'],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Variations', style: AppTypography.textTheme.labelLarge),
                  Text(
                    'Sell same product in different sizes/types',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _addVariation,
              icon: const Icon(Icons.add, size: 16, color: AppColors.primaryGreen),
              label: const Text('Add', style: TextStyle(color: AppColors.primaryGreen)),
            ),
          ],
        ),

        // Preset chips (always visible, additive)
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: presets.entries.map((entry) {
            return ActionChip(
              avatar: const Icon(Icons.auto_awesome, size: 13, color: AppColors.primaryGreen),
              label: Text(entry.key, style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              backgroundColor: AppColors.primaryGreen.withOpacity(0.06),
              side: BorderSide(color: AppColors.primaryGreen.withOpacity(0.3)),
              onPressed: () {
                setState(() {
                  final existing = _variations.map((v) => v.name).toSet();
                  final toAdd = entry.value.where((n) => !existing.contains(n));
                  _variations.addAll(
                    toAdd.map((n) => ProductVariation(name: n, priceModifier: 0, stock: 0)),
                  );
                });
              },
            );
          }).toList(),
        ),

        // Variation rows
        if (_variations.isNotEmpty) ...[
          const SizedBox(height: 10),
          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text('Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey))),
                const Expanded(flex: 2, child: Text('Price (KES)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey))),
                const Expanded(flex: 2, child: Text('Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey))),
                const SizedBox(width: 32), // delete button space
              ],
            ),
          ),
          const SizedBox(height: 4),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _variations.length,
            itemBuilder: (ctx, i) {
              final variation = _variations[i];
              // Use persistent controllers keyed by index
              final nameCtrl = TextEditingController(text: variation.name);
              // priceModifier field stores the absolute price per variant
              final priceCtrl = TextEditingController(
                  text: variation.priceModifier == 0 ? '' : variation.priceModifier.toStringAsFixed(0));
              final stockCtrl = TextEditingController(
                  text: variation.stock == 0 ? '' : variation.stock.toString());
              nameCtrl.selection = TextSelection.collapsed(offset: nameCtrl.text.length);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      // Name field
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'e.g. 500g',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          onChanged: (v) => setState(() =>
                              _variations[i] = _variations[i].copyWith(name: v)),
                        ),
                      ),
                      Container(width: 1, height: 36, color: Colors.grey.shade200),
                      // Absolute selling price
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '0',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (v) => setState(() => _variations[i] = _variations[i]
                              .copyWith(priceModifier: double.tryParse(v) ?? 0)),
                        ),
                      ),
                      Container(width: 1, height: 36, color: Colors.grey.shade200),
                      // Stock
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '0',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (v) => setState(() => _variations[i] = _variations[i]
                              .copyWith(stock: int.tryParse(v) ?? 0)),
                        ),
                      ),
                      // Delete
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.red),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _variations.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No variants � the item sells as one standard option. Tap a preset above or "Add" to configure sizes.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  void _addVariation() {
    setState(() {
      _variations.add(const ProductVariation(name: '', priceModifier: 0, stock: 0));
    });
  }
  // ignore: unused_element
  Future<void> _loadInitialImage() async {
    if (widget.existingItem != null && widget.existingItem!['imagePath'] != null) {
      final file = File(widget.existingItem!['imagePath']);
      if (await file.exists()) {
         setState(() {
           _currentImagePath = widget.existingItem!['imagePath'];
           _hasInitialImage = true;
         });
      }
    }
  }
}
