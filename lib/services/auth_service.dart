import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_auth_service.dart';
import '../models/shop.dart';
import '../models/shop_member.dart';
import '../models/permissions.dart';
import '../db/db_provider.dart';
import 'device_service.dart';
import 'performance_monitor.dart';
import 'realtime_service.dart';

/// Session modes for multi-tenancy access control
/// 
/// - OPERATOR: Local staff with full write access
/// - MANAGER: Admin with elevated permissions
/// - OBSERVER: Enterprise owner visiting foreign shop (read-only)
/// - GUEST: Unauthenticated visitor
enum SessionMode {
  operator,   // Regular staff - can make sales, manage inventory
  manager,    // Admin - can configure settings, manage team
  observer,   // Ghost Mode - read-only access for enterprise owners
  guest,      // Not authenticated
}

/// AuthService - Handles shop authentication and membership management
class AuthService {
  // Use DeviceService for shop_id
  static const String _memberIdKey = 'current_member_id';
  static const String _cachedShopDataKey = 'cached_shop_data';
  static const String _cachedMemberDataKey = 'cached_member_data';

  // Memory cache to avoid hitting SharedPreferences/Network constantly
  static Shop? _memoryCachedShop;
  static ShopMember? _memoryCachedMember;
  static DateTime? _lastMemberFetch;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // In-flight request deduplication — concurrent callers share one network call
  static Future<Shop?>? _shopFetchInFlight;
  static Future<ShopMember?>? _memberFetchInFlight;

  // Role preview: owners/managers can see app as a cashier
  static String? _rolePreviewOverride;

  /// Set role preview mode (null to disable)
  static void setRolePreview(String? role) {
    _rolePreviewOverride = role;
    // Clear member cache so getCurrentMember returns the previewed role
    _memoryCachedMember = null;
    _lastMemberFetch = null;
  }

  /// Get the current role preview override (null if not previewing)
  static String? getRolePreview() => _rolePreviewOverride;

  /// Whether role preview is currently active
  static bool get isRolePreview => _rolePreviewOverride != null;

  /// Invalidate memory cache to force a fresh fetch
  static void invalidateCache() {
    _memoryCachedShop = null;
    _memoryCachedMember = null;
    _lastMemberFetch = null;
  }

  /// Check if device is already linked to a shop
  /// Returns true only if shop_id exists (WITHOUT auto-generating)
  static Future<bool> isAuthenticated() async {
    return await DeviceService.hasStoredShopId();
  }

  /// Get current shop info from Supabase (with offline cache fallback).
  /// Uses in-flight deduplication: concurrent calls share one network request.
  static Future<Shop?> getCurrentShop({bool forceRefresh = false}) async {
    // Fast path: return memory cache immediately (no network)
    if (!forceRefresh && _memoryCachedShop != null) {
      return _memoryCachedShop;
    }

    // If a fetch is already in-flight, piggyback on it
    if (!forceRefresh && _shopFetchInFlight != null) {
      return _shopFetchInFlight!;
    }

    // Start a single fetch that all concurrent callers will share
    _shopFetchInFlight = _fetchCurrentShop(forceRefresh);
    try {
      return await _shopFetchInFlight!;
    } finally {
      _shopFetchInFlight = null;
    }
  }

  static Future<Shop?> _fetchCurrentShop(bool forceRefresh) async {
    final shopId = await _getStoredShopId();
    if (shopId == null || shopId.isEmpty) return null;

    try {
      // Try fetching from cloud
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('shops')
          .select()
          .eq('id', shopId)
          .maybeSingle();

      if (response == null) {
        // Cloud row missing — try to re-push cached data to recover
        final cached = await _getCachedShopData();
        if (cached != null) {
          debugPrint('⚠️ Shop row missing on cloud, attempting re-push from cache...');
          await _rePushShopToCloud(cached);
        }
        return cached;
      }

      final shop = Shop.fromMap(response);
      _memoryCachedShop = shop;
      await _cacheShopData(shop);
      return shop;
    } catch (e) {
      debugPrint('📱 Using cached shop data (offline): $e');
      final cached = await _getCachedShopData();
      if (cached != null) {
        _memoryCachedShop = cached; // Stop repeated timeout attempts
      }
      return cached;
    }
  }

