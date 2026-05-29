import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import '../../db/db_provider.dart';
import '../../services/cloud_publish_service.dart';
import 'store_branding_screen.dart';
import 'module_activation_screen.dart';
import 'catalog_manager_screen.dart';

class OnlineStoreDashboard extends StatefulWidget {
  const OnlineStoreDashboard({super.key});

  @override
  State<OnlineStoreDashboard> createState() => _OnlineStoreDashboardState();
}

class _OnlineStoreDashboardState extends State<OnlineStoreDashboard> {
  bool _isLoading = true;
  bool _isPublishedOnline = false;
  String? _coverImageUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final shops = await DbProvider.query('shops');
      if (shops.isNotEmpty) {
        final shop = shops.first;
        _isPublishedOnline = shop['is_published_online'] == 1;
        if (shop['theme_config'] != null) {
          try {
            final config = ShopThemeConfig.fromJson(jsonDecode(shop['theme_config'] as String));
            final cover = config.coverImageUrl;
            if (cover != null && cover.isNotEmpty) {
              if (cover.startsWith('http') || cover.startsWith('/') || cover.contains('\\')) {
                _coverImageUrl = cover;
              } else {
                final dir = await getApplicationDocumentsDirectory();
                _coverImageUrl = p.join(dir.path, cover);
              }
            }
          } catch (e) {
            debugPrint('Error decoding theme config: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading shop dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePublish(bool val) async {
    setState(() {
      _isPublishedOnline = val;
    });

    try {
      final db = await DbProvider.db;
      final existing = await db.query('shops', limit: 1);
      if (existing.isNotEmpty) {
        await db.update(
          'shops',
          {
            'is_published_online': val ? 1 : 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        final shopId = 'local_shop';
        await db.insert('shops', {
          'id': shopId,
          'is_published_online': val ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await CloudPublishService.publishShopAndInventory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(val ? 'Store is now LIVE on Mbeck Go!' : 'Store is now offline.'),
            backgroundColor: val ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling online store publish: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update visibility: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final hasCover = _coverImageUrl != null && _coverImageUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Store'),
        actions: [
          Row(
            children: [
              const Text('LIVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Switch(
                value: _isPublishedOnline,
                onChanged: _togglePublish,
                activeColor: Colors.greenAccent,
              ),
            ],
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preview Card
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: hasCover
                    ? (_coverImageUrl!.startsWith('http')
                        ? NetworkImage(_coverImageUrl!) as ImageProvider
                        : FileImage(File(_coverImageUrl!)) as ImageProvider)
                    : const NetworkImage('https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=1000&auto=format&fit=crop'),
                fit: BoxFit.cover,
                colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.darken),
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront, size: 48, color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    'Preview Mbeck Go Profile',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          _buildMenuTile(
            title: 'Store Branding & Details',
            subtitle: 'Cover photo, logo, description, and colors',
            icon: Icons.brush,
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreBrandingScreen()));
              _loadData();
            },
          ),
          _buildMenuTile(
            title: 'Manage Business Modules',
            subtitle: 'Toggle Retail, Restaurant, Lodging, Services on/off',
            icon: Icons.view_module,
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ModuleActivationScreen()));
              _loadData();
            },
          ),
          _buildMenuTile(
            title: 'Cloud Catalog Manager',
            subtitle: 'Select which items to publish online',
            icon: Icons.inventory,
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogManagerScreen()));
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: Icon(icon, color: Colors.blue)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
