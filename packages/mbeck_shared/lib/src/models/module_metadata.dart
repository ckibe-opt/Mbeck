import 'dart:convert';

/// Typed contract for `marketplace_items.metadata` (jsonb in cloud).
///
/// The seller writes this from `cloud_publish_service.dart` and the buyer
/// reads it in `cloud_shop_api_service.dart`. Each module gets its own
/// schema so we never quietly leak retail's `variations_json` into a lodging
/// card or a restaurant's `prep_time_minutes` into a service slot.
///
/// Wire format (all fields optional, all snake_case to match Postgres):
///
///   retail        : { barcode, variations_json }
///   restaurant    : { preparation_time_mins, modifier_groups_json }
///   services      : { duration_minutes, buffer_minutes }
///   lodging       : { capacity, amenities, rate_per_night, rate_per_week,
///                     rate_per_month, room_type, images[] }
///   entertainment : { rate_per_hour, flat_rate, asset_type, type_name,
///                     images[] }
///
/// Use [ModuleMetadata.fromCloud] to deserialize a `marketplace_items` row
/// (the row's `module_source` column drives which subtype is built), and
/// [toJson] when you want to ship it back to the cloud.
sealed class ModuleMetadata {
  const ModuleMetadata();

  /// Wire string for `marketplace_items.module_source`.
  String get moduleSource;

  Map<String, dynamic> toJson();

  /// Builds the right subtype from a marketplace_items row.
  /// Pass the whole row; we read `module_source` and `metadata`.
  factory ModuleMetadata.fromCloud(Map<String, dynamic> row) {
    final module = (row['module_source'] as String?) ?? 'retail';
    final raw = row['metadata'];
    final Map<String, dynamic> meta = raw is Map<String, dynamic>
        ? raw
        : (raw is String && raw.isNotEmpty ? jsonDecode(raw) as Map<String, dynamic> : <String, dynamic>{});

    switch (module) {
      case 'retail':        return RetailMetadata.fromJson(meta);
      case 'restaurant':    return RestaurantMetadata.fromJson(meta);
      case 'services':      return ServicesMetadata.fromJson(meta);
      case 'lodging':       return LodgingMetadata.fromJson(meta);
      case 'entertainment': return EntertainmentMetadata.fromJson(meta);
      default:              return RetailMetadata.fromJson(meta);
    }
  }
}

/// `retail` (`inventory` items).
class RetailMetadata extends ModuleMetadata {
  final String? barcode;
  final String? variationsJson;

  const RetailMetadata({this.barcode, this.variationsJson});

  @override
  String get moduleSource => 'retail';

  factory RetailMetadata.fromJson(Map<String, dynamic> j) => RetailMetadata(
        barcode: j['barcode'] as String?,
        variationsJson: j['variations_json'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        if (barcode != null) 'barcode': barcode,
        if (variationsJson != null) 'variations_json': variationsJson,
      };
}

/// `restaurant` (`restaurant_menu` items).
class RestaurantMetadata extends ModuleMetadata {
  final int? preparationTimeMins;
  /// JSON-encoded list of modifier groups. Stored as a string because
  /// downstream UIs commonly re-encode/parse independently.
  final String? modifierGroupsJson;

  const RestaurantMetadata({this.preparationTimeMins, this.modifierGroupsJson});

  @override
  String get moduleSource => 'restaurant';

  factory RestaurantMetadata.fromJson(Map<String, dynamic> j) => RestaurantMetadata(
        preparationTimeMins: (j['preparation_time_mins'] as num?)?.toInt(),
        modifierGroupsJson: j['modifier_groups_json'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        if (preparationTimeMins != null) 'preparation_time_mins': preparationTimeMins,
        if (modifierGroupsJson != null) 'modifier_groups_json': modifierGroupsJson,
      };
}

/// `services` (`services_catalog` items).
class ServicesMetadata extends ModuleMetadata {
  final int? durationMinutes;
  final int? bufferMinutes;

