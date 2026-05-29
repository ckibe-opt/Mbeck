import 'package:flutter/material.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';

class ServiceBuffersScreen extends StatefulWidget {
  const ServiceBuffersScreen({super.key});

  @override
  State<ServiceBuffersScreen> createState() => _ServiceBuffersScreenState();
}

class _ServiceBuffersScreenState extends State<ServiceBuffersScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final db = await DbProvider.db;
      final services = await db.rawQuery('''
        SELECT id, name, duration_minutes, buffer_minutes 
        FROM services_catalog 
        WHERE is_active = 1
        ORDER BY name ASC
      ''');
      
      if (mounted) {
        setState(() {
          _services = List.from(services);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading services for buffers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showBufferModal(Map<String, dynamic> service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BufferFormSheet(
        service: service,
        onSave: () {
          Navigator.pop(context);
          _loadServices();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('Buffer / Cleanup Times', style: TextStyle(color: AppColors.gray900, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _services.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined, size: 64, color: AppColors.gray300),
                      const SizedBox(height: 16),
                      Text('No Active Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                      const SizedBox(height: 8),
                      Text('Add services in the Catalog first to assign\ncleanup or setup buffers to them.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.gray500, height: 1.4)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _services.length,
                  itemBuilder: (context, index) {
                    final service = _services[index];
                    final buffer = service['buffer_minutes'] as int? ?? 0;
                    final hasBuffer = buffer > 0;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: hasBuffer ? AppColors.primaryGreen.withOpacity(0.1) : AppColors.gray200,
                          child: Icon(Icons.cleaning_services, color: hasBuffer ? AppColors.primaryGreen : AppColors.gray500),
                        ),
                        title: Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text('Duration: ${service['duration_minutes']} mins', style: TextStyle(color: AppColors.gray600)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasBuffer)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: AppColors.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text('+$buffer mins', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.gray500),
                              onPressed: () => _showBufferModal(service),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          const InteractiveHelpScroll(contextKey: 'services_buffers'),
        ],
      ),
    );
  }
}

class _BufferFormSheet extends StatefulWidget {
  final Map<String, dynamic> service;
  final VoidCallback onSave;

  const _BufferFormSheet({required this.service, required this.onSave});

  @override
  State<_BufferFormSheet> createState() => _BufferFormSheetState();
}

class _BufferFormSheetState extends State<_BufferFormSheet> {
  final _bufferCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bufferCtrl.text = (widget.service['buffer_minutes'] ?? 0).toString();
  }

  @override
  void dispose() {
    _bufferCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final buffer = int.tryParse(_bufferCtrl.text) ?? 0;
    
    final db = await DbProvider.db;
    await db.update('services_catalog', {'buffer_minutes': buffer}, where: 'id = ?', whereArgs: [widget.service['id']]);
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
            Text('Set Buffer for ${widget.service['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Buffer time is automatically added to the end of a booking to prevent back-to-back scheduling before cleanup is done.', style: TextStyle(color: AppColors.gray600, fontSize: 13, height: 1.4)),
            const SizedBox(height: 24),
            TextField(
              controller: _bufferCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Buffer Time (Minutes)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _save,
              child: const Text('Save Buffer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
