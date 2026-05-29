import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'auth_service.dart';
import 'device_service.dart';

class SecurityService {
  static const _storage = FlutterSecureStorage();
  static const _secretKeyName = 'mbeck_shop_secret_key';
  static const _dbKeyName = 'mbeck_db_encryption_key';
  
  String? _cachedSecret;
  String? _cachedDbKey;

  /// Retrieves the shop's secret key from secure storage.
  /// Generates a new one if it doesn't exist.
  Future<String> getSecretKey() async {
    if (_cachedSecret != null) return _cachedSecret!;
    
    try {
      String? key = await _storage.read(key: _secretKeyName);
      if (key == null) {
        key = const Uuid().v4(); // Generate a robust random key
        await _storage.write(key: _secretKeyName, value: key);
      }
      _cachedSecret = key;
      return key;
    } catch (e) {
      debugPrint('⚠️ SecureStorage Error (getSecretKey): $e');
      // Fallback: Generate temporary key for this session
      _cachedSecret ??= const Uuid().v4();
      return _cachedSecret!;
    }
  }

  /// Signs transaction data using HMAC-SHA256.
  /// 
  /// GHOST MODE PROTECTION: This method will throw an exception if the current
  /// session is in Observer mode (Ghost Mode). This prevents Enterprise owners
  /// visiting foreign shops from creating transactions.
  Future<String> signTransaction({
    required int timestamp,
    required num totalAmount, // Changed from int to num
    required String type,
    String? details,
    String? targetShopId, // Optional: override shop ID check
  }) async {
    // ========== GHOST MODE CHECK ==========
    // Verify we're not in observer mode before signing
    try {
      final sessionMode = await AuthService.getSessionMode();
      if (sessionMode == SessionMode.observer) {
        debugPrint('🚫 GHOST MODE: Refusing to sign transaction - read-only access');
        throw GhostModeException('Cannot create transactions in Ghost Mode. You are visiting a shop you do not operate.');
      }
    } on GhostModeException {
      rethrow;
    } catch (e) {
      debugPrint('⚠️ Error checking session mode (ignoring): $e');
    }
    
    // If a target shop ID is provided, verify it matches our home shop
    if (targetShopId != null) {
      final homeShopId = await DeviceService.getShopId();
      if (targetShopId != homeShopId) {
        debugPrint('🚫 SHOP MISMATCH: Transaction shop ($targetShopId) != home shop ($homeShopId)');
        throw GhostModeException('Cannot sign transactions for a different shop.');
      }
    }
    // =====================================
    
    final key = await getSecretKey();
    final hmac = Hmac(sha256, utf8.encode(key));
    
    // Create a canonical string representation of the data to sign
    // Ensure amount is formatted to 2 decimals to avoid floating point drift
    final formattedAmount = totalAmount.toStringAsFixed(2);
    final data = 'timestamp=$timestamp|amount=$formattedAmount|type=$type|details=${details ?? ""}';
    final digest = hmac.convert(utf8.encode(data));
    
    return digest.toString();
  }

  /// Verifies a transaction signature.
  Future<bool> verifySignature({
    required int timestamp,
    required num totalAmount,
    required String type,
    required String signature,
    String? details,
  }) async {
    final expectedSignature = await signTransaction(
      timestamp: timestamp,
      totalAmount: totalAmount,
      type: type,
      details: details,
    );
    
    return expectedSignature == signature;
  }

  /// Retrieves the database encryption key.
  Future<String> getDatabaseKey() async {
    if (_cachedDbKey != null) return _cachedDbKey!;
    
    try {
      String? key = await _storage.read(key: _dbKeyName);
      if (key == null) {
        key = const Uuid().v4(); 
        await _storage.write(key: _dbKeyName, value: key);
      }
      _cachedDbKey = key;
      return key;
    } catch (e) {
      debugPrint('⚠️ SecureStorage Error (getDatabaseKey): $e');
      // Fallback: Generate check key
      _cachedDbKey ??= const Uuid().v4();
      return _cachedDbKey!;
    }
  }
}

/// Exception thrown when an operation is blocked due to Ghost Mode.
/// 
/// Ghost Mode is active when an Enterprise owner visits a shop they don't
/// operate. In this mode, all write operations are blocked to prevent
/// data pollution.
class GhostModeException implements Exception {
  final String message;
  
  GhostModeException(this.message);
  
  @override
  String toString() => 'GhostModeException: $message';
}
