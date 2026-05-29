import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:mbeck_shared/mbeck_shared.dart';
import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../db/db_provider.dart';
import '../services/cloud_publish_service.dart';
import '../services/event_service.dart';
import '../theme/design_system.dart';

class _DesignEntry {
  final String id;
  final String name;
  final String description;
  final String tier;
  final Color primary;
  final Color secondary;
  final IconData icon;
  final bool isDark;
  final List<String> optimizedFor;
  final List<String> features;

  const _DesignEntry({
    required this.id, required this.name, required this.description,
    required this.tier, required this.primary, required this.secondary,
    required this.icon, this.isDark = false,
    required this.optimizedFor, this.features = const [],
  });

  Color get tierColor {
    switch (tier) {
      case 'Rare': return const Color(0xFF1E88E5);
      case 'Ultra Rare': return const Color(0xFF9C27B0);
      case 'Exclusive': return const Color(0xFFFF6F00);
      default: return const Color(0xFF78909C);
    }
  }
}

const _kDesigns = <_DesignEntry>[
  _DesignEntry(id: 'ethos_minimal', name: 'Modern Minimal', description: 'Bold typography, grid structures, and absolute clarity.', tier: 'Exclusive', primary: Color(0xFF121212), secondary: Color(0xFFE31E24), icon: Icons.grid_view, optimizedFor: ['retail', 'services'], features: ['Architectural grid', 'Swiss typography']),
  _DesignEntry(id: 'le_jardin', name: 'Organic Garden', description: 'Warm boutique café aesthetic with organic shapes.', tier: 'Exclusive', primary: Color(0xFFE67E22), secondary: Color(0xFF8DA399), icon: Icons.local_florist, optimizedFor: ['restaurant', 'retail'], features: ['Circular navigation', 'Editorial layout']),
  _DesignEntry(id: 'velvet_night', name: 'Premium Dark', description: 'Deep shadows and gold leaf typography for luxury.', tier: 'Exclusive', primary: Color(0xFF0D0D12), secondary: Color(0xFFC5A059), icon: Icons.nightlife, isDark: true, optimizedFor: ['entertainment', 'restaurant'], features: ['Luxe gradients', 'Fluid motion']),
  _DesignEntry(id: 'vanguard_immersive', name: 'Architectural', description: 'Immersive scrollytelling with parallax headers.', tier: 'Exclusive', primary: Color(0xFF121212), secondary: Color(0xFFD4AF37), icon: Icons.architecture, isDark: true, optimizedFor: ['lodging', 'retail', 'services'], features: ['Parallax header', 'Deep-contrast']),
  _DesignEntry(id: 'serenity', name: 'Soft Serenity', description: 'Ethereal and calming. Soft gradients and floating imagery.', tier: 'Exclusive', primary: Color(0xFFE0F2F1), secondary: Color(0xFFB2DFDB), icon: Icons.spa, optimizedFor: ['lodging', 'services'], features: ['Floating UI', 'Pastel aesthetics']),
  _DesignEntry(id: 'artisan_craft', name: 'Rustic Artisan', description: 'Warm earth tones with a handcrafted feel.', tier: 'Rare', primary: Color(0xFF8D6E63), secondary: Color(0xFFA1887F), icon: Icons.eco, optimizedFor: ['retail', 'restaurant', 'services'], features: ['Earth-tone palette', 'Polaroid cards']),
];

class ShopAppearanceScreen extends StatefulWidget {
  const ShopAppearanceScreen({super.key});
  @override
  State<ShopAppearanceScreen> createState() => _ShopAppearanceScreenState();
}

