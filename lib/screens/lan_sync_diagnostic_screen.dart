import 'package:flutter/material.dart';
import '../services/lan_sync_service.dart';
import '../services/device_service.dart';
import '../services/event_service.dart';
import '../services/initial_cloud_sync_service.dart';
import '../models/event.dart';

class LANSyncDiagnosticScreen extends StatefulWidget {
  const LANSyncDiagnosticScreen({super.key});

  @override
  State<LANSyncDiagnosticScreen> createState() => _LANSyncDiagnosticScreenState();
}

class _LANSyncDiagnosticScreenState extends State<LANSyncDiagnosticScreen> {
  String _deviceId = 'Loading...';
  String _shopId = 'Loading...';
  bool _isListening = false;
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _setupLANSyncListener();
    _addLog('🔍 LAN Sync Diagnostic Started');
  }

  @override
  void dispose() {
    LANSyncService.instance.onEventReceived = null;
    LANSyncService.instance.onSyncError = null;
    super.dispose();
  }

  void _loadDeviceInfo() async {
    final deviceId = await DeviceService.getDeviceId();
    final shopId = await DeviceService.getShopId();
    if (!mounted) return;
    setState(() {
      _deviceId = deviceId;
      _shopId = shopId;
    });
    _addLog('📱 Device ID: $deviceId');
    _addLog('🏪 Shop ID: $shopId');
  }

  void _setupLANSyncListener() {
    // Check current status
    setState(() {
      _isListening = LANSyncService.instance.isListening;
    });
    _addLog('📡 LAN Sync Status: ${_isListening ? "ACTIVE" : "INACTIVE"}');

    // Setup callbacks
    LANSyncService.instance.onEventReceived = (Event event) {
      _addLog('📥 RECEIVED: ${event.eventType} from ${event.deviceId}');
    };

    LANSyncService.instance.onSyncError = (String error) {
      _addLog('❌ ERROR: $error');
    };
  }

  void _addLog(String message) {
    if (!mounted) return; // Fix: Check if widget is still mounted
    setState(() {
      _logs.add('${DateTime.now().millisecondsSinceEpoch % 100000}: $message');
      if (_logs.length > 50) _logs.removeAt(0); // Keep only last 50 logs
    });
  }

  Future<void> _startLANSync() async {
    _addLog('🚀 Starting LAN Sync...');
    try {
      await LANSyncService.instance.startListening();
      setState(() {
        _isListening = LANSyncService.instance.isListening;
      });
      _addLog('✅ LAN Sync Started: $_isListening');
    } catch (e) {
      _addLog('❌ Failed to start LAN Sync: $e');
    }
  }

  Future<void> _stopLANSync() async {
    _addLog('🛑 Stopping LAN Sync...');
    try {
      await LANSyncService.instance.stopListening();
      setState(() {
        _isListening = LANSyncService.instance.isListening;
      });
      _addLog('✅ LAN Sync Stopped');
    } catch (e) {
      _addLog('❌ Failed to stop LAN Sync: $e');
    }
  }

  Future<void> _sendTestEvent() async {
    _addLog('📤 Sending test event...');
    try {
      final event = await EventService.emitEvent(
        eventType: 'TEST_LAN_SYNC',
        payload: {
          'message': 'Test LAN Sync Message',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      _addLog('✅ Test event sent: ${event.id.substring(0, 8)}...');
    } catch (e) {
      _addLog('❌ Failed to send test event: $e');
    }
  }

  Future<void> _performInitialSync() async {
    _addLog('🚀 Starting initial cloud sync...');
    try {
      await InitialCloudSyncService.performInitialSync();
      _addLog('✅ Initial cloud sync completed!');
    } catch (e) {
      _addLog('❌ Initial cloud sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LAN Sync Diagnostic'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Device Information', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Device ID: $_deviceId'),
                    Text('Shop ID: $_shopId'),
                    Text('LAN Sync: ${_isListening ? "ACTIVE" : "INACTIVE"}',
                        style: TextStyle(
                          color: _isListening ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isListening ? _stopLANSync : _startLANSync,
                    child: Text(_isListening ? 'Stop LAN Sync' : 'Start LAN Sync'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _sendTestEvent,
                    child: const Text('Send Test Event'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _performInitialSync,
                icon: const Icon(Icons.cloud_download),
                label: const Text('Initial Cloud Sync'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Logs
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Debug Logs', style: Theme.of(context).textTheme.titleMedium),
                          TextButton(
                            onPressed: () => setState(() => _logs.clear()),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _logs.map((log) => Text(
                                log,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              )).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
