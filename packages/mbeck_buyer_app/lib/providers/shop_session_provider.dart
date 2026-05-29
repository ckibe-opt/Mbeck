import 'dart:async';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mbeck_shared/mbeck_shared.dart';
import '../services/http_discovery_service.dart';
import '../services/shop_api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class ShopSessionProvider extends ChangeNotifier {
  BonsoirDiscovery? _discovery;
  final List<BonsoirService> _discoveredShops = [];
  bool _isScanning = false;
  BonsoirService? _connectedShop; // The shop we are currently "in"
  StreamSubscription? _subscription;
  
  // Theme State
  ShopThemeConfig? _currentShopTheme;
  ShopThemeConfig? get currentShopTheme => _currentShopTheme;

  // Shop Image State
  String? _shopImageUrl;
  String? get shopImageUrl => _shopImageUrl;

  // Module State (Phase 5)
  List<String>? _enabledModules;
  String? _businessType;
  List<String>? get enabledModules => _enabledModules;
  String? get businessType => _businessType;
  bool get isRestaurant => _enabledModules?.contains('restaurant') ?? false;
  bool get isServices => _enabledModules?.contains('services') ?? false;
  bool get isRetail => _enabledModules?.contains('retail') ?? false;
  bool get isEntertainment => _enabledModules?.contains('entertainment') ?? false;
  bool get isLodging => _enabledModules?.contains('lodging') ?? false;
  bool get isMultiModule => (_enabledModules?.length ?? 0) > 1;

  // Connection Health
  Timer? _heartbeatTimer;
  bool _isConnectionHealthy = true;
  bool get isConnectionHealthy => _isConnectionHealthy;
  bool get isConnected => _connectedShop != null || _currentIp != null || _currentCloudId != null;

  List<BonsoirService> get discoveredShops => _discoveredShops;
  bool get isScanning => _isScanning;
  BonsoirService? get connectedShop => _connectedShop;

  /// Start scanning for shops on the local network (Hybrid: mDNS + HTTP fallback)
  Future<void> startDiscovery() async {
    if (_isScanning) return;

    _discoveredShops.clear();
    _isScanning = true;
    notifyListeners();

    try {
      // Phase 1: Try mDNS discovery (works on mobile, unreliable on Windows)
      debugPrint('📡 Phase 1: Trying mDNS discovery...');
      await _tryMdnsDiscovery();
      
      // Wait a bit for mDNS to resolve
      await Future.delayed(const Duration(seconds: 5));
      
      // Phase 2: If no shops found via mDNS, try HTTP scan
      if (_discoveredShops.isEmpty) {
        debugPrint('📡 Phase 2: mDNS found nothing, trying HTTP discovery...');
        await _tryHttpDiscovery();
      } else {
        debugPrint('✅ Found ${_discoveredShops.length} shops via mDNS');
      }
      
    } catch (e) {
      debugPrint('❌ Discovery error: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }
  
  /// Try mDNS discovery (Bonsoir)
  Future<void> _tryMdnsDiscovery() async {
    try {
      // 1. Create discovery
      _discovery = BonsoirDiscovery(type: ServiceConstants.serviceType);
      
      // 2. Initialize (v6 requirement)
      await _discovery!.initialize();
      
      // 3. Start
      await _discovery!.start();

      // 4. Listen to events
      _subscription = _discovery!.eventStream!.listen((event) {
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          final service = event.service;
          if (service != null) {
            debugPrint('Found service: ${service.name}');
            _addOrUpdateService(service);
          }
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          final service = event.service;
          if (service != null) {
            debugPrint('Resolved service: ${service.name} -> ${service.toJson()}');
            _addOrUpdateService(service);
          }
        } else if (event is BonsoirDiscoveryServiceLostEvent) {
          final service = event.service;
          if (service != null) {
            debugPrint('Lost service: ${service.name}');
            _removeService(service);
          }
        }
      });

      debugPrint('📡 mDNS scanning started...');

    } catch (e) {
      debugPrint('❌ mDNS discovery failed: $e');
    }
  }
  
  /// Try HTTP discovery (Subnet scan)
  Future<void> _tryHttpDiscovery() async {
    try {
      final shops = await HttpDiscoveryService.discoverShops(
        timeout: const Duration(seconds: 10),
      );
      
      if (shops.isNotEmpty) {
        // Convert DiscoveredShop to BonsoirService format for compatibility
        // For now, just mark that we found shops (connection screen uses provider directly)
        debugPrint('✅ Found ${shops.length} shops via HTTP');
        
        // Store shops in our list
        for (final shop in shops) {
          // Create  a pseudo-service for UI compatibility
          final service = BonsoirService(
            name: shop.name,
            type: ServiceConstants.serviceType,
            port: shop.port,
            attributes: {
              'id': shop.shopId ?? '',
              'type': 'seller',
              'version': shop.version,
            },
          );
          _addOrUpdateService(service);
        }
      }
    } catch (e) {
      debugPrint('❌ HTTP discovery failed: $e');
    }
  }

  void _addOrUpdateService(BonsoirService service) {
    // Only add services with valid port (skip unresolved)
    if (service.port <= 0) {
      debugPrint('⚠️ Skipping unresolved service: ${service.name} (port: ${service.port})');
      return;
    }
    
    // Check if we already have it
    final index = _discoveredShops.indexWhere((s) => s.name == service.name);
    if (index != -1) {
      _discoveredShops[index] = service;
    } else {
      _discoveredShops.add(service);
    }
    notifyListeners();
  }

  void _removeService(BonsoirService service) {
    _discoveredShops.removeWhere((s) => s.name == service.name);
    notifyListeners();
  }

  /// Stop scanning
  Future<void> stopDiscovery() async {
    await _subscription?.cancel();
    _subscription = null;
    await _discovery?.stop();
    _discovery = null;
    _isScanning = false;
    notifyListeners();
    debugPrint('🔕 Scanning stopped.');
  }

  /// Manually connect to a shop (e.g. from QR scan or list selection)
  /// Validates the connection by pinging the API.
  // Connection State
  String? _currentIp;
  int? _currentPort;
  String? _currentShopName;
  String? _currentShopId;
  String? _currentCloudId;

  String? get currentIp => _currentIp ?? _connectedShop?.host;
  int? get currentPort => _currentPort ?? _connectedShop?.port;
  String? get currentShopName => _currentShopName;
  String? get currentShopId => _currentShopId;
  String? get currentCloudId => _currentCloudId;

  /// Returns the actively configured shop API service (Local vs Cloud Mode)
  ShopApiService? get api {
    if (_currentIp != null && _currentPort != null) {
      return LocalShopApiService(ip: _currentIp!, port: _currentPort!);
    } else if (_currentCloudId != null) {
      return CloudShopApiService(
        shopId: _currentCloudId!,
        shopName: _currentShopName ?? 'Cloud Shop',
      );
    }
    return null;
  }

  /// Connect via Discovered Service
  Future<bool> connectToShop(BonsoirService service) async {
    if (service.port == 0) {
      debugPrint('❌ Cannot connect: Port is 0 (Unresolved)');
      return false;
    }
    
    _connectedShop = service;
    _currentShopName = service.name;
    _currentPort = service.port;
    _currentShopId = service.attributes?['id'] ?? 'local_shop';
    _currentCloudId = service.attributes?['cloud_id']; 
    
    // Resolve Hostname to IP (Critical for Windows mDNS)
    _currentIp = service.host; // Default to hostname
    
    if (service.host != null) {
      try {
        debugPrint('🔍 Resolving hostname: ${service.host}');
        final ips = await InternetAddress.lookup(service.host!);
        if (ips.isNotEmpty) {
          final resolvedIp = ips.first.address;
           debugPrint('✅ Resolved ${service.host} -> $resolvedIp');
           _currentIp = resolvedIp;
        }
      } catch (e) {
        debugPrint('⚠️ Failed to resolve hostname ${service.host}: $e');
        // Fallback: If hostname fails, maybe we can't connect, but we leave it as hostname just in case.
      }
    }
    
    
    // Fetch Shop Theme
    try {
      final supabase = Supabase.instance.client;
      // Prefer Cloud ID if available, otherwise search by exact name/port logic or fallback
      // Since 'attributes.id' is the shop_id, we use that.
      if (_currentShopId != null) {
          final response = await supabase
            .from('shops')
            .select()
            .eq('id', _currentShopId!)
            .maybeSingle();
            
          if (response != null) {
            final dynTheme = response['theme_config'] ?? response['branding'];
            if (dynTheme != null) {
              _currentShopTheme = ShopThemeConfig.fromJson(dynTheme is String ? jsonDecode(dynTheme) : Map<String, dynamic>.from(dynTheme));
            } else {
              _currentShopTheme = null;
            }
          } else {
             _currentShopTheme = null; // Reset to default
          }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to fetch shop theme via Cloud: $e');
      // Don't reset _currentShopTheme here yet, wait for Local API try
    }

    // NEW: Fetch Theme from Local API (Offline Priority)
    await _fetchLocalTheme(_currentIp!, _currentPort!);
    
    // NEW: Fetch Shop Info including enabled modules (Phase 5)
    await _fetchShopInfo(_currentIp!, _currentPort!);
    
    // Start heartbeat monitoring
    _startHeartbeat();
    
    notifyListeners();
    return true;
  }

  /// Helper: Fetch theme from local shop API
  Future<void> _fetchLocalTheme(String ip, int port) async {
    try {
      final url = Uri.parse('http://$ip:$port/api/v1/theme');
      debugPrint('🎨 Fetching theme from local: $url');
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body); // jsonDecode needs dart:convert
        _currentShopTheme = ShopThemeConfig.fromJson(json);
        debugPrint('✅ Applied local theme: ${_currentShopTheme?.stylePreset}');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load local theme: $e');
      // Only set to default if we have NOTHING (no cloud theme either)
      if (_currentShopTheme == null) {
        // _currentShopTheme = ShopThemeConfig.standard();
      }
    }
  }

  /// Helper: Fetch shop info and enabled modules from local API (with retry)
  Future<void> _fetchShopInfo(String ip, int port) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final url = Uri.parse('http://$ip:$port/api/v1/info');
        debugPrint('📋 Fetching shop info from: $url (attempt $attempt)');
        final response = await http.get(url).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final Map<String, dynamic> json = jsonDecode(response.body);
          
          // Extract enabled modules
          if (json['enabledModules'] != null) {
            _enabledModules = List<String>.from(json['enabledModules']);
            debugPrint('📦 Enabled modules: $_enabledModules');
          }
          
          // Extract business type
          if (json['businessType'] != null) {
            _businessType = json['businessType'] as String;
            debugPrint('🏪 Business type: $_businessType');
          }
          
          // Extract shop image URL
          if (json['shopImageUrl'] != null) {
            _shopImageUrl = json['shopImageUrl'] as String;
            debugPrint('📸 Shop image: $_shopImageUrl');
          }
          
          // Extract theme from info response (more reliable than separate call)
          if (json['theme'] != null) {
            try {
              _currentShopTheme = ShopThemeConfig.fromJson(Map<String, dynamic>.from(json['theme']));
              debugPrint('🎨 Applied theme from info: ${_currentShopTheme?.stylePreset}');
            } catch (e) {
              debugPrint('⚠️ Failed to parse theme from info: $e');
            }
          }
          return; // Success
        }
      } catch (e) {
        debugPrint('⚠️ Failed to fetch shop info (attempt $attempt/3): $e');
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
    // Default to retail if all attempts failed
    _enabledModules = ['retail'];
    _businessType = 'retail';
  }

  /// Heartbeat: periodic health check on connected shop
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _isConnectionHealthy = true;
    
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (_currentIp == null) {
        _heartbeatTimer?.cancel();
        return;
      }
      
      try {
        final url = Uri.parse('http://$_currentIp:$_currentPort/api/v1/status');
        final response = await http.get(url).timeout(const Duration(seconds: 3));
        
        if (response.statusCode == 200) {
          if (!_isConnectionHealthy) {
            _isConnectionHealthy = true;
            debugPrint('🟢 Connection restored to $_currentShopName');
            notifyListeners();
          }
        } else {
          _markUnhealthy();
        }
      } catch (e) {
        _markUnhealthy();
      }
    });
  }

  void _markUnhealthy() {
    if (_isConnectionHealthy) {
      _isConnectionHealthy = false;
      debugPrint('🔴 Connection lost to $_currentShopName');
      notifyListeners();
    }
  }

  /// Connect via Manual IP/Port
  Future<bool> connectToShopByIp(String ip, int port, String name) async {
    debugPrint('Connecting to $ip:$port ($name)...');
    
    // Validate connection by pinging status
    try {
      // Use short timeout to fail fast
       await http.get(Uri.parse('http://$ip:$port/api/v1/status'))
          .timeout(const Duration(seconds: 3));
       
       _currentIp = ip;
       _currentPort = port;
       _currentShopName = name;
       _currentCloudId = null; // Clear cloud state
       _connectedShop = null; // Clear auto-discovered shop if manual
       
       // NEW: Fetch Theme
       await _fetchLocalTheme(ip, port);
       
       // NEW: Fetch Shop Info including enabled modules (Phase 5)
       await _fetchShopInfo(ip, port);

       // Start heartbeat monitoring
       _startHeartbeat();

       notifyListeners();
       return true;
    } catch (e) {
      debugPrint('❌ Failed to connect to $ip:$port: $e');
      return false;
    }
  }

  /// Connect via Supabase Cloud (Global E-Commerce Mode)
  Future<bool> connectToCloudShop(String cloudId, String name) async {
    debugPrint('☁️ Connecting to Cloud Shop: $name ($cloudId)...');
    
    _currentCloudId = cloudId;
    _currentShopId = cloudId;
    _currentShopName = name;
    _currentIp = null;
    _currentPort = null;
    _connectedShop = null;
    
    try {
      final cloudApi = api;
      if (cloudApi == null) throw Exception('API not initialized');
      
      final info = await cloudApi.fetchInfo();
      debugPrint('☁️ Cloud Shop Info: $info');
      
      // Attempt to load theme
      final supabase = Supabase.instance.client;
      final response = await supabase.from('shops').select().eq('id', cloudId).maybeSingle();
      if (response != null) {
        final dynTheme = response['theme_config'] ?? response['branding'];
        if (dynTheme != null) {
          _currentShopTheme = ShopThemeConfig.fromJson(dynTheme is String ? jsonDecode(dynTheme) : Map<String, dynamic>.from(dynTheme));
        }
        // Extract enabled modules from the array column
        if (response['enabled_modules'] != null) {
          final dynMod = response['enabled_modules'];
          _enabledModules = List<String>.from(dynMod is String ? jsonDecode(dynMod) : dynMod);
        } else if (response['modules'] != null) {
          // Legacy support
          final dynMod = response['modules'];
          final modMap = dynMod is String ? jsonDecode(dynMod) : dynMod;
          _enabledModules = List<String>.from(modMap['enabled'] ?? ['retail']);
        } else {
          // Fallback: Check individual boolean flags
          _enabledModules = [];
          if (response['is_retail_published'] == true) _enabledModules!.add('retail');
          if (response['is_restaurant_published'] == true) _enabledModules!.add('restaurant');
          if (response['is_services_published'] == true) _enabledModules!.add('services');
          if (response['is_lodging_published'] == true) _enabledModules!.add('lodging');
          if (response['is_entertainment_published'] == true) _enabledModules!.add('entertainment');
          
          if (_enabledModules!.isEmpty) _enabledModules = ['retail'];
        }
        debugPrint('☁️ Cloud Shop Modules: $_enabledModules');
      }

      // Fire shop_view analytics event (fire-and-forget)
      try { await api?.trackEvent('shop_view'); } catch (_) {}

      notifyListeners();
      return true;
    } catch (e, stacktrace) {
      debugPrint('❌ Failed to connect to cloud shop: $e');
      debugPrint('Stacktrace: $stacktrace');
      disconnect();
      return false;
    }
  }
  
  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isConnectionHealthy = true;
    _connectedShop = null;
    _currentIp = null;
    _currentPort = null;
    _currentShopName = null;
    _currentShopId = null;
    _currentCloudId = null;
    _currentShopTheme = null;
    _shopImageUrl = null;
    _enabledModules = null;
    _businessType = null;
    
    notifyListeners();
    // Restart scanning to find shops again
    startDiscovery();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    stopDiscovery();
    super.dispose();
  }
}
