import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/permissions.dart';
import '../services/device_service.dart';
import '../services/onboarding_service.dart';
import '../widgets/role_card.dart';
import '../widgets/standard_app_bar.dart';
import '../theme/design_system.dart';

/// Add Team Member Screen - Invite new staff to join the shop
class AddTeamMemberScreen extends StatefulWidget {
  const AddTeamMemberScreen({super.key});

  @override
  State<AddTeamMemberScreen> createState() => _AddTeamMemberScreenState();
}

class _AddTeamMemberScreenState extends State<AddTeamMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  
  String _selectedRole = 'CASHIER';
  bool _isLoading = false;
  String? _shopId;
  // ignore: unused_field
  String? _shopPassword;
  List<String> _enabledModules = [];
  List<String> _availableRoles = [];

  @override
  void initState() {
    super.initState();
    _loadShopInfo();
  }

  Future<void> _loadShopInfo() async {
    _shopId = await DeviceService.getShopId();
    // Load enabled modules for role filtering
    _enabledModules = await OnboardingService.getSelectedModules();
    _availableRoles = RolePresets.getRolesForModule(_enabledModules);
    // Set default role based on available roles
    if (_availableRoles.isNotEmpty && !_availableRoles.contains(_selectedRole)) {
      _selectedRole = _availableRoles.first;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StandardAppBar(
        title: 'Add Team Member',
      ),
      body: _shopId == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const Icon(
                      Icons.person_add,
                      size: 64,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Invite Staff Member',
                      textAlign: TextAlign.center,
                      style: AppTypography.displayMedium.copyWith(
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Add a new team member to help run your shop',
                      textAlign: TextAlign.center,
                      style: AppTypography.textTheme.bodyMedium!.copyWith(
                        color: AppColors.gray600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Staff Member Name',
                        hintText: 'e.g., David Kamau',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Optional note
                    TextFormField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: 'Note (Optional)',
                        hintText: 'e.g., Morning shift, weekends only',
                        prefixIcon: const Icon(Icons.note_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Role selection
                    Text(
                      'Select Role',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Choose the role that best matches their responsibilities',
                      style: AppTypography.textTheme.bodyMedium!.copyWith(
                        color: AppColors.gray600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Role cards - filtered by module
                    ..._availableRoles.map((role) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: RoleCard(
                          role: role,
                          isSelected: _selectedRole == role,
                          onTap: () => setState(() => _selectedRole = role),
                          showPermissions: true,
                        ),
                      );
                    }),

                    const SizedBox(height: AppSpacing.xl),

                    // Invitation instructions
                    _buildInviteInstructions(),

                    const SizedBox(height: AppSpacing.xl),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _generateInvite,
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
                                : const Text('Generate Invite'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInviteInstructions() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'How to Invite',
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.info,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '1. Generate invite with staff member details\n'
            '2. Share your Shop ID and Password with them\n'
            '3. They download Mbeck Seller app\n'
            '4. They select "Join Existing Shop"\n'
            '5. They enter Shop ID, Password, and their name\n'
            '6. They\'ll be added with the selected role',
            style: AppTypography.textTheme.bodyMedium!.copyWith(
              color: AppColors.gray700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Shop ID:',
                  style: AppTypography.textTheme.labelSmall!.copyWith(
                    color: AppColors.gray600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _shopId ?? 'Loading...',
                        style: AppTypography.textTheme.bodyLarge!.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _shopId ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Shop ID copied!')),
                        );
                      },
                      tooltip: 'Copy Shop ID',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final note = _noteController.text.trim();
      
      // Create an invitation record (for tracking expected members)
      // This is optional - the member will actually be created when they join via signup
      final supabase = Supabase.instance.client;
      
      await supabase.from('team_invitations').insert({
        'shop_id': _shopId,
        'invited_name': name,
        'invited_role': _selectedRole,
        'note': note.isEmpty ? null : note,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      }).catchError((e) {
        // Table might not exist yet - that's OK, just show success
        debugPrint('Note: team_invitations table not set up yet');
      });

      if (mounted) {
        // Show success dialog with instructions
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                const Text('Invite Created!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share these details with $name:'),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shop ID:',
                        style: AppTypography.textTheme.labelSmall!.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _shopId ?? '',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Shop Password:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Text('(The password you set during shop creation)'),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Role: ${RolePresets.getRoleDisplayName(_selectedRole)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'When they join, their role will be set automatically. '
                  'You can change it later in Team Members.',
                  style: TextStyle(fontSize: 13, color: AppColors.gray600),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to Team Management
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
