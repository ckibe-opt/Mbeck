import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/shop_session_provider.dart';
import '../services/receipt_service.dart';
import '../services/order_service.dart';
import 'package:mbeck_shared/mbeck_shared.dart';

/// Buyer shows this QR to the seller, then waits for confirmation
class BuyerCheckoutScreen extends StatefulWidget {
  const BuyerCheckoutScreen({super.key});

  @override
  State<BuyerCheckoutScreen> createState() => _BuyerCheckoutScreenState();
}

class _BuyerCheckoutScreenState extends State<BuyerCheckoutScreen> {
  int _step = 0; // 0: Show QR, 1: Awaiting, 2: Scan Receipt, 3: Done
  String? _receiptSignature;
  Timer? _syncTimer;
  DateTime? _lastChecked;
  bool _isChecking = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (timer) => _checkStatus());
    
    // Auto LAN Checkout attempt
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _step == 0) {
        final session = context.read<ShopSessionProvider>();
        final cart = context.read<CartProvider>();
        if (session.currentIp != null && session.currentPort != null) {
          _submitOrderLocal(context, cart, session);
        }
      }
    });
  }

  Future<void> _checkStatus() async {
    if (!mounted || _isChecking) return;
    setState(() => _isChecking = true);

    final session = context.read<ShopSessionProvider>();
    final ip = session.currentIp;
    final port = session.currentPort;

    if (ip == null || port == null) {
      setState(() => _isChecking = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('http://$ip:$port/api/v1/checkout/sync')
      ).timeout(const Duration(seconds: 3));

      if (mounted) {
        setState(() => _lastChecked = DateTime.now());
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'];
        
        if (status == 'awaiting_process' && _step == 0) {
          if (mounted) setState(() => _step = 1);
        } else if (status == 'completed' && _step < 3) {
          final receipt = data['receipt'];
          if (receipt != null) {
            _receiptSignature = receipt['sig'];
            
            // Save receipt using the data from the sync (official record)
            await ReceiptService.saveScannedReceipt(receipt);
            
            // ACK receipt so seller can close dialog
            await _ackReceipt(ip, port);
            
            // Clear cart
            if (mounted) {
              context.read<CartProvider>().clear();
              setState(() => _step = 3);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Sync Polling Error: $e');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _ackReceipt(String ip, int port) async {
    try {
      await http.post(Uri.parse('http://$ip:$port/api/v1/checkout/ack'));
    } catch (e) {
      debugPrint('ACK Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final session = context.read<ShopSessionProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: _step == 3 ? Colors.green : null,
        foregroundColor: _step == 3 ? Colors.white : null,
      ),
      body: _buildBody(cart, session),
    );
  }

  String _getTitle() {
    switch (_step) {
      case 0: return 'Show to Seller';
      case 1: return 'Awaiting Confirmation';
      case 2: return 'Scan Receipt';
      case 3: return 'Transaction Complete';
      default: return 'Checkout';
    }
  }

  Widget _buildBody(CartProvider cart, ShopSessionProvider session) {
    switch (_step) {
      case 0:
        return _buildShowQrStep(cart, session);
      case 1:
        return _buildAwaitingStep();
      case 2:
        return _buildScanReceiptStep(cart, session);
      case 3:
        return _buildCompleteStep();
      default:
        return const SizedBox();
    }
  }

  /// Step 0: Buyer shows QR with cart items to seller
  Widget _buildShowQrStep(CartProvider cart, ShopSessionProvider session) {
    // Encode cart items as JSON for QR
    final qrData = jsonEncode({
      'type': 'mbeck_cart',
      'shop_id': session.currentShopId,
      'items': cart.items.map((i) => i.toJson()).toList(),
      'total': cart.grandTotal,
      'timestamp': DateTime.now().toIso8601String(),
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Show this QR code to the seller',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // QR Code
          Container(
            padding: const EdgeInsets.all(20),
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
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 250,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          // Cart Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Text(
                  '${cart.itemCount} items',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.formatWithCurrency(cart.grandTotal),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Auto-advance indicator
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Awaiting seller scan...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),

          const Divider(height: 32),
          
          // REMOTE ORDER BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : () => _submitOrderRemote(context, cart, session),
              icon: _isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.send),
              label: Text(_isSubmitting ? 'Sending...' : 'Send Order to Shop'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use this if the seller is not nearby or offline',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrderLocal(BuildContext context, CartProvider cart, ShopSessionProvider session) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final ip = session.currentIp;
      final port = session.currentPort;
      
      if (ip == null || port == null) return;

      final payload = jsonEncode({
        'items': cart.items.map((i) => i.toJson()).toList(),
        'totalAmount': cart.grandTotal,
        'meta': 'MbeckGo/AutoLAN',
      });

      final response = await http.post(
        Uri.parse('http://$ip:$port/api/v1/cart/checkout'),
        headers: {
          'Content-Type': 'application/json',
          'x-client-id': 'MbeckGo_LAN'
        },
        body: payload,
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          setState(() {
            _step = 1; // Move directly to Awaiting confirmation step
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order securely transmitted over LAN!')),
          );
        }
      } else {
        // Soft fail, user can still show QR
        debugPrint('Auto LAN checkout failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
       debugPrint('Auto LAN checkout error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitOrderRemote(BuildContext context, CartProvider cart, ShopSessionProvider session) async {
    setState(() => _isSubmitting = true);
    
    try {
      final api = session.api;
      if (api == null) throw Exception("Not connected");
      
      final result = await OrderService.createOrder(
        shopId: session.currentShopId!,
        items: cart.items,
        totalAmount: cart.grandTotal,
        apiService: api,
      );
      
      if (!mounted) return;
      
      if (result['offline'] == true) {
         _showOfflineSuccess(context, result['message']);
      } else {
         // Success online
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Order sent successfully!')),
         );
         cart.clear();
         Navigator.pop(context); // Go back to shop home
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending order: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showOfflineSuccess(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Order Saved Offline'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              context.read<CartProvider>().clear();
              Navigator.pop(context); // Close checkout screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Step 1: Awaiting seller confirmation
  Widget _buildAwaitingStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 32),
            const Text(
              'Waiting for Seller',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'The seller is processing your purchase.\nPlease wait for confirmation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 48),
            
            // Help text
            Text(
              'Your receipt will appear here automatically\nonce the seller completes the sale.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blue.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel Transaction'),
            ),
            const SizedBox(height: 24),
            
            // Manual Check UI
            if (_step == 1) ...[
               OutlinedButton.icon(
                 onPressed: _isChecking ? null : _checkStatus,
                 icon: _isChecking 
                   ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                   : const Icon(Icons.refresh, size: 18),
                 label: Text(_isChecking ? 'Checking...' : 'Check Status Now'),
               ),
               if (_lastChecked != null)
                 Padding(
                   padding: const EdgeInsets.only(top: 8),
                   child: Text(
                     'Last checked: ${_formatTime(_lastChecked!)}',
                     style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                   ),
                 ),
            ],
          ],
        ),
      ),
    );
  }

  /// Step 2: Scan seller's receipt QR
  Widget _buildScanReceiptStep(CartProvider cart, ShopSessionProvider session) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text('Scan the receipt QR code shown by the seller'),
              ),
            ],
          ),
        ),
        Expanded(
          child: MobileScanner(
            onDetect: (capture) async {
              if (_step != 2) return;
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              
              final code = barcodes.first.rawValue;
              if (code == null) return;
              
              try {
                final data = jsonDecode(code);
                // Check for new compressed format (s: shop, t: total, d: date)
                if (data.containsKey('s') && data.containsKey('t') && data.containsKey('d')) {
                  _receiptSignature = data['sig'];
                  
                  // Save receipt using the data from the QR (official record)
                  await ReceiptService.saveScannedReceipt(data);
                  
                  // Clear cart now that we have the official receipt
                  cart.clear();
                  
                  if (mounted) {
                    setState(() => _step = 3);
                  }
                } else {
                  throw Exception("Invalid receipt format");
                }
              } catch (e) {
                debugPrint('❌ Checkout Scan Error: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invalid QR: $e')),
                  );
                }
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton(
            onPressed: () => setState(() => _step = 1),
            child: const Text('Go Back'),
          ),
        ),
      ],
    );
  }

  /// Step 3: Transaction complete
  Widget _buildCompleteStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, size: 60, color: Colors.green.shade700),
            ),
            const SizedBox(height: 32),
            const Text(
              'Purchase Complete!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your receipt has been saved',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (_receiptSignature != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Receipt: ${_receiptSignature!.substring(0, 16)}...',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 48),
            FilledButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
  }
}
