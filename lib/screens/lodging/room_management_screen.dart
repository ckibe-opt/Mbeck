import 'package:flutter/material.dart';
import '../../../widgets/empty_state_guide.dart';
import '../../widgets/universal_image.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/lodging_service.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';
import '../../widgets/standard_app_bar.dart';
import '../../db/db_provider.dart';
import '../../services/event_service.dart';
import '../../config/app_config.dart';

/// Room Management screen for the Lodging module.
///
/// Features:
/// - Tab 1: Room Types — create/edit types with image gallery, rate, amenities
/// - Tab 2: All Rooms — grid of rooms with batch-add, status management
class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _roomTypes = [];
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;
  String _filterType = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bulkPublish(bool publish) async {
    setState(() => _isLoading = true);
    try {
      final db = await DbProvider.db;
      final publishVal = publish ? 1 : 0;
      await db.update(
        'lodging_rooms',
        {'is_published': publishVal, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      );

      try {
        await EventService.emitEvent(
          eventType: 'SHOP_UPDATE',
          payload: {'action': publish ? 'bulk_publish' : 'bulk_unpublish', 'module': 'lodging'},
        );
      } catch (e) {
        debugPrint('⚠️ Failed to emit bulk publish event: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(publish ? 'All rooms published online!' : 'All rooms removed from online.')),
        );
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final types = await LodgingService.getRoomTypesWithDetails();
      final rooms = await LodgingService.getRooms(activeOnly: false);
      if (mounted) {
        setState(() {
          _roomTypes = types;
          _rooms = rooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rooms: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRooms {
    if (_filterType == 'All') return _rooms;
    return _rooms.where((r) => r['room_type'] == _filterType).toList();
  }

  // ========== BUILD ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          Column(
            children: [
          // ─── App Bar ─────────────────────
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B7280), size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text('Spaces', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF9CA3AF), size: 22), onPressed: _loadAll),

                      ],
                    ),
                  ),
                  // Cyan underline tabs
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF0891B2),
                    unselectedLabelColor: const Color(0xFF6B7280),
                    indicatorColor: const Color(0xFF0891B2),
                    indicatorWeight: 2.5,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(text: 'Types (${_roomTypes.length})'),
                      Tab(text: 'All Rooms (${_rooms.length})'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ─── Content ─────────────────────
          Expanded(
            child: _isLoading
                ? AppSkeleton.screen()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRoomTypesTab(),
                      _buildAllRoomsTab(),
                    ],
                  ),
          ),
        ],
      ),
      const InteractiveHelpScroll(contextKey: 'lodging_rooms'),
      ],
      ),
    );
  }

  // ========== TAB 1: ROOM TYPES ==========

  Widget _buildRoomTypesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: GestureDetector(
            onTap: () => _showRoomTypeDialog(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0891B2),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: const Color(0xFF0891B2).withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Center(child: Text('Create Room Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
          ),
        ),
        Expanded(
          child: _roomTypes.isEmpty
              ? EmptyStateGuide(
                  icon: Icons.category_outlined,
                  title: 'No room types yet',
                  subtitle: 'Create types like "Standard", "Deluxe", or "Suite" to organize your property',
                  actionLabel: 'Create Room Type',
                  onAction: () => _showRoomTypeDialog(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: _roomTypes.length,
                  itemBuilder: (context, index) => _buildRoomTypeCard(_roomTypes[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildRoomTypeCard(Map<String, dynamic> type) {
    final roomCount = (type['room_count'] as int?) ?? 0;
    final rate = (type['rate_per_night'] as num?)?.toDouble() ?? 0;
    final capacity = (type['capacity'] as int?) ?? 2;
    final amenities = type['amenities'] as String? ?? '';

    return GestureDetector(
      onTap: () => _showRoomTypeDialog(existing: type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: LodgingService.getRoomTypeImages(type['id'] as int),
              builder: (context, snapshot) {
                final images = snapshot.data ?? [];
                if (images.isNotEmpty) {
                  final path = images.first['image_path'] as String;
                  if (path.isNotEmpty) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: UniversalImage(path, width: 56, height: 56, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _typePlaceholder()),
                    );
                  }
                }
                return _typePlaceholder();
              },
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(type['name'] as String? ?? 'Unnamed', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                      if ((type['is_published'] as int?) == 1)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.public, size: 14, color: Color(0xFF0891B2)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('KES ${rate.toStringAsFixed(0)}/night • $capacity guests', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                  if (amenities.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(amenities, style: TextStyle(fontSize: 10, color: Colors.grey[400]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0891B2).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.15)),
              ),
              child: Text('$roomCount rooms', style: const TextStyle(color: Color(0xFF0891B2), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typePlaceholder() {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF0891B2).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.hotel, color: Color(0xFF0891B2), size: 24),
    );
  }

  // ========== TAB 2: ALL ROOMS ==========

  Widget _buildAllRoomsTab() {
    final typeNames = _roomTypes.map((t) => t['name'] as String).toList();
    final occupiedCount = _filteredRooms.where((r) => r['status'] == 'occupied').length;
    final availableCount = _filteredRooms.where((r) => r['status'] == 'available').length;
    final cleaningCount = _filteredRooms.where((r) => r['status'] == 'cleaning').length;

    return Column(
      children: [
        // Stat pills
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 0, 6),
          child: SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildRoomStatPill('Occupied', occupiedCount, _filteredRooms.length, const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                _buildRoomStatPill('Available', availableCount, _filteredRooms.length, const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _buildRoomStatPill('Cleaning', cleaningCount, _filteredRooms.length, const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                // Batch Add button in stats row
                GestureDetector(
                  onTap: _roomTypes.isEmpty
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create a Room Type first')));
                          _tabController.animateTo(0);
                        }
                      : () => _showBatchAddDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: const Color(0xFF111827).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Add Rooms', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
        // Filter chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip('All'),
              ...typeNames.map((t) => _filterChip(t)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Room grid
        Expanded(
          child: _filteredRooms.isEmpty
              ? const EmptyStateGuide(
                  icon: Icons.bed_outlined,
                  title: 'No rooms configured',
                  subtitle: 'Use "Add Rooms" above to batch-create rooms and start accepting reservations',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  children: _buildFloorRoomSections(),
                ),
        ),
      ],
    );
  }

  Widget _buildRoomStatPill(String label, int value, int total, Color color) {
    final pct = total > 0 ? (value * 100 ~/ total) : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.06), color.withOpacity(0.02)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF111827), height: 1)),
              const SizedBox(width: 4),
              Text('$pct%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFloorRoomSections() {
    final Map<String, List<Map<String, dynamic>>> byFloor = {};
    for (final room in _filteredRooms) {
      final floor = (room['floor'] as String?)?.trim();
      final key = (floor != null && floor.isNotEmpty) ? floor : 'Ground';
      byFloor.putIfAbsent(key, () => []).add(room);
    }

    final sortedFloors = byFloor.keys.toList()
      ..sort((a, b) {
        final na = int.tryParse(a);
        final nb = int.tryParse(b);
        if (na != null && nb != null) return na.compareTo(nb);
        if (na != null) return -1;
        if (nb != null) return 1;
        if (a == 'Ground') return -1;
        if (b == 'Ground') return 1;
        return a.compareTo(b);
      });

    final widgets = <Widget>[];
    for (final floor in sortedFloors) {
      final rooms = byFloor[floor]!;
      // Floor header
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(
          '${_floorLabel(floor).toUpperCase()} • ${rooms.length} ROOMS',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF6B7280), letterSpacing: 1.5),
        ),
      ));
      // 2-column grid
      widgets.add(GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: rooms.map((r) => _buildRoomCard(r)).toList(),
      ));
    }
    return widgets;
  }

  String _floorLabel(String floor) {
    final n = int.tryParse(floor);
    if (n == null) return floor;
    if (n == 0) return 'Ground Floor';
    final suffix = n == 1 ? 'st' : n == 2 ? 'nd' : n == 3 ? 'rd' : 'th';
    return '$n$suffix Floor';
  }

  Widget _filterChip(String label) {
    final isSelected = _filterType == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filterType = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0891B2).withOpacity(0.12) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? const Color(0xFF0891B2).withOpacity(0.3) : const Color(0xFFE5E7EB)),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF0891B2) : const Color(0xFF6B7280),
          )),
        ),
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final isActive = (room['is_active'] as int?) == 1;
    final status = room['status'] as String? ?? 'available';
    final name = room['name'] as String? ?? 'Room';
    final type = room['type_name'] as String? ?? room['room_type'] as String? ?? '';
    final rate = (room['rate_per_night'] as num?)?.toDouble() ?? 0;
    final sc = _statusColor(status);

    return GestureDetector(
      onTap: () => _showStatusMenu(room),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: status == 'maintenance' ? const Color(0xFFF9FAFB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sc.withOpacity(0.25)),
          boxShadow: status == 'maintenance' ? null : [BoxShadow(color: sc.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name + icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5,
                      color: isActive ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                      decoration: status == 'maintenance' ? TextDecoration.lineThrough : null,
                    )),
                    Text(type.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 1)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((room['is_published'] as int?) == 1)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.public, size: 16, color: AppColors.primaryGreen),
                      ),
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: sc.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_statusIcon(status), size: 14, color: sc),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: status == 'occupied' ? sc : sc.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: status == 'occupied' ? Colors.white : sc, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            // Price or info
            if (status == 'available')
              Text('KES ${rate.toStringAsFixed(0)}/night', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'occupied': return Icons.people;
      case 'available': return Icons.check;
      case 'cleaning': return Icons.refresh;
      case 'maintenance': return Icons.build;
      default: return Icons.bed;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available': return const Color(0xFF059669); // Emerald
      case 'occupied': return const Color(0xFF2563EB); // Royal Blue
      case 'cleaning': return const Color(0xFFD97706); // Amber
      case 'maintenance': return const Color(0xFF475569); // Slate
      default: return const Color(0xFF64748B);
    }
  }

  // ========== ROOM TYPE DIALOG ==========

