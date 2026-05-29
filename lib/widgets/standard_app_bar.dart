import 'package:flutter/material.dart';
import '../theme/design_system.dart';

/// StandardAppBar provides a consistent AppBar design across all screens
/// This ensures all titles are visible and styled uniformly
class StandardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool centerTitle;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const StandardAppBar({
    super.key,
    required this.title,
    this.actions,
    this.backgroundColor,
    this.foregroundColor,
    this.centerTitle = false,
    this.leading,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    // Auto-calculate foreground color based on background brightness
    final bgColor = backgroundColor ?? Colors.white;
    final isLightBackground = bgColor.computeLuminance() > 0.5;
    final autoForeground = isLightBackground ? AppColors.primaryBlack : Colors.white;
    
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      backgroundColor: bgColor,
      foregroundColor: foregroundColor ?? autoForeground,
      elevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
      bottom: bottom ?? _buildBottomBorder(),
    );
  }

  PreferredSize _buildBottomBorder() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(
        height: 1,
        color: AppColors.gray200,
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 1),
      );
}
