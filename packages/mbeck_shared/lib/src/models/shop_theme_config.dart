import 'dart:convert';
import 'package:flutter/material.dart';

/// Configuration for Shop Branding and Theming
/// Stored as JSON in the `shops` table.
///
/// Supports per-module design selection:
/// A multi-module business can assign different visual designs
/// to each module (e.g., "artisan_craft" for retail, "bistro_elegant" for restaurant).
class ShopThemeConfig {
  final Color primaryColor;
  final Color secondaryColor;
  final String? fontFamily;
  final String? coverImageUrl;
  final String stylePreset;
  final String? displayTag;
  
  // --- UI Configuration (Generic) ---
  final String productListLayout; // 'grid', 'list', 'gallery'
  final String cardStyle;         // 'standard', 'flat', 'neon', 'outlined'
  final double borderRadius;
  final bool showShadows;

  // --- Per-Module Design System ---
  /// Maps module name → designId (e.g. {'retail': 'artisan_craft', 'restaurant': 'bistro_elegant'})
  final Map<String, String> moduleDesigns;
  
  /// Module-specific content (e.g. intro messages, top images)
  final Map<String, dynamic> moduleConfigs;

  /// Fallback design for modules without a specific assignment
  final String globalDesign;

  // --- Typography ---
  final String headingFont;
  final String bodyFont;
  
  // --- Advanced ---
  final bool darkMode;

  // --- Business Contact (shown to buyers) ---
  final String? phoneNumber;
  final String? locationAddress;
  final double? latitude;
  final double? longitude;
  final List<String> environmentImages;

  const ShopThemeConfig({
    required this.primaryColor,
    required this.secondaryColor,
    this.fontFamily,
    this.coverImageUrl,
    this.stylePreset = 'standard',
    this.displayTag,
    this.productListLayout = 'grid',
    this.cardStyle = 'standard',
    this.borderRadius = 12.0,
    this.showShadows = true,
    this.moduleDesigns = const {},
    this.moduleConfigs = const {},
    this.globalDesign = 'clean_standard',
    this.headingFont = 'Roboto',
    this.bodyFont = 'Roboto',
    this.darkMode = false,
    this.phoneNumber,
    this.locationAddress,
    this.latitude,
    this.longitude,
    this.environmentImages = const [],
  });

  /// Default theme used when no configuration exists
  factory ShopThemeConfig.standard() {
    return const ShopThemeConfig(
      primaryColor: Color(0xFF4CAF50), // Mbeck Green
      secondaryColor: Color(0xFF7E57C2), // Purple Accent
      stylePreset: 'standard',
      environmentImages: [],
    );
  }

  /// Resolve the design ID for a specific module
  String designForModule(String module) {
    return moduleDesigns[module] ?? globalDesign;
  }

