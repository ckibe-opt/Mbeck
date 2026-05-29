import 'package:mbeck_business/models/shop.dart';
import 'package:mbeck_business/models/shop_member.dart';
import 'package:mbeck_business/models/event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbeck_shared/mbeck_shared.dart';
// Removed duplicate mbeck_shared import

void main() {
  group('Shop Model Enterprise Fields', () {
    final mockShopMap = {
      'id': 'shop_123',
      'business_name': 'Test Enterprise Shop',
      'owner_device_id': 'device_abc',
      'owner_id': 'user_xyz',
      'chain_id': 'chain_789',
      'franchise_id': 'franchise_001',
      'region': 'Nairobi',
      'currency': 'KES',
      'subscription_tier': 'ENTERPRISE',
      'subscription_status': 'ACTIVE',
      'joined_at': '2025-01-01T10:00:00.000Z',
      'created_at': '2025-01-01T10:00:00.000Z',
      'updated_at': '2025-01-02T10:00:00.000Z',
      'trust_score': 95.5,
    };

    test('should parse enterprise fields correctly from map', () {
      final shop = Shop.fromMap(mockShopMap);

      expect(shop.id, 'shop_123');
      expect(shop.franchiseId, 'franchise_001');
      expect(shop.region, 'Nairobi');
      expect(shop.currency, 'KES');
      expect(shop.subscriptionTier, 'ENTERPRISE');
    });

    test('should default currency to KES if missing', () {
      final mapWithoutCurrency = Map<String, dynamic>.from(mockShopMap);
      mapWithoutCurrency.remove('currency');
      
      final shop = Shop.fromMap(mapWithoutCurrency);
      expect(shop.currency, 'KES');
    });

    test('should handle null enterprise fields gracefully', () {
      final mapWithNulls = Map<String, dynamic>.from(mockShopMap);
      mapWithNulls['franchise_id'] = null;
      mapWithNulls['region'] = null;
      
      final shop = Shop.fromMap(mapWithNulls);
      expect(shop.franchiseId, null);
      expect(shop.region, null);
    });

    test('toMap should include enterprise fields', () {
      final shop = Shop.fromMap(mockShopMap);
      final map = shop.toMap();

      expect(map['franchise_id'], 'franchise_001');
      expect(map['region'], 'Nairobi');
      expect(map['currency'], 'KES');
    });
  });

  group('ShopMember Model Enterprise Fields', () {
    final mockMemberMap = {
      'id': 1,
      'shop_id': 'shop_123',
      'user_id': 'auth_user_456',
      'device_id': 'device_789',
      'user_name': 'Shop Manager',
      'role': 'MANAGER',
      'permissions': {'can_manage_staff': true},
      'joined_at': '2025-01-01T10:00:00.000Z',
      'is_active': true,
    };

    test('should parse user_id correctly', () {
      final member = ShopMember.fromMap(mockMemberMap);

      expect(member.userId, 'auth_user_456');
      expect(member.role, 'MANAGER');
      expect(member.userName, 'Shop Manager');
    });

    test('should handle null user_id (backward compatibility)', () {
      final mapWithoutUser = Map<String, dynamic>.from(mockMemberMap);
      mapWithoutUser['user_id'] = null;

      final member = ShopMember.fromMap(mapWithoutUser);
      expect(member.userId, null);
    });

    test('toMap should include user_id', () {
      final member = ShopMember.fromMap(mockMemberMap);
      final map = member.toMap();

      expect(map['user_id'], 'auth_user_456');
    });
  });
}
