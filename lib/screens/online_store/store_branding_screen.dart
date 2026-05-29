import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../../db/db_provider.dart';
import '../../services/cloud_publish_service.dart';

class StoreBrandingScreen extends StatefulWidget {
  const StoreBrandingScreen({super.key});

  @override
  State<StoreBrandingScreen> createState() => _StoreBrandingScreenState();
}

class _StoreBrandingScreenState extends State<StoreBrandingScreen> {
  bool _isLoading = true;
  final TextEditingController _tagCtrl = TextEditingController();
  String? _coverImageUrl;
  String? _resolvedLocalPath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tagCtrl.addListener(_onTagChanged);
    _loadBranding();
  }

  @override
  void dispose() {
    _tagCtrl.removeListener(_onTagChanged);
    _tagCtrl.dispose();
    super.dispose();
  }

  void _onTagChanged() {
    setState(() {}); // trigger rebuild for live preview
  }

  Future<void> _loadBranding() async {
    try {
      final shops = await DbProvider.query('shops');
      if (shops.isNotEmpty) {
        final shop = shops.first;
        if (shop['theme_config'] != null) {
          try {
            final config = ShopThemeConfig.fromJson(jsonDecode(shop['theme_config'] as String));
            _coverImageUrl = config.coverImageUrl;
            _tagCtrl.text = config.displayTag ?? config.stylePreset;
            _resolveCoverPath();
          } catch (e) {
            debugPrint('Error parsing theme config: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading branding: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resolveCoverPath() async {
    final text = _coverImageUrl;
    if (text == null || text.isEmpty) {
      if (mounted) setState(() => _resolvedLocalPath = null);
      return;
    }
    if (text.startsWith('http') || text.startsWith('/') || text.contains('\\')) {
      if (mounted) setState(() => _resolvedLocalPath = text);
    } else {
      try {
        final dir = await getApplicationDocumentsDirectory();
        if (mounted) setState(() => _resolvedLocalPath = p.join(dir.path, text));
      } catch (_) {
        if (mounted) setState(() => _resolvedLocalPath = text);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final img = await _picker.pickImage(source: source, maxWidth: 1200, maxHeight: 800, imageQuality: 85);
      if (img == null) return;
      final dir = await getApplicationDocumentsDirectory();
      if (_coverImageUrl != null && !_coverImageUrl!.startsWith('http')) {
        final old = File(p.join(dir.path, _coverImageUrl!));
        if (old.existsSync()) try { old.deleteSync(); } catch (_) {}
      }
      final name = 'shop_cover_${DateTime.now().millisecondsSinceEpoch}${p.extension(img.path)}';
      await File(img.path).copy(p.join(dir.path, name));
      
      setState(() { 
        _coverImageUrl = name;
      });
      _resolveCoverPath();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Picture'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_coverImageUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _coverImageUrl = null;
                    });
                    _resolveCoverPath();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveBranding() async {
    final cover = _coverImageUrl ?? '';
    final tag = _tagCtrl.text.trim();
    
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await DbProvider.db;
      final existing = await db.query('shops', limit: 1);
      
      ShopThemeConfig config;
      if (existing.isNotEmpty && existing.first['theme_config'] != null) {
        try {
          final oldConfig = ShopThemeConfig.fromJson(jsonDecode(existing.first['theme_config'] as String));
          config = oldConfig.copyWith(
            coverImageUrl: cover.isEmpty ? null : cover,
            displayTag: tag.isEmpty ? null : tag,
            // also update stylePreset for backward compatibility
            stylePreset: tag.isEmpty ? 'RETAIL STORE' : tag,
          );
        } catch (_) {
          config = ShopThemeConfig(
            primaryColor: const Color(0xFF4CAF50),
            secondaryColor: const Color(0xFF7E57C2),
            coverImageUrl: cover.isEmpty ? null : cover,
            displayTag: tag.isEmpty ? null : tag,
            stylePreset: tag.isEmpty ? 'RETAIL STORE' : tag,
          );
        }
      } else {
        config = ShopThemeConfig(
          primaryColor: const Color(0xFF4CAF50),
          secondaryColor: const Color(0xFF7E57C2),
          coverImageUrl: cover.isEmpty ? null : cover,
          displayTag: tag.isEmpty ? null : tag,
          stylePreset: tag.isEmpty ? 'RETAIL STORE' : tag,
        );
      }

      final jsonString = jsonEncode(config.toJson());
      final name = existing.isNotEmpty ? (existing.first['business_name'] ?? existing.first['name']) : 'Mbeck Shop';
      final shopId = existing.isNotEmpty ? existing.first['id'] : 'local_shop';

      if (existing.isEmpty) {
        await db.insert('shops', {
          'id': shopId,
          'theme_config': jsonString,
          'business_name': name,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await db.update(
          'shops',
          {
            'theme_config': jsonString,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [shopId],
        );
      }

      // Sync to cloud
      await CloudPublishService.publishShopAndInventory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branding saved & syncing to cloud...')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving branding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save branding: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPreviewImage() {
    if (_resolvedLocalPath == null || _resolvedLocalPath!.isEmpty) {
      return Container(
        color: Colors.grey.shade800,
        child: const Center(
          child: Icon(Icons.image, size: 48, color: Colors.white54),
        ),
      );
    }
    if (_resolvedLocalPath!.startsWith('http')) {
      return Image.network(
        _resolvedLocalPath!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade800,
            child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.white54)),
          );
        },
      );
    } else {
      final file = File(_resolvedLocalPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
        );
      } else {
        return Container(
          color: Colors.grey.shade800,
          child: const Center(child: Icon(Icons.image_not_supported, size: 48, color: Colors.white54)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Branding'),
        actions: [
          _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveBranding,
                  child: const Text('SAVE', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Cover Image', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _showImagePickerOptions,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                    ),
                    child: _resolvedLocalPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: _buildPreviewImage(),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 32, color: Colors.grey.shade600),
                              const SizedBox(height: 8),
                              Text('Tap to select cover image', style: TextStyle(color: Colors.grey.shade700)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Display Tag', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _tagCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'e.g. ORGANIC GROCER, LUXURY LODGE',
                  ),
                ),
                const SizedBox(height: 32),
                const Text('Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildPreviewImage(),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              _tagCtrl.text.isEmpty ? 'DISPLAY TAG' : _tagCtrl.text.toUpperCase(),
                              style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
    );
  }
}
