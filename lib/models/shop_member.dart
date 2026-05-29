import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'permissions.dart';

/// ShopMember Model - Represents a team member (user) in a shop
@immutable
class ShopMember {
  final int id;
  final String shopId;
  final String? userId; // Link to Supabase Auth User
  final String deviceId;
  final String userName;
  final String role; // OWNER, ADMIN, STAFF
  final Map<String, dynamic> permissions;
  final DateTime joinedAt;
  final DateTime? lastActiveAt;
  final bool isActive;

  const ShopMember({
    required this.id,
    required this.shopId,
    this.userId,
    required this.deviceId,
    required this.userName,
    required this.role,
    required this.permissions,
    required this.joinedAt,
    this.lastActiveAt,
    required this.isActive,
  });

  /// Check if member has a specific permission
  /// Owners always have all permissions
  bool hasPermission(String permission) {
    if (role == 'OWNER') return true; // Owners have all permissions
    
    // Check locally saved user-specific permissions
    if (permissions[permission] == true) return true;

    // Fallback/additive check against the app's predefined RolePresets
    // This allows code-based preset updates to instantly apply without DB migrations
    final preset = RolePresets.getPresetForRole(role);
    return preset[permission] == true;
  }

  /// Check if member is owner
  bool get isOwner => role == 'OWNER';

  /// Check if member is admin
  bool get isAdmin => role == 'ADMIN';

  /// Check if member is staff
  bool get isStaff => role == 'STAFF';

  /// Get formatted role name
  String get roleDisplayName {
    switch (role) {
      case 'OWNER':
        return 'Owner';
      case 'ADMIN':
        return 'Admin';
      case 'STAFF':
        return 'Staff';
      default:
        return role;
    }
  }

  /// Convert ShopMember to Map for database/API storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'user_id': userId,
      'device_id': deviceId,
      'user_name': userName,
      'role': role,
      'permissions': jsonEncode(permissions),
      'joined_at': joinedAt.toIso8601String(),
      'last_active_at': lastActiveAt?.toIso8601String(),
      'is_active': isActive,
    };
  }

  /// Create ShopMember from Map (database/API response)
  factory ShopMember.fromMap(Map<String, dynamic> map) {
    return ShopMember(
      id: (map['id'] as num?)?.toInt() ?? 0,
      shopId: (map['shop_id'] as String?) ?? '',
      userId: map['user_id'] as String?,
      deviceId: (map['device_id'] as String?) ?? '',
      userName: (map['user_name'] as String?) ?? 'Unknown User',
      role: (map['role'] as String?) ?? 'STAFF',
      permissions: _parsePermissions(map['permissions']),
      joinedAt: _parseDateTime(map['joined_at']),
      lastActiveAt:
          map['last_active_at'] != null ? _parseDateTime(map['last_active_at']) : null,
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }

  /// Parse permissions from various formats
  static Map<String, dynamic> _parsePermissions(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        return Map<String, dynamic>.from(jsonDecode(value));
      } catch (e) {
        return {};
      }
    }
    return {};
  }

  /// Parse DateTime from string or timestamp
  static DateTime _parseDateTime(dynamic value) {
    if (value is String) {
      return DateTime.parse(value);
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }

  /// Copy with method for creating modified copies
  ShopMember copyWith({
    int? id,
    String? shopId,
    String? userId,
    String? deviceId,
    String? userName,
    String? role,
    Map<String, dynamic>? permissions,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    bool? isActive,
  }) {
    return ShopMember(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'ShopMember(id: $id, name: $userName, role: $role, shopId: $shopId, active: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ShopMember &&
        other.id == id &&
        other.shopId == shopId &&
        other.deviceId == deviceId &&
        other.userName == userName &&
        other.role == role;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        shopId.hashCode ^
        deviceId.hashCode ^
        userName.hashCode ^
        role.hashCode;
  }
}
