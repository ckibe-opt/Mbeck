import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../providers/shop_session_provider.dart';
import '../showcase/shop_showcase_screen.dart';

class ExploreBusiness {
  final String id;
  final String name;
  final String coverUrl;
  final double rating;
  final String location;
  final double distanceKm;
  final bool isVerified;
  final List<String> modules; // 'retail', 'restaurant', 'lodging', 'entertainment', 'services'
  final String displayTag; // e.g. "LODGE & BISTRO", "QUICK SERVICE", "WELLNESS"
  final List<String> items; // Items searchable, e.g. "Headphones", "Wings"
  bool isFavorite;

  ExploreBusiness({
    required this.id,
    required this.name,
    required this.coverUrl,
    required this.rating,
    required this.location,
    required this.distanceKm,
    required this.isVerified,
    required this.modules,
    required this.displayTag,
    required this.items,
    this.isFavorite = false,
  });
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  
  String _activeFilter = 'All'; // 'All', 'Stores', 'Entertainment', 'Services', 'Food', 'Housing'
  bool _isLoading = false;
  List<ExploreBusiness> _businesses = [];
  List<ExploreBusiness> _filteredBusinesses = [];

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    setState(() => _isLoading = true);
    
    List<ExploreBusiness> list = [];

    try {
      // Attempt to fetch from real Supabase shops table
      final response = await _supabase
          .from('shops')
          .select()
          .eq('is_published_online', true)
          .limit(20);

      if (response != null && response is List && response.isNotEmpty) {
        for (var shop in response) {
          final idStr = shop['id'].toString();

          // Resolve display tag
          String tag = 'BUSINESS';
          List<String> activeModules = [];
          if (shop['is_retail_published'] == true) {
            tag = 'RETAIL STORE';
            activeModules.add('retail');
          }
          if (shop['is_restaurant_published'] == true) {
            tag = 'DINING';
            activeModules.add('restaurant');
          }
          if (shop['is_lodging_published'] == true) {
            tag = 'LODGE & BISTRO';
            activeModules.add('lodging');
          }
          if (shop['is_services_published'] == true) {
            tag = 'SERVICES';
            activeModules.add('services');
          }
          if (shop['is_entertainment_published'] == true) {
            tag = 'ENTERTAINMENT';
            activeModules.add('entertainment');
          }

          // Fallback business types mapping
          if (activeModules.isEmpty) {
            final type = (shop['business_type'] ?? '').toString().toLowerCase();
            if (type.contains('retail')) {
              activeModules.add('retail');
              tag = 'RETAIL';
            } else if (type.contains('restaurant')) {
              activeModules.add('restaurant');
              tag = 'FOOD & BEVERAGES';
            } else if (type.contains('lodging')) {
              activeModules.add('lodging');
              tag = 'STAYS';
            } else if (type.contains('service')) {
              activeModules.add('services');
              tag = 'SERVICES';
            } else if (type.contains('entertainment')) {
              activeModules.add('entertainment');
              tag = 'ENTERTAINMENT';
            } else {
              // Default to retail/services
              activeModules.add('retail');
              tag = 'STORE';
            }
          }

          // Fetch theme config for cover image
          String cover = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=1000&auto=format&fit=crop';
          if (shop['theme_config'] != null) {
            try {
              Map<String, dynamic> theme = {};
              if (shop['theme_config'] is String) {
                theme = jsonDecode(shop['theme_config']);
              } else if (shop['theme_config'] is Map) {
                theme = Map<String, dynamic>.from(shop['theme_config']);
              }
              if (theme['cover_image_url'] != null && theme['cover_image_url'].toString().startsWith('http')) {
                cover = theme['cover_image_url'];
              }
            } catch (_) {}
          }

          list.add(ExploreBusiness(
            id: idStr,
            name: shop['name'] ?? shop['business_name'] ?? 'Mbeck Shop',
            coverUrl: cover,
            rating: 4.5 + ((shop['online_views'] ?? 0) % 5) * 0.1,
            location: 'Nairobi',
            distanceKm: 1.0 + ((shop['online_views'] ?? 0) % 10) * 0.3,
            isVerified: shop['verification_status'] == 'VERIFIED',
            modules: activeModules,
            displayTag: tag,
            items: [], // Search will query item catalog or fallback to name search
          ));
        }
      }
    } catch (e) {
      debugPrint('Supabase shop fetch error: $e');
    }

