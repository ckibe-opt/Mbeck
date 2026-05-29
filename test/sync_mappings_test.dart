import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mbeck_business/db/db_provider.dart';
import 'package:mbeck_business/services/sync_service.dart';
import 'package:mbeck_business/services/event_processor.dart';
import 'package:mbeck_business/services/device_service.dart';
import 'package:mbeck_business/services/auth_service.dart';

/// Mock HTTP overrides to intercept all Supabase and Rest requests globally
class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClientImage();
  }
}

class MockHttpClientImage implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return MockHttpClientRequest(method, url);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return MockHttpClientRequest('GET', url);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return MockHttpClientRequest('POST', url);
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) async {
    return MockHttpClientRequest('PUT', url);
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) async {
    return MockHttpClientRequest('DELETE', url);
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) async {
    return MockHttpClientRequest('PATCH', url);
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) async {
    return MockHttpClientRequest('HEAD', url);
  }

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) async {
    final scheme = port == 443 ? 'https' : 'http';
    return MockHttpClientRequest(method, Uri(scheme: scheme, host: host, port: port, path: path));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClientRequest implements HttpClientRequest {
  final String method;
  final Uri url;

  MockHttpClientRequest(this.method, this.url);

  @override
  Uri get uri => url;

  @override
  bool followRedirects = true;

  @override
  bool persistentConnection = true;

  @override
  bool bufferOutput = true;

  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  Future<HttpClientResponse> get done => Completer<HttpClientResponse>().future;

  @override
  Future<void> flush() => Future.value(null);

  @override
  Future<void> addStream(Stream<List<int>> stream) => Future.value(null);

  @override
  Future<HttpClientResponse> close() async {
    final urlStr = url.toString();
    String responseBody = '[]';
    int statusCode = 200;

    if (urlStr.contains('/rest/v1/shops')) {
      if (method == 'GET') {
        // Return a single shop object since maybeSingle() is called
        responseBody = jsonEncode({
          'id': 'shop_test_456',
          'name': 'Test Shop POS',
          'owner_device_id': 'device_test_123',
          'owner_id': 'owner_test_uid',
          'subscription_tier': 'PRO',
          'subscription_status': 'ACTIVE',
          'joined_at': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'theme_config': {},
          'trust_score': 100.0,
        });
      } else {
        responseBody = jsonEncode({'success': true});
      }
    } else if (urlStr.contains('/rest/v1/shop_members')) {
      if (method == 'GET') {
        // Return a single shop member object
        responseBody = jsonEncode({
          'id': 1,
          'shop_id': 'shop_test_456',
          'device_id': 'device_test_123',
          'user_name': 'Test Manager',
          'role': 'OWNER',
          'permissions': {},
          'is_active': true,
        });
      } else {
        responseBody = jsonEncode({'success': true});
      }
    } else if (urlStr.contains('/rest/v1/services_bookings')) {
      if (method == 'GET') {
        // Return a mock pending services booking
        responseBody = jsonEncode([
          {
            'id': 'booking_cloud_123',
            'shop_id': 'shop_test_456',
            'service_id': 5,
            'customer_name': 'Alice Green',
            'customer_phone': '+254700111222',
            'start_time': DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
            'end_time': DateTime.now().add(const Duration(hours: 3)).millisecondsSinceEpoch,
            'notes': 'Urgent booking request',
            'created_at': DateTime.now().toIso8601String(),
          }
        ]);
      } else if (method == 'PATCH') {
        responseBody = jsonEncode({'success': true});
      }
    } else if (urlStr.contains('/rest/v1/lodging_reservations')) {
      if (method == 'GET') {
        // Return a mock pending lodging reservation with ISO timestamps
        responseBody = jsonEncode([
          {
            'id': 'reservation_cloud_789',
            'shop_id': 'shop_test_456',
            'room_id': 12,
            'guest_name': 'Bob Blue',
            'guest_phone': '+254722333444',
            'check_in_date': '2026-06-15T12:00:00.000Z',
            'check_out_date': '2026-06-18T10:00:00.000Z',
            'nights': 3,
            'rate_per_night': 2500.0,
            'total_amount': 7500.0,
            'created_at': DateTime.now().toIso8601String(),
          }
        ]);
      } else if (method == 'PATCH') {
        responseBody = jsonEncode({'success': true});
      }
    }

    return MockHttpClientResponse(responseBody, statusCode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClientResponse implements HttpClientResponse {
  final String body;
  final int statusCode;

  MockHttpClientResponse(this.body, this.statusCode);

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => true;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  String get reasonPhrase => 'OK';

  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  int get contentLength => body.length;

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final bytes = utf8.encode(body);
    return Stream<List<int>>.fromIterable([bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Set mock HttpOverrides globally
    HttpOverrides.global = MockHttpOverrides();

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Seed SharedPreferences
    SharedPreferences.setMockInitialValues({
      'device_id': 'device_test_123',
      'shop_id': 'shop_test_456',
      'cached_member_data': jsonEncode({
        'id': 1,
        'shop_id': 'shop_test_456',
        'device_id': 'device_test_123',
        'user_name': 'Test Manager',
        'role': 'OWNER',
        'permissions': {},
        'joined_at': DateTime.now().toIso8601String(),
        'is_active': true,
      }),
      'cached_shop_data': jsonEncode({
        'id': 'shop_test_456',
        'name': 'Test Shop POS',
        'owner_device_id': 'device_test_123',
        'owner_id': 'owner_test_uid',
        'subscription_tier': 'PRO',
        'subscription_status': 'ACTIVE',
        'joined_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'theme_config': {},
        'trust_score': 100.0,
      }),
    });

    // Initialize Supabase
    try {
      await Supabase.initialize(
        url: 'https://mock.supabase.co',
        anonKey: 'mockAnonKey',
      );
    } catch (_) {
      // Ignored if already initialized
    }
    
    await SyncService.init('https://mock.supabase.co', 'mockAnonKey');
  });

  setUp(() async {
    // Invalidate static caching state to isolate test environment
    DeviceService.clearCache();
    AuthService.invalidateCache();

    // Re-seed SharedPreferences for the fresh run
    SharedPreferences.setMockInitialValues({
      'device_id': 'device_test_123',
      'shop_id': 'shop_test_456',
      'cached_member_data': jsonEncode({
        'id': 1,
        'shop_id': 'shop_test_456',
        'device_id': 'device_test_123',
        'user_name': 'Test Manager',
        'role': 'OWNER',
        'permissions': {},
        'joined_at': DateTime.now().toIso8601String(),
        'is_active': true,
      }),
      'cached_shop_data': jsonEncode({
        'id': 'shop_test_456',
        'name': 'Test Shop POS',
        'owner_device_id': 'device_test_123',
        'owner_id': 'owner_test_uid',
        'subscription_tier': 'PRO',
        'subscription_status': 'ACTIVE',
        'joined_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'theme_config': {},
        'trust_score': 100.0,
      }),
    });

    // Force a fresh in-memory database
    await DbProvider.close();
    await DbProvider.init(databaseName: inMemoryDatabasePath);
    await DbProvider.deleteAllData();
  });

  tearDown(() async {
    await DbProvider.close();
  });

  group('Sync Mappings & Downstream pull tests', () {
    test('testPullRemoteBookings parses and ingests service bookings correctly', () async {
      final db = await DbProvider.db;

      // Ensure bookings table is empty initially
      final initialRows = await db.query('services_bookings');
      expect(initialRows, isEmpty);

      // Trigger booking sync pull
      await SyncService.testPullRemoteBookings();

      // Check if mapped record was inserted into SQLite
      final rows = await db.query('services_bookings');
      expect(rows.length, 1);

      final booking = rows.first;
      expect(booking['cloud_id'], 'booking_cloud_123');
      expect(booking['customer_name'], 'Alice Green');
      expect(booking['customer_phone'], '+254700111222');
      expect(booking['service_id'], 5);
      expect(booking['status'], 'pending');
      expect(booking['notes'], 'Urgent booking request');
    });

    test('testPullRemoteReservations parses ISO timestamps and ingests lodging reservations correctly', () async {
      final db = await DbProvider.db;

      // Ensure reservations table is empty initially
      final initialRows = await db.query('lodging_reservations');
      expect(initialRows, isEmpty);

      // Seed lodging_rooms to satisfy the FOREIGN KEY constraint
      await db.insert('lodging_rooms', {
        'id': 12,
        'name': 'Room 12',
        'room_type': 'Standard',
        'status': 'available',
        'is_active': 1,
        'is_published': 1,
      });

      // Trigger lodging reservations sync pull
      await SyncService.testPullRemoteReservations();

      // Check if mapped record was inserted into SQLite
      final rows = await db.query('lodging_reservations');
      expect(rows.length, 1);

      final reservation = rows.first;
      expect(reservation['cloud_id'], 'reservation_cloud_789');
      expect(reservation['guest_name'], 'Bob Blue');
      expect(reservation['guest_phone'], '+254722333444');
      expect(reservation['room_id'], 12);
      expect(reservation['nights'], 3);
      expect(reservation['rate_per_night'], 2500.0);
      expect(reservation['total_amount'], 7500.0);
      expect(reservation['status'], 'pending');

      // Verify that ISO check_in_date & check_out_date are parsed correctly into Milliseconds
      final expectedCheckIn = DateTime.parse('2026-06-15T12:00:00.000Z').millisecondsSinceEpoch;
      final expectedCheckOut = DateTime.parse('2026-06-18T10:00:00.000Z').millisecondsSinceEpoch;

      expect(reservation['check_in_date'], expectedCheckIn);
      expect(reservation['check_out_date'], expectedCheckOut);
    });
  });
}