void _showRoomTypeDialog({Map<String, dynamic>? existing}) async {
    final isEditing = existing != null;
    
    final FocusNode nameFocus = FocusNode();
    final FocusNode rateFocus = FocusNode();
    bool isPublished = (existing?['is_published'] as int?) == 1;
    bool nameError = false;
    bool rateError = false;

    final nameCtl = TextEditingController(text: existing?['name'] ?? '');
    final rateCtl = TextEditingController(
      text: (existing?['rate_per_night'] as num?)?.toStringAsFixed(0) ?? '',
    );
    final rateWeekCtl = TextEditingController(
      text: (existing?['rate_per_week'] as num?)?.toStringAsFixed(0) ?? '',
    );
    final rateMonthCtl = TextEditingController(
      text: (existing?['rate_per_month'] as num?)?.toStringAsFixed(0) ?? '',
    );
    final capacityCtl = TextEditingController(
      text: (existing?['capacity'] as int?)?.toString() ?? '2',
    );
    final amenitiesCtl = TextEditingController(text: existing?['amenities'] ?? '');
    final descCtl = TextEditingController(text: existing?['description'] ?? '');
    List<String> imagePaths = [];
    final picker = ImagePicker();

    // Load existing images
    if (isEditing) {
      final images = await LodgingService.getRoomTypeImages(existing['id'] as int);
      imagePaths = images.map((img) => img['image_path'] as String).toList();
    }

    Future<void> pickImage(StateSetter setSheetState) async {
      if (imagePaths.length >= 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 10 images')),
          );
        }
        return;
      }
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Take Photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ]),
        ),
      );
      if (source == null) return;

      final XFile? photo = await picker.pickImage(
        source: source,
        imageQuality: 50, maxWidth: 512, maxHeight: 512,
      );
      if (photo != null) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'roomtype_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await File(photo.path).copy('${directory.path}/$fileName');
        setSheetState(() => imagePaths.add(savedImage.path));
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEditing ? 'Edit Room Type' : 'Create Room Type',
                  style: AppTypography.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                // Image gallery
                Container(
                  height: 130,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.photo_library, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Type Photos (${imagePaths.length}/10)',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            const Spacer(),
                            Text(
                              'Shared by all rooms of this type',
                              style: TextStyle(color: Colors.grey[400], fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: imagePaths.isEmpty
                            ? Center(
                                child: TextButton.icon(
                                  onPressed: () => pickImage(setSheetState),
                                  icon: const Icon(Icons.add_a_photo),
                                  label: const Text('Add Photos'),
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                itemCount: imagePaths.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == imagePaths.length) {
                                    return GestureDetector(
                                      onTap: () => pickImage(setSheetState),
                                      child: Container(
                                        width: 70,
                                        margin: const EdgeInsets.only(right: 8, bottom: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppColors.primaryGreen),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.add_a_photo,
                                            color: AppColors.primaryGreen, size: 20),
                                      ),
                                    );
                                  }
                                  return Stack(
                                    children: [
                                      Container(
                                        width: 70,
                                        margin: const EdgeInsets.only(right: 8, bottom: 8),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: (() {
                                            final path = imagePaths[index];
                                            if (path.isNotEmpty) {
                                              return UniversalImage(
                                                path,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(Icons.broken_image),
                                                ),
                                              );
                                            }
                                            return Container(
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.broken_image),
                                            );
                                          })(),
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 8,
                                        child: GestureDetector(
                                          onTap: () =>
                                              setSheetState(() => imagePaths.removeAt(index)),
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close,
                                                size: 16, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                TextField(
                  controller: nameCtl,
                  focusNode: nameFocus,
                  onChanged: (_) {
                    if (nameError) setSheetState(() => nameError = false);
                  },
                  decoration: InputDecoration(
                    labelText: 'Type Name *',
                    hintText: 'e.g. Standard, Deluxe, Suite',
                    border: const OutlineInputBorder(),
                    errorText: nameError ? 'Name is required' : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Rate + Capacity row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rateCtl,
                        focusNode: rateFocus,
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          if (rateError) setSheetState(() => rateError = false);
                          setSheetState(() {}); // rebuild hints
                        },
                        decoration: InputDecoration(
                          labelText: 'Rate/Night (opt.)',
                          border: const OutlineInputBorder(),
                          errorText: rateError ? 'Need at least 1 rate' : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: capacityCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Capacity',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Optional weekly + monthly rates
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rateWeekCtl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Rate/Week (opt.)',
                          hintText: (() {
                            final n = double.tryParse(rateCtl.text);
                            return n != null
                                ? '≈ ${(n * 7 * 0.9).toStringAsFixed(0)}'
                                : '7 nights × rate';
                          })(),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: rateMonthCtl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Rate/Month (opt.)',
                          hintText: (() {
                            final n = double.tryParse(rateCtl.text);
                            return n != null
                                ? '≈ ${(n * 30 * 0.75).toStringAsFixed(0)}'
                                : '30 nights × rate';
                          })(),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Leave blank to use nightly rate × periods',
                  style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                ),
                const SizedBox(height: 12),

                // Amenities
                TextField(
                  controller: amenitiesCtl,
                  decoration: const InputDecoration(
                    labelText: 'Amenities',
                    hintText: 'WiFi, TV, AC, Hot Water, Balcony',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                TextField(
                  controller: descCtl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),

                if (AppConfig.showMbeckGoFeatures) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publish to Cloud',
                        style:
                            TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        isPublished
                            ? 'Visible on Mbeck Go Marketplace'
                            : 'Only available for in-store booking',
                        style: const TextStyle(fontSize: 12)),
                    value: isPublished,
                    onChanged: (val) => setSheetState(() => isPublished = val),
                    activeColor: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.threed_rotation, color: AppColors.primaryGreen, size: 18),
                            SizedBox(width: 8),
                            Text(
                              '360° Virtual Tour Service',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGreen),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Landlords can order a premium 360° virtual tour session. We will bring our professional 360° cameras to shoot your property.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Virtual Tour service requested! Our team will contact you shortly to schedule the photoshoot.'),
                                backgroundColor: AppColors.primaryGreen,
                              ),
                            );
                          },
                          icon: const Icon(Icons.videocam_outlined, size: 14),
                          label: const Text('Request Photo Session', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Save button
                FilledButton.icon(
                  onPressed: () async {
                    final name = nameCtl.text.trim();
                    final rateNight = double.tryParse(rateCtl.text);
                    final rateWeek = double.tryParse(rateWeekCtl.text);
                    final rateMonth = double.tryParse(rateMonthCtl.text);

                    bool valid = true;
                    if (name.isEmpty) {
                      setSheetState(() => nameError = true);
                      if (valid) nameFocus.requestFocus();
                      valid = false;
                    }

                    if (rateNight == null && rateWeek == null && rateMonth == null) {
                      setSheetState(() => rateError = true);
                      if (valid) rateFocus.requestFocus();
                      valid = false;
                    }

                    if (!valid) return;

                    try {
                      int typeId;
                      if (isEditing) {
                        typeId = existing['id'] as int;
                        await LodgingService.updateRoomType(typeId, {
                          'name': name,
                          'rate_per_night': rateNight ?? 0,
                          'rate_per_week': rateWeek,
                          'rate_per_month': rateMonth,
                          'capacity': int.tryParse(capacityCtl.text) ?? 2,
                          'amenities': amenitiesCtl.text.trim(),
                          'description': descCtl.text.trim(),
                          'is_published': isPublished ? 1 : 0,
                        });
                      } else {
                        typeId = await LodgingService.createRoomType(
                          name: name,
                          ratePerNight: rateNight ?? 0,
                          ratePerWeek: rateWeek,
                          ratePerMonth: rateMonth,
                          capacity: int.tryParse(capacityCtl.text) ?? 2,
                          amenities: amenitiesCtl.text.trim().isNotEmpty
                              ? amenitiesCtl.text.trim()
                              : null,
                          description: descCtl.text.trim().isNotEmpty
                              ? descCtl.text.trim()
                              : null,
                          isPublished: isPublished,
                        );
                      }

                      // Save images
                      await LodgingService.saveRoomTypeImages(typeId, imagePaths);

                      _loadAll();
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: Text(isEditing ? 'Update Type' : 'Create Type'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== BATCH ADD DIALOG ==========

  void _showBatchAddDialog() {
    int? selectedTypeId;
    final floorCtl = TextEditingController();
    final fromCtl = TextEditingController();
    final toCtl = TextEditingController();
    final prefixCtl = TextEditingController(text: 'Room');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final from = int.tryParse(fromCtl.text);
          final to = int.tryParse(toCtl.text);
          final count = (from != null && to != null && to >= from) ? to - from + 1 : 0;
          final prefix = prefixCtl.text.trim().isNotEmpty ? prefixCtl.text.trim() : 'Room';

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Batch Add Rooms', style: AppTypography.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Create multiple rooms at once',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Room type dropdown
                  DropdownButtonFormField<int>(
                    value: selectedTypeId,
                    decoration: const InputDecoration(
                      labelText: 'Room Type *',
                      border: OutlineInputBorder(),
                    ),
                    items: _roomTypes.map((t) {
                      final rate = (t['rate_per_night'] as num?)?.toDouble() ?? 0;
                      return DropdownMenuItem<int>(
                        value: t['id'] as int,
                        child: Text('${t['name']} — KES ${rate.toStringAsFixed(0)}/night'),
                      );
                    }).toList(),
                    onChanged: (val) => setSheetState(() => selectedTypeId = val),
                  ),
                  const SizedBox(height: 12),

                  // Floor
                  TextField(
                    controller: floorCtl,
                    decoration: const InputDecoration(
                      labelText: 'Floor *',
                      hintText: 'e.g. 1, Ground, G',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // From + To row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fromCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'From Number *',
                            hintText: '101',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('to', style: TextStyle(fontSize: 14)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: toCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'To Number *',
                            hintText: '108',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Prefix
                  TextField(
                    controller: prefixCtl,
                    decoration: const InputDecoration(
                      labelText: 'Name Prefix',
                      hintText: 'Room, Apt, Unit',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Preview
                  if (count > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preview: $count rooms',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$prefix $from — $prefix $to',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          Text(
                            'Floor: ${floorCtl.text.isNotEmpty ? floorCtl.text : "—"}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Create button
                  FilledButton.icon(
                    onPressed: () async {
                      if (selectedTypeId == null ||
                          from == null ||
                          to == null ||
                          to < from ||
                          floorCtl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fill in all required fields')),
                        );
                        return;
                      }

                      if (count > 100) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Maximum 100 rooms per batch')),
                        );
                        return;
                      }

                      try {
                        final created = await LodgingService.batchCreateRooms(
                          roomTypeId: selectedTypeId!,
                          startNumber: from,
                          endNumber: to,
                          floor: floorCtl.text.trim(),
                          prefix: prefix,
                        );

                        _loadAll();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('✅ Created $created rooms')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(count > 0 ? 'Create $count Rooms' : 'Create Rooms'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ========== STATUS MENU ==========

  void _showStatusMenu(Map<String, dynamic> roomOriginal) {
    final room = Map<String, dynamic>.from(roomOriginal);
    final name = room['name'] as String? ?? 'Room';
    final status = room['status'] as String? ?? 'available';
    final isActive = (room['is_active'] as int?) == 1;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text(name, style: AppTypography.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Status: ${status.toUpperCase()}',
              style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (status != 'available')
              _statusAction(ctx, room, 'available', Icons.check_circle, 'Mark Available',
                  Colors.green),
            if (status != 'cleaning')
              _statusAction(
                  ctx, room, 'cleaning', Icons.cleaning_services, 'Mark Cleaning', Colors.orange),
            if (status != 'maintenance')
              _statusAction(
                  ctx, room, 'maintenance', Icons.build, 'Mark Maintenance', Colors.grey),
            const Divider(),
            ListTile(
              leading: Icon(isActive ? Icons.visibility_off : Icons.visibility,
                  color: isActive ? Colors.red : Colors.green),
              title: Text(isActive ? 'Deactivate Room' : 'Activate Room'),
              onTap: () async {
                await LodgingService.toggleRoomActive(room['id'] as int, !isActive);
                _loadAll();
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Room'),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Delete Room?'),
                    content: Text('Are you sure you want to delete $name?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await LodgingService.deleteRoom(room['id'] as int);
                  _loadAll();
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _statusAction(BuildContext ctx, Map<String, dynamic> room, String newStatus,
      IconData icon, String label, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      onTap: () async {
        await LodgingService.setRoomStatus(room['id'] as int, newStatus);
        _loadAll();
        if (ctx.mounted) Navigator.pop(ctx);
      },
    );
  }
}
