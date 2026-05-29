import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../db/db_provider.dart';
import '../../services/sync_service.dart';

class StarterPackScreen extends StatefulWidget {
  const StarterPackScreen({super.key});

  @override
  State<StarterPackScreen> createState() => _StarterPackScreenState();
}

class _StarterPackScreenState extends State<StarterPackScreen> {
  bool _isLoading = false;
  String? _status;

  Future<void> _loadStarterPack() async {
    setState(() {
      _isLoading = true;
      _status = "Connecting to Cloud...";
    });

    try {
      final supabase = Supabase.instance.client;
      
      // 1. Call Edge Function
      setState(() => _status = "Requesting Starter Inventory...");
      
      final FunctionResponse res = await supabase.functions.invoke('initialize-shop');
      
      if (res.status != 200) {
        throw Exception('Server Error: ${res.status} - ${res.data}');
      }

      // 2. Trigger Sync to Download It
      setState(() => _status = "Downloading items to device...");
      await SyncService.syncEvents(force: true);

      // 3. Verify
      final count = (await DbProvider.query('inventory')).length;
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Success! 🚀"),
            content: Text("Added 20 generic items to your shop.\nTotal items: $count"),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close Dialog
                  Navigator.pop(context); // Close Screen
                },
                child: const Text("Start Selling"),
              )
            ],
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() => _status = "Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quick Setup")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "Empty Shop?",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Don't waste hours typing.\nLoad the 'Mbeck Starter Pack' with top 20 kiosk items instantly.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(_status ?? "Working..."),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _loadStarterPack,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text("Load Starter Pack (Free)"),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Skip, I'll add items manually"),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}
