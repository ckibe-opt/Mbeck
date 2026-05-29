import 'package:mbeck_shared/mbeck_shared.dart';

abstract class ShopApiService {
  String? get shopId;
  String? get shopName;
  bool get hasSession;

  Future<Map<String, dynamic>> fetchInfo();
  Future<bool> tryRestoreSession(String shopId);
  Future<void> clearSession();

  Future<List<InventoryItem>> getInventory();
  Future<Map<String, dynamic>> checkout(List<Map<String, dynamic>> items);

  Future<List<Map<String, dynamic>>> getRestaurantMenu();
  Future<List<Map<String, dynamic>>> getServicesCatalog();
  Future<List<Map<String, dynamic>>> getServicesStaff();
  Future<List<Map<String, dynamic>>> getEntertainmentAssets();

  Future<List<Map<String, dynamic>>> getLodgingRooms({int? typeId});
  Future<List<Map<String, dynamic>>> getLodgingRoomTypes();

  Future<bool> pingOrder({
    required String module,
    required List<Map<String, dynamic>> items,
    String? tableNumber,
    String? customerName,
    String? note,
  });

  Future<Map<String, dynamic>?> getReceipt(String txnId);
  Future<Map<String, dynamic>> getActiveOrders();
  Future<Map<String, dynamic>> getReceipts();

  // Services Module
  Future<List<String>> getServiceAvailability(String serviceId, String date);
  Future<bool> submitBooking(Map<String, dynamic> bookingData);

  // ─── Lodging Reservation ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> lodgingBook({
    required String roomId,
    required String guestName,
    required String guestPhone,
    required String checkInDate,
    required String checkOutDate,
    String notes = '',
  });

  // ─── Messaging (both LAN and Cloud) ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMessages();
  Future<bool> sendMessage(String content);
  Future<void> markMessagesRead();

  // ─── Analytics (fire-and-forget) ──────────────────────────────────────────
  Future<void> trackEvent(
    String eventType, {
    String? itemId,
    String? itemName,
    String? module,
  });
}
