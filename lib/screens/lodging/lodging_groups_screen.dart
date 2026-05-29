import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';

class LodgingGroupsScreen extends StatefulWidget {
  const LodgingGroupsScreen({super.key});

  @override
  State<LodgingGroupsScreen> createState() => _LodgingGroupsScreenState();
}

class _LodgingGroupsScreenState extends State<LodgingGroupsScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final db = await DbProvider.db;
      final groups = await db.query('lodging_groups', orderBy: 'id DESC');
      if (mounted) {
        setState(() {
          _groups = List.from(groups);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading groups: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showGroupModal([Map<String, dynamic>? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GroupFormSheet(
        initialData: existing,
        onSave: () {
          Navigator.pop(context);
          _loadGroups();
        },
      ),
    );
  }

  void _deleteGroup(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Group Block?', style: TextStyle(color: Colors.black)),
        content: const Text('Are you sure you want to permanently delete this room block? Existing reservations will not be deleted but they will lose their group association.'),
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
      await db.delete('lodging_groups', where: 'id = ?', whereArgs: [id]);
      _loadGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group block deleted')));
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
        title: const Text('Group Blocks & Events', style: TextStyle(color: AppColors.gray900, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
      ),
      body: Stack(
        children: [
          _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_work_outlined, size: 64, color: AppColors.gray300),
                      const SizedBox(height: 16),
                      Text('No Active Group Blocks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                      const SizedBox(height: 8),
                      Text('Allocate blocks of rooms temporarily under a master\ncontract for weddings, sports teams, or tours.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.gray500, height: 1.4)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    final id = group['id'] as int;
                    final name = group['name'] as String;
                    final contractStr = group['contract_name'] as String? ?? '';
                    final allocated = group['total_rooms_allocated'] as int;
                    final pickedUp = group['rooms_picked_up'] as int? ?? 0;
                    
                    final cutoffDateInt = group['cutoff_date'] as int?;
                    String cutoffStr = 'No Cutoff Date';
                    bool isCutoffPassed = false;
                    
                    if (cutoffDateInt != null) {
                      final dt = DateTime.fromMillisecondsSinceEpoch(cutoffDateInt);
                      cutoffStr = DateFormat('MMM d, yyyy').format(dt);
                      isCutoffPassed = DateTime.now().isAfter(dt);
                    }
                    
                    final double progress = allocated > 0 ? (pickedUp / allocated) : 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                Text('$pickedUp / $allocated Rooms', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 14)),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (contractStr.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(contractStr, style: TextStyle(color: AppColors.gray600, fontSize: 13)),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildBadge(
                                      Icons.event_busy, 
                                      'Cutoff: $cutoffStr', 
                                      isCutoffPassed ? Colors.red.shade700 : AppColors.gray700, 
                                      isCutoffPassed ? Colors.red.shade50 : AppColors.gray100
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: AppColors.gray500),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showGroupModal(group);
                                } else if (val == 'delete') {
                                  _deleteGroup(id);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit Block')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete Block', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          ),
                          // Progress Bar Wrapper
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Pickup Rate', style: TextStyle(fontSize: 10, color: AppColors.gray500, fontWeight: FontWeight.bold)),
                                    Text('${(progress * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8,
                                    backgroundColor: AppColors.gray100,
                                    color: progress >= 1.0 ? AppColors.success : AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          const InteractiveHelpScroll(contextKey: 'lodging_groups'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: () => _showGroupModal(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Group Block', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

class _GroupFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback onSave;

  const _GroupFormSheet({this.initialData, required this.onSave});

  @override
  State<_GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends State<_GroupFormSheet> {
  final _nameCtrl = TextEditingController();
  final _contractCtrl = TextEditingController();
  final _allocatedCtrl = TextEditingController();
  
  DateTime? _cutoffDate;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameCtrl.text = widget.initialData!['name'];
      _contractCtrl.text = widget.initialData!['contract_name'] ?? '';
      _allocatedCtrl.text = widget.initialData!['total_rooms_allocated'].toString();
      
      if (widget.initialData!['cutoff_date'] != null) {
        _cutoffDate = DateTime.fromMillisecondsSinceEpoch(widget.initialData!['cutoff_date']);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _cutoffDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
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
      setState(() => _cutoffDate = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final allocatedStr = _allocatedCtrl.text.trim();

    if (name.isEmpty || allocatedStr.isEmpty || _cutoffDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name, Date, and Block Amount are required')));
      return;
    }

    final allocated = int.tryParse(allocatedStr);
    if (allocated == null || allocated <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid room block amount')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final db = await DbProvider.db;
      final data = {
        'name': name,
        'contract_name': _contractCtrl.text.trim(),
        'total_rooms_allocated': allocated,
        'cutoff_date': _cutoffDate!.millisecondsSinceEpoch,
      };

      if (widget.initialData == null) {
        data['rooms_picked_up'] = 0;
        await db.insert('lodging_groups', data);
      } else {
        await db.update('lodging_groups', data, where: 'id = ?', whereArgs: [widget.initialData!['id']]);
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
    _contractCtrl.dispose();
    _allocatedCtrl.dispose();
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
            Text(widget.initialData == null ? 'New Group Block' : 'Edit Group Block', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gray900)),
            const SizedBox(height: 24),
            
            // Name
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Group Name (e.g. Smith Wedding)',
                filled: true,
                fillColor: AppColors.gray50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _allocatedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Rooms to Hold',
                      filled: true,
                      fillColor: AppColors.gray50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.gray300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_busy, size: 18, color: AppColors.gray500),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _cutoffDate == null 
                                  ? 'Select Cutoff Date'
                                  : DateFormat('MMM d, yyyy').format(_cutoffDate!),
                              style: TextStyle(color: _cutoffDate == null ? AppColors.gray500 : AppColors.gray900, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contract
            TextField(
              controller: _contractCtrl,
              decoration: InputDecoration(
                labelText: 'Master Contract / Entity (Optional)',
                filled: true,
                fillColor: AppColors.gray50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
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
                        : const Text('Save Group Block', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
