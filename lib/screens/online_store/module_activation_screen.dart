import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/cloud_publish_service.dart';
import 'module_config_screen.dart';

class ModuleActivationScreen extends StatefulWidget {
  const ModuleActivationScreen({super.key});

  @override
  State<ModuleActivationScreen> createState() => _ModuleActivationScreenState();
}

class _ModuleActivationScreenState extends State<ModuleActivationScreen> {
  bool _isLoading = true;
  bool _retail = false;
  bool _restaurant = false;
  bool _lodging = false;
  bool _services = false;
  bool _entertainment = false;

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _retail = prefs.getBool('publish_retail') ?? false;
        _services = prefs.getBool('publish_services') ?? false;
        _restaurant = prefs.getBool('publish_menu') ?? false;
        _lodging = prefs.getBool('publish_lodging') ?? false;
        _entertainment = prefs.getBool('publish_entertainment') ?? false;
      });
    } catch (e) {
      debugPrint('Error loading modules from SharedPreferences: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveModules() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('publish_retail', _retail);
      await prefs.setBool('publish_services', _services);
      await prefs.setBool('publish_menu', _restaurant);
      await prefs.setBool('publish_lodging', _lodging);
      await prefs.setBool('publish_entertainment', _entertainment);

      // Trigger sync to cloud
      await CloudPublishService.publishShopAndInventory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Module configuration synced to cloud!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving modules: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save module configurations: $e'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Modules'),
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
                  onPressed: _saveModules,
                  child: const Text('SAVE', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Toggle modules on/off to display them on Mbeck Go. Tap a module to configure its specific design and content (like intro messages and environment pictures).',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.shopping_bag),
                    title: const Text('Retail Store'),
                    subtitle: const Text('Sell physical goods and products'),
                    trailing: Switch(
                      value: _retail,
                      onChanged: (val) => setState(() => _retail = val),
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ModuleConfigScreen(moduleKey: 'retail', moduleName: 'Retail Store')));
                    },
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.restaurant),
                    title: const Text('Restaurant Menu'),
                    subtitle: const Text('Food delivery and dine-in menus'),
                    trailing: Switch(
                      value: _restaurant,
                      onChanged: (val) => setState(() => _restaurant = val),
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ModuleConfigScreen(moduleKey: 'restaurant', moduleName: 'Restaurant')));
                    },
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.hotel),
                    title: const Text('Lodging & Stays'),
                    subtitle: const Text('Rooms, hotels, and rentals'),
                    trailing: Switch(
                      value: _lodging,
                      onChanged: (val) => setState(() => _lodging = val),
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ModuleConfigScreen(moduleKey: 'lodging', moduleName: 'Lodging')));
                    },
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.spa),
                    title: const Text('Services & Appointments'),
                    subtitle: const Text('Bookings for salons, mechanics, etc.'),
                    trailing: Switch(
                      value: _services,
                      onChanged: (val) => setState(() => _services = val),
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ModuleConfigScreen(moduleKey: 'services', moduleName: 'Services')));
                    },
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.sports_esports),
                    title: const Text('Entertainment & Tickets'),
                    subtitle: const Text('Events, gaming, and venue ticketing'),
                    trailing: Switch(
                      value: _entertainment,
                      onChanged: (val) => setState(() => _entertainment = val),
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ModuleConfigScreen(moduleKey: 'entertainment', moduleName: 'Entertainment')));
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