  /// Get all shops the current device/user belongs to
  static Future<List<Shop>> getUserShops() async {
    try {
      final supabase = Supabase.instance.client;
      final deviceId = await DeviceService.getDeviceId();
      final user = supabase.auth.currentUser;

      // Query members based on user_id (if logged in) OR device_id
      dynamic query = supabase.from('shop_members').select('shop_id, shops(*)');
      
      if (user != null) {
        query = query.or('user_id.eq.${user.id},device_id.eq.$deviceId');
      } else {
        query = query.eq('device_id', deviceId);
      }

      final response = await query;
      
      if (response == null) return [];

      final List<Shop> shops = [];
      for (var row in response as List) {
        if (row['shops'] != null) {
          shops.add(Shop.fromMap(row['shops']));
        }
      }
      return shops;
    } catch (e) {
      debugPrint('⚠️ Error fetching user shops: $e');
      return [];
    }
  }

  /// Select a shop to be active
  /// 
  /// This is the main method for switching between shops in multi-shop mode.
  /// It updates the active shop ID and switches the database context.
  static Future<void> selectShop(String shopId) async {
    final homeShopId = await DeviceService.getHomeShopId();
    
    if (shopId == homeShopId) {
      // Switching to home shop - clear active shop
      await DeviceService.setActiveShopId(null);
    } else {
      // Switching to another shop - set active shop
      await DeviceService.setActiveShopId(shopId);
    }
    
    // Switch to the appropriate database
    await DbProvider.switchToShopDatabase(shopId);
    
    // Update legacy storage for backward compat
    await _storeShopId(shopId);
    
    // Reinitialize RealtimeService for the new shop
    await RealtimeService.dispose();
    await RealtimeService.init();
    
    // Force refresh of cached data
    _memoryCachedShop = null;
    _memoryCachedMember = null;
    
    final shop = await getCurrentShop();
    
    // Sync to the new DB immediately
    if (shop != null) {
      await _syncToLocalDb(shop);
    }

    final member = await getCurrentMember();
    
    // Verify access
    if (member == null || !member.isActive) {
       throw Exception('You do not have active access to this shop.');
    }
    
    debugPrint('✅ Shop Selected: ${shop?.businessName}');
  }

  /// Get current member info from Supabase (with offline cache fallback).
  /// Uses in-flight deduplication: concurrent calls share one network request.
  static Future<ShopMember?> getCurrentMember({bool forceRefresh = false}) async {
    // Fast path: return memory cache immediately
    if (!forceRefresh && 
        _memoryCachedMember != null && 
        _lastMemberFetch != null &&
        DateTime.now().difference(_lastMemberFetch!) < _cacheDuration) {
      final cached = _memoryCachedMember!;
      return _rolePreviewOverride != null ? cached.copyWith(role: _rolePreviewOverride) : cached;
    }

    // If a fetch is already in-flight, piggyback on it
    if (!forceRefresh && _memberFetchInFlight != null) {
      return _memberFetchInFlight!;
    }

    _memberFetchInFlight = _fetchCurrentMember();
    try {
      return await _memberFetchInFlight!;
    } finally {
      _memberFetchInFlight = null;
    }
  }

