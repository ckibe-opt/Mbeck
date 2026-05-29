import 'dart:async';
import 'package:flutter/material.dart';
import '../../../widgets/empty_state_guide.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../db/db_provider.dart';
import '../../models/shop_member.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/event_processor.dart';
import '../../services/restaurant_service.dart';
import '../../theme/design_system.dart';
import 'restaurant_pos_screen.dart';
import '../../widgets/restaurant/order_app_bar.dart';
import '../../widgets/restaurant/kitchen_queue_tab_bar.dart';
import '../../widgets/restaurant/kitchen_ticket_card.dart';
import '../../widgets/interactive_help_scroll.dart';

/// Kitchen Display System (KDS) for Restaurant Module.
///
/// Shows incoming tickets separated by *Courses/Orders* in a Kanban Board style.
/// Chefs fire entire tables or courses at once, ensuring synchronized meal completion.
class OrderQueueScreen extends StatefulWidget {
  const OrderQueueScreen({super.key});

  @override
  State<OrderQueueScreen> createState() => _OrderQueueScreenState();
}

class _OrderQueueScreenState extends State<OrderQueueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data model: Flat list of all relevant items
  List<Map<String, dynamic>> _allItems = [];
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLoading = true;
  Timer? _refreshTimer;
  final Set<int> _processingItemIds = {};
  bool _isDeliveryRole = false;
  ShopMember? _currentMember;
  StreamSubscription<String>? _eventSub;

  final List<String> _statuses = ['pending', 'preparing', 'ready'];
  final Map<String, String> _statusLabels = {
    'pending': 'To Fire (Pending)',
    'preparing': 'Cooking',
    'ready': 'Ready to Serve',
  };
  final Map<String, IconData> _statusIcons = {
    'pending': Icons.local_fire_department_outlined,
    'preparing': Icons.restaurant,
    'ready': Icons.room_service,
  };
  final Map<String, Color> _statusColors = {
    'pending': Colors.orange,
    'preparing': Colors.red,
    'ready': Colors.green,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
    _checkRole();
    _loadKdsItems();

    // Auto-refresh every 10 seconds for real-time kitchen updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadKdsItems();
    });

    // Listen for remote ORDER_STATUS_CHANGE and ORDER_CREATED events
    _eventSub = EventProcessor.events.listen((eventType) {
      if (eventType == 'ORDER_STATUS_CHANGE' || eventType == 'ORDER_CREATED') {
        if (eventType == 'ORDER_CREATED') {
          _playAlertSound();
        }
        _loadKdsItems();
      }
    });
  }

  void _playAlertSound() async {
    try {
      // Play system alert sound or asset
      await _audioPlayer.play(AssetSource('audio/beep_short.ogg'));
    } catch (e) {
      debugPrint('Failed to play KDS alert sound: $e');
    }
  }

  Future<void> _checkRole() async {
    final member = await AuthService.getCurrentMember();
    if (mounted) {
      setState(() {
        _currentMember = member;
        _isDeliveryRole = member?.role.toUpperCase() == 'DELIVERY';
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    _eventSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadKdsItems() async {
    try {
      final db = await DbProvider.db;

      final result = await db.rawQuery('''
        SELECT 
          oi.*, 
          m.image_path,
          o.status as order_status,
          o.order_number,
          o.table_number,
          o.order_type,
          o.customer_name,
          o.created_at as order_created_at,
          o.created_by,
          o.preparing_by,
          o.ready_by,
          o.served_by
        FROM restaurant_order_items oi
        JOIN restaurant_orders o ON oi.order_id = o.id
        LEFT JOIN restaurant_menu m ON m.id = oi.menu_item_id
        WHERE o.status NOT IN ('cancelled') 
          AND oi.status IN ('pending', 'preparing', 'ready')
        ORDER BY oi.created_at ASC
      ''');

      final List<Map<String, dynamic>> items = [];
      for (final item in result) {
        if (_isDeliveryRole &&
            item['order_type'] != 'takeaway' &&
            item['order_type'] != 'delivery') {
          continue;
        }
        items.add(Map<String, dynamic>.from(item));
      }

      _autoCompleteServedOrders();

      if (mounted) {
        setState(() {
          _allItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading KDS items: $e');
      if (mounted) {
        setState(() {
          _allItems = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _autoCompleteServedOrders() async {
    try {
      final db = await DbProvider.db;
      // Only auto-complete TAKEAWAY and DELIVERY orders. Dine-in must be checked out via Split Bill (POS).
      final activeOrders = await db.rawQuery(
          "SELECT id FROM restaurant_orders WHERE status NOT IN ('completed', 'cancelled') AND order_type IN ('takeaway', 'delivery')");

      for (final o in activeOrders) {
        final orderId = o['id'] as int;

        // Count total items vs served items
        final counts = await db.rawQuery('''
          SELECT 
            COUNT(*) as total_items,
            SUM(CASE WHEN status = 'served' THEN 1 ELSE 0 END) as served_items
          FROM restaurant_order_items
          WHERE order_id = ?
        ''', [orderId]);

        if (counts.isNotEmpty) {
          final total = (counts.first['total_items'] as num?)?.toInt() ?? 0;
          final served = (counts.first['served_items'] as num?)?.toInt() ?? 0;

          if (total > 0 && total == served) {
            final staffName = _currentMember?.userName ?? 'System Auto';
            await RestaurantService.completeParentOrder(orderId, staffName,
                createSaleTransaction: true);
          }
        }
      }
    } catch (e) {
      debugPrint('Error in auto-complete check: $e');
    }
  }

  Future<void> _updateItemsBulkStatus(
      List<int> itemIds, String newStatus, int orderId) async {
    for (var id in itemIds) {
      _processingItemIds.add(id);
    }
    setState(() {});

    try {
      final db = await DbProvider.db;
      final now = DateTime.now().millisecondsSinceEpoch;
      final staffName = _currentMember?.userName ?? 'Unknown';

      Map<String, dynamic> itemUpdates = {
        'status': newStatus,
        'updated_at': now,
      };

      Map<String, dynamic> orderUpdates = {
        'status': newStatus,
        'updated_at': now,
      };

      if (newStatus == 'preparing') {
        itemUpdates['fired_at'] = now;
        itemUpdates['preparing_by'] = staffName;
        orderUpdates['preparing_by'] = staffName;
      } else if (newStatus == 'ready') {
        itemUpdates['ready_by'] = staffName;
        orderUpdates['ready_by'] = staffName;
      } else if (newStatus == 'served') {
        itemUpdates['served_by'] = staffName;
        orderUpdates['served_by'] = staffName;
      }

      // Update parent order status and tracking
      await db.update('restaurant_orders', orderUpdates,
          where: 'id = ?', whereArgs: [orderId]);

      // Update specific items and their tracking
      await db.update(
        'restaurant_order_items',
        itemUpdates,
        where: 'id IN (${itemIds.map((_) => '?').join(',')})',
        whereArgs: itemIds,
      );

      // ========== LAN SYNC: Emit ORDER_STATUS_CHANGE event ==========
      try {
        final orderRows = await db.query('restaurant_orders',
            where: 'id = ?', whereArgs: [orderId], limit: 1);
        final orderNumber = orderRows.isNotEmpty
            ? orderRows.first['order_number'] as String?
            : null;
        await EventService.emitEvent(
          eventType: 'ORDER_STATUS_CHANGE',
          payload: {
            'order_id': orderId,
            'order_number': orderNumber,
            'new_status': newStatus,
            'staff_name': staffName,
          },
          timestamp: now,
        );
      } catch (e) {
        debugPrint('⚠️ Failed to emit ORDER_STATUS_CHANGE (non-fatal): $e');
      }
      // ===============================================================

      HapticFeedback.lightImpact();
      _loadKdsItems();
    } catch (e) {
      debugPrint('Error bulk updating item status: $e');
    } finally {
      if (mounted) {
        for (var id in itemIds) {
          _processingItemIds.remove(id);
        }
        setState(() {});
      }
    }
  }

  Future<void> _updateSingleItemStatus(int itemId, String newStatus) async {
    _processingItemIds.add(itemId);
    setState(() {});

    try {
      final db = await DbProvider.db;
      final now = DateTime.now().millisecondsSinceEpoch;
      final staffName = _currentMember?.userName ?? 'Unknown';

      Map<String, dynamic> itemUpdates = {
        'status': newStatus,
        'updated_at': now,
      };

      if (newStatus == 'preparing') {
        itemUpdates['fired_at'] = now;
        itemUpdates['preparing_by'] = staffName;
      } else if (newStatus == 'ready') {
        itemUpdates['ready_by'] = staffName;
      } else if (newStatus == 'served') {
        itemUpdates['served_by'] = staffName;
      }

      await db.update(
        'restaurant_order_items',
        itemUpdates,
        where: 'id = ?',
        whereArgs: [itemId],
      );

      // ========== LAN SYNC: Emit ORDER_STATUS_CHANGE event ==========
      try {
        // Look up the parent order for this item
        final itemRows = await db.query('restaurant_order_items',
            where: 'id = ?', whereArgs: [itemId], limit: 1);
        if (itemRows.isNotEmpty) {
          final orderId = itemRows.first['order_id'] as int;
          final orderRows = await db.query('restaurant_orders',
              where: 'id = ?', whereArgs: [orderId], limit: 1);
          final orderNumber = orderRows.isNotEmpty
              ? orderRows.first['order_number'] as String?
              : null;
          await EventService.emitEvent(
            eventType: 'ORDER_STATUS_CHANGE',
            payload: {
              'order_id': orderId,
              'order_number': orderNumber,
              'new_status': newStatus,
              'staff_name': staffName,
            },
            timestamp: now,
          );
        }
      } catch (e) {
        debugPrint('⚠️ Failed to emit ORDER_STATUS_CHANGE (non-fatal): $e');
      }
      // ===============================================================

      HapticFeedback.lightImpact();
      _loadKdsItems();
    } catch (e) {
      debugPrint('Error updating single item status: $e');
    } finally {
      if (mounted) {
        _processingItemIds.remove(itemId);
        setState(() {});
      }
    }
  }

  // Groups items by Order ID for a specific tab
  List<Map<String, dynamic>> _getOrderGroupsForStatus(String status) {
    Map<int, Map<String, dynamic>> groups = {};
    for (final item in _allItems.where((i) => i['order_status'] == status)) {
      final orderId = item['order_id'] as int;
      if (!groups.containsKey(orderId)) {
        groups[orderId] = {
          'order_id': orderId,
          'order_number': item['order_number'],
          'table_number': item['table_number'],
          'order_type': item['order_type'],
          'order_created_at': item['order_created_at'],
          'fired_at': item['fired_at'] ?? 0,
          'customer_name': item['customer_name'],
          'created_by': item['created_by'],
          'preparing_by': item['preparing_by'],
          'ready_by': item['ready_by'],
          'served_by': item['served_by'],
          'items': <Map<String, dynamic>>[],
        };
      }
      groups[orderId]!['items'].add(item);
    }

    final sorted = groups.values.toList();
    sorted.sort((a, b) => (a['order_created_at'] as num? ?? 0)
        .compareTo(b['order_created_at'] as num? ?? 0));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    // Current group for count metrics
    String currentStatus = _statuses[_tabController.index];
    Map<String, int> statusCounts = {};
    for (var s in _statuses) {
      statusCounts[s] = _getOrderGroupsForStatus(s).length;
    }

    final groups = _getOrderGroupsForStatus(currentStatus);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Light gray from showcase
      appBar: OrderAppBar(
        isDeliveryRole: _isDeliveryRole,
        onBack: () => Navigator.of(context).maybePop(),
        onRefresh: _loadKdsItems,
      ),
      body: Stack(
        children: [
          Column(
            children: [
          // Kanab Tab bar
          Container(
            color: Colors.white,
            width: double.infinity,
            child: KitchenQueueTabBar(
              statuses: _statuses,
              currentStatus: currentStatus,
              statusCounts: statusCounts,
              onStatusSelected: (status) {
                final idx = _statuses.indexOf(status);
                if (idx != -1) {
                  _tabController.animateTo(idx);
                  setState(() {}); // refresh the tabs
                }
              },
            ),
          ),

          // KDS Feed
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryGreen))
                : TabBarView(
                    controller: _tabController,
                    physics:
                        const NeverScrollableScrollPhysics(), // Disabling swipe to force tapping tabs for cleaner state mgmt
                    children: _statuses.map((status) {
                      if (groups.isEmpty) {
                        return EmptyStateGuide(
                          icon: _statusIcons[status]!,
                          title: 'Kitchen is idle',
                          subtitle: 'Orders placed from the POS or waiter app will appear here as kitchen tickets',
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: groups.length,
                        itemBuilder: (ctx, i) {
                          final group = groups[i];
                          final orderId = group['order_id'] as int;
                          final List<Map<String, dynamic>> items =
                              List<Map<String, dynamic>>.from(group['items']);
                          final itemIds =
                              items.map((e) => e['id'] as int).toList();

                          return KitchenTicketCard(
                            group: group,
                            status: status,
                            onItemAction: (itemId, current, target) {
                              _updateSingleItemStatus(itemId, target);
                            },
                            onAction: () {
                              if (status == 'pending') {
                                _updateItemsBulkStatus(
                                    itemIds, 'preparing', orderId);
                              } else if (status == 'preparing') {
                                _updateItemsBulkStatus(
                                    itemIds, 'ready', orderId);
                              } else if (status == 'ready') {
                                _updateItemsBulkStatus(
                                    itemIds, 'served', orderId);
                              }
                            },
                          );
                        },
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
      const InteractiveHelpScroll(contextKey: 'kds'),
      ],
      ),
      floatingActionButton: _isDeliveryRole
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RestaurantPosScreen()))
                    .then((_) => _loadKdsItems());
              },
              label: const Text('FOH Terminal'),
              icon: const Icon(Icons.point_of_sale),
              backgroundColor: Colors.blueGrey,
            ),
    );
  }
}
