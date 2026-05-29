import 'package:flutter/material.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';

class ServiceAddonsScreen extends StatefulWidget {
  const ServiceAddonsScreen({super.key});

  @override
  State<ServiceAddonsScreen> createState() => _ServiceAddonsScreenState();
}

class _ServiceAddonsScreenState extends State<ServiceAddonsScreen> {
  List<Map<String, dynamic>> _addons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddons();
  }

  Future<void> _loadAddons() async {
    try {
      final db = await DbProvider.db;
      final addons = await db.rawQuery('''
        SELECT a.*, c.name as parent_service_name 
        FROM services_addons a
        JOIN services_catalog c ON a.parent_service_id = c.id
        ORDER BY c.name ASC, a.name ASC
      ''');
      
      if (mounted) {
        setState(() {
          _addons = List.from(addons);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading addons: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddonModal([Map<String, dynamic>? existing]) async {
    final db = await DbProvider.db;
    final services = await db.query('services_catalog', where: 'is_active = 1', orderBy: 'name ASC');
    
    if (services.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a core service in the Catalog first.')));
      return;
    }
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddonFormSheet(
        initialData: existing,
        services: List.from(services),
        onSave: () {
          Navigator.pop(context);
          _loadAddons();
        },
      ),
    );
  }

  void _deleteAddon(int id) async {
    final db = await DbProvider.db;
    await db.delete('services_addons', where: 'id = ?', whereArgs: [id]);
    _loadAddons();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('Service Add-ons', style: TextStyle(color: AppColors.gray900, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _addons.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_add_check, size: 64, color: AppColors.gray300),
                      const SizedBox(height: 16),
                      Text('No Add-ons Configured', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                      const SizedBox(height: 8),
                      Text('Create up-sell services (e.g. Deep Condition)\nthat increase the booking time and price.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.gray500, height: 1.4)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addons.length,
                  itemBuilder: (context, index) {
                    final addon = _addons[index];
                    final isActive = addon['is_active'] == 1;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: ListTile(
                        title: Text(addon['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('For: ${addon['parent_service_name']}', style: TextStyle(color: AppColors.gray700)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.timer, size: 14, color: AppColors.gray500),
                                const SizedBox(width: 4),
                                Text('+${addon['duration_added_minutes']} mins', style: TextStyle(color: AppColors.gray800)),
                                const SizedBox(width: 16),
                                const Icon(Icons.attach_money, size: 14, color: AppColors.gray500),
                                Text('+${(addon['price_added'] as num).toStringAsFixed(2)}', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'edit') _showAddonModal(addon);
                            if (val == 'delete') _deleteAddon(addon['id']);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit Add-on')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete Add-on', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          const InteractiveHelpScroll(contextKey: 'services_addons'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: () => _showAddonModal(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Add-on', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _AddonFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final List<Map<String, dynamic>> services;
  final VoidCallback onSave;

  const _AddonFormSheet({this.initialData, required this.services, required this.onSave});

  @override
  State<_AddonFormSheet> createState() => _AddonFormSheetState();
}

class _AddonFormSheetState extends State<_AddonFormSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _durCtrl = TextEditingController(text: '0');
  int? _selectedServiceId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameCtrl.text = widget.initialData!['name'];
      _priceCtrl.text = widget.initialData!['price_added'].toString();
      _durCtrl.text = widget.initialData!['duration_added_minutes'].toString();
      _selectedServiceId = widget.initialData!['parent_service_id'];
      _isActive = widget.initialData!['is_active'] == 1;
    } else {
      _selectedServiceId = widget.services.first['id'] as int;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _durCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _selectedServiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a name and select a service')));
      return;
    }

    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final dur = int.tryParse(_durCtrl.text) ?? 0;

    final data = {
      'name': _nameCtrl.text,
      'parent_service_id': _selectedServiceId,
      'price_added': price,
      'duration_added_minutes': dur,
      'is_active': _isActive ? 1 : 0,
    };

    final db = await DbProvider.db;
    if (widget.initialData == null) {
      await db.insert('services_addons', data);
    } else {
      await db.update('services_addons', data, where: 'id = ?', whereArgs: [widget.initialData!['id']]);
    }
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.initialData == null ? 'Create Add-on' : 'Edit Add-on', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            DropdownButtonFormField<int>(
              value: _selectedServiceId,
              decoration: const InputDecoration(labelText: 'Parent Service', border: OutlineInputBorder()),
              items: widget.services.map((s) {
                return DropdownMenuItem<int>(
                  value: s['id'] as int,
                  child: Text(s['name']),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedServiceId = val),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Add-on Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Extra Price (\$)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _durCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Extra Time (Mins)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Is Active'),
              value: _isActive,
              onChanged: (val) => setState(() => _isActive = val),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _save,
              child: const Text('Save Add-on', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
