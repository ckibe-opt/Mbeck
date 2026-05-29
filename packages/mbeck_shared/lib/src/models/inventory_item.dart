import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'product_variation.dart';

@immutable
class InventoryItem {
  final int? id;
  final String name;
  final String? category;
  final double sellingPrice;
  final double originalPrice;
  final int stock;
  final String? imagePath;
  final String? visualVector; // NEW: Added for AI Visual Recognition
  final String? specification; // NEW: Added for product details
  final String? barcode;     // NEW: Added for scanning
  final String? variationsJson; // JSON array of ProductVariation
  final String? cloudId;     // NEW: Cloud sync tracking identifier
  final String? sourceModule; // NEW: Retail module domain tracker
  final bool isPublished;  // NEW: Online Marketplace item discovery

  /// Get parsed variations list
  List<ProductVariation> get variations {
    if (variationsJson == null || variationsJson!.isEmpty) return [];
    try {
      final List decoded = jsonDecode(variationsJson!);
      return decoded.map((e) => ProductVariation.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Check if product has variations
  bool get hasVariations => variations.isNotEmpty;

  const InventoryItem({
    this.id,
    required this.name,
    this.category,
    required this.sellingPrice,
    required this.originalPrice,
    required this.stock,
    this.imagePath,
    this.visualVector,
    this.specification,
    this.barcode,
    this.variationsJson,
    this.cloudId,
    this.sourceModule,
    this.isPublished = false,
  });

  InventoryItem copyWith({
    int? id,
    String? name,
    String? category,
    double? sellingPrice,
    double? originalPrice,
    int? stock,
    String? imagePath,
    String? visualVector,
    String? specification,
    String? barcode,
    String? variationsJson,
    String? cloudId,
    String? sourceModule,
    bool? isPublished,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      originalPrice: originalPrice ?? this.originalPrice,
      stock: stock ?? this.stock,
      imagePath: imagePath ?? this.imagePath,
      visualVector: visualVector ?? this.visualVector,
      specification: specification ?? this.specification,
      barcode: barcode ?? this.barcode,
      variationsJson: variationsJson ?? this.variationsJson,
      cloudId: cloudId ?? this.cloudId,
      sourceModule: sourceModule ?? this.sourceModule,
      isPublished: isPublished ?? this.isPublished,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'sellingPrice': sellingPrice,
      'originalPrice': originalPrice,
      'stock': stock,
      'imagePath': imagePath,
      'visual_vector': visualVector,
      'specification': specification,
      'barcode': barcode,
      'variationsJson': variationsJson,
      'cloud_id': cloudId,
      'source_module': sourceModule,
      'is_published': isPublished ? 1 : 0,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    // Handle cases where 'id' might be a UUID string (from cloud)
    int? localId;
    if (map['id'] is int) {
      localId = map['id'];
    } else if (map['id'] is String) {
      localId = int.tryParse(map['id']);
    }

    return InventoryItem(
      id: localId,
      name: map['name'] as String? ?? 'Unknown Item',
      category: map['category'] as String? ?? 'General',
      sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (map['originalPrice'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      imagePath: map['imagePath'] as String? ?? map['image_path'] as String?,
      visualVector: map['visual_vector'] as String?,
      specification: map['specification'] as String?,
      barcode: map['barcode'] as String?,
      variationsJson: map['variationsJson'] as String? ?? map['variations_json'] as String?,
      cloudId: map['cloud_id'] as String?,
      sourceModule: map['source_module'] as String?,
      isPublished: map['is_published'] is bool 
          ? map['is_published'] as bool 
          : (map['is_published'] as num?)?.toInt() == 1,
    );
  }

  @override
  String toString() {
    return 'InventoryItem(id: $id, name: $name, stock: $stock, isPublished: $isPublished)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is InventoryItem &&
        other.id == id &&
        other.name == name &&
        other.category == category &&
        other.sellingPrice == sellingPrice &&
        other.originalPrice == originalPrice &&
        other.stock == stock &&
        other.imagePath == imagePath &&
        other.visualVector == visualVector &&
        other.specification == specification &&
        other.barcode == barcode &&
        other.variationsJson == variationsJson &&
        other.cloudId == cloudId &&
        other.sourceModule == sourceModule &&
        other.isPublished == isPublished;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      category.hashCode ^
      sellingPrice.hashCode ^
      originalPrice.hashCode ^
      stock.hashCode ^
      imagePath.hashCode ^
      visualVector.hashCode ^
      specification.hashCode ^
      barcode.hashCode ^
      variationsJson.hashCode ^
      cloudId.hashCode ^
      sourceModule.hashCode ^
      isPublished.hashCode;
}
