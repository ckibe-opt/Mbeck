import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../db/db_provider.dart';
import 'event_service.dart';
import 'security_service.dart';
import 'cloud_storage_service.dart';

/// Centralized service layer for the Lodging module.
///
/// Manages:
/// - Room registry CRUD
/// - Reservation lifecycle (pending → confirmed → checked_in → checked_out)
/// - Check-in / check-out with billing
/// - Room status tracking (available / occupied / cleaning / maintenance)
/// - Revenue queries
class LodgingService {
  // ========== ROOM TYPES ==========

  static Future<List<Map<String, dynamic>>> getRoomTypesWithDetails() async {
    final db = await DbProvider.db;
    return await db.rawQuery('''
      SELECT rt.*,
             COUNT(DISTINCT r.id) as room_count,
             (SELECT COUNT(*) FROM lodging_room_type_images WHERE room_type_id = rt.id) as image_count
      FROM lodging_room_types rt
      LEFT JOIN lodging_rooms r ON r.room_type_id = rt.id AND r.is_active = 1
      WHERE rt.is_active = 1
      GROUP BY rt.id
      ORDER BY rt.name ASC
    ''');
  }

  static Future<List<Map<String, dynamic>>> getActiveRoomTypes() async {
    final db = await DbProvider.db;
    return await db.query(
      'lodging_room_types',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
  }

  static Future<int> createRoomType({
    required String name,
    double ratePerNight = 0,
    double? ratePerWeek,
    double? ratePerMonth,
    int capacity = 2,
    String? amenities,
    String? description,
    bool isPublished = false,
  }) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final id = await db.insert('lodging_room_types', {
      'cloud_id': const Uuid().v4(),
      'name': name,
      'rate_per_night': ratePerNight,
      'rate_per_week': ratePerWeek,
      'rate_per_month': ratePerMonth,
      'capacity': capacity,
      'amenities': amenities,
      'description': description,
      'is_published': isPublished ? 1 : 0,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    EventService.emitEvent(
      eventType: 'LODGING_ROOM_TYPE_CREATE',
      payload: {'room_type_id': id, 'name': name, 'rate': ratePerNight},
    );

    debugPrint('🏨 Created room type: $name — KES $ratePerNight/night');
    return id;
  }

  static Future<void> updateRoomType(int id, Map<String, dynamic> updates) async {
    final db = await DbProvider.db;
    updates['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.update('lodging_room_types', updates, where: 'id = ?', whereArgs: [id]);

    EventService.emitEvent(
      eventType: 'LODGING_ROOM_TYPE_UPDATE',
      payload: {'room_type_id': id, ...updates},
    );
  }

  static Future<List<Map<String, dynamic>>> getRoomTypeImages(int typeId) async {
    final db = await DbProvider.db;
    return await db.query(
      'lodging_room_type_images',
      where: 'room_type_id = ?',
      whereArgs: [typeId],
      orderBy: 'sort_order ASC',
    );
  }

  static Future<void> saveRoomTypeImages(int typeId, List<String> imagePaths) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Delete old images
    await db.delete('lodging_room_type_images',
        where: 'room_type_id = ?', whereArgs: [typeId]);

    // Insert new images
    for (int i = 0; i < imagePaths.length; i++) {
      final cloudUrl = await CloudStorageService.uploadImage(imagePaths[i], folder: 'lodging');
      final finalPath = (cloudUrl != null && cloudUrl.startsWith('http')) ? cloudUrl : imagePaths[i];

      await db.insert('lodging_room_type_images', {
        'room_type_id': typeId,
        'image_path': finalPath,
        'sort_order': i,
        'created_at': now,
      });
    }
  }

  // ========== ROOMS ==========

  static Future<List<Map<String, dynamic>>> getRooms({
    String? roomType,
    int? roomTypeId,
    bool activeOnly = true,
  }) async {
    final db = await DbProvider.db;
    String where = '';
    List<dynamic> whereArgs = [];

    if (activeOnly) {
      where = 'r.is_active = 1';
    }
    if (roomTypeId != null) {
      where += where.isNotEmpty ? ' AND r.room_type_id = ?' : 'r.room_type_id = ?';
      whereArgs.add(roomTypeId);
    } else if (roomType != null && roomType != 'All') {
      where += where.isNotEmpty ? ' AND r.room_type = ?' : 'r.room_type = ?';
      whereArgs.add(roomType);
    }

    return await db.rawQuery('''
      SELECT r.*,
             rt.name as type_name,
             rt.is_published as type_is_published,
             rt.amenities as type_amenities,
             rt.rate_per_night as type_rate,
             rt.capacity as type_capacity,
             (SELECT image_path FROM lodging_room_type_images 
              WHERE room_type_id = r.room_type_id ORDER BY sort_order ASC LIMIT 1) as type_image
      FROM lodging_rooms r
      LEFT JOIN lodging_room_types rt ON r.room_type_id = rt.id
      ${where.isNotEmpty ? 'WHERE $where' : ''}
      ORDER BY r.floor ASC, r.name ASC
    ''', whereArgs);
  }

  static Future<List<String>> getRoomTypeNames() async {
    final db = await DbProvider.db;
    final result = await db.rawQuery(
      "SELECT DISTINCT name FROM lodging_room_types WHERE is_active = 1 ORDER BY name ASC",
    );
    return result.map((r) => r['name'] as String).toList();
  }

  /// Batch-create multiple rooms in a single transaction
  static Future<int> batchCreateRooms({
    required int roomTypeId,
    required int startNumber,
    required int endNumber,
    required String floor,
    String prefix = 'Room',
  }) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Get type info for the room_type text field
    final types = await db.query('lodging_room_types',
        where: 'id = ?', whereArgs: [roomTypeId]);
    if (types.isEmpty) throw Exception('Room type not found');
    final type = types.first;

    int created = 0;
    await db.transaction((txn) async {
      for (int num = startNumber; num <= endNumber; num++) {
        final name = '$prefix $num';
        await txn.insert('lodging_rooms', {
          'cloud_id': const Uuid().v4(),
          'name': name,
          'room_type': type['name'],
          'room_type_id': roomTypeId,
          'floor': floor,
          'capacity': type['capacity'],
          'rate_per_night': type['rate_per_night'],
          'amenities': type['amenities'],
          'status': 'available',
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
        created++;
      }
    });

    EventService.emitEvent(
      eventType: 'LODGING_ROOMS_BATCH_CREATE',
      payload: {
        'room_type_id': roomTypeId,
        'type_name': type['name'],
        'floor': floor,
        'start': startNumber,
        'end': endNumber,
        'count': created,
      },
    );

    debugPrint('🏨 Batch created $created rooms: $prefix $startNumber-$endNumber (${type['name']}, Floor $floor)');
    return created;
  }

  static Future<int> createRoom({
    required String name,
    required String roomType,
    required double ratePerNight,
    int? roomTypeId,
    int capacity = 2,
    String? floor,
    String? amenities,
    String? description,
  }) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cloudId = const Uuid().v4();

    final id = await db.insert('lodging_rooms', {
      'cloud_id': cloudId,
      'source_module': 'lodging',
      'name': name,
      'room_type': roomType,
      'room_type_id': roomTypeId,
      'floor': floor,
      'capacity': capacity,
      'rate_per_night': ratePerNight,
      'amenities': amenities,
      'description': description,
      'status': 'available',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    EventService.emitEvent(
      eventType: 'LODGING_ROOM_CREATE',
      payload: {'cloud_id': cloudId, 'source_module': 'lodging', 'room_id': id, 'name': name, 'room_type': roomType},
    );

    debugPrint('🏨 Created room: $name ($roomType) — KES $ratePerNight/night');
    return id;
  }

  static Future<void> updateRoom(int id, Map<String, dynamic> updates) async {
    final db = await DbProvider.db;
    updates['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.update('lodging_rooms', updates, where: 'id = ?', whereArgs: [id]);

    EventService.emitEvent(
      eventType: 'LODGING_ROOM_UPDATE',
      payload: {'source_module': 'lodging', 'room_id': id, ...updates},
    );
  }

  static Future<void> setRoomStatus(int roomId, String status) async {
    await updateRoom(roomId, {'status': status});
  }

  static Future<void> toggleRoomActive(int id, bool active) async {
    await updateRoom(id, {'is_active': active ? 1 : 0});
  }

  static Future<void> toggleRoomPublished(int id, bool published) async {
    await updateRoom(id, {'is_published': published ? 1 : 0});
  }

  static Future<void> toggleRoomTypePublished(int id, bool published) async {
    await updateRoomType(id, {'is_published': published ? 1 : 0});
  }

  static Future<void> deleteRoom(int id) async {
    final db = await DbProvider.db;
    await db.delete('lodging_rooms', where: 'id = ?', whereArgs: [id]);
    EventService.emitEvent(
      eventType: 'LODGING_ROOM_DELETE',
      payload: {'source_module': 'lodging', 'room_id': id},
    );
  }

  // ========== ROOM STATUS BOARD ==========

  /// Returns rooms with their current reservation info (if occupied).
  static Future<List<Map<String, dynamic>>> getRoomStatusBoard() async {
    final db = await DbProvider.db;
    return await db.rawQuery('''
      SELECT r.*,
             res.id as reservation_id,
             res.guest_name,
             res.guest_phone,
             res.check_in_date,
             res.check_out_date,
             res.actual_check_in,
             res.nights,
             res.rate_per_night as res_rate,
             res.total_amount as res_total,
             res.status as res_status
      FROM lodging_rooms r
      LEFT JOIN lodging_reservations res
        ON res.room_id = r.id AND res.status = 'checked_in'
      WHERE r.is_active = 1
      ORDER BY r.sort_order ASC, r.name ASC
    ''');
  }

  // ========== RESERVATIONS ==========

  /// Creates a reservation. The UI computes [totalAmount] and [billingUnit]
  /// so that weekly/monthly/custom billing is fully flexible.
  static Future<int> createReservation({
    required int roomId,
    required String guestName,
    String? guestPhone,
    String? guestEmail,
    String? guestIdNumber,
    int? customerId,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    String? notes,
    double amountPaid = 0,
    /// 'night' | 'week' | 'month' | 'custom'
    String billingUnit = 'night',
    /// Pre-computed total from the UI (handles weekly/monthly discounted rates).
    /// If null, falls back to rate_per_night × nights.
    double? totalAmount,
  }) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Look up room rate
    final rooms = await db.query('lodging_rooms',
        where: 'id = ?', whereArgs: [roomId]);
    if (rooms.isEmpty) throw Exception('Room not found');
    final room = rooms.first;
    final ratePerNight = (room['rate_per_night'] as num?)?.toDouble() ?? 0;

    // Calculate nights (always store total days for record-keeping)
    final nights = checkOutDate.difference(checkInDate).inDays;
    if (nights < 1) throw Exception('Check-out must be after check-in');

    final computedTotal = totalAmount ?? (ratePerNight * nights);

    final cloudId = const Uuid().v4();

    final id = await db.insert('lodging_reservations', {
      'cloud_id': cloudId,
      'source_module': 'lodging',
      'customer_id': customerId,
      'room_id': roomId,
      'guest_name': guestName,
      'guest_phone': guestPhone,
      'guest_email': guestEmail,
      'guest_id_number': guestIdNumber,
      'check_in_date': checkInDate.millisecondsSinceEpoch,
      'check_out_date': checkOutDate.millisecondsSinceEpoch,
      'nights': nights,
      'rate_per_night': ratePerNight,
      'total_amount': computedTotal,
      'amount_paid': amountPaid,
      'billing_unit': billingUnit,
      'status': 'pending',
      'notes': notes,
      'created_at': now,
      'updated_at': now,
    });

    EventService.emitEvent(
      eventType: 'LODGING_RESERVATION_CREATE',
      payload: {
        'cloud_id': cloudId,
        'source_module': 'lodging',
        'reservation_id': id,
        'room_id': roomId,
        'guest_name': guestName,
        'check_in': checkInDate.millisecondsSinceEpoch,
        'check_out': checkOutDate.millisecondsSinceEpoch,
        'nights': nights,
        'billing_unit': billingUnit,
        'total_amount': computedTotal,
      },
    );

    debugPrint(
        '📅 Reservation #$id: $guestName, ${room['name']}, $nights nights ($billingUnit)');
    return id;
  }

  static Future<void> confirmReservation(int reservationId) async {
    await _updateReservationStatus(reservationId, 'confirmed');
  }

  static Future<void> checkIn(int reservationId) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Get reservation and room
    final reservations = await db.query('lodging_reservations',
        where: 'id = ?', whereArgs: [reservationId]);
    if (reservations.isEmpty) throw Exception('Reservation not found');
    final res = reservations.first;
    
    // Check room status to prevent dirty check-in bypass
    final rooms = await db.query('lodging_rooms', where: 'id = ?', whereArgs: [res['room_id']]);
    if (rooms.isNotEmpty && rooms.first['status'] != 'available') {
      throw Exception('Room is not available for check-in (Status: ${rooms.first['status']})');
    }

    // Update reservation status
    await db.update('lodging_reservations', {
      'status': 'checked_in',
      'actual_check_in': now,
      'updated_at': now,
    }, where: 'id = ?', whereArgs: [reservationId]);

    // Set room to occupied
    await setRoomStatus(res['room_id'] as int, 'occupied');

    EventService.emitEvent(
      eventType: 'LODGING_CHECK_IN',
      payload: {
        'reservation_id': reservationId,
        'room_id': res['room_id'],
        'guest_name': res['guest_name'],
      },
    );

    debugPrint('✅ Check-in: ${res['guest_name']} → Room ${res['room_id']}');
  }

  static Future<void> checkOut(int reservationId) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Get reservation
    final reservations = await db.query('lodging_reservations',
        where: 'id = ?', whereArgs: [reservationId]);
    if (reservations.isEmpty) throw Exception('Reservation not found');
    final res = reservations.first;

    final totalAmount = (res['total_amount'] as num?)?.toDouble() ?? 0;
    final amountPaid = (res['amount_paid'] as num?)?.toDouble() ?? 0;
    final roomId = res['room_id'] as int;

    // Update reservation
    await db.update('lodging_reservations', {
      'status': 'checked_out',
      'actual_check_out': now,
      'updated_at': now,
    }, where: 'id = ?', whereArgs: [reservationId]);

    // Set room to cleaning
    await setRoomStatus(roomId, 'cleaning');

    // Build human-readable stay description based on billing unit
    final rooms = await db.query('lodging_rooms',
        where: 'id = ?', whereArgs: [roomId]);
    final roomName = rooms.isNotEmpty ? rooms.first['name'] : 'Room';
    final nights = res['nights'] as int? ?? 0;
    final billingUnit = res['billing_unit'] as String? ?? 'night';
    final String stayDesc;
    switch (billingUnit) {
      case 'week':
        final weeks = (nights / 7).ceil();
        stayDesc = '$weeks week${weeks != 1 ? 's' : ''}';
        break;
      case 'month':
        final months = (nights / 30).ceil();
        stayDesc = '$months month${months != 1 ? 's' : ''}';
        break;
      case 'custom':
        final m = nights ~/ 30;
        final w = (nights % 30) ~/ 7;
        final d = (nights % 30) % 7;
        final parts = <String>[];
        if (m > 0) parts.add('$m mo');
        if (w > 0) parts.add('$w wk');
        if (d > 0) parts.add('$d d');
        stayDesc = parts.isEmpty ? '$nights nights' : parts.join(' ');
        break;
      default:
        stayDesc = '$nights night${nights != 1 ? 's' : ''}';
    }
    
    // Process finances: Split the total into what was Paid vs what is Owed/Debt (Deficit)
    double cashReceived = amountPaid;
    if (cashReceived > totalAmount) cashReceived = totalAmount; // Cap sale at totalAmount
    
    if (cashReceived > 0) {
      final details = 'Lodging: $roomName — ${res['guest_name']} ($stayDesc)';
      final signature = await SecurityService().signTransaction(
        timestamp: now,
        totalAmount: cashReceived,
        type: 'sale',
        details: details,
      );

      await db.insert('txn', {
        'type': 'sale',
        'totalAmount': cashReceived.round(),
        'details': details,
        'timestamp': now,
        'receiptSignature': signature,
        'source_module': 'lodging',
      });
    }
    
    final deficit = totalAmount - amountPaid;
    if (deficit > 0) {
      // Record a debt transaction in the raw txn ledger to preserve immutable ledger states
      final debtDetails = 'Lodging (Debt Unpaid): $roomName — ${res['guest_name']} ($stayDesc)';
      final txnId = await db.insert('txn', {
        'type': 'owing',
        'totalAmount': deficit.round(),
        'details': debtDetails,
        'timestamp': now,
        'source_module': 'lodging',
      });

      // Synchronize directly into the central CRM Customers Ledger
      await db.insert('customer_ledger', {
        'customer_id': res['customer_id'],
        'customer_name': res['guest_name'],
        'customer_phone': res['guest_phone'],
        'type': 'owing',
        'amount': deficit,
        'notes': 'Unpaid Deficit for Room: $roomName ($stayDesc)',
        'txn_id': txnId,
        'status': 'open',
        'created_at': now,
      });
    }

    EventService.emitEvent(
      eventType: 'LODGING_CHECK_OUT',
      payload: {
        'reservation_id': reservationId,
        'room_id': roomId,
        'guest_name': res['guest_name'],
        'total_amount': totalAmount,
        'deficit': deficit > 0 ? deficit : 0,
      },
    );

    debugPrint('🚪 Check-out: ${res['guest_name']} — Paid: KES ${amountPaid.toStringAsFixed(0)} / Deficit: KES ${deficit > 0 ? deficit.toStringAsFixed(0) : "0"}');
  }

  static Future<void> cancelReservation(int reservationId) async {
    final db = await DbProvider.db;
    final reservations = await db.query('lodging_reservations',
        where: 'id = ?', whereArgs: [reservationId]);
    if (reservations.isEmpty) return;
    final res = reservations.first;

    await _updateReservationStatus(reservationId, 'cancelled');

    // If room was occupied by this reservation, free it
    if (res['status'] == 'checked_in') {
      await setRoomStatus(res['room_id'] as int, 'available');
    }
  }

  static Future<void> _updateReservationStatus(int id, String status) async {
    final db = await DbProvider.db;
    await db.update('lodging_reservations', {
      'status': status,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [id]);

    EventService.emitEvent(
      eventType: 'LODGING_RESERVATION_STATUS',
      payload: {'reservation_id': id, 'status': status},
    );
  }

  static Future<void> deleteReservation(int reservationId) async {
    final db = await DbProvider.db;
    await db.delete('lodging_reservations',
        where: 'id = ?', whereArgs: [reservationId]);
  }

  /// Mark room as available after cleaning
  static Future<void> markRoomClean(int roomId) async {
    await setRoomStatus(roomId, 'available');
  }

  /// Put room into maintenance mode
  static Future<void> markRoomMaintenance(int roomId) async {
    await setRoomStatus(roomId, 'maintenance');
  }

  // ========== QUERIES ==========

  static Future<List<Map<String, dynamic>>> getReservationsForDateRange(
      DateTime start, DateTime end) async {
    final db = await DbProvider.db;
    return await db.rawQuery('''
      SELECT r.*, lr.name as room_name, lr.room_type
      FROM lodging_reservations r
      JOIN lodging_rooms lr ON r.room_id = lr.id
      WHERE r.check_in_date < ? AND r.check_out_date > ?
        AND r.status NOT IN ('cancelled')
      ORDER BY r.check_in_date ASC
    ''', [end.millisecondsSinceEpoch, start.millisecondsSinceEpoch]);
  }

  static Future<List<Map<String, dynamic>>> getUpcomingReservations({
    int limit = 20,
  }) async {
    final db = await DbProvider.db;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return await db.rawQuery('''
      SELECT r.*, lr.name as room_name, lr.room_type
      FROM lodging_reservations r
      JOIN lodging_rooms lr ON r.room_id = lr.id
      WHERE r.check_in_date >= ?
        AND r.status IN ('pending', 'confirmed')
      ORDER BY r.check_in_date ASC
      LIMIT ?
    ''', [startOfDay.millisecondsSinceEpoch, limit]);
  }

  static Future<List<Map<String, dynamic>>> getActiveStays() async {
    final db = await DbProvider.db;
    return await db.rawQuery('''
      SELECT r.*, lr.name as room_name, lr.room_type
      FROM lodging_reservations r
      JOIN lodging_rooms lr ON r.room_id = lr.id
      WHERE r.status = 'checked_in'
      ORDER BY r.check_out_date ASC
    ''');
  }

  /// Check for date conflicts on a room
  static Future<bool> hasConflict({
    required int roomId,
    required DateTime checkIn,
    required DateTime checkOut,
    int? excludeReservationId,
  }) async {
    final db = await DbProvider.db;
    String sql = '''
      SELECT COUNT(*) as cnt FROM lodging_reservations
      WHERE room_id = ?
      AND status NOT IN ('cancelled', 'checked_out')
      AND check_in_date < ? AND check_out_date > ?
    ''';
    List<dynamic> args = [
      roomId,
      checkOut.millisecondsSinceEpoch,
      checkIn.millisecondsSinceEpoch,
    ];

    if (excludeReservationId != null) {
      sql += ' AND id != ?';
      args.add(excludeReservationId);
    }

    final result = await db.rawQuery(sql, args);
    return ((result.first['cnt'] as int?) ?? 0) > 0;
  }

  // ========== REVENUE ==========

  static Future<double> getTodayRevenue() async {
    final db = await DbProvider.db;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as revenue
      FROM lodging_reservations
      WHERE status = 'checked_out' AND actual_check_out >= ?
    ''', [startOfDay]);

    return (result.first['revenue'] as num?)?.toDouble() ?? 0.0;
  }

  static Future<Map<String, int>> getRoomStatusCounts() async {
    final db = await DbProvider.db;
    final result = await db.rawQuery('''
      SELECT status, COUNT(*) as cnt
      FROM lodging_rooms
      WHERE is_active = 1
      GROUP BY status
    ''');

    final counts = <String, int>{};
    for (final row in result) {
      counts[row['status'] as String] = (row['cnt'] as int?) ?? 0;
    }
    return counts;
  }

  static Future<void> recordPayment(int reservationId, double amount) async {
    final db = await DbProvider.db;
    await db.rawUpdate('''
      UPDATE lodging_reservations 
      SET amount_paid = amount_paid + ?, updated_at = ?
      WHERE id = ?
    ''', [amount, DateTime.now().millisecondsSinceEpoch, reservationId]);
  }
}
