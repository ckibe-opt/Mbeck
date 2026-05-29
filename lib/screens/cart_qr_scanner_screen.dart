import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/checkout_sync_service.dart';

class CartQrScannerScreen extends StatefulWidget {
  const CartQrScannerScreen({super.key});

  @override
  State<CartQrScannerScreen> createState() => _CartQrScannerScreenState();
}

class _CartQrScannerScreenState extends State<CartQrScannerScreen> {
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Customer Cart'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_isScanned) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null) {
                  try {
                    final data = jsonDecode(code);
                    if (data is Map<String, dynamic> && data['type'] == 'mbeck_cart') {
                      _isScanned = true;
                      // Notify Sync Service
                      CheckoutSyncService().updateStatus(CheckoutStatus.awaiting_process);
                      Navigator.pop(context, data);
                      return;
                    }
                  } catch (e) {
                    debugPrint('Invalid QR data: $e');
                  }
                }
              }
            },
          ),
          // Scanner Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Align the QR code from the Buyer App',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
