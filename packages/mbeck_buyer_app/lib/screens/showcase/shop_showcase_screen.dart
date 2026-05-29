import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/shop_session_provider.dart';
import '../lodging/lodging_browse_screen.dart';
import '../restaurant/restaurant_menu_screen.dart';
import '../entertainment/entertainment_tickets_screen.dart';
import '../retail/retail_store_screen.dart';
import '../services/services_booking_screen.dart';
import '../chat/chat_detail_screen.dart';

class ShopShowcaseScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final String coverUrl;
  final String displayTag;
  final String location;
  final double rating;
  final List<String> modules;
  final bool isVerified;

  const ShopShowcaseScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.coverUrl,
    required this.displayTag,
    required this.location,
    required this.rating,
    required this.modules,
    required this.isVerified,
  });

  @override
  State<ShopShowcaseScreen> createState() => _ShopShowcaseScreenState();
}

class _ShopShowcaseScreenState extends State<ShopShowcaseScreen> {
  final List<Map<String, String>> _experienceImages = [
    {
      'title': 'The Lounge',
      'url': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=1000&auto=format&fit=crop',
    },
    {
      'title': 'Garden',
      'url': 'https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?q=80&w=1000&auto=format&fit=crop',
    },
    {
      'title': 'Poolside',
      'url': 'https://images.unsplash.com/photo-1582719508461-905c673771fd?q=80&w=1000&auto=format&fit=crop',
    },
  ];

