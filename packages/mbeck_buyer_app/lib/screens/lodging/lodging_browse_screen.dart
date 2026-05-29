import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/shop_session_provider.dart';
import '../../theme/shop_theme_extension.dart';
import '../../utils/num_utils.dart' as nu;
import 'package:mbeck_shared/mbeck_shared.dart';
import 'room_type_detail_screen.dart';

/// Lodging browsing screen for buyer app.
///
/// Shows room types as a catalog with images, capacity, rate, and availability.
/// Tapping a room type opens the detail screen with image gallery and room list.
/// Falls back to flat room list if no room types are configured.
class LodgingBrowseScreen extends StatefulWidget {
  const LodgingBrowseScreen({super.key});

  @override
  State<LodgingBrowseScreen> createState() => _LodgingBrowseScreenState();
}

class _LodgingBrowseScreenState extends State<LodgingBrowseScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _roomTypes = [];
  List<Map<String, dynamic>> _rooms = []; // fallback flat list
  bool _isLoading = true;
  String? _error;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    final session = context.read<ShopSessionProvider>();
    final api = session.api;
    if (api == null) {
      setState(() { _error = 'Not connected'; _isLoading = false; });
      return;
    }
    try {

      // Try room types first (richer experience)
      final roomTypes = await api.getLodgingRoomTypes();
      if (roomTypes.isNotEmpty) {
        if (mounted) setState(() { _roomTypes = roomTypes; _isLoading = false; });
      } else {
        // Fallback: flat room list
        final rooms = await api.getLodgingRooms();
        if (mounted) setState(() { _rooms = rooms; _isLoading = false; });
      }
      _animController.forward();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _roomTypes.isNotEmpty
                  ? _buildRoomTypeCatalog(theme)
                  : _rooms.isNotEmpty
                      ? _buildFlatRoomList(theme)
                      : _buildEmpty(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red.shade300),
            ),
            const SizedBox(height: 20),
            const Text('Unable to load rooms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hotel_outlined, size: 56, color: Color(0xFF00897B)),
          ),
          const SizedBox(height: 20),
          const Text('No rooms available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Check back later for availability', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  // ─── Room Type Catalog (primary view) ────────────────────
  Widget _buildRoomTypeCatalog(ThemeData theme) {
    final ext = theme.extension<ShopThemeExtension>() ?? const ShopThemeExtension();
    final totalAvailable = _roomTypes.fold<int>(0, (sum, t) => sum + nu.toInt(t['available_rooms']));
    final totalRooms = _roomTypes.fold<int>(0, (sum, t) => sum + nu.toInt(t['total_rooms']));

    return CustomScrollView(
      slivers: [
        // Hero header
        SliverToBoxAdapter(
          child: Container(
            decoration: ext.buildHeroDecoration(primary: theme.primaryColor, secondary: theme.colorScheme.secondary),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(ext.contentPadding.left, 12, ext.contentPadding.right, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back,
                            color: ext.heroDarkText ? theme.textTheme.bodyLarge?.color : Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: ext.heroDarkText ? theme.primaryColor.withOpacity(0.1) : Colors.white24,
                            borderRadius: BorderRadius.circular(ext.chipBorderRadius),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle,
                                color: ext.heroDarkText ? Colors.green : Colors.greenAccent, size: 16),
                              const SizedBox(width: 4),
                              Text('$totalAvailable available',
                                style: TextStyle(
                                  color: ext.heroDarkText ? theme.textTheme.bodyMedium?.color : Colors.white,
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Accommodation',
                      style: TextStyle(
                        color: ext.heroDarkText ? theme.textTheme.bodyLarge?.color : Colors.white,
                        fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('${_roomTypes.length} room types · $totalRooms rooms total',
                      style: TextStyle(
                        color: ext.heroDarkText ? Colors.grey.shade600 : Colors.white70,
                        fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Section title
        SliverPadding(
          padding: EdgeInsets.fromLTRB(ext.contentPadding.left, 24, ext.contentPadding.right, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              ext.transformSectionHeader('Choose your room type'),
              style: ext.buildSectionHeaderStyle(
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) ??
                  const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),

        // Room type cards
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: ext.contentPadding.left),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final type = _roomTypes[index];
                return AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    final delay = index * 0.15;
                    final progress = (_animController.value - delay).clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - progress)),
                      child: Opacity(opacity: progress, child: child),
                    );
                  },
                  child: _buildRoomTypeCard(type, theme),
                );
              },
              childCount: _roomTypes.length,
            ),
          ),
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildRoomTypeCard(Map<String, dynamic> type, ThemeData theme) {
    final name = type['name'] as String? ?? 'Standard Room';
    final description = type['description'] as String? ?? '';
    final capacity = nu.toInt(type['capacity'], 2);
    final rate = nu.toDouble(type['rate_per_night']);
    final amenities = type['amenities'] as String? ?? '';
    final available = nu.toInt(type['available_rooms']);
    final total = nu.toInt(type['total_rooms']);
    final images = type['images'] as List<dynamic>? ?? [];
    final coverUrl = images.isNotEmpty ? images.first['url'] as String? : null;

    final isAvailable = available > 0;

    final ext = theme.extension<ShopThemeExtension>() ?? const ShopThemeExtension();
    return Padding(
      padding: EdgeInsets.only(bottom: ext.itemSpacing),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: ext.buildCardDecoration(
          surface: theme.cardColor,
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => RoomTypeDetailScreen(roomType: type),
            ));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              SizedBox(
                height: 180,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (coverUrl != null)
                      Image.network(coverUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderImage(name))
                    else
                      _buildPlaceholderImage(name),

                    // Gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Availability badge
                    Positioned(
                      top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isAvailable ? Colors.green.shade600 : Colors.red.shade600,
                          borderRadius: BorderRadius.circular(ext.chipBorderRadius),
                        ),
                        child: Text(
                          isAvailable ? '$available of $total available' : 'Fully booked',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // Image count badge
                    if (images.length > 1)
                      Positioned(
                        top: 12, left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text('${images.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),

                    // Name + rate overlay
                    Positioned(
                      bottom: 12, left: 16, right: 16,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(name,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(CurrencyFormatter.formatWithCurrency(rate),
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              Text('/night', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Details section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) ...[
                      Text(description,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                    ],

                    // Capacity
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('Up to $capacity guests',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Amenity chips
                    if (amenities.isNotEmpty)
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: amenities.split(',').take(5).map((a) {
                          final amenity = a.trim();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(ext.chipBorderRadius),
                              border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_amenityIcon(amenity), size: 14, color: theme.primaryColor),
                                const SizedBox(width: 4),
                                Text(amenity,
                                  style: TextStyle(fontSize: 11, color: theme.primaryColor, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF26A69A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hotel, size: 48, color: Colors.white54),
            const SizedBox(height: 8),
            Text(name, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
          ],
        ),
      ),
    );
  }

  IconData _amenityIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'wifi': return Icons.wifi;
      case 'tv': return Icons.tv;
      case 'ac': case 'air conditioning': return Icons.ac_unit;
      case 'mini-bar': case 'minibar': return Icons.local_bar;
      case 'balcony': return Icons.balcony;
      case 'pool': case 'swimming pool': return Icons.pool;
      case 'parking': return Icons.local_parking;
      case 'breakfast': return Icons.free_breakfast;
      case 'gym': case 'fitness': return Icons.fitness_center;
      case 'spa': return Icons.spa;
      case 'laundry': return Icons.local_laundry_service;
      case 'safe': return Icons.lock;
      case 'desk': case 'workspace': return Icons.desk;
      default: return Icons.check_circle_outline;
    }
  }

  // ─── Flat room list (fallback when no room types configured) ────
  Widget _buildFlatRoomList(ThemeData theme) {
    final ext = theme.extension<ShopThemeExtension>() ?? const ShopThemeExtension();
    final available = _rooms.where((r) => r['status'] == 'available').length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: ext.buildHeroDecoration(primary: theme.primaryColor, secondary: theme.colorScheme.secondary),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(ext.contentPadding.left, 12, ext.contentPadding.right, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back,
                            color: ext.heroDarkText ? theme.textTheme.bodyLarge?.color : Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Rooms & Accommodation',
                      style: TextStyle(
                        color: ext.heroDarkText ? theme.textTheme.bodyLarge?.color : Colors.white,
                        fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('$available of ${_rooms.length} rooms available',
                      style: TextStyle(
                        color: ext.heroDarkText ? Colors.grey.shade600 : Colors.white.withOpacity(0.8))),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: ext.contentPadding,
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildFlatRoomCard(_rooms[index], theme),
              childCount: _rooms.length,
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  Widget _buildFlatRoomCard(Map<String, dynamic> room, ThemeData theme) {
    final name = room['name'] as String? ?? 'Room';
    final type = room['room_type'] as String? ?? 'standard';
    final capacity = nu.toInt(room['capacity'], 2);
    final rate = nu.toDouble(room['rate_per_night']);
    final status = room['status'] as String? ?? 'available';
    final amenities = room['amenities'] as String? ?? '';
    final description = room['description'] as String? ?? '';
    final floor = room['floor'] as String? ?? '';
    final statusColor = status == 'available' ? Colors.green
        : status == 'occupied' ? Colors.red
        : status == 'cleaning' ? Colors.orange
        : Colors.grey;

    final ext = theme.extension<ShopThemeExtension>() ?? const ShopThemeExtension();
    return Card(
      margin: EdgeInsets.only(bottom: ext.itemSpacing),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ext.cardBorderRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.08)),
            child: Row(
              children: [
                Icon(Icons.hotel, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${type[0].toUpperCase()}${type.substring(1)}${floor.isNotEmpty ? ' · Floor $floor' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(ext.chipBorderRadius)),
                  child: Text(status[0].toUpperCase() + status.substring(1),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty) ...[
                  Text(description, style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Icon(Icons.people_outline, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text('Up to $capacity guests', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const Spacer(),
                    Text(CurrencyFormatter.formatWithCurrency(rate),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.primaryColor)),
                    Text(' /night', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
                if (amenities.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 4,
                    children: amenities.split(',').map((a) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(ext.chipBorderRadius)),
                      child: Text(a.trim(), style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