  static Future<ShopMember?> _fetchCurrentMember() async {
    final deviceId = await DeviceService.getDeviceId();
    final shopId = await _getStoredShopId();
    if (shopId == null || shopId.isEmpty) return null;

    final shop = await getCurrentShop();
    if (shop == null) return null;

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      dynamic query = supabase
          .from('shop_members')
          .select()
          .eq('shop_id', shopId)
          .eq('is_active', true);

      if (user != null) {
         query = query.or('user_id.eq.${user.id},device_id.eq.$deviceId');
      } else {
         query = query.eq('device_id', deviceId);
      }

      final response = await query.maybeSingle();

      if (response == null) {
        return await _getCachedMemberData();
      }

      final member = ShopMember.fromMap(response);
      _memoryCachedMember = member;
      _lastMemberFetch = DateTime.now();
      await _cacheMemberData(member);
      
      return _rolePreviewOverride != null ? member.copyWith(role: _rolePreviewOverride) : member;
    } catch (e) {
      debugPrint('📱 Using cached member data (offline): $e');
      final cached = await _getCachedMemberData();
      if (cached != null) {
        _memoryCachedMember = cached; // Stop repeated timeout attempts
        _lastMemberFetch = DateTime.now(); // Respect normal cache duration
      }
      if (cached != null && _rolePreviewOverride != null) {
        return cached.copyWith(role: _rolePreviewOverride);
      }
      return cached;
    }
  }

  /// Create new shop (Owner flow)
  /// Uses server-side RPC to hash passwords inside Postgres (never exposed to client).
  static Future<Shop?> createShop({
    required String businessName,
    required String password,
    required String adminPassword,
    required String userName,
  }) async {
    PerformanceMonitor().startTrace('AuthService.createShop');
    try {
      final deviceId = await DeviceService.getDeviceId();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = Random().nextInt(9999).toString().padLeft(4, '0');
      final shopId = 'shop_${timestamp}_$random';

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      // Use server-side RPC — passwords hashed inside Postgres
      try {
        final result = await supabase.rpc('create_shop_secure', params: {
          'p_shop_id': shopId,
          'p_name': businessName,
          'p_password': password,
          'p_admin_password': adminPassword,
          'p_owner_device_id': deviceId,
          'p_owner_name': userName,
          'p_owner_user_id': userId,
        });

        final shopData = (result as Map<String, dynamic>)['shop'];
        final memberData = result['member'];

        await _storeShopId(shopId);

        final shop = Shop.fromMap(shopData is String ? jsonDecode(shopData) : shopData);
        final member = ShopMember.fromMap(memberData is String ? jsonDecode(memberData) : memberData);

        await _cacheShopData(shop);
        await _cacheMemberData(member);

        debugPrint('✅ Shop created (server-side): $shopId');
        PerformanceMonitor().endTrace('AuthService.createShop', metadata: {'shopId': shopId});
        return shop;
      } catch (rpcError) {
        // Fallback to legacy client-side flow if RPC not deployed yet
        debugPrint('⚠️ Server-side RPC failed, falling back to legacy: $rpcError');
        return await _createShopLegacy(
          shopId: shopId,
          businessName: businessName,
          password: password,
          adminPassword: adminPassword,
          userName: userName,
          deviceId: deviceId,
          userId: userId,
        );
      }
    } catch (e) {
      debugPrint('❌ Error creating shop: $e');
      PerformanceMonitor().endTrace('AuthService.createShop', metadata: {'error': e.toString()});
      return null;
    }
  }

  /// Legacy fallback for createShop (client-side hashing)
  static Future<Shop?> _createShopLegacy({
    required String shopId,
    required String businessName,
    required String password,
    required String adminPassword,
    required String userName,
    required String deviceId,
    String? userId,
  }) async {
    final passwordHash = _hashPassword(password);
    final adminPasswordHash = _hashPassword(adminPassword);
    final supabase = Supabase.instance.client;

    final shopData = await supabase.from('shops').insert({
      'id': shopId,
      'name': businessName,
      'password_hash': passwordHash,
      'admin_password_hash': adminPasswordHash,
      'owner_device_id': deviceId,
      'owner_id': userId,
      'subscription_tier': 'FREE',
      'subscription_status': 'ACTIVE',
      'trial_ends_at': null,
    }).select().single();

    final memberData = await supabase.from('shop_members').insert({
      'shop_id': shopId,
      'device_id': deviceId,
      'user_id': userId,
      'user_name': userName,
      'role': 'OWNER',
      'permissions': RolePresets.owner,
    }).select().single();

    await _storeShopId(shopId);

    final shop = Shop.fromMap(shopData);
    final member = ShopMember.fromMap(memberData);

    await _cacheShopData(shop);
    await _cacheMemberData(member);

    debugPrint('✅ Shop created (legacy): $shopId');
    PerformanceMonitor().endTrace('AuthService.createShop', metadata: {'shopId': shopId});
    return shop;
  }

  /// Join existing shop (Staff flow)
  /// Uses server-side RPC for password verification (hashes never leave DB).
  static Future<Shop?> joinShop({
    required String shopId,
    required String password,
    required String userName,
    String? adminPassword,
    bool joinAsManager = false,
  }) async {
    PerformanceMonitor().startTrace('AuthService.joinShop');
    try {
      final deviceId = await DeviceService.getDeviceId();
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      // PRE-FLIGHT FIX: Re-map permanent User IDs so returning users aren't needlessly duplicated
      if (userId != null) {
        try {
          final existing = await supabase.from('shop_members').select()
              .eq('shop_id', shopId).eq('user_id', userId).maybeSingle();
          if (existing != null) {
            if (existing['device_id'] != deviceId || existing['user_name'] != userName) {
              await supabase.from('shop_members').update({
                'device_id': deviceId,
                'user_name': userName,
                'is_active': true
              }).eq('id', existing['id']);
            }
            // Route to login to reuse their existing owner/cashier permissions
            return await login(shopId: shopId, password: password);
          }
        } catch (_) {}
      }

      // Use server-side RPC — password verified inside Postgres
      try {
        final result = await supabase.rpc('join_shop_secure', params: {
          'p_shop_id': shopId,
          'p_password': password,
          'p_device_id': deviceId,
          'p_user_name': userName,
          'p_join_as_manager': joinAsManager,
          'p_admin_password': adminPassword,
          'p_user_id': userId,
        });

        final data = result as Map<String, dynamic>;
        final shopMap = data['shop'];
        final memberMap = data['member'];

        final shop = Shop.fromMap(shopMap is String ? jsonDecode(shopMap) : shopMap);
        final member = ShopMember.fromMap(memberMap is String ? jsonDecode(memberMap) : memberMap);

        await _storeShopId(shopId);
        await _cacheShopData(shop);
        await _cacheMemberData(member);

        debugPrint('✅ Joined shop (server-side): $shopId as $userName (${member.role})');
        PerformanceMonitor().endTrace('AuthService.joinShop', metadata: {'shopId': shopId, 'role': member.role});
        return shop;
      } on PostgrestException catch (e) {
        // Server-side exceptions from RAISE EXCEPTION
        throw Exception(e.message);
      } catch (rpcError) {
        // Fallback to legacy client-side flow if RPC not deployed yet
        debugPrint('⚠️ Server-side RPC failed, falling back to legacy: $rpcError');
        return await _joinShopLegacy(
          shopId: shopId,
          password: password,
          userName: userName,
          adminPassword: adminPassword,
          joinAsManager: joinAsManager,
          deviceId: deviceId,
          userId: userId,
        );
      }
    } catch (e) {
      debugPrint('❌ Error joining shop: $e');
      PerformanceMonitor().endTrace('AuthService.joinShop', metadata: {'error': e.toString()});
      rethrow;
    }
  }

  /// Legacy fallback for joinShop (client-side hash comparison)
  static Future<Shop?> _joinShopLegacy({
    required String shopId,
    required String password,
    required String userName,
    String? adminPassword,
    bool joinAsManager = false,
    required String deviceId,
    String? userId,
  }) async {
    final supabase = Supabase.instance.client;

    final shopData = await supabase.from('shops').select().eq('id', shopId).maybeSingle();
    if (shopData == null) throw Exception('Shop not found. Please check the Shop ID.');

    final shop = Shop.fromMap(shopData);
    final passwordHash = _hashPassword(password);

    if (shopData['password_hash'] != passwordHash) {
      throw Exception('Incorrect shop password. Please try again.');
    }

    String role = 'CASHIER';
    Map<String, dynamic> permissions = RolePresets.cashier;

    if (joinAsManager) {
      if (adminPassword == null || adminPassword.isEmpty) {
        throw Exception('Admin password is required for Manager access.');
      }
      final adminHash = _hashPassword(adminPassword);
      final storedAdminHash = shopData['admin_password_hash'] ?? shopData['password_hash'];
      if (storedAdminHash != adminHash) {
        throw Exception('Incorrect ADMIN password.');
      }
      role = 'MANAGER';
      permissions = RolePresets.admin;
    }

    final existing = await supabase.from('shop_members').select()
        .eq('shop_id', shopId).eq('device_id', deviceId).maybeSingle();

    if (existing != null) {
      final updates = <String, dynamic>{'is_active': true, 'last_active_at': DateTime.now().toIso8601String()};
      if (joinAsManager && existing['role'] != 'OWNER') {
        updates['role'] = role;
        updates['permissions'] = permissions;
      }
      await supabase.from('shop_members').update(updates).eq('id', existing['id']);
      await _storeShopId(shopId);
      await _cacheShopData(shop);
      await _cacheMemberData(ShopMember.fromMap(existing));
      return shop;
    }

    final memberData = await supabase.from('shop_members').insert({
      'shop_id': shopId, 'device_id': deviceId, 'user_id': userId,
      'user_name': userName, 'role': role, 'permissions': permissions,
    }).select().single();

    await _storeShopId(shopId);
    final member = ShopMember.fromMap(memberData);
    await _cacheShopData(shop);
    await _cacheMemberData(member);

    debugPrint('✅ Joined shop (legacy): $shopId as $userName ($role)');
    PerformanceMonitor().endTrace('AuthService.joinShop', metadata: {'shopId': shopId, 'role': role});
    return shop;
  }

  /// Log into existing shop (Returning Staff/Owner flow)
  /// Uses server-side RPC for password verification.
  static Future<Shop?> login({
    required String shopId,
    required String password,
  }) async {
    PerformanceMonitor().startTrace('AuthService.login');
    try {
      final deviceId = await DeviceService.getDeviceId();
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      // PRE-FLIGHT FIX: Sync new device ID for existing permanently authenticated users
      if (userId != null) {
        try {
          final existing = await supabase.from('shop_members').select()
              .eq('shop_id', shopId).eq('user_id', userId).maybeSingle();
          if (existing != null && existing['device_id'] != deviceId) {
            await supabase.from('shop_members').update({'device_id': deviceId}).eq('id', existing['id']);
          }
        } catch (_) {}
      }

      // Use server-side RPC — password verified inside Postgres
      try {
        final result = await supabase.rpc('login_shop_secure', params: {
          'p_shop_id': shopId,
          'p_password': password,
          'p_device_id': deviceId,
        });

        final data = result as Map<String, dynamic>;
        final shopMap = data['shop'];
        final memberMap = data['member'];

        final shop = Shop.fromMap(shopMap is String ? jsonDecode(shopMap) : shopMap);
        final member = ShopMember.fromMap(memberMap is String ? jsonDecode(memberMap) : memberMap);

        await _storeShopId(shopId);
        await _cacheShopData(shop);
        await _cacheMemberData(member);

        debugPrint('✅ Logged into shop (server-side): $shopId');
        PerformanceMonitor().endTrace('AuthService.login', metadata: {'shopId': shopId});
        return shop;
      } on PostgrestException catch (e) {
        throw Exception(e.message);
      } catch (rpcError) {
        debugPrint('⚠️ Server-side RPC failed, falling back to legacy: $rpcError');
        return await _loginLegacy(shopId: shopId, password: password, deviceId: deviceId);
      }
    } catch (e) {
      debugPrint('❌ Error logging into shop: $e');
      PerformanceMonitor().endTrace('AuthService.login', metadata: {'error': e.toString()});
      rethrow;
    }
  }

  /// Legacy fallback for login (client-side hash comparison)
  static Future<Shop?> _loginLegacy({
    required String shopId,
    required String password,
    required String deviceId,
  }) async {
    final supabase = Supabase.instance.client;

    final shopData = await supabase.from('shops').select().eq('id', shopId).maybeSingle();
    if (shopData == null) throw Exception('Shop not found. Please check the Shop ID.');

    final shop = Shop.fromMap(shopData);
    final passwordHash = _hashPassword(password);

    final storedShopHash = shopData['password_hash'];
    final storedAdminHash = shopData['admin_password_hash'];
    if (storedShopHash != passwordHash && storedAdminHash != passwordHash) {
      throw Exception('Incorrect password. Please try again.');
    }

    final userId = supabase.auth.currentUser?.id;
    dynamic query = supabase.from('shop_members').select().eq('shop_id', shopId);
    if (userId != null) {
      query = query.or('device_id.eq.$deviceId,user_id.eq.$userId');
    } else {
      query = query.eq('device_id', deviceId);
    }
    final existing = await query.maybeSingle();

    if (existing == null) {
      throw Exception('Device/Account is not registered to this shop. Please "Join" instead.');
    }

    if (existing['device_id'] != deviceId) {
      await supabase.from('shop_members').update({'device_id': deviceId}).eq('id', existing['id']);
    }

    await supabase.from('shop_members').update({
      'is_active': true, 'last_active_at': DateTime.now().toIso8601String(),
    }).eq('id', existing['id']);

    await _storeShopId(shopId);
    await _cacheShopData(shop);
    await _cacheMemberData(ShopMember.fromMap(existing));

    debugPrint('✅ Logged into shop (legacy): $shopId');
    PerformanceMonitor().endTrace('AuthService.login', metadata: {'shopId': shopId});
    return shop;
  }

  /// Generate QR code data for shop
  static Future<String> generateShopQRCode(String shopId) async {
    // Format: myshop://join?shop_id=SHOP_ID
    return 'myshop://join?shop_id=$shopId';
  }

  /// Parse QR code and extract shop ID
  static String? parseShopQRCode(String qrData) {
    try {
      final uri = Uri.tryParse(qrData);
      if (uri?.scheme == 'myshop' && uri?.host == 'join') {
        return uri?.queryParameters['shop_id'];
      }
      // Also support plain shop IDs
      if (qrData.startsWith('shop_')) {
        return qrData;
      }
    } catch (e) {
      debugPrint('⚠️ Error parsing QR code: $e');
    }
    return null;
  }

  /// Update member's last active timestamp
  static Future<void> updateLastActive() async {
    try {
      final deviceId = await DeviceService.getDeviceId();
      final shopId = await _getStoredShopId();
      if (shopId == null) return;

      final supabase = Supabase.instance.client;
      await supabase
          .from('shop_members')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('shop_id', shopId)
          .eq('device_id', deviceId);
    } catch (e) {
      debugPrint('⚠️ Error updating last active: $e');
    }
  }

  /// Check if current device is the shop owner
  static Future<bool> isOwner() async {
    final member = await getCurrentMember();
    return member?.isOwner ?? false;
  }

  /// Get the current session mode for the active shop
  /// 
  /// This determines what level of access the current device/user has:
  /// - OPERATOR: Local staff (cashier role)
  /// - MANAGER: Admin privileges (manager/owner role)
  /// - OBSERVER: Ghost Mode - visiting enterprise owner with read-only access
  /// - GUEST: Not authenticated to any shop
  static Future<SessionMode> getSessionMode() async {
    final shopId = await _getStoredShopId();
    if (shopId == null || shopId.isEmpty) {
      return SessionMode.guest;
    }
    
    return await getSessionModeForShop(shopId);
  }

  /// Get session mode for a specific shop
  /// 
  /// Used to determine access level when visiting/connecting to a shop.
  /// For Enterprise owners visiting a shop they don't operate locally,
  /// this returns OBSERVER (Ghost Mode).
  static Future<SessionMode> getSessionModeForShop(String targetShopId) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final deviceId = await DeviceService.getDeviceId();
      
      // Check if we're a member of the target shop
      dynamic memberQuery = supabase
          .from('shop_members')
          .select('role, is_active')
          .eq('shop_id', targetShopId)
          .eq('is_active', true);
      
      if (user != null) {
        memberQuery = memberQuery.or('user_id.eq.${user.id},device_id.eq.$deviceId');
      } else {
        memberQuery = memberQuery.eq('device_id', deviceId);
      }
      
      final memberResult = await memberQuery.maybeSingle();
      
      if (memberResult != null) {
        // We ARE a member of this shop
        final role = memberResult['role'] as String?;
        
        if (role == 'OWNER' || role == 'MANAGER') {
          return SessionMode.manager;
        } else {
          return SessionMode.operator;
        }
      }
      
      // Not a member of target shop - check if we're an enterprise owner
      // An enterprise owner is someone who owns ANY shop and is visiting another
      if (user != null) {
        // Check if this user owns any shop
        final ownerCheck = await supabase
            .from('shops')
            .select('id')
            .eq('owner_id', user.id)
            .limit(1);
        
        if ((ownerCheck as List).isNotEmpty) {
          // User owns at least one shop - they're an enterprise owner
          // Visiting a different shop = Ghost Mode
          debugPrint('👻 Enterprise owner detected - entering Ghost Mode for shop: $targetShopId');
          return SessionMode.observer;
        }
      }
      
      // Also check by device ownership (for non-cloud-linked shops)
      final deviceOwnerCheck = await supabase
          .from('shops')
          .select('id')
          .eq('owner_device_id', deviceId)
          .limit(1);
      
      if ((deviceOwnerCheck as List).isNotEmpty) {
        final ownedShopId = deviceOwnerCheck.first['id'];
        if (ownedShopId != targetShopId) {
          // Device owns a different shop - Ghost Mode
          debugPrint('👻 Device owns shop $ownedShopId - Ghost Mode for $targetShopId');
          return SessionMode.observer;
        }
      }
      
      // Not a member and not an enterprise owner = guest
      return SessionMode.guest;
      
    } catch (e) {
      debugPrint('⚠️ Error determining session mode: $e');
      // Default to guest on error for safety
      return SessionMode.guest;
    }
  }

  /// Check if current session is in Ghost Mode (read-only access)
  /// 
  /// Ghost Mode is activated when an Enterprise owner (someone who owns at least
  /// one shop) visits a shop they don't operate. This prevents data pollution
  /// and ensures their device doesn't accidentally modify the foreign shop's ledger.
  static Future<bool> isGhostMode() async {
    final mode = await getSessionMode();
    return mode == SessionMode.observer;
  }
  
  /// Check if current session is in Ghost Mode for a specific shop
  static Future<bool> isGhostModeForShop(String shopId) async {
    final mode = await getSessionModeForShop(shopId);
    return mode == SessionMode.observer;
  }

  /// Hash password (SHA256 with salt) — LEGACY, used only as fallback.
  /// Server-side RPC functions now handle hashing inside Postgres.
  /// @deprecated Use server-side create_shop_secure / join_shop_secure / login_shop_secure
  static String _hashPassword(String password) {
    const salt = 'myshop_salt_2025_v1';
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Local storage helpers
  static Future<String?> _getStoredShopId() async {
    try {
      return await DeviceService.getShopId();
    } catch (e) {
      debugPrint('⚠️ Error reading shop ID: $e');
      return null;
    }
  }

  static Future<void> _storeShopId(String shopId) async {
    try {
      await DeviceService.setShopId(shopId);
    } catch (e) {
      debugPrint('❌ Error storing shop ID: $e');
    }
  }

  /// Cache shop data locally for offline access
  static Future<void> _cacheShopData(Shop shop) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopJson = jsonEncode(shop.toMap());
      await prefs.setString(_cachedShopDataKey, shopJson);
      
      // NEW: Sync to local SQLite for Server/API access
      await _syncToLocalDb(shop);
    } catch (e) {
      debugPrint('⚠️ Error caching shop data: $e');
    }
  }

  /// Get cached shop data (offline fallback)
  static Future<Shop?> _getCachedShopData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopJson = prefs.getString(_cachedShopDataKey);
      if (shopJson == null) return null;
      
      final shopMap = jsonDecode(shopJson) as Map<String, dynamic>;
      return Shop.fromMap(shopMap);
    } catch (e) {
      debugPrint('⚠️ Error reading cached shop: $e');
      return null;
    }
  }

  /// Cache member data locally for offline access
  static Future<void> _cacheMemberData(ShopMember member) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memberJson = jsonEncode(member.toMap());
      await prefs.setString(_cachedMemberDataKey, memberJson);
    } catch (e) {
      debugPrint('⚠️ Error caching member data: $e');
    }
  }

  /// Get cached member data (offline fallback)
  static Future<ShopMember?> _getCachedMemberData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memberJson = prefs.getString(_cachedMemberDataKey);
      if (memberJson == null) return null;
      
      final memberMap = jsonDecode(memberJson) as Map<String, dynamic>;
      return ShopMember.fromMap(memberMap);
    } catch (e) {
      debugPrint('⚠️ Error reading cached member: $e');
      return null;
    }
  }

  /// Logout - Clear local authentication data AND Supabase session
  static Future<void> logout() async {
    try {
      // 1. Sign out from Supabase (clears session tokens)
      await SupabaseAuthService.signOut();
      
      // 2. Clear local SharedPreferences
      await DeviceService.clearAllShopIds();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_memberIdKey);
      
      // 3. Clear memory cache
      _memoryCachedShop = null;
      _memoryCachedMember = null;
      
      debugPrint('✅ Logged out (Supabase session + local data cleared)');
    } catch (e) {
      debugPrint('⚠️ Error during logout: $e');
    }
  }

  /// Sync shop data to the active local SQLite database
  static Future<void> _syncToLocalDb(Shop shop) async {
    try {
      final db = await DbProvider.db;
      // Check if settings exist
      final existing = await db.query('shop_settings', limit: 1);
      
      // 🛡️ Safety Check: Don't overwrite a branded local name with a generic cloud default
      final newName = shop.businessName;
      final isNewNameGeneric = newName == 'My Shop' || newName == 'Unknown Shop' || newName == 'Mbeck Shop';
      
      if (existing.isEmpty) {
        await db.insert('shop_settings', {
          'shop_id': shop.id,
          'shop_name': newName,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        final currentLocalName = existing.first['shop_name'] as String?;
        final isLocalNameGeneric = currentLocalName == null || 
                                  currentLocalName == 'My Shop' || 
                                  currentLocalName == 'Unknown Shop' || 
                                  currentLocalName == 'Mbeck Shop';
        
        // Only update if the new name is NOT generic, OR if the local name IS generic
        if (!isNewNameGeneric || isLocalNameGeneric) {
          await db.update('shop_settings', {
            'shop_id': shop.id,
            'shop_name': newName,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          }, where: 'id = ?', whereArgs: [existing.first['id']]);
          debugPrint('✅ Synced shop settings to local DB: $newName');
        } else {
          debugPrint('ℹ️ Kept branded local name "$currentLocalName" instead of generic cloud name "$newName"');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error syncing to local DB: $e');
    }
  }

  /// Re-push cached shop data to Supabase when the cloud row is missing.
  /// This handles the scenario where a Supabase schema rebuild wiped the
  /// shops/shop_members tables but the local device still has valid data.
  static Future<void> _rePushShopToCloud(Shop shop) async {
    try {
      final supabase = Supabase.instance.client;
      final deviceId = await DeviceService.getDeviceId();
      final userId = supabase.auth.currentUser?.id;

      // Re-insert shop row (upsert to be idempotent)
      await supabase.from('shops').upsert({
        'id': shop.id,
        'name': shop.businessName,
        'password_hash': 'recovered', // Placeholder — user should re-set
        'owner_device_id': shop.ownerDeviceId,
        'owner_id': userId ?? shop.ownerId,
        'subscription_tier': shop.subscriptionTier,
        'subscription_status': shop.subscriptionStatus,
        'currency': shop.currency,
        'region': shop.region,
        'franchise_id': shop.franchiseId,
      }, onConflict: 'id');

      debugPrint('✅ Re-pushed shop to cloud: ${shop.id}');

      // Re-insert shop_member row so RLS policies allow access
      final cachedMember = await _getCachedMemberData();
      if (cachedMember != null) {
        await supabase.from('shop_members').upsert({
          'shop_id': shop.id,
          'device_id': deviceId,
          'user_id': userId,
          'user_name': cachedMember.userName,
          'role': cachedMember.role,
          'permissions': cachedMember.permissions,
          'is_active': true,
        }, onConflict: 'shop_id,device_id');

        debugPrint('✅ Re-pushed shop member to cloud');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to re-push shop to cloud: $e');
      // Non-fatal — the app will still work offline with cached data
    }
  }

  /// Get shop ID for current device (for filtering data)
  static Future<String?> getShopId() async {
    return await _getStoredShopId();
  }

  /// Get the currently authenticated Supabase User
  static Future<User?> getCurrentUser() async {
    return await SupabaseAuthService.getCurrentUser();
  }

  /// Check if the user has a Google account linked
  static bool isGoogleLinked(User? user) {
    return SupabaseAuthService.isGoogleLinked(user);
  }

  /// Get the email of the linked Google identity
  static String? getGoogleLinkedEmail(User? user) {
    return SupabaseAuthService.getGoogleLinkedEmail(user);
  }

  /// Link Google Account with Native OAuth + Redirect Fallback
  static Future<void> linkGoogleAccount() async {
    await SupabaseAuthService.linkGoogleAccount();
  }

  /// Unlink Google Account with Lockout Prevention
  static Future<void> unlinkGoogleAccount() async {
    await SupabaseAuthService.unlinkGoogleAccount();
  }
}
