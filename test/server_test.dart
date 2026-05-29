import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mbeck_business/server/local_server.dart'; 
import 'package:mbeck_business/server/routes/api_router.dart';
import 'package:shelf/shelf.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mbeck_business/db/db_provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ApiRouter', () {
    late ApiRouter apiRouter;
    late Handler handler;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      
      const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'read') return 'test-key-32-chars-long-123456789012';
        return null;
      });

      await DbProvider.close();
      await DbProvider.init(databaseName: inMemoryDatabasePath);
      
      // Seed dummy data
      await DbProvider.insert('inventory', {
        'name': 'Test Item 1',
        'sellingPrice': 100.0,
        'stock': 10,
      });
      await DbProvider.insert('inventory', {
        'name': 'Test Item 2',
        'sellingPrice': 200.0,
        'stock': 5,
      });
      await DbProvider.insert('inventory', {
        'name': 'Test Item 3',
        'sellingPrice': 300.0,
        'stock': 2,
      });

      apiRouter = ApiRouter();
      handler = apiRouter.handler;
    });

    tearDown(() async {
      await DbProvider.close();
    });

    test('GET /api/v1/status returns 200 and online status', () async {
      final request = Request('GET', Uri.parse('http://localhost/api/v1/status'));
      final response = await handler(request);

      expect(response.statusCode, 200);
      final body = await response.readAsString();
      final json = jsonDecode(body);
      expect(json['status'], 'online');
      expect(json['service'], 'Mbeck Shop Server');
    });

    test('GET /api/v1/inventory/public returns dummy data', () async {
      final request = Request('GET', Uri.parse('http://localhost/api/v1/inventory/public'));
      final response = await handler(request);

      expect(response.statusCode, 200);
      final body = await response.readAsString();
      final json = jsonDecode(body);
      expect(json['data'], isList);
      expect((json['data'] as List).length, 3);
    });
  });
}
