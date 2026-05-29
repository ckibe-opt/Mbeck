import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mbeck_modules/mbeck_modules.dart';
import '../server/local_server.dart';
import '../server/service_discovery.dart';
import 'home_widget_service.dart';

@pragma('vm:entry-point')
class BackgroundShopService {
  static const notificationChannelId = 'shop_service_channel';
  static const notificationId = 888;

  /// Update the foreground notification with current sync status.
  /// Sends 'updateSyncStatus' to the background isolate, which updates
  /// its own foreground notification — no separate notification created.
  static Future<void> updateNotification({
    required String title,
    required String content,
  }) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (isRunning) {
        service.invoke('updateSyncStatus', {'title': title, 'content': content});
      }
    } catch (e) {
      debugPrint('⚠️ Failed to update notification: $e');
    }
  }

  /// Initialize the background service
  static Future<void> initialize() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint("🖥️ Desktop Mode: Starting Shop Server directly (No Background Service)");
      
      const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://mmnnrydehabyokygyxpo.supabase.co');
      const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1tbm5yeWRlaGFieW9reWd5eHBvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1OTM5NTEsImV4cCI6MjA4NTE2OTk1MX0.vSwuvySp8wlSXOXPskGmCMyT6BMZ1WMmsRZwX-Mo3Qo');

      try {
        await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
        debugPrint("✅ Desktop Supabase Initialized");
      } catch (e) {
         debugPrint("⚠️ Desktop Supabase Init Error: $e");
      }

      await ShopServer.start();
      return;
    }

    final service = FlutterBackgroundService();

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId, 
      'Mbeck POS LAN Sync',
      description: 'Syncs orders, inventory and sales across devices on your network',
      importance: Importance.low, 
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // This will be executed in the isolate
        onStart: onStart,

        // auto start service
        autoStart: false,
        isForegroundMode: true,

        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Mbeck POS',
        initialNotificationContent: 'Starting LAN sync service...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();
  
  // Initialize Supabase in Background Isolate
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://mmnnrydehabyokygyxpo.supabase.co');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1tbm5yeWRlaGFieW9reWd5eHBvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1OTM5NTEsImV4cCI6MjA4NTE2OTk1MX0.vSwuvySp8wlSXOXPskGmCMyT6BMZ1WMmsRZwX-Mo3Qo');

  try {
     await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    debugPrint("✅ Background Supabase Initialized");
  } catch (e) {
    debugPrint("⚠️ Background Supabase Init Error (might be already initialized): $e");
  }

  // ignore: unused_local_variable
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Listen for peer count update from main isolate
  service.on('updateSyncStatus').listen((event) {
    if (service is AndroidServiceInstance && event != null) {
      service.setForegroundNotificationInfo(
        title: event['title'] as String? ?? 'Mbeck POS — LAN Sync Active',
        content: event['content'] as String? ?? '',
      );
    }
  });

  // Listen for stop event
  service.on('stopService').listen((event) {
    // Update home widget to offline before stopping
    HomeWidgetService.updateBroadcastStatus(
      isRunning: false,
      isBroadcasting: false,
    );
    service.stopSelf();
  });

  // Listen for status request from UI
  service.on('requestStatus').listen((event) {
    _broadcastStatus(service);
  });
  
  // Start the server
  try {
    // CRITICAL: Register modules in this isolate
    // On Android, onStart runs in a separate Dart isolate where the
    // ModuleRegistry singleton is empty. Without this, module API routes
    // (restaurant/menu, services/catalog) would return 404.
    if (ModuleRegistry.instance.allModules.isEmpty) {
      debugPrint('📦 [Background] Registering modules in isolate...');
      ModuleRegistry.instance.registerAll([
        RetailModule(),
        RestaurantModule(),
        ServicesModule(),
      ]);
      debugPrint('✅ [Background] Registered ${ModuleRegistry.instance.allModules.length} module(s)');
    }

    await ShopServer.start();
    _broadcastStatus(service); // Broadcast immediately after start
    
    final ip = ShopServer.ipAddress ?? 'Unknown IP';
    final port = ShopServer.port;

    // Update notification with LAN sync context
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Mbeck POS — LAN Sync Active",
        content: "Syncing devices on $ip",
      );
    }
    
    debugPrint("✅ Background Service Started: http://$ip:$port");
    
  } catch (e, stack) {
    debugPrint("❌ Background Service Failed to Start: $e\n$stack");
    
    service.invoke('serverStatus', {
      'isRunning': false,
      'ip': null,
      'isBroadcasting': false,
      'error': e.toString(),
    });

    // Update home screen widget to show offline
    HomeWidgetService.updateBroadcastStatus(
      isRunning: false,
      isBroadcasting: false,
    );

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Mbeck Shop Error",
        content: "Startup failed: ${e.toString().split('\n').first}",
      );
    }
     service.stopSelf();
  }
  
  // Timer to keep isolate alive and update status (heartbeat)
  Timer.periodic(const Duration(minutes: 2), (timer) async {
    _broadcastStatus(service); // Broadcast status periodically
    
    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) {
        timer.cancel();
      }
    }
    
    debugPrint("💓 Background Service Heartbeat: ${DateTime.now()}");
  });
}

/// Helper to broadcast current server status to UI
void _broadcastStatus(ServiceInstance service) {
  final isRunning = ShopServer.isRunning;
  final ip = ShopServer.ipAddress;
  final isBroadcasting = ShopBroadcast.isBroadcasting;

  service.invoke(
    'serverStatus',
    {
      'isRunning': isRunning,
      'ip': ip,
      'port': ShopServer.port,
      'isBroadcasting': isBroadcasting,
    },
  );

  // Also update Android home screen widget
  HomeWidgetService.updateBroadcastStatus(
    isRunning: isRunning,
    isBroadcasting: isBroadcasting,
    ipAddress: ip,
    shopName: ShopBroadcast.shopName,
  );
}
