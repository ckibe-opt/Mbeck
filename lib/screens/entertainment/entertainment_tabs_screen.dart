import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';

class EntertainmentTabsScreen extends StatefulWidget {
  const EntertainmentTabsScreen({super.key});

  @override
  State<EntertainmentTabsScreen> createState() => _EntertainmentTabsScreenState();
}

class _EntertainmentTabsScreenState extends State<EntertainmentTabsScreen> {
  List<Map<String, dynamic>> _tabs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTabs();
  }

  Future<void> _loadTabs() async {
    try {
      final db = await DbProvider.db;
      final query = '''
        SELECT t.*, s.customer_name, a.name as asset_name
        FROM entertainment_tabs t
        JOIN entertainment_sessions s ON t.session_id = s.id
        JOIN entertainment_assets a ON s.asset_id = a.id
        ORDER BY t.created_at DESC
      ''';
      
      final tabs = await db.rawQuery(query);
      if (mounted) {
        setState(() {
          _tabs = List.from(tabs);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tabs: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddTabModal() async {
    final db = await DbProvider.db;
    final sessions = await db.rawQuery('''
      SELECT s.id, s.customer_name, a.name as asset_name 
      FROM entertainment_sessions s 
      JOIN entertainment_assets a ON s.asset_id = a.id 
      WHERE s.status = 'active'
    ''');
    
    if (sessions.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active sessions available to attach a tab.')));
      return;
    }

    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddTabSheet(
        sessions: sessions,
        onSave: () {
          Navigator.pop(context);
          _loadTabs();
        },
      ),
    );
  }

  void _deleteTab(int id) async {
    final db = await DbProvider.db;
    await db.delete('entertainment_tabs', where: 'id = ?', whereArgs: [id]);
    _loadTabs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('Cross-Module Tabs', style: TextStyle(color: AppColors.gray900, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : _tabs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_bar, size: 64, color: AppColors.gray300),
                          const SizedBox(height: 16),
                          Text('No Active Tabs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                          const SizedBox(height: 8),
                          Text('Link food and beverage orders to active gaming sessions.',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.gray500, height: 1.4)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tabs.length,
                      itemBuilder: (context, index) {
                        final tab = _tabs[index];
                        final date = DateTime.fromMillisecondsSinceEpoch(tab['created_at']);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gray200),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                              child: Icon(Icons.receipt_long, color: AppColors.primaryGreen),
                            ),
                            title: Text('Order #${tab['external_order_id']} (${tab['external_module']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${tab['asset_name']} - ${tab['customer_name'] ?? 'Walk-in'}\n${DateFormat.yMd().add_jm().format(date)}', style: TextStyle(color: AppColors.gray600, height: 1.3)),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('\$${(tab['amount'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gray900, fontSize: 16)),
                                IconButton(icon: Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteTab(tab['id'])),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          const InteractiveHelpScroll(contextKey: 'entertainment_tabs'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: _showAddTabModal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Tab', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _AddTabSheet extends StatefulWidget {
  final List<Map<String, dynamic>> sessions;
  final VoidCallback onSave;

  const _AddTabSheet({required this.sessions, required this.onSave});

  @override
  State<_AddTabSheet> createState() => _AddTabSheetState();
}

class _AddTabSheetState extends State<_AddTabSheet> {
  final _orderIdCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  int? _selectedSessionId;

  Future<void> _save() async {
    if (_selectedSessionId == null || _orderIdCtrl.text.isEmpty || _amountCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null) return;

    final db = await DbProvider.db;
    await db.insert('entertainment_tabs', {
      'session_id': _selectedSessionId,
      'external_order_id': _orderIdCtrl.text,
      'external_module': 'restaurant',
      'amount': amount,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    
    widget.onSave();
  }

  @override
  void dispose() {
    _orderIdCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
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
            const Text('Link Order to Session', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            DropdownButtonFormField<int>(
              value: _selectedSessionId,
              decoration: const InputDecoration(labelText: 'Target Session', border: OutlineInputBorder()),
              items: widget.sessions.map((s) {
                return DropdownMenuItem<int>(
                  value: s['id'] as int,
                  child: Text('${s['asset_name']} - ${s['customer_name'] ?? 'Walk-in'}'),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedSessionId = val),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _orderIdCtrl,
              decoration: const InputDecoration(labelText: 'Restaurant Order ID', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tab Amount (\$)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _save,
              child: const Text('Link Tab', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
