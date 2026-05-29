import 'package:flutter/material.dart';
import '../../../widgets/empty_state_guide.dart';
import '../../widgets/universal_image.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../db/db_provider.dart';
import 'package:uuid/uuid.dart';
import '../../services/event_service.dart';
import '../../services/auth_service.dart';
import '../../models/shop.dart';
import '../paywall_screen.dart';
import '../../services/revenuecat_service.dart';
import '../../config/app_config.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';

/// Service Catalog Screen
///
/// Features:
/// - Tab 1: Service Categories — manage categories with representative images
/// - Tab 2: All Services — list/add/edit services with supply linking
class ServiceCatalogScreen extends StatefulWidget {
  const ServiceCatalogScreen({super.key});

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _serviceCategories = [];
  List<Map<String, dynamic>> _availableSupplies = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bulkPublish(bool publish) async {
    setState(() => _isLoading = true);
    try {
      final db = await DbProvider.db;
      final publishVal = publish ? 1 : 0;
      await db.update(
        'services_catalog',
        {'is_published': publishVal, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      );

      try {
        await EventService.emitEvent(
          eventType: 'SHOP_UPDATE',
          payload: {'action': publish ? 'bulk_publish' : 'bulk_unpublish', 'module': 'services'},
        );
      } catch (e) {
        debugPrint('⚠️ Failed to emit bulk publish event: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(publish ? 'All services published online!' : 'All services removed from online.')),
        );
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    try {
      final db = await DbProvider.db;

      // Load service categories
      final cats = await db.query('service_categories', orderBy: 'sort_order ASC, name ASC');

      // Load services joined with category image
      final services = await db.rawQuery('''
        SELECT s.*,
               sc.image_path as category_image,
               sc.name as category_name
        FROM services_catalog s
        LEFT JOIN service_categories sc ON s.category_id = sc.id
        ORDER BY s.category ASC, s.name ASC
      ''');

      // Extract text categories
      final catNames = <String>{'All'};
      for (final s in services) {
        final cat = (s['category'] as String?) ?? '';
        if (cat.isNotEmpty) catNames.add(cat);
      }
      for (final c in cats) {
        final name = c['name'] as String? ?? '';
        if (name.isNotEmpty) catNames.add(name);
      }

      // Load supplies for linking
      List<Map<String, dynamic>> supplies = [];
      try {
        supplies = await db.query('supplies',
            where: "module = 'services'", orderBy: 'name ASC');
      } catch (_) {}

      if (mounted) {
        setState(() {
          _serviceCategories = cats;
          _services = services;
          _categories = catNames.toList()..sort();
          _availableSupplies = List.from(supplies);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading services: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredServices {
    if (_selectedCategory == 'All') return _services;
    return _services.where((s) {
      final cat = s['category'] as String? ?? '';
      final catName = s['category_name'] as String? ?? '';
      return cat == _selectedCategory || catName == _selectedCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          Column(
            children: [
          // ─── App Bar ─────────────────────
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B7280), size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text('Service Catalog', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF9CA3AF), size: 22), onPressed: _loadAll),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Color(0xFF9CA3AF)),
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
                  ),
                  // Purple underline tabs
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF7C3AED),
                    unselectedLabelColor: const Color(0xFF6B7280),
                    indicatorColor: const Color(0xFF7C3AED),
                    indicatorWeight: 2.5,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(text: 'Categories (${_serviceCategories.length})'),
                      Tab(text: 'All Services (${_services.length})'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ─── Content ─────────────────────
          Expanded(
            child: _isLoading
                ? AppSkeleton.screen()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCategoriesTab(),
                      _buildServicesTab(),
                    ],
                  ),
          ),
        ],
      ),
      const InteractiveHelpScroll(contextKey: 'services_catalog'),
      ],
      ),
    );
  }

  // ========== TAB 1: CATEGORIES ==========

