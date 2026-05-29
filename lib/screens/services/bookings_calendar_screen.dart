import 'package:flutter/material.dart';
import '../../../widgets/empty_state_guide.dart';
import '../../db/db_provider.dart';
import '../../services/services_service.dart';
import '../../theme/design_system.dart';
import '../../widgets/standard_app_bar.dart';
import '../../widgets/interactive_help_scroll.dart';
import 'service_catalog_screen.dart';
import 'staff_management_screen.dart';
import 'package:intl/intl.dart';

/// Bookings Calendar Screen for providers to view and manage appointments.
///
/// Features:
/// - Day view with date navigation
/// - Manual booking creation with service/staff/time picker
/// - Booking status lifecycle (pending → confirmed → completed)
/// - Revenue tracking per day
/// - Staff filter
class BookingsCalendarScreen extends StatefulWidget {
  const BookingsCalendarScreen({super.key});

  @override
  State<BookingsCalendarScreen> createState() => _BookingsCalendarScreenState();
}

class _BookingsCalendarScreenState extends State<BookingsCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _staff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final services = await ServicesService.getServices();
      final staff = await ServicesService.getStaff();
      if (mounted) {
        setState(() {
          _services = services;
          _staff = staff;
        });
      }
      await _loadBookingsForDate();
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBookingsForDate() async {
    final bookings = await ServicesService.getBookingsForDate(_selectedDate);
    if (mounted) {
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    }
  }

  void _changeDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    _loadBookingsForDate();
  }

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadBookingsForDate();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'completed': return Colors.blue;
      case 'cancelled': return Colors.red;
      case 'no_show': return Colors.grey;
      default: return Colors.grey;
    }
  }

  // ─── New Booking ────────────────────────────────────────────────

  void _showNewBookingDialog() {
    if (_services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add services first before creating bookings')),
      );
      return;
    }

    final customerNameCtl = TextEditingController();
    final customerPhoneCtl = TextEditingController();
    final notesCtl = TextEditingController();
    int? selectedServiceId = _services.first['id'] as int;
    int? selectedStaffId;
    TimeOfDay selectedTime = TimeOfDay.now();
    List<Map<String, dynamic>> _availableAddons = [];
    List<Map<String, dynamic>> _selectedAddons = [];

    // Fetch addons when service changes
    Future<void> fetchAddons(int serviceId, Function setS) async {
      final db = await DbProvider.db;
      final addons = await db.query('services_addons',
          where: 'parent_service_id = ? AND is_active = 1',
          whereArgs: [serviceId]);
      setS(() => _availableAddons = List.from(addons));
    }

    // pre-load addons for the first service
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final db = await DbProvider.db;
      final addons = await db.query('services_addons',
          where: 'parent_service_id = ? AND is_active = 1',
          whereArgs: [selectedServiceId]);
      if (mounted) {
        // will update on next rebuild — the StatefulBuilder handles this
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final selectedService = _services.firstWhere(
            (s) => s['id'] == selectedServiceId,
            orElse: () => _services.first,
          );
          final baseDurationMin = (selectedService['duration_minutes'] as int?) ?? 30;
          final bufferMin = (selectedService['buffer_minutes'] as int?) ?? 0;
          final addonExtraMin = _selectedAddons.fold<int>(0,
              (sum, a) => sum + ((a['duration_added_minutes'] as int?) ?? 0));
          final totalDurationMin = baseDurationMin + addonExtraMin;
          final basePrice = (selectedService['price'] as num?)?.toDouble() ?? 0;
          final addonPriceSum = _selectedAddons.fold<double>(0,
              (sum, a) => sum + ((a['price_added'] as num?)?.toDouble() ?? 0));
          final totalPrice = basePrice + addonPriceSum;

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('New Booking',
                      style: AppTypography.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMM d').format(_selectedDate),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  // Customer name
                  TextField(
                    controller: customerNameCtl,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),

                  // Customer phone
                  TextField(
                    controller: customerPhoneCtl,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),

                  // Service dropdown
                  DropdownButtonFormField<int>(
                    value: selectedServiceId,
                    decoration: const InputDecoration(
                      labelText: 'Service *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.spa_outlined),
                    ),
                    items: _services.map((s) {
                      final p = (s['price'] as num?)?.toDouble() ?? 0;
                      return DropdownMenuItem(
                        value: s['id'] as int,
                        child: Text(
                          '${s['name']} — KES ${p.toStringAsFixed(0)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setSheetState(() {
                        selectedServiceId = v;
                        _selectedAddons = [];
                      });
                      if (v != null) fetchAddons(v, setSheetState);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Staff dropdown (optional)
                  if (_staff.isNotEmpty)
                    DropdownButtonFormField<int?>(
                      value: selectedStaffId,
                      decoration: const InputDecoration(
                        labelText: 'Staff (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Any available')),
                        ..._staff.map((s) => DropdownMenuItem(
                              value: s['id'] as int,
                              child: Text(
                                  '${s['name']}${s['role'] != null && s['role'] != '' ? ' (${s['role']})' : ''}'),
                            )),
                      ],
                      onChanged: (v) =>
                          setSheetState(() => selectedStaffId = v),
                    ),
                  if (_staff.isNotEmpty) const SizedBox(height: 12),

                  // Time picker
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setSheetState(() => selectedTime = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Appointment Time *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.schedule),
                      ),
                      child: Text(selectedTime.format(context)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Duration: ${totalDurationMin}min (+${bufferMin}min buffer)  •  KES ${totalPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(height: 12),

                  // ─── Addons picker ───────────────
                  if (_availableAddons.isNotEmpty) ...[
                    Text('Add-ons', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: _availableAddons.map((addon) {
                        final isSelected = _selectedAddons.any((a) => a['id'] == addon['id']);
                        return FilterChip(
                          label: Text(
                            '${addon['name']} (+KES ${(addon['price_added'] as num).toStringAsFixed(0)}, +${addon['duration_added_minutes']}min)',
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: isSelected,
                          onSelected: (sel) => setSheetState(() {
                            if (sel) {
                              _selectedAddons.add(addon);
                            } else {
                              _selectedAddons.removeWhere((a) => a['id'] == addon['id']);
                            }
                          }),
                          selectedColor: AppColors.primaryGreen.withOpacity(0.15),
                          checkmarkColor: AppColors.primaryGreen,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

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
                      final name = customerNameCtl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Customer name is required')),
                        );
                        return;
                      }

                      // Compute start/end incl. buffer
                      final startTime = DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );
                      // endTime = base duration + addon extra; buffer reduces scheduling space but is NOT billed
                      final endTime = startTime.add(Duration(minutes: totalDurationMin + bufferMin));

                      // Check for conflicts
                      final hasConflict = await ServicesService.hasConflict(
                        serviceId: selectedServiceId!,
                        staffId: selectedStaffId,
                        startTime: startTime,
                        endTime: endTime,
                      );

                      if (hasConflict && ctx.mounted) {
                        final proceed = await showDialog<bool>(
                          context: context,
                          builder: (dlg) => AlertDialog(
                            title: const Text('Time Conflict'),
                            content: const Text(
                                'This slot overlaps with an existing booking. Create anyway?'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dlg, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dlg, true),
                                  child: const Text('Create Anyway')),
                            ],
                          ),
                        );
                        if (proceed != true) return;
                      }

                      await ServicesService.createBooking(
                        serviceId: selectedServiceId!,
                        staffId: selectedStaffId,
                        customerName: name,
                        customerPhone:
                            customerPhoneCtl.text.trim().isNotEmpty
                                ? customerPhoneCtl.text.trim()
                                : null,
                        startTime: startTime,
                        endTime: endTime,
                        notes: notesCtl.text.trim().isNotEmpty
                            ? notesCtl.text.trim()
                            : null,
                        selectedAddons: List.from(_selectedAddons),
                      );

                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadBookingsForDate();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Booking created for $name'),
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Create Booking'),
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
    ).then((_) {
      customerNameCtl.dispose();
      customerPhoneCtl.dispose();
      notesCtl.dispose();
    });
  }

  // ─── Booking Details ────────────────────────────────────────────

  void _showBookingDetails(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? 'pending';
    final startTime =
        DateTime.fromMillisecondsSinceEpoch(booking['start_time'] as int);
    final endTime =
        DateTime.fromMillisecondsSinceEpoch(booking['end_time'] as int);
    final timeFormat = DateFormat('h:mm a');
    final serviceName = booking['service_name'] as String? ?? 'Service';
    final staffName = booking['staff_name'] as String?;
    final price =
        (booking['service_price'] as num?)?.toDouble() ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking['customer_name'] ?? 'Unknown',
                          style: AppTypography.textTheme.titleLarge),
                      Text(serviceName,
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info rows
            _infoRow(Icons.schedule,
                '${timeFormat.format(startTime)} — ${timeFormat.format(endTime)}'),
            if (staffName != null)
              _infoRow(Icons.person_outline, 'Staff: $staffName'),
            if (booking['customer_phone'] != null)
              _infoRow(Icons.phone_outlined, booking['customer_phone']),
            _infoRow(Icons.attach_money,
                'KES ${price.toStringAsFixed(0)}'),
            if (booking['notes'] != null &&
                booking['notes'].toString().isNotEmpty)
              _infoRow(Icons.note_outlined, booking['notes']),

            const Divider(height: 24),

            // Status actions
            Text('Update Status:',
                style: AppTypography.textTheme.labelLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status != 'confirmed' && status != 'completed')
                  _statusChip(booking['id'] as int, 'confirmed',
                      'Confirm', Colors.green, Icons.check_circle),
                if (status != 'completed')
                  _statusChip(booking['id'] as int, 'completed',
                      'Complete & Bill', Colors.blue, Icons.paid),
                if (status != 'cancelled' && status != 'completed')
                  _statusChip(booking['id'] as int, 'cancelled',
                      'Cancel', Colors.red, Icons.cancel),
                if (status != 'no_show' && status != 'completed')
                  _statusChip(booking['id'] as int, 'no_show',
                      'No Show', Colors.grey, Icons.person_off),
              ],
            ),
            const SizedBox(height: 16),

            // Delete
            if (status == 'cancelled' || status == 'no_show')
              TextButton.icon(
                onPressed: () async {
                  await ServicesService.deleteBooking(booking['id'] as int);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadBookingsForDate();
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Delete Booking',
                    style: TextStyle(color: Colors.red)),
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
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(int bookingId, String newStatus, String label,
      Color color, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      onPressed: () async {
        try {
          await ServicesService.updateBookingStatus(bookingId, newStatus);

          if (mounted) {
            Navigator.pop(context);
            _loadBookingsForDate();

            if (newStatus == 'completed') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Booking completed & sale recorded!'),
                  backgroundColor: AppColors.primaryGreen,
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red),
            );
          }
        }
      },
    );
  }

  // ─── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final confirmedCount = _bookings.where((b) => b['status'] == 'confirmed').length;
    final pendingCount = _bookings.where((b) => b['status'] == 'pending').length;
    final doneCount = _bookings.where((b) => b['status'] == 'completed').length;

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
                    padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B7280), size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text('Bookings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5)),
                        const Spacer(),
                        // Nav icons
                        _navIcon(Icons.spa_outlined, 'Catalog', () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceCatalogScreen())).then((_) => _loadAll());
                        }),
                        _navIcon(Icons.people_outline, 'Staff', () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffManagementScreen())).then((_) => _loadAll());
                        }),
                        _navIcon(Icons.calendar_month, 'Date', _showDatePicker),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ─── Day Strip ────────────────
                  SizedBox(
                    height: 68,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: 14,
                      itemBuilder: (ctx, i) {
                        final date = DateTime.now().subtract(Duration(days: 3 - i));
                        final isSel = DateUtils.isSameDay(date, _selectedDate);
                        final isT = DateUtils.isSameDay(date, DateTime.now());
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedDate = date);
                            _loadBookingsForDate();
                          },
                          child: Container(
                            width: 46,
                            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF0D9488) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isSel ? const Color(0xFF0D9488) : isT ? const Color(0xFF0D9488).withOpacity(0.4) : const Color(0xFFE5E7EB)),
                              boxShadow: isSel ? [BoxShadow(color: const Color(0xFF0D9488).withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))] : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('E').format(date).substring(0, 2),
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isSel ? Colors.white.withOpacity(0.7) : const Color(0xFF9CA3AF)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${date.day}',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isSel ? Colors.white : const Color(0xFF111827)),
                                ),
                                if (isT && !isSel)
                                  Container(width: 4, height: 4, margin: const EdgeInsets.only(top: 2), decoration: const BoxDecoration(color: Color(0xFF0D9488), shape: BoxShape.circle)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          // ─── Stats ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                _buildStatPill('Total', _bookings.length, const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                _buildStatPill('Confirmed', confirmedCount, const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _buildStatPill('Pending', pendingCount, const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _buildStatPill('Done', doneCount, const Color(0xFF6366F1)),
              ],
            ),
          ),
          // ─── Bookings List ───────────────
          Expanded(
            child: _isLoading
                ? AppSkeleton.screen()
                : _bookings.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadBookingsForDate,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _bookings.length,
                          itemBuilder: (ctx, i) => _buildBookingCard(_bookings[i]),
                        ),
                      ),
          ),
        ],
      ),
      const InteractiveHelpScroll(contextKey: 'services_bookings'),
      ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "services_bookings_fab",
        onPressed: _showNewBookingDialog,
        backgroundColor: const Color(0xFF111827),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _navIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF6B7280), size: 22),
        tooltip: tooltip,
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildStatPill(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyStateGuide(
      icon: Icons.event_available,
      title: 'No bookings for this day',
      subtitle: 'Appointments will appear here once customers book or you create one manually',
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final startTime = DateTime.fromMillisecondsSinceEpoch(booking['start_time'] as int);
    final endTime = DateTime.fromMillisecondsSinceEpoch(booking['end_time'] as int);
    final timeFormat = DateFormat('h:mm a');
    final status = booking['status'] as String? ?? 'pending';
    final serviceName = booking['service_name'] as String? ?? 'Service';
    final staffName = booking['staff_name'] as String?;
    final price = (booking['service_price'] as num?)?.toDouble() ?? 0;
    final statusColor = _getStatusColor(status);

    return GestureDetector(
      onTap: () => _showBookingDetails(booking),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Status bar
            Container(width: 4, color: statusColor),
            const SizedBox(width: 12),
            // Time column
            SizedBox(
              width: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    Text(timeFormat.format(startTime), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Icon(Icons.arrow_downward, size: 10, color: Colors.grey[300]),
                    ),
                    Text(timeFormat.format(endTime), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                  ],
                ),
              ),
            ),
            // Divider
            Container(width: 1, height: 50, color: const Color(0xFFF3F4F6)),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            booking['customer_name'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(serviceName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (staffName != null) ...[
                          Icon(Icons.person_outline, size: 10, color: Colors.grey[400]),
                          const SizedBox(width: 2),
                          Text(staffName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey[400])),
                          const SizedBox(width: 8),
                        ],
                        Text('KES ${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
