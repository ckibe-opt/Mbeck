import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/shop_session_provider.dart';

class ServicesBookingScreen extends StatefulWidget {
  final String shopId;
  final String shopName;

  const ServicesBookingScreen({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  @override
  State<ServicesBookingScreen> createState() => _ServicesBookingScreenState();
}

class _ServicesBookingScreenState extends State<ServicesBookingScreen> {
  final Set<int> _selectedServices = {}; 
  int _selectedSpecialist = 0; // Maria selected
  int _selectedDateIndex = 0; // Mon 12 selected
  bool _isLoading = false;
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final session = Provider.of<ShopSessionProvider>(context, listen: false);
      final api = session.api;
      if (api != null) {
        final catalog = await api.getServicesCatalog();
        if (mounted) {
          setState(() {
            _services = catalog.map((item) => {
              'id': item['id'],
              'name': item['name'],
              'duration': '${item['duration_minutes']} MINS',
              'price': (item['price'] as num).toInt(),
              'image': item['image_path'] ?? 'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?q=80&w=1000&auto=format&fit=crop',
              'category': item['category'] ?? 'General',
            }).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading services catalog: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  final List<Map<String, dynamic>> _specialists = [
    {
      'name': 'Maria',
      'role': 'Senior Masseur',
      'rating': 4.9,
      'image': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?q=80&w=1000&auto=format&fit=crop',
    },
    {
      'name': 'Sarah',
      'role': 'Master Stylist',
      'rating': 4.8,
      'image': 'https://images.unsplash.com/photo-1580489944761-15a19d654956?q=80&w=1000&auto=format&fit=crop',
    },
  ];

  final List<Map<String, String>> _dates = [
    {'day': 'MON', 'num': '12'},
    {'day': 'TUE', 'num': '13'},
    {'day': 'WED', 'num': '14'},
    {'day': 'THU', 'num': '15'},
    {'day': 'FRI', 'num': '16'},
  ];

  @override
  Widget build(BuildContext context) {
    int totalCost = 0;
    for (int index in _selectedServices) {
      if (index < _services.length) {
        totalCost += (_services[index]['price'] as int);
      }
    }
    const int deposit = 500;
    final int balanceAtCounter = totalCost > deposit ? totalCost - deposit : 0;

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
              fontSize: 16,
              letterSpacing: 1.0,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
            : _services.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.spa_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No services available in this salon.', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Select Services Section Header
                              _buildSectionHeader('Select Services'),

                              // 2. Services List
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _services.length,
                                itemBuilder: (context, index) {
                                  return _buildServiceCard(index);
                                },
                              ),

                              // 3. Specialist Section Header
                              _buildSectionHeader('Expert Specialist'),

                              // 4. Specialists list
                              _buildSpecialistsRow(),

                              // 5. Schedule Header
                              _buildSectionHeader('Schedule'),

                              // 6. Schedule Row
                              _buildScheduleRow(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                      
                      // 7. Sticky Bottom booking drawer
                      _buildBottomBookingBar(totalCost, deposit, balanceAtCounter),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (title == 'Select Services')
            const Text(
              'VIEW ALL',
              style: TextStyle(color: Color(0xFF00FF88), fontSize: 12, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(int index) {
    final service = _services[index];
    final isSelected = _selectedServices.contains(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C1C1E)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Service Image
          SizedBox(
            width: 100,
            height: 100,
            child: Image.network(
              service['image'],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.spa, color: Colors.grey),
            ),
          ),
          // Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${service['duration']} • KES ${service['price']}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          // Select toggle
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    if (_selectedServices.length > 1) {
                      _selectedServices.remove(index);
                    }
                  } else {
                    _selectedServices.add(index);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF00FF88) : const Color(0xFF1C1C1E),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected ? Icons.check : Icons.add,
                  color: isSelected ? Colors.black : Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialistsRow() {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _specialists.length,
        itemBuilder: (context, index) {
          final spec = _specialists[index];
          final isSelected = _selectedSpecialist == index;

          return GestureDetector(
            onTap: () => setState(() => _selectedSpecialist = index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 105,
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C0C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFF00FF88) : const Color(0xFF1C1C1E),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(spec['image']),
                    radius: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    spec['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec['role'],
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        spec['rating'].toString(),
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleRow() {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _dates.length,
        itemBuilder: (context, index) {
          final date = _dates[index];
          final isSelected = _selectedDateIndex == index;

          return GestureDetector(
            onTap: () => setState(() => _selectedDateIndex = index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 56,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00FF88) : const Color(0xFF0C0C0C),
                borderRadius: BorderRadius.circular(16),
                border: isSelected ? null : Border.all(color: const Color(0xFF1C1C1E)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date['day']!,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.grey,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date['num']!,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildBottomBookingBar(int totalCost, int deposit, int balanceAtCounter) {
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade900, width: 0.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Price',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        'KES $totalCost',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pay Online Deposit Now',
                        style: TextStyle(color: Color(0xFF00FF88), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'KES $deposit',
                        style: const TextStyle(color: Color(0xFF00FF88), fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pay at Counter Later',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        'KES $balanceAtCounter',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: totalCost > 0 ? _submitBooking : null,
                child: const Text(
                  'CONFIRM APPOINTMENT >',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitBooking() async {
    final session = Provider.of<ShopSessionProvider>(context, listen: false);
    final api = session.api;
    if (api == null) return;

    final selectedDate = _dates[_selectedDateIndex];
    final selectedSpec = _specialists[_selectedSpecialist]['name'];
    
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))),
    );

    // Sum total cost
    int totalCost = 0;
    List<Map<String, dynamic>> bookedItems = [];
    for (int idx in _selectedServices) {
      if (idx < _services.length) {
        final svc = _services[idx];
        totalCost += (svc['price'] as num).toInt();
        bookedItems.add({
          'id': svc['id'],
          'name': svc['name'],
          'price': svc['price'],
        });
      }
    }

    try {
      final success = await api.submitBooking({
        'service_name': bookedItems.map((b) => b['name']).join(', '),
        'staff_name': selectedSpec,
        'appointment_time': '2026-06-${selectedDate['num']}T10:00:00Z',
        'total_price': totalCost,
        'notes': 'Booked via Mbeck Go',
      });

      if (mounted) Navigator.pop(context); // Close progress dialog

      if (success) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF00FF88)),
                SizedBox(width: 8),
                Text('Appointment Confirmed!', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Text(
              'Your appointment with $selectedSpec has been confirmed.\n\nDate: ${selectedDate['day']} ${selectedDate['num']}\nTotal: KES $totalCost\n\nWe look forward to seeing you!',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                child: const Text('Great', style: TextStyle(color: Color(0xFF00FF88))),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // Back to showcase
                },
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit appointment booking.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}
