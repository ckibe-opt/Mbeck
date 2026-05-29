import 'package:flutter_test/flutter_test.dart';
import 'package:mbeck_business/services/device_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // Initialize Flutter binding for tests
  group('DeviceService Tests', () {
    setUp(() async {
      // Mock SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      // Clear cached IDs
      DeviceService.clearCache();
    });

    test('getShopId generates a temporary shop_id but does not persist it by default', () async {
      final shopId1 = await DeviceService.getShopId();
      
      expect(shopId1, isNotEmpty);
      expect(shopId1.startsWith('shop_'), isTrue);

      // Clear cache and verify it generates a NEW one because it wasn't persisted to SharedPreferences
      DeviceService.clearCache();
      final shopId2 = await DeviceService.getShopId();

      expect(shopId2, isNot(equals(shopId1))); // Should be different
    });

    test('getDeviceId generates and persists device_id', () async {
      final deviceId1 = await DeviceService.getDeviceId();
      
      expect(deviceId1, isNotEmpty);
      expect(deviceId1.startsWith('device_'), isTrue);

      // Clear cache and verify persistence
      DeviceService.clearCache();
      final deviceId2 = await DeviceService.getDeviceId();

      expect(deviceId2, deviceId1); // Should be same
    });

    test('shop_id and device_id are different', () async {
      final shopId = await DeviceService.getShopId();
      final deviceId = await DeviceService.getDeviceId();

      expect(shopId, isNot(equals(deviceId)));
    });

    test('IDs are cached after first generation', () async {
      final shopId1 = await DeviceService.getShopId();
      final shopId2 = await DeviceService.getShopId();

      expect(shopId1, shopId2); // Should use cache
    });
  });
}
