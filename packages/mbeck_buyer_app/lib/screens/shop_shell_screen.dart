import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shop_session_provider.dart';
import 'lodging/lodging_browse_screen.dart';
import 'entertainment/entertainment_browse_screen.dart';
import 'relocation/relocation_booking_screen.dart';

class ShopShellScreen extends StatefulWidget {
  const ShopShellScreen({super.key});

  @override
  State<ShopShellScreen> createState() => _ShopShellScreenState();
}

class _ShopShellScreenState extends State<ShopShellScreen> {
  int _currentIndex = 0;
  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  void _checkConnection() {
    final session = Provider.of<ShopSessionProvider>(context, listen: false);
    if (session.isConnected) {
      setState(() {
        _isConnecting = false;
      });
    } else {
      // If not connected, pop back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active shop session.')),
        );
        Navigator.pop(context);
      });
    }
  }

  final List<Widget> _pages = [
    const LodgingBrowseScreen(),
    const EntertainmentBrowseScreen(),
    const RelocationBookingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isConnecting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to Keja Oasis...'),
            ],
          ),
        ),
      );
    }

    final session = Provider.of<ShopSessionProvider>(context);
    final shopName = session.currentShopName ?? 'Keja Oasis Hub';

    return Scaffold(
      appBar: AppBar(
        title: Text(shopName),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.hotel),
            label: 'Lodging',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Movers',
          ),
        ],
      ),
    );
  }
}
