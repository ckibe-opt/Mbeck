import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/services_service.dart';
import '../../theme/design_system.dart';
import '../../widgets/standard_app_bar.dart';
import '../../widgets/interactive_help_scroll.dart';

class ShiftSchedulingScreen extends StatefulWidget {
  const ShiftSchedulingScreen({super.key});

  @override
  State<ShiftSchedulingScreen> createState() => _ShiftSchedulingScreenState();
}

class _ShiftSchedulingScreenState extends State<ShiftSchedulingScreen> {
  DateTime _activeDate = DateTime.now();
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _staffList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final staff = await ServicesService.getStaff(activeOnly: true);
      final shifts = await ServicesService.getShiftsForDate(_activeDate);
      if (mounted) {
        setState(() {
          _staffList = staff;
          _shifts = shifts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading shift data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onDateTabSelected(DateTime date) {
    setState(() {
      _activeDate = date;
    });
    _loadData();
  }

  Future<void> _showAddShiftBottomSheet() async {
    int? selectedStaffId;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
    bool isRecurring = false;
    
    // Set initial staff if available
    if (_staffList.isNotEmpty) {
      selectedStaffId = _staffList.first['id'] as int;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // For backdrop blur effect container
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Schedule Shift',
                style: AppTypography.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Staff Dropdown
              Text('Staff Member', style: AppTypography.textTheme.labelLarge),
              const SizedBox(height: 8),
              if (_staffList.isEmpty)
                const Text('No active staff available.', style: TextStyle(color: Colors.red))
              else
                DropdownButtonFormField<int>(
                  initialValue: selectedStaffId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                    isDense: true,
                  ),
                  items: _staffList.map((s) {
                    return DropdownMenuItem<int>(
                      value: s['id'] as int,
                      child: Text(s['name'] as String),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setSheetState(() => selectedStaffId = val);
                  },
                ),
              const SizedBox(height: 16),

              // Time Selectors
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start Time', style: AppTypography.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: ctx,
                              initialTime: startTime,
                            );
                            if (time != null) setSheetState(() => startTime = time);
                          },
                          icon: const Icon(Icons.access_time),
                          label: Text(startTime.format(ctx)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('End Time', style: AppTypography.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: ctx,
                              initialTime: endTime,
                            );
                            if (time != null) setSheetState(() => endTime = time);
                          },
                          icon: const Icon(Icons.access_time_filled),
                          label: Text(endTime.format(ctx)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Recurring Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Recurring Shift', style: AppTypography.textTheme.bodyLarge),
                subtitle: Text('Repeat this shift weekly', style: AppTypography.textTheme.bodySmall),
                activeThumbColor: AppColors.primaryGreen,
                value: isRecurring,
                onChanged: (val) => setSheetState(() => isRecurring = val),
              ),
              const SizedBox(height: 24),

              // Save Button
              FilledButton.icon(
                onPressed: () async {
                  if (selectedStaffId == null) return;
                  
                  // Combine date & time
                  final startDt = DateTime(
                    _activeDate.year, _activeDate.month, _activeDate.day,
                    startTime.hour, startTime.minute,
                  );
                  final endDt = DateTime(
                    _activeDate.year, _activeDate.month, _activeDate.day,
                    endTime.hour, endTime.minute,
                  );

                  // Validate time
                  if (endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('End time must be after start time.')),
                    );
                    return;
                  }

                  // Determine status based on time
                  final now = DateTime.now();
                  String status = 'upcoming';
                  if (startDt.isBefore(now) && endDt.isAfter(now)) {
                    status = 'active';
                  } else if (endDt.isBefore(now)) {
                    status = 'completed';
                  }

                  try {
                    await ServicesService.createShift(
                      staffId: selectedStaffId!,
                      startTime: startDt,
                      endTime: endDt,
                      status: status,
                      isRecurring: isRecurring,
                    );

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadData();
                  } catch(e) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to save shift: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Publish Shift'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardAppBar(
        title: 'Shift Scheduling',
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
          _buildDayNavigationRibbon(),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _shifts.isEmpty
                    ? _buildEmptyState()
                    : _buildTimeline(),
          ),
        ],
      ),
      const InteractiveHelpScroll(contextKey: 'services_shifts'),
      ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'shift_fab',
        backgroundColor: AppColors.primaryGreen,
        onPressed: _showAddShiftBottomSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDayNavigationRibbon() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    return Container(
      height: 60,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          _buildDateTab('Yesterday', yesterday),
          const SizedBox(width: 8),
          _buildDateTab('Today', today),
          const SizedBox(width: 8),
          _buildDateTab('Tomorrow', tomorrow),
        ],
      ),
    );
  }

  Widget _buildDateTab(String label, DateTime date) {
    // Normalize dates to remove time parts for correct comparison
    final activeNormalized = DateTime(_activeDate.year, _activeDate.month, _activeDate.day);
    final isSelected = activeNormalized == date;
    
    return InkWell(
      onTap: () => _onDateTabSelected(date),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No shifts scheduled',
                style: AppTypography.textTheme.titleMedium
                    ?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            const Text(
              'Tap the + button to schedule staff for this day.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _shifts.length,
        itemBuilder: (ctx, index) {
          final shift = _shifts[index];
          return _buildShiftCard(shift);
        },
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    final status = shift['status'] as String? ?? 'upcoming';
    final isActive = status == 'active';
    final isCompleted = status == 'completed';

    final startTime = DateTime.fromMillisecondsSinceEpoch(shift['start_time'] as int);
    final endTime = DateTime.fromMillisecondsSinceEpoch(shift['end_time'] as int);
    final staffName = shift['staff_name'] as String? ?? 'Unknown';
    final staffRole = shift['staff_role'] as String? ?? '';
    final isRecurring = (shift['is_recurring'] as int?) == 1;

    final timeFormat = DateFormat.jm();
    final timeRange = '${timeFormat.format(startTime)} - ${timeFormat.format(endTime)}';

    // Styling based on status
    final cardOpacity = (isActive || isCompleted) ? 1.0 : 0.75;
    final accentColor = isActive ? AppColors.primaryGreen : AppColors.gray400;

    return Opacity(
      opacity: cardOpacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: accentColor, width: 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    timeRange,
                    style: AppTypography.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusTag(status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey.shade200,
                    child: Text(
                      staffName.isNotEmpty ? staffName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staffName,
                          style: AppTypography.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (staffRole.isNotEmpty)
                          Text(
                            staffRole,
                            style: AppTypography.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isRecurring)
                    Icon(Icons.repeat, size: 20, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'active':
        bg = AppColors.primaryGreen.withValues(alpha: 0.1);
        fg = AppColors.primaryGreen;
        label = 'Active';
        break;
      case 'upcoming':
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
        label = 'Upcoming';
        break;
      case 'completed':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        label = 'Completed';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTypography.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