  const ServicesMetadata({this.durationMinutes, this.bufferMinutes});

  @override
  String get moduleSource => 'services';

  factory ServicesMetadata.fromJson(Map<String, dynamic> j) => ServicesMetadata(
        durationMinutes: (j['duration_minutes'] as num?)?.toInt(),
        bufferMinutes: (j['buffer_minutes'] as num?)?.toInt(),
      );

  @override
  Map<String, dynamic> toJson() => {
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
        if (bufferMinutes != null) 'buffer_minutes': bufferMinutes,
      };
}

/// `lodging` (`lodging_rooms` joined with `lodging_room_types`).
class LodgingMetadata extends ModuleMetadata {
  final int? capacity;
  final String? amenities;
  final num? ratePerNight;
  final num? ratePerWeek;
  final num? ratePerMonth;
  final String? roomType;
  /// Resolved-to-cloud-URL gallery, ordered. Up to 8 entries on the seller side.
  final List<String> images;

  const LodgingMetadata({
    this.capacity,
    this.amenities,
    this.ratePerNight,
    this.ratePerWeek,
    this.ratePerMonth,
    this.roomType,
    this.images = const [],
  });

  @override
  String get moduleSource => 'lodging';

  factory LodgingMetadata.fromJson(Map<String, dynamic> j) {
    final rawImages = j['images'];
    final List<String> imgs = rawImages is List
        ? rawImages.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const <String>[];
    return LodgingMetadata(
      capacity: (j['capacity'] as num?)?.toInt(),
      amenities: j['amenities'] as String?,
      ratePerNight: j['rate_per_night'] as num?,
      ratePerWeek: j['rate_per_week'] as num?,
      ratePerMonth: j['rate_per_month'] as num?,
      roomType: j['room_type'] as String?,
      images: imgs,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        if (capacity != null) 'capacity': capacity,
        if (amenities != null) 'amenities': amenities,
        if (ratePerNight != null) 'rate_per_night': ratePerNight,
        if (ratePerWeek != null) 'rate_per_week': ratePerWeek,
        if (ratePerMonth != null) 'rate_per_month': ratePerMonth,
        if (roomType != null) 'room_type': roomType,
        if (images.isNotEmpty) 'images': images,
      };

  /// Convenience: split the comma/pipe-delimited `amenities` string into chips.
  List<String> get amenitiesList {
    final raw = amenities;
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(RegExp(r'[,|;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

/// `entertainment` (`entertainment_assets` joined with `entertainment_asset_types`).
class EntertainmentMetadata extends ModuleMetadata {
  final num? ratePerHour;
  final num? flatRate;
  /// Pricing model: 'hourly' or 'flat' (matches `entertainment_asset_types.asset_type`).
  final String? assetType;
  final String? typeName;
  final List<String> images;

  const EntertainmentMetadata({
    this.ratePerHour,
    this.flatRate,
    this.assetType,
    this.typeName,
    this.images = const [],
  });

  @override
  String get moduleSource => 'entertainment';

  factory EntertainmentMetadata.fromJson(Map<String, dynamic> j) {
    final rawImages = j['images'];
    final List<String> imgs = rawImages is List
        ? rawImages.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const <String>[];
    return EntertainmentMetadata(
      ratePerHour: j['rate_per_hour'] as num?,
      flatRate: j['flat_rate'] as num?,
      assetType: j['asset_type'] as String?,
      typeName: j['type_name'] as String?,
      images: imgs,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        if (ratePerHour != null) 'rate_per_hour': ratePerHour,
        if (flatRate != null) 'flat_rate': flatRate,
        if (assetType != null) 'asset_type': assetType,
        if (typeName != null) 'type_name': typeName,
        if (images.isNotEmpty) 'images': images,
      };

  bool get isHourly => assetType == 'hourly';
  bool get isFlat => assetType == 'flat';
}

