import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../db/db_provider.dart';
import 'event_service.dart';
import 'security_service.dart';
import 'cloud_storage_service.dart';

/// Centralized service layer for the Services module.
///
/// Manages:
/// - Service catalog CRUD
/// - Staff CRUD
/// - Booking lifecycle (create → confirm → complete → bill)
/// - Supply link management (auto-deduct on completion)
/// - Revenue queries
class ServicesService {
  // ========== SERVICE CATALOG ==========

  static Future<List<Map<String, dynamic>>> getServices({
    String? category,
    bool activeOnly = true,
  }) async {
    final db = await DbProvider.db;
    String where = '';
    List<dynamic> whereArgs = [];

    if (activeOnly) {
      where = 'active = 1';
    }
    if (category != null && category != 'All') {
      where += where.isNotEmpty ? ' AND category = ?' : 'category = ?';
      whereArgs.add(category);
    }

    return await db.query(
      'services_catalog',
      where: where.isNotEmpty ? where : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'category ASC, name ASC',
    );
  }

  static Future<List<String>> getServiceCategories() async {
    final db = await DbProvider.db;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM services_catalog WHERE active = 1 AND category IS NOT NULL AND category != \'\' ORDER BY category ASC',
    );
    return result.map((r) => r['category'] as String).toList();
  }

  static Future<int> createService({
    required String name,
    required double price,
    required int durationMinutes,
    String? description,
    String? category,
    String? staffIds,
    String? imagePath,
  }) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cloudId = const Uuid().v4();

    final cloudUrl = await CloudStorageService.uploadImage(imagePath, folder: 'services');
    final finalImagePath = (cloudUrl != null && cloudUrl.startsWith('http')) ? cloudUrl : imagePath;

    final id = await db.insert('services_catalog', {
      'cloud_id': cloudId,
      'source_module': 'services',
      'name': name,
      'description': description,
      'duration_minutes': durationMinutes,
      'price': price,
      'category': category ?? '',
      'staff_ids': staffIds,
      'active': 1,
      'image_path': finalImagePath,
      'created_at': now,
      'updated_at': now,
    });

    EventService.emitEvent(
      eventType: 'SERVICE_CREATE',
      payload: {
        'cloud_id': cloudId,
        'source_module': 'services',
        'service_id': id,
        'name': name,
        'price': price,
        'duration_minutes': durationMinutes,
        'category': category,
      },
    );

    debugPrint('✅ Created service: $name (KES $price, ${durationMinutes}min)');
    return id;
  }

  static Future<void> updateService(int id, Map<String, dynamic> updates) async {
    final db = await DbProvider.db;
    updates['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    if (updates.containsKey('image_path') && updates['image_path'] != null) {
      final cloudUrl = await CloudStorageService.uploadImage(updates['image_path'], folder: 'services');
      updates['image_path'] = (cloudUrl != null && cloudUrl.startsWith('http')) ? cloudUrl : updates['image_path'];
    }

    await db.update('services_catalog', updates, where: 'id = ?', whereArgs: [id]);

    EventService.emitEvent(
      eventType: 'SERVICE_UPDATE',
      payload: {'service_id': id, ...updates},
    );
  }

  static Future<void> toggleServiceActive(int id, bool active) async {
    await updateService(id, {'active': active ? 1 : 0});
  }

  static Future<void> deleteService(int id) async {
    final db = await DbProvider.db;
    await db.delete('services_catalog', where: 'id = ?', whereArgs: [id]);
    await db.delete('supply_links',
        where: "item_type = 'service' AND item_id = ?", whereArgs: [id]);

    EventService.emitEvent(
      eventType: 'SERVICE_DELETE',
      payload: {'service_id': id, 'source_module': 'services'},
    );
  }

  // ========== SUPPLY LINKS ==========

  static Future<List<Map<String, dynamic>>> getSupplyLinksForService(int serviceId) async {
    final db = await DbProvider.db;
    return await db.rawQuery('''
      SELECT sl.*, s.name as supply_name, s.unit as supply_unit
      FROM supply_links sl
      JOIN supplies s ON sl.supply_id = s.id
      WHERE sl.item_type = 'service' AND sl.item_id = ?
    ''', [serviceId]);
  }

  static Future<void> saveSupplyLinks(int serviceId, List<Map<String, dynamic>> links) async {
    final db = await DbProvider.db;
    await db.delete('supply_links',
        where: "item_type = 'service' AND item_id = ?", whereArgs: [serviceId]);
    for (final link in links) {
      await db.insert('supply_links', {
        'item_id': serviceId,
        'item_type': 'service',
        'supply_id': link['supply_id'],
        'quantity_per_use': link['quantity_per_use'] ?? 1.0,
      });
    }
  }

  /// Deduct supplies when a booking is completed
  static Future<void> _deductSupplies(int serviceId) async {
    final db = await DbProvider.db;
    final links = await db.query('supply_links',
        where: "item_type = 'service' AND item_id = ?", whereArgs: [serviceId]);

    for (final link in links) {
      final supplyId = link['supply_id'] as int;
      final qty = (link['quantity_per_use'] as num?)?.toDouble() ?? 1.0;
      await db.rawUpdate(
        'UPDATE supplies SET quantity = MAX(0, quantity - ?), updated_at = ? WHERE id = ?',
        [qty, DateTime.now().millisecondsSinceEpoch, supplyId],
      );
    }
  }

  // ========== STAFF SHIFTS ==========

  static Future<int> createShift({
    required int staffId,
    required DateTime startTime,
    required DateTime endTime,
    String status = 'active',
    bool isRecurring = false,
  }) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cloudId = const Uuid().v4();

    final id = await db.insert('services_staff_shifts', {
      'cloud_id': cloudId,
      'staff_id': staffId,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'status': status,
      'is_recurring': isRecurring ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    });

    EventService.emitEvent(
      eventType: 'SHIFT_CREATE',
      payload: {
        'cloud_id': cloudId,
        'source_module': 'services',
        'shift_id': id,
        'staff_id': staffId,
        'start_time': startTime.millisecondsSinceEpoch,
        'end_time': endTime.millisecondsSinceEpoch,
        'status': status,
        'is_recurring': isRecurring,
      },
    );

    debugPrint('⌚ Shift created for Staff ID $staffId');
    return id;
  }

  static Future<List<Map<String, dynamic>>> getShiftsForDate(DateTime date, {int? staffId}) async {
    final db = await DbProvider.db;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    String where = 's.start_time >= ? AND s.start_time < ?';
    List<dynamic> args = [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch];

    if (staffId != null) {
      where += ' AND s.staff_id = ?';
      args.add(staffId);
    }

    return await db.rawQuery('''
      SELECT s.*, st.name as staff_name, st.role as staff_role
      FROM services_staff_shifts s
      JOIN services_staff st ON s.staff_id = st.id
      WHERE $where
      ORDER BY s.start_time ASC
    ''', args);
  }

  static Future<void> updateShiftStatus(int shiftId, String newStatus) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update('services_staff_shifts', {
      'status': newStatus,
      'updated_at': now,
    }, where: 'id = ?', whereArgs: [shiftId]);

    EventService.emitEvent(
      eventType: 'SHIFT_STATUS_CHANGE',
      payload: {
        'source_module': 'services',
        'shift_id': shiftId,
        'new_status': newStatus,
      },
    );
  }

  static Future<void> deleteShift(int shiftId) async {
    final db = await DbProvider.db;
    await db.delete('services_staff_shifts', where: 'id = ?', whereArgs: [shiftId]);

    EventService.emitEvent(
      eventType: 'SHIFT_DELETE',
      payload: {'shift_id': shiftId},
    );
  }

  // ========== STAFF ==========

  static Future<List<Map<String, dynamic>>> getStaff({bool activeOnly = true}) async {
    final db = await DbProvider.db;
    if (activeOnly) {
      return await db.query('services_staff', where: 'active = 1', orderBy: 'name ASC');
    }
    return await db.query('services_staff', orderBy: 'name ASC');
  }

  static Future<int> createStaff({
    required String name,
    String? role,
    String? phone,
    String? email,
    String availableDays = '1,2,3,4,5',
    String workStart = '09:00',
    String workEnd = '17:00',
  }) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final id = await db.insert('services_staff', {
      'name': name,
      'role': role,
      'phone': phone,
      'email': email,
      'available_days': availableDays,
      'work_hours_start': workStart,
      'work_hours_end': workEnd,
      'active': 1,
      'created_at': now,
    });

    debugPrint('👤 Created staff: $name ($role)');
    return id;
  }

  static Future<void> updateStaff(int id, Map<String, dynamic> updates) async {
    final db = await DbProvider.db;
    await db.update('services_staff', updates, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> toggleStaffActive(int id, bool active) async {
    await updateStaff(id, {'active': active ? 1 : 0});
  }

  // ========== BOOKINGS ==========

  /// Creates a new booking, applying addon pricing and buffer-aware end time.
  static Future<int> createBooking({
    required int serviceId,
    int? staffId,
    required String customerName,
    String? customerPhone,
    String? customerEmail,
    required DateTime startTime,
    required DateTime endTime,
    String? notes,
    double depositPaid = 0,
    List<Map<String, dynamic>> selectedAddons = const [],
    double? overrideTotalPrice,
  }) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cloudId = const Uuid().v4();

    // Compute total from addons
    double addonPriceSum = 0;
    final addonIds = selectedAddons.map((a) => a['id'].toString()).join(',');
    for (final addon in selectedAddons) {
      addonPriceSum += (addon['price_added'] as num?)?.toDouble() ?? 0;
    }

    // resolve base price
    double basePrice = overrideTotalPrice ?? 0;
    if (overrideTotalPrice == null) {
      final svc = await db.query('services_catalog', where: 'id = ?', whereArgs: [serviceId]);
      if (svc.isNotEmpty) {
        basePrice = (svc.first['price'] as num?)?.toDouble() ?? 0;
      }
    }
    final totalPrice = basePrice + addonPriceSum;
    final totalDurationMin = endTime.difference(startTime).inMinutes;

    final id = await db.insert('services_bookings', {
      'cloud_id': cloudId,
      'source_module': 'services',
      'service_id': serviceId,
      'staff_id': staffId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'status': 'pending',
      'notes': notes,
      'deposit_paid': depositPaid,
      'addon_ids': addonIds.isNotEmpty ? addonIds : null,
      'total_price': totalPrice,
      'total_duration_minutes': totalDurationMin,
      'created_at': now,
      'updated_at': now,
    });

    EventService.emitEvent(
      eventType: 'BOOKING_CREATE',
      payload: {
        'cloud_id': cloudId,
        'source_module': 'services',
        'booking_id': id,
        'service_id': serviceId,
        'staff_id': staffId,
        'customer_name': customerName,
        'total_price': totalPrice,
        'addon_ids': addonIds,
        'start_time': startTime.millisecondsSinceEpoch,
      },
    );

    debugPrint('📅 Booking #$id created for $customerName (KES ${totalPrice.toStringAsFixed(0)})');
    return id;
  }

  static Future<void> updateBookingStatus(int bookingId, String newStatus) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Get booking data before update
    final bookings = await db.query('services_bookings',
        where: 'id = ?', whereArgs: [bookingId]);
    if (bookings.isEmpty) throw Exception('Booking not found');
    final booking = bookings.first;

    await db.update('services_bookings', {
      'status': newStatus,
      'updated_at': now,
    }, where: 'id = ?', whereArgs: [bookingId]);

    EventService.emitEvent(
      eventType: 'BOOKING_STATUS_CHANGE',
      payload: {
        'source_module': 'services',
        'booking_id': bookingId,
        'new_status': newStatus,
        'previous_status': booking['status'],
      },
    );

    // When completed: record sale + deduct supplies
    if (newStatus == 'completed') {
      await _completeBooking(booking, now);
    }
  }

  static Future<void> _completeBooking(Map<String, dynamic> booking, int now) async {
    final db = await DbProvider.db;
    final serviceId = booking['service_id'] as int?;

    // Look up service for price and name
    String serviceName = 'Service';
    double basePrice = 0;
    if (serviceId != null) {
      final services = await db.query('services_catalog',
          where: 'id = ?', whereArgs: [serviceId]);
      if (services.isNotEmpty) {
        serviceName = services.first['name'] as String? ?? 'Service';
        basePrice = (services.first['price'] as num?)?.toDouble() ?? 0;
      }
    }

    // ✅ BUG FIX: If total_price was recorded at booking time (includes addons), use it.
    // Fall back to base service price only if no stored total found.
    final storedTotalPrice = (booking['total_price'] as num?)?.toDouble();
    final price = (storedTotalPrice != null && storedTotalPrice > 0) ? storedTotalPrice : basePrice;

    // Sign and record as sale transaction
    final details = 'Service: $serviceName (${booking['customer_name']})';
    final signature = await SecurityService().signTransaction(
      timestamp: now,
      totalAmount: price,
      type: 'sale',
      details: details,
    );

    await db.insert('txn', {
      'type': 'sale',
      'totalAmount': price.round(),
      'details': details,
      'timestamp': now,
      'receiptSignature': signature,
      'source_module': 'services',
    });

    // Deduct supplies
    if (serviceId != null) {
      await _deductSupplies(serviceId);
    }

    debugPrint('💰 Booking completed: $serviceName — KES ${price.toStringAsFixed(0)}');
  }

  static Future<List<Map<String, dynamic>>> getBookingsForDate(DateTime date) async {
    final db = await DbProvider.db;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return await db.rawQuery('''
      SELECT b.*, 
             sc.name as service_name, sc.price as service_price, sc.duration_minutes,
             st.name as staff_name
      FROM services_bookings b
      LEFT JOIN services_catalog sc ON b.service_id = sc.id
      LEFT JOIN services_staff st ON b.staff_id = st.id
      WHERE b.start_time >= ? AND b.start_time < ?
      ORDER BY b.start_time ASC
    ''', [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch]);
  }

  static Future<List<Map<String, dynamic>>> getUpcomingBookings({int limit = 10}) async {
    final db = await DbProvider.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.rawQuery('''
      SELECT b.*, 
             sc.name as service_name, sc.price as service_price,
             st.name as staff_name
      FROM services_bookings b
      LEFT JOIN services_catalog sc ON b.service_id = sc.id
      LEFT JOIN services_staff st ON b.staff_id = st.id
      WHERE b.start_time >= ? AND b.status IN ('pending', 'confirmed')
      ORDER BY b.start_time ASC
      LIMIT ?
    ''', [now, limit]);
  }

  static Future<void> deleteBooking(int bookingId) async {
    final db = await DbProvider.db;
    await db.delete('services_bookings', where: 'id = ?', whereArgs: [bookingId]);

    EventService.emitEvent(
      eventType: 'BOOKING_DELETE',
      payload: {'booking_id': bookingId},
    );
  }

  // ========== REVENUE ==========

  static Future<double> getTodayRevenue() async {
    final db = await DbProvider.db;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(sc.price), 0) as revenue
      FROM services_bookings b
      JOIN services_catalog sc ON b.service_id = sc.id
      WHERE b.status = 'completed' AND b.updated_at >= ?
    ''', [startOfDay]);

    return (result.first['revenue'] as num?)?.toDouble() ?? 0.0;
  }

  static Future<Map<String, int>> getBookingStatusCounts(DateTime date) async {
    final db = await DbProvider.db;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery('''
      SELECT status, COUNT(*) as cnt
      FROM services_bookings
      WHERE start_time >= ? AND start_time < ?
      GROUP BY status
    ''', [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch]);

    final counts = <String, int>{};
    for (final row in result) {
      counts[row['status'] as String] = (row['cnt'] as int?) ?? 0;
    }
    return counts;
  }

  /// Check for time slot conflicts against existing bookings.
  /// Also validates that the assigned staff member has a shift covering the slot.
  static Future<bool> hasConflict({
    required int serviceId,
    int? staffId,
    required DateTime startTime,
    required DateTime endTime,
    int? excludeBookingId,
  }) async {
    final db = await DbProvider.db;

    // 1. Standard booking overlap check
    String sql = '''
      SELECT COUNT(*) as cnt FROM services_bookings
      WHERE status IN ('pending', 'confirmed')
      AND start_time < ? AND end_time > ?
    ''';
    List<dynamic> args = [
      endTime.millisecondsSinceEpoch,
      startTime.millisecondsSinceEpoch,
    ];

    if (staffId != null) {
      sql += ' AND staff_id = ?';
      args.add(staffId);
    }
    if (excludeBookingId != null) {
      sql += ' AND id != ?';
      args.add(excludeBookingId);
    }

    final result = await db.rawQuery(sql, args);
    final hasBookingConflict = ((result.first['cnt'] as int?) ?? 0) > 0;
    if (hasBookingConflict) return true;

    // 2. ✅ BUG FIX: Verify the staff member actually has an active shift covering this slot.
    if (staffId != null) {
      final shiftCheck = await db.rawQuery('''
        SELECT COUNT(*) as cnt FROM services_staff_shifts
        WHERE staff_id = ?
          AND start_time <= ?
          AND end_time >= ?
          AND status IN ('active', 'upcoming')
      ''', [
        staffId,
        startTime.millisecondsSinceEpoch,
        endTime.millisecondsSinceEpoch,
      ]);
      final hasShift = ((shiftCheck.first['cnt'] as int?) ?? 0) > 0;
      // If no explicit shift exists (i.e. raw staff defaults are in use), allow through.
      // Only block if shifts have been configured and none covers this window.
      final anyShiftForStaff = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM services_staff_shifts WHERE staff_id = ?',
        [staffId],
      );
      final shiftsConfigured = ((anyShiftForStaff.first['cnt'] as int?) ?? 0) > 0;
      if (shiftsConfigured && !hasShift) return true;
    }

    return false;
  }
}
