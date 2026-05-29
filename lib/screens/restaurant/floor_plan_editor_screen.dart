// ============================================================================
// FLOOR PLAN EDITOR — Setup mode for drag-and-drop table placement
// ============================================================================

import 'package:flutter/material.dart';
import 'shared_map_state.dart';
import '../../db/db_provider.dart';
import '../../services/event_service.dart';
import '../../theme/design_system.dart';

class FloorPlanEditorScreen extends StatefulWidget {
  const FloorPlanEditorScreen({super.key});

  @override
  State<FloorPlanEditorScreen> createState() => _FloorPlanEditorScreenState();
}

class _FloorPlanEditorScreenState extends State<FloorPlanEditorScreen> with SingleTickerProviderStateMixin {
  List<_FloorTable> _tables = [];
  bool _isLoading = true;
  bool _isDirty = false;
  int? _selectedIndex;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<String> _zones = ['Main Hall', 'Patio', 'VIP', 'Bar', 'Terrace'];
  final List<String> _shapes = ['round', 'square', 'rectangle', 'booth'];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.5).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _loadFloorPlan();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadFloorPlan() async {
    final db = await DbProvider.db;
    final rows = await db.query('restaurant_floor_plan', orderBy: 'id ASC');
    if (mounted) {
      setState(() {
        _tables = rows.map((r) => _FloorTable(
          tableNumber: r['table_number'] as String,
          label: r['label'] as String?,
          shape: r['shape'] as String? ?? 'round',
          seats: r['seats'] as int? ?? 4,
          x: (r['x'] as num?)?.toDouble() ?? 0.5,
          y: (r['y'] as num?)?.toDouble() ?? 0.5,
          zone: r['zone'] as String? ?? 'Main Hall',
        )).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveFloorPlan() async {
    // Save to local DB
    final db = await DbProvider.db;
    await db.transaction((txn) async {
      await txn.delete('restaurant_floor_plan');
      for (final t in _tables) {
        await txn.insert('restaurant_floor_plan', {
          'table_number': t.tableNumber,
          'label': t.label,
          'shape': t.shape,
          'seats': t.seats,
          'x': t.x,
          'y': t.y,
          'zone': t.zone,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });

    // Emit event for LAN sync
    await EventService.emitEvent(
      eventType: 'FLOOR_PLAN_UPDATE',
      payload: {
        'tables': _tables.map((t) => {
          'table_number': t.tableNumber,
          'label': t.label,
          'shape': t.shape,
          'seats': t.seats,
          'x': t.x,
          'y': t.y,
          'zone': t.zone,
        }).toList(),
      },
    );

    setState(() => _isDirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Floor plan saved & synced to LAN'), backgroundColor: Color(0xFF10B981)),
      );
    }
  }

  void _addTable() {
    final nextNum = _tables.isEmpty ? 1 : _tables.map((t) => int.tryParse(t.tableNumber.replaceAll('T-', '')) ?? 0).reduce((a, b) => a > b ? a : b) + 1;
    setState(() {
      _tables.add(_FloorTable(
        tableNumber: 'T-$nextNum',
        shape: 'round',
        seats: 4,
        x: 0.5,
        y: 0.5,
        zone: 'Main Hall',
      ));
      _selectedIndex = _tables.length - 1;
      _isDirty = true;
    });
  }

  void _deleteTable(int index) {
    setState(() {
      _tables.removeAt(index);
      _selectedIndex = null;
      _isDirty = true;
    });
  }

  void _showEditDialog(int index) {
    final t = _tables[index];
    final numberCtrl = TextEditingController(text: t.tableNumber);
    final labelCtrl = TextEditingController(text: t.label ?? '');
    final seatsCtrl = TextEditingController(text: t.seats.toString());
    String shape = t.shape;
    String zone = t.zone;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Edit Table', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
              const SizedBox(height: 16),
              // Table number
              _buildField('Table Number', numberCtrl),
              const SizedBox(height: 10),
              _buildField('Label (optional)', labelCtrl),
              const SizedBox(height: 10),
              _buildField('Seats', seatsCtrl, isNumber: true),
              const SizedBox(height: 12),
              // Shape selector
              const Text('Shape', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: _shapes.map((s) => GestureDetector(
                  onTap: () => setSheetState(() => shape = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: shape == s ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: shape == s ? const Color(0xFF10B981) : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_shapeIcon(s), size: 14, color: shape == s ? const Color(0xFF10B981) : const Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(s[0].toUpperCase() + s.substring(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: shape == s ? const Color(0xFF10B981) : const Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 12),
              // Zone selector
              const Text('Zone', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: _zones.map((z) => GestureDetector(
                  onTap: () => setSheetState(() => zone = z),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: zone == z ? const Color(0xFF3B82F6).withOpacity(0.1) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: zone == z ? const Color(0xFF3B82F6) : Colors.transparent),
                    ),
                    child: Text(z, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: zone == z ? const Color(0xFF3B82F6) : const Color(0xFF6B7280))),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Delete button
                  Expanded(
                    child: GestureDetector(
                      onTap: () { Navigator.pop(ctx); _deleteTable(index); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(child: Text('Delete', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFEF4444)))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Apply button
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _tables[index] = _FloorTable(
                            tableNumber: numberCtrl.text,
                            label: labelCtrl.text.isEmpty ? null : labelCtrl.text,
                            shape: shape,
                            seats: int.tryParse(seatsCtrl.text) ?? 4,
                            x: _tables[index].x,
                            y: _tables[index].y,
                            zone: zone,
                          );
                          _isDirty = true;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(child: Text('Apply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white))),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      numberCtrl.dispose();
      labelCtrl.dispose();
      seatsCtrl.dispose();
    });
  }

  Widget _buildField(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
          ),
        ),
      ],
    );
  }

  IconData _shapeIcon(String shape) {
    switch (shape) {
      case 'round': return Icons.circle_outlined;
      case 'square': return Icons.crop_square;
      case 'rectangle': return Icons.rectangle_outlined;
      case 'booth': return Icons.event_seat;
      default: return Icons.circle_outlined;
    }
  }

  Color _zoneColor(String zone) {
    switch (zone) {
      case 'VIP': return const Color(0xFFF59E0B);
      case 'Patio': return const Color(0xFF10B981);
      case 'Bar': return const Color(0xFF8B5CF6);
      case 'Terrace': return const Color(0xFF0891B2);
      default: return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: Column(
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text('Floor Plan Editor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3)),
                    const Spacer(),
                    if (_isDirty)
                      GestureDetector(
                        onTap: _saveFloorPlan,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // ─── Zone legend ─────────────────────
          Container(
            color: const Color(0xFF1F2937),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _zones.map((z) {
                        final count = _tables.where((t) => t.zone == z).length;
                        if (count == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: _zoneColor(z), borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: 4),
                              Text('$z ($count)', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Text('${_tables.length} tables', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          // ─── Canvas ─────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
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
                          child: GestureDetector(
                            onTapUp: (details) => setState(() => _selectedIndex = null),
                            child: Stack(
                            children: [
                              // Grid
                              RepaintBoundary(
                                child: CustomPaint(
                                  size: Size(canvasW, canvasH),
                                  painter: _GridPainter(),
                                ),
                              ),
                            // Tables
                            ..._tables.asMap().entries.map((entry) {
                              final i = entry.key;
                              final t = entry.value;
                              final isSelected = _selectedIndex == i;
                              final tableSize = t.shape == 'rectangle' ? const Size(72, 44) : const Size(52, 52);

                              return Positioned(
                                left: 0,
                                top: 0,
                                child: StatefulBuilder(
                                  builder: (context, setStateLocal) {
                                    final t = _tables[i];
                                    final isSelected = _selectedIndex == i;
                                    return Transform.translate(
                                      offset: Offset((t.x * canvasW) - tableSize.width / 2, (t.y * canvasH) - tableSize.height / 2),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() => _selectedIndex = i);
                                        },
                                        onDoubleTap: () => _showEditDialog(i),
                                        onPanUpdate: (details) {
                                          setStateLocal(() {
                                            final newX = (t.x + details.delta.dx / canvasW).clamp(0.05, 0.95);
                                            final newY = (t.y + details.delta.dy / canvasH).clamp(0.05, 0.95);
                                            _tables[i] = _FloorTable(
                                              tableNumber: t.tableNumber,
                                              label: t.label,
                                              shape: t.shape,
                                              seats: t.seats,
                                              x: newX,
                                              y: newY,
                                              zone: t.zone,
                                            );
                                            _selectedIndex = i;
                                            _isDirty = true;
                                          });
                                          // Force parent toolbar to update dirty state
                                          if (!_isDirty) setState(() {});
                                        },
                                        onPanEnd: (details) => setState(() {}),
                                        child: AnimatedBuilder(
                                          animation: _pulseAnimation,
                                          builder: (context, child) {
                                            final pulseSpread = isSelected ? _pulseAnimation.value * 5 : 0.0;
                                            return AnimatedContainer(
                                              duration: const Duration(milliseconds: 100),
                                              width: tableSize.width,
                                              height: tableSize.height,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? _zoneColor(t.zone).withOpacity(0.3)
                                                    : _zoneColor(t.zone).withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(
                                                  t.shape == 'round' ? 26 : t.shape == 'booth' ? 6 : 10,
                                                ),
                                                border: Border.all(
                                                  color: isSelected ? _zoneColor(t.zone) : _zoneColor(t.zone).withOpacity(0.3),
                                                  width: isSelected ? 2.5 : 1.5,
                                                ),
                                                boxShadow: isSelected
                                                    ? [BoxShadow(color: _zoneColor(t.zone).withOpacity(0.4), blurRadius: 10 + pulseSpread, spreadRadius: pulseSpread / 2)]
                                                    : null,
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(t.tableNumber, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _zoneColor(t.zone))),
                                                  Text('${t.seats}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
                                                ],
                                              ),
                                            );
                                          }
                                        ),
                                      ),
                                    );
                                  }
                                ),
                              );
                            }),
                            // Hint
                            if (_tables.isEmpty)
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.table_restaurant, size: 48, color: Colors.grey[700]),
                                    const SizedBox(height: 8),
                                    Text('Tap + to add your first table', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[600])),
                                    const SizedBox(height: 4),
                                    Text('Drag tables to position, double-tap to edit', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      ),
                    );
                  },
                  ),
          ),
          // ─── Bottom bar ─────────────────────
          Container(
            color: const Color(0xFF1F2937),
            padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
            child: Row(
              children: [
                if (_selectedIndex != null) ...[
                  GestureDetector(
                    onTap: () => _showEditDialog(_selectedIndex!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 14, color: Color(0xFF3B82F6)),
                          SizedBox(width: 4),
                          Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF3B82F6))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _deleteTable(_selectedIndex!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete, size: 14, color: Color(0xFFEF4444)),
                          SizedBox(width: 4),
                          Text('Delete', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: _addTable,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 18, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Add Table', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── GRID PAINTER ────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1F2937)
      ..strokeWidth = 0.5;

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

// ─── MODEL ───────────────────────────────────────────────────────────────────

class _FloorTable {
  final String tableNumber;
  final String? label;
  final String shape;
  final int seats;
  final double x;
  final double y;
  final String zone;

  const _FloorTable({
    required this.tableNumber,
    this.label,
    this.shape = 'round',
    this.seats = 4,
    this.x = 0.5,
    this.y = 0.5,
    this.zone = 'Main Hall',
  });
}
