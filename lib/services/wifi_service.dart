import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class WifiService {
  static const String _wifiPassKey = 'mbeck_hotspot_password';

  /// Generates or retrieves a stable WiFi password for this shop
  static Future<String> getHotspotPassword() async {
    final prefs = await SharedPreferences.getInstance();
    String? pass = prefs.getString(_wifiPassKey);
    
    if (pass == null) {
      // Generate a reasonably secure 10-character alphanumeric password
      const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
      final random = Random.secure();
      pass = List.generate(10, (index) => chars[random.nextInt(chars.length)]).join();
      await prefs.setString(_wifiPassKey, pass);
    }
    
    return pass;
  }

  /// Generates a valid SSID based on the shop name
  static Future<String> getHotspotSSID() async {
    final shop = await AuthService.getCurrentShop();
    if (shop == null) return "Mbeck_Shop_Hotspot";
    
    // Sanitize shop name: remove special chars, keep alphanumeric and spaces (replaced by _)
    String sanitized = shop.businessName
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
        
    if (sanitized.length > 20) sanitized = sanitized.substring(0, 20);
    
    return "Mbeck_$sanitized";
  }

  /// Returns the standard WIFI: string for QR codes
  /// WIFI:T:WPA;S:SSID;P:PASSWORD;;
  static Future<String> getWifiQrString() async {
    final ssid = await getHotspotSSID();
    final pass = await getHotspotPassword();
    return 'WIFI:T:WPA;S:$ssid;P:$pass;;';
  }
}
