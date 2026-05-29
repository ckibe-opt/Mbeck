import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/wifi_service.dart';
import '../theme/design_system.dart';
import '../widgets/standard_app_bar.dart';

class WifiConnectionScreen extends StatefulWidget {
  const WifiConnectionScreen({super.key});

  @override
  State<WifiConnectionScreen> createState() => _WifiConnectionScreenState();
}

class _WifiConnectionScreenState extends State<WifiConnectionScreen> {
  final GlobalKey _qrKey = GlobalKey();
  String? _qrData;
  String? _ssid;
  String? _password;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWifiData();
  }

  Future<void> _loadWifiData() async {
    final data = await WifiService.getWifiQrString();
    final ssid = await WifiService.getHotspotSSID();
    final pass = await WifiService.getHotspotPassword();
    
    if (mounted) {
      setState(() {
        _qrData = data;
        _ssid = ssid;
        _password = pass;
        _isLoading = false;
      });
    }
  }

  Future<void> _shareQrCode() async {
    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/mbeck_wifi_qr.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Connect to $_ssid WiFi to shop with Mbeck Buyer App.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing QR: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _copyPassword() {
    if (_password != null) {
      Clipboard.setData(ClipboardData(text: _password!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Password copied!'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: const StandardAppBar(title: 'Buyer WiFi Access'),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step-by-step header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wifi, color: Colors.green.shade700, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            'Quick Setup',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildStep('1', 'Turn ON mobile hotspot on this phone'),
                      _buildStep('2', 'Name it: $_ssid'),
                      _buildStep('3', 'Set password: $_password'),
                      _buildStep('4', 'Buyers scan QR below to connect'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // QR Code
                RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_qrData != null)
                          QrImageView(
                            data: _qrData!,
                            version: QrVersions.auto,
                            size: 220.0,
                            gapless: false,
                          ),
                        const SizedBox(height: 16),
                        Text(
                          '$_ssid',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _copyPassword,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _password ?? '',
                                  style: TextStyle(
                                    color: AppColors.gray700,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.copy, size: 18, color: AppColors.gray500),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to copy password',
                          style: TextStyle(color: AppColors.gray400, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Share button
                ElevatedButton.icon(
                  onPressed: _shareQrCode,
                  icon: const Icon(Icons.share),
                  label: const Text('Share / Print QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Security notice - IMPORTANT
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Security Note',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This hotspot provides LOCAL-ONLY access for Mbeck sync. '
                        'Buyers connecting will NOT have internet access through your phone.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.green.shade900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
