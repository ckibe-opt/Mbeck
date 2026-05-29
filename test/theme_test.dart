import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbeck_business/theme/design_system.dart';
import 'package:mbeck_shared/mbeck_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Design System (Seller App)', () {
    test('AppColors matches emerald green palette', () {
      expect(AppColors.primaryGreen, const Color(0xFF10B981));
      expect(AppColors.primaryDark, const Color(0xFF059669));
      expect(AppColors.gray50, const Color(0xFFF9FAFB));
    });

    // test('AppTheme.lightTheme holds correct primary color', () {
    //   final theme = AppTheme.lightTheme;
    //   expect(theme.primaryColor, AppColors.primaryGreen);
    //   expect(theme.scaffoldBackgroundColor, AppColors.gray50);
    //   expect(theme.colorScheme.primary, AppColors.primaryGreen);
    // });

    // test('AppTypography defines Inter font', () {
    //   final style = AppTypography.textTheme.displayLarge;
    //   expect(style, isNotNull);
    // });
  });

  group('ShopThemeConfig (Shared)', () {
    test('Standard factory returns defaults', () {
      final config = ShopThemeConfig.standard();
      expect(config.primaryColor.value, const Color(0xFF4CAF50).value); // Checking standard Mbeck Green
      expect(config.stylePreset, 'standard');
    });

    test('Parses hex color correctly from JSON', () {
      final json = {
        'primary_color': '#FF0000',
        'secondary_color': '00FF00', // Without hash
        'style_preset': 'dark',
      };
      final config = ShopThemeConfig.fromJson(json);
      
      expect(config.primaryColor.value, const Color(0xFFFF0000).value);
      expect(config.secondaryColor.value, const Color(0xFF00FF00).value);
      expect(config.stylePreset, 'dark');
    });

    test('Fallback to defaults on invalid color', () {
      final json = {
        'primary_color': 'NOT_A_COLOR',
      };
      final config = ShopThemeConfig.fromJson(json);
      
      // Should fallback to default Mbeck Green (0xFF4CAF50)
      expect(config.primaryColor.value, const Color(0xFF4CAF50).value);
    });
  });
}
