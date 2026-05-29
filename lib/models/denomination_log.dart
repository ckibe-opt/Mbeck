// lib/models/denomination_log.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

@immutable
class DenominationLog {
  final int? id;
  final Map<String, int> amounts; // denom -> count
  final int computedTotal;

  const DenominationLog({this.id, required this.amounts, required this.computedTotal});

  factory DenominationLog.fromMap(Map<String, dynamic> m) {
    final jsonStr = m['amountsJson'] as String? ?? '{}';
    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      parsed = {};
    }
    final amountsParsed = parsed.map((k, v) => MapEntry(k, (v is int) ? v : int.tryParse(v.toString()) ?? 0));
    return DenominationLog(
      id: m['id'] as int?,
      amounts: Map<String, int>.from(amountsParsed),
      computedTotal: m['computedTotal'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'amountsJson': jsonEncode(amounts),
        'computedTotal': computedTotal,
      };

  DenominationLog copyWith({
    int? id,
    Map<String, int>? amounts,
    int? computedTotal,
  }) {
    return DenominationLog(
      id: id ?? this.id,
      amounts: amounts ?? this.amounts,
      computedTotal: computedTotal ?? this.computedTotal,
    );
  }

  @override
  String toString() => 'DenominationLog(id: $id, computedTotal: $computedTotal, amounts: $amounts)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final mapEquals = const MapEquality().equals;

    return other is DenominationLog &&
        other.id == id &&
        mapEquals(other.amounts, amounts) &&
        other.computedTotal == computedTotal;
  }

  @override
  int get hashCode {
    // Use MapEquality for a proper hash of the map's contents.
    return id.hashCode ^
           const MapEquality().hash(amounts) ^
           computedTotal.hashCode;
  }
}
