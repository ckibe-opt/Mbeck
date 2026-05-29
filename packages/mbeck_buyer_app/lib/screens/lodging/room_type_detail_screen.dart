import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/shop_session_provider.dart';
import 'package:mbeck_shared/mbeck_shared.dart';



/// Hotel-booking-style detail screen for a room type.
class RoomTypeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> roomType;

  const RoomTypeDetailScreen({super.key, required this.roomType});

  @override
  State<RoomTypeDetailScreen> createState() => _RoomTypeDetailScreenState();
}

class _RoomTypeDetailScreenState extends State<RoomTypeDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<Map<String, dynamic>> _rooms = [];
  bool _loadingRooms = true;
  bool _isBooking = false;

  Map<String, dynamic> get _type => widget.roomType;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    final session = context.read<ShopSessionProvider>();
    final api = session.api;
    if (api == null) return;
    try {
      final typeId = (_type['id'] as num?)?.toInt();
      if (typeId != null) {
        final rooms = await api.getLodgingRooms(typeId: typeId);
        if (mounted) setState(() { _rooms = rooms; _loadingRooms = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _loadingRooms = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _type['name'] as String? ?? 'Room Type';
    final description = _type['description'] as String? ?? '';
    final capacity = (_type['capacity'] as num?)?.toInt() ?? 2;
    final rate = (_type['rate_per_night'] as num?)?.toDouble() ?? 0;
    final amenities = _type['amenities'] as String? ?? '';
    final images = _type['images'] as List<dynamic>? ?? [];
    final availableRooms = (_type['available_rooms'] as num?)?.toInt() ?? 0;
    final totalRooms = (_type['total_rooms'] as num?)?.toInt() ?? 0;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── Image Carousel ─────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 300,
              child: Stack(
                children: [
                  if (images.isNotEmpty)
                    PageView.builder(
                      controller: _pageController,
                      onPageChanged: (page) => setState(() => _currentPage = page),
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final url = images[index]['url'] as String?;
                        if (url != null) {
                          return Image.network(url, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(name));
                        }
                        return _buildPlaceholder(name);
                      },
                    )
                  else
                    _buildPlaceholder(name),

                  // Top gradient for status bar
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                        ),
                      ),
                    ),
                  ),

                  // Back button
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),

                  // Page indicator
                  if (images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (i) {
                          final isActive = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isActive ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white : Colors.white54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),

                  // Image counter
                  if (images.length > 1)
                    Positioned(
                      bottom: 16, right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${_currentPage + 1}/${images.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ─── Room Type Info ────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name & Rate
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(name,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(CurrencyFormatter.formatWithCurrency(rate),
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.primaryColor)),
                          Text('/night', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Quick stats row
                  Row(
                    children: [
                      _buildStatChip(Icons.people, 'Up to $capacity guests'),
                      const SizedBox(width: 12),
                      _buildStatChip(
                        availableRooms > 0 ? Icons.check_circle : Icons.cancel,
                        '$availableRooms of $totalRooms available',
                        color: availableRooms > 0 ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Host Trust Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundImage: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=1000&auto=format&fit=crop'),
                          radius: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hosted by Keja Oasis',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF222222)),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.stars, color: Colors.amber, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Superhost • ★ 4.9 Rating',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Description
                  if (description.isNotEmpty) ...[
                    Text('About this room',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                    const SizedBox(height: 8),
                    Text(description,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5)),
                    const SizedBox(height: 24),
                  ],

                  // Amenities
                  if (amenities.isNotEmpty) ...[
                    Text('Amenities',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: amenities.split(',').map((a) {
                        final amenity = a.trim();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00897B).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF00897B).withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_amenityIcon(amenity), size: 18, color: const Color(0xFF00897B)),
                              const SizedBox(width: 8),
                              Text(amenity,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF00695C), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Divider
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 16),

                  // Available Rooms header
                  Text('Available Rooms',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                  const SizedBox(height: 4),
                  Text('Individual rooms of this type',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ─── Room List ────────────────
          if (_loadingRooms)
            const SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )),
            )
          else if (_rooms.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.hotel_outlined, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('No rooms of this type', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildRoomTile(_rooms[index]),
                  childCount: _rooms.length,
                ),
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            onPressed: (_rooms.any((r) => r['status'] == 'available') && !_isBooking)
                ? () => _showBookingSheet()
                : null,
            icon: _isBooking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.hotel),
            label: Text(_isBooking ? 'Reserving…' : 'Reserve a Room'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> room) {
    final name = room['name'] as String? ?? 'Room';
    final floor = room['floor'] as String? ?? '';
    final status = room['status'] as String? ?? 'available';
    final isAvailable = status == 'available';
    final roomId = (room['id'] as num?)?.toInt();
    final statusColor = isAvailable ? Colors.green : (status == 'occupied' ? Colors.red : Colors.orange);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isAvailable ? Icons.door_front_door : Icons.do_not_disturb,
              color: statusColor, size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                if (floor.isNotEmpty)
                  Text('Floor \$floor', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (isAvailable && roomId != null)
            TextButton(
              onPressed: _isBooking ? null : () => _showBookingSheet(preselectedRoomId: roomId.toString()),
              child: const Text('Book'),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status[0].toUpperCase() + status.substring(1),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Booking Sheet ──────────────────────────────────────────────────────────

  Future<void> _showBookingSheet({String? preselectedRoomId}) async {
    final rate = (_type['rate_per_night'] as num?)?.toDouble() ?? 0;
    final availableRooms = _rooms.where((r) => r['status'] == 'available').toList();
    if (availableRooms.isEmpty) return;

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime checkIn = DateTime.now().add(const Duration(days: 1));
    DateTime checkOut = DateTime.now().add(const Duration(days: 2));
    String? selectedRoomId = preselectedRoomId ?? availableRooms.first['id']?.toString();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final nights = checkOut.difference(checkIn).inDays.clamp(1, 365);
            final total = rate * nights;

            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hotel, size: 22),
                        const SizedBox(width: 10),
                        Text('Reserve Room', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    if (availableRooms.length > 1) ...[
                      const Text('Select Room', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedRoomId,
                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                        items: availableRooms.map((r) {
                          final rId = r['id']?.toString() ?? '';
                          return DropdownMenuItem(value: rId, child: Text(r['name'] as String? ?? 'Room $rId'));
                        }).toList(),
                        onChanged: (v) => setSheetState(() => selectedRoomId = v),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      children: [
                        Expanded(child: _datePicker(ctx, 'Check-in', checkIn, (d) => setSheetState(() { checkIn = d; if (!checkOut.isAfter(checkIn)) checkOut = checkIn.add(const Duration(days: 1)); }))),
                        const SizedBox(width: 12),
                        Expanded(child: _datePicker(ctx, 'Check-out', checkOut, (d) => setSheetState(() => checkOut = d))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$nights night${nights > 1 ? "s" : ""}', style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text(CurrencyFormatter.formatWithCurrency(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00695C))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Guest Name *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Special requests', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes_outlined)),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter your name')));
                            return;
                          }
                          if (selectedRoomId == null) return;
                          Navigator.pop(ctx);
                          await _submitReservation(
                            roomId: selectedRoomId!,
                            guestName: nameCtrl.text.trim(),
                            guestPhone: phoneCtrl.text.trim(),
                            checkIn: checkIn,
                            checkOut: checkOut,
                            notes: notesCtrl.text.trim(),
                            total: total,
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Confirm Reservation', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _datePicker(BuildContext ctx, String label, DateTime date, ValueChanged<DateTime> onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: ctx,
          initialDate: date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text('\${date.day}/\${date.month}/\${date.year}'),
      ),
    );
  }

  Future<void> _submitReservation({
    required String roomId,
    required String guestName,
    required String guestPhone,
    required DateTime checkIn,
    required DateTime checkOut,
    required String notes,
    required double total,
  }) async {
    setState(() => _isBooking = true);
    final session = context.read<ShopSessionProvider>();
    final api = session.api;
    if (api == null) { setState(() => _isBooking = false); return; }
    try {
      String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}';
      final result = await api.lodgingBook(
        roomId: roomId,
        guestName: guestName,
        guestPhone: guestPhone,
        checkInDate: fmt(checkIn),
        checkOutDate: fmt(checkOut),
        notes: notes,
      );
      if (mounted) {
        // Cloud bookings are PENDING; LAN bookings are instant
        final isCloud = result['source'] == 'cloud' ||
            (result['message'] as String? ?? '').contains('confirm');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(isCloud ? Icons.schedule : Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(
                isCloud
                    ? (result['message'] as String? ?? 'Reservation request submitted!')
                    : 'Room reserved! Total: ${CurrencyFormatter.formatWithCurrency(total)}',
              )),
            ]),
            backgroundColor: isCloud ? Colors.blue.shade700 : Colors.green.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
        await _loadRooms();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reservation failed: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }


  Widget _buildStatChip(IconData icon, String text, {Color? color}) {
    final c = color ?? Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF26A69A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hotel, size: 64, color: Colors.white.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 16)),
          ],
        ),
      ),
    );
  }

  IconData _amenityIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'wifi': return Icons.wifi;
      case 'tv': return Icons.tv;
      case 'ac': case 'air conditioning': return Icons.ac_unit;
      case 'mini-bar': case 'minibar': return Icons.local_bar;
      case 'balcony': return Icons.balcony;
      case 'pool': case 'swimming pool': return Icons.pool;
      case 'parking': return Icons.local_parking;
      case 'breakfast': return Icons.free_breakfast;
      case 'gym': case 'fitness': return Icons.fitness_center;
      case 'spa': return Icons.spa;
      case 'laundry': return Icons.local_laundry_service;
      case 'safe': return Icons.lock;
      case 'desk': case 'workspace': return Icons.desk;
      default: return Icons.check_circle_outline;
    }
  }
}
