import 'package:flutter/material.dart';
import '../../services/lodging_service.dart';
import '../../theme/design_system.dart';
import '../../widgets/interactive_help_scroll.dart';
import '../../widgets/standard_app_bar.dart';
import 'room_management_screen.dart';
import 'package:intl/intl.dart';
import '../../../widgets/empty_state_guide.dart';
import 'package:url_launcher/url_launcher.dart';
import '../buyer_inbox_screen.dart';

/// Reservations Dashboard — the main tab screen for the Lodging module.
///
/// Shows a room status board (grid of rooms color-coded by status)
/// and provides check-in, check-out, and new reservation creation.
class ReservationsDashboardScreen extends StatefulWidget {
  const ReservationsDashboardScreen({super.key});

  @override
  State<ReservationsDashboardScreen> createState() =>
      _ReservationsDashboardScreenState();
}

class _ReservationsDashboardScreenState
    extends State<ReservationsDashboardScreen> {
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _upcoming = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final rooms = await LodgingService.getRoomStatusBoard();
      final upcoming = await LodgingService.getUpcomingReservations(limit: 5);
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _upcoming = upcoming;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available': return const Color(0xFF10B981);
      case 'occupied': return const Color(0xFF3B82F6);
      case 'cleaning': return const Color(0xFFF59E0B);
      case 'maintenance': return const Color(0xFF6B7280);
      default: return const Color(0xFF6B7280);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'available': return Icons.check;
      case 'occupied': return Icons.people;
      case 'cleaning': return Icons.refresh;
      case 'maintenance': return Icons.build;
      default: return Icons.help_outline;
    }
  }

  // ─── New Reservation ──────────────────────────────────────────

  void _showNewReservationDialog({int? preselectedRoomId}) {
    if (_rooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add rooms first')),
      );
      return;
    }

    final guestNameCtl = TextEditingController();
    final guestPhoneCtl = TextEditingController();
    final guestIdCtl = TextEditingController();
    final notesCtl = TextEditingController();

    // Only show available rooms
    final availableRooms = _rooms
        .where((r) =>
            r['status'] == 'available' || r['id'] == preselectedRoomId)
        .toList();

    if (availableRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available rooms')),
      );
      return;
    }

    int selectedRoomId =
        preselectedRoomId ?? (availableRooms.first['id'] as int);
    DateTime checkInDate = DateTime.now();

    // Billing mode: 'night' | 'week' | 'month' | 'custom'
    String billingMode = 'night';
    int nightCount = 1;
    int weekCount = 1;
    int monthCount = 1;
    int customMonths = 0;
    int customWeeks = 0;
    int customDays = 1;

    // Compute total days from current mode
    int totalDays(String mode) {
      switch (mode) {
        case 'week': return weekCount * 7;
        case 'month': return monthCount * 30;
        case 'custom': return customMonths * 30 + customWeeks * 7 + customDays;
        default: return nightCount;
      }
    }

    DateTime checkOutDate() =>
        checkInDate.add(Duration(days: totalDays(billingMode)));


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final selectedRoom = _rooms.firstWhere(
            (r) => r['id'] == selectedRoomId,
            orElse: () => availableRooms.first,
          );
          final rateNight =
              (selectedRoom['rate_per_night'] as num?)?.toDouble() ?? 0;
          final rateWeek =
              (selectedRoom['rate_per_week'] as num?)?.toDouble();
          final rateMonth =
              (selectedRoom['rate_per_month'] as num?)?.toDouble();

          // Effective total computed from billing mode
          double computeTotal() {
            switch (billingMode) {
              case 'week':
                return (rateWeek ?? rateNight * 7) * weekCount;
              case 'month':
                return (rateMonth ?? rateNight * 30) * monthCount;
              case 'custom':
                // Blended: months at monthly rate, weeks at weekly, days at nightly
                final mTotal = customMonths * (rateMonth ?? rateNight * 30);
                final wTotal = customWeeks * (rateWeek ?? rateNight * 7);
                final dTotal = customDays * rateNight;
                return mTotal + wTotal + dTotal;
              default: // 'night'
                return rateNight * nightCount;
            }
          }

          final total = computeTotal();
          final checkOut = checkOutDate();
          final dateFormat = DateFormat('EEE, MMM d');

          // Helpers
          Widget _intField({
            required int value,
            required String label,
            required int min,
            required int max,
            required ValueChanged<int> onChanged,
          }) {
            return Column(
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: value > min
                          ? () => setSheetState(() => onChanged(value - 1))
                          : null,
                      child: Container(
                        width: 28, height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.remove, size: 14),
                      ),
                    ),
                    Container(
                      width: 36,
                      alignment: Alignment.center,
                      child: Text('$value',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    InkWell(
                      onTap: value < max
                          ? () => setSheetState(() => onChanged(value + 1))
                          : null,
                      child: Container(
                        width: 28, height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.add, size: 14,
                            color: AppColors.primaryGreen),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

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
                  Text('New Reservation',
                      style: AppTypography.textTheme.titleLarge),
                  const SizedBox(height: 16),

                  // Guest name
                  TextField(
                    controller: guestNameCtl,
                    decoration: const InputDecoration(
                      labelText: 'Guest Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),

                  // Phone + ID
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: guestPhoneCtl,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone_outlined),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: guestIdCtl,
                          decoration: const InputDecoration(
                            labelText: 'ID Number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge_outlined),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Room dropdown
                  DropdownButtonFormField<int>(
                    value: selectedRoomId,
                    decoration: const InputDecoration(
                      labelText: 'Room *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                    ),
                    items: availableRooms.map((r) {
                      final floorLabel = r['floor'] != null &&
                              r['floor'].toString().isNotEmpty
                          ? ' · Fl ${r['floor']}'
                          : '';
                      final rRate =
                          (r['rate_per_night'] as num?)?.toDouble() ?? 0;
                      return DropdownMenuItem(
                        value: r['id'] as int,
                        child: Text(
                          '${r['name']}$floorLabel (${r['room_type']}) KES ${rRate.toStringAsFixed(0)}/n',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setSheetState(() => selectedRoomId = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Check-in date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: checkInDate,
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 1)),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setSheetState(() => checkInDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Check-in *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.login),
                      ),
                      child: Text(dateFormat.format(checkInDate)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Billing Mode ──────────────────────────────────
                  const Text('Billing Period',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  // Mode chips
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final mode in [
                        ('night', Icons.nights_stay, 'Nightly'),
                        ('week', Icons.date_range, 'Weekly'),
                        ('month', Icons.calendar_month, 'Monthly'),
                        ('custom', Icons.tune, 'Custom'),
                      ])
                        ChoiceChip(
                          avatar: Icon(mode.$2,
                              size: 14,
                              color: billingMode == mode.$1
                                  ? Colors.white
                                  : null),
                          label: Text(mode.$3),
                          selected: billingMode == mode.$1,
                          selectedColor: AppColors.primaryGreen,
                          labelStyle: TextStyle(
                            color: billingMode == mode.$1
                                ? Colors.white
                                : null,
                            fontSize: 12,
                          ),
                          onSelected: (_) =>
                              setSheetState(() => billingMode = mode.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Mode-specific duration picker
                  if (billingMode == 'night')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _intField(
                          value: nightCount,
                          label: 'Nights',
                          min: 1,
                          max: 365,
                          onChanged: (v) => nightCount = v,
                        ),
                      ],
                    ),

                  if (billingMode == 'week')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _intField(
                          value: weekCount,
                          label: 'Weeks',
                          min: 1,
                          max: 52,
                          onChanged: (v) => weekCount = v,
                        ),
                      ],
                    ),

                  if (billingMode == 'month')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _intField(
                          value: monthCount,
                          label: 'Months',
                          min: 1,
                          max: 24,
                          onChanged: (v) => monthCount = v,
                        ),
                      ],
                    ),

                  if (billingMode == 'custom')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _intField(
                          value: customMonths,
                          label: 'Months',
                          min: 0,
                          max: 24,
                          onChanged: (v) => customMonths = v,
                        ),
                        _intField(
                          value: customWeeks,
                          label: 'Weeks',
                          min: 0,
                          max: 51,
                          onChanged: (v) => customWeeks = v,
                        ),
                        _intField(
                          value: customDays,
                          label: 'Days',
                          min: 0,
                          max: 6,
                          onChanged: (v) => customDays = v,
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  // Live cost preview
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.primaryGreen.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_outlined,
                            color: AppColors.primaryGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Check-out: ${dateFormat.format(checkOut)}  (${totalDays(billingMode)} nights)',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                'Total: KES ${total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  TextField(
                    controller: notesCtl,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  FilledButton.icon(
                    onPressed: () async {
                      final name = guestNameCtl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Guest name is required')),
                        );
                        return;
                      }
                      final days = totalDays(billingMode);
                      if (days < 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Duration must be at least 1 night')),
                        );
                        return;
                      }

                      final computedCheckOut = checkOutDate();

                      // Check conflicts
                      final conflict =
                          await LodgingService.hasConflict(
                        roomId: selectedRoomId,
                        checkIn: checkInDate,
                        checkOut: computedCheckOut,
                      );

                      if (conflict && ctx.mounted) {
                        final proceed = await showDialog<bool>(
                          context: context,
                          builder: (dlg) => AlertDialog(
                            title: const Text('Date Conflict'),
                            content: const Text(
                                'This room has an overlapping reservation. Create anyway?'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dlg, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dlg, true),
                                  child:
                                      const Text('Create Anyway')),
                            ],
                          ),
                        );
                        if (proceed != true) return;
                      }

                      await LodgingService.createReservation(
                        roomId: selectedRoomId,
                        guestName: name,
                        guestPhone:
                            guestPhoneCtl.text.trim().isNotEmpty
                                ? guestPhoneCtl.text.trim()
                                : null,
                        guestIdNumber:
                            guestIdCtl.text.trim().isNotEmpty
                                ? guestIdCtl.text.trim()
                                : null,
                        checkInDate: checkInDate,
                        checkOutDate: computedCheckOut,
                        billingUnit: billingMode,
                        totalAmount: computeTotal(),
                        notes: notesCtl.text.trim().isNotEmpty
                            ? notesCtl.text.trim()
                            : null,
                      );

                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAll();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Reservation created for $name'),
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Create Reservation'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      guestNameCtl.dispose();
      guestPhoneCtl.dispose();
      guestIdCtl.dispose();
      notesCtl.dispose();
    });
  }
  // ─── Room Tap Actions ─────────────────────────────────────────

  void _onRoomTap(Map<String, dynamic> room) {
    final status = room['status'] as String? ?? 'available';
    final resStatus = room['res_status'] as String?;

    if (status == 'occupied' && resStatus == 'checked_in') {
      _showOccupiedRoomSheet(room);
    } else if (status == 'available') {
      _showNewReservationDialog(preselectedRoomId: room['id'] as int);
    } else if (status == 'cleaning') {
      _showCleaningSheet(room);
    } else {
      // maintenance or other
      _showMaintenanceSheet(room);
    }
  }

  void _showOccupiedRoomSheet(Map<String, dynamic> room) {
    final guestName = room['guest_name'] as String? ?? 'Guest';
    final checkIn = room['actual_check_in'] as int?;
    final checkOut = room['check_out_date'] as int?;
    final resId = room['reservation_id'] as int?;
    final total = (room['res_total'] as num?)?.toDouble() ?? 0;
    final dateFormat = DateFormat('MMM d, h:mm a');
    final dayFormat = DateFormat('EEE, MMM d');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(room['name'] ?? 'Room',
                          style: AppTypography.textTheme.titleLarge),
                      Text(guestName,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 15)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'OCCUPIED',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (checkIn != null)
              _infoRow(Icons.login, 'Checked in: ${dateFormat.format(DateTime.fromMillisecondsSinceEpoch(checkIn))}'),
            if (checkOut != null)
              _infoRow(Icons.logout, 'Expected out: ${dayFormat.format(DateTime.fromMillisecondsSinceEpoch(checkOut))}'),
            if (room['guest_phone'] != null)
              _infoRow(Icons.phone_outlined, room['guest_phone']),
            _infoRow(Icons.attach_money, 'Total: KES ${total.toStringAsFixed(0)}'),
            const Divider(height: 24),
            if (resId != null)
              FilledButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dlg) => AlertDialog(
                      title: const Text('Check Out?'),
                      content: Text(
                          'Check out $guestName from ${room['name']}? This will record the stay as a sale.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(dlg, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(dlg, true),
                            child: const Text('Check Out')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await LodgingService.checkOut(resId);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadAll();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '$guestName checked out — KES ${total.toStringAsFixed(0)} recorded'),
                          backgroundColor: AppColors.primaryGreen,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Check Out'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCleaningSheet(Map<String, dynamic> room) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${room['name']} — Cleaning',
                style: AppTypography.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('This room is being cleaned after a guest checked out.'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                await LodgingService.markRoomClean(room['id'] as int);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAll();
              },
              icon: const Icon(Icons.check),
              label: const Text('Mark as Clean & Available'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaintenanceSheet(Map<String, dynamic> room) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${room['name']} — Maintenance',
                style: AppTypography.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('This room is under maintenance.'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                await LodgingService.markRoomClean(room['id'] as int);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAll();
              },
              icon: const Icon(Icons.check),
              label: const Text('Mark as Available'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  // ─── Upcoming Reservations ────────────────────────────────────

  void _showUpcomingSheet(Map<String, dynamic> res) {
    final status = res['status'] as String? ?? 'pending';
    final resId = res['id'] as int;
    final checkIn = DateTime.fromMillisecondsSinceEpoch(
        res['check_in_date'] as int);
    final checkOut = DateTime.fromMillisecondsSinceEpoch(
        res['check_out_date'] as int);
    final dayFormat = DateFormat('EEE, MMM d');
    final total = (res['total_amount'] as num?)?.toDouble() ?? 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(res['guest_name'] ?? 'Guest',
                style: AppTypography.textTheme.titleLarge),
            Text('${res['room_name']} (${res['room_type']})',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            _infoRow(Icons.login,
                'Check-in: ${dayFormat.format(checkIn)}'),
            _infoRow(Icons.logout,
                'Check-out: ${dayFormat.format(checkOut)}'),
            _infoRow(Icons.nights_stay,
                '${res['nights']} night${(res['nights'] as int) != 1 ? 's' : ''}'),
            _infoRow(Icons.attach_money,
                'Total: KES ${total.toStringAsFixed(0)}'),
            if (res['notes'] != null &&
                res['notes'].toString().isNotEmpty)
              _infoRow(Icons.note_outlined, res['notes']),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status == 'pending')
                  ActionChip(
                    avatar: const Icon(Icons.check, size: 16, color: Colors.green),
                    label: const Text('Confirm',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                    backgroundColor: Colors.green.withOpacity(0.1),
                    side: BorderSide(color: Colors.green.withOpacity(0.3)),
                    onPressed: () async {
                      await LodgingService.confirmReservation(resId);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAll();
                    },
                  ),
                if (status == 'pending' || status == 'confirmed')
                  ActionChip(
                    avatar: const Icon(Icons.login, size: 16, color: Colors.blue),
                    label: const Text('Check In',
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    side: BorderSide(color: Colors.blue.withOpacity(0.3)),
                    onPressed: () async {
                      await LodgingService.checkIn(resId);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAll();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${res['guest_name']} checked into ${res['room_name']}'),
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        );
                      }
                    },
                  ),
                if (status != 'cancelled')
                  ActionChip(
                    avatar: const Icon(Icons.cancel, size: 16, color: Colors.red),
                    label: const Text('Cancel',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    backgroundColor: Colors.red.withOpacity(0.1),
                    side: BorderSide(color: Colors.red.withOpacity(0.3)),
                    onPressed: () async {
                      await LodgingService.cancelReservation(resId);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAll();
                    },
                  ),
                ActionChip(
                  avatar: const Icon(Icons.phone, size: 16, color: Colors.teal),
                  label: const Text('Call Guest',
                      style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600)),
                  backgroundColor: Colors.teal.withOpacity(0.1),
                  side: BorderSide(color: Colors.teal.withOpacity(0.3)),
                  onPressed: () async {
                    final phone = res['guest_phone'] as String?;
                    if (phone != null && phone.isNotEmpty) {
                      final url = Uri.parse('tel:$phone');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No phone number registered for this guest')),
                      );
                    }
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.deepPurple),
                  label: const Text('Open Chat',
                      style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600)),
                  backgroundColor: Colors.deepPurple.withOpacity(0.1),
                  side: BorderSide(color: Colors.deepPurple.withOpacity(0.3)),
                  onPressed: () {
                    final clientId = res['client_id'] as String?;
                    if (clientId != null && clientId.isNotEmpty) {
                      Navigator.pop(ctx); // Close sheet
                      final isCloud = clientId.contains('-') || (res['source'] == 'cloud');
                      BuyerInboxScreen.openConversation(
                        context,
                        clientId: clientId,
                        displayId: res['guest_name'] ?? 'Guest',
                        isCloud: isCloud,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No chat ID available for this guest')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableCount = _rooms.where((r) => r['status'] == 'available').length;
    final occupiedCount = _rooms.where((r) => r['status'] == 'occupied').length;
    final cleaningCount = _rooms.where((r) => r['status'] == 'cleaning').length;

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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF6B7280), size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text('Lodging', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.meeting_room_outlined, color: Color(0xFF6B7280), size: 22),
                      tooltip: 'Manage Rooms',
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomManagementScreen())).then((_) => _loadAll());
                      },
                    ),
                    IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF9CA3AF), size: 22), onPressed: _loadAll),
                  ],
                ),
              ),
            ),
          ),
          // ─── Content ─────────────────────
          Expanded(
            child: _isLoading
                ? AppSkeleton.screen()
                : _rooms.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadAll,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          children: [
                            // Stat pills
                            SizedBox(
                              height: 62,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _buildStatPill('Available', availableCount, const Color(0xFF10B981)),
                                  const SizedBox(width: 8),
                                  _buildStatPill('Occupied', occupiedCount, const Color(0xFF3B82F6)),
                                  const SizedBox(width: 8),
                                  _buildStatPill('Cleaning', cleaningCount, const Color(0xFFF59E0B)),
                                  const SizedBox(width: 8),
                                  _buildStatPill('Total', _rooms.length, const Color(0xFF6366F1)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Room Status Board
                            const Text('ROOM STATUS BOARD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF6B7280), letterSpacing: 1.5)),
                            const SizedBox(height: 8),
                            ..._buildFloorSections(),

                            // Upcoming reservations
                            if (_upcoming.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              const Text('UPCOMING RESERVATIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF6B7280), letterSpacing: 1.5)),
                              const SizedBox(height: 8),
                              ..._upcoming.map((r) => _buildUpcomingCard(r)),
                            ],
                          ],
                        ),
                      ),
          ),
        ],
      ),
      const InteractiveHelpScroll(contextKey: 'lodging_reservations'),
      ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "lodging_reservations_fab",
        onPressed: () => _showNewReservationDialog(),
        backgroundColor: const Color(0xFF111827),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  List<Widget> _buildFloorSections() {
    final Map<String, List<Map<String, dynamic>>> byFloor = {};
    for (final room in _rooms) {
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
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(
          '${_floorLabel(floor).toUpperCase()} • ${rooms.length} ROOMS',
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF9CA3AF), letterSpacing: 1.2),
        ),
      ));
      widgets.add(GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        childAspectRatio: 0.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: rooms.map((r) => _buildRoomTile(r)).toList(),
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

  Widget _buildStatPill(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color, height: 1.1)),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color.withOpacity(0.8), height: 1.2)),
        ],
      ),
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> room) {
    final status = room['status'] as String? ?? 'available';
    final name = room['name'] as String? ?? 'Room';
    final guestName = room['guest_name'] as String?;
    final sc = _statusColor(status);

    return GestureDetector(
      onTap: () => _onRoomTap(room),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: status == 'maintenance' ? const Color(0xFFF9FAFB) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sc.withOpacity(0.25)),
          boxShadow: status == 'maintenance' ? null : [BoxShadow(color: sc.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: sc.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(_statusIcon(status), size: 14, color: sc),
            ),
            const SizedBox(height: 4),
            Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF111827), decoration: status == 'maintenance' ? TextDecoration.lineThrough : null), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            if (guestName != null)
              Text(guestName, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: sc), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)
            else
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: sc.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                  child: Text(status.toUpperCase(), style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: sc, letterSpacing: 0.3), overflow: TextOverflow.ellipsis),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingCard(Map<String, dynamic> res) {
    final checkIn = DateTime.fromMillisecondsSinceEpoch(res['check_in_date'] as int);
    final dayFormat = DateFormat('EEE, MMM d');
    final status = res['status'] as String? ?? 'pending';
    final nights = res['nights'] as int? ?? 1;
    final statusColor = status == 'confirmed' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return GestureDetector(
      onTap: () => _showUpcomingSheet(res),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.event_note, color: statusColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(res['guest_name'] ?? 'Guest', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                  const SizedBox(height: 2),
                  Text('${res['room_name']} • ${dayFormat.format(checkIn)} • $nights night${nights != 1 ? 's' : ''}', style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(status.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateGuide(
      icon: Icons.hotel_outlined,
      title: 'No rooms configured',
      subtitle: 'Set up your rooms or accommodation units first, then reservations will appear on this board',
      actionLabel: 'Set Up Rooms',
      onAction: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomManagementScreen())).then((_) => _loadAll());
      },
    );
  }
}
