import 'package:flutter/foundation.dart';

/// Shop Model - Represents a business/shop in the system.
///
/// NAMING CONTRACT — DO NOT BREAK:
/// * Cloud (Supabase `shops` table)  -> column is `name`
/// * Local SQLite (`shops` table)    -> column is `business_name`
/// * Dart model field                -> `businessName`
///
/// `Shop.fromMap` reads `name` first, then falls back to `business_name`,
/// so it works with either source. When WRITING to the cloud, always use
/// `'name'` (see CloudPublishService). When writing to local SQLite, use
/// `'business_name'`. There is no plan to unify these — renaming the local
/// column is more disruptive than the mapping.
@immutable
class Shop {
  final String id;
  final String businessName;
  final String ownerDeviceId;
  final String? ownerId; // Supabase Auth UID (The "Chain Owner")
  final String? chainId; // Optional: Group ID for complex franchises
  final String? franchiseId; // Enterprise Franchise ID
  final String? region; // Operational Region
  final String currency; // ISO Currency Code (e.g., KES)
  final String subscriptionTier; // FREE, PRO, ENTERPRISE
  final String subscriptionStatus; // ACTIVE, SUSPENDED, CANCELLED
  final bool isPublishedOnline; // Controls Mbeck Go visibility
  final String verificationStatus; // UNVERIFIED, PENDING, VERIFIED, REJECTED
  final int onlineViews; // Lifetime buyer app views
  final DateTime joinedAt;
  final DateTime? trialEndsAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> themeConfig;
  final double trustScore;

  const Shop({
    required this.id,
    required this.businessName,
    required this.ownerDeviceId,
    this.ownerId,
    this.chainId,
    this.franchiseId,
    this.region,
    this.currency = 'KES',
    required this.subscriptionTier,
    required this.subscriptionStatus,
    this.isPublishedOnline = false,
    this.verificationStatus = 'UNVERIFIED',
    this.onlineViews = 0,
    required this.joinedAt,
    this.trialEndsAt,
    required this.createdAt,
    required this.updatedAt,
    this.themeConfig = const {},
    this.trustScore = 0.0,
  });

  // ... (Getters remain same) ...
  /// Check if the shop is currently on trial
  bool get isOnTrial {
    if (trialEndsAt == null) return false;
    return DateTime.now().isBefore(trialEndsAt!);
  }

  /// Check if the shop has Pro or Enterprise access (including trial)
  bool get hasProAccess {
    return subscriptionTier == 'PRO' ||
        subscriptionTier == 'PRO Yearly' ||
        subscriptionTier == 'ENTERPRISE' ||
        subscriptionTier == 'ENTERPRISE Yearly' ||
        isOnTrial;
  }

  /// Check if the shop has Enterprise access
  bool get isEnterprise =>
      subscriptionTier == 'ENTERPRISE' ||
      subscriptionTier == 'ENTERPRISE Yearly';

  /// Check if the shop can install paid modules (Pro or Enterprise)
  bool get canAccessPaidModules => hasProAccess;

