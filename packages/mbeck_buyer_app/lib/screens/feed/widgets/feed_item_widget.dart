import 'package:flutter/material.dart';

class FeedItemWidget extends StatelessWidget {
  final Map<String, dynamic> businessData;
  final VoidCallback onDetailsTapped;

  const FeedItemWidget({
    super.key,
    required this.businessData,
    required this.onDetailsTapped,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> images = businessData['images'] ?? [];
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Horizontal Image Swiper
        PageView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: images.isNotEmpty ? images.length : 1,
          itemBuilder: (context, index) {
            final imageUrl = images.isNotEmpty ? images[index] : null;
            return imageUrl != null
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.grey.shade900,
                    child: const Center(child: Icon(Icons.business, size: 64, color: Colors.white54)),
                  );
          },
        ),

        // 2. Dark Gradient Overlay (Bottom)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.4,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.9),
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // 3. Right Side Action Column
        Positioned(
          right: 16,
          bottom: 120, // Sit above the nav bar and bottom details
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionIcon(Icons.favorite_border, businessData['likes'] ?? '0'),
              const SizedBox(height: 20),
              _buildActionIcon(Icons.bookmark_border, 'SAVE'),
              const SizedBox(height: 20),
              _buildActionIcon(Icons.share, 'SHARE'),
              const SizedBox(height: 20),
              _buildActionIcon(Icons.phone, 'DIAL', iconColor: const Color(0xFFC7F900)),
            ],
          ),
        ),

        // 4. Bottom Left Info Panel
        Positioned(
          left: 16,
          bottom: 24, // Padding from bottom nav
          right: 80, // Leave room for right column
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Premium Badge (if applicable)
              if (businessData['isPremium'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC7F900), // Lime green
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.black),
                      const SizedBox(width: 4),
                      Text(
                        businessData['badgeText'] ?? 'PREMIUM',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              
              // Title
              Text(
                businessData['name'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  shadows: [
                    Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(0, 2))
                  ]
                ),
              ),
              const SizedBox(height: 8),
              
              // Description
              Text(
                businessData['description'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              
              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onDetailsTapped,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC7F900),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('View Details', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (businessData['tourPrice'] != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          backgroundColor: Colors.black45,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          businessData['tourPrice'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // 5. Top Bar (Logo and Search) - overlaid on feed item
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: Color(0xFFC7F900)),
                  const SizedBox(width: 8),
                  Text(
                    'Mbeck',
                    style: TextStyle(
                      color: const Color(0xFFC7F900),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.search, color: Color(0xFFC7F900)),
                onPressed: () {
                  // TODO: Route to search or explore
                },
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionIcon(IconData icon, String label, {Color iconColor = Colors.white}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
