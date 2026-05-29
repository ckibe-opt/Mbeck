
import 'dart:convert';
import 'package:flutter/material.dart';

// Import Shared Logic (Mocking the import by redefined class if needed, or using relative import if running in context)
// Since we are running as a standalone script, we might have issues with package imports if not run via `dart run`.
// To make this script robust and standalone for testing logic *without* flutter dependencies interfering with strict dart:io:
// We will Include the Logic directly or rely on `packages/mbeck_shared` being available.
// However, `Color` class comes from Flutter. This script needs to be run with `flutter test` or similar, OR we mock Color.
// But wait, the user wants to test the *shared* logic.
// Best approach: Use `flutter test` or import the package if `pub get` is done.

// Let's assume we can import the file relatively.
import '../packages/mbeck_shared/lib/src/models/shop_theme_config.dart';

void main() {
  print('🧪 Starting Theme Flow Verification...');

  // 1. Simulate Seller Choosing "Cyberpunk" Preset
  print('\n[Step 1] Seller selects "Cyberpunk" preset in UI');
  final sellerConfig = ShopThemeConfig(
    primaryColor: const Color(0xFF00E5FF),   // Neon Blue
    secondaryColor: const Color(0xFFFF00FF), // Neon Pink
    stylePreset: 'cyberpunk',
    fontFamily: 'Orbitron',
  );

  print('   > Selected: ${sellerConfig.stylePreset}');
  print('   > Primary: ${sellerConfig.primaryColor}');

  // 2. Simulate Save to DB (JSON Serialization)
  print('\n[Step 2] Serializing to JSON for Database Storage');
  final jsonPayload = sellerConfig.toJson();
  print('   > JSON Payload: ${jsonEncode(jsonPayload)}');

  // Verify Critical Fields
  if (jsonPayload['style_preset'] != 'cyberpunk') throw '❌ Preset failed to serialize';
  if (!jsonPayload['primary_color'].toString().contains('#')) throw '❌ Color hex format incorrect';
  
  // 3. Simulate DB Retrieval (JSON Parsing) by Buyer App
  print('\n[Step 3] Buyer App retrieves JSON from Shop Info');
  
  // Create a clean Map to simulate fresh DB read
  final dbResponse = Map<String, dynamic>.from(jsonPayload);
  
  final buyerConfig = ShopThemeConfig.fromJson(dbResponse);
  
  // 4. Verification
  print('\n[Step 4] Verifying Buyer Config matches Seller Config');
  
  bool success = true;
  
  if (buyerConfig.stylePreset != sellerConfig.stylePreset) {
    print('❌ Preset mismatch: Expected ${sellerConfig.stylePreset}, got ${buyerConfig.stylePreset}');
    success = false;
  }
  
  if (buyerConfig.primaryColor.value != sellerConfig.primaryColor.value) {
     print('❌ Primary Color mismatch');
     success = false;
  }
  
  if (buyerConfig.fontFamily != sellerConfig.fontFamily) {
    print('❌ Font Family mismatch');
    success = false;
  }

  if (success) {
    print('\n✅ TEST PASSED: Theme Data flows correctly from Seller to Buyer logic.');
    print('   Buyer App will render: Cyberpunk Theme with Neon Blue (#00E5FF)');
  } else {
    print('\n❌ TEST FAILED');
    throw Exception('Verification Failed');
  }
}
