import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../providers/shop_session_provider.dart';

class EntertainmentTicketsScreen extends StatefulWidget {
  final String shopId;
  final String shopName;

  const EntertainmentTicketsScreen({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  @override
  State<EntertainmentTicketsScreen> createState() => _EntertainmentTicketsScreenState();
}

class _EntertainmentTicketsScreenState extends State<EntertainmentTicketsScreen> {
  int _ticketQuantity = 2;
  int _selectedEventIndex = 0;
  String _activeCategory = 'All Events';
  bool _isLoading = false;

  Timer? _countdownTimer;
  int _secondsRemaining = 600; // 10 minutes hold

  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final session = Provider.of<ShopSessionProvider>(context, listen: false);
      final api = session.api;
      if (api != null) {
        final assets = await api.getEntertainmentAssets();
        if (mounted) {
          setState(() {
            _events = assets.map((item) {
              return {
                'id': item['id'],
                'title': item['name'],
                'price': (item['price'] as num).toInt(),
                'location': widget.shopName,
                'dateTime': 'Upcoming Event',
                'image': item['image_path'] ?? 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?q=80&w=1000&auto=format&fit=crop',
                'tag': item['category']?.toUpperCase() ?? 'EVENT',
              };
            }).toList();
            _isLoading = false;
            if (_events.isNotEmpty && _selectedEventIndex >= _events.length) {
              _selectedEventIndex = 0;
            }
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading events: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _countdownTimer?.cancel();
        _showExpiredDialog();
      }
    });
  }

  String get _timerText {
    final int minutes = _secondsRemaining ~/ 60;
    final int seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Hold Expired', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          'Your ticket reservation hold has expired. The tickets have been released back to the general pool.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Restart Hold', style: TextStyle(color: Color(0xFF00FF88))),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _secondsRemaining = 600;
                _startTimer();
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Colors.black,
          primaryColor: const Color(0xFFC7F900),
        ),
        child: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF00FF88)),
          ),
        ),
      );
    }

    if (_events.isEmpty) {
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
            title: const Text('ENTERTAINMENT TICKETS', style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No tickets or events available.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selectedEvent = _events[_selectedEventIndex];
    final totalCost = (selectedEvent['price'] as int) * _ticketQuantity;

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFC7F900),
      ),
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero Event Banner Header
                    _buildHeroBanner(),

                    // 2. Category Filters
                    _buildCategoryRow(),

                    // 3. Events List Title
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        'Upcoming Events',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),

                    // 4. Events Cards
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        return _buildEventCard(index);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            
            // 5. Sticky Bottom Ticket Checkout Bar
            _buildBottomCheckoutBar(totalCost),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?q=80&w=1000&auto=format&fit=crop',
            fit: BoxFit.cover,
          ),
          // Dark Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
          // Back Button
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
          // Content Overlay
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LUXURY SOUNDS LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The Elite Sessions',
                  style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.grey.shade400, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Dec 31st, 9:00 PM',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.location_on, color: Colors.grey.shade400, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Nairobi',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
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

  Widget _buildCategoryRow() {
    final categories = ['All Events', 'Concerts', 'Nightlife'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _activeCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _activeCategory = cat),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    );
  }

  Widget _buildEventCard(int index) {
    final event = _events[index];
    final isSelected = _selectedEventIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedEventIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E0E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF00FF88) : const Color(0xFF1C1C1E),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Event Image
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(event['image'], fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        event['tag'],
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
                            event['title'],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'KES ${event['price']}',
                          style: const TextStyle(
                            color: Color(0xFF00FF88),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.storefront, color: Colors.grey, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          event['location'],
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.grey, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          event['dateTime'],
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
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

  Widget _buildBottomCheckoutBar(int totalCost) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C0C),
        border: Border(top: BorderSide(color: Color(0xFF1E1E1E), width: 1.0)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Urgency Timer Banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.2), width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hourglass_empty, color: Colors.amber, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Ticketmaster hold expires in: ',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11.5),
                  ),
                  Text(
                    _timerText,
                    style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECTION',
                      style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Ticket Quantity',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                // Counter buttons
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white, size: 16),
                        onPressed: () {
                          if (_ticketQuantity > 1) {
                            setState(() => _ticketQuantity--);
                          }
                        },
                      ),
                      Text(
                        '$_ticketQuantity',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 16),
                        onPressed: () {
                          setState(() => _ticketQuantity++);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.confirmation_number_outlined, size: 20),
                label: Text(
                  'BUY TICKET NOW - $totalCost KES',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                onPressed: () => _handleTicketPurchase(totalCost),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTicketPurchase(int totalCost) async {
    final session = Provider.of<ShopSessionProvider>(context, listen: false);
    final api = session.api;
    if (api == null) return;

    // Show loading progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingCtx) => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))),
    );

    try {
      final selectedEvent = _events[_selectedEventIndex];
      final success = await api.pingOrder(
        module: 'entertainment',
        items: [
          {
            'name': selectedEvent['title'],
            'price': selectedEvent['price'],
            'qty': _ticketQuantity,
            'notes': 'Ticket Hold Purchase',
          }
        ],
        customerName: 'Buyer',
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to purchase tickets. Please try again.'), backgroundColor: Colors.redAccent),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    final selectedEvent = _events[_selectedEventIndex];
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00FF88), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ticket Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'BOARDING PASS / ENTRY TICKET',
                      style: TextStyle(
                        color: Color(0xFF00FF88),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Icon(Icons.confirmation_number, color: Colors.grey.shade600, size: 18),
                  ],
                ),
              ),
              
              // Ticket Body (Event Details)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedEvent['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTicketInfoCol('DATE & TIME', selectedEvent['dateTime']),
                        _buildTicketInfoCol('QTY', '$_ticketQuantity x Tickets'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTicketInfoCol('VENUE', selectedEvent['location']),
                        _buildTicketInfoCol('TOTAL PRICE', 'KES $totalCost'),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Perforation Line with notches
              Row(
                children: [
                  Container(
                    height: 20,
                    width: 10,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(10)),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Flex(
                          direction: Axis.horizontal,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.max,
                          children: List.generate(
                            (constraints.constrainWidth() / 8).floor(),
                            (index) => const SizedBox(
                              width: 4,
                              height: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(color: Colors.grey),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    height: 20,
                    width: 10,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
                    ),
                  ),
                ],
              ),
              
              // Ticket Bottom (QR Code & Actions)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.qr_code_2,
                      color: Colors.white,
                      size: 110,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'TICKET ID: MB-984-1823',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Apple Wallet Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                        icon: const Icon(Icons.wallet, color: Colors.white, size: 18),
                        label: const Text(
                          'Add to Apple Wallet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Added to wallet successfully!'),
                              backgroundColor: Color(0xFF00FF88),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        child: const Text(
                          'Close & Go Home',
                          style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () {
                          _countdownTimer?.cancel();
                          Navigator.pop(ctx); // Close dialog
                          Navigator.pop(context); // Go back to showcase
                        },
                      ),
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

  Widget _buildTicketInfoCol(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
