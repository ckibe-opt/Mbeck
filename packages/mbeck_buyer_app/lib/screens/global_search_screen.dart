import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/shop_session_provider.dart';
import 'showcase/shop_showcase_screen.dart';
import 'dart:convert';
import 'package:mbeck_shared/mbeck_shared.dart';

// Inline search result model and service for self-contained buyer app
class SearchResult {
  final String id;
  final String shopId;
  final String shopName;
  final String itemName;
  final String description;
  final double price;
  final String type;
  final String category;
  final bool isAvailable;

  SearchResult({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.itemName,
    required this.description,
    required this.price,
    required this.type,
    this.category = '',
    this.isAvailable = true,
  });

  String get formattedPrice => CurrencyFormatter.formatWithCurrency(price);
  String get typeLabel {
    switch (type) {
      case 'product': return 'Product';
      case 'service': return 'Service';
      case 'menu_item': return 'Food';
      default: return 'Item';
    }
  }
}

class GlobalSearchService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static SearchResult _mapToResult(Map<String, dynamic> data, String type) {
    return SearchResult(
      id: data['id']?.toString() ?? '',
      shopId: data['shop_id'] ?? '',
      shopName: data['shops']?['name'] ?? 'Unknown Shop',
      itemName: data['name'] ?? data['service_name'] ?? data['item_name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? data['sellingPrice'] ?? 0).toDouble(),
      type: type,
      category: data['category'] ?? '',
      isAvailable: data['is_available'] ?? data['stock'] != null ? (data['stock'] > 0) : true,
    );
  }

  static Future<List<SearchResult>> searchAll(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final results = await Future.wait([
        _searchShops(query),
        _searchProducts(query),
        _searchServices(query),
        _searchMenuItems(query),
      ]);
      final allResults = [...results[0], ...results[1], ...results[2], ...results[3]];
      allResults.sort((a, b) {
        final aExact = a.itemName.toLowerCase() == query.toLowerCase();
        final bExact = b.itemName.toLowerCase() == query.toLowerCase();
        if (aExact && !bExact) return -1;
        if (bExact && !aExact) return 1;
        return a.itemName.compareTo(b.itemName);
      });
      return allResults;
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  static Future<List<SearchResult>> _searchShops(String query) async {
    try {
      final response = await _supabase.from('shops')
          .select()
          .or('name.ilike.%$query%,business_name.ilike.%$query%,business_type.ilike.%$query%')
          .eq('is_published_online', true)
          .eq('verification_status', 'VERIFIED')
          .limit(20);
      return (response as List).map((data) => SearchResult(
        id: data['id']?.toString() ?? '',
        shopId: data['id']?.toString() ?? '',
        shopName: data['name'] ?? data['business_name'] ?? 'Unknown Shop',
        itemName: data['name'] ?? data['business_name'] ?? 'Unknown Shop',
        description: data['business_type'] ?? 'Storefront',
        price: 0,
        type: 'shop',
        category: data['business_type'] ?? '',
        isAvailable: true,
      )).toList();
    } catch (e) { return []; }
  }

  static Future<List<SearchResult>> _searchProducts(String query) async {
    try {
      final response = await _supabase.from('inventory')
          .select('*, shops!inner(name, is_published_online, verification_status)')
          .ilike('name', '%$query%')
          .eq('shops.is_published_online', true)
          .eq('shops.is_retail_published', true)
          .eq('shops.verification_status', 'VERIFIED')
          .limit(50);
      return (response as List).map((r) => _mapToResult(r, 'product')).toList();
    } catch (e) { return []; }
  }

  static Future<List<SearchResult>> _searchServices(String query) async {
    try {
      final response = await _supabase.from('services_catalog')
          .select('*, shops!inner(name, is_published_online, verification_status)')
          .ilike('service_name', '%$query%')
          .eq('shops.is_published_online', true)
          .eq('shops.is_services_published', true)
          .eq('shops.verification_status', 'VERIFIED')
          .limit(50);
      return (response as List).map((r) => _mapToResult(r, 'service')).toList();
    } catch (e) { return []; }
  }

  static Future<List<SearchResult>> _searchMenuItems(String query) async {
    try {
      final response = await _supabase.from('restaurant_menu')
          .select('*, shops!inner(name, is_published_online, verification_status)')
          .ilike('item_name', '%$query%')
          .eq('shops.is_published_online', true)
          .eq('shops.is_restaurant_published', true)
          .eq('shops.verification_status', 'VERIFIED')
          .limit(50);
      return (response as List).map((r) => _mapToResult(r, 'menu_item')).toList();
    } catch (e) { return []; }
  }
}



class GlobalSearchScreen extends StatefulWidget {
  final String? initialQuery;
  const GlobalSearchScreen({super.key, this.initialQuery});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late TabController _tabController;
  List<SearchResult> _allResults = [];
  List<SearchResult> _filteredResults = [];
  bool _isLoading = false;
  Timer? _debounce;
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    if (widget.initialQuery != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    final filters = ['all', 'product', 'service', 'menu_item'];
    _activeFilter = filters[_tabController.index];
    _applyFilter();
  }

