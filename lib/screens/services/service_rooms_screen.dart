import 'package:flutter/material.dart';
import '../../db/db_provider.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';

class ServiceRoomsScreen extends StatefulWidget {
  const ServiceRoomsScreen({super.key});

  @override
  State<ServiceRoomsScreen> createState() => _ServiceRoomsScreenState();
}

class _ServiceRoomsScreenState extends State<ServiceRoomsScreen> {
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final db = await DbProvider.db;
      final rooms = await db.query('services_rooms', orderBy: 'id DESC');
      if (mounted) {
        setState(() {
          _rooms = List.from(rooms);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rooms: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRoomModal([Map<String, dynamic>? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RoomFormSheet(
        initialData: existing,
        onSave: () {
          Navigator.pop(context);
          _loadRooms();
        },
      ),
    );
  }

  void _deleteRoom(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Room?'),
        content: const Text('Are you sure you want to delete this room? Bookings assigned to it will lose their room anchor.'),
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
      await db.delete('services_rooms', where: 'id = ?', whereArgs: [id]);
      _loadRooms();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('Physical Rooms & Assets', style: TextStyle(color: AppColors.gray900, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gray900),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.meeting_room_outlined, size: 64, color: AppColors.gray300),
                      const SizedBox(height: 16),
                      Text('No Rooms Configured', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                      const SizedBox(height: 8),
                      Text('Add physical constraints (e.g. Massage Room A)\nto prevent double-booking constraints.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.gray500, height: 1.4)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rooms.length,
                  itemBuilder: (context, index) {
                    final room = _rooms[index];
                    final isActive = room['is_active'] == 1;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive ? AppColors.primaryGreen.withOpacity(0.1) : AppColors.gray200,
                          child: Icon(Icons.meeting_room, color: isActive ? AppColors.primaryGreen : AppColors.gray500),
                        ),
                        title: Text(room['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text('Capacity: ${room['capacity']}', style: TextStyle(color: AppColors.gray600)),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'edit') _showRoomModal(room);
                            if (val == 'delete') _deleteRoom(room['id']);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit Room')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete Room', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          const InteractiveHelpScroll(contextKey: 'services_rooms'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: () => _showRoomModal(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Room', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _RoomFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback onSave;

  const _RoomFormSheet({this.initialData, required this.onSave});

  @override
  State<_RoomFormSheet> createState() => _RoomFormSheetState();
}

class _RoomFormSheetState extends State<_RoomFormSheet> {
  final _nameCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '1');
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nameCtrl.text = widget.initialData!['name'];
      _capacityCtrl.text = widget.initialData!['capacity'].toString();
      _isActive = widget.initialData!['is_active'] == 1;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room name required')));
      return;
    }
    
    final db = await DbProvider.db;
    final data = {
      'name': _nameCtrl.text,
      'capacity': int.tryParse(_capacityCtrl.text) ?? 1,
      'is_active': _isActive ? 1 : 0,
    };

    if (widget.initialData == null) {
      await db.insert('services_rooms', data);
    } else {
      await db.update('services_rooms', data, where: 'id = ?', whereArgs: [widget.initialData!['id']]);
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
            Text(widget.initialData == null ? 'New Room/Asset' : 'Edit Room', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Room Name (e.g. Massage Room 1)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _capacityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacity (Concurrent clients)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Active Room'),
              value: _isActive,
              onChanged: (val) => setState(() => _isActive = val),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _save,
              child: const Text('Save Room', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
