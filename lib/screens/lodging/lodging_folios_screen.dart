import 'package:flutter/material.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';

class LodgingFoliosScreen extends StatefulWidget {
  const LodgingFoliosScreen({super.key});

  @override
  State<LodgingFoliosScreen> createState() => _LodgingFoliosScreenState();
}

class _LodgingFoliosScreenState extends State<LodgingFoliosScreen> {
  List<Map<String, dynamic>> _folios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFolios();
  }

  Future<void> _loadFolios() async {
    try {
      final db = await DbProvider.db;
      // Join folios with reservations to display the guest context
      final foliosData = await db.rawQuery('''
        SELECT f.*, r.guest_name, r.room_id
        FROM lodging_folios f
        JOIN lodging_reservations r ON f.reservation_id = r.id
        ORDER BY f.id DESC
      ''');
      
      if (mounted) {
        setState(() {
          _folios = List.from(foliosData);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading folios: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFolioModal([Map<String, dynamic>? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FolioFormSheet(
        initialData: existing,
        onSave: () {
          Navigator.pop(context);
          _loadFolios();
        },
      ),
    );
  }

  void _deleteFolio(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Folio?', style: TextStyle(color: Colors.black)),
        content: const Text('Are you sure you want to permanently delete this sub-ledger folio? The original reservation will be preserved.'),
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
      await db.delete('lodging_folios', where: 'id = ?', whereArgs: [id]);
      _loadFolios();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Folio sub-ledger deleted')));
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
        title: const Text('Folio Management', style: TextStyle(color: AppColors.gray900, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
      ),
      body: Stack(
        children: [
          _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _folios.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppColors.gray300),
                      const SizedBox(height: 16),
                      Text('No Active Folios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                      const SizedBox(height: 8),
                      Text('Create separate billing folios so a guest can charge\nroom rates to their company and extras to themselves.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.gray500, height: 1.4)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _folios.length,
                  itemBuilder: (context, index) {
                    final folio = _folios[index];
                    final id = folio['id'] as int;
                    final name = folio['name'] as String;
                    final subtotal = (folio['subtotal'] as num).toDouble();
                    final isMaster = (folio['is_master'] as int?) == 1;
                    final guestName = folio['guest_name'] as String? ?? 'Unknown Guest';

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
                            Text('KES ${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 16)),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text('Linked to: $guestName', style: TextStyle(color: AppColors.gray600, fontSize: 13, fontWeight: FontWeight.w500)),
                            if (folio['billing_address'] != null && folio['billing_address'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(folio['billing_address'].toString(), style: TextStyle(color: AppColors.gray400, fontSize: 12)),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildBadge(Icons.hotel_class, isMaster ? 'Master Folio' : 'Sub-Ledger', isMaster ? Colors.purple.shade700 : AppColors.gray700, isMaster ? Colors.purple.shade50 : AppColors.gray100),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: AppColors.gray500),
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showFolioModal(folio);
                            } else if (val == 'delete') {
                              _deleteFolio(id);
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
          const InteractiveHelpScroll(contextKey: 'lodging_folios'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: () => _showFolioModal(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Folio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

class _FolioFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback onSave;

  const _FolioFormSheet({this.initialData, required this.onSave});

  @override
  State<_FolioFormSheet> createState() => _FolioFormSheetState();
}

class _FolioFormSheetState extends State<_FolioFormSheet> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  
  bool _isMaster = false;
  int? _selectedReservationId;
  List<Map<String, dynamic>> _activeReservations = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadReservations();
    if (widget.initialData != null) {
      _nameCtrl.text = widget.initialData!['name'];
      _addressCtrl.text = widget.initialData!['billing_address'] ?? '';
      _isMaster = widget.initialData!['is_master'] == 1;
      _selectedReservationId = widget.initialData!['reservation_id'];
    }
  }

  Future<void> _loadReservations() async {
    try {
      final db = await DbProvider.db;
      final res = await db.query('lodging_reservations', where: "status NOT IN ('cancelled')", orderBy: 'id DESC', limit: 50);
      if (mounted) setState(() => _activeReservations = List.from(res));
    } catch (e) {
      debugPrint('Error loading reservations for folio: $e');
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty || _selectedReservationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Folio name and reservation link are required')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final db = await DbProvider.db;
      final data = {
        'name': name,
        'billing_address': _addressCtrl.text.trim(),
        'is_master': _isMaster ? 1 : 0,
        'reservation_id': _selectedReservationId,
      };

      if (widget.initialData == null) {
        data['subtotal'] = 0.0;
        await db.insert('lodging_folios', data);
      } else {
        await db.update('lodging_folios', data, where: 'id = ?', whereArgs: [widget.initialData!['id']]);
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
    _addressCtrl.dispose();
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
            Text(widget.initialData == null ? 'New Folio Sub-ledger' : 'Edit Folio', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gray900)),
            const SizedBox(height: 24),

            // Link to Reservation Dropdown
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Link to Reservation',
                filled: true,
                fillColor: AppColors.gray50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isDense: true,
                  isExpanded: true,
                  value: _selectedReservationId,
                  hint: const Text('Select a reservation...'),
                  items: _activeReservations.map((res) {
                    return DropdownMenuItem<int>(
                      value: res['id'] as int,
                      child: Text('${res['guest_name']} (Room ${res['room_id']})', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedReservationId = val;
                      if (_nameCtrl.text.isEmpty && val != null) {
                        final res = _activeReservations.firstWhere((r) => r['id'] == val);
                        _nameCtrl.text = '${res['guest_name']} - Incidental Folio';
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Name
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Folio Name (e.g. Incidental Charges)',
                filled: true,
                fillColor: AppColors.gray50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            
            // Billing Address
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Enterprise Billing Address (Optional)',
                filled: true,
                fillColor: AppColors.gray50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),

            // Switches
            SwitchListTile(
              title: const Text('Master Folio', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Is this the primary folio responsible for the room rate charges?', style: TextStyle(fontSize: 12)),
              activeColor: Colors.purple,
              contentPadding: EdgeInsets.zero,
              value: _isMaster,
              onChanged: (val) => setState(() => _isMaster = val),
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
                        : const Text('Save Folio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