  void _applyFilter() {
    setState(() {
      if (_activeFilter == 'all') {
        _filteredResults = _allResults;
      } else {
        _filteredResults = _allResults.where((r) => r.type == _activeFilter).toList();
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.length > 2) {
        _performSearch(query);
      } else {
        setState(() {
          _allResults = [];
          _filteredResults = [];
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Use the unified GlobalSearchService
      final results = await GlobalSearchService.searchAll(query);
      
      if (mounted) {
        setState(() {
          _allResults = results;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'shop':
        return Icons.storefront;
      case 'product':
        return Icons.shopping_bag;
      case 'service':
        return Icons.build;
      case 'menu_item':
        return Icons.restaurant;
      default:
        return Icons.inventory_2;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'shop':
        return Colors.green;
      case 'product':
        return Colors.purple;
      case 'service':
        return Colors.blue;
      case 'menu_item':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'shop':
        return 'Shop';
      case 'product':
        return 'Product';
      case 'service':
        return 'Service';
      case 'menu_item':
        return 'Food';
      default:
        return 'Item';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Search'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [

        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'All', icon: Icon(Icons.apps, size: 18)),
            Tab(text: 'Products', icon: Icon(Icons.shopping_bag, size: 18)),
            Tab(text: 'Services', icon: Icon(Icons.build, size: 18)),
            Tab(text: 'Food', icon: Icon(Icons.restaurant, size: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Search products, services, food...',
                hintText: 'e.g. Haircut, Pizza, Bread...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: _filteredResults.isEmpty && 
                   _searchController.text.length > 2 && 
                   !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_activeFilter == 'all' ? 'results' : _getTypeLabel(_activeFilter).toLowerCase() + 's'} found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredResults.length,
                    itemBuilder: (context, index) {
                      final item = _filteredResults[index];
                      final typeColor = _getTypeColor(item.type);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: typeColor.withOpacity(0.1),
                            child: Icon(_getTypeIcon(item.type), color: typeColor),
                          ),
                          title: Text(item.itemName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.type != 'shop') Text('@ ${item.shopName}'),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: typeColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.typeLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: typeColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (item.category.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      item.category,
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: item.type == 'shop' 
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400)
                                ]
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    item.formattedPrice,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    item.isAvailable ? 'Available' : 'Not Available',
                                    style: TextStyle(
                                      color: item.isAvailable ? Colors.green : Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                          onTap: () async {
                            final session = context.read<ShopSessionProvider>();
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Connecting to ${item.shopName}...')),
                            );
                            
                            final success = await session.connectToCloudShop(item.shopId, item.shopName);
                            
                            if (success && mounted) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              
                              // Fetch shop metadata dynamically to open showcase
                              try {
                                final supabase = Supabase.instance.client;
                                final shopRes = await supabase.from('shops').select().eq('id', item.shopId).maybeSingle();
                                
                                if (shopRes != null && mounted) {
                                  // Parse theme config
                                  String cover = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=1000&auto=format&fit=crop';
                                  if (shopRes['theme_config'] != null) {
                                    try {
                                      final theme = shopRes['theme_config'] is String 
                                          ? jsonDecode(shopRes['theme_config']) 
                                          : Map<String, dynamic>.from(shopRes['theme_config']);
                                      if (theme['cover_image_url'] != null && theme['cover_image_url'].toString().startsWith('http')) {
                                        cover = theme['cover_image_url'];
                                      }
                                    } catch (_) {}
                                  }
                                  
                                  // Resolve tag & modules
                                  String tag = 'BUSINESS';
                                  List<String> activeModules = [];
                                  if (shopRes['is_retail_published'] == true) {
                                    tag = 'RETAIL STORE';
                                    activeModules.add('retail');
                                  }
                                  if (shopRes['is_restaurant_published'] == true) {
                                    tag = 'DINING';
                                    activeModules.add('restaurant');
                                  }
                                  if (shopRes['is_lodging_published'] == true) {
                                    tag = 'LODGE & BISTRO';
                                    activeModules.add('lodging');
                                  }
                                  if (shopRes['is_services_published'] == true) {
                                    tag = 'SERVICES';
                                    activeModules.add('services');
                                  }
                                  if (shopRes['is_entertainment_published'] == true) {
                                    tag = 'ENTERTAINMENT';
                                    activeModules.add('entertainment');
                                  }
                                  
                                  if (activeModules.isEmpty) {
                                    final bt = (shopRes['business_type'] ?? '').toString().toLowerCase();
                                    if (bt.contains('retail')) activeModules.add('retail');
                                    else if (bt.contains('restaurant')) activeModules.add('restaurant');
                                    else if (bt.contains('lodging')) activeModules.add('lodging');
                                    else if (bt.contains('service')) activeModules.add('services');
                                    else if (bt.contains('entertainment')) activeModules.add('entertainment');
                                    else activeModules.add('retail');
                                  }
                                  
                                  final views = shopRes['online_views'] ?? 0;
                                  
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ShopShowcaseScreen(
                                        shopId: item.shopId,
                                        shopName: item.shopName,
                                        coverUrl: cover,
                                        displayTag: tag,
                                        location: 'Nairobi',
                                        rating: 4.5 + (views % 5) * 0.1,
                                        modules: activeModules,
                                        isVerified: shopRes['verification_status'] == 'VERIFIED',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                              } catch (e) {
                                debugPrint('Error navigating to shop from search: $e');
                              }
                              
                              // Fallback in case metadata fetch fails
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ShopShowcaseScreen(
                                    shopId: item.shopId,
                                    shopName: item.shopName,
                                    coverUrl: '',
                                    displayTag: 'STORE',
                                    location: 'Nairobi',
                                    rating: 4.5,
                                    modules: const ['retail'],
                                    isVerified: false,
                                  ),
                                ),
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to connect to remote shop.')),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