  Widget _buildCategoriesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: GestureDetector(
            onTap: () => _showCategoryDialog(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Center(child: Text('Add Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
          ),
        ),
        Expanded(
          child: _serviceCategories.isEmpty
              ? EmptyStateGuide(
                  icon: Icons.category_outlined,
                  title: 'No categories yet',
                  subtitle: 'Create categories like "Haircut", "Consultation", or "Classes" to organize your services',
                  actionLabel: 'Add Category',
                  onAction: () => _showCategoryDialog(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: _serviceCategories.length,
                  itemBuilder: (context, index) => _buildCategoryCard(_serviceCategories[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat) {
    final imagePath = cat['image_path'] as String?;
    final name = cat['name'] as String? ?? '';
    final serviceCount = _services.where((s) {
      final sCat = s['category'] as String? ?? '';
      final sCatName = s['category_name'] as String? ?? '';
      return sCat == name || sCatName == name;
    }).length;

    return GestureDetector(
      onTap: () => _showCategoryDialog(existing: cat),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(
          children: [
            // Category image
            imagePath != null && imagePath.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: UniversalImage(imagePath, width: 56, height: 56, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _categoryPlaceholder()),
                  )
                : _categoryPlaceholder(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827), letterSpacing: -0.2)),
                  if (cat['description'] != null && (cat['description'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(cat['description'] as String,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.3),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.15)),
              ),
              child: Text('$serviceCount services',
                  style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryPlaceholder() {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.spa, color: Color(0xFF7C3AED), size: 24),
    );
  }

  // ========== TAB 2: ALL SERVICES ==========

  Widget _buildServicesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: GestureDetector(
            onTap: () => _showServiceDialog(null),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Center(child: Text('Add Service', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
          ),
        ),
        // Category filter chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _categories.map((c) {
                final isSelected = _selectedCategory == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCategory = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF7C3AED).withOpacity(0.12) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? const Color(0xFF7C3AED).withOpacity(0.3) : const Color(0xFFE5E7EB)),
                      ),
                      child: Text(c, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF6B7280),
                      )),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: _filteredServices.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: _filteredServices.length,
                    itemBuilder: (context, index) => _buildServiceCard(_filteredServices[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateGuide(
      icon: Icons.spa,
      title: 'No services listed',
      subtitle: 'Add the services you offer to start accepting appointments and billing customers',
      actionLabel: 'Add Service',
      onAction: () => _showServiceDialog(null),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final isActive = (service['active'] as int?) == 1;
    final duration = service['duration_minutes'] as int? ?? 30;
    final price = (service['price'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: () => _showServiceDialog(service),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(
          children: [
            _buildServiceImage(service),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['name'] ?? 'Untitled',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: isActive ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('$duration min', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                      const SizedBox(width: 16),
                      Text('KES ${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                    ],
                  ),
                ],
              ),
            ),
            if ((service['is_published'] as int?) == 1)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.public, size: 20, color: AppColors.primaryGreen),
              ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[400]),
              onSelected: (action) {
                switch (action) {
                  case 'edit': _showServiceDialog(service); break;
                  case 'toggle': _toggleActive(service); break;
                  case 'delete': _confirmDelete(service); break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'toggle', child: Text(isActive ? 'Deactivate' : 'Activate')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceImage(Map<String, dynamic> service) {
    final imagePath = service['image_path'] as String?;
    final catImage = service['category_image'] as String?;
    final isActive = (service['active'] as int?) == 1;
    final displayImage = (imagePath != null && imagePath.isNotEmpty) ? imagePath : catImage;

    if (displayImage != null && displayImage.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: UniversalImage(displayImage, width: 44, height: 44, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholderIcon(isActive)),
      );
    }
    return _buildPlaceholderIcon(isActive);
  }

  Widget _buildPlaceholderIcon(bool isActive) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF7C3AED).withOpacity(0.1) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.spa, size: 20, color: isActive ? const Color(0xFF7C3AED) : Colors.grey),
    );
  }

  // ========== ACTIONS ==========

  Future<void> _toggleActive(Map<String, dynamic> service) async {
    final newActive = (service['active'] as int?) == 1 ? 0 : 1;
    await DbProvider.update(
      'services_catalog',
      {'active': newActive, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [service['id']],
    );

    await EventService.emitEvent(
      eventType: 'SERVICE_UPDATE',
      payload: {
        'service_id': service['id'],
        'name': service['name']?.toString(),
        'is_active': newActive,
      },
    );

    _loadAll();
  }

  Future<void> _confirmDelete(Map<String, dynamic> service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service?'),
        content: Text('Are you sure you want to delete "${service['name']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await DbProvider.delete(
        'services_catalog',
        where: 'id = ?',
        whereArgs: [service['id']],
      );

      await EventService.emitEvent(
        eventType: 'SERVICE_DELETE',
        payload: {
          'service_id': service['id'],
          'name': service['name']?.toString(),
        },
      );

      _loadAll();
    }
  }

  // ========== CATEGORY DIALOG ==========

  void _showCategoryDialog({Map<String, dynamic>? existing}) {
    final isEditing = existing != null;
    final nameCtl = TextEditingController(text: existing?['name'] ?? '');
    final descCtl = TextEditingController(text: existing?['description'] ?? '');
    String? imagePath = existing?['image_path'];
    final picker = ImagePicker();

    Future<void> pickImage(StateSetter setSheetState) async {
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

      final XFile? photo = await picker.pickImage(
          source: source, imageQuality: 50, maxWidth: 512, maxHeight: 512);
      if (photo != null) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'svccat_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final saved = await File(photo.path).copy('${dir.path}/$fileName');
        setSheetState(() => imagePath = saved.path);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(isEditing ? 'Edit Category' : 'New Category',
                    style: AppTypography.textTheme.titleLarge),
                const SizedBox(height: 16),

                // Image picker
                GestureDetector(
                  onTap: () => pickImage(setSheetState),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: imagePath != null && imagePath!.isNotEmpty
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(imagePath!),
                                    width: double.infinity,
                                    height: 140,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.add_a_photo, color: Colors.grey))),
                              ),
                              Positioned(
                                top: 8, right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('Tap to change',
                                      style: TextStyle(color: Colors.white, fontSize: 11)),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_a_photo, color: Colors.grey, size: 32),
                              const SizedBox(height: 8),
                              Text('Add Category Photo',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                              Text('Shared by all services in this category',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(
                    labelText: 'Category Name *',
                    hintText: 'e.g. Hair, Nails, Spa, Facial',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                FilledButton.icon(
                  onPressed: () async {
                    final name = nameCtl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Category name is required')),
                      );
                      return;
                    }

                    final db = await DbProvider.db;
                    final now = DateTime.now().millisecondsSinceEpoch;

                    if (isEditing) {
                      await db.update('service_categories', {
                        'name': name,
                        'description': descCtl.text.trim(),
                        'image_path': imagePath,
                        'updated_at': now,
                      }, where: 'id = ?', whereArgs: [existing['id']]);

                      // Update services with old category name
                      final oldName = existing['name'] as String? ?? '';
                      if (oldName != name) {
                        await db.rawUpdate(
                          'UPDATE services_catalog SET category = ? WHERE category = ?',
                          [name, oldName],
                        );
                      }
                    } else {
                      await db.insert('service_categories', {
                        'name': name,
                        'description': descCtl.text.trim(),
                        'image_path': imagePath,
                        'created_at': now,
                        'updated_at': now,
                      });
                    }

                    _loadAll();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.save),
                  label: Text(isEditing ? 'Update Category' : 'Create Category'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      nameCtl.dispose();
      descCtl.dispose();
    });
  }

  // ========== SERVICE DIALOG (preserved with supply linking) ==========

  void _showServiceDialog(Map<String, dynamic>? service) async {
    final isEditing = service != null;
    final nameController = TextEditingController(text: service?['name'] ?? '');
    final descController = TextEditingController(text: service?['description'] ?? '');
    final priceController = TextEditingController(
        text: (service?['price'] as num?)?.toStringAsFixed(0) ?? '');
    final durationController = TextEditingController(
        text: (service?['duration_minutes'] as int?)?.toString() ?? '30');
    String? imagePath = service?['image_path'];
    final picker = ImagePicker();
    bool nameError = false;
    bool priceError = false;
    final FocusNode nameFocus = FocusNode();
    final FocusNode priceFocus = FocusNode();

    // Category dropdown
    int? selectedCategoryId = service?['category_id'] as int?;
    String categoryText = service?['category'] as String? ?? '';
    final categoryController = TextEditingController(text: categoryText);
    bool isPublished = (service?['is_published'] as int?) == 1;

    // Load existing supply links
    List<Map<String, dynamic>> linkedSupplies = [];
    final Map<int, TextEditingController> supplyControllers = {};
    if (isEditing) {
      try {
        final db = await DbProvider.db;
        final links = await db.query('supply_links',
            where: "item_type = 'service' AND item_id = ?",
            whereArgs: [service['id']]);
        for (final link in links) {
          final supplyId = link['supply_id'] as int;
          final supply = _availableSupplies.firstWhere(
              (s) => s['id'] == supplyId,
              orElse: () => <String, dynamic>{});
          if (supply.isNotEmpty) {
            final qty = (link['quantity_per_use'] as num?)?.toDouble() ?? 1;
            linkedSupplies.add({
              'supply_id': supplyId,
              'supply_name': supply['name'],
              'unit': supply['unit'],
              'quantity_per_use': qty,
            });
            supplyControllers[supplyId] = TextEditingController(text: qty.toString());
          }
        }
      } catch (_) {}
    }

    Future<void> pickImage(StateSetter setDialogState) async {
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

      final XFile? photo = await picker.pickImage(
          source: source, imageQuality: 50, maxWidth: 512, maxHeight: 512);
      if (photo != null) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'service_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage =
            await File(photo.path).copy('${directory.path}/$fileName');
        setDialogState(() => imagePath = savedImage.path);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Service' : 'Add Service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image picker
                GestureDetector(
                  onTap: () => pickImage(setDialogState),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: imagePath != null && imagePath!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(imagePath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.add_a_photo, color: Colors.grey))))
                        : const Center(
                            child: Icon(Icons.add_a_photo, color: Colors.grey)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  focusNode: nameFocus,
                  onChanged: (_) {
                    if (nameError) setDialogState(() => nameError = false);
                  },
                  decoration: InputDecoration(
                    labelText: 'Service Name *',
                    hintText: 'e.g., Haircut, Massage',
                    errorText: nameError ? 'Service name is required' : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Brief description of the service',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        focusNode: priceFocus,
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          if (priceError) setDialogState(() => priceError = false);
                        },
                        decoration: InputDecoration(
                          labelText: 'Price (KES) *',
                          prefixText: 'KES ',
                          errorText: priceError ? 'Price is required' : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration *',
                          suffixText: 'min',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Category — chip picker using service_categories
                if (_serviceCategories.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Category',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          // "None" chip
                          ChoiceChip(
                            label: const Text('None'),
                            selected: selectedCategoryId == null,
                            selectedColor: Colors.grey.shade300,
                            labelStyle: TextStyle(
                              color: selectedCategoryId == null ? Colors.black87 : null,
                              fontSize: 12,
                            ),
                            onSelected: (_) => setDialogState(() {
                              selectedCategoryId = null;
                              categoryText = '';
                            }),
                          ),
                          ..._serviceCategories.map((c) {
                            final id = c['id'] as int;
                            final name = c['name'] as String;
                            final sel = selectedCategoryId == id;
                            return ChoiceChip(
                              label: Text(name),
                              selected: sel,
                              selectedColor: AppColors.primaryGreen,
                              labelStyle: TextStyle(
                                color: sel ? Colors.white : null,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setDialogState(() {
                                selectedCategoryId = id;
                                categoryText = name;
                              }),
                            );
                          }),
                        ],
                      ),
                    ],
                  )
                else
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      hintText: 'e.g., Hair, Nails, Spa',
                    ),
                    onChanged: (v) => categoryText = v,
                  ),
                // === Supply/Products Used Section ===
                if (_availableSupplies.isNotEmpty) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      Icon(Icons.inventory_2, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      const Text('Products Used (Supply Link)',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Auto-deduct supplies when booking completes',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  ...linkedSupplies.asMap().entries.map((entry) {
                    final i = entry.key;
                    final link = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${link['supply_name']}',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          ),
                          SizedBox(
                            width: 70,
                            height: 32,
                            child: TextField(
                              controller: supplyControllers[link['supply_id']],
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 6),
                                suffixText: '${link['unit']}',
                                suffixStyle: const TextStyle(fontSize: 10),
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                linkedSupplies[i]['quantity_per_use'] =
                                    double.tryParse(v) ?? 1;
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setDialogState(() {
                                  linkedSupplies.removeAt(i);
                                  supplyControllers[link['supply_id']]?.dispose();
                                  supplyControllers.remove(link['supply_id']);
                                }),
                            icon: Icon(Icons.close,
                                size: 16, color: Colors.red.shade300),
                            padding: EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(maxWidth: 28, maxHeight: 28),
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        final linkedIds =
                            linkedSupplies.map((l) => l['supply_id']).toSet();
                        final available = _availableSupplies
                            .where((s) => !linkedIds.contains(s['id']))
                            .toList();
                        if (available.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('All supplies already linked')),
                          );
                          return;
                        }
                        showDialog(
                          context: context,
                          builder: (dlgCtx) => SimpleDialog(
                            title: const Text('Select Supply'),
                            children: available
                                .map((s) => SimpleDialogOption(
                                      onPressed: () {
                                        Navigator.pop(dlgCtx);
                                        setDialogState(() {
                                          linkedSupplies.add({
                                            'supply_id': s['id'],
                                            'supply_name': s['name'],
                                            'unit': s['unit'],
                                            'quantity_per_use': 1.0,
                                          });
                                          supplyControllers[s['id']] = TextEditingController(text: '1.0');
                                        });
                                      },
                                      child:
                                          Text('${s['name']} (${s['unit']})'),
                                    ))
                                .toList(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Link Supply',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
                // === End Supply Linking ===

                const Divider(height: 32),
                
                // Marketplace Publishing toggle
                if (AppConfig.showMbeckGoFeatures) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publish to Marketplace', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      isPublished ? 'Visible in the Mbeck Go app' : 'Only visible in-store',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    value: isPublished,
                    onChanged: (val) => setDialogState(() => isPublished = val),
                    activeColor: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final price = double.tryParse(priceController.text) ?? 0;
                final duration =
                    int.tryParse(durationController.text) ?? 30;

                if (name.isEmpty || price <= 0) {
                  setDialogState(() {
                    nameError = name.isEmpty;
                    priceError = price <= 0;
                  });
                  if (name.isEmpty) {
                    nameFocus.requestFocus();
                  } else {
                    priceFocus.requestFocus();
                  }
                  return;
                }

                final data = {
                  'name': name,
                  'description': descController.text.trim(),
                  'price': price,
                  'duration_minutes': duration,
                  'category': categoryText,
                  'category_id': selectedCategoryId,
                  'image_path': imagePath,
                  'is_published': isPublished ? 1 : 0,
                  'updated_at': DateTime.now().millisecondsSinceEpoch,
                };

                final db = await DbProvider.db;
                int serviceId;

                if (isEditing) {
                  serviceId = service['id'] as int;
                  await db.update('services_catalog', data,
                      where: 'id = ?', whereArgs: [serviceId]);
                  await EventService.emitEvent(
                    eventType: 'SERVICE_UPDATE',
                    payload: {'service_id': serviceId, ...data},
                  );
                } else {
                  final shop = await AuthService.getCurrentShop();
                  final isProSub = await RevenueCatService.isProSubscriber();
                  if (shop != null && !isProSub &&
                      shop.isServiceLimitReached(_services.length)) {
                    Navigator.pop(ctx);
                    if (context.mounted) {
                      PaywallScreen.show(context,
                          featureName:
                              'Service Limit Reached (Max ${shop.maxServiceItems} services)');
                    }
                    return;
                  }
                  data['active'] = 1;
                  data['created_at'] = DateTime.now().millisecondsSinceEpoch;
                  data['cloud_id'] = const Uuid().v4();
                  serviceId =
                      await db.insert('services_catalog', data);
                  await EventService.emitEvent(
                    eventType: 'SERVICE_CREATE',
                    payload: {'service_id': serviceId, ...data},
                  );
                }

                // Save supply links
                await db.delete('supply_links',
                    where: "item_type = 'service' AND item_id = ?",
                    whereArgs: [serviceId]);
                for (final link in linkedSupplies) {
                  await db.insert('supply_links', {
                    'item_id': serviceId,
                    'item_type': 'service',
                    'supply_id': link['supply_id'],
                    'quantity_per_use': link['quantity_per_use'],
                  });
                }

                Navigator.pop(ctx);
                _loadAll();
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    ).then((_) {
      nameController.dispose();
      descController.dispose();
      priceController.dispose();
      durationController.dispose();
      categoryController.dispose();
      nameFocus.dispose();
      priceFocus.dispose();
      for (final ctrl in supplyControllers.values) {
        ctrl.dispose();
      }
    });
  }
}
