import 'package:flutter/material.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';

class EntertainmentPricingScreen extends StatefulWidget {
  const EntertainmentPricingScreen({super.key});

  @override
  State<EntertainmentPricingScreen> createState() => _EntertainmentPricingScreenState();
}

class _EntertainmentPricingScreenState extends State<EntertainmentPricingScreen> {
  List<Map<String, dynamic>> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    try {
      final db = await DbProvider.db;
      final rules = await db.query('entertainment_pricing_rules', orderBy: 'id DESC');
      if (mounted) {
        setState(() {
          _rules = List.from(rules);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pricing rules: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRuleModal([Map<String, dynamic>? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PricingRuleSheet(
        initialData: existing,
        onSave: () {
          Navigator.pop(context);
          _loadRules();
        },
      ),
    );
  }

  void _deleteRule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Pricing Rule?'),
        content: const Text('Are you sure you want to remove this dynamic pricing rule?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await DbProvider.db;
      await db.delete('entertainment_pricing_rules', where: 'id = ?', whereArgs: [id]);
      _loadRules();
    }
  }

  String _getDayName(int? day) {
    switch (day) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Everyday';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('Dynamic Pricing', style: TextStyle(color: AppColors.gray900, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : _rules.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_graph, size: 64, color: AppColors.gray300),
                          const SizedBox(height: 16),
                          Text('No Pricing Rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                          const SizedBox(height: 8),
                          Text('Set up peak/off-peak rates based on days and times.',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.gray500, height: 1.4)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rules.length,
                      itemBuilder: (context, index) {
                        final rule = _rules[index];
                        final isActive = rule['is_active'] == 1;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gray200),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(rule['category'] ?? 'All Assets', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('\$${rule['rate_per_hour']}/hr', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 16)),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text('${_getDayName(rule['day_of_week'])}s • ${rule['start_time']} - ${rule['end_time']}', style: TextStyle(color: AppColors.gray700)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isActive ? AppColors.success.withOpacity(0.1) : AppColors.gray200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isActive ? 'Active' : 'Disabled',
                                    style: TextStyle(color: isActive ? AppColors.success : AppColors.gray600, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'edit') _showRuleModal(rule);
                                if (val == 'delete') _deleteRule(rule['id']);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit Rule')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete Rule', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          const InteractiveHelpScroll(contextKey: 'entertainment_pricing'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: () => _showRuleModal(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Rule', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _PricingRuleSheet extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback onSave;

  const _PricingRuleSheet({this.initialData, required this.onSave});

  @override
  State<_PricingRuleSheet> createState() => _PricingRuleSheetState();
}

class _PricingRuleSheetState extends State<_PricingRuleSheet> {
  final _categoryCtrl = TextEditingController();
  final _startCtrl = TextEditingController(text: '18:00');
  final _endCtrl = TextEditingController(text: '23:59');
  final _rateCtrl = TextEditingController();
  int? _dayOfWeek;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _categoryCtrl.text = widget.initialData!['category'] ?? '';
      _startCtrl.text = widget.initialData!['start_time'];
      _endCtrl.text = widget.initialData!['end_time'];
      _rateCtrl.text = widget.initialData!['rate_per_hour'].toString();
      _dayOfWeek = widget.initialData!['day_of_week'];
      _isActive = widget.initialData!['is_active'] == 1;
    }
  }

  @override
  void dispose() {
    _categoryCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rate = double.tryParse(_rateCtrl.text);
    if (rate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid rate amount')));
      return;
    }

    final data = {
      'category': _categoryCtrl.text.isEmpty ? 'All' : _categoryCtrl.text,
      'day_of_week': _dayOfWeek,
      'start_time': _startCtrl.text,
      'end_time': _endCtrl.text,
      'rate_per_hour': rate,
      'is_active': _isActive ? 1 : 0,
    };

    final db = await DbProvider.db;
    if (widget.initialData == null) {
      await db.insert('entertainment_pricing_rules', data);
    } else {
      await db.update('entertainment_pricing_rules', data, where: 'id = ?', whereArgs: [widget.initialData!['id']]);
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
            Text(widget.initialData == null ? 'New Pricing Rule' : 'Edit Rule', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(labelText: 'Asset Category (e.g. Pool, VIP Room)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              value: _dayOfWeek,
              decoration: const InputDecoration(labelText: 'Day of Week', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: null, child: Text('Everyday')),
                DropdownMenuItem(value: 1, child: Text('Monday')),
                DropdownMenuItem(value: 5, child: Text('Friday')),
                DropdownMenuItem(value: 6, child: Text('Saturday')),
                DropdownMenuItem(value: 7, child: Text('Sunday')),
              ],
              onChanged: (val) => setState(() => _dayOfWeek = val),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _startCtrl, decoration: const InputDecoration(labelText: 'Start Time (HH:mm)', border: OutlineInputBorder()))),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: _endCtrl, decoration: const InputDecoration(labelText: 'End Time (HH:mm)', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rateCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Hourly Rate (\$)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Rule Active'),
              value: _isActive,
              onChanged: (val) => setState(() => _isActive = val),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _save,
              child: const Text('Save Rule', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
