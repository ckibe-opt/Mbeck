import 'package:flutter/material.dart';
import '../../../widgets/empty_state_guide.dart';
import '../../widgets/universal_image.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/entertainment_service.dart';
import '../../theme/design_system.dart';
import '../../widgets/standard_app_bar.dart';
import '../../widgets/interactive_help_scroll.dart';
import '../../config/app_config.dart';

/// Screen for managing entertainment assets (pool tables, PS stations, etc.)
///
/// Features:
/// - Tab 1: Asset Types — create/edit types with image gallery, rate, billing
/// - Tab 2: All Assets — grid with batch-add, status management
class AssetManagementScreen extends StatefulWidget {
  const AssetManagementScreen({super.key});

  @override
  State<AssetManagementScreen> createState() => _AssetManagementScreenState();
}

class _AssetManagementScreenState extends State<AssetManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _assetTypes = [];
  List<Map<String, dynamic>> _assets = [];
  List<String> _categories = ['All'];
  String _selectedCategory = 'All';
  bool _isLoading = true;

  static const _presetCategories = [
    'Pool', 'Gaming', 'Swimming', 'Karaoke', 'Bowling', 'VR', 'Other',
  ];

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

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final types = await EntertainmentService.getAssetTypesWithDetails();
      final assets = await EntertainmentService.getAssets(activeOnly: false);
      final cats = await EntertainmentService.getCategories();

      if (mounted) {
        setState(() {
          _assetTypes = types;
          _assets = assets;
          _categories = ['All', ...cats];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading assets: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAssets {
    if (_selectedCategory == 'All') return _assets;
    return _assets.where((a) => a['category'] == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StandardAppBar(title: 'Asset Management'),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primaryGreen,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.primaryGreen,
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.category),
                      text: 'Asset Types (${_assetTypes.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.sports_esports),
                      text: 'All Assets (${_assets.length})',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAssetTypesTab(),
                          _buildAllAssetsTab(),
                        ],
                      ),
              ),
            ],
          ),
          const InteractiveHelpScroll(contextKey: 'asset_management'),
        ],
      ),
    );
  }

  // ========== TAB 1: ASSET TYPES ==========

  Widget _buildAssetTypesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: () => _showAssetTypeDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Create Asset Type'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        Expanded(
          child: _assetTypes.isEmpty
              ? EmptyStateGuide(
                  icon: Icons.category_outlined,
                  title: 'No asset types yet',
                  subtitle: 'Create types like "Pool Table" or "PS5 Station" to start billing sessions',
                  actionLabel: 'Create Asset Type',
                  onAction: () => _showAssetTypeDialog(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _assetTypes.length,
                  itemBuilder: (context, index) => _buildAssetTypeCard(_assetTypes[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildAssetTypeCard(Map<String, dynamic> type) {
    final assetCount = (type['asset_count'] as int?) ?? 0;
    final imageCount = (type['image_count'] as int?) ?? 0;
    final rate = (type['rate_per_hour'] as num?)?.toDouble() ?? 0;
    final flatRate = (type['flat_rate'] as num?)?.toDouble() ?? 0;
    final billingType = type['asset_type'] as String? ?? 'hourly';
    final category = type['category'] as String? ?? '';

    final rateText = billingType == 'flat'
        ? 'KES ${flatRate.toStringAsFixed(0)} flat'
        : 'KES ${rate.toStringAsFixed(0)}/hr';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showAssetTypeDialog(existing: type),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Type image
              FutureBuilder<List<Map<String, dynamic>>>(
                future: EntertainmentService.getAssetTypeImages(type['id'] as int),
                builder: (context, snapshot) {
                  final images = snapshot.data ?? [];
                  if (images.isNotEmpty) {
                    final path = images.first['image_path'] as String;
                    if (path.isNotEmpty) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: UniversalImage(path,
                            width: 64, height: 64, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _typePlaceholder(category)),
                      );
                    }
                  }
                  return _typePlaceholder(category);
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(type['name'] as String? ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if ((type['is_published'] as int?) == 1)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.public, size: 14, color: AppColors.primaryGreen),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('$category • $rateText',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    Text(billingType == 'hourly' ? '⏱ Hourly billing' : '💰 Flat rate',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$assetCount assets',
                        style: const TextStyle(
                            color: AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  if (imageCount > 0) ...[
                    const SizedBox(height: 4),
                    Text('📷 $imageCount', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typePlaceholder(String category) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(_categoryIcon(category), color: AppColors.primaryGreen, size: 28),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'pool':
        return Icons.sports;
      case 'gaming':
        return Icons.sports_esports;
      case 'swimming':
        return Icons.pool;
      case 'karaoke':
        return Icons.mic;
      case 'bowling':
        return Icons.sports_cricket;
      case 'vr':
        return Icons.vrpano;
      default:
        return Icons.attractions;
    }
  }

  // ========== TAB 2: ALL ASSETS ==========

  Widget _buildAllAssetsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((c) => _filterChip(c)).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _assetTypes.isEmpty
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Create an Asset Type first')),
                        );
                        _tabController.animateTo(0);
                      }
                    : () => _showBatchAddDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Batch Add'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredAssets.isEmpty
              ? const EmptyStateGuide(
                  icon: Icons.sports_esports_outlined,
                  title: 'No assets registered',
                  subtitle: 'Use "Batch Add" above to create multiple assets at once and start billing customers',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _filteredAssets.length,
                  itemBuilder: (context, index) => _buildAssetTile(_filteredAssets[index]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategory = label),
        selectedColor: AppColors.primaryGreen.withOpacity(0.2),
        checkmarkColor: AppColors.primaryGreen,
      ),
    );
  }

  Widget _buildAssetTile(Map<String, dynamic> asset) {
    final isActive = (asset['is_active'] as int?) == 1;
    final billingType = asset['asset_type'] as String? ?? 'hourly';
    final rate = (asset['rate_per_hour'] as num?)?.toDouble() ?? 0;
    final flatRate = (asset['flat_rate'] as num?)?.toDouble() ?? 0;
    final category = asset['category'] as String? ?? '';
    final typeImage = asset['type_image'] as String?;
    final imagePath = asset['image_path'] as String?;
    final isPublished = (asset['is_published'] as int?) == 1;

    // Use asset's own image, fallback to type image
    final displayImage = (imagePath != null && imagePath.isNotEmpty) ? imagePath : typeImage;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: displayImage != null && displayImage.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: UniversalImage(displayImage,
                    width: 48, height: 48, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => CircleAvatar(
                      backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                      child: Icon(_categoryIcon(category), color: AppColors.primaryGreen),
                    )),
              )
            : CircleAvatar(
                backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                child: Icon(_categoryIcon(category), color: AppColors.primaryGreen),
              ),
        title: Text(
          asset['name'] as String? ?? '',
          style: TextStyle(
              fontWeight: FontWeight.w600, color: isActive ? null : Colors.grey),
        ),
        subtitle: Text(
          billingType == 'flat'
              ? '$category • KES ${flatRate.toStringAsFixed(0)} flat'
              : '$category • KES ${rate.toStringAsFixed(0)}/hr',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isActive ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            if (isPublished)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.public, size: 16, color: AppColors.primaryGreen),
              ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'toggle':
                    await EntertainmentService.updateAsset(
                        asset['id'] as int, {'is_active': isActive ? 0 : 1});
                    _loadAll();
                    break;
                  case 'delete':
                    await EntertainmentService.deactivateAsset(asset['id'] as int);
                    _loadAll();
                    break;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(isActive ? 'Deactivate' : 'Activate'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========== ASSET TYPE DIALOG ==========

  void _showAssetTypeDialog({Map<String, dynamic>? existing}) async {
    final isEditing = existing != null;
    final nameCtl = TextEditingController(text: existing?['name'] ?? '');
    final rateCtl = TextEditingController(
        text: (existing?['rate_per_hour'] as num?)?.toStringAsFixed(0) ?? '');
    final flatRateCtl = TextEditingController(
        text: (existing?['flat_rate'] as num?)?.toStringAsFixed(0) ?? '0');
    final descCtl = TextEditingController(text: existing?['description'] ?? '');
    String category = existing?['category'] ?? '';
    String billingType = existing?['asset_type'] ?? 'hourly';
    List<String> imagePaths = [];
    final picker = ImagePicker();
    bool nameError = false;
    bool categoryError = false;
    final FocusNode nameFocus = FocusNode();
    bool isPublished = (existing?['is_published'] as int?) == 1;

    if (isEditing) {
      final images = await EntertainmentService.getAssetTypeImages(existing['id'] as int);
      imagePaths = images.map((img) => img['image_path'] as String).toList();
    }

    Future<void> pickImage(StateSetter setSheetState) async {
      if (imagePaths.length >= 10) return;
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

      final XFile? photo = await picker.pickImage(source: source, imageQuality: 50, maxWidth: 512, maxHeight: 512);
      if (photo != null) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'assettype_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final saved = await File(photo.path).copy('${dir.path}/$fileName');
        setSheetState(() => imagePaths.add(saved.path));
      }
    }

    if (!mounted) return;

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
                Text(isEditing ? 'Edit Asset Type' : 'Create Asset Type',
                    style: AppTypography.textTheme.titleLarge),
                const SizedBox(height: 16),

                // Image gallery
                Container(
                  height: 130,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.photo_library, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('Type Photos (${imagePaths.length}/10)',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            const Spacer(),
                            Text('Shared by all assets of this type',
                                style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: imagePaths.isEmpty
                            ? Center(
                                child: TextButton.icon(
                                  onPressed: () => pickImage(setSheetState),
                                  icon: const Icon(Icons.add_a_photo),
                                  label: const Text('Add Photos'),
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                itemCount: imagePaths.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == imagePaths.length) {
                                    return GestureDetector(
                                      onTap: () => pickImage(setSheetState),
                                      child: Container(
                                        width: 70,
                                        margin: const EdgeInsets.only(right: 8, bottom: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppColors.primaryGreen),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.add_a_photo,
                                            color: AppColors.primaryGreen, size: 20),
                                      ),
                                    );
                                  }
                                  return Stack(
                                    children: [
                                      Container(
                                        width: 70,
                                        margin: const EdgeInsets.only(right: 8, bottom: 8),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: (() {
                                            final path = imagePaths[index];
                                            if (path.isNotEmpty) {
                                              return UniversalImage(
                                                path,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(Icons.broken_image),
                                                ),
                                              );
                                            }
                                            return Container(
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.broken_image),
                                            );
                                          })(),
                                        ),
                                      ),
                                      Positioned(
                                        top: 0, right: 8,
                                        child: GestureDetector(
                                          onTap: () => setSheetState(() => imagePaths.removeAt(index)),
                                          child: Container(
                                            decoration: const BoxDecoration(
                                                color: Colors.red, shape: BoxShape.circle),
                                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                TextField(
                  controller: nameCtl,
                  focusNode: nameFocus,
                  onChanged: (_) {
                    if (nameError) setSheetState(() => nameError = false);
                  },
                  decoration: InputDecoration(
                    labelText: 'Type Name *',
                    hintText: 'e.g. Pool Table, PS5 Station',
                    border: const OutlineInputBorder(),
                    errorText: nameError ? 'Name is required' : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Category chips
                Text(
                  'Category *',
                  style: AppTypography.textTheme.labelLarge?.copyWith(
                    color: categoryError ? Colors.red : null,
                  ),
                ),
                if (categoryError)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Please select a category', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _presetCategories.map((cat) {
                    final isSelected = category.toLowerCase() == cat.toLowerCase();
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) {
                        setSheetState(() {
                          category = cat;
                          if (categoryError) categoryError = false;
                        });
                      },
                      selectedColor: AppColors.primaryGreen.withOpacity(0.2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Billing type toggle
                Text('Billing Type', style: AppTypography.textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('⏱ Hourly'),
                        selected: billingType == 'hourly',
                        onSelected: (_) => setSheetState(() => billingType = 'hourly'),
                        selectedColor: AppColors.primaryGreen.withOpacity(0.2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('💰 Flat Rate'),
                        selected: billingType == 'flat',
                        onSelected: (_) => setSheetState(() => billingType = 'flat'),
                        selectedColor: AppColors.primaryGreen.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Rate
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rateCtl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: billingType == 'hourly' ? 'Rate/Hour (KES) *' : 'Rate/Hour',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: flatRateCtl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: billingType == 'flat' ? 'Flat Rate (KES) *' : 'Flat Rate',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                TextField(
                  controller: descCtl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),

                if (AppConfig.showMbeckGoFeatures) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publish to Cloud',
                        style:
                            TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        isPublished
                            ? 'Visible on Mbeck Go Marketplace'
                            : 'Only available for in-store booking',
                        style: const TextStyle(fontSize: 12)),
                    value: isPublished,
                    onChanged: (val) => setSheetState(() => isPublished = val),
                    activeColor: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 16),
                ],

                // Save
                FilledButton.icon(
                  onPressed: () async {
                    final name = nameCtl.text.trim();
                    final rate = double.tryParse(rateCtl.text) ?? 0;
                    final flatRate = double.tryParse(flatRateCtl.text) ?? 0;
                    if (name.isEmpty || category.isEmpty) {
                      setSheetState(() {
                        nameError = name.isEmpty;
                        categoryError = category.isEmpty;
                      });
                      if (name.isEmpty) nameFocus.requestFocus();
                      return;
                    }

                    try {
                      int typeId;
                      if (isEditing) {
                        typeId = existing['id'] as int;
                        await EntertainmentService.updateAssetType(typeId, {
                          'name': name,
                          'category': category,
                          'asset_type': billingType,
                          'rate_per_hour': rate,
                          'flat_rate': flatRate,
                          'description': descCtl.text.trim(),
                          'is_published': isPublished ? 1 : 0,
                        });
                      } else {
                        typeId = await EntertainmentService.createAssetType(
                          name: name,
                          category: category,
                          billingType: billingType,
                          ratePerHour: rate,
                          flatRate: flatRate,
                          description: descCtl.text.trim().isNotEmpty ? descCtl.text.trim() : null,
                          isPublished: isPublished,
                        );
                      }

                      await EntertainmentService.saveAssetTypeImages(typeId, imagePaths);
                      _loadAll();
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: Text(isEditing ? 'Update Type' : 'Create Type'),
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
      rateCtl.dispose();
      flatRateCtl.dispose();
      descCtl.dispose();
      nameFocus.dispose();
    });
  }

  // ========== BATCH ADD DIALOG ==========

  void _showBatchAddDialog() {
    int? selectedTypeId;
    final fromCtl = TextEditingController();
    final toCtl = TextEditingController();
    final prefixCtl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final from = int.tryParse(fromCtl.text);
          final to = int.tryParse(toCtl.text);
          final count = (from != null && to != null && to >= from) ? to - from + 1 : 0;

          // Get type name for preview
          String typeName = '';
          if (selectedTypeId != null) {
            final type = _assetTypes.firstWhere(
              (t) => t['id'] == selectedTypeId,
              orElse: () => <String, dynamic>{},
            );
            typeName = type['name'] as String? ?? '';
          }
          final prefix = prefixCtl.text.trim().isNotEmpty ? prefixCtl.text.trim() : typeName;

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Batch Add Assets', style: AppTypography.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Create multiple assets at once',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 20),

                  // Type dropdown
                  DropdownButtonFormField<int>(
                    value: selectedTypeId,
                    decoration: const InputDecoration(
                      labelText: 'Asset Type *',
                      border: OutlineInputBorder(),
                    ),
                    items: _assetTypes.map((t) {
                      final rate = (t['rate_per_hour'] as num?)?.toDouble() ?? 0;
                      final cat = t['category'] ?? '';
                      return DropdownMenuItem<int>(
                        value: t['id'] as int,
                        child: Text('${t['name']} ($cat) — KES ${rate.toStringAsFixed(0)}/hr'),
                      );
                    }).toList(),
                    onChanged: (val) => setSheetState(() => selectedTypeId = val),
                  ),
                  const SizedBox(height: 12),

                  // From + To
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fromCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'From # *', hintText: '1',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('to'),
                      ),
                      Expanded(
                        child: TextField(
                          controller: toCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'To # *', hintText: '4',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Prefix
                  TextField(
                    controller: prefixCtl,
                    decoration: InputDecoration(
                      labelText: 'Name Prefix',
                      hintText: 'Leave empty to use type name (e.g. "$typeName")',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Preview
                  if (count > 0 && prefix.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Preview: $count assets',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                          const SizedBox(height: 4),
                          Text('$prefix $from — $prefix $to',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Create
                  FilledButton.icon(
                    onPressed: () async {
                      if (selectedTypeId == null || from == null || to == null || to < from) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fill in all required fields')),
                        );
                        return;
                      }
                      if (count > 50) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Maximum 50 assets per batch')),
                        );
                        return;
                      }

                      try {
                        final created = await EntertainmentService.batchCreateAssets(
                          assetTypeId: selectedTypeId!,
                          startNumber: from,
                          endNumber: to,
                          prefix: prefixCtl.text.trim(),
                        );
                        _loadAll();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('✅ Created $created assets')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(count > 0 ? 'Create $count Assets' : 'Create Assets'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      fromCtl.dispose();
      toCtl.dispose();
      prefixCtl.dispose();
    });
  }
}
