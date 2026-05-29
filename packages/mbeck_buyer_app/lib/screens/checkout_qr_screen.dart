import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/shop_session_provider.dart';
import '../services/receipt_service.dart';

class CheckoutQrScreen extends StatefulWidget {
  final double totalAmount;
  final int itemCount;

  const CheckoutQrScreen({
    super.key,
    required this.totalAmount,
    required this.itemCount,
  });

  @override
  State<CheckoutQrScreen> createState() => _CheckoutQrScreenState();
}

class _CheckoutQrScreenState extends State<CheckoutQrScreen> {
  String? _transactionSignature;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _performCheckout();
  }

  Future<void> _performCheckout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cart = context.read<CartProvider>();
      final session = context.read<ShopSessionProvider>();
      final api = session.api;
      
      if (api == null) {
        throw Exception('Not connected to a shop');
      }

      // 1. Prepare items for API
      final payloadItems = cart.items.map((i) => {
        'id': i.item.id,
        'qty': i.quantity,
      }).toList();

      // 2. Call Seller API
      debugPrint('💳 [CHECKOUT] Sending request to seller...');
      final response = await api.checkout(payloadItems);
      
      final signature = response['signature'] as String;
      
      // 3. Save Receipt Locally
      await ReceiptService.saveReceipt(
        shopId: session.currentShopId ?? 'unknown_shop',
        shopName: session.currentShopName ?? 'Unknown Shop',
        cartItems: cart.items.map((i) => {
          'id': i.item.id,
          'name': i.item.name,
          'price': i.item.sellingPrice,
          'quantity': i.quantity,
        }).toList(),
      );

      // 4. Clear Cart
      cart.clear();

      if (mounted) {
        setState(() {
          _transactionSignature = signature;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [CHECKOUT] Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Gate Pass'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text('Finalizing Transaction...', style: TextStyle(color: Colors.grey)),
                  ],
                )
              else if (_errorMessage != null)
                Column(
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Checkout Failed', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _performCheckout,
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Cart'),
                    ),
                  ],
                )
              else if (_transactionSignature != null)
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: _transactionSignature!,
                            version: QrVersions.auto,
                            size: 250.0,
                            foregroundColor: Colors.black,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Scan at Exit',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Valid for ${widget.itemCount} items',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Payment Verified',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
