import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/shop_member.dart';

/// A widget that conditionally shows its child based on the current user's permissions.
class PermissionGuard extends StatelessWidget {
  /// The permission required to view the child.
  final String permission;

  /// The widget to display if access is granted.
  final Widget child;

  /// The widget to display if access is denied.
  /// Defaults to [SizedBox.shrink()] (hidden).
  /// You can provide a "Lock" icon or "Access Denied" message here.
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ShopMember?>(
      future: AuthService.getCurrentMember(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // While loading or if no member found, hide by default (secure by default)
          return fallback ?? const SizedBox.shrink();
        }

        final member = snapshot.data!;
        
        // Check if member has the required permission
        if (member.hasPermission(permission)) {
          return child;
        }

        // Access denied
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}
