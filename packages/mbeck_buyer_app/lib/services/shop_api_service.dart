import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mbeck_shared/mbeck_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'shop_session_storage.dart';
import 'shop_api_interface.dart';

export 'shop_api_interface.dart';
export 'cloud_shop_api_service.dart';

class LocalShopApiService implements ShopApiService {
  final String ip;
  final int port;
  
  // Session token for authenticated requests (in-memory cache)
  String? _sessionToken;
  String? _shopId;
  String? _shopName;
  int _tokenExpirySeconds = 86400; // Default 24h

  LocalShopApiService({required this.ip, required this.port});

  String get _baseUrl => 'http://$ip:$port/api/v1';
  @override
  String? get shopId => _shopId;
  @override
  String? get shopName => _shopName;
  @override
  bool get hasSession => _sessionToken != null;

  /// Retry a request with exponential backoff
  Future<http.Response> _retryRequest(
    Future<http.Response> Function() requestFn, {
    int maxAttempts = 3,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        attempt++;
        return await requestFn();
      } on TimeoutException {
        if (attempt >= maxAttempts) {
          throw Exception('Shop is not responding. Check your WiFi connection.');
        }
        debugPrint('⏱️ Request timed out (attempt $attempt/$maxAttempts), retrying...');
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      } on SocketException {
        if (attempt >= maxAttempts) {
          throw Exception('Cannot reach the shop. Make sure you\'re on the same WiFi network.');
        }
        debugPrint('🔌 Connection refused (attempt $attempt/$maxAttempts), retrying...');
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      } catch (e) {
        if (attempt >= maxAttempts) rethrow;
        debugPrint('❌ Request failed (attempt $attempt/$maxAttempts): $e');
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  /// Human-friendly error message from status code
  String _friendlyError(int statusCode, String context) {
    switch (statusCode) {
      case 404:
        return 'Endpoint not found. The shop may need to be updated.';
      case 500:
        return 'Shop server error. Try again in a moment.';
      case 503:
        return 'Shop is temporarily unavailable. Try again shortly.';
      default:
        return '$context failed (error $statusCode).';
    }
  }

  /// Fetch shop info and establish session (MUST be called first)
  /// 
  /// Returns the shop info and stores the session token for later use.
  /// Token is persisted locally for reconnection without re-handshake.
  Future<Map<String, dynamic>> fetchInfo() async {
    final url = Uri.parse('$_baseUrl/info');
    try {
      final response = await _retryRequest(
        () => http.get(url).timeout(const Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        
        // Store session token for authenticated requests
        _sessionToken = json['sessionToken'];
        _shopId = json['shopId'];
        _shopName = json['name'];
        _tokenExpirySeconds = json['tokenExpiresIn'] ?? 86400;
        
        // ===== PERSIST SESSION =====
        // Store token locally for reconnection without re-handshake
        if (_shopId != null && _sessionToken != null) {
          await ShopSessionStorage.setToken(
            shopId: _shopId!,
            token: _sessionToken!,
            expiresIn: Duration(seconds: _tokenExpirySeconds),
          );
          
          // Cache shop metadata for offline access
          await ShopSessionStorage.setShopMetadata(_shopId!, {
            'name': _shopName,
            'ip': ip,
            'port': port,
            'currency': json['currency'],
            'version': json['version'],
          });
        }
        // ===========================
        
        debugPrint('🔐 Session established with shop: $_shopName');
        return json;
      } else {
        throw Exception(_friendlyError(response.statusCode, 'Shop info'));
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Cannot reach shop. Check your WiFi connection.');
    }
  }

  /// Try to restore a cached session for faster reconnection
  /// 
  /// Call this before fetchInfo() to avoid unnecessary handshake.
  /// Returns true if a valid cached session was restored.
  Future<bool> tryRestoreSession(String shopId) async {
    final cachedToken = await ShopSessionStorage.getToken(shopId);
    if (cachedToken != null) {
      _sessionToken = cachedToken;
      _shopId = shopId;
      
      // Restore cached metadata
      final metadata = await ShopSessionStorage.getShopMetadata(shopId);
      if (metadata != null) {
        _shopName = metadata['name'];
      }
      
      debugPrint('🔄 Session restored for shop: $_shopName');
      return true;
    }
    return false;
  }

  /// Get or generate a persistent client ID for this device
  Future<String> _getClientId() async {
    final prefs = await SharedPreferences.getInstance();
    String? clientId = prefs.getString('buyer_client_id');
    if (clientId == null) {
      clientId = const Uuid().v4();
      await prefs.setString('buyer_client_id', clientId);
    }
    return clientId;
  }

  /// Fetch public inventory from the shop
  Future<List<InventoryItem>> getInventory() async {
    final url = Uri.parse('$_baseUrl/inventory/public');
    try {
      final response = await _retryRequest(
        () => http.get(url).timeout(const Duration(seconds: 10)),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final List<dynamic> data = json['data'];
        
        return data.map((item) => InventoryItem.fromMap(item)).toList();
      } else {
        throw Exception(_friendlyError(response.statusCode, 'Loading inventory'));
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Cannot load inventory. Check your connection.');
    }
  }



  /// Perform checkout for the current cart (REQUIRES session token)
  /// 
  /// Call fetchInfo() first to establish a session.
  Future<Map<String, dynamic>> checkout(List<Map<String, dynamic>> items) async {
    // Ensure we have a session
    if (_sessionToken == null) {
      await fetchInfo();
    }
    
    final url = Uri.parse('$_baseUrl/cart/checkout');
    
    final clientId = await _getClientId();
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_sessionToken', // REQUIRED for checkout
          'x-client-id': clientId, // Inject client ID for receipts matching
        },
        body: jsonEncode({
          'items': items, // Format: [{"id": 1, "qty": 2}]
          'meta': 'MbeckBuyer/1.0',
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        // Token expired, clear and retry with new session
        debugPrint('⏰ Token expired, refreshing...');
        if (_shopId != null) {
          await ShopSessionStorage.removeSession(_shopId!);
        }
        _sessionToken = null;
        await fetchInfo();
        return checkout(items); // Retry once
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please wait and try again.');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Checkout failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Checkout connection error: $e');
    }
  }
  
  /// Clear session (call when disconnecting from shop)
  Future<void> clearSession() async {
    if (_shopId != null) {
      await ShopSessionStorage.removeSession(_shopId!);
    }
    _sessionToken = null;
    _shopId = null;
    _shopName = null;
    debugPrint('🔓 Session cleared');
  }


  /// Fetch restaurant menu from shop
  Future<List<Map<String, dynamic>>> getRestaurantMenu() async {
    final url = Uri.parse('$_baseUrl/restaurant/menu');
    try {
      final response = await _retryRequest(
        () => http.get(url).timeout(const Duration(seconds: 8)),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(json['menu'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Failed to load restaurant menu: $e');
      return [];
    }
  }

  /// Fetch services catalog from shop
  Future<List<Map<String, dynamic>>> getServicesCatalog() async {
    final url = Uri.parse('$_baseUrl/services/catalog');
    try {
      final response = await _retryRequest(
        () => http.get(url).timeout(const Duration(seconds: 8)),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(json['catalog'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Failed to load services catalog: $e');
      return [];
    }
  }

  /// Fetch services staff list
  Future<List<Map<String, dynamic>>> getServicesStaff() async {
    final url = Uri.parse('$_baseUrl/services/staff');
    try {
      final response = await _retryRequest(
        () => http.get(url).timeout(const Duration(seconds: 8)),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(json['staff'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Failed to load services staff: $e');
      return [];
    }
  }

  /// Fetch entertainment assets from shop
  Future<List<Map<String, dynamic>>> getEntertainmentAssets() async {
    final url = Uri.parse('$_baseUrl/entertainment/assets');
    try {
      final response = await _retryRequest(
        () => http.get(url).timeout(const Duration(seconds: 8)),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(json['assets'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Failed to load entertainment assets: $e');
      return [];
    }
  }

  /// Fetch lodging rooms from shop (all or filtered by type)
  Future<List<Map<String, dynamic>>> getLodgingRooms({int? typeId}) async {
    final queryParam = typeId != null ? '?typeId=$typeId' : '';
    final url = Uri.parse('$_baseUrl/lodging/rooms$queryParam');
    try {
      final response = await _retryRequest(
        () => http.get(url).timeout(const Duration(seconds: 8)),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(json['rooms'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Failed to load lodging rooms: $e');
      return [];
    }
  }

  /// Fetch lodging room types with images and availability
  Future<List<Map<String, dynamic>>> getLodgingRoomTypes() async {
    final url = Uri.parse('$_baseUrl/lodging/room-types');
    try {
      final response = await _retryRequest(
        () => http.get(url).timeout(const Duration(seconds: 8)),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(json['roomTypes'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Failed to load lodging room types: $e');
      return [];
    }
  }

  /// Ping the shop that an order is ready (buyer picked items)
  Future<bool> pingOrder({
    required String module,
    required List<Map<String, dynamic>> items,
    String? tableNumber,
    String? customerName,
    String? note,
  }) async {
    final url = Uri.parse('$_baseUrl/order/ping');
    final clientId = await _getClientId();
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          // Forward client identity so the seller can link the resulting
          // restaurant_order back to this buyer for active-order tracking.
          'x-client-id': clientId,
        },
        body: jsonEncode({
          'module': module,
          'items': items,
          'tableNumber': tableNumber ?? '',
          'customerName': customerName ?? 'Customer',
          'clientId': clientId,
          'note': note ?? '',
        }),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to ping order: $e');
      return false;
    }
  }

  /// Fetch a receipt by transaction ID or signature
  Future<Map<String, dynamic>?> getReceipt(String txnId) async {
    final url = Uri.parse('$_baseUrl/receipt/$txnId');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['receipt'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to fetch receipt: $e');
      return null;
    }
  }

  /// Fetch active orders for the current client session
  Future<Map<String, dynamic>> getActiveOrders() async {
    if (_sessionToken == null) await fetchInfo();
    final clientId = await _getClientId();
    final url = Uri.parse('$_baseUrl/orders/active');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_sessionToken',
          'x-client-id': clientId,
        },
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'orders': [], 'count': 0};
    } catch (e) {
      debugPrint('Failed to fetch active orders: $e');
      return {'orders': [], 'count': 0};
    }
  }

  /// Fetch all historical receipts for the current client session
  Future<Map<String, dynamic>> getReceipts() async {
    if (_sessionToken == null) await fetchInfo();
    final clientId = await _getClientId();
    final url = Uri.parse('$_baseUrl/receipts');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_sessionToken',
          'x-client-id': clientId,
        },
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'receipts': [], 'count': 0};
    } catch (e) {
      debugPrint('Failed to fetch receipts: $e');
      return {'receipts': [], 'count': 0};
    }
  }

  @override
  Future<List<String>> getServiceAvailability(String serviceId, String date) async {
    final url = Uri.parse('$_baseUrl/services/availability?service_id=$serviceId&date=$date');
    try {
      final response = await _retryRequest(
        () => http.get(url).timeout(const Duration(seconds: 5)),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['slots'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Error loading availability: $e');
      return [];
    }
  }

  @override
  Future<bool> submitBooking(Map<String, dynamic> bookingData) async {
    final url = Uri.parse('$_baseUrl/services/book');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bookingData),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error submitting booking: $e');
      return false;
    }
  }

  // ─── GAP 4: LODGING RESERVATION ────────────────────────────────────────────

  /// Reserve a room at the connected shop.
  /// Returns {success, reservation_id, total_amount} or throws.
  Future<Map<String, dynamic>> lodgingBook({
    required String roomId,
    required String guestName,
    required String guestPhone,
    required String checkInDate,  // YYYY-MM-DD
    required String checkOutDate, // YYYY-MM-DD
    String notes = '',
  }) async {
    final clientId = await _getClientId();
    final url = Uri.parse('$_baseUrl/lodging/book');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'x-client-id': clientId},
        body: jsonEncode({
          'room_id': roomId,
          'guest_name': guestName,
          'guest_phone': guestPhone,
          'check_in_date': checkInDate,
          'check_out_date': checkOutDate,
          'notes': notes,
        }),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Booking failed');
    } catch (e) {
      debugPrint('lodgingBook error: $e');
      rethrow;
    }
  }

  // ─── GAP 4: ENTERTAINMENT BOOKING ──────────────────────────────────────────

  /// Start an entertainment session at the connected shop.
  /// Returns {success, session_id} or throws.
  Future<Map<String, dynamic>> entertainmentBook({
    required int assetId,
    required String customerName,
    String notes = '',
  }) async {
    final clientId = await _getClientId();
    final url = Uri.parse('$_baseUrl/entertainment/book');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'x-client-id': clientId},
        body: jsonEncode({
          'asset_id': assetId,
          'customer_name': customerName,
          'notes': notes,
        }),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Booking failed');
    } catch (e) {
      debugPrint('entertainmentBook error: $e');
      rethrow;
    }
  }

  // ─── GAP 5: MESSAGING ──────────────────────────────────────────────────────

  /// Fetch all messages for this client from the connected shop.
  Future<List<Map<String, dynamic>>> getMessages() async {
    final clientId = await _getClientId();
    final url = Uri.parse('$_baseUrl/messages');
    try {
      final response = await http.get(
        url,
        headers: {'x-client-id': clientId},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['messages'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('getMessages error: $e');
      return [];
    }
  }

  /// Send a message from the buyer to the shop.
  Future<bool> sendMessage(String content) async {
    final clientId = await _getClientId();
    final url = Uri.parse('$_baseUrl/messages');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'x-client-id': clientId},
        body: jsonEncode({'content': content}),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('sendMessage error: $e');
      return false;
    }
  }

  /// Mark all shop-sent messages as read.
  Future<void> markMessagesRead() async {
    final clientId = await _getClientId();
    final url = Uri.parse('$_baseUrl/messages/read');
    try {
      await http.patch(url, headers: {'x-client-id': clientId})
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('markMessagesRead error: $e');
    }
  }

  @override
  Future<void> trackEvent(
    String eventType, {
    String? itemId,
    String? itemName,
    String? module,
  }) async {
    // LAN mode — no Supabase analytics
  }
}




