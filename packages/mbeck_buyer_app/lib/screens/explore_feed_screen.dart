import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/shop_session_provider.dart';
import '../services/shop_discovery_service.dart';
import 'package:http/http.dart' as http;

class ExploreFeedScreen extends StatefulWidget {
  const ExploreFeedScreen({super.key});

  @override
  State<ExploreFeedScreen> createState() => _ExploreFeedScreenState();
}

class _ExploreFeedScreenState extends State<ExploreFeedScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _cloudShops = [];
  List<DiscoveredShop> _lanShops = [];
  bool _isLoadingCloud = true;
  bool _isScanningLan = false;
  bool _isSearching = false;
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> get _filteredCloudShops {
    if (_selectedCategory == 'All') return _cloudShops;
    final catLower = _selectedCategory.toLowerCase();
    return _cloudShops.where((shop) {
      // 1. Prioritize multi-module boolean flags
      if (catLower == 'food' && shop['is_restaurant_published'] == true) return true;
      if (catLower == 'retail' && shop['is_retail_published'] == true) return true;
      if (catLower == 'stays' && shop['is_lodging_published'] == true) return true;
      if (catLower == 'services' && shop['is_services_published'] == true) return true;
      if (catLower == 'fun' && shop['is_entertainment_published'] == true) return true;
      
      // 2. Fallback to business_type string for older records
      final bt = (shop['business_type'] ?? '').toString().toLowerCase();
      if (catLower == 'food' && bt.contains('restaurant')) return true;
      if (catLower == 'stays' && bt.contains('lodging')) return true;
      if (catLower == 'fun' && bt.contains('entertainment')) return true;
      if (bt.contains(catLower)) return true;
      
      return false;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchCloudShops();
    _startSilentLanScan();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchShops(String query) async {
    if (query.trim().isEmpty) {
      _fetchCloudShops();
      return;
    }
    setState(() => _isSearching = true);
    try {
      final response = await _supabase
          .from('shops')
          .select()
          .eq('is_published_online', true)
          .or('name.ilike.%$query%,business_name.ilike.%$query%,business_type.ilike.%$query%')
          .limit(20);
      if (mounted) {
        setState(() {
          _cloudShops = List<Map<String, dynamic>>.from(response);
          _isSearching = false;
          _selectedCategory = 'All'; // Reset filter
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _fetchCloudShops() async {
    setState(() => _isLoadingCloud = true);
    try {
      final response = await _supabase
          .from('shops')
          .select()
          .eq('is_published_online', true)
          .limit(20)
          .order('online_views', ascending: false);
          
      if (mounted) {
        setState(() {
          _cloudShops = List<Map<String, dynamic>>.from(response);
          _isLoadingCloud = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load marketplace shops: $e');
      if (mounted) {
        setState(() => _isLoadingCloud = false);
      }
    }
  }

  Future<void> _startSilentLanScan() async {
    if (_isScanningLan) return;
    setState(() => _isScanningLan = true);
    try {
      final shops = await ShopDiscoveryService.discoverShops(timeout: const Duration(seconds: 4));
      if (mounted) {
        setState(() {
          _lanShops = shops;
          _isScanningLan = false;
        });
        _fetchShopPreviews(shops);
      }
    } catch (e) {
      debugPrint('LAN Scan error: $e');
      if (mounted) setState(() => _isScanningLan = false);
    }
  }

  Future<void> _fetchShopPreviews(List<DiscoveredShop> shops) async {
    for (final shop in shops) {
      try {
        final url = Uri.parse('http://${shop.ip}:${shop.port}/api/v1/info');
        final response = await http.get(url).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          shop.businessType = json['businessType'] as String?;
          shop.enabledModules = List<String>.from(json['enabledModules'] ?? []);
          shop.shopImageUrl = json['shopImageUrl'] as String?;
          shop.theme = json['theme'] as Map<String, dynamic>?;
          if (mounted) setState(() {});
        }
      } catch (e) {
        debugPrint('Failed to fetch preview for ${shop.name}: $e');
      }
    }
  }

  Future<void> _connectToCloudShop(String shopId, String shopName) async {
    _showConnectingDialog(shopName);
    final session = context.read<ShopSessionProvider>();
    final success = await session.connectToCloudShop(shopId, shopName);
    
    if (!mounted) return;
    Navigator.pop(context); // close dialog

    if (success) {
      _logAnalytics(shopId, shopName);
      // Trigger navigation update to Shop tab handled by the shell
      // Wait, Explore is now part of the shell, so we just set connection
      // and let the shell switch tabs if we tell it to.
      // We will handle this in ShopShellScreen listening to connection changes.
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to enter shop context. Please try again.')),
      );
    }
  }

  Future<void> _connectToLanShop(DiscoveredShop shop) async {
    _showConnectingDialog(shop.name);
    final session = context.read<ShopSessionProvider>();
    final success = await session.connectToShopByIp(shop.ip, shop.port, shop.name);
    
    if (!mounted) return;
    Navigator.pop(context);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${shop.name}'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Connection failed. Check WiFi signal.'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  void _showConnectingDialog(String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text('Connecting to $name...', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logAnalytics(String shopId, String shopName) async {
    try {
      await _supabase.rpc('increment_shop_views', params: {'target_shop_id': shopId});
    } catch (_) {}
    try {
      await _supabase.rpc('log_analytics_event', params: {
        'p_event_name': 'MARKETPLACE_SHOP_OPENED',
        'p_platform': 'buyer',
        'p_shop_id': shopId,
        'p_details': {'shop_name': shopName}
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // theme/session removed - not used in this context

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Sleek Header
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: const Text(
                'Explore',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child:              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for shops, food, services...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _fetchCloudShops();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() {}), // refresh suffix icon
                  onSubmitted: (value) => _searchShops(value),
                ),
              ),
            ),
          ),

          // Horizontal Categories
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCategoryPill('🌟 All', _selectedCategory == 'All'),
                  _buildCategoryPill('🍽️ Food', _selectedCategory == 'Food'),
                  _buildCategoryPill('🛍️ Retail', _selectedCategory == 'Retail'),
                  _buildCategoryPill('🛏️ Stays', _selectedCategory == 'Stays'),
                  _buildCategoryPill('💆 Services', _selectedCategory == 'Services'),
                  _buildCategoryPill('🎮 Fun', _selectedCategory == 'Fun'),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // LAN Shop (Active Now)
          if (_lanShops.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Text('NEARBY ON WIFI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1, color: Colors.green)),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildLanShopCard(_lanShops[index]),
                childCount: _lanShops.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],

          // Cloud Shops (Trending)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text('TRENDING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1, color: Colors.grey)),
            ),
          ),

          if (_isLoadingCloud || _isSearching)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_filteredCloudShops.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('No shops found.', style: TextStyle(color: Colors.grey.shade600))),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildCloudShopCard(_filteredCloudShops[index]),
                childCount: _filteredCloudShops.length,
              ),
            ),
            
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label.replaceAll(RegExp(r'[^\w\s]'), '').trim(); // extract "Food", "Retail"
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Filtered by $_selectedCategory'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLanShopCard(DiscoveredShop shop) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.teal.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _connectToLanShop(shop),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.storefront, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shop.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Tap to connect and order', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloudShopCard(Map<String, dynamic> shop) {
    Map<String, dynamic> themeConfig = {};
    if (shop['theme_config'] != null) {
      if (shop['theme_config'] is String) {
        try { themeConfig = jsonDecode(shop['theme_config']); } catch (_) {}
      } else if (shop['theme_config'] is Map) {
        themeConfig = shop['theme_config'];
      }
    }
    
    final coverImage = themeConfig['cover_image_url'] as String? ?? '';
    final shopName = shop['name'] ?? shop['business_name'] ?? 'Mbeck Shop';
    final views = shop['online_views'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _connectToCloudShop(shop['id'].toString(), shopName),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverImage.isNotEmpty && coverImage.startsWith('http'))
                    Image.network(coverImage, fit: BoxFit.cover)
                  else
                    Container(color: Colors.grey.shade200, child: const Icon(Icons.storefront, size: 48, color: Colors.grey)),
                  // Gradient overlay for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text('4.${(views % 9) + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('Global Marketplace • $views views', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
}
