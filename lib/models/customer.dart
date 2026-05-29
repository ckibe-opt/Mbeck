import 'package:flutter/foundation.dart';

@immutable
class Customer {
  final int? id;
  final String name;
  final String? phone; // E.164 preferred
  final String? idNo;
  final String? bankAccount;
  final String? notes;
  final String? agent;
  final String? store;
  final int? createdAt;

  const Customer({
    this.id,
    required this.name,
    this.phone,
    this.idNo,
    this.bankAccount,
    this.notes,
    this.agent,
    this.store,
    this.createdAt,
  });

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? idNo,
    String? bankAccount,
    String? notes,
    String? agent,
    String? store,
    int? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      idNo: idNo ?? this.idNo,
      bankAccount: bankAccount ?? this.bankAccount,
      notes: notes ?? this.notes,
      agent: agent ?? this.agent,
      store: store ?? this.store,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        id: m['id'] as int?,
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String?,
        idNo: m['id_no'] as String?,
        bankAccount: m['bank_account'] as String?,
        notes: m['notes'] as String?,
        agent: m['agent'] as String?,
        store: m['store'] as String?,
        createdAt: m['createdAt'] as int?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'id_no': idNo,
        'bank_account': bankAccount,
        'notes': notes,
        'agent': agent,
        'store': store,
        'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
      };

  @override
  String toString() {
    return 'Customer(id: $id, name: $name, phone: $phone, store: $store)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Customer &&
        other.id == id &&
        other.name == name &&
        other.phone == phone &&
        other.idNo == idNo &&
        other.bankAccount == bankAccount &&
        other.notes == notes &&
        other.agent == agent &&
        other.store == store &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      phone.hashCode ^
      idNo.hashCode ^
      bankAccount.hashCode ^
      notes.hashCode ^
      agent.hashCode ^
      store.hashCode ^
      createdAt.hashCode;
}
