import 'package:flutter/material.dart';

class KitchenQueueTabBar extends StatelessWidget {
  final List<String> statuses;
  final String currentStatus;
  final ValueChanged<String> onStatusSelected;
  final Map<String, int> statusCounts;

  const KitchenQueueTabBar({
    Key? key,
    required this.statuses,
    required this.currentStatus,
    required this.onStatusSelected,
    required this.statusCounts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: statuses.map((status) {
          final isSelected = status == currentStatus;
          final count = statusCounts[status] ?? 0;

          Color bgColor;
          Color borderColor;
          Color textColor;

          if (isSelected) {
            switch (status) {
              case 'pending':
                bgColor = Colors.orange.shade50;
                borderColor = Colors.orange.shade200;
                textColor = Colors.orange.shade700;
                break;
              case 'preparing':
                bgColor = Colors.red.shade50;
                borderColor = Colors.red.shade200;
                textColor = Colors.red.shade700;
                break;
              case 'ready':
                bgColor = Colors.green.shade50;
                borderColor = Colors.green.shade200;
                textColor = Colors.green.shade700;
                break;
              default:
                bgColor = Colors.blue.shade50;
                borderColor = Colors.blue.shade200;
                textColor = Colors.blue.shade700;
            }
          } else {
            bgColor = Colors.white;
            borderColor = Colors.grey.shade200;
            textColor = Colors.grey.shade600;
          }

          String label;
          IconData icon;
          switch (status) {
            case 'pending':
              label = 'New';
              icon = Icons.local_fire_department_outlined;
              break;
            case 'preparing':
              label = 'Cooking';
              icon = Icons.restaurant;
              break;
            case 'ready':
              label = 'Ready';
              icon = Icons.room_service;
              break;
            default:
              label = 'Served';
              icon = Icons.check_circle;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onStatusSelected(status),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1))
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 14,
                        color: isSelected ? textColor : Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '$label ($count)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (status == 'pending' && count > 0 && !isSelected) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
