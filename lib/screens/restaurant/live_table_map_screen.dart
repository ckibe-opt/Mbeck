// ============================================================================
// LIVE TABLE MAP — Real-time table status visualization
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../db/db_provider.dart';
import '../../services/auth_service.dart';
import '../../services/event_processor.dart';
import '../../services/restaurant_service.dart';
import '../../theme/design_system.dart';
import 'shared_map_state.dart';
import 'split_bill_screen.dart';
import 'table_transfer_screen.dart';
import '../../widgets/interactive_help_scroll.dart';

class LiveTableMapScreen extends StatefulWidget {
  const LiveTableMapScreen({super.key});

  @override
  State<LiveTableMapScreen> createState() => _LiveTableMapScreenState();
}

class _LiveTableMapScreenState extends State<LiveTableMapScreen> with SingleTickerProviderStateMixin {
  List<_LiveTable> _tables = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  StreamSubscription? _eventSub;
  int? _selectedIndex;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    
    _loadData();
    // Auto-refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadData());
    // Also refresh on order events
    _eventSub = EventProcessor.events.listen((eventType) {
      if (eventType == 'ORDER_CREATED' || 
          eventType == 'ORDER_STATUS_CHANGE' || 
          eventType == 'ORDER_UPDATE' || 
          eventType == 'TABLE_TRANSFER' || 
          eventType == 'FLOOR_PLAN_UPDATE') {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _eventSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = await DbProvider.db;

    // 1. Load floor plan
    final floorRows = await db.query('restaurant_floor_plan', orderBy: 'id ASC');
    if (floorRows.isEmpty) {
      if (mounted) setState(() { _tables = []; _isLoading = false; });
      return;
    }

    // 2. Load active orders (not completed / cancelled)
    final activeOrders = await db.query(
      'restaurant_orders',
      where: "status NOT IN ('completed', 'cancelled')",
      orderBy: 'created_at DESC',
    );

    // Build table map — normalize table numbers for flexible matching
    // e.g. order table_number='4' should match floor plan 'T-4'
    String _normalizeTableNum(String raw) {
      return raw.replaceAll(RegExp(r'^(T-|Table\s*)', caseSensitive: false), '').trim();
    }
    final ordersByNormalized = <String, Map<String, dynamic>>{};
    for (final order in activeOrders) {
      final tn = order['table_number']?.toString();
      if (tn != null && tn.isNotEmpty) {
        final norm = _normalizeTableNum(tn);
        if (!ordersByNormalized.containsKey(norm)) {
          ordersByNormalized[norm] = order;
        }
      }
    }

    final List<_LiveTable> tables = [];
    for (final r in floorRows) {
      final tn = r['table_number'] as String;
      final norm = _normalizeTableNum(tn);
      final order = ordersByNormalized[norm];
      _TableStatus status = _TableStatus.available;
      String? orderInfo;
      int? seatedMinutes;
      List<String> menuItems = [];

      if (order != null) {
        final orderStatus = order['status']?.toString() ?? 'pending';
        final createdAt = order['created_at'] as int? ?? 0;
        seatedMinutes = createdAt > 0
            ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(createdAt)).inMinutes
            : 0;

        // Query order_items table for actual menu item names
        try {
          final orderId = order['id'];
          if (orderId != null) {
            final orderItems = await db.query(
              'restaurant_order_items',
              where: 'order_id = ?',
              whereArgs: [orderId],
            );
            for (final oi in orderItems) {
              final name = oi['menu_item_name']?.toString() ?? 'Item';
              final qty = oi['quantity'] as int? ?? 1;
              menuItems.add('${qty}x $name');
            }
          }
        } catch (_) {}

        orderInfo = menuItems.isNotEmpty
            ? menuItems.join(', ')
            : 'Order ${order['order_number']}';
        orderInfo += ' • KES ${(order['total'] as num?)?.toStringAsFixed(0) ?? '0'}';

        switch (orderStatus) {
          case 'pending':
            status = (seatedMinutes != null && seatedMinutes > 15) ? _TableStatus.needsAttention : _TableStatus.occupied;
            break;
          case 'preparing':
            status = _TableStatus.occupied;
            break;
          case 'ready':
            status = _TableStatus.foodReady;
            break;
          case 'served':
            status = _TableStatus.occupied;
            break;
          case 'paid':
            status = _TableStatus.paid;
            break;
          default:
            status = _TableStatus.occupied;
        }
      }

      tables.add(_LiveTable(
        tableNumber: tn,
        label: r['label'] as String?,
        shape: r['shape'] as String? ?? 'round',
        seats: r['seats'] as int? ?? 4,
        x: (r['x'] as num?)?.toDouble() ?? 0.5,
        y: (r['y'] as num?)?.toDouble() ?? 0.5,
        zone: r['zone'] as String? ?? 'Main Hall',
        status: status,
        orderId: order?['id'] as int?,
        orderInfo: orderInfo,
        menuItems: menuItems,
        seatedMinutes: seatedMinutes,
        orderStatus: order?['status']?.toString(),
      ));
    }

    if (mounted) setState(() { _tables = tables; _isLoading = false; });
  }

  Color _statusColor(_TableStatus s) {
    switch (s) {
      case _TableStatus.available: return const Color(0xFF10B981);
      case _TableStatus.occupied: return const Color(0xFFF59E0B);
      case _TableStatus.needsAttention: return const Color(0xFFEF4444);
      case _TableStatus.reserved: return const Color(0xFF3B82F6);
      case _TableStatus.foodReady: return const Color(0xFFF59E0B);
      case _TableStatus.paid: return const Color(0xFF6B7280); // Gray
    }
  }

  String _statusLabel(_TableStatus s) {
    switch (s) {
      case _TableStatus.available: return 'Available';
      case _TableStatus.occupied: return 'Occupied';
      case _TableStatus.needsAttention: return 'Needs Attention';
      case _TableStatus.reserved: return 'Reserved';
      case _TableStatus.foodReady: return 'Food Ready';
      case _TableStatus.paid: return 'Paid (Cleaning)';
    }
  }

  String _statusEmoji(_LiveTable t) {
    switch (t.status) {
      case _TableStatus.available: return '';
      case _TableStatus.occupied:
        if (t.orderStatus == 'preparing') return '🍳';
        if (t.orderStatus == 'served') return '💳';
        return '⏳';
      case _TableStatus.needsAttention: return '⚠️';
      case _TableStatus.reserved: return '🕐';
      case _TableStatus.foodReady: return '🔔';
      case _TableStatus.paid: return '🧹';
    }
  }

  void _showTableDetail(int index) {
    final t = _tables[index];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1F2937),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _statusColor(t.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(t.shape == 'round' ? 22 : 10),
                    border: Border.all(color: _statusColor(t.status), width: 2),
                  ),
                  child: Center(child: Text(t.tableNumber, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _statusColor(t.status)))),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.label ?? t.tableNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(t.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(_statusLabel(t.status), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _statusColor(t.status))),
                        ),
                        const SizedBox(width: 6),
                        Text('${t.seats} seats • ${t.zone}', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if (t.orderInfo != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show each menu item on its own line
                    if (t.menuItems.isNotEmpty)
                      ...t.menuItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            const Text('• ', style: TextStyle(fontSize: 12, color: Color(0xFF10B981))),
                            Expanded(child: Text(item, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
                          ],
                        ),
                      ))
                    else
                      Text(t.orderInfo!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 6),
                    // Total line
                    Text(t.orderInfo!.split('•').last.trim(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                    if (t.seatedMinutes != null) ...[
                      const SizedBox(height: 4),
                      Text('Seated ${t.seatedMinutes} min ago', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: t.seatedMinutes! > 15 ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
                      )),
                    ],
                  ],
                ),
              ),
              if (t.orderId != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (t.status == _TableStatus.paid) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final currentMember = await AuthService.getCurrentMember();
                            await RestaurantService.completeParentOrder(t.orderId!, currentMember?.userName ?? 'Unknown', createSaleTransaction: false);
                            _loadData();
                          },
                          icon: const Icon(Icons.cleaning_services, size: 16, color: Color(0xFF10B981)),
                          label: const Text('Clear Table', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF10B981)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final currentMember = await AuthService.getCurrentMember();
                            await RestaurantService.completeParentOrder(t.orderId!, currentMember?.userName ?? 'Unknown', createSaleTransaction: true);
                            _loadData();
                          },
                          icon: const Icon(Icons.payments, size: 16, color: Colors.greenAccent),
                          label: const Text('Pay Full', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.greenAccent.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showSplitBillDialog(t.orderId!, t.orderInfo!.split('•').last.trim());
                          },
                          icon: const Icon(Icons.call_split, size: 16, color: Colors.white),
                          label: const Text('Split Bill', style: TextStyle(color: Colors.white, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showTransferTableDialog(t.orderId!, t.tableNumber);
                        },
                        icon: const Icon(Icons.merge_type, size: 16, color: Colors.white),
                        label: const Text('Transfer', style: TextStyle(color: Colors.white, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _showSplitBillDialog(int orderId, String currentTotal) {
    final rawTotal = double.tryParse(currentTotal.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SplitBillScreen(
          orderId: orderId,
          currentTotalText: currentTotal,
          initiallyParsedTotal: rawTotal,
        ),
      ),
    ).then((changed) {
      if (changed == true) _loadData();
    });
  }

  void _showTransferTableDialog(int orderId, String currentTable) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TableTransferScreen(
          orderId: orderId,
          currentTableNumber: currentTable,
        ),
      ),
    ).then((changed) {
      if (changed == true) _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableCount = _tables.where((t) => t.status == _TableStatus.available).length;
    final occupiedCount = _tables.where((t) => t.status != _TableStatus.available).length;

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: Stack(
        children: [
          Column(
            children: [
              // ─── App Bar ─────────────────────
          Container(
            color: const Color(0xFF111827),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22), onPressed: () => Navigator.pop(context)),
                    const Text('Live Table Map', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _loadData,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.refresh, size: 18, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ─── Status Legend ─────────────────────
          Container(
            color: const Color(0xFF1F2937),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildLegendDot(const Color(0xFF10B981), 'Available', availableCount),
                const SizedBox(width: 10),
                _buildLegendDot(const Color(0xFFF59E0B), 'Occupied', occupiedCount),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                  child: Text('Auto-refresh 5s', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.grey[600])),
                ),
              ],
            ),
          ),
          // ─── Map Canvas ─────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                : _tables.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.table_restaurant, size: 48, color: Colors.grey[700]),
                            const SizedBox(height: 8),
                            Text('No floor plan set up yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text('Use Floor Plan Editor to add tables', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final canvasW = 2500.0;
                          final canvasH = 2500.0;

                          return InteractiveViewer(
                            transformationController: SharedMapState.viewerController,
                            minScale: 0.1,
                            maxScale: 3.0,
                            constrained: false,
                            boundaryMargin: const EdgeInsets.all(2000),
                            child: SizedBox(
                              width: canvasW,
                              height: canvasH,
                              child: Stack(
                              children: [
                                RepaintBoundary(
                                  child: CustomPaint(size: Size(canvasW, canvasH), painter: _MapGridPainter()),
                                ),
                              ..._tables.asMap().entries.map((entry) {
                                final i = entry.key;
                                final t = entry.value;
                                final color = _statusColor(t.status);
                                final emoji = _statusEmoji(t);
                                final isSelected = _selectedIndex == i;
                                final tableSize = t.shape == 'rectangle' ? const Size(76, 48) : const Size(56, 56);

                                return Positioned(
                                  left: (t.x * canvasW) - tableSize.width / 2,
                                  top: (t.y * canvasH) - tableSize.height / 2,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedIndex = i);
                                      _showTableDetail(i);
                                    },
                                  child: AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      final isPulsing = t.status == _TableStatus.foodReady || t.status == _TableStatus.needsAttention;
                                      final pulseGlow = isPulsing ? _pulseAnimation.value * 8 : 0.0;
                                      
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        width: tableSize.width,
                                        height: tableSize.height,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(t.status == _TableStatus.available ? 0.05 : 0.25),
                                          borderRadius: BorderRadius.circular(
                                            t.shape == 'round' ? 28 : t.shape == 'booth' ? 6 : 10,
                                          ),
                                          border: Border.all(color: color, width: isSelected ? 3 : 2),
                                          boxShadow: [
                                            if (isPulsing)
                                              BoxShadow(color: color.withOpacity(0.5), blurRadius: 10 + pulseGlow, spreadRadius: pulseGlow / 3),
                                            if (isSelected)
                                              BoxShadow(color: color.withOpacity(0.4), blurRadius: 12),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if (emoji.isNotEmpty) Text(emoji, style: const TextStyle(fontSize: 12)),
                                            Text(t.tableNumber, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
                                            if (t.seatedMinutes != null)
                                              Text('${t.seatedMinutes}m', style: TextStyle(
                                                fontSize: 7, fontWeight: FontWeight.w800,
                                                color: t.seatedMinutes! > 15 ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
                                              )),
                                          ],
                                        ),
                                      );
                                    }
                                  ),
                                  ),
                                );
                              }),
                            ],
                          ),
                          ),
                        );
                      },
                      ),
          ),
        ],
      ),
      const InteractiveHelpScroll(contextKey: 'tables'),
      ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 4),
        Text('$label: $count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400])),
      ],
    );
  }
}

// ─── GRID PAINTER ────────────────────────────────────────────────────────────

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1F2937)..strokeWidth = 0.5;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── MODELS ──────────────────────────────────────────────────────────────────

enum _TableStatus { available, occupied, needsAttention, reserved, foodReady, paid }

class _LiveTable {
  final String tableNumber;
  final String? label;
  final String shape;
  final int seats;
  final double x, y;
  final String zone;
  final _TableStatus status;
  final int? orderId;
  final String? orderInfo;
  final List<String> menuItems;
  final int? seatedMinutes;
  final String? orderStatus;

  const _LiveTable({
    required this.tableNumber,
    this.label,
    this.shape = 'round',
    this.seats = 4,
    this.x = 0.5,
    this.y = 0.5,
    this.zone = 'Main Hall',
    this.status = _TableStatus.available,
    this.orderId,
    this.orderInfo,
    this.menuItems = const [],
    this.seatedMinutes,
    this.orderStatus,
  });
}
