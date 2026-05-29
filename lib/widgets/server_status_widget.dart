
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../../theme/design_system.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/home_widget_service.dart';
import '../server/local_server.dart';

class ServerStatusWidget extends StatefulWidget {
  const ServerStatusWidget({super.key});

  @override
  State<ServerStatusWidget> createState() => _ServerStatusWidgetState();
}

class _ServerStatusWidgetState extends State<ServerStatusWidget> {
  bool _isRunning = false;
  bool _isBroadcasting = false;
  String? _ip;
  String? _error;

  bool _isBusy = false;
  StreamSubscription? _statusSub;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _initServiceListener();
  }

  void _initServiceListener() async {
    // FlutterBackgroundService only works on Android/iOS.
    // On desktop, the server runs directly in the main isolate.
    if (!_isMobile) {
      if (mounted) {
        setState(() {
          _isRunning = ShopServer.isRunning;
          _ip = ShopServer.ipAddress;
          _isBroadcasting = ShopServer.isRunning;
        });
      }

      // Start a polling timer for Desktop to accurately reflect changes
      _statusSub = Stream.periodic(const Duration(seconds: 2)).listen((_) {
        if (mounted) {
          setState(() {
            _isRunning = ShopServer.isRunning;
            _ip = ShopServer.ipAddress;
            _isBroadcasting = ShopServer.isRunning;
          });
        }
      });
      return;
    }

    final service = FlutterBackgroundService();
    
    // Initial check
    final isRunning = await service.isRunning();
    if (mounted) {
      setState(() => _isRunning = isRunning);
    }

    // Listen for status updates from background isolate
    _statusSub = service.on('serverStatus').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _isRunning = event['isRunning'] ?? false;
          _ip = event['ip'];
          _isBroadcasting = event['isBroadcasting'] ?? false;
          _error = event['error'];
          _isBusy = false; // Reset busy state when we get a status update
        });
      }
    });

    // Request current status immediately
    if (isRunning) {
      service.invoke('requestStatus');
    }
  }

  Future<void> _toggleServer() async {
    if(_isBusy) return;
    if (!_isMobile) {
      if (ShopServer.isRunning) {
        await ShopServer.stop();
      } else {
        await ShopServer.start();
      }
      if (mounted) {
        setState(() {
          _isRunning = ShopServer.isRunning;
          _ip = ShopServer.ipAddress;
          _isBroadcasting = ShopServer.isRunning;
          _isBusy = false;
        });
      }
      return;
    }

    setState(() => _isBusy = true);
    
    final service = FlutterBackgroundService();
    if (_isRunning) {
      service.invoke('stopService');
      // Wait a moment for teardown
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
         _isRunning = false;
         _isBroadcasting = false;
         _isBusy = false; 
      });
      // Sync home-screen widget immediately
      HomeWidgetService.updateBroadcastStatus(
        isRunning: false,
        isBroadcasting: false,
      );
    } else {
      await service.startService();
      // Optimistic update, actual status will come via stream
      setState(() => _isRunning = true);
      // Sync home-screen widget immediately
      HomeWidgetService.updateBroadcastStatus(
        isRunning: true,
        isBroadcasting: false,
      );
      // Keep busy until stream updates or timeout
      Future.delayed(const Duration(seconds: 5), () {
        if(mounted && _isBusy) setState(() => _isBusy = false);
      });
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isRunning ? AppColors.primaryGreen.withOpacity(0.1) : AppColors.gray100,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: _isRunning ? AppColors.primaryGreen : AppColors.gray300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isRunning ? Icons.wifi_tethering : Icons.wifi_tethering_off,
            size: 16,
            color: _isRunning ? AppColors.primaryGreen : AppColors.gray500,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: SizedBox(
               width: 120, // Constrain width to prevent overflow
               child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error != null 
                        ? 'ERROR: $_error'
                        : (_isRunning ? (_isBroadcasting ? 'BROADCASTING' : 'ONLINE (Starting mDNS...)') : 'OFFLINE'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _error != null ? AppColors.danger : (_isRunning ? AppColors.primaryGreen : AppColors.gray500),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isRunning && _ip != null)
                    Text(
                      _ip!,
                      style: TextStyle(fontSize: 10, color: AppColors.primaryDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 24,
            width: 24,
            child: _isBusy 
              ? const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(
                  value: _isRunning,
                  onChanged: (val) => _toggleServer(),
                  activeColor: AppColors.primaryGreen,
                ),
          ),
        ],
      ),
    );
  }
}
