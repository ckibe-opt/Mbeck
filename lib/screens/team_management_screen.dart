import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_member.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../widgets/role_card.dart';
import '../widgets/standard_app_bar.dart';
import '../theme/design_system.dart';
import '../models/permissions.dart';
import 'add_team_member_screen.dart';
import 'edit_team_member_screen.dart';
import 'data_share_screen.dart';
import 'onboarding/starter_pack_screen.dart';
import 'paywall_screen.dart';
import '../services/revenuecat_service.dart';
import '../models/shop.dart';

/// Team Management Screen - Manage staff members and roles
class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  List<ShopMember> _allMembers = [];
  ShopMember? _currentMember;
  bool _isLoading = true;

  // Access control state
  bool _isCheckingAccess = true;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final member = await AuthService.getCurrentMember();
      final isManager = member?.role.toUpperCase() == 'MANAGER';
      final isOwner = member?.role.toUpperCase() == 'OWNER';
      final hasPermission = member?.hasPermission(Permissions.viewTeamMembers) ?? false;
      final hasAccess = hasPermission || isManager || isOwner;
      
      if (mounted) {
        setState(() {
          _hasAccess = hasAccess;
          _isCheckingAccess = false;
        });
        if (!hasAccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Access Denied: You do not have permission to view Team Members."),
              backgroundColor: AppColors.danger,
            ),
          );
          Navigator.pop(context);
        } else {
          _loadTeamMembers();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingAccess = false;
          _hasAccess = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error checking access: $e"), backgroundColor: AppColors.danger),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadTeamMembers() async {
    setState(() => _isLoading = true);

    try {
      // Get current shop ID and member
      final shopId = await DeviceService.getShopId();
      _currentMember = await AuthService.getCurrentMember();

      if (shopId == null) { // ignore: unnecessary_null_comparison
        setState(() {
          _allMembers = [];
          _isLoading = false;
        });
        return;
      }

      // Fetch all members from Supabase
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('shop_members')
          .select()
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .order('joined_at', ascending: true);

      _allMembers = (response as List)
          .map((json) => ShopMember.fromMap(json))
          .toList();
      
      debugPrint('✅ Loaded ${_allMembers.length} team members');
    } catch (e) {
      debugPrint('❌ Error loading team members: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading team: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      _allMembers = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Group members by role for organized display
  Map<String, List<ShopMember>> _groupMembersByRole() {
    final Map<String, List<ShopMember>> grouped = {};
    
    for (final member in _allMembers) {
      final role = member.role;
      if (!grouped.containsKey(role)) {
        grouped[role] = [];
      }
      grouped[role]!.add(member);
    }
    
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return Scaffold(
        appBar: StandardAppBar(title: 'Team Members'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasAccess) {
      return Scaffold(
        appBar: StandardAppBar(title: 'Team Members'),
        body: const Center(child: Text("Access Denied")),
      );
    }

    // Check permission OR role (fallback for existing members with stale permission blobs)
    final isManager = _currentMember?.role.toUpperCase() == 'MANAGER';
    final hasPermission = _currentMember?.hasPermission(Permissions.addTeamMember) ?? false;
    final canManageTeam = hasPermission || isManager;

    return Scaffold(
      appBar: StandardAppBar(
        title: 'Team Members',
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined),
            tooltip: 'Quick Setup (Starter Pack)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StarterPackScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildTeamList(),
      floatingActionButton: canManageTeam
          ? FloatingActionButton.extended(
              heroTag: "team_fab",
              onPressed: _addTeamMember,
              backgroundColor: AppColors.primaryGreen,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Member'),
            )
          : null,
    );
  }

  Widget _buildTeamList() {
    if (_allMembers.isEmpty) {
      return _buildEmptyState();
    }

    final groupedMembers = _groupMembersByRole();
    
    // Sort roles: Owner first, then by hierarchy
    final sortedRoles = groupedMembers.keys.toList()
      ..sort((a, b) {
        const roleOrder = {
          'OWNER': 0,
          'MANAGER': 1,
          'ADMIN': 1,
          'SHIFT_SUPERVISOR': 2,
          'SUPERVISOR': 2,
          'INVENTORY_MANAGER': 3,
          'CASHIER': 4,
          'STAFF': 4,
          'STOCKER': 5,
          'CUSTOM': 6,
        };
        return (roleOrder[a.toUpperCase()] ?? 99) - (roleOrder[b.toUpperCase()] ?? 99);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: sortedRoles.length,
      itemBuilder: (context, index) {
        final role = sortedRoles[index];
        final members = groupedMembers[role]!;
        
        return _buildRoleSection(role, members);
      },
    );
  }

  Widget _buildRoleSection(String role, List<ShopMember> members) {
    final displayName = RolePresets.getRoleDisplayName(role);
    final icon = RolePresets.getRoleIcon(role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role header
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            top: AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$displayName (${members.length})',
                style: AppTypography.textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray800,
                ),
              ),
            ],
          ),
        ),

        // Member cards
        ...members.map((member) => _buildMemberCard(member)),

        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildMemberCard(ShopMember member) {
    final isCurrentUser = member.deviceId == _currentMember?.deviceId;
    final canEdit = _canEditMember(member);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
          child: Text(
            member.userName.isNotEmpty ? member.userName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.userName,
                style: AppTypography.textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  'You',
                  style: AppTypography.textTheme.labelSmall!.copyWith(
                    color: AppColors.gray600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              member.deviceId, // Use deviceId as identifier since no phone/email
              style: AppTypography.textTheme.bodyMedium!.copyWith(
                color: AppColors.gray600,
              ),
            ),
            const SizedBox(height: 6),
            RoleBadge(role: member.role, compact: true),
          ],
        ),
        trailing: canEdit
            ? IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showMemberOptions(member),
              )
            : null,
        isThreeLine: true,
      ),
    );
  }

  Widget _buildEmptyState() {
    // Check permission OR role (fallback)
    final isManager = _currentMember?.role.toUpperCase() == 'MANAGER';
    final hasPermission = _currentMember?.hasPermission(Permissions.addTeamMember) ?? false;
    final canAddMember = hasPermission || isManager;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 80,
              color: AppColors.gray400,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Team Members Yet',
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.gray700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add staff members to help run your shop',
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.bodyMedium!.copyWith(
                color: AppColors.gray600,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(height: AppSpacing.xl),
            if (canAddMember)
              ElevatedButton.icon(
                onPressed: _addTeamMember,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
                icon: const Icon(Icons.person_add),
                label: const Text('Add First Team Member'),
              ),
          ],
        ),
      ),
    );
  }

  bool _canEditMember(ShopMember member) {
    if (_currentMember == null) return false;
    
    // Owner can edit anyone
    if (_currentMember!.isOwner) return true;
    
    // Cannot edit yourself
    if (member.deviceId == _currentMember!.deviceId) return false;
    
    // Check if the current user has the 'manage_permissions' capability
    if (_currentMember!.hasPermission(Permissions.managePermissions)) {
      // Cannot edit the Owner
      if (member.isOwner || member.role.toUpperCase() == 'OWNER') return false;
      
      // Managers shouldn't downgrade or edit other Managers/Admins
      if (member.role.toUpperCase() == 'MANAGER' || 
          member.role.toUpperCase() == 'ADMIN') {
        return false;
      }
      
      // Can edit any other subordinate role
      return true;
    }
    
    return false;
  }

  void _showMemberOptions(ShopMember member) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share, color: AppColors.primaryGreen),
              title: const Text('Share Data with this Device'),
              subtitle: const Text('Send all shop data over WiFi'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DataShareScreen(isReceiveMode: false),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Role & Permissions'),
              onTap: () {
                Navigator.pop(context);
                _editMember(member);
              },
            ),
            if (_currentMember?.hasPermission(Permissions.removeTeamMember) ?? false) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_remove, color: AppColors.errorText),
                title: const Text('Remove from Team', style: TextStyle(color: AppColors.errorText)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmRemoveMember(member);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addTeamMember() async {
    final shop = await AuthService.getCurrentShop();
    if (shop != null) {
      final isEnterpriseSub = await RevenueCatService.isEnterpriseSubscriber();
      final isProSub = await RevenueCatService.isProSubscriber();

      int limit = shop.maxStaffMembers;
      if (isEnterpriseSub) {
        limit = -1; // Unlimited
      } else if (isProSub) {
        if (limit == 1) {
          limit = 3;
        }
      }

      final limitReached = (limit != -1) && (_allMembers.length >= limit);
      if (limitReached) {
        if (mounted) {
          PaywallScreen.show(context, featureName: 'Staff Limit Reached (Max $limit members)');
        }
        return;
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddTeamMemberScreen(),
      ),
    ).then((_) => _loadTeamMembers()); // Reload after adding
  }

  void _editMember(ShopMember member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditTeamMemberScreen(member: member),
      ),
    ).then((success) {
      if (success == true) {
        _loadTeamMembers(); // Reload if changes were saved
      }
    });
  }

  void _confirmRemoveMember(ShopMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Team Member?'),
        content: Text(
          'Are you sure you want to remove ${member.userName} from your team? They will lose access to this shop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeMember(member);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.errorText),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(ShopMember member) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Soft delete - set is_active to false instead of deleting
      await supabase
          .from('shop_members')
          .update({'is_active': false})
          .eq('id', member.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${member.userName} removed from team'),
            backgroundColor: AppColors.success,
          ),
        );
      }

      // Reload team to reflect changes
      await _loadTeamMembers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing member: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}
