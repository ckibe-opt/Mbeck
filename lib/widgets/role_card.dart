import 'package:flutter/material.dart';
import '../models/permissions.dart';
import '../theme/design_system.dart';

/// RoleCard - Beautiful card for role selection
/// Used in Add Team Member and Edit Member screens
class RoleCard extends StatelessWidget {
  final String role;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showPermissions;

  const RoleCard({
    super.key,
    required this.role,
    this.isSelected = false,
    required this.onTap,
    this.showPermissions = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = RolePresets.getRoleDisplayName(role);
    final description = RolePresets.getRoleDescription(role);
    final icon = RolePresets.getRoleIcon(role);
    final permissions = RolePresets.getPresetForRole(role);

    // Get top 3 permissions for this role
    final List<String> keyPermissions = _getKeyPermissions(role);

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(
          color: isSelected ? AppColors.primaryGreen : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: Icon + Name
              Row(
                children: [
                  Text(
                    icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      displayName.toUpperCase(),
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.primaryGreen : AppColors.gray900,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.primaryGreen,
                      size: 24,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Description
              Text(
                description,
                style: AppTypography.textTheme.bodyMedium!.copyWith(
                  color: AppColors.gray600,
                ),
              ),

              if (showPermissions) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.md),

                // Permission summary badge
                _buildPermissionSummary(permissions),
                const SizedBox(height: AppSpacing.sm),

                // Key permissions
                ...keyPermissions.take(3).map((perm) {
                  final isAllowed = permissions[perm] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        Icon(
                          isAllowed ? Icons.check : Icons.close,
                          size: 16,
                          color: isAllowed ? AppColors.primaryGreen : AppColors.gray400,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            RolePresets.getPermissionDisplayName(perm),
                            style: AppTypography.textTheme.labelSmall!.copyWith(
                              color: isAllowed ? AppColors.gray700 : AppColors.gray400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Get key permissions to display for each role
  List<String> _getKeyPermissions(String role) {
    switch (role.toUpperCase()) {
      case 'CASHIER':
      case 'STAFF':
        return [
          Permissions.createSale,
          Permissions.viewInventory,
          Permissions.viewProfitMargins, // Will show as X
        ];
      case 'STOCKER':
      case 'INVENTORY_CLERK':
        return [
          Permissions.addInventoryItem,
          Permissions.adjustStock,
          Permissions.createSale, // Will show as X
        ];
      case 'SHIFT_SUPERVISOR':
      case 'SUPERVISOR':
        return [
          Permissions.processRefund,
          Permissions.voidSale,
          Permissions.viewReports,
        ];
      case 'INVENTORY_MANAGER':
        return [
          Permissions.editInventoryItem,
          Permissions.deleteInventoryItem,
          Permissions.exportData,
        ];
      case 'MANAGER':
      case 'ADMIN':
        return [
          Permissions.manageAccounting,
          Permissions.viewProfitMargins,
          Permissions.viewReports,
        ];
      case 'CUSTOM':
        return [
          Permissions.changeSettings,
          Permissions.viewInventory,
          Permissions.createSale,
        ];
      case 'WAITER':
        return [
          Permissions.createSale,
          Permissions.viewInventory,
          Permissions.viewOrders,
        ];
      case 'CHEF':
        return [
          Permissions.viewOrders,
          Permissions.viewInventory,
          Permissions.createSale, // Will show as X
        ];
      case 'DELIVERY':
        return [
          Permissions.viewOrders,
          Permissions.markDelivered,
          Permissions.viewCustomers,
        ];
      case 'RECEPTIONIST':
        return [
          Permissions.viewCustomers,
          Permissions.addCustomer,
          Permissions.viewInventory,
        ];
      case 'SERVICE_PROVIDER':
        return [
          Permissions.createSale,
          Permissions.viewCustomers,
          Permissions.viewInventory,
        ];
      default:
        return [];
    }
  }

  /// Build a compact badge showing granted/total permission count
  Widget _buildPermissionSummary(Map<String, dynamic> permissions) {
    final granted = permissions.values.where((v) => v == true).length;
    final total = permissions.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        '$granted/$total permissions granted',
        style: AppTypography.textTheme.labelSmall!.copyWith(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Compact role badge for list views
class RoleBadge extends StatelessWidget {
  final String role;
  final bool compact;

  const RoleBadge({
    super.key,
    required this.role,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = RolePresets.getRoleDisplayName(role);
    final icon = RolePresets.getRoleIcon(role);

    Color backgroundColor;
    Color textColor;

    // Color coding for visual hierarchy
    switch (role.toUpperCase()) {
      case 'OWNER':
        backgroundColor = AppColors.warningYellow.withOpacity(0.2);
        textColor = Colors.orange.shade800;
        break;
      case 'MANAGER':
      case 'ADMIN':
        backgroundColor = AppColors.primaryGreen.withOpacity(0.1);
        textColor = AppColors.primaryGreen;
        break;
      case 'SHIFT_SUPERVISOR':
      case 'SUPERVISOR':
        backgroundColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        break;
      case 'INVENTORY_MANAGER':
        backgroundColor = Colors.purple.shade50;
        textColor = Colors.purple.shade700;
        break;
      case 'STOCKER':
      case 'INVENTORY_CLERK':
        backgroundColor = Colors.brown.shade50;
        textColor = Colors.brown.shade700;
        break;
      case 'WAITER':
        backgroundColor = Colors.amber.shade50;
        textColor = Colors.amber.shade800;
        break;
      case 'CHEF':
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      case 'DELIVERY':
        backgroundColor = Colors.teal.shade50;
        textColor = Colors.teal.shade700;
        break;
      case 'RECEPTIONIST':
        backgroundColor = Colors.cyan.shade50;
        textColor = Colors.cyan.shade700;
        break;
      case 'SERVICE_PROVIDER':
        backgroundColor = Colors.indigo.shade50;
        textColor = Colors.indigo.shade700;
        break;
      default: // Cashier and others
        backgroundColor = AppColors.gray200;
        textColor = AppColors.gray700;
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Text(
          displayName,
          style: AppTypography.textTheme.labelSmall!.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            displayName,
            style: AppTypography.textTheme.labelLarge!.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
