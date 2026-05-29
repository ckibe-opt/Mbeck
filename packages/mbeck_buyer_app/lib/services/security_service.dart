import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static final SecurityService instance = SecurityService._init();
  static const String _privateKeyKey = 'device_private_key_ed25519';
  
  late SimpleKeyPair _keyPair;
  bool _isInitialized = false;

  SecurityService._init();

  Future<void> init() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString(_privateKeyKey);

    final algorithm = Ed25519();

    if (storedKey != null) {
      // Restore key
      final bytes = base64Decode(storedKey);
      _keyPair = await algorithm.newKeyPairFromSeed(bytes);
      debugPrint('🔐 Security: Device Key Restored');
    } else {
      // Generate new key
      _keyPair = await algorithm.newKeyPair();
      final seed = await _keyPair.extractPrivateKeyBytes();
      await prefs.setString(_privateKeyKey, base64Encode(seed));
      debugPrint('🔐 Security: New Device Key Generated');
    }
    
    _isInitialized = true;
  }

  /// Sign a payload (e.g. "Exit Token")
  Future<String> signPayload(String payload) async {
    if (!_isInitialized) await init();
    
    final algorithm = Ed25519();
    final message = utf8.encode(payload);
    
    final signature = await algorithm.sign(
      message,
      keyPair: _keyPair,
    );
    
    // Return Format: Payload.Signature (Base64)
    final sigBase64 = base64Encode(signature.bytes);
    return '$payload.$sigBase64';
  }

  /// Get Public Key (to share with Seller)
  Future<String> getPublicKey() async {
    if (!_isInitialized) await init();
    final pubKey = await _keyPair.extractPublicKey();
    return base64Encode(pubKey.bytes);
  }
}