  /// Create from JSON Map (e.g. from Database)
  factory ShopThemeConfig.fromJson(Map<String, dynamic> json) {
    // Parse module_designs map
    Map<String, String> modDesigns = {};
    if (json['module_designs'] != null) {
      final raw = json['module_designs'];
      if (raw is Map) {
        modDesigns = Map<String, String>.from(raw.map((k, v) => MapEntry(k.toString(), v.toString())));
      } else if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          modDesigns = Map<String, String>.from(decoded.map((k, v) => MapEntry(k.toString(), v.toString())));
        }
      }
    }

    final envImagesRaw = json['environment_images'];
    List<String> envImages = [];
    if (envImagesRaw is List) {
      envImages = envImagesRaw.map((e) => e.toString()).toList();
    }

    Map<String, dynamic> mConfigs = {};
    if (json['module_configs'] != null) {
      final rawCfg = json['module_configs'];
      if (rawCfg is Map) {
        mConfigs = Map<String, dynamic>.from(rawCfg);
      } else if (rawCfg is String) {
        try {
          final decoded = jsonDecode(rawCfg);
          if (decoded is Map) {
            mConfigs = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }
    }

    return ShopThemeConfig(
      primaryColor: _parseColor(json['primary_color'], const Color(0xFF4CAF50)),
      secondaryColor: _parseColor(json['secondary_color'], const Color(0xFF7E57C2)),
      fontFamily: json['font_family'],
      coverImageUrl: json['cover_image_url'],
      stylePreset: json['style_preset'] ?? 'standard',
      displayTag: json['display_tag'],
      productListLayout: json['product_list_layout'] ?? 'grid',
      cardStyle: json['card_style'] ?? 'standard',
      borderRadius: (json['border_radius'] as num?)?.toDouble() ?? 12.0,
      showShadows: json['show_shadows'] ?? true,
      moduleDesigns: modDesigns,
      moduleConfigs: mConfigs,
      globalDesign: json['global_design'] ?? json['style_preset'] ?? 'clean_standard',
      headingFont: json['heading_font'] ?? 'Roboto',
      bodyFont: json['body_font'] ?? 'Roboto',
      darkMode: json['dark_mode'] ?? false,
      phoneNumber: json['phone_number'],
      locationAddress: json['location_address'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      environmentImages: envImages,
    );
  }

  /// Convert to JSON Map (for Database storage)
  Map<String, dynamic> toJson() {
    return {
      'primary_color': _colorToHex(primaryColor),
      'secondary_color': _colorToHex(secondaryColor),
      'font_family': fontFamily,
      'cover_image_url': coverImageUrl,
      'style_preset': stylePreset,
      'display_tag': displayTag,
      'product_list_layout': productListLayout,
      'card_style': cardStyle,
      'border_radius': borderRadius,
      'show_shadows': showShadows,
      'module_designs': moduleDesigns,
      'module_configs': moduleConfigs,
      'global_design': globalDesign,
      'heading_font': headingFont,
      'body_font': bodyFont,
      'dark_mode': darkMode,
      'phone_number': phoneNumber,
      'location_address': locationAddress,
      'latitude': latitude,
      'longitude': longitude,
      'environment_images': environmentImages,
    };
  }

  /// Create a copy with modifications
  ShopThemeConfig copyWith({
    Color? primaryColor,
    Color? secondaryColor,
    String? fontFamily,
    String? coverImageUrl,
    String? stylePreset,
    String? displayTag,
    String? productListLayout,
    String? cardStyle,
    double? borderRadius,
    bool? showShadows,
    Map<String, String>? moduleDesigns,
    Map<String, dynamic>? moduleConfigs,
    String? globalDesign,
    String? headingFont,
    String? bodyFont,
    bool? darkMode,
    String? phoneNumber,
    String? locationAddress,
    double? latitude,
    double? longitude,
    List<String>? environmentImages,
  }) {
    return ShopThemeConfig(
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      fontFamily: fontFamily ?? this.fontFamily,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      stylePreset: stylePreset ?? this.stylePreset,
      displayTag: displayTag ?? this.displayTag,
      productListLayout: productListLayout ?? this.productListLayout,
      cardStyle: cardStyle ?? this.cardStyle,
      borderRadius: borderRadius ?? this.borderRadius,
      showShadows: showShadows ?? this.showShadows,
      moduleDesigns: moduleDesigns ?? this.moduleDesigns,
      moduleConfigs: moduleConfigs ?? this.moduleConfigs,
      globalDesign: globalDesign ?? this.globalDesign,
      headingFont: headingFont ?? this.headingFont,
      bodyFont: bodyFont ?? this.bodyFont,
      darkMode: darkMode ?? this.darkMode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      locationAddress: locationAddress ?? this.locationAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      environmentImages: environmentImages ?? this.environmentImages,
    );
  }

  // Helper: Parse Hex String or Integer to Color
  static Color _parseColor(dynamic value, Color fallback) {
    if (value == null) return fallback;
    try {
      if (value is int) return Color(value);
      if (value is String) {
        // Handle #RRGGBB or RRGGBB
        final hex = value.replaceAll('#', '');
        if (hex.length == 6) {
          return Color(int.parse('FF$hex', radix: 16));
        } else if (hex.length == 8) {
          return Color(int.parse(hex, radix: 16));
        }
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  // Helper: Color to Hex String
  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}
