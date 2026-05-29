import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../../db/db_provider.dart';
import '../../services/cloud_publish_service.dart';

class ModuleConfigScreen extends StatefulWidget {
  final String moduleKey;
  final String moduleName;

  const ModuleConfigScreen({super.key, required this.moduleKey, required this.moduleName});

  @override
  State<ModuleConfigScreen> createState() => _ModuleConfigScreenState();
}

class _ModuleConfigScreenState extends State<ModuleConfigScreen> {
  bool _isLoading = true;
  final TextEditingController _introCtrl = TextEditingController();
  String? _heroImageUrl;
  List<String> _envImages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _introCtrl.addListener(() => setState(() {}));
    _loadConfig();
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final shops = await DbProvider.query('shops');
      if (shops.isNotEmpty) {
        final shop = shops.first;
        if (shop['theme_config'] != null) {
          final config = ShopThemeConfig.fromJson(jsonDecode(shop['theme_config'] as String));
          if (config.moduleConfigs.containsKey(widget.moduleKey)) {
            final mCfg = config.moduleConfigs[widget.moduleKey] as Map<String, dynamic>;
            _introCtrl.text = mCfg['intro_message'] ?? '';
            _heroImageUrl = mCfg['hero_image'];
            final env = mCfg['environment_images'];
            if (env is List) {
              _envImages = env.map((e) => e.toString()).toList();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading module config: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);

    try {
      final db = await DbProvider.db;
      final existing = await db.query('shops', limit: 1);
      
      ShopThemeConfig config;
      if (existing.isNotEmpty && existing.first['theme_config'] != null) {
        config = ShopThemeConfig.fromJson(jsonDecode(existing.first['theme_config'] as String));
      } else {
        config = ShopThemeConfig.standard();
      }

      final modConfigs = Map<String, dynamic>.from(config.moduleConfigs);
      modConfigs[widget.moduleKey] = {
        'intro_message': _introCtrl.text.trim(),
        'hero_image': _heroImageUrl,
        'environment_images': _envImages,
      };

      config = config.copyWith(moduleConfigs: modConfigs);

      final jsonString = jsonEncode(config.toJson());
      final shopId = existing.isNotEmpty ? existing.first['id'] : 'local_shop';

      if (existing.isEmpty) {
        await db.insert('shops', {
          'id': shopId,
          'theme_config': jsonString,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await db.update(
          'shops',
          {'theme_config': jsonString, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [shopId],
        );
      }

      await CloudPublishService.publishShopAndInventory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.moduleName} config saved & synced!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving module config: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickHeroImage(ImageSource source) async {
    try {
      final img = await _picker.pickImage(source: source, maxWidth: 1200, maxHeight: 800, imageQuality: 85);
      if (img == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final name = 'mod_hero_${DateTime.now().millisecondsSinceEpoch}${p.extension(img.path)}';
      await File(img.path).copy(p.join(dir.path, name));
      setState(() => _heroImageUrl = name);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _pickEnvImage(ImageSource source) async {
    try {
      final img = await _picker.pickImage(source: source, maxWidth: 1200, maxHeight: 800, imageQuality: 85);
      if (img == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final name = 'mod_env_${DateTime.now().millisecondsSinceEpoch}${p.extension(img.path)}';
      await File(img.path).copy(p.join(dir.path, name));
      setState(() => _envImages.add(name));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _showImageOptions(Function(ImageSource) onPick) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () { Navigator.pop(context); onPick(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () { Navigator.pop(context); onPick(ImageSource.camera); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String path, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (path.startsWith('http')) {
      return Image.network(path, width: width, height: height, fit: fit, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image));
    }
    return FutureBuilder<Directory>(
      future: getApplicationDocumentsDirectory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final file = File(p.join(snapshot.data!.path, path));
        if (file.existsSync()) return Image.file(file, width: width, height: height, fit: fit);
        return const Icon(Icons.broken_image);
      },
    );
  }

  Widget _buildPreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: Container(
              height: 150,
              color: Colors.grey.shade200,
              child: _heroImageUrl != null 
                  ? _buildImage(_heroImageUrl!)
                  : Center(child: Icon(Icons.image, size: 40, color: Colors.grey.shade400)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.moduleName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _introCtrl.text.isEmpty ? 'Your intro message will appear here...' : _introCtrl.text,
                  style: TextStyle(color: Colors.grey.shade700, fontStyle: _introCtrl.text.isEmpty ? FontStyle.italic : FontStyle.normal),
                ),
                if (_envImages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _envImages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 120,
                              child: _buildImage(_envImages[index]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.moduleName} Setup'),
        actions: [
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator())))
              : TextButton(onPressed: _saveConfig, child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Top / Hero Image', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _showImageOptions(_pickHeroImage),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                    child: _heroImageUrl != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildImage(_heroImageUrl!))
                        : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo), SizedBox(height: 4), Text('Set Hero Image')]),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Intro Message', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _introCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Welcome to our store! We offer the best...',
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Environment Pictures', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      InkWell(
                        onTap: () => _showImageOptions(_pickEnvImage),
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
                          child: const Center(child: Icon(Icons.add_photo_alternate)),
                        ),
                      ),
                      ..._envImages.asMap().entries.map((entry) {
                        return Stack(
                          children: [
                            Container(
                              width: 140,
                              margin: const EdgeInsets.only(right: 8),
                              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildImage(entry.value)),
                            ),
                            Positioned(
                              top: 4, right: 12,
                              child: InkWell(
                                onTap: () => setState(() => _envImages.removeAt(entry.key)),
                                child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)),
                              ),
                            )
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text('Mbeck Go Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildPreview(),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}
