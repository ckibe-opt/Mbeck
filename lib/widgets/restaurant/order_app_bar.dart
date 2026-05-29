import 'package:flutter/material.dart';

class OrderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDeliveryRole;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  const OrderAppBar({
    Key? key,
    required this.isDeliveryRole,
    required this.onBack,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF1F2937),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack,
        tooltip: 'Back',
      ),
      title: Text(
        isDeliveryRole ? 'Delivery Kanban Board' : 'Kitchen Kanban Board',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      actions: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.circle, color: Colors.green, size: 12), // online indicator
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: onRefresh,
          tooltip: 'Refresh',
        ),
      ],
    );
  }
}
