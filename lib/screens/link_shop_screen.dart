import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/device_service.dart';
import 'home_screen.dart';
import '../widgets/standard_app_bar.dart';

class LinkShopScreen extends StatefulWidget {
  const LinkShopScreen({super.key});

  @override
  State<LinkShopScreen> createState() => _LinkShopScreenState();
}

class _LinkShopScreenState extends State<LinkShopScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _linkShop() async {
    final inputId = _controller.text.trim();
    if (inputId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Verify existence via Cloud RPC
      // Uses the function 'rpc_verify_shop_exists' we just created
      final exists = await Supabase.instance.client.rpc(
        'rpc_verify_shop_exists',
        params: {'p_shop_id': inputId},
      );

      if (exists == true) {
        // 2. Save locally
        await DeviceService.setShopId(inputId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Device Linked! Access restored.'),
              backgroundColor: Colors.green,
            ),
          );
          
          // 3. Restart / Go Home to reload data context
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        setState(() => _error = "❌ Invalid Shop ID. Not found in cloud.");
      }
    } catch (e) {
      setState(() => _error = "Connection Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StandardAppBar(title: "Link Existing Shop"),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_sync, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              "Restore Your Identity",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Enter your Shop ID to link this device to your existing credit profile and history.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "Shop ID",
                hintText: "e.g. shop_176...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _linkShop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: Icon(Icons.hourglass_empty, color: Colors.white, size: 20),
                    )
                  : const Text("LINK DEVICE", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
