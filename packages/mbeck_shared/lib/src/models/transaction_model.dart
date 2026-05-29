import 'package:flutter/foundation.dart';

@immutable
class TxnModel {
  final int? id;
  final int? customerId;
  // itemId removed - transactions now have multiple items via transaction_items table
  final String type; // e.g. 'Incoming', 'Outgoing', 'sale'
  final int totalAmount;
  final String? details;
  final int? denominationLogId;
  final int timestamp;
  final String? receiptSignature;
  final String? cloudId;     // NEW: Cloud sync tracking identifier
  final String? sourceModule; // NEW: Originating module domain

  const TxnModel({
    this.id,
    this.customerId,
    required this.type,
    required this.totalAmount,
    this.details,
    this.denominationLogId,
    required this.timestamp,
    this.receiptSignature,
    this.cloudId,
    this.sourceModule,
  });

  factory TxnModel.fromMap(Map<String, dynamic> m) => TxnModel(
        id: m['id'] as int?,
        customerId: m['customerId'] as int?,
        type: m['type'] as String? ?? '',
        totalAmount: m['totalAmount'] as int? ?? 0,
        details: m['details'] as String?,
        denominationLogId: m['denominationLogId'] as int?,
        timestamp: m['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        receiptSignature: m['receiptSignature'] as String?,
        cloudId: m['cloud_id'] as String?,
        sourceModule: m['source_module'] as String? ?? 'retail',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'type': type,
        'totalAmount': totalAmount,
        'details': details,
        'denominationLogId': denominationLogId,
        'timestamp': timestamp,
        'receiptSignature': receiptSignature,
        'cloud_id': cloudId,
        'source_module': sourceModule,
      };

  TxnModel copyWith({
    int? id,
    int? customerId,
    String? type,
    int? totalAmount,
    String? details,
    int? denominationLogId,
    int? timestamp,
    String? receiptSignature,
    String? cloudId,
    String? sourceModule,
  }) {
    return TxnModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      type: type ?? this.type,
      totalAmount: totalAmount ?? this.totalAmount,
      details: details ?? this.details,
      denominationLogId: denominationLogId ?? this.denominationLogId,
      timestamp: timestamp ?? this.timestamp,
      receiptSignature: receiptSignature ?? this.receiptSignature,
      cloudId: cloudId ?? this.cloudId,
      sourceModule: sourceModule ?? this.sourceModule,
    );
  }

  @override
  String toString() {
    return 'TxnModel(id: $id, type: $type, totalAmount: $totalAmount, timestamp: $timestamp, cloudId: $cloudId, sourceModule: $sourceModule)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TxnModel &&
        other.id == id &&
        other.customerId == customerId &&
        other.type == type &&
        other.totalAmount == totalAmount &&
        other.details == details &&
        other.denominationLogId == denominationLogId &&
        other.timestamp == timestamp &&
        other.receiptSignature == receiptSignature &&
        other.cloudId == cloudId &&
        other.sourceModule == sourceModule;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      customerId.hashCode ^
      type.hashCode ^
      totalAmount.hashCode ^
      details.hashCode ^
      denominationLogId.hashCode ^
      timestamp.hashCode ^
      receiptSignature.hashCode ^
      cloudId.hashCode ^
      sourceModule.hashCode;
}
