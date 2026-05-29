import 'package:flutter/material.dart';
import '../../services/services_service.dart';
import '../../theme/design_system.dart';
import '../../widgets/standard_app_bar.dart';
import '../../widgets/interactive_help_scroll.dart';

/// Staff Management screen for the Services module.
///
/// Features:
/// - List all staff with role, contact info, and availability
/// - Add/edit staff
/// - Toggle active/inactive
/// - Set working days and hours
class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  List<Map<String, dynamic>> _staff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    try {
      final staff = await ServicesService.getStaff(activeOnly: false);
      if (mounted) setState(() { _staff = staff; _isLoading = false; });
    } catch (e) {
      debugPrint('Error loading staff: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const _dayLabels = {
    '1': 'Mon', '2': 'Tue', '3': 'Wed',
    '4': 'Thu', '5': 'Fri', '6': 'Sat', '7': 'Sun',
  };

  String _formatDays(String? days) {
    if (days == null || days.isEmpty) return 'Not set';
    return days.split(',').map((d) => _dayLabels[d.trim()] ?? d.trim()).join(', ');
  }

  void _showStaffDialog({Map<String, dynamic>? existing}) {
    final isEditing = existing != null;
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final roleController = TextEditingController(text: existing?['role'] ?? '');
    final phoneController = TextEditingController(text: existing?['phone'] ?? '');
    final emailController = TextEditingController(text: existing?['email'] ?? '');
    final startController = TextEditingController(
        text: existing?['work_hours_start'] ?? '09:00');
    final endController = TextEditingController(
        text: existing?['work_hours_end'] ?? '17:00');

    // Parse available days into a Set
    Set<String> selectedDays = {};
    final daysStr = existing?['available_days'] as String? ?? '1,2,3,4,5';
    for (final d in daysStr.split(',')) {
      if (d.trim().isNotEmpty) selectedDays.add(d.trim());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(isEditing ? 'Edit Staff' : 'Add Staff',
                    style: AppTypography.textTheme.titleLarge),
                const SizedBox(height: 16),

                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: roleController,
                  decoration: const InputDecoration(
                    labelText: 'Role / Title',
                    hintText: 'e.g., Barber, Masseuse, Stylist',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneController,
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
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Working days
                Text('Working Days',
                    style: AppTypography.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _dayLabels.entries.map((entry) {
                    final isSelected = selectedDays.contains(entry.key);
                    return FilterChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      onSelected: (selected) {
                        setSheetState(() {
                          if (selected) {
                            selectedDays.add(entry.key);
                          } else {
                            selectedDays.remove(entry.key);
                          }
                        });
                      },
                      selectedColor: AppColors.primaryGreen.withOpacity(0.2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Working hours
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startController,
                        decoration: const InputDecoration(
                          labelText: 'Start Time',
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: '09:00',
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('to'),
                    ),
                    Expanded(
                      child: TextField(
                        controller: endController,
                        decoration: const InputDecoration(
                          labelText: 'End Time',
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: '17:00',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Name is required')),
                      );
                      return;
                    }

                    final daysStr = (selectedDays.toList()..sort()).join(',');

                    if (isEditing) {
                      await ServicesService.updateStaff(existing['id'] as int, {
                        'name': name,
                        'role': roleController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'email': emailController.text.trim(),
                        'available_days': daysStr,
                        'work_hours_start': startController.text.trim(),
                        'work_hours_end': endController.text.trim(),
                      });
                    } else {
                      await ServicesService.createStaff(
                        name: name,
                        role: roleController.text.trim(),
                        phone: phoneController.text.trim(),
                        email: emailController.text.trim(),
                        availableDays: daysStr,
                        workStart: startController.text.trim(),
                        workEnd: endController.text.trim(),
                      );
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadStaff();
                  },
                  icon: const Icon(Icons.save),
                  label: Text(isEditing ? 'Update' : 'Add Staff'),
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
    ).then((_) {
      nameController.dispose();
      roleController.dispose();
      phoneController.dispose();
      emailController.dispose();
      startController.dispose();
      endController.dispose();
    });
  }

  Color _getAvatarGradientStart(String name) {
    final colors = [
      const Color(0xFF6366F1), // indigo
      const Color(0xFF8B5CF6), // violet
      const Color(0xFF3B82F6), // blue
      const Color(0xFFF59E0B), // amber
      const Color(0xFFEF4444), // red
      const Color(0xFF10B981), // emerald
    ];
    return colors[name.length % colors.length];
  }
  Color _getAvatarGradientEnd(String name) {
    final colors = [
      const Color(0xFF9333EA), // purple
      const Color(0xFF6366F1), // indigo
      const Color(0xFF0EA5E9), // sky
      const Color(0xFFF97316), // orange
      const Color(0xFFEC4899), // pink
      const Color(0xFF14B8A6), // teal
    ];
    return colors[name.length % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _staff.where((s) => (s['active'] as int?) == 1).length;
    final inactiveCount = _staff.length - activeCount;

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
                  // Title row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B7280), size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text('Team', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: -0.5)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _showStaffDialog(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_add, size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text('Invite', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Stat cards
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
                    child: SizedBox(
                      height: 80,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildStatPill('Total Staff', _staff.length, const Color(0xFF4F46E5), Icons.people),
                          const SizedBox(width: 10),
                          _buildStatPill('Active', activeCount, const Color(0xFF10B981), Icons.check_circle_outline),
                          const SizedBox(width: 10),
                          _buildStatPill('Inactive', inactiveCount, const Color(0xFFF59E0B), Icons.access_time),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ─── Search ──────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: const Row(
                children: [
                  Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search team members...',
                        hintStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ─── Content ─────────────────────
          Expanded(
            child: _isLoading
                ? AppSkeleton.screen()
                : _staff.isEmpty
                    ? _buildEmptyState()
                    : _buildList(),
          ),
        ],
      ),
      const InteractiveHelpScroll(contextKey: 'services_staff'),
      ],
      ),
    );
  }

  Widget _buildStatPill(String label, int value, Color color, IconData icon) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const Spacer(),
          Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF111827), height: 1)),
          Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('No team members yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text('Tap Invite to add your first staff member', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadStaff,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
        itemCount: _staff.length,
        itemBuilder: (ctx, index) => _buildStaffTile(_staff[index]),
      ),
    );
  }

  Widget _buildStaffTile(Map<String, dynamic> staff) {
    final isActive = (staff['active'] as int?) == 1;
    final name = staff['name'] as String? ?? 'Unknown';
    final role = staff['role'] as String? ?? '';
    final phone = staff['phone'] as String? ?? '';
    final hours = '${staff['work_hours_start'] ?? '09:00'} - ${staff['work_hours_end'] ?? '17:00'}';

    return GestureDetector(
      onTap: () => _showStaffDialog(existing: staff),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? const Color(0xFFF3F4F6) : const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(
          children: [
            // Avatar with online dot
            Stack(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isActive
                        ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_getAvatarGradientStart(name), _getAvatarGradientEnd(name)])
                        : null,
                    color: isActive ? null : const Color(0xFFE2E8F0),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(name),
                      style: TextStyle(
                        color: isActive ? Colors.white : const Color(0xFF64748B),
                        fontSize: 17, fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800,
                            color: isActive ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                            decoration: isActive ? null : TextDecoration.lineThrough,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (role.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF4F46E5).withOpacity(0.08) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isActive ? const Color(0xFF4F46E5).withOpacity(0.15) : const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5,
                              color: isActive ? const Color(0xFF4338CA) : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(phone, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                    ),
                  const SizedBox(height: 4),
                  // Schedule pill
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time, size: 10, color: isActive ? const Color(0xFF10B981) : const Color(0xFF6B7280)),
                            const SizedBox(width: 3),
                            Text(
                              hours,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isActive ? const Color(0xFF10B981) : const Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isActive ? '• Active' : '• Inactive',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[400]),
              onSelected: (action) {
                if (action == 'edit') {
                  _showStaffDialog(existing: staff);
                } else if (action == 'toggle') {
                  ServicesService.toggleStaffActive(staff['id'] as int, !isActive);
                  _loadStaff();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'toggle', child: Text(isActive ? 'Deactivate' : 'Activate')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
