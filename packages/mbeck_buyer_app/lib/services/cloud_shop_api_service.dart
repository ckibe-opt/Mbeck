import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
import 'shop_api_interface.dart';
import 'package:flutter/foundation.dart';

class CloudShopApiService implements ShopApiService {
  final String _shopId;
  final String _shopName;
  final _supabase = Supabase.instance.client;

  CloudShopApiService({required String shopId, required String shopName})
      : _shopId = shopId,
        _shopName = shopName;

  @override
  String? get shopId => _shopId;

  @override
  String? get shopName => _shopName;

  @override
  bool get hasSession => true; // Anonymous auth is always active

  @override
  Future<Map<String, dynamic>> fetchInfo() async {
    final response = await _supabase.from('shops').select().eq('id', _shopId).maybeSingle();
    if (response == null) throw Exception('Shop not found');
    return {
      'shopId': _shopId,
      'name': response['name'] ?? _shopName,
      'currency': response['currency'] ?? 'KES',
      'version': '1.0.0',
    };
  }

  @override
  Future<bool> tryRestoreSession(String shopId) async => true;

  @override
  Future<void> clearSession() async {}

  @override
  Future<List<InventoryItem>> getInventory() async {
    try {
      debugPrint('☁️ Cloud API: Fetching inventory for shop $_shopId (module: retail)');
      final response = await _supabase
          .from('marketplace_items')
          .select()
          .eq('shop_id', _shopId)
          .eq('module_source', 'retail')
          .eq('is_published', true);
      
      debugPrint('☁️ Cloud API: Received ${(response as List).length} items from marketplace_items');
      
      return (response as List).map((i) {
        final meta = i['metadata'] as Map<String, dynamic>? ?? {};
        
        // Map unified schema back to InventoryItem expected schema
        final mapped = Map<String, dynamic>.from(i);
        mapped['cloud_id'] = i['id']; // Map UUID to cloud_id
        mapped['sellingPrice'] = i['price'];
        mapped['originalPrice'] = i['original_price'];
        mapped['image_path'] = i['image_url'];
        mapped['specification'] = i['description'];
        mapped['stock'] = i['stock'] ?? 0;
        mapped['variations_json'] = meta['variations_json'];
        
        debugPrint('☁️ Cloud API: Mapped item ${i['name']} (stock: ${mapped['stock']})');
        return InventoryItem.fromMap(mapped);
      }).toList();
    } catch (e, stack) {
      debugPrint('❌ Cloud API Error (getInventory): $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> checkout(List<Map<String, dynamic>> items) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Calculate total locally or let edge function handle it
      // For MVP, submit order to local sync queue table or native orders table
      final response = await _supabase.from('cloud_orders').insert({
        'shop_id': _shopId,
        'customer_id': user.id,
        'items': items,
        'status': 'PENDING',
        'source': 'cloud_checkout',
      }).select().maybeSingle();

      return {'success': true, 'orderId': response?['id'], 'receiptId': response?['id']};
    } catch (e) {
      throw Exception('Cloud Checkout Error: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRestaurantMenu() async {
    try {
      debugPrint('☁️ Cloud API: Fetching restaurant menu for shop $_shopId');
      final response = await _supabase
          .from('marketplace_items')
          .select()
          .eq('shop_id', _shopId)
          .eq('module_source', 'restaurant')
          .eq('is_published', true);
          
      debugPrint('☁️ Cloud API: Received ${(response as List).length} items from marketplace_items (restaurant)');
          
      return (response as List).map((i) {
        final meta = i['metadata'] as Map<String, dynamic>? ?? {};
        return {
          'id': i['id'],
          'name': i['name'],
          'description': i['description'],
          'price': i['price'],
          'image_path': i['image_url'],
          'category': i['category'],
          'prep_time_minutes': meta['prep_time_minutes'] ?? 15,
          'available': (i['is_published'] == true) ? 1 : 0,
        };
      }).toList();
    } catch (e, stack) {
      debugPrint('❌ Cloud API Error (getRestaurantMenu): $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getServicesCatalog() async {
    try {
      debugPrint('☁️ Cloud API: Fetching services catalog for shop $_shopId');
      final response = await _supabase
          .from('marketplace_items')
          .select()
          .eq('shop_id', _shopId)
          .eq('module_source', 'services')
          .eq('is_published', true);
          
      debugPrint('☁️ Cloud API: Received ${(response as List).length} items from marketplace_items (services)');
          
      return (response as List).map((i) {
        final meta = i['metadata'] as Map<String, dynamic>? ?? {};
        return {
          'id': i['id'],
          'name': i['name'],
          'description': i['description'],
          'price': i['price'],
          'image_path': i['image_url'],
          'category': i['category'],
          'duration_minutes': meta['duration_minutes'] ?? 30,
          'active': (i['is_published'] == true) ? 1 : 0,
        };
      }).toList();
    } catch (e, stack) {
      debugPrint('❌ Cloud API Error (getServicesCatalog): $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getServicesStaff() async {
    // Phase 6 feature
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getEntertainmentAssets() async {
    final response = await _supabase
        .from('marketplace_items')
        .select()
        .eq('shop_id', _shopId)
        .eq('module_source', 'entertainment')
        .eq('is_published', true);
        
    return (response as List).map((i) {
      final meta = i['metadata'] as Map<String, dynamic>? ?? {};
      return {
        'id': i['id'],
        'name': i['name'],
        'description': i['description'],
        'price': i['price'],
        'image_path': i['image_url'],
        'category': i['category'],
        'type': meta['type'] ?? 'game',
        'available': (i['is_published'] == true) ? 1 : 0,
      };
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getLodgingRooms({int? typeId}) async {
    // For cloud mode, we primarily use room types. 
    // This fallback returns all published lodging items as rooms.
    return getLodgingRoomTypes();
  }

  @override
  Future<List<Map<String, dynamic>>> getLodgingRoomTypes() async {
    final response = await _supabase
        .from('marketplace_items')
        .select()
        .eq('shop_id', _shopId)
        .eq('module_source', 'lodging')
        .eq('is_published', true);
        
    return (response as List).map((i) {
      final meta = i['metadata'] as Map<String, dynamic>? ?? {};
      return {
        'id': i['id'],
        'name': i['name'],
        'description': i['description'],
        'rate_per_night': i['price'],
        'images': i['image_url'] != null ? [{'url': i['image_url']}] : [],
        'capacity': meta['capacity'] ?? 2,
        'amenities': meta['amenities'] ?? '',
        'available_rooms': meta['available_rooms'] ?? 1,
        'total_rooms': meta['total_rooms'] ?? 1,
      };
    }).toList();
  }

  @override
  Future<bool> pingOrder({
    required String module,
    required List<Map<String, dynamic>> items,
    String? tableNumber,
    String? customerName,
    String? note,
  }) async {
    try {
      await _supabase.from('kitchen_queue').insert({
        'shop_id': _shopId,
        'module': module,
        'items': items,
        'table_number': tableNumber,
        'customer_name': customerName,
        'notes': note,
        'status': 'NEW',
      });
      return true;
    } catch (e) {
      debugPrint('Cloud Ping Error: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getReceipt(String txnId) async {
    final response = await _supabase.from('receipts').select().eq('id', txnId).maybeSingle();
    return response;
  }

  @override
  Future<Map<String, dynamic>> getActiveOrders() async {
    // Cloud implementation placeholder. Real implementation would query Supabase for customer's cloud orders.
    return {'orders': [], 'count': 0};
  }

  @override
  Future<Map<String, dynamic>> getReceipts() async {
    // Cloud implementation placeholder. 
    return {'receipts': [], 'count': 0};
  }

  @override
  Future<List<String>> getServiceAvailability(String serviceId, String date) async {
    // Cloud mode doesn't track real-time slots yet, return empty to trigger default slots
    return [];
  }

  @override
  Future<bool> submitBooking(Map<String, dynamic> bookingData) async {
    try {
      await _supabase.from('service_bookings').insert({
        'shop_id': _shopId,
        ...bookingData,
        'status': 'PENDING',
      });
      return true;
    } catch (e) {
      debugPrint('Cloud Booking Error: $e');
      return false;
    }
  }

  // ─── Lodging Reservation ───────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> lodgingBook({
    required String roomId,
    required String guestName,
    required String guestPhone,
    required String checkInDate,   // YYYY-MM-DD
    required String checkOutDate,  // YYYY-MM-DD
    String notes = '',
  }) async {
    try {
      final buyerId = _supabase.auth.currentUser?.id;
      // Supabase expects timestamptz — append midnight UTC for date-only strings
      String toTs(String d) => d.contains('T') ? d : '${d}T00:00:00Z';
      final response = await _supabase.from('lodging_reservations').insert({
        'shop_id': _shopId,
        'room_id': roomId,           // UUID string
        'guest_name': guestName,
        'guest_phone': guestPhone,
        'check_in_date': toTs(checkInDate),
        'check_out_date': toTs(checkOutDate),
        'notes': notes,
        'status': 'PENDING',
        'source': 'cloud',
        if (buyerId != null) 'buyer_id': buyerId,
      }).select().maybeSingle();
      debugPrint('☁️ Cloud lodging reservation submitted: ${response?['id']}');
      return {
        'success': true,
        'source': 'cloud',
        'reservation_id': response?['id'],
        'message': 'Reservation request sent to the hotel. They will confirm shortly.',
      };
    } catch (e) {
      debugPrint('❌ Cloud lodgingBook error: $e');
      throw Exception('Could not submit reservation: $e');
    }
  }


  // ─── Messaging ─────────────────────────────────────────────────────────────


  @override
  Future<List<Map<String, dynamic>>> getMessages() async {
    try {
      final buyerId = _supabase.auth.currentUser?.id;
      if (buyerId == null) return [];
      final rows = await _supabase
          .from('cloud_messages')
          .select()
          .eq('shop_id', _shopId)
          .eq('buyer_id', buyerId)
          .order('created_at');
      return (rows as List).map((r) => {
        'id': r['id'],
        'sender': r['sender'],
        'content': r['content'],
        'timestamp': DateTime.parse(r['created_at'] as String).millisecondsSinceEpoch,
        'read': (r['read'] as bool? ?? false) ? 1 : 0,
      }).toList();
    } catch (e) {
      debugPrint('CloudShopApiService.getMessages error: $e');
      return [];
    }
  }

  @override
  Future<bool> sendMessage(String content) async {
    try {
      final buyerId = _supabase.auth.currentUser?.id;
      if (buyerId == null) return false;
      await _supabase.from('cloud_messages').insert({
        'shop_id': _shopId,
        'buyer_id': buyerId,
        'sender': 'buyer',
        'content': content,
      });
      await trackEvent('message_sent');
      return true;
    } catch (e) {
      debugPrint('CloudShopApiService.sendMessage error: $e');
      return false;
    }
  }

  @override
  Future<void> markMessagesRead() async {
    try {
      final buyerId = _supabase.auth.currentUser?.id;
      if (buyerId == null) return;
      await _supabase
          .from('cloud_messages')
          .update({'read': true})
          .eq('shop_id', _shopId)
          .eq('buyer_id', buyerId)
          .eq('sender', 'shop')
          .eq('read', false);
    } catch (e) {
      debugPrint('CloudShopApiService.markMessagesRead error: $e');
    }
  }

  // ─── Analytics ─────────────────────────────────────────────────────────────

  @override
  Future<void> trackEvent(
    String eventType, {
    String? itemId,
    String? itemName,
    String? module,
  }) async {
    try {
      final buyerId = _supabase.auth.currentUser?.id;
      await _supabase.from('shop_analytics_events').insert({
        'shop_id': _shopId,
        'buyer_id': buyerId,
        'event_type': eventType,
        if (itemId != null) 'item_id': itemId,
        if (itemName != null) 'item_name': itemName,
        if (module != null) 'module': module,
      });
    } catch (_) {} // fire-and-forget
  }
}
