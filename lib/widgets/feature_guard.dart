import 'package:flutter/material.dart';
import '../services/credit_service.dart';
import '../screens/paywall_screen.dart';
import '../theme/design_system.dart';

/// Wrap any UI with FeatureGuard to lock it behind the paywall after trial expiry.
///
/// Behavior:
/// - Access granted: renders [child] normally.
/// - Access denied: disables interaction, overlays a lock, and on tap opens [PaywallScreen].
class FeatureGuard extends StatelessWidget {
  final Widget child;
  final String featureName;

  const FeatureGuard({
    super.key,
    required this.child,
    required this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CreditProfile?>(
      future: CreditService.getCreditProfileCached(),
      builder: (context, snapshot) {
        // Fail-closed by default: until we know the profile, treat as locked.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Stack(
            alignment: Alignment.center,
            children: [
              AbsorbPointer(child: child),
              Positioned.fill(
                child: Container(
                  color: AppColors.gray900.withOpacity(0.06),
                ),
              ),
              Center(
                child: AppSkeleton.box(width: 40, height: 40),
              ),
            ],
          );
        }

        final profile = snapshot.data;
        final locked = snapshot.hasError || profile == null || profile.isFeatureLocked;

        if (!locked) return child;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => PaywallScreen.show(context, featureName: featureName),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AbsorbPointer(child: child),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.gray900.withOpacity(0.06),
                    borderRadius: _tryExtractBorderRadius(child),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gray800,
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, size: 14, color: AppColors.surfaceWhite),
                      const SizedBox(width: 6),
                      Text('Locked', style: AppTypography.textTheme.labelMedium?.copyWith(color: AppColors.surfaceWhite, fontWeight: FontWeight.w700, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Best-effort: if [child] is a Material widget with shape, we'd need reflection.
  /// Keep it simple: return null to avoid incorrect rounding.
  BorderRadius? _tryExtractBorderRadius(Widget child) {
    return null;
  }
}

