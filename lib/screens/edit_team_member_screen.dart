import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../models/shop_member.dart';
import '../models/permissions.dart';
import '../services/onboarding_service.dart';
import '../widgets/role_card.dart';
import '../widgets/standard_app_bar.dart';
import '../theme/design_system.dart';

/// Edit Team Member Screen - Change role and permissions
class EditTeamMemberScreen extends StatefulWidget {
  final ShopMember member;

  const EditTeamMemberScreen({
    super.key,
    required this.member,
  });

  @override
  State<EditTeamMemberScreen> createState() => _EditTeamMemberScreenState();
}

class _EditTeamMemberScreenState extends State<EditTeamMemberScreen> with SingleTickerProviderStateMixin {
  late String _selectedRole;
  late TabController _tabController;
  bool _isLoading = false;
  bool _hasChanges = false;
  List<String> _availableRoles = [];

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.member.role;
    _tabController = TabController(length: 2, vsync: this);
    _loadModules();
  }

  Future<void> _loadModules() async {
    final modules = await OnboardingService.getSelectedModules();
    if (mounted) {
      setState(() {
        _availableRoles = RolePresets.getRolesForModule(modules);
        // Ensure current role is always included even if module changed
        if (!_availableRoles.contains(_selectedRole)) {
          _availableRoles.insert(0, _selectedRole);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardAppBar(
        title: 'Edit ${widget.member.userName}',
      ),
      body: Column(
        children: [
          // Member info header
          _buildMemberHeader(),

          // Tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryGreen,
              unselectedLabelColor: AppColors.gray600,
              indicatorColor: AppColors.primaryGreen,
              tabs: const [
                Tab(text: 'Role'),
                Tab(text: 'Details'),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRoleTab(),
                _buildDetailsTab(),
              ],
            ),
          ),

          // Save button
          if (_hasChanges) _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildMemberHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(
            color: AppColors.gray200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primaryGreen.withOpacity(0.2),
            child: Text(
              widget.member.userName.isNotEmpty 
                  ? widget.member.userName[0].toUpperCase() 
                  : '?',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.member.userName,
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                RoleBadge(role: _selectedRole),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Change Role',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Select a new role to update permissions automatically',
          style: AppTypography.textTheme.bodyMedium!.copyWith(
            color: AppColors.gray600,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Current role indicator
        if (_selectedRole != widget.member.role)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.warning),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Role will change from ${RolePresets.getRoleDisplayName(widget.member.role)} '
                    'to ${RolePresets.getRoleDisplayName(_selectedRole)}',
                    style: AppTypography.textTheme.bodyMedium!.copyWith(
                      color: AppColors.gray700,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Role selection cards
        ..._availableRoles.map((role) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: RoleCard(
              role: role,
              isSelected: _selectedRole == role,
              onTap: () {
                setState(() {
                  _selectedRole = role;
                  _hasChanges = _selectedRole != widget.member.role;
                });
              },
              showPermissions: true,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _buildDetailItem(
          'Name',
          widget.member.userName,
          Icons.person_outline,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildDetailItem(
          'Device ID',
          widget.member.deviceId,
          Icons.smartphone,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildDetailItem(
          'Joined',
          _formatDate(widget.member.joinedAt),
          Icons.calendar_today,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildDetailItem(
          'Last Active',
          widget.member.lastActiveAt != null
              ? _formatDate(widget.member.lastActiveAt!)
              : 'Never',
          Icons.access_time,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildDetailItem(
          'Status',
          widget.member.isActive ? 'Active' : 'Inactive',
          Icons.circle,
          valueColor: widget.member.isActive ? AppColors.success : AppColors.gray400,
        ),

        const SizedBox(height: AppSpacing.xl),
        const Divider(),
        const SizedBox(height: AppSpacing.lg),

        // Current permissions list
        Text(
          'Current Permissions',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...RolePresets.getAllPermissions().map((permission) {
          final hasPermission = widget.member.hasPermission(permission);
          return ListTile(
            dense: true,
            leading: Icon(
              hasPermission ? Icons.check_circle : Icons.cancel,
              color: hasPermission ? AppColors.success : AppColors.gray300,
              size: 20,
            ),
            title: Text(
              RolePresets.getPermissionDisplayName(permission),
              style: TextStyle(
                color: hasPermission ? AppColors.gray900 : AppColors.gray400,
                fontSize: 14,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDetailItem(
    String label,
    String value, 
    IconData icon,
    {Color? valueColor}
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gray600),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.textTheme.labelSmall!.copyWith(
                    color: AppColors.gray600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.gray900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final newPermissions = RolePresets.getPresetForRole(_selectedRole);

      // Update in database
      await supabase
          .from('shop_members')
          .update({
            'role': _selectedRole,
            'permissions': jsonEncode(newPermissions),
          })
          .eq('id', widget.member.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${widget.member.userName}\'s role updated to ${RolePresets.getRoleDisplayName(_selectedRole)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );

        // Go back with success
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating role: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
