import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../db/db_provider.dart';
import '../../services/event_service.dart';
import '../../services/auth_service.dart';
import 'package:uuid/uuid.dart';
import '../../theme/design_system.dart';
import '../../widgets/standard_app_bar.dart';
import '../../widgets/waiter_rings_bell_button.dart';
import '../../widgets/interactive_help_scroll.dart';

class RestaurantPosScreen extends StatefulWidget {
  const RestaurantPosScreen({super.key});

  @override
  State<RestaurantPosScreen> createState() => _RestaurantPosScreenState();
}

class _RestaurantPosScreenState extends State<RestaurantPosScreen> with SingleTickerProviderStateMixin {
  // Menu Data
  List<Map<String, dynamic>> _menuItems = [];
  List<String> _categories = [];
  bool _isLoading = true;
  TabController? _tabController;

  // Cart/Order Data (Optimized with ValueNotifier)
  // Each map represents a line item: { id: int, qty: int, course_id: int }
  final ValueNotifier<List<Map<String, dynamic>>> _cartNotifier = ValueNotifier([]);
  
  final TextEditingController _tableCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  String _orderType = 'dine_in'; // dine_in, takeaway

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _cartNotifier.dispose();
    _tableCtrl.dispose();
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    try {
      final db = await DbProvider.db;
      final items = await db.query('restaurant_menu', where: 'available = 1', orderBy: 'name ASC');
      
      final cats = <String>{'All'};
      for (var item in items) {
        if (item['category'] != null) cats.add(item['category'] as String);
      }
      
      if (mounted) {
        setState(() {
          _menuItems = items;
          _categories = cats.toList()..sort();
          _isLoading = false;
          _tabController?.dispose();
          _tabController = TabController(length: _categories.length, vsync: this);
        });
      }
    } catch (e) {
      debugPrint('Error loading menu: $e');
    }
  }

  List<Map<String, dynamic>> _getItemsByCategory(String category) {
    if (category == 'All') return _menuItems;
    return _menuItems.where((item) => item['category'] == category).toList();
  }

  void _addToCart(int itemId, {int courseId = 1}) {
    final currentCart = List<Map<String, dynamic>>.from(_cartNotifier.value);
    
    // Check if item exists in the same course to increment quantity
    final existingIdx = currentCart.indexWhere((i) => i['id'] == itemId && i['course_id'] == courseId);
    
    if (existingIdx >= 0) {
      currentCart[existingIdx]['qty'] = (currentCart[existingIdx]['qty'] as int) + 1;
    } else {
      currentCart.add({'id': itemId, 'qty': 1, 'course_id': courseId});
    }
    
    _cartNotifier.value = currentCart;
  }

  void _removeFromCart(int itemId, {int courseId = 1}) {
    final currentCart = List<Map<String, dynamic>>.from(_cartNotifier.value);
    final existingIdx = currentCart.indexWhere((i) => i['id'] == itemId && i['course_id'] == courseId);
    
    if (existingIdx >= 0) {
      final newQty = (currentCart[existingIdx]['qty'] as int) - 1;
      if (newQty <= 0) {
        currentCart.removeAt(existingIdx);
      } else {
        currentCart[existingIdx]['qty'] = newQty;
      }
      _cartNotifier.value = currentCart;
    }
  }

  double _calculateTotal() {
    double total = 0;
    for (var cartItem in _cartNotifier.value) {
      final itemId = cartItem['id'];
      final qty = cartItem['qty'] as int;
      final item = _menuItems.firstWhere((i) => i['id'] == itemId);
      total += (item['price'] as num) * qty;
    }
    return total;
  }

  Future<void> _submitOrder() async {
    final cart = _cartNotifier.value;
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_orderType == 'dine_in' && _tableCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a table number for Dine-In orders.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final db = await DbProvider.db;
      final total = _calculateTotal();
      final orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      final cloudId = const Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Fetch member outside transaction to prevent SQL deadlock
      final currentMember = await AuthService.getCurrentMember();
      final createdBy = currentMember?.userName ?? 'Unknown';

      // Materialize the items immediately to preserve names and historical prices
      final itemsList = cart.map((cartItem) {
        final itemId = cartItem['id'];
        final qty = cartItem['qty'] as int;
        final courseId = cartItem['course_id'] as int;
        final item = _menuItems.firstWhere((i) => i['id'] == itemId);
        
        return {
          'menu_item_id': item['id'],
          'menu_item_name': item['name'],
          'course_id': courseId,
          'quantity': qty,
          'unit_price': item['price'],
          'subtotal': (item['price'] as num) * qty,
        };
      }).toList();

      await db.transaction((txn) async {
        // 1. Create Order
        final orderId = await txn.insert('restaurant_orders', {
          'cloud_id': cloudId,
          'source_module': 'restaurant',
          'order_number': orderNumber,
          'order_type': _orderType,
          'table_number': _tableCtrl.text,
          'customer_name': _nameCtrl.text,
          'items_json': jsonEncode(itemsList), // Fixed to use fully materialized reference map
          'subtotal': total,
          'total': total,
          'status': 'pending',
          'notes': _noteCtrl.text,
          'created_by': createdBy,
          'created_at': now,
          'updated_at': now,
        });

        // 2. Create Order Items mapping the new Course ID
        for (var cartItem in cart) {
          final itemId = cartItem['id'];
          final qty = cartItem['qty'] as int;
          final courseId = cartItem['course_id'] as int;
          final item = _menuItems.firstWhere((i) => i['id'] == itemId);
          
          await txn.insert('restaurant_order_items', {
            'order_id': orderId,
            'menu_item_id': item['id'],
            'menu_item_name': item['name'],
            'course_id': courseId,
            'quantity': qty,
            'unit_price': item['price'],
            'subtotal': (item['price'] as num) * qty,
            'status': 'pending',
          });
        }
      });

    // Auto-create floor plan table if it doesn't exist
    if (_orderType == 'dine_in' && _tableCtrl.text.trim().isNotEmpty) {
      try {
        final tableNum = _tableCtrl.text.trim();
        final existing = await db.query('restaurant_floor_plan',
            where: 'table_number = ?', whereArgs: [tableNum], limit: 1);
        if (existing.isEmpty) {
          final tableCount = (await db.rawQuery(
              'SELECT COUNT(*) as cnt FROM restaurant_floor_plan')).first['cnt'] as int? ?? 0;
          final row = tableCount ~/ 5;
          final col = tableCount % 5;
          await db.insert('restaurant_floor_plan', {
            'table_number': tableNum,
            'shape': 'round',
            'seats': 4,
            'x': 0.1 + (col * 0.18),
            'y': 0.1 + (row * 0.18),
            'zone': 'Main Hall',
            'created_at': now,
            'updated_at': now,
          });
          debugPrint('🍽️ Auto-created floor plan table: $tableNum');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to auto-create floor plan table (non-fatal): $e');
      }
    }

    // Emit event for LAN sync to other devices
      await EventService.emitEvent(
        eventType: 'ORDER_CREATED',
        timestamp: now,
        payload: {
          'cloud_id': cloudId,
          'source_module': 'restaurant',
          'order_number': orderNumber,
          'order_type': _orderType,
          'table_number': _tableCtrl.text,
          'customer_name': _nameCtrl.text,
          'items_json': jsonEncode(cart),
          'total': total,
          'status': 'pending',
          'notes': _noteCtrl.text,
          'items': itemsList,
          'created_at': now,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order #$orderNumber placed!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      debugPrint('Error placing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final useSplitLayout = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      appBar: const StandardAppBar(
        title: 'New Order',
        actions: [WaiterRingsBellButton()],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : useSplitLayout
                  ? _buildSplitLayout()
                  : _buildMobileLayout(),
          const InteractiveHelpScroll(contextKey: 'pos'),
        ],
      ),
    );
  }

  Widget _buildSplitLayout() {
    return Container(
      color: AppColors.gray50, // Matches the HTML background
      child: Column(
        children: [
          _buildCategoryTabs(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildMenuGrid(crossAxisCount: 3),
                ),
                Expanded(
                  flex: 2, // Give cart more space (40%)
                  child: _buildCartSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      color: AppColors.gray50,
      child: Stack(
        children: [
          Column(
            children: [
              _buildCategoryTabs(),
              Expanded(child: _buildMenuGrid(crossAxisCount: 2)),
            ],
          ),
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _cartNotifier,
            builder: (context, cart, child) {
              if (cart.isEmpty) return const SizedBox.shrink();
              return Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  heroTag: "restaurant_pos_fab",
                  onPressed: () => _showMobileTray(),
                  label: Text('View Tray (${cart.length} items)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  icon: const Icon(Icons.shopping_basket),
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppColors.primaryGreen,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.primaryGreen,
        tabs: _categories.map((c) => Tab(text: c)).toList(),
      ),
    );
  }

  Widget _buildMenuGrid({required int crossAxisCount}) {
    return TabBarView(
      controller: _tabController,
      children: _categories.map((cat) {
        final items = _getItemsByCategory(cat);
        return GridView.builder(
          padding: const EdgeInsets.all(16).copyWith(bottom: 80), // Pad bottom for FAB
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.85,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _cartNotifier,
              builder: (context, cart, child) {
                // Determine cumulative quantity across all courses for grid UI shortcut
                int totalQty = 0;
                for (var ci in cart) {
                  if (ci['id'] == item['id']) totalQty += ci['qty'] as int;
                }
                
                final isSelected = totalQty > 0;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryGreen : AppColors.gray200,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: const [AppShadows.sm],
                  ),
                  child: InkWell(
                    onTap: () => _showCourseSelectionModal(item),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Image Section
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg - 1)),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final imgPath = item['image_path'] as String?;
                                    if (imgPath != null && imgPath.isNotEmpty && File(imgPath).existsSync()) {
                                      return Image.file(
                                        File(imgPath),
                                        fit: BoxFit.cover,
                                        cacheWidth: 300,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: AppColors.gray100,
                                          child: const Icon(Icons.restaurant, color: AppColors.gray400, size: 40),
                                        ),
                                      );
                                    }
                                    return Container(
                                      color: AppColors.gray100,
                                      child: const Icon(Icons.restaurant, color: AppColors.gray400, size: 40),
                                    );
                                  },
                                ),
                                // Gradient Overlay
                                Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  height: 60,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                                      ),
                                    ),
                                  ),
                                ),
                                // Category Tag
                                if (item['category'] != null)
                                  Positioned(
                                    top: 8, left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        item['category'],
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Details Section
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'],
                                style: AppTypography.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.gray900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'KES ${item['price']}',
                                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$totalQty',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  else
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.gray100,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(Icons.add, size: 16, color: AppColors.gray600),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      }).toList(),
    );
  }

  void _showCourseSelectionModal(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select kitchen course for this item:'),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryGreen,
              ),
              onPressed: () {
                _addToCart(item['id'], courseId: 1);
                Navigator.pop(ctx);
              },
              child: const Text('Course 1 (Appetizers / Starters)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryGreen,
              ),
              onPressed: () {
                _addToCart(item['id'], courseId: 2);
                Navigator.pop(ctx);
              },
              child: const Text('Course 2 (Mains)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryGreen,
              ),
              onPressed: () {
                _addToCart(item['id'], courseId: 3);
                Navigator.pop(ctx);
              },
              child: const Text('Course 3 (Desserts / Drinks)'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileTray() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Current Tray', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(child: _buildCartSection(scrollController: controller)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartSection({ScrollController? scrollController}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [AppShadows.md], // Left edge shadow for desktop split
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Actions
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.gray200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text('Current Order', style: AppTypography.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: _cartNotifier,
                  builder: (context, cart, child) {
                    if (cart.isEmpty) return const SizedBox.shrink();
                    return TextButton.icon(
                      onPressed: () {
                        // Confirm clear
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Clear Cart?'),
                            content: const Text('Are you sure you want to remove all items?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () {
                                  _cartNotifier.value = [];
                                  Navigator.pop(ctx);
                                },
                                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Order Details inputs
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _orderType,
                        decoration: InputDecoration(
                          labelText: 'Type',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'dine_in', child: Text('Dine In')),
                          DropdownMenuItem(value: 'takeaway', child: Text('Takeaway')),
                          DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
                        ],
                        onChanged: (v) => setState(() => _orderType = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _tableCtrl,
                        decoration: InputDecoration(
                          labelText: 'Table #',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                        ),
                        keyboardType: TextInputType.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Customer Name (Optional)',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Kitchen Notes (e.g. no onions)',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                    prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.gray200, thickness: 4),
          
          // Cart Items List (Listens to Notifier)
          Expanded(
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _cartNotifier,
              builder: (context, cart, child) {
                if (cart.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_basket_outlined, size: 60, color: AppColors.gray300),
                        const SizedBox(height: 16),
                        Text('Your tray is empty', style: AppTypography.textTheme.titleMedium?.copyWith(color: AppColors.gray500)),
                        const SizedBox(height: 8),
                        Text('Tap items on the menu to add them', style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.gray400)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: cart.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final cartItem = cart[index];
                    final itemId = cartItem['id'];
                    final qty = cartItem['qty'] as int;
                    final courseId = cartItem['course_id'] as int;
                    final item = _menuItems.firstWhere((i) => i['id'] == itemId);
                    
                    final courseLabel = courseId == 1 ? 'Start' : (courseId == 2 ? 'Main' : 'Dessert');
                    
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Quantity controls
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.gray200),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 20),
                                onPressed: () => _removeFromCart(itemId, courseId: courseId),
                                color: qty == 1 ? AppColors.danger : AppColors.gray600,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                padding: EdgeInsets.zero,
                              ),
                              Container(
                                width: 24,
                                alignment: Alignment.center,
                                child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 20),
                                onPressed: () => _addToCart(itemId, courseId: courseId),
                                color: AppColors.primaryGreen,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Item Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.gray200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(courseLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('KES ${item['price']}', style: const TextStyle(color: AppColors.gray500, fontSize: 13)),
                                  ],
                                ),
                              ],
                          ),
                        ),
                        // Subtotal
                        Text(
                          'KES ${(item['price'] as num) * qty}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          
          // Footer / Submit
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: const [
                BoxShadow(color: Colors.black12, offset: Offset(0, -4), blurRadius: 10),
              ],
            ),
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _cartNotifier,
              builder: (context, cart, child) {
                final total = _calculateTotal();
                final isCartEmpty = cart.isEmpty;
                
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Amount', style: AppTypography.textTheme.titleMedium?.copyWith(color: AppColors.gray600)),
                        Text('KES $total', style: AppTypography.textTheme.headlineSmall?.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: isCartEmpty ? null : _submitOrder,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        disabledBackgroundColor: AppColors.gray300,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                      ),
                      child: Text(
                        'PLACE ORDER',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: isCartEmpty ? AppColors.gray500 : Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
