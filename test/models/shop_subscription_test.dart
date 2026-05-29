import 'package:mbeck_business/models/shop.dart';
import 'package:mbeck_business/models/shop_member.dart';
import 'package:mbeck_business/models/event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbeck_shared/mbeck_shared.dart';

void main() {
  group('Shop Subscription Limits', () {
    Shop createShop({required String tier}) {
      return Shop(
        id: 'test_shop',
        businessName: 'Test Business',
        ownerDeviceId: 'device_123',
        ownerId: 'user_123',
        subscriptionTier: tier,
        subscriptionStatus: 'ACTIVE',
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    test('Free Tier Limits', () {
      final shop = createShop(tier: 'FREE');
      
      expect(shop.maxInventoryItems, 50);
      expect(shop.maxStaffMembers, 1);
      
      expect(shop.isInventoryLimitReached(49), false);
      expect(shop.isInventoryLimitReached(50), true);
      expect(shop.isInventoryLimitReached(51), true);

      // Staff limit 1 means only owner allowed
      expect(shop.isStaffLimitReached(0), false);
      expect(shop.isStaffLimitReached(1), true);
    });

    test('Pro Tier Limits', () {
      final shop = createShop(tier: 'PRO');
      
      expect(shop.maxInventoryItems, -1); // Unlimited
      expect(shop.maxStaffMembers, 3);
      
      expect(shop.isInventoryLimitReached(1000), false);
      
      expect(shop.isStaffLimitReached(2), false);
      expect(shop.isStaffLimitReached(3), true);
    });

    test('Enterprise Tier Limits', () {
      final shop = createShop(tier: 'ENTERPRISE');
      
      expect(shop.maxInventoryItems, -1);
      expect(shop.maxStaffMembers, -1);
      
      expect(shop.isInventoryLimitReached(10000), false);
      expect(shop.isStaffLimitReached(100), false);
    });
  });
}