    if (mounted) {
      setState(() {
        _businesses = list;
        _isLoading = false;
        _applyFilterAndSearch();
      });
    }
  }

  void _onSearchTextChanged() {
    _applyFilterAndSearch();
  }

  void _applyFilterAndSearch() {
    final query = _searchController.text.trim().toLowerCase();
    List<ExploreBusiness> list = List.from(_businesses);

    // Apply Tab Category Filter
    if (_activeFilter != 'All') {
      String targetModule = '';
      switch (_activeFilter) {
        case 'Stores':
          targetModule = 'retail';
          break;
        case 'Entertainment':
          targetModule = 'entertainment';
          break;
        case 'Services':
          targetModule = 'services';
          break;
        case 'Food':
          targetModule = 'restaurant';
          break;
        case 'Housing':
          targetModule = 'lodging';
          break;
      }

      if (targetModule.isNotEmpty) {
        list = list.where((b) => b.modules.contains(targetModule)).toList();
      }
    }

    // Apply Search Query Filter
    if (query.isNotEmpty) {
      list = list.where((b) {
        // Match business name
        final nameMatch = b.name.toLowerCase().contains(query);
        if (nameMatch) return true;

        // Match item name inside products/services
        final itemMatch = b.items.any((item) => item.toLowerCase().contains(query));
        return itemMatch;
      }).toList();
    }

    setState(() {
      _filteredBusinesses = list;
    });
  }

  Future<void> _connectToShop(ExploreBusiness biz) async {
    // Show premium loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade800, width: 0.5),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFC7F900)),
              SizedBox(height: 20),
              Text(
                'Connecting to cloud database...',
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.none,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final session = Provider.of<ShopSessionProvider>(context, listen: false);
    try {
      final success = await session.connectToCloudShop(biz.id, biz.name);
      if (mounted) {
        Navigator.pop(context); // Dismiss loading
        if (success) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShopShowcaseScreen(
                shopId: biz.id,
                shopName: biz.name,
                coverUrl: biz.coverUrl,
                displayTag: biz.displayTag,
                location: biz.location,
                rating: biz.rating,
                modules: biz.modules,
                isVerified: biz.isVerified,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to switch shop context.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFC7F900),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Premium Top Bar
              _buildTopBar(),
              
              // 2. Beautiful Search Bar
              _buildSearchBar(),
              
              // 3. Horizontally Scrollable Filters
              _buildFilterNavbar(),
              
              // 4. Content / Card List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFC7F900)))
                    : _filteredBusinesses.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _filteredBusinesses.length,
                            itemBuilder: (context, index) {
                              return _buildBusinessCard(_filteredBusinesses[index]);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              const Text(
                'MbeckGo',
                style: TextStyle(
                  color: Color(0xFFC7F900),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          // Location Selector
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade900, width: 0.5),
              ),
              child: const Row(
                children: [
                  Text(
                    'Nairobi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Icon(Icons.location_on, color: Color(0xFFC7F900), size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFF222222), width: 1.0),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search products, dining, stays...',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
            prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 22),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterNavbar() {
    final List<Map<String, dynamic>> tabs = [
      {'name': 'All', 'icon': Icons.apps},
      {'name': 'Stores', 'icon': Icons.shopping_bag_outlined},
      {'name': 'Entertainment', 'icon': Icons.sports_esports_outlined},
      {'name': 'Services', 'icon': Icons.spa_outlined},
      {'name': 'Food', 'icon': Icons.restaurant_outlined},
      {'name': 'Housing', 'icon': Icons.hotel_outlined},
    ];

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final bool isSelected = _activeFilter == tab['name'];

          return GestureDetector(
            onTap: () {
              setState(() {
                _activeFilter = tab['name'];
                _applyFilterAndSearch();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00E676) : const Color(0xFF141414),
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? null
                    : Border.all(color: const Color(0xFF262626), width: 1.0),
              ),
              child: Row(
                children: [
                  Icon(
                    tab['icon'],
                    color: isSelected ? Colors.black : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tab['name'],
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.grey,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBusinessCard(ExploreBusiness biz) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E1E1E), width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _connectToShop(biz),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    biz.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF2C2C2C),
                      child: const Icon(Icons.storefront, size: 50, color: Colors.grey),
                    ),
                  ),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ),
                // Module tag top-left
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      biz.displayTag,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                // Favorite button top-right
                Positioned(
                  top: 12,
                  right: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    radius: 18,
                    child: IconButton(
                      icon: Icon(
                        biz.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: biz.isFavorite ? Colors.red : Colors.white,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() {
                          biz.isFavorite = !biz.isFavorite;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),
              ],
            ),
            
            // Detail Area
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            biz.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (biz.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              color: Color(0xFF00FF88),
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      // Rating
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              biz.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Location details
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${biz.location} • ${biz.distanceKm.toStringAsFixed(1)} km away',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
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
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, color: Colors.grey, size: 64),
          const SizedBox(height: 16),
          Text(
            'No businesses found',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your filters or search term.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
