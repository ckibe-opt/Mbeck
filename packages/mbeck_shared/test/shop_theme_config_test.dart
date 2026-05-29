import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbeck_shared/mbeck_shared.dart';

void main() {
  group('ShopThemeConfig', () {
    test('standard() factory creates default values', () {
      final config = ShopThemeConfig.standard();
      expect(config.stylePreset, 'standard');
      expect(config.primaryColor.value, 0xFF4CAF50);
      expect(config.productListLayout, 'grid');
      expect(config.cardStyle, 'standard');
      expect(config.showShadows, true);
    });

    test('fromJson parses standard generic fields', () {
      final json = {
        'style_preset': 'cyberpunk',
        'product_list_layout': 'list',
        'card_style': 'neon',
        'border_radius': 0.0,
        'show_shadows': true,
      };
      
      final config = ShopThemeConfig.fromJson(json);
      
      expect(config.stylePreset, 'cyberpunk');
      expect(config.productListLayout, 'list');
      expect(config.cardStyle, 'neon');
      expect(config.borderRadius, 0.0);
    });

    test('fromJson uses defaults for missing generic fields', () {
      // Simulating old database row without new fields
      final json = {
        'style_preset': 'minimal',
      };
      
      final config = ShopThemeConfig.fromJson(json);
      
      expect(config.stylePreset, 'minimal');
      // Defaults
      expect(config.productListLayout, 'grid');
      expect(config.cardStyle, 'standard'); 
      expect(config.borderRadius, 12.0);
    });

    test('toJson includes generic fields', () {
      const config = ShopThemeConfig(
        primaryColor: Colors.black,
        secondaryColor: Colors.white,
        stylePreset: 'custom',
        productListLayout: 'gallery',
        cardStyle: 'flat',
        borderRadius: 8.0,
        showShadows: false
      );
      
      final json = config.toJson();
      
      expect(json['product_list_layout'], 'gallery');
      expect(json['card_style'], 'flat');
      expect(json['border_radius'], 8.0);
      expect(json['show_shadows'], false);
    });
  });
}
