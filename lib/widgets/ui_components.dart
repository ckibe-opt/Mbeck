import 'package:flutter/material.dart';
import '../theme/design_system.dart';

/// StatCard - Reusable performance metric display component
/// Based on research from Square/Shopify POS designs
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: AppColors.gray200, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: AppIconSizes.lg),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.textTheme.labelMedium?.copyWith(
                  color: AppColors.gray600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: AppTypography.textTheme.headlineLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ActionTile - Operation grid tile component
/// Enhanced with research-based icon sizing
class ActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLocked;
  final Widget? badge;

  const ActionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLocked = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(
          color: isLocked ? AppColors.gray300 : AppColors.gray200,
        ),
      ),
      child: InkWell(
        onTap: isLocked ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLocked ? Icons.lock_outline : icon,
                  color: isLocked ? AppColors.gray400 : color,
                  size: AppIconSizes.xl,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  style: AppTypography.textTheme.labelLarge?.copyWith(
                    color: isLocked ? AppColors.gray400 : null,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isLocked) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Restricted',
                    style: AppTypography.textTheme.labelSmall?.copyWith(
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              ],
            ),
            if (badge != null)
              Positioned(
                top: 8,
                right: 8,
                child: badge!,
              ),
          ],
        ),
      ),
    );
  }
}

/// M-Pesa Badge - Indicates M-Pesa integration
class MPesaBadge extends StatelessWidget {
  const MPesaBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        'M-Pesa',
        style: AppTypography.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Online Status Badge
class OnlineBadge extends StatelessWidget {
  final bool isOnline;

  const OnlineBadge({super.key, this.isOnline = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isOnline ? AppColors.success : AppColors.gray400,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: AppTypography.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
