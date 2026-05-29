import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/shop_session_provider.dart';

class RestaurantMenuScreen extends StatefulWidget {
  final String shopId;
  final String shopName;

  const RestaurantMenuScreen({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  String _activeCategory = 'Grill';
  int _orderItemCount = 0;
  int _orderTotalCost = 0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _menuItems = [];
  final List<Map<String, dynamic>> _orderCart = [];

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  Future<void> _loadMenuItems() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final session = Provider.of<ShopSessionProvider>(context, listen: false);
      final api = session.api;
      if (api != null) {
        final items = await api.getRestaurantMenu();
        if (mounted) {
          setState(() {
            _menuItems = items;
            _isLoading = false;
            if (items.isNotEmpty) {
              final Set<String> cats = items.map((i) => i['category'] as String? ?? 'Grill').toSet();
              if (cats.isNotEmpty && !cats.contains(_activeCategory)) {
                _activeCategory = cats.first;
              }
            }
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading restaurant menu: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get _availableCount => _menuItems.where((i) => i['available'] == 1 || i['available'] == true || i['available'].toString() == '1').length;

  @override
  Widget build(BuildContext context) {
    final filteredItems = _menuItems.where((i) => i['category'] == _activeCategory).toList();

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFC7F900),
      ),
      child: Scaffold(
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
                : _menuItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('No menu items available.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
                              child: const Text('Go Back'),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: CustomScrollView(
                              slivers: [
                                // 1. Bistro Cover Header
                                _buildPromoHeader(),

                                // 2. Category Row
                                SliverToBoxAdapter(
                                  child: _buildCategoryRow(),
                                ),

                                // 3. Menu list
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) => _buildMenuItemCard(filteredItems[index]),
                                      childCount: filteredItems.length,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
            
            // 4. Floating bottom order status bar
            if (_orderItemCount > 0)
              _buildBottomFloatingOrderBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoHeader() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF0C0C0C),
      leading: CircleAvatar(
        backgroundColor: Colors.black.withOpacity(0.5),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: const Text(
        'BISTRO PRIME',
        style: TextStyle(
          color: Color(0xFF00FF88),
          fontWeight: FontWeight.w900,
          fontSize: 16,
          letterSpacing: 1.5,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1544025162-d76694265947?q=80&w=1000&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
            ),
            // Promotions Content overlaid inside image bottom
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade900, width: 0.5),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NYAMA CHOMA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Slow-grilled premium cuts seasoned with traditional rock salt and served with kachumbari.',
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow() {
    final Set<String> categorySet = {'Grill'};
    if (_menuItems.isNotEmpty) {
      categorySet.clear();
      for (var item in _menuItems) {
        if (item['category'] != null && item['category'].toString().isNotEmpty) {
          categorySet.add(item['category'].toString());
        }
      }
    }
    final categories = categorySet.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Uber Eats-inspired Delivery/Status Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade900, width: 0.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, color: Color(0xFF00FF88), size: 16),
                    SizedBox(width: 6),
                    Text(
                      '15-25 mins',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.circle, color: Color(0xFF00FF88), size: 8),
                    SizedBox(width: 6),
                    Text(
                      'Open Now',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.delivery_dining, color: Color(0xFF00FF88), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'KES 150 Delivery',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Horizontal Categories List
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            children: categories.map((cat) {
              final isSelected = _activeCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _activeCategory = cat),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF00FF88) : const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected ? null : Border.all(color: Colors.grey.shade900),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.grey,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItemCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C1C1E)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Image
          SizedBox(
            width: 100,
            height: 100,
            child: (item['image'] ?? item['image_path']) != null
                ? Image.network(
                    item['image'] ?? item['image_path'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.restaurant, color: Colors.grey),
                  )
                : const Icon(Icons.restaurant, color: Colors.grey),
          ),
          
          // Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      Text(
                        'KES ${item['price']}',
                        style: const TextStyle(
                          color: Color(0xFF00FF88),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['description'],
                    style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Rating + Add control
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            item['rating'].toString(),
                            style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      // Add Button
                      GestureDetector(
                        onTap: () => _addItemToOrder(item),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF00FF88),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.black, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addItemToOrder(Map<String, dynamic> item) {
    int itemPrice = item['price'] as int;
    String itemName = item['name'] as String;
    String selectedSide = 'Truffle Mash';
    String spiceLevel = 'Medium';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customize $itemName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  
                  // Side selection
                  const Text('Select Side (Choose 1)', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Truffle Mash', 'French Fries', 'Steamed Veggies'].map((side) {
                      final bool isSelected = selectedSide == side;
                      return ChoiceChip(
                        label: Text(side),
                        selected: isSelected,
                        selectedColor: const Color(0xFF00FF88),
                        onSelected: (val) {
                          setModalState(() => selectedSide = side);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  
                  // Spice level
                  const Text('Spice Level', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Mild', 'Medium', 'Hot'].map((spice) {
                      final bool isSelected = spiceLevel == spice;
                      return ChoiceChip(
                        label: Text(spice),
                        selected: isSelected,
                        selectedColor: const Color(0xFF00FF88),
                        onSelected: (val) {
                          setModalState(() => spiceLevel = spice);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF88),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setState(() {
                          _orderItemCount++;
                          _orderTotalCost += itemPrice;
                          _orderCart.add({
                            'name': itemName,
                            'price': itemPrice,
                            'qty': 1,
                            'notes': 'Side: $selectedSide, Spice: $spiceLevel',
                          });
                        });
                        Navigator.pop(ctx); // Close sheet
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added $itemName ($selectedSide, $spiceLevel spice) to order!'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Text('Add to Order', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildBottomFloatingOrderBar() {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFF00FF88),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF88).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: _submitOrder,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: Colors.black),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'View Order ($_orderItemCount Items)',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ),
                  Text(
                    'KES $_orderTotalCost',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitOrder() async {
    final session = Provider.of<ShopSessionProvider>(context, listen: false);
    final api = session.api;
    if (api == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Confirm Order'),
        content: Text('Submit order for KES $_orderTotalCost?'),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text('Place Order', style: TextStyle(color: Color(0xFF00FF88))),
            onPressed: () async {
              Navigator.pop(ctx); // Close confirm dialog
              
              // Show progress indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingCtx) => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))),
              );

              try {
                // Submit order to Supabase kitchen_queue
                final success = await api.pingOrder(
                  module: 'restaurant',
                  items: _orderCart.map((i) => {
                    'name': i['name'],
                    'price': i['price'],
                    'qty': i['qty'] ?? 1,
                    'notes': i['notes'] ?? '',
                  }).toList(),
                  customerName: 'Buyer',
                  tableNumber: 'Table 5', // simulated table number
                );

                if (mounted) Navigator.pop(context); // Close loading dialog

                if (success) {
                  setState(() {
                    _orderItemCount = 0;
                    _orderTotalCost = 0;
                    _orderCart.clear();
                  });
                  
                  showDialog(
                    context: context,
                    builder: (successCtx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E),
                      title: const Text('Order Placed!'),
                      content: const Text('Your meal is being prepared. Check progress in Activity dashboard.'),
                      actions: [
                        TextButton(
                          child: const Text('OK', style: TextStyle(color: Color(0xFF00FF88))),
                          onPressed: () {
                            Navigator.pop(successCtx);
                            Navigator.pop(context); // Back to showcase
                          },
                        )
                      ],
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to submit order to kitchen.'), backgroundColor: Colors.redAccent),
                  );
                }
              } catch (e) {
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Order submission failed: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
