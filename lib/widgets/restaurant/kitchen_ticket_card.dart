import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class KitchenTicketCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final String status;
  final VoidCallback onAction;
  final Function(int itemId, String currentStatus, String targetStatus)
      onItemAction;

  const KitchenTicketCard({
    Key? key,
    required this.group,
    required this.status,
    required this.onAction,
    required this.onItemAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final orderNum =
        group['order_number']?.toString() ?? '#${group['order_id']}';
    final isDineIn = group['order_type'] == 'dine_in';
    final tableLine = isDineIn ? 'TABLE ${group['table_number']}' : 'TAKEAWAY';

    // Time tracking
    final firedAt = (group['fired_at'] as num?)?.toInt() ?? 0;
    final createdAt = (group['order_created_at'] as num?)?.toInt() ?? 0;
    final anchorTime = firedAt > 0 ? firedAt : createdAt;
    final waitMinutes = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(anchorTime))
        .inMinutes;

    final isCooking = status == 'preparing';
    final isOverdue = isCooking && waitMinutes >= 15;

    // Responsibility info
    String? responsiblePerson;
    if (status == 'pending') {
      responsiblePerson = group['created_by']?.toString() ?? 'Unknown Waiter';
    } else if (isCooking || status == 'ready') {
      responsiblePerson =
          group['preparing_by']?.toString() ?? group['created_by']?.toString();
    } else if (status == 'served') {
      responsiblePerson =
          group['served_by']?.toString() ?? group['ready_by']?.toString();
    }
    responsiblePerson ??= 'System';

    // Styling logic
    Color borderColor;
    Color topBarColor;
    Color tagBgColor;
    Color tagTextColor;

    switch (status) {
      case 'pending':
        borderColor = Colors.orange.shade500;
        topBarColor = Colors.transparent;
        break;
      case 'preparing':
        borderColor = isOverdue ? Colors.red.shade600 : Colors.red.shade500;
        topBarColor = isOverdue ? Colors.red.shade500 : Colors.transparent;
        break;
      case 'ready':
        borderColor = Colors.green.shade500;
        topBarColor = Colors.transparent;
        break;
      default:
        borderColor = Colors.blue.shade500;
        topBarColor = Colors.transparent;
        break;
    }

    if (isDineIn) {
      tagBgColor = Colors.purple.shade100;
      tagTextColor = Colors.purple.shade700;
    } else {
      tagBgColor = Colors.blue.shade100;
      tagTextColor = Colors.blue.shade700;
    }

    final List<Map<String, dynamic>> items =
        List<Map<String, dynamic>>.from(group['items']);

    // Check if there are notes
    final notes = items
        .where((i) =>
            i['item_note'] != null &&
            i['item_note'].toString().trim().isNotEmpty)
        .map((i) => i['item_note'].toString())
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: status == 'preparing' && isOverdue
            ? Colors.red.shade50
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (status == 'preparing' && isOverdue)
                ? Colors.red.shade300
                : Colors.grey.shade200,
            width: (status == 'preparing' && isOverdue) ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left thick border strip
            Container(width: 4, color: borderColor),

            Expanded(
              child: Column(
                children: [
                  // Overdue warning top strip
                  if (topBarColor != Colors.transparent)
                    Container(height: 4, color: topBarColor),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tagBgColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                          isDineIn
                                              ? Icons.table_restaurant
                                              : Icons.shopping_bag_outlined,
                                          size: 10,
                                          color: tagTextColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        tableLine.toUpperCase(),
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: tagTextColor),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '#$orderNum',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.schedule,
                                      size: 10, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$waitMinutes min',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),

                        // Items
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: items.map((item) {
                              final itemId = item['id'] as int;
                              final itemStatus = item['status'] as String;
                              final qty =
                                  (item['quantity'] as num?)?.toInt() ?? 1;
                              final name = item['menu_item_name']?.toString() ??
                                  'Unknown';

                              // Visual logic for crossed-out items
                              bool isCompleted = false;
                              if (status == 'preparing' &&
                                  itemStatus == 'ready') {
                                isCompleted = true;
                              } else if (status == 'pending' &&
                                  (itemStatus == 'preparing' ||
                                      itemStatus == 'ready')) {
                                isCompleted = true;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    // Quick strike-off tap logic depending on ticket scope
                                    if (status == 'pending' &&
                                        itemStatus == 'pending') {
                                      onItemAction(
                                          itemId, 'pending', 'preparing');
                                    } else if (status == 'preparing' &&
                                        itemStatus == 'preparing') {
                                      onItemAction(
                                          itemId, 'preparing', 'ready');
                                    } else if (status == 'ready' &&
                                        itemStatus == 'ready') {
                                      onItemAction(itemId, 'ready', 'served');
                                    } else if (isCompleted &&
                                        status == 'preparing') {
                                      // Undo (un-strike)
                                      onItemAction(
                                          itemId, 'ready', 'preparing');
                                    }
                                  },
                                  child: Opacity(
                                    opacity: isCompleted ? 0.6 : 1.0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: isCompleted
                                            ? Colors.green.shade50
                                                .withOpacity(0.5)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            child: Text(
                                              '${qty}x',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.grey.shade800),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  decoration: isCompleted
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey.shade900),
                                            ),
                                          ),
                                          if (isCompleted)
                                            Row(
                                              children: [
                                                Text('UNDO',
                                                    style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors
                                                            .green.shade600)),
                                                const SizedBox(width: 2),
                                                Icon(Icons.check,
                                                    size: 16,
                                                    color:
                                                        Colors.green.shade500),
                                              ],
                                            )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // Notes
                        if (notes.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange.shade100),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(Icons.comment_outlined,
                                      size: 14, color: Colors.orange.shade600),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: notes
                                        .expand((n) => n.split(';'))
                                        .where((n) => n.trim().isNotEmpty)
                                        .map((note) => Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade200,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                note.trim(),
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.orange.shade900),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Footer (Waiter + Action)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person,
                                    size: 12, color: Colors.grey.shade400),
                                const SizedBox(width: 4),
                                Text(
                                  responsiblePerson,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getActionColor(status),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                minimumSize: const Size(0, 32),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              onPressed: onAction,
                              icon: const Icon(Icons.arrow_forward, size: 14),
                              label: Text(
                                _getActionText(status),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getActionText(String status) {
    switch (status) {
      case 'pending':
        return 'Start Cooking';
      case 'preparing':
        return 'Mark Ready';
      case 'ready':
        return 'Serve';
      default:
        return 'Archive';
    }
  }

  Color _getActionColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.red.shade500;
      case 'preparing':
        return Colors.green.shade500;
      case 'ready':
        return Colors.blue.shade500;
      default:
        return Colors.grey.shade500;
    }
  }
}
