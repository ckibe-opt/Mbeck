import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/design_system.dart';

/// Reusable barcode scanner screen.
///
/// Returns the scanned barcode string via Navigator.pop.
/// Supports single-scan and continuous-scan modes.
class BarcodeScannerScreen extends StatefulWidget {
  /// If true, stays open after scanning and returns via callback.
  /// If false (default), pops after first scan.
  final bool continuousMode;

  /// Label shown at the bottom of the scanner.
  final String instruction;

  const BarcodeScannerScreen({
    super.key,
    this.continuousMode = false,
    this.instruction = 'Point camera at a barcode',
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // Only detect 1D barcode formats — explicitly exclude QR codes
  static const _barcodeFormats = [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.code93,
    BarcodeFormat.itf,
    BarcodeFormat.codabar,
  ];

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: _barcodeFormats,
  );

  bool _hasScanned = false;
  String? _lastScanned;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned && !widget.continuousMode) return;

    // Filter to only valid 1D barcodes (extra safety in case controller allows others)
    final validBarcodes = capture.barcodes.where((b) =>
      b.rawValue != null &&
      b.rawValue!.isNotEmpty &&
      _barcodeFormats.contains(b.format),
    ).toList();

    if (validBarcodes.isEmpty) return;

    // If multiple barcodes detected, pick the first one (closest to center is preferred
    // but mobile_scanner doesn't expose coordinates reliably, so first match wins)
    final barcode = validBarcodes.first;
    final code = barcode.rawValue!;

    // Avoid duplicate rapid scans of same code
    if (code == _lastScanned) return;

    _lastScanned = code;
    HapticFeedback.mediumImpact();

    if (widget.continuousMode) {
      // In continuous mode, return each scan individually
      Navigator.pop(context, code);
    } else {
      _hasScanned = true;
      Navigator.pop(context, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? Colors.amber : Colors.white,
            ),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Viewfinder overlay
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryGreen, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Darkened corners
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ScanOverlayPainter(),
              ),
            ),
          ),

          // Instruction text
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.instruction,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a semi-transparent overlay with a clear rectangle in the center
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.4);
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    const rectWidth = 280.0;
    const rectHeight = 160.0;

    final left = centerX - rectWidth / 2;
    final top = centerY - rectHeight / 2;
    final right = centerX + rectWidth / 2;
    final bottom = centerY + rectHeight / 2;

    // Draw 4 rectangles around the cutout
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, top), paint);          // Top
    canvas.drawRect(Rect.fromLTRB(0, bottom, size.width, size.height), paint); // Bottom
    canvas.drawRect(Rect.fromLTRB(0, top, left, bottom), paint);           // Left
    canvas.drawRect(Rect.fromLTRB(right, top, size.width, bottom), paint); // Right
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
