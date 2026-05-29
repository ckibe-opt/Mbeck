import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

@immutable
class Event {
  final String id;
  final String eventType;
  final Map<String, dynamic> payload;
  final String hash;
  final int timestamp;
  final String? shopId;
  final String? deviceId;
  
  // Sync Metadata
  final int synced;
  final int syncAttempts;
  final int failed;

  // The exact string used to generate the hash
  final String? payloadRaw; 

  const Event({
    required this.id,
    required this.eventType,
    required this.payload,
    required this.hash,
    required this.timestamp,
    this.shopId,
    this.deviceId,
    this.synced = 0,
    this.syncAttempts = 0,
    this.failed = 0,
    this.payloadRaw, 
  });

  /// Create a new event with canonical JSON encoding
  factory Event.create({
    required String eventType,
    required Map<String, dynamic> payload,
    String? shopId,
    String? deviceId,
    int? timestamp,
  }) {
    final id = const Uuid().v4();
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    
    // 1. Encode payload with SORTED KEYS (canonical JSON)
    final rawString = _encodeCanonical(payload);
    
    // 2. Calculate hash using that specific string
    final hashInput = '$id|$eventType|$rawString|$ts|${shopId ?? ''}|${deviceId ?? ''}';
    final bytes = utf8.encode(hashInput);
    final hash = sha256.convert(bytes).toString();


    return Event(
      id: id,
      eventType: eventType,
      payload: payload,
      payloadRaw: rawString,
      hash: hash,
      timestamp: ts,
      shopId: shopId,
      deviceId: deviceId,
    );
  }

  /// Encode JSON with keys sorted alphabetically
  static String _encodeCanonical(Map<String, dynamic> map) {
    final sortedKeys = map.keys.toList()..sort();
    final sorted = <String, dynamic>{};
    
    for (final key in sortedKeys) {
      final value = map[key];
      if (value is Map<String, dynamic>) {
        sorted[key] = jsonDecode(_encodeCanonical(value));
      } else if (value is List) {
        sorted[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return jsonDecode(_encodeCanonical(item));
          }
          return item;
        }).toList();
      } else {
        sorted[key] = value;
      }
    }
    
    return jsonEncode(sorted);
  }

  /// Verify event integrity
  bool verifyIntegrity() {
    final rawString = payloadRaw ?? _encodeCanonical(payload);
    final hashInput = '$id|$eventType|$rawString|$timestamp|${shopId ?? ''}|${deviceId ?? ''}';
    final bytes = utf8.encode(hashInput);
    final computedHash = sha256.convert(bytes).toString();
    return computedHash == hash;
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedPayload;
    String raw;
    
    if (map['payload'] is String) {
      raw = map['payload'] as String;
      parsedPayload = jsonDecode(raw) as Map<String, dynamic>;
    } else {
      parsedPayload = Map<String, dynamic>.from(map['payload'] as Map);
      raw = _encodeCanonical(parsedPayload);
    }

    return Event(
      id: map['id'] as String,
      eventType: map['event_type'] as String,
      payload: parsedPayload,
      payloadRaw: map['payload_raw'] as String? ?? raw,
      hash: map['hash'] as String,
      timestamp: map['timestamp'] as int,
      shopId: map['shop_id'] as String?,
      deviceId: map['device_id'] as String?,
      synced: map['synced'] as int? ?? 0,
      syncAttempts: map['sync_attempts'] as int? ?? 0,
      failed: map['failed'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    final raw = payloadRaw ?? _encodeCanonical(payload);
    
    return {
      'id': id,
      'event_type': eventType,
      'payload': raw,
      'payload_raw': raw,
      'hash': hash,
      'timestamp': timestamp,
      'shop_id': shopId,
      'device_id': deviceId,
      'synced': synced,
      'sync_attempts': syncAttempts,
      'failed': failed,
    };
  }

  Event copyWith({
    int? synced,
    int? syncAttempts,
    int? failed,
  }) {
    return Event(
      id: id,
      eventType: eventType,
      payload: payload,
      payloadRaw: payloadRaw,
      hash: hash,
      timestamp: timestamp,
      shopId: shopId,
      deviceId: deviceId,
      synced: synced ?? this.synced,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      failed: failed ?? this.failed,
    );
  }
}