class _ShopAppearanceScreenState extends State<ShopAppearanceScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _isPublishedOnline = false;
  List<String> _enabledModules = ['retail'];
  String? _coverImagePath;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  final ImagePicker _picker = ImagePicker();
  Map<String, String> _moduleDesigns = {};
  String _globalDesign = 'clean_standard';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final mods = await OnboardingService.getSelectedModules();
      final shops = await DbProvider.query('shops');
      if (shops.isNotEmpty) {
        final shop = shops.first;
        _nameController.text = shop['business_name']?.toString() ?? shop['name']?.toString() ?? '';
        _isPublishedOnline = shop['is_published_online'] == 1;
        if (shop['theme_config'] != null) {
          try {
            final cfg = ShopThemeConfig.fromJson(jsonDecode(shop['theme_config'] as String));
            _moduleDesigns = Map<String, String>.from(cfg.moduleDesigns);
            _globalDesign = cfg.globalDesign;
            _coverImagePath = cfg.coverImageUrl;
            _phoneController.text = cfg.phoneNumber ?? '';
            _addressController.text = cfg.locationAddress ?? '';
          } catch (_) {}
        }
      }
      if (mounted) setState(() { _enabledModules = mods; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _designFor(String module) => _moduleDesigns[module] ?? _globalDesign;
  void _setDesign(String module, String id) => setState(() { _moduleDesigns[module] = id; _hasChanges = true; });

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final globalDesignEntry = _kDesigns.firstWhere(
        (d) => d.id == _globalDesign,
        orElse: () => const _DesignEntry(
          id: 'standard', 
          name: 'Standard', 
          description: '', 
          tier: 'Free', 
          primary: Color(0xFF4CAF50), 
          secondary: Color(0xFF7E57C2), 
          icon: Icons.shopping_bag,
          optimizedFor: [],
          features: [],
        ),
      );

      final config = ShopThemeConfig(
        primaryColor: globalDesignEntry.primary,
        secondaryColor: globalDesignEntry.secondary,
        coverImageUrl: _coverImagePath,
        moduleDesigns: _moduleDesigns,
        globalDesign: _globalDesign,
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        locationAddress: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      );
      final json = jsonEncode(config.toJson());
      final db = await DbProvider.db;
      final existing = await db.query('shops', limit: 1);
      final name = _nameController.text.trim().isEmpty ? 'Mbeck Shop' : _nameController.text.trim();
      if (existing.isEmpty) {
        final shopId = await AuthService.getShopId() ?? 'local_shop';
        await db.insert('shops', {'id': shopId, 'theme_config': json, 'business_name': name, 'is_published_online': _isPublishedOnline ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()});
      } else {
        await db.update('shops', {'theme_config': json, 'business_name': name, 'is_published_online': _isPublishedOnline ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [existing.first['id']]);
      }
      await EventService.emitEvent(eventType: 'SETTINGS_UPDATE', payload: {'theme_config': json, 'business_name': name});
      AuthService.invalidateCache();
      if (mounted) setState(() { _isSaving = false; _hasChanges = false; });
      try {
        await CloudPublishService.publishShopAndInventory();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('✅ Design saved & published!'), backgroundColor: AppColors.primaryGreen));
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('✅ Saved locally. Will sync when online.'), backgroundColor: Colors.orange.shade700));
      }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); setState(() => _isSaving = false); }
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final img = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 800, imageQuality: 85);
      if (img == null) return;
      final dir = await getApplicationDocumentsDirectory();
      if (_coverImagePath != null) {
        final old = File(p.join(dir.path, _coverImagePath!));
        if (old.existsSync()) try { old.deleteSync(); } catch (_) {}
      }
      final name = 'shop_cover_${DateTime.now().millisecondsSinceEpoch}${p.extension(img.path)}';
      await File(img.path).copy(p.join(dir.path, name));
      setState(() { _coverImagePath = name; _hasChanges = true; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text('Storefront Design', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AppColors.gray100, height: 1)),
        actions: [
          if (_hasChanges)
            _isSaving
                ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Save & Publish'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0)),
                    ),
                  ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreviewBanner(),
                  const SizedBox(height: 20),
                  _buildSection('BUSINESS INFO', Icons.storefront, _buildIdentityFields()),
                  const SizedBox(height: 16),
                  _buildSection('COVER IMAGE', Icons.photo_camera, _buildCoverImage()),
                  const SizedBox(height: 16),
                  _buildSection('VISIBILITY', Icons.public, _buildVisibility()),
                  const SizedBox(height: 24),
                  ..._enabledModules.map((mod) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _buildModuleSection(mod),
                  )),
                  const SizedBox(height: 60),
                ],
              ),
            ),
    );
  }

  // ── Live preview banner ────────────────────────────────────────────────────
  Widget _buildPreviewBanner() {
    // Show the first module's active design as preview
    final previewMod = _enabledModules.isNotEmpty ? _enabledModules.first : 'retail';
    final activeId = _designFor(previewMod);
    final design = _kDesigns.firstWhere((d) => d.id == activeId, orElse: () => _kDesigns.first);

    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [design.primary, design.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: design.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(design.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('ACTIVE DESIGN', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(design.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                _tierPill(design.tier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section wrapper ────────────────────────────────────────────────────────
  Widget _buildSection(String label, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 14, color: AppColors.gray400),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF9CA3AF), letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray100),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: content,
        ),
      ],
    );
  }

  Widget _buildIdentityFields() {
    return Column(children: [
      TextField(controller: _nameController, decoration: InputDecoration(labelText: 'Business Name', hintText: 'e.g. Mama Mboga Fresh', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.storefront), isDense: true), onChanged: (_) => setState(() => _hasChanges = true)),
      const SizedBox(height: 12),
      TextField(controller: _phoneController, decoration: InputDecoration(labelText: 'Phone Number', hintText: '+254 712 345 678', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.call), isDense: true), keyboardType: TextInputType.phone, onChanged: (_) => setState(() => _hasChanges = true)),
      const SizedBox(height: 12),
      TextField(controller: _addressController, decoration: InputDecoration(labelText: 'Location / Address', hintText: 'e.g. Tom Mboya St, Nairobi', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.location_on), isDense: true), onChanged: (_) => setState(() => _hasChanges = true)),
    ]);
  }

  Widget _buildCoverImage() {
    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        height: 140, width: double.infinity,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.gray50, border: Border.all(color: AppColors.gray100)),
        child: _coverImagePath != null
            ? Stack(fit: StackFit.expand, children: [
                ClipRRect(borderRadius: BorderRadius.circular(11), child: FutureBuilder<String>(
                  future: _resolvePath(_coverImagePath!),
                  builder: (ctx, snap) {
                    if (snap.hasData && File(snap.data!).existsSync()) return Image.file(File(snap.data!), fit: BoxFit.cover);
                    return const Center(child: Icon(Icons.image, size: 40, color: Colors.grey));
                  },
                )),
                Positioned(top: 8, right: 8, child: CircleAvatar(
                  backgroundColor: Colors.black54, radius: 14,
                  child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.close, size: 14, color: Colors.white), onPressed: () => setState(() { _coverImagePath = null; _hasChanges = true; })),
                )),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_a_photo, size: 32, color: AppColors.gray300),
                const SizedBox(height: 8),
                Text('Tap to upload cover image', style: TextStyle(color: AppColors.gray400, fontWeight: FontWeight.w600)),
              ]),
      ),
    );
  }

  Widget _buildVisibility() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Publish on Mbeck Go', style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: const Text('Allow buyers to discover your shop online'),
      value: _isPublishedOnline,
      activeColor: AppColors.primaryGreen,
      onChanged: (v) => setState(() { _isPublishedOnline = v; _hasChanges = true; }),
    );
  }

  // ── Module design picker ──────────────────────────────────────────────────
  Widget _buildModuleSection(String module) {
    final currentId = _designFor(module);
    final recommended = _kDesigns.where((d) => d.optimizedFor.contains(module)).toList();
    final others = _kDesigns.where((d) => !d.optimizedFor.contains(module)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Module header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
            child: Icon(_moduleIcon(module), size: 18, color: const Color(0xFF4F46E5)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_moduleLabel(module)} Design', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
            Text('Swipe to browse designs', style: TextStyle(fontSize: 11, color: AppColors.gray400)),
          ]),
        ]),
        const SizedBox(height: 12),

        // Recommended carousel
        if (recommended.isNotEmpty) ...[
          _chipLabel('✦ RECOMMENDED'),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: recommended.map((d) => _designCard(d, module, currentId)).toList(),
            ),
          ),
        ],

        // Other designs
        if (others.isNotEmpty) ...[
          const SizedBox(height: 12),
          _chipLabel('MORE DESIGNS'),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: others.map((d) => _designCard(d, module, currentId)).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _designCard(_DesignEntry design, String module, String currentId) {
    final isSelected = design.id == currentId;
    return GestureDetector(
      onTap: () => _setDesign(module, design.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected && design.isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? design.primary : AppColors.gray100,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: design.primary.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(
          children: [
            // Gradient preview
            Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [design.primary, design.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Stack(
                children: [
                  Center(child: Icon(design.icon, color: Colors.white, size: 28)),
                  if (isSelected)
                    Positioned(top: 8, right: 8,
                      child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Icon(Icons.check, size: 12, color: design.primary))),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(design.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isSelected && design.isDark ? Colors.white : AppColors.gray900), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 4),
                    _tierPill(design.tier),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tierPill(String tier) {
    final entry = _kDesigns.firstWhere((d) => d.tier == tier, orElse: () => _kDesigns.first);
    final color = entry.tierColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(tier.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
    );
  }

  Widget _chipLabel(String text) => Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF9CA3AF), letterSpacing: 1.5));

  String _moduleLabel(String m) {
    const map = {'retail': 'Retail', 'restaurant': 'Restaurant', 'services': 'Services', 'entertainment': 'Entertainment', 'lodging': 'Lodging'};
    return map[m] ?? m;
  }

  IconData _moduleIcon(String m) {
    const map = {'retail': Icons.storefront, 'restaurant': Icons.restaurant, 'services': Icons.design_services, 'entertainment': Icons.sports_esports, 'lodging': Icons.hotel};
    return map[m] ?? Icons.apps;
  }

  Future<String> _resolvePath(String name) async {
    if (name.startsWith('/') || name.contains('\\')) return name;
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, name);
  }
}
