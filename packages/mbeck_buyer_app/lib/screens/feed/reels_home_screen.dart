import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/shop_session_provider.dart';
import '../showcase/shop_showcase_screen.dart';
import 'widgets/feed_item_widget.dart';

class ReelsHomeScreen extends StatefulWidget {
  const ReelsHomeScreen({super.key});

  @override
  State<ReelsHomeScreen> createState() => _ReelsHomeScreenState();
}

class _ReelsHomeScreenState extends State<ReelsHomeScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _feedData = [];

  @override
  void initState() {
    super.initState();
    _loadFeedData();
  }

  Future<void> _loadFeedData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('shops')
          .select()
          .eq('is_published_online', true)
          .limit(10);

      final List<Map<String, dynamic>> mapped = [];
      if (response != null && response is List) {
        for (var shop in response) {
          String cover = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=1000&auto=format&fit=crop';
          List<String> activeModules = [];
          String displayTag = 'BUSINESS';

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

          if (shop['is_retail_published'] == true) {
            displayTag = 'RETAIL STORE';
            activeModules.add('retail');
          }
          if (shop['is_restaurant_published'] == true) {
            displayTag = 'DINING';
            activeModules.add('restaurant');
          }
          if (shop['is_lodging_published'] == true) {
            displayTag = 'LODGE & BISTRO';
            activeModules.add('lodging');
          }
          if (shop['is_services_published'] == true) {
            displayTag = 'SERVICES';
            activeModules.add('services');
          }
          if (shop['is_entertainment_published'] == true) {
            displayTag = 'ENTERTAINMENT';
            activeModules.add('entertainment');
          }

          if (activeModules.isEmpty) {
            final type = (shop['business_type'] ?? '').toString().toLowerCase();
            if (type.contains('retail')) {
              activeModules.add('retail');
              displayTag = 'RETAIL';
            } else if (type.contains('restaurant')) {
              activeModules.add('restaurant');
              displayTag = 'FOOD';
            } else if (type.contains('lodging')) {
              activeModules.add('lodging');
              displayTag = 'STAYS';
            } else if (type.contains('service')) {
              activeModules.add('services');
              displayTag = 'SERVICES';
            } else if (type.contains('entertainment')) {
              activeModules.add('entertainment');
              displayTag = 'ENTERTAINMENT';
            } else {
              activeModules.add('retail');
              displayTag = 'STORE';
            }
          }

          mapped.add({
            'id': shop['id'].toString(),
            'name': shop['name'] ?? shop['business_name'] ?? 'Mbeck Shop',
            'description': shop['business_type'] ?? 'Premium local vendor.',
            'badgeText': shop['verification_status'] == 'VERIFIED' ? 'VERIFIED' : 'POPULAR',
            'isPremium': shop['verification_status'] == 'VERIFIED',
            'tourPrice': null,
            'likes': '${(shop['online_views'] ?? 0) + 120}',
            'images': [cover],
            'modules': activeModules,
            'displayTag': displayTag,
            'location': 'Nairobi',
            'rating': 4.5 + ((shop['online_views'] ?? 0) % 5) * 0.1,
            'isVerified': shop['verification_status'] == 'VERIFIED',
          });
        }
      }

      if (mounted) {
        setState(() {
          _feedData = mapped;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reels feed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _connectAndNavigate(Map<String, dynamic> data) async {
    final session = Provider.of<ShopSessionProvider>(context, listen: false);
    
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFC7F900))),
    );

    final shopId = data['id'] as String;
    final shopName = data['name'] as String;

    try {
      await session.connectToCloudShop(shopId, shopName);
      
      if (mounted) {
        Navigator.pop(context); // hide loading
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShopShowcaseScreen(
              shopId: shopId,
              shopName: shopName,
              coverUrl: data['images'].isNotEmpty ? data['images'][0] : '',
              displayTag: data['displayTag'] ?? 'BUSINESS',
              location: data['location'] ?? 'Nairobi',
              rating: data['rating'] ?? 4.5,
              modules: List<String>.from(data['modules'] ?? []),
              isVerified: data['isVerified'] ?? false,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC7F900)))
          : _feedData.isEmpty
              ? const Center(
                  child: Text(
                    'No online shops found.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : PageView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: _feedData.length,
                  itemBuilder: (context, index) {
                    final data = _feedData[index];
                    return FeedItemWidget(
                      businessData: data,
                      onDetailsTapped: () => _connectAndNavigate(data),
                    );
                  },
                ),
    );
  }
}