  void _callBusiness() {
    final theme = Provider.of<ShopSessionProvider>(context, listen: false).currentShopTheme;
    final phone = theme?.phoneNumber?.isNotEmpty == true ? theme!.phoneNumber! : '+254 700 123 456';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.phone, color: Color(0xFF00FF88)),
            SizedBox(width: 8),
            Text('Call Business'),
          ],
        ),
        content: Text(
          'Would you like to place a call to ${widget.shopName}?\n\nNumber: $phone',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text('Call Now', style: TextStyle(color: Color(0xFF00FF88))),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Dialing $phone...')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showMapLocation() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening Google Maps location for ${widget.location}...'),
        backgroundColor: const Color(0xFF1C1C1E),
      ),
    );
  }

  void _openChatRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          shopId: widget.shopId,
          shopName: widget.shopName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ShopSessionProvider>().currentShopTheme;
    final coverUrl = theme?.coverImageUrl?.isNotEmpty == true ? theme!.coverImageUrl! : widget.coverUrl;
    
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFC7F900),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Cover Header
              _buildCoverHero(coverUrl, theme),

              // 2. Action Buttons Row (Call, Map, Chat)
              _buildQuickActionsRow(),

              // 3. The Experience Section
              _buildExperienceSection(theme),

              // 4. Business Modules Section
              _buildModulesSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverHero(String coverUrl, theme) {
    return SizedBox(
      height: 380,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            coverUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF222222),
              child: const Icon(Icons.storefront, size: 80, color: Colors.grey),
            ),
          ),
          // Gradient shader overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
          ),
          
          // Back button & drawer icons
          Positioned(
            top: 40,
            left: 12,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.5),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 12,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.5),
              child: IconButton(
                icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
                onPressed: () {},
              ),
            ),
          ),

          // Business Overlay info at bottom
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (theme?.displayTag?.isNotEmpty == true ? theme!.displayTag! : widget.displayTag).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Icon(widget.isVerified ? Icons.verified : Icons.stars, color: widget.isVerified ? const Color(0xFF00FF88) : Colors.amber, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            widget.isVerified ? 'Verified' : 'Popular',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      widget.shopName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (widget.isVerified) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, color: Color(0xFF00FF88), size: 24),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF00FF88), size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        (theme?.locationAddress?.isNotEmpty == true ? theme!.locationAddress! : 'Tom Mboya St, ${widget.location}'),
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.circle, color: Color(0xFF00FF88), size: 8),
                    const SizedBox(width: 4),
                    const Text(
                      'Open Now',
                      style: TextStyle(color: Color(0xFF00FF88), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Call
          Expanded(
            child: _buildActionBtn(
              icon: Icons.phone_outlined,
              label: 'Call',
              onTap: _callBusiness,
            ),
          ),
          const SizedBox(width: 12),
          // Map
          Expanded(
            child: _buildActionBtn(
              icon: Icons.map_outlined,
              label: 'Map',
              onTap: _showMapLocation,
            ),
          ),
          const SizedBox(width: 12),
          // Chat
          Expanded(
            child: _buildActionBtn(
              icon: Icons.chat_bubble_outline,
              label: 'Chat',
              onTap: _openChatRoom,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E1E1E), width: 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF00FF88), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceSection(theme) {
    final List<String> images = [];
    if (theme != null) {
      if (theme.environmentImages != null && theme.environmentImages.isNotEmpty) {
        images.addAll(theme.environmentImages.cast<String>());
      }
      if (theme.moduleConfigs != null) {
        theme.moduleConfigs.forEach((k, v) {
          if (v is Map && v['environment_images'] is List) {
            images.addAll((v['environment_images'] as List).map((e) => e.toString()));
          }
        });
      }
    }
    
    final displayImages = images.isNotEmpty 
        ? images.toSet().toList() 
        : _experienceImages.map((e) => e['url']!).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'The Experience',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'VIEW ALL',
                  style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: displayImages.length,
            itemBuilder: (context, index) {
              final url = displayImages[index];
              return Container(
                width: 220,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: NetworkImage(url),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.bottomLeft,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModulesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 28, 16, 12),
          child: Text(
            'Business Modules',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // 1. Lodging Module
              if (widget.modules.contains('lodging'))
                _buildModuleCard(
                  numStr: '01',
                  icon: Icons.hotel_outlined,
                  title: 'Book Rooms',
                  subtitle: 'Luxury lodging & safari stays',
                  btnLabel: 'Explore >',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LodgingBrowseScreen()),
                    );
                  },
                ),
              
              // 2. Restaurant Module
              if (widget.modules.contains('restaurant'))
                _buildModuleCard(
                  numStr: '02',
                  icon: Icons.restaurant_outlined,
                  title: 'Dine with Us',
                  subtitle: 'Gourmet local & global cuisine',
                  btnLabel: 'Menu >',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RestaurantMenuScreen(
                          shopId: widget.shopId,
                          shopName: widget.shopName,
                        ),
                      ),
                    );
                  },
                ),

              // 3. Entertainment Module
              if (widget.modules.contains('entertainment'))
                _buildModuleCard(
                  numStr: '03',
                  icon: Icons.sports_esports_outlined,
                  title: 'Buy Tickets',
                  subtitle: 'Entertainment & Amapiano nights',
                  btnLabel: 'Get Tickets >',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EntertainmentTicketsScreen(
                          shopId: widget.shopId,
                          shopName: widget.shopName,
                        ),
                      ),
                    );
                  },
                ),

              // 4. Retail Module
              if (widget.modules.contains('retail'))
                _buildModuleCard(
                  numStr: '04',
                  icon: Icons.shopping_bag_outlined,
                  title: 'Shop Products',
                  subtitle: 'Premium retail & accessories',
                  btnLabel: 'Shop Now >',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RetailStoreScreen(
                          shopId: widget.shopId,
                          shopName: widget.shopName,
                        ),
                      ),
                    );
                  },
                ),

              // 5. Services Module
              if (widget.modules.contains('services'))
                _buildModuleCard(
                  numStr: '05',
                  icon: Icons.spa_outlined,
                  title: 'Book Services',
                  subtitle: 'Rejuvenating spa & styling',
                  btnLabel: 'Book Now >',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ServicesBookingScreen(
                          shopId: widget.shopId,
                          shopName: widget.shopName,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard({
    required String numStr,
    required IconData icon,
    required String title,
    required String subtitle,
    required String btnLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF161616)),
      ),
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // Background Number
          Positioned(
            right: 0,
            top: 0,
            child: Text(
              numStr,
              style: TextStyle(
                color: Colors.grey.shade900.withOpacity(0.5),
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          
          Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF00FF88), size: 24),
              ),
              const SizedBox(width: 16),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    
                    // Button
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF88),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: onTap,
                        child: Text(
                          btnLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
