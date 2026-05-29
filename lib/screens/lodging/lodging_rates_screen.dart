import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';

class LodgingRatesScreen extends StatefulWidget {
  const LodgingRatesScreen({super.key});

  @override
  State<LodgingRatesScreen> createState() => _LodgingRatesScreenState();
}

class _LodgingRatesScreenState extends State<LodgingRatesScreen> {
  List<Map<String, dynamic>> _ratePlans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRatePlans();
  }

  Future<void> _loadRatePlans() async {
    try {
      final db = await DbProvider.db;
      final rates = await db.query('lodging_rate_plans', orderBy: 'id DESC');
      if (mounted) {
        setState(() {
          _ratePlans = List.from(rates);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rate plans: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRatePlanModal([Map<String, dynamic>? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RatePlanFormSheet(
        initialData: existing,
        onSave: () {
          Navigator.pop(context);
          _loadRatePlans();
        },
      ),
    );
  }

  void _deleteRatePlan(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Rate Plan?', style: TextStyle(color: Colors.black)),
        content: const Text('Are you sure you want to permanently delete this rate plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.gray500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final db = await DbProvider.db;
      await db.delete('lodging_rate_plans', where: 'id = ?', whereArgs: [id]);
      _loadRatePlans();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate plan deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('Rate Plans & Seasons', style: TextStyle(color: AppColors.gray900, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
      ),
      body: Stack(
        children: [
          _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _ratePlans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.price_change_outlined, size: 64, color: AppColors.gray300),
                      const SizedBox(height: 16),
                      Text('No Rate Plans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                      const SizedBox(height: 8),
                      Text('Create seasonal pricing, non-refundable rates,\nand breakfast-included packages.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.gray500, height: 1.4)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _ratePlans.length,
                  itemBuilder: (context, index) {
                    final rate = _ratePlans[index];
                    final id = rate['id'] as int;
                    final name = rate['name'] as String;
                    final baseRate = (rate['base_rate'] as num).toDouble();
                    final includesBreakfast = (rate['includes_breakfast'] as int?) == 1;
                    final isRefundable = (rate['is_refundable'] as int?) == 1;
                    
                    String dateRange = 'Active Always';
                    if (rate['start_date'] != null && rate['end_date'] != null) {
                      final start = DateTime.fromMillisecondsSinceEpoch(rate['start_date'] as int);
                      final end = DateTime.fromMillisecondsSinceEpoch(rate['end_date'] as int);
                      dateRange = '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
                    }

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
                            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            Text('KES ${baseRate.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 16)),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(rate['description'] ?? '', style: TextStyle(color: AppColors.gray600, fontSize: 13)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildBadge(Icons.calendar_month, dateRange, AppColors.gray700, AppColors.gray100),
                                if (includesBreakfast) _buildBadge(Icons.restaurant, 'Breakfast Included', Colors.orange.shade700, Colors.orange.shade50),
                                if (!isRefundable) _buildBadge(Icons.money_off, 'Non-Refundable', Colors.red.shade700, Colors.red.shade50),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: AppColors.gray500),
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showRatePlanModal(rate);
                            } else if (val == 'delete') {
                              _deleteRatePlan(id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          const InteractiveHelpScroll(contextKey: 'lodging_rates'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: () => _showRatePlanModal(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Rate Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RatePlanFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback onSave;

  const _RatePlanFormSheet({this.initialData, required this.onSave});

  @override
  State<_RatePlanFormSheet> createState() => _RatePlanFormSheetState();
}

class _RatePlanFormSheetState extends State<_RatePlanFormSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  
  bool _includesBreakfast = false;
  bool _isRefundable = true;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameCtrl.text = widget.initialData!['name'];
      _descCtrl.text = widget.initialData!['description'] ?? '';
      _rateCtrl.text = widget.initialData!['base_rate'].toString();
      _includesBreakfast = widget.initialData!['includes_breakfast'] == 1;
      _isRefundable = widget.initialData!['is_refundable'] == 1;
      
      if (widget.initialData!['start_date'] != null) {
        _startDate = DateTime.fromMillisecondsSinceEpoch(widget.initialData!['start_date']);
      }
      if (widget.initialData!['end_date'] != null) {
        _endDate = DateTime.fromMillisecondsSinceEpoch(widget.initialData!['end_date']);
      }
    }
  }

  Future<void> _pickDateRange() async {
    final initialRange = _startDate != null && _endDate != null
        ? DateTimeRange(start: _startDate!, end: _endDate!)
        : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppColors.gray900,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final rateStr = _rateCtrl.text.trim();

    if (name.isEmpty || rateStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and base rate are required')));
      return;
    }

    final rate = double.tryParse(rateStr);
    if (rate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid base rate')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final db = await DbProvider.db;
      final data = {
        'name': name,
        'description': _descCtrl.text.trim(),
        'base_rate': rate,
        'includes_breakfast': _includesBreakfast ? 1 : 0,
        'is_refundable': _isRefundable ? 1 : 0,
        'start_date': _startDate?.millisecondsSinceEpoch,
        'end_date': _endDate?.millisecondsSinceEpoch,
      };

      if (widget.initialData == null) {
        await db.insert('lodging_rate_plans', data);
      } else {
        await db.update('lodging_rate_plans', data, where: 'id = ?', whereArgs: [widget.initialData!['id']]);
      }

      widget.onSave();
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.initialData == null ? 'New Rate Plan' : 'Edit Rate Plan', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gray900)),
            const SizedBox(height: 24),
            
            // Name
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Plan Name (e.g. Summer Special)',
                filled: true,
                fillColor: AppColors.gray50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            
            // Base Rate
            TextField(
              controller: _rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Base Nightly Rate',
                prefixText: 'KES ',
                filled: true,
                fillColor: AppColors.gray50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description',
                filled: true,
                fillColor: AppColors.gray50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),

            // Switches
            SwitchListTile(
              title: const Text('Includes Breakfast', style: TextStyle(fontWeight: FontWeight.w500)),
              activeColor: AppColors.primaryGreen,
              contentPadding: EdgeInsets.zero,
              value: _includesBreakfast,
              onChanged: (val) => setState(() => _includesBreakfast = val),
            ),
            SwitchListTile(
              title: const Text('Fully Refundable', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Allow guests to cancel without penalty', style: TextStyle(fontSize: 12)),
              activeColor: AppColors.primaryGreen,
              contentPadding: EdgeInsets.zero,
              value: _isRefundable,
              onChanged: (val) => setState(() => _isRefundable = val),
            ),
            const SizedBox(height: 16),

            // Date Picker Row
            const Text('Active Season (Optional)', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.gray700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDateRange,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.gray300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month, size: 18, color: AppColors.gray500),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _startDate == null 
                                  ? 'Always Active'
                                  : '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d, yy').format(_endDate!)}',
                              style: TextStyle(color: _startDate == null ? AppColors.gray500 : AppColors.gray900, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_startDate != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearDates,
                    tooltip: 'Clear dates',
                  )
                ],
              ],
            ),
            const SizedBox(height: 32),

            // Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.gray500)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isProcessing ? null : _save,
                    child: _isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Rate Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