  /// Get remaining trial days
  int get trialDaysRemaining {
    if (trialEndsAt == null) return 0;
    final diff = trialEndsAt!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Check if shop is active
  bool get isActive => subscriptionStatus == 'ACTIVE';

  /// Check if shop subscription is suspended
  bool get isSuspended => subscriptionStatus == 'SUSPENDED';

  /// Check if shop subscription is cancelled
  bool get isCancelled => subscriptionStatus == 'CANCELLED';

  /// Convert Shop to Map for database/API storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': businessName,
      'owner_device_id': ownerDeviceId,
      'owner_id': ownerId,
      'chain_id': chainId,
      'franchise_id': franchiseId,
      'region': region,
      'currency': currency,
      'subscription_tier': subscriptionTier,
      'subscription_status': subscriptionStatus,
      'is_published_online': isPublishedOnline ? 1 : 0,
      'verification_status': verificationStatus,
      'online_views': onlineViews,
      'joined_at': joinedAt.toIso8601String(),
      'trial_ends_at': trialEndsAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'theme_config': themeConfig,
      'trust_score': trustScore,
    };
  }

  /// Create Shop from Map (database/API response)
  factory Shop.fromMap(Map<String, dynamic> map) {
    try {
      return Shop(
        id: (map['id'] as String?) ?? 'unknown_id',
        // Check 'name' first (DB column), fallback to 'business_name' (legacy/local)
        businessName: (map['name'] as String?) ?? (map['business_name'] as String?) ?? 'Unknown Shop',
        ownerDeviceId: (map['owner_device_id'] as String?) ?? 'unknown_device',
        ownerId: map['owner_id'] as String?,
        chainId: map['chain_id'] as String?,
        franchiseId: map['franchise_id'] as String?,
        region: map['region'] as String?,
        currency: (map['currency'] as String?) ?? 'KES',
        subscriptionTier: (map['subscription_tier'] as String?) ?? 'FREE',
        subscriptionStatus: (map['subscription_status'] as String?) ?? 'ACTIVE',
        isPublishedOnline: map['is_published_online'] == 1 || map['is_published_online'] == true,
        verificationStatus: (map['verification_status'] as String?) ?? 'UNVERIFIED',
        onlineViews: (map['online_views'] as num?)?.toInt() ?? 0,
        joinedAt: _parseDateTime(map['joined_at']),
        trialEndsAt:
            map['trial_ends_at'] != null ? _parseDateTime(map['trial_ends_at']) : null,
        createdAt: _parseDateTime(map['created_at']),
        updatedAt: _parseDateTime(map['updated_at']),
        themeConfig: map['theme_config'] != null 
            ? Map<String, dynamic>.from(map['theme_config']) 
            : const {},
        trustScore: (map['trust_score'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e, stack) {
      debugPrint('ERROR IN Shop.fromMap: $e\n$stack');
      rethrow;
    }
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
  Shop copyWith({
    String? id,
    String? businessName,
    String? ownerDeviceId,
    String? ownerId,
    String? chainId,
    String? franchiseId,
    String? region,
    String? currency,
    String? subscriptionTier,
    String? subscriptionStatus,
    bool? isPublishedOnline,
    String? verificationStatus,
    int? onlineViews,
    DateTime? joinedAt,
    DateTime? trialEndsAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? themeConfig,
    double? trustScore,
  }) {
    return Shop(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      ownerDeviceId: ownerDeviceId ?? this.ownerDeviceId,
      ownerId: ownerId ?? this.ownerId,
      chainId: chainId ?? this.chainId,
      franchiseId: franchiseId ?? this.franchiseId,
      region: region ?? this.region,
      currency: currency ?? this.currency,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      isPublishedOnline: isPublishedOnline ?? this.isPublishedOnline,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      onlineViews: onlineViews ?? this.onlineViews,
      joinedAt: joinedAt ?? this.joinedAt,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      themeConfig: themeConfig ?? this.themeConfig,
      trustScore: trustScore ?? this.trustScore,
    );
  }

  @override
  String toString() {
    return 'Shop(id: $id, name: $businessName, tier: $subscriptionTier, trust: $trustScore)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Shop &&
        other.id == id &&
        other.businessName == businessName &&
        other.ownerId == ownerId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        businessName.hashCode ^
        ownerId.hashCode ^
        trustScore.hashCode;
  }
}

/// Extension to handle subscription logic and limits
extension ShopSubscriptionLogic on Shop {
  /// Maximum number of inventory items allowed
  /// Returns -1 for unlimited
  int get maxInventoryItems {
    switch (subscriptionTier) {
      case 'PRO':
      case 'PRO Yearly':
      case 'ENTERPRISE':
      case 'ENTERPRISE Yearly':
        return -1; // Unlimited
      case 'FREE':
      default:
        return 50;
    }
  }

  /// Maximum number of staff members allowed (including owner)
  /// Returns -1 for unlimited
  int get maxStaffMembers {
    switch (subscriptionTier) {
      case 'ENTERPRISE':
      case 'ENTERPRISE Yearly':
        return -1; // Unlimited
      case 'PRO':
      case 'PRO Yearly':
        return 3;
      case 'FREE':
      default:
        return 1;
    }
  }

  /// Maximum number of menu items allowed
  /// Returns -1 for unlimited
  int get maxMenuItems {
    switch (subscriptionTier) {
      case 'PRO':
      case 'PRO Yearly':
      case 'ENTERPRISE':
      case 'ENTERPRISE Yearly':
        return -1; // Unlimited
      case 'FREE':
      default:
        return 30;
    }
  }

  /// Maximum number of service catalog items allowed
  /// Returns -1 for unlimited
  int get maxServiceItems {
    switch (subscriptionTier) {
      case 'PRO':
      case 'PRO Yearly':
      case 'ENTERPRISE':
      case 'ENTERPRISE Yearly':
        return -1; // Unlimited
      case 'FREE':
      default:
        return 20;
    }
  }

  /// Helper to check if a specific limit is reached
  bool isInventoryLimitReached(int currentCount) {
    if (maxInventoryItems == -1) return false;
    return currentCount >= maxInventoryItems;
  }

  /// Helper to check if staff limit is reached
  bool isStaffLimitReached(int currentCount) {
    if (maxStaffMembers == -1) return false;
    return currentCount >= maxStaffMembers;
  }

  /// Helper to check if menu limit is reached
  bool isMenuLimitReached(int currentCount) {
    if (maxMenuItems == -1) return false;
    return currentCount >= maxMenuItems;
  }

  /// Helper to check if service limit is reached
  bool isServiceLimitReached(int currentCount) {
    if (maxServiceItems == -1) return false;
    return currentCount >= maxServiceItems;
  }
}
