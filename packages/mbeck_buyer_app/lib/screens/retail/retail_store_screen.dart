import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/shop_session_provider.dart';

class RetailStoreScreen extends StatefulWidget {
  final String shopId;
  final String shopName;

  const RetailStoreScreen({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  @override
  State<RetailStoreScreen> createState() => _RetailStoreScreenState();
}

class _RetailStoreScreenState extends State<RetailStoreScreen> {
  String _activeCategory = 'All';
  int _cartItemCount = 2;
  bool _isLoading = false;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final session = Provider.of<ShopSessionProvider>(context, listen: false);
      final api = session.api;
      if (api != null) {
        final items = await api.getInventory();
        final List<Map<String, dynamic>> mapped = items.map((item) {
          List<String> specList = ['Standard'];
          if (item.variationsJson != null && item.variationsJson!.isNotEmpty) {
            try {
              final decoded = jsonDecode(item.variationsJson!);
              if (decoded is List) {
                specList = decoded.map((e) {
                  if (e is Map) {
                    return (e['name'] ?? '').toString();
                  }
                  return e.toString();
                }).where((s) => s.isNotEmpty).toList();
              }
            } catch (e) {
              debugPrint('Error parsing variationsJson: $e');
            }
          }
          if (specList.isEmpty) specList = ['Standard'];
              
          return {
            'name': item.name,
            'price': item.sellingPrice,
            'rating': 4.5 + ((item.id ?? 0) % 5) * 0.1,
            'reviews': 10 + ((item.id ?? 0) % 90),
            'image': item.imagePath ?? 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?q=80&w=1000&auto=format&fit=crop',
            'category': item.category ?? 'General',
            'inStock': item.stock > 0,
            'promo': item.sellingPrice < (item.originalPrice ?? 0) ? 'SALE' : null,
            'description': item.specification ?? 'Premium select product.',
            'specs': specList,
            'id': item.id.toString(),
            'cloud_id': item.cloudId,
          };
        }).toList();

        if (mapped.isNotEmpty && !_activeCategory.startsWith('All') && !mapped.any((p) => p['category'] == _activeCategory)) {
          _activeCategory = 'All';
        }

        if (mounted) {
          setState(() {
            _products = mapped;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _activeCategory == 'All'
        ? _products
        : _products.where((p) => p['category'] == _activeCategory).toList();

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFC7F900),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0C0C0C),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.shopName.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF00FF88),
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1.0,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
            : _products.isEmpty
                ? const Center(
                    child: Text(
                      'No products available in this store.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : Column(
                    children: [
                      // 1. Search Box
                      _buildSearchBox(),

                      // 2. Horizontal Categories
                      _buildCategoryRow(),

                      // 3. Products Grid
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.65,
                          ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            return _buildProductCard(filteredProducts[index]);
                          },
                        ),
                      ),
                    ],
                  ),
        // 4. Floating Action Cart Button
        floatingActionButton: _buildFloatingCartButton(),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade900),
        ),
        child: const TextField(
          style: TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search premium collection...',
            hintStyle: TextStyle(color: Colors.grey),
            prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRow() {
    final Set<String> categoriesSet = {'All'};
    for (var prod in _products) {
      if (prod['category'] != null && prod['category'].toString().isNotEmpty) {
        categoriesSet.add(prod['category'].toString());
      }
    }
    final categories = categoriesSet.toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
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
                alignment: Alignment.center,
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
          },
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> prod) {
    final bool inStock = prod['inStock'] ?? true;

    return GestureDetector(
      onTap: () => _showProductDetailsBottomSheet(prod),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1C1C1E)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Aspect
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(prod['image'], fit: BoxFit.cover),
                  // Stock Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: inStock ? const Color(0xFF00FF88).withOpacity(0.2) : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: inStock ? const Color(0xFF00FF88) : Colors.red, width: 0.5),
                      ),
                      child: Text(
                        inStock ? 'IN STOCK' : 'OUT OF STOCK',
                        style: TextStyle(
                          color: inStock ? const Color(0xFF00FF88) : Colors.red,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Flash / Discount Badge
                  if (prod['promo'] != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC7F900),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          prod['promo'],
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Details Area
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          prod['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFF00FF88), size: 12),
                          const SizedBox(width: 2),
                          Text(
                            '${prod['rating']} (${prod['reviews']})',
                            style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'KES ${prod['price'].toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Add To Cart button
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF141414),
                        foregroundColor: const Color(0xFF00FF88),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(color: Colors.grey.shade900),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: inStock ? () => _showProductDetailsBottomSheet(prod) : null,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 14),
                          SizedBox(width: 6),
                          Text('Options', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
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

  void _showProductDetailsBottomSheet(Map<String, dynamic> prod) {
    final bool inStock = prod['inStock'] ?? true;
    String selectedSpec = (prod['specs'] as List<String>).first;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          prod['image'],
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (prod['promo'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC7F900).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  prod['promo'],
                                  style: const TextStyle(
                                    color: Color(0xFFC7F900),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 8.5,
                                  ),
                                ),
                              ),
                            Text(
                              prod['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '${prod['rating']} (${prod['reviews']} reviews)',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'KES ${prod['price'].toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
                              style: const TextStyle(
                                color: Color(0xFF00FF88),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF222222), height: 24),
                  const Text(
                    'Product details',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    prod['description'] ?? 'Premium quality select item.',
                    style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Color / Style',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: (prod['specs'] as List<String>).map((spec) {
                      final bool isSelected = selectedSpec == spec;
                      return ChoiceChip(
                        label: Text(spec),
                        selected: isSelected,
                        selectedColor: const Color(0xFF00FF88),
                        backgroundColor: const Color(0xFF222222),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          setModalState(() => selectedSpec = spec);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: inStock ? () {
                              Navigator.pop(ctx);
                              setState(() => _cartItemCount++);
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added $selectedSpec to Cart!'),
                                  backgroundColor: const Color(0xFF00FF88),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            } : null,
                            child: const Text(
                              'Add to Cart',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FF88),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: inStock ? () {
                              Navigator.pop(ctx);
                              showDialog(
                                context: context,
                                builder: (confirmCtx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E1E),
                                  title: const Text('Confirm Purchase'),
                                  content: Text(
                                      'Do you want to buy ${prod['name']} ($selectedSpec) now?\n\nTotal: KES ${prod['price'].toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
                                      style: const TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(
                                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                      onPressed: () => Navigator.pop(confirmCtx),
                                    ),
                                    TextButton(
                                      child: const Text('Buy Now', style: TextStyle(color: Color(0xFF00FF88))),
                                      onPressed: () {
                                        Navigator.pop(confirmCtx);
                                        ScaffoldMessenger.of(context).clearSnackBars();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Successfully purchased ${prod['name']} ($selectedSpec)!'),
                                            backgroundColor: const Color(0xFF00FF88),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            } : null,
                            child: const Text(
                              'Buy Now',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFloatingCartButton() {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        FloatingActionButton(
          backgroundColor: const Color(0xFF00FF88),
          foregroundColor: Colors.black,
          onPressed: _showCartDialog,
          child: const Icon(Icons.shopping_cart),
        ),
        if (_cartItemCount > 0)
          CircleAvatar(
            backgroundColor: Colors.black,
            radius: 9,
            child: CircleAvatar(
              backgroundColor: const Color(0xFF00FF88),
              radius: 8,
              child: Text(
                '$_cartItemCount',
                style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  void _showCartDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Shopping Cart'),
        content: Text('You have $_cartItemCount items in your cart. Would you like to proceed to checkout?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text('Checkout', style: TextStyle(color: Color(0xFF00FF88))),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _cartItemCount = 0);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order submitted successfully!')),
              );
            },
          ),
        ],
      ),
    );
  }
}
