// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ReceiptsTable extends Receipts with TableInfo<$ReceiptsTable, Receipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sellerIdMeta = const VerificationMeta(
    'sellerId',
  );
  @override
  late final GeneratedColumn<String> sellerId = GeneratedColumn<String>(
    'seller_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sellerNameMeta = const VerificationMeta(
    'sellerName',
  );
  @override
  late final GeneratedColumn<String> sellerName = GeneratedColumn<String>(
    'seller_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemsJsonMeta = const VerificationMeta(
    'itemsJson',
  );
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
    'items_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalAmountMeta = const VerificationMeta(
    'totalAmount',
  );
  @override
  late final GeneratedColumn<int> totalAmount = GeneratedColumn<int>(
    'total_amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signatureMeta = const VerificationMeta(
    'signature',
  );
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
    'signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
    'is_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  @override
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
    'module',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sellerId,
    sellerName,
    itemsJson,
    totalAmount,
    timestamp,
    signature,
    isSynced,
    module,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Receipt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('seller_id')) {
      context.handle(
        _sellerIdMeta,
        sellerId.isAcceptableOrUnknown(data['seller_id']!, _sellerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sellerIdMeta);
    }
    if (data.containsKey('seller_name')) {
      context.handle(
        _sellerNameMeta,
        sellerName.isAcceptableOrUnknown(data['seller_name']!, _sellerNameMeta),
      );
    } else if (isInserting) {
      context.missing(_sellerNameMeta);
    }
    if (data.containsKey('items_json')) {
      context.handle(
        _itemsJsonMeta,
        itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsJsonMeta);
    }
    if (data.containsKey('total_amount')) {
      context.handle(
        _totalAmountMeta,
        totalAmount.isAcceptableOrUnknown(
          data['total_amount']!,
          _totalAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalAmountMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('signature')) {
      context.handle(
        _signatureMeta,
        signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta),
      );
    } else if (isInserting) {
      context.missing(_signatureMeta);
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    if (data.containsKey('module')) {
      context.handle(
        _moduleMeta,
        module.isAcceptableOrUnknown(data['module']!, _moduleMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Receipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Receipt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sellerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seller_id'],
      )!,
      sellerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seller_name'],
      )!,
      itemsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items_json'],
      )!,
      totalAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_amount'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      signature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
      module: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $ReceiptsTable createAlias(String alias) {
    return $ReceiptsTable(attachedDatabase, alias);
  }
}

class Receipt extends DataClass implements Insertable<Receipt> {
  final String id;
  final String sellerId;
  final String sellerName;
  final String itemsJson;
  final int totalAmount;
  final DateTime timestamp;
  final String signature;
  final bool isSynced;
  final String? module;
  final String? notes;
  const Receipt({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.itemsJson,
    required this.totalAmount,
    required this.timestamp,
    required this.signature,
    required this.isSynced,
    this.module,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['seller_id'] = Variable<String>(sellerId);
    map['seller_name'] = Variable<String>(sellerName);
    map['items_json'] = Variable<String>(itemsJson);
    map['total_amount'] = Variable<int>(totalAmount);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['signature'] = Variable<String>(signature);
    map['is_synced'] = Variable<bool>(isSynced);
    if (!nullToAbsent || module != null) {
      map['module'] = Variable<String>(module);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  ReceiptsCompanion toCompanion(bool nullToAbsent) {
    return ReceiptsCompanion(
      id: Value(id),
      sellerId: Value(sellerId),
      sellerName: Value(sellerName),
      itemsJson: Value(itemsJson),
      totalAmount: Value(totalAmount),
      timestamp: Value(timestamp),
      signature: Value(signature),
      isSynced: Value(isSynced),
      module: module == null && nullToAbsent
          ? const Value.absent()
          : Value(module),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Receipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Receipt(
      id: serializer.fromJson<String>(json['id']),
      sellerId: serializer.fromJson<String>(json['sellerId']),
      sellerName: serializer.fromJson<String>(json['sellerName']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      totalAmount: serializer.fromJson<int>(json['totalAmount']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      signature: serializer.fromJson<String>(json['signature']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      module: serializer.fromJson<String?>(json['module']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sellerId': serializer.toJson<String>(sellerId),
      'sellerName': serializer.toJson<String>(sellerName),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'totalAmount': serializer.toJson<int>(totalAmount),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'signature': serializer.toJson<String>(signature),
      'isSynced': serializer.toJson<bool>(isSynced),
      'module': serializer.toJson<String?>(module),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Receipt copyWith({
    String? id,
    String? sellerId,
    String? sellerName,
    String? itemsJson,
    int? totalAmount,
    DateTime? timestamp,
    String? signature,
    bool? isSynced,
    Value<String?> module = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => Receipt(
    id: id ?? this.id,
    sellerId: sellerId ?? this.sellerId,
    sellerName: sellerName ?? this.sellerName,
    itemsJson: itemsJson ?? this.itemsJson,
    totalAmount: totalAmount ?? this.totalAmount,
    timestamp: timestamp ?? this.timestamp,
    signature: signature ?? this.signature,
    isSynced: isSynced ?? this.isSynced,
    module: module.present ? module.value : this.module,
    notes: notes.present ? notes.value : this.notes,
  );
  Receipt copyWithCompanion(ReceiptsCompanion data) {
    return Receipt(
      id: data.id.present ? data.id.value : this.id,
      sellerId: data.sellerId.present ? data.sellerId.value : this.sellerId,
      sellerName: data.sellerName.present
          ? data.sellerName.value
          : this.sellerName,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      totalAmount: data.totalAmount.present
          ? data.totalAmount.value
          : this.totalAmount,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      signature: data.signature.present ? data.signature.value : this.signature,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      module: data.module.present ? data.module.value : this.module,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Receipt(')
          ..write('id: $id, ')
          ..write('sellerId: $sellerId, ')
          ..write('sellerName: $sellerName, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('timestamp: $timestamp, ')
          ..write('signature: $signature, ')
          ..write('isSynced: $isSynced, ')
          ..write('module: $module, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sellerId,
    sellerName,
    itemsJson,
    totalAmount,
    timestamp,
    signature,
    isSynced,
    module,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Receipt &&
          other.id == this.id &&
          other.sellerId == this.sellerId &&
          other.sellerName == this.sellerName &&
          other.itemsJson == this.itemsJson &&
          other.totalAmount == this.totalAmount &&
          other.timestamp == this.timestamp &&
          other.signature == this.signature &&
          other.isSynced == this.isSynced &&
          other.module == this.module &&
          other.notes == this.notes);
}

class ReceiptsCompanion extends UpdateCompanion<Receipt> {
  final Value<String> id;
  final Value<String> sellerId;
  final Value<String> sellerName;
  final Value<String> itemsJson;
  final Value<int> totalAmount;
  final Value<DateTime> timestamp;
  final Value<String> signature;
  final Value<bool> isSynced;
  final Value<String?> module;
  final Value<String?> notes;
  final Value<int> rowid;
  const ReceiptsCompanion({
    this.id = const Value.absent(),
    this.sellerId = const Value.absent(),
    this.sellerName = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.totalAmount = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.signature = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.module = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReceiptsCompanion.insert({
    required String id,
    required String sellerId,
    required String sellerName,
    required String itemsJson,
    required int totalAmount,
    required DateTime timestamp,
    required String signature,
    this.isSynced = const Value.absent(),
    this.module = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sellerId = Value(sellerId),
       sellerName = Value(sellerName),
       itemsJson = Value(itemsJson),
       totalAmount = Value(totalAmount),
       timestamp = Value(timestamp),
       signature = Value(signature);
  static Insertable<Receipt> custom({
    Expression<String>? id,
    Expression<String>? sellerId,
    Expression<String>? sellerName,
    Expression<String>? itemsJson,
    Expression<int>? totalAmount,
    Expression<DateTime>? timestamp,
    Expression<String>? signature,
    Expression<bool>? isSynced,
    Expression<String>? module,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sellerId != null) 'seller_id': sellerId,
      if (sellerName != null) 'seller_name': sellerName,
      if (itemsJson != null) 'items_json': itemsJson,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (timestamp != null) 'timestamp': timestamp,
      if (signature != null) 'signature': signature,
      if (isSynced != null) 'is_synced': isSynced,
      if (module != null) 'module': module,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReceiptsCompanion copyWith({
    Value<String>? id,
    Value<String>? sellerId,
    Value<String>? sellerName,
    Value<String>? itemsJson,
    Value<int>? totalAmount,
    Value<DateTime>? timestamp,
    Value<String>? signature,
    Value<bool>? isSynced,
    Value<String?>? module,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return ReceiptsCompanion(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      itemsJson: itemsJson ?? this.itemsJson,
      totalAmount: totalAmount ?? this.totalAmount,
      timestamp: timestamp ?? this.timestamp,
      signature: signature ?? this.signature,
      isSynced: isSynced ?? this.isSynced,
      module: module ?? this.module,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sellerId.present) {
      map['seller_id'] = Variable<String>(sellerId.value);
    }
    if (sellerName.present) {
      map['seller_name'] = Variable<String>(sellerName.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (totalAmount.present) {
      map['total_amount'] = Variable<int>(totalAmount.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (signature.present) {
      map['signature'] = Variable<String>(signature.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptsCompanion(')
          ..write('id: $id, ')
          ..write('sellerId: $sellerId, ')
          ..write('sellerName: $sellerName, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('timestamp: $timestamp, ')
          ..write('signature: $signature, ')
          ..write('isSynced: $isSynced, ')
          ..write('module: $module, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserProfileTable extends UserProfile
    with TableInfo<$UserProfileTable, UserProfileData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfileTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneNumberMeta = const VerificationMeta(
    'phoneNumber',
  );
  @override
  late final GeneratedColumn<String> phoneNumber = GeneratedColumn<String>(
    'phone_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creditScoreMeta = const VerificationMeta(
    'creditScore',
  );
  @override
  late final GeneratedColumn<int> creditScore = GeneratedColumn<int>(
    'credit_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _walletBalanceMeta = const VerificationMeta(
    'walletBalance',
  );
  @override
  late final GeneratedColumn<double> walletBalance = GeneratedColumn<double>(
    'wallet_balance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    phoneNumber,
    creditScore,
    walletBalance,
    lastUpdated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfileData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('phone_number')) {
      context.handle(
        _phoneNumberMeta,
        phoneNumber.isAcceptableOrUnknown(
          data['phone_number']!,
          _phoneNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_phoneNumberMeta);
    }
    if (data.containsKey('credit_score')) {
      context.handle(
        _creditScoreMeta,
        creditScore.isAcceptableOrUnknown(
          data['credit_score']!,
          _creditScoreMeta,
        ),
      );
    }
    if (data.containsKey('wallet_balance')) {
      context.handle(
        _walletBalanceMeta,
        walletBalance.isAcceptableOrUnknown(
          data['wallet_balance']!,
          _walletBalanceMeta,
        ),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfileData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      phoneNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone_number'],
      )!,
      creditScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credit_score'],
      ),
      walletBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}wallet_balance'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      ),
    );
  }

  @override
  $UserProfileTable createAlias(String alias) {
    return $UserProfileTable(attachedDatabase, alias);
  }
}

class UserProfileData extends DataClass implements Insertable<UserProfileData> {
  final String id;
  final String phoneNumber;
  final int? creditScore;
  final double walletBalance;
  final DateTime? lastUpdated;
  const UserProfileData({
    required this.id,
    required this.phoneNumber,
    this.creditScore,
    required this.walletBalance,
    this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['phone_number'] = Variable<String>(phoneNumber);
    if (!nullToAbsent || creditScore != null) {
      map['credit_score'] = Variable<int>(creditScore);
    }
    map['wallet_balance'] = Variable<double>(walletBalance);
    if (!nullToAbsent || lastUpdated != null) {
      map['last_updated'] = Variable<DateTime>(lastUpdated);
    }
    return map;
  }

  UserProfileCompanion toCompanion(bool nullToAbsent) {
    return UserProfileCompanion(
      id: Value(id),
      phoneNumber: Value(phoneNumber),
      creditScore: creditScore == null && nullToAbsent
          ? const Value.absent()
          : Value(creditScore),
      walletBalance: Value(walletBalance),
      lastUpdated: lastUpdated == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdated),
    );
  }

  factory UserProfileData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileData(
      id: serializer.fromJson<String>(json['id']),
      phoneNumber: serializer.fromJson<String>(json['phoneNumber']),
      creditScore: serializer.fromJson<int?>(json['creditScore']),
      walletBalance: serializer.fromJson<double>(json['walletBalance']),
      lastUpdated: serializer.fromJson<DateTime?>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'phoneNumber': serializer.toJson<String>(phoneNumber),
      'creditScore': serializer.toJson<int?>(creditScore),
      'walletBalance': serializer.toJson<double>(walletBalance),
      'lastUpdated': serializer.toJson<DateTime?>(lastUpdated),
    };
  }

  UserProfileData copyWith({
    String? id,
    String? phoneNumber,
    Value<int?> creditScore = const Value.absent(),
    double? walletBalance,
    Value<DateTime?> lastUpdated = const Value.absent(),
  }) => UserProfileData(
    id: id ?? this.id,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    creditScore: creditScore.present ? creditScore.value : this.creditScore,
    walletBalance: walletBalance ?? this.walletBalance,
    lastUpdated: lastUpdated.present ? lastUpdated.value : this.lastUpdated,
  );
  UserProfileData copyWithCompanion(UserProfileCompanion data) {
    return UserProfileData(
      id: data.id.present ? data.id.value : this.id,
      phoneNumber: data.phoneNumber.present
          ? data.phoneNumber.value
          : this.phoneNumber,
      creditScore: data.creditScore.present
          ? data.creditScore.value
          : this.creditScore,
      walletBalance: data.walletBalance.present
          ? data.walletBalance.value
          : this.walletBalance,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileData(')
          ..write('id: $id, ')
          ..write('phoneNumber: $phoneNumber, ')
          ..write('creditScore: $creditScore, ')
          ..write('walletBalance: $walletBalance, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, phoneNumber, creditScore, walletBalance, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileData &&
          other.id == this.id &&
          other.phoneNumber == this.phoneNumber &&
          other.creditScore == this.creditScore &&
          other.walletBalance == this.walletBalance &&
          other.lastUpdated == this.lastUpdated);
}

class UserProfileCompanion extends UpdateCompanion<UserProfileData> {
  final Value<String> id;
  final Value<String> phoneNumber;
  final Value<int?> creditScore;
  final Value<double> walletBalance;
  final Value<DateTime?> lastUpdated;
  final Value<int> rowid;
  const UserProfileCompanion({
    this.id = const Value.absent(),
    this.phoneNumber = const Value.absent(),
    this.creditScore = const Value.absent(),
    this.walletBalance = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfileCompanion.insert({
    required String id,
    required String phoneNumber,
    this.creditScore = const Value.absent(),
    this.walletBalance = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       phoneNumber = Value(phoneNumber);
  static Insertable<UserProfileData> custom({
    Expression<String>? id,
    Expression<String>? phoneNumber,
    Expression<int>? creditScore,
    Expression<double>? walletBalance,
    Expression<DateTime>? lastUpdated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (creditScore != null) 'credit_score': creditScore,
      if (walletBalance != null) 'wallet_balance': walletBalance,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfileCompanion copyWith({
    Value<String>? id,
    Value<String>? phoneNumber,
    Value<int?>? creditScore,
    Value<double>? walletBalance,
    Value<DateTime?>? lastUpdated,
    Value<int>? rowid,
  }) {
    return UserProfileCompanion(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      creditScore: creditScore ?? this.creditScore,
      walletBalance: walletBalance ?? this.walletBalance,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (phoneNumber.present) {
      map['phone_number'] = Variable<String>(phoneNumber.value);
    }
    if (creditScore.present) {
      map['credit_score'] = Variable<int>(creditScore.value);
    }
    if (walletBalance.present) {
      map['wallet_balance'] = Variable<double>(walletBalance.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileCompanion(')
          ..write('id: $id, ')
          ..write('phoneNumber: $phoneNumber, ')
          ..write('creditScore: $creditScore, ')
          ..write('walletBalance: $walletBalance, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoreCacheTable extends StoreCache
    with TableInfo<$StoreCacheTable, StoreCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoreCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ipAddressMeta = const VerificationMeta(
    'ipAddress',
  );
  @override
  late final GeneratedColumn<String> ipAddress = GeneratedColumn<String>(
    'ip_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isTrustedMeta = const VerificationMeta(
    'isTrusted',
  );
  @override
  late final GeneratedColumn<bool> isTrusted = GeneratedColumn<bool>(
    'is_trusted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_trusted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    ipAddress,
    port,
    lastSeen,
    isTrusted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'store_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoreCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('ip_address')) {
      context.handle(
        _ipAddressMeta,
        ipAddress.isAcceptableOrUnknown(data['ip_address']!, _ipAddressMeta),
      );
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    if (data.containsKey('is_trusted')) {
      context.handle(
        _isTrustedMeta,
        isTrusted.isAcceptableOrUnknown(data['is_trusted']!, _isTrustedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoreCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoreCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ipAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ip_address'],
      ),
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      ),
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen'],
      )!,
      isTrusted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_trusted'],
      )!,
    );
  }

  @override
  $StoreCacheTable createAlias(String alias) {
    return $StoreCacheTable(attachedDatabase, alias);
  }
}

class StoreCacheData extends DataClass implements Insertable<StoreCacheData> {
  final String id;
  final String name;
  final String? ipAddress;
  final int? port;
  final DateTime lastSeen;
  final bool isTrusted;
  const StoreCacheData({
    required this.id,
    required this.name,
    this.ipAddress,
    this.port,
    required this.lastSeen,
    required this.isTrusted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || ipAddress != null) {
      map['ip_address'] = Variable<String>(ipAddress);
    }
    if (!nullToAbsent || port != null) {
      map['port'] = Variable<int>(port);
    }
    map['last_seen'] = Variable<DateTime>(lastSeen);
    map['is_trusted'] = Variable<bool>(isTrusted);
    return map;
  }

  StoreCacheCompanion toCompanion(bool nullToAbsent) {
    return StoreCacheCompanion(
      id: Value(id),
      name: Value(name),
      ipAddress: ipAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(ipAddress),
      port: port == null && nullToAbsent ? const Value.absent() : Value(port),
      lastSeen: Value(lastSeen),
      isTrusted: Value(isTrusted),
    );
  }

  factory StoreCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoreCacheData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      ipAddress: serializer.fromJson<String?>(json['ipAddress']),
      port: serializer.fromJson<int?>(json['port']),
      lastSeen: serializer.fromJson<DateTime>(json['lastSeen']),
      isTrusted: serializer.fromJson<bool>(json['isTrusted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'ipAddress': serializer.toJson<String?>(ipAddress),
      'port': serializer.toJson<int?>(port),
      'lastSeen': serializer.toJson<DateTime>(lastSeen),
      'isTrusted': serializer.toJson<bool>(isTrusted),
    };
  }

  StoreCacheData copyWith({
    String? id,
    String? name,
    Value<String?> ipAddress = const Value.absent(),
    Value<int?> port = const Value.absent(),
    DateTime? lastSeen,
    bool? isTrusted,
  }) => StoreCacheData(
    id: id ?? this.id,
    name: name ?? this.name,
    ipAddress: ipAddress.present ? ipAddress.value : this.ipAddress,
    port: port.present ? port.value : this.port,
    lastSeen: lastSeen ?? this.lastSeen,
    isTrusted: isTrusted ?? this.isTrusted,
  );
  StoreCacheData copyWithCompanion(StoreCacheCompanion data) {
    return StoreCacheData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      ipAddress: data.ipAddress.present ? data.ipAddress.value : this.ipAddress,
      port: data.port.present ? data.port.value : this.port,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      isTrusted: data.isTrusted.present ? data.isTrusted.value : this.isTrusted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoreCacheData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ipAddress: $ipAddress, ')
          ..write('port: $port, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('isTrusted: $isTrusted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, ipAddress, port, lastSeen, isTrusted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoreCacheData &&
          other.id == this.id &&
          other.name == this.name &&
          other.ipAddress == this.ipAddress &&
          other.port == this.port &&
          other.lastSeen == this.lastSeen &&
          other.isTrusted == this.isTrusted);
}

class StoreCacheCompanion extends UpdateCompanion<StoreCacheData> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> ipAddress;
  final Value<int?> port;
  final Value<DateTime> lastSeen;
  final Value<bool> isTrusted;
  final Value<int> rowid;
  const StoreCacheCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.ipAddress = const Value.absent(),
    this.port = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.isTrusted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoreCacheCompanion.insert({
    required String id,
    required String name,
    this.ipAddress = const Value.absent(),
    this.port = const Value.absent(),
    required DateTime lastSeen,
    this.isTrusted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       lastSeen = Value(lastSeen);
  static Insertable<StoreCacheData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? ipAddress,
    Expression<int>? port,
    Expression<DateTime>? lastSeen,
    Expression<bool>? isTrusted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (ipAddress != null) 'ip_address': ipAddress,
      if (port != null) 'port': port,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (isTrusted != null) 'is_trusted': isTrusted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoreCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? ipAddress,
    Value<int?>? port,
    Value<DateTime>? lastSeen,
    Value<bool>? isTrusted,
    Value<int>? rowid,
  }) {
    return StoreCacheCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
      isTrusted: isTrusted ?? this.isTrusted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ipAddress.present) {
      map['ip_address'] = Variable<String>(ipAddress.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (isTrusted.present) {
      map['is_trusted'] = Variable<bool>(isTrusted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoreCacheCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ipAddress: $ipAddress, ')
          ..write('port: $port, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('isTrusted: $isTrusted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VisualCollisionsTable extends VisualCollisions
    with TableInfo<$VisualCollisionsTable, VisualCollision> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisualCollisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _item1IdMeta = const VerificationMeta(
    'item1Id',
  );
  @override
  late final GeneratedColumn<int> item1Id = GeneratedColumn<int>(
    'item1_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _item2IdMeta = const VerificationMeta(
    'item2Id',
  );
  @override
  late final GeneratedColumn<int> item2Id = GeneratedColumn<int>(
    'item2_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _collisionCountMeta = const VerificationMeta(
    'collisionCount',
  );
  @override
  late final GeneratedColumn<int> collisionCount = GeneratedColumn<int>(
    'collision_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastCollisionMeta = const VerificationMeta(
    'lastCollision',
  );
  @override
  late final GeneratedColumn<DateTime> lastCollision =
      GeneratedColumn<DateTime>(
        'last_collision',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    item1Id,
    item2Id,
    collisionCount,
    lastCollision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visual_collisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<VisualCollision> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('item1_id')) {
      context.handle(
        _item1IdMeta,
        item1Id.isAcceptableOrUnknown(data['item1_id']!, _item1IdMeta),
      );
    } else if (isInserting) {
      context.missing(_item1IdMeta);
    }
    if (data.containsKey('item2_id')) {
      context.handle(
        _item2IdMeta,
        item2Id.isAcceptableOrUnknown(data['item2_id']!, _item2IdMeta),
      );
    } else if (isInserting) {
      context.missing(_item2IdMeta);
    }
    if (data.containsKey('collision_count')) {
      context.handle(
        _collisionCountMeta,
        collisionCount.isAcceptableOrUnknown(
          data['collision_count']!,
          _collisionCountMeta,
        ),
      );
    }
    if (data.containsKey('last_collision')) {
      context.handle(
        _lastCollisionMeta,
        lastCollision.isAcceptableOrUnknown(
          data['last_collision']!,
          _lastCollisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastCollisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VisualCollision map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisualCollision(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      item1Id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item1_id'],
      )!,
      item2Id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item2_id'],
      )!,
      collisionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}collision_count'],
      )!,
      lastCollision: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_collision'],
      )!,
    );
  }

  @override
  $VisualCollisionsTable createAlias(String alias) {
    return $VisualCollisionsTable(attachedDatabase, alias);
  }
}

class VisualCollision extends DataClass implements Insertable<VisualCollision> {
  final int id;
  final int item1Id;
  final int item2Id;
  final int collisionCount;
  final DateTime lastCollision;
  const VisualCollision({
    required this.id,
    required this.item1Id,
    required this.item2Id,
    required this.collisionCount,
    required this.lastCollision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['item1_id'] = Variable<int>(item1Id);
    map['item2_id'] = Variable<int>(item2Id);
    map['collision_count'] = Variable<int>(collisionCount);
    map['last_collision'] = Variable<DateTime>(lastCollision);
    return map;
  }

  VisualCollisionsCompanion toCompanion(bool nullToAbsent) {
    return VisualCollisionsCompanion(
      id: Value(id),
      item1Id: Value(item1Id),
      item2Id: Value(item2Id),
      collisionCount: Value(collisionCount),
      lastCollision: Value(lastCollision),
    );
  }

  factory VisualCollision.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VisualCollision(
      id: serializer.fromJson<int>(json['id']),
      item1Id: serializer.fromJson<int>(json['item1Id']),
      item2Id: serializer.fromJson<int>(json['item2Id']),
      collisionCount: serializer.fromJson<int>(json['collisionCount']),
      lastCollision: serializer.fromJson<DateTime>(json['lastCollision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'item1Id': serializer.toJson<int>(item1Id),
      'item2Id': serializer.toJson<int>(item2Id),
      'collisionCount': serializer.toJson<int>(collisionCount),
      'lastCollision': serializer.toJson<DateTime>(lastCollision),
    };
  }

  VisualCollision copyWith({
    int? id,
    int? item1Id,
    int? item2Id,
    int? collisionCount,
    DateTime? lastCollision,
  }) => VisualCollision(
    id: id ?? this.id,
    item1Id: item1Id ?? this.item1Id,
    item2Id: item2Id ?? this.item2Id,
    collisionCount: collisionCount ?? this.collisionCount,
    lastCollision: lastCollision ?? this.lastCollision,
  );
  VisualCollision copyWithCompanion(VisualCollisionsCompanion data) {
    return VisualCollision(
      id: data.id.present ? data.id.value : this.id,
      item1Id: data.item1Id.present ? data.item1Id.value : this.item1Id,
      item2Id: data.item2Id.present ? data.item2Id.value : this.item2Id,
      collisionCount: data.collisionCount.present
          ? data.collisionCount.value
          : this.collisionCount,
      lastCollision: data.lastCollision.present
          ? data.lastCollision.value
          : this.lastCollision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VisualCollision(')
          ..write('id: $id, ')
          ..write('item1Id: $item1Id, ')
          ..write('item2Id: $item2Id, ')
          ..write('collisionCount: $collisionCount, ')
          ..write('lastCollision: $lastCollision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, item1Id, item2Id, collisionCount, lastCollision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisualCollision &&
          other.id == this.id &&
          other.item1Id == this.item1Id &&
          other.item2Id == this.item2Id &&
          other.collisionCount == this.collisionCount &&
          other.lastCollision == this.lastCollision);
}

class VisualCollisionsCompanion extends UpdateCompanion<VisualCollision> {
  final Value<int> id;
  final Value<int> item1Id;
  final Value<int> item2Id;
  final Value<int> collisionCount;
  final Value<DateTime> lastCollision;
  const VisualCollisionsCompanion({
    this.id = const Value.absent(),
    this.item1Id = const Value.absent(),
    this.item2Id = const Value.absent(),
    this.collisionCount = const Value.absent(),
    this.lastCollision = const Value.absent(),
  });
  VisualCollisionsCompanion.insert({
    this.id = const Value.absent(),
    required int item1Id,
    required int item2Id,
    this.collisionCount = const Value.absent(),
    required DateTime lastCollision,
  }) : item1Id = Value(item1Id),
       item2Id = Value(item2Id),
       lastCollision = Value(lastCollision);
  static Insertable<VisualCollision> custom({
    Expression<int>? id,
    Expression<int>? item1Id,
    Expression<int>? item2Id,
    Expression<int>? collisionCount,
    Expression<DateTime>? lastCollision,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (item1Id != null) 'item1_id': item1Id,
      if (item2Id != null) 'item2_id': item2Id,
      if (collisionCount != null) 'collision_count': collisionCount,
      if (lastCollision != null) 'last_collision': lastCollision,
    });
  }

  VisualCollisionsCompanion copyWith({
    Value<int>? id,
    Value<int>? item1Id,
    Value<int>? item2Id,
    Value<int>? collisionCount,
    Value<DateTime>? lastCollision,
  }) {
    return VisualCollisionsCompanion(
      id: id ?? this.id,
      item1Id: item1Id ?? this.item1Id,
      item2Id: item2Id ?? this.item2Id,
      collisionCount: collisionCount ?? this.collisionCount,
      lastCollision: lastCollision ?? this.lastCollision,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (item1Id.present) {
      map['item1_id'] = Variable<int>(item1Id.value);
    }
    if (item2Id.present) {
      map['item2_id'] = Variable<int>(item2Id.value);
    }
    if (collisionCount.present) {
      map['collision_count'] = Variable<int>(collisionCount.value);
    }
    if (lastCollision.present) {
      map['last_collision'] = Variable<DateTime>(lastCollision.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisualCollisionsCompanion(')
          ..write('id: $id, ')
          ..write('item1Id: $item1Id, ')
          ..write('item2Id: $item2Id, ')
          ..write('collisionCount: $collisionCount, ')
          ..write('lastCollision: $lastCollision')
          ..write(')'))
        .toString();
  }
}

class $OrdersTable extends Orders with TableInfo<$OrdersTable, Order> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
    'shop_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalAmountMeta = const VerificationMeta(
    'totalAmount',
  );
  @override
  late final GeneratedColumn<double> totalAmount = GeneratedColumn<double>(
    'total_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemsJsonMeta = const VerificationMeta(
    'itemsJson',
  );
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
    'items_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moduleMeta = const VerificationMeta('module');
  @override
  late final GeneratedColumn<String> module = GeneratedColumn<String>(
    'module',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shopId,
    totalAmount,
    status,
    createdAt,
    itemsJson,
    module,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Order> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shop_id')) {
      context.handle(
        _shopIdMeta,
        shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('total_amount')) {
      context.handle(
        _totalAmountMeta,
        totalAmount.isAcceptableOrUnknown(
          data['total_amount']!,
          _totalAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalAmountMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('items_json')) {
      context.handle(
        _itemsJsonMeta,
        itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsJsonMeta);
    }
    if (data.containsKey('module')) {
      context.handle(
        _moduleMeta,
        module.isAcceptableOrUnknown(data['module']!, _moduleMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Order map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Order(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      shopId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shop_id'],
      )!,
      totalAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_amount'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      itemsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items_json'],
      )!,
      module: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module'],
      ),
    );
  }

  @override
  $OrdersTable createAlias(String alias) {
    return $OrdersTable(attachedDatabase, alias);
  }
}

class Order extends DataClass implements Insertable<Order> {
  final String id;
  final String shopId;
  final double totalAmount;
  final int status;
  final DateTime createdAt;
  final String itemsJson;
  final String? module;
  const Order({
    required this.id,
    required this.shopId,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    required this.itemsJson,
    this.module,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['shop_id'] = Variable<String>(shopId);
    map['total_amount'] = Variable<double>(totalAmount);
    map['status'] = Variable<int>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['items_json'] = Variable<String>(itemsJson);
    if (!nullToAbsent || module != null) {
      map['module'] = Variable<String>(module);
    }
    return map;
  }

  OrdersCompanion toCompanion(bool nullToAbsent) {
    return OrdersCompanion(
      id: Value(id),
      shopId: Value(shopId),
      totalAmount: Value(totalAmount),
      status: Value(status),
      createdAt: Value(createdAt),
      itemsJson: Value(itemsJson),
      module: module == null && nullToAbsent
          ? const Value.absent()
          : Value(module),
    );
  }

  factory Order.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Order(
      id: serializer.fromJson<String>(json['id']),
      shopId: serializer.fromJson<String>(json['shopId']),
      totalAmount: serializer.fromJson<double>(json['totalAmount']),
      status: serializer.fromJson<int>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      module: serializer.fromJson<String?>(json['module']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'shopId': serializer.toJson<String>(shopId),
      'totalAmount': serializer.toJson<double>(totalAmount),
      'status': serializer.toJson<int>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'module': serializer.toJson<String?>(module),
    };
  }

  Order copyWith({
    String? id,
    String? shopId,
    double? totalAmount,
    int? status,
    DateTime? createdAt,
    String? itemsJson,
    Value<String?> module = const Value.absent(),
  }) => Order(
    id: id ?? this.id,
    shopId: shopId ?? this.shopId,
    totalAmount: totalAmount ?? this.totalAmount,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    itemsJson: itemsJson ?? this.itemsJson,
    module: module.present ? module.value : this.module,
  );
  Order copyWithCompanion(OrdersCompanion data) {
    return Order(
      id: data.id.present ? data.id.value : this.id,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      totalAmount: data.totalAmount.present
          ? data.totalAmount.value
          : this.totalAmount,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      module: data.module.present ? data.module.value : this.module,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Order(')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('module: $module')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    shopId,
    totalAmount,
    status,
    createdAt,
    itemsJson,
    module,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Order &&
          other.id == this.id &&
          other.shopId == this.shopId &&
          other.totalAmount == this.totalAmount &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.itemsJson == this.itemsJson &&
          other.module == this.module);
}

class OrdersCompanion extends UpdateCompanion<Order> {
  final Value<String> id;
  final Value<String> shopId;
  final Value<double> totalAmount;
  final Value<int> status;
  final Value<DateTime> createdAt;
  final Value<String> itemsJson;
  final Value<String?> module;
  final Value<int> rowid;
  const OrdersCompanion({
    this.id = const Value.absent(),
    this.shopId = const Value.absent(),
    this.totalAmount = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.module = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrdersCompanion.insert({
    required String id,
    required String shopId,
    required double totalAmount,
    required int status,
    required DateTime createdAt,
    required String itemsJson,
    this.module = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       shopId = Value(shopId),
       totalAmount = Value(totalAmount),
       status = Value(status),
       createdAt = Value(createdAt),
       itemsJson = Value(itemsJson);
  static Insertable<Order> custom({
    Expression<String>? id,
    Expression<String>? shopId,
    Expression<double>? totalAmount,
    Expression<int>? status,
    Expression<DateTime>? createdAt,
    Expression<String>? itemsJson,
    Expression<String>? module,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shopId != null) 'shop_id': shopId,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (itemsJson != null) 'items_json': itemsJson,
      if (module != null) 'module': module,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrdersCompanion copyWith({
    Value<String>? id,
    Value<String>? shopId,
    Value<double>? totalAmount,
    Value<int>? status,
    Value<DateTime>? createdAt,
    Value<String>? itemsJson,
    Value<String?>? module,
    Value<int>? rowid,
  }) {
    return OrdersCompanion(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      itemsJson: itemsJson ?? this.itemsJson,
      module: module ?? this.module,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (totalAmount.present) {
      map['total_amount'] = Variable<double>(totalAmount.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (module.present) {
      map['module'] = Variable<String>(module.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrdersCompanion(')
          ..write('id: $id, ')
          ..write('shopId: $shopId, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('module: $module, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ReceiptsTable receipts = $ReceiptsTable(this);
  late final $UserProfileTable userProfile = $UserProfileTable(this);
  late final $StoreCacheTable storeCache = $StoreCacheTable(this);
  late final $VisualCollisionsTable visualCollisions = $VisualCollisionsTable(
    this,
  );
  late final $OrdersTable orders = $OrdersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    receipts,
    userProfile,
    storeCache,
    visualCollisions,
    orders,
  ];
}

typedef $$ReceiptsTableCreateCompanionBuilder =
    ReceiptsCompanion Function({
      required String id,
      required String sellerId,
      required String sellerName,
      required String itemsJson,
      required int totalAmount,
      required DateTime timestamp,
      required String signature,
      Value<bool> isSynced,
      Value<String?> module,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$ReceiptsTableUpdateCompanionBuilder =
    ReceiptsCompanion Function({
      Value<String> id,
      Value<String> sellerId,
      Value<String> sellerName,
      Value<String> itemsJson,
      Value<int> totalAmount,
      Value<DateTime> timestamp,
      Value<String> signature,
      Value<bool> isSynced,
      Value<String?> module,
      Value<String?> notes,
      Value<int> rowid,
    });

class $$ReceiptsTableFilterComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sellerId => $composableBuilder(
    column: $table.sellerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sellerName => $composableBuilder(
    column: $table.sellerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReceiptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sellerId => $composableBuilder(
    column: $table.sellerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sellerName => $composableBuilder(
    column: $table.sellerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReceiptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sellerId =>
      $composableBuilder(column: $table.sellerId, builder: (column) => column);

  GeneratedColumn<String> get sellerName => $composableBuilder(
    column: $table.sellerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<int> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<String> get module =>
      $composableBuilder(column: $table.module, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$ReceiptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReceiptsTable,
          Receipt,
          $$ReceiptsTableFilterComposer,
          $$ReceiptsTableOrderingComposer,
          $$ReceiptsTableAnnotationComposer,
          $$ReceiptsTableCreateCompanionBuilder,
          $$ReceiptsTableUpdateCompanionBuilder,
          (Receipt, BaseReferences<_$AppDatabase, $ReceiptsTable, Receipt>),
          Receipt,
          PrefetchHooks Function()
        > {
  $$ReceiptsTableTableManager(_$AppDatabase db, $ReceiptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReceiptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sellerId = const Value.absent(),
                Value<String> sellerName = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                Value<int> totalAmount = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReceiptsCompanion(
                id: id,
                sellerId: sellerId,
                sellerName: sellerName,
                itemsJson: itemsJson,
                totalAmount: totalAmount,
                timestamp: timestamp,
                signature: signature,
                isSynced: isSynced,
                module: module,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sellerId,
                required String sellerName,
                required String itemsJson,
                required int totalAmount,
                required DateTime timestamp,
                required String signature,
                Value<bool> isSynced = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReceiptsCompanion.insert(
                id: id,
                sellerId: sellerId,
                sellerName: sellerName,
                itemsJson: itemsJson,
                totalAmount: totalAmount,
                timestamp: timestamp,
                signature: signature,
                isSynced: isSynced,
                module: module,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReceiptsTable,
      Receipt,
      $$ReceiptsTableFilterComposer,
      $$ReceiptsTableOrderingComposer,
      $$ReceiptsTableAnnotationComposer,
      $$ReceiptsTableCreateCompanionBuilder,
      $$ReceiptsTableUpdateCompanionBuilder,
      (Receipt, BaseReferences<_$AppDatabase, $ReceiptsTable, Receipt>),
      Receipt,
      PrefetchHooks Function()
    >;
typedef $$UserProfileTableCreateCompanionBuilder =
    UserProfileCompanion Function({
      required String id,
      required String phoneNumber,
      Value<int?> creditScore,
      Value<double> walletBalance,
      Value<DateTime?> lastUpdated,
      Value<int> rowid,
    });
typedef $$UserProfileTableUpdateCompanionBuilder =
    UserProfileCompanion Function({
      Value<String> id,
      Value<String> phoneNumber,
      Value<int?> creditScore,
      Value<double> walletBalance,
      Value<DateTime?> lastUpdated,
      Value<int> rowid,
    });

class $$UserProfileTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phoneNumber => $composableBuilder(
    column: $table.phoneNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditScore => $composableBuilder(
    column: $table.creditScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get walletBalance => $composableBuilder(
    column: $table.walletBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfileTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phoneNumber => $composableBuilder(
    column: $table.phoneNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditScore => $composableBuilder(
    column: $table.creditScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get walletBalance => $composableBuilder(
    column: $table.walletBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfileTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get phoneNumber => $composableBuilder(
    column: $table.phoneNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get creditScore => $composableBuilder(
    column: $table.creditScore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get walletBalance => $composableBuilder(
    column: $table.walletBalance,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$UserProfileTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfileTable,
          UserProfileData,
          $$UserProfileTableFilterComposer,
          $$UserProfileTableOrderingComposer,
          $$UserProfileTableAnnotationComposer,
          $$UserProfileTableCreateCompanionBuilder,
          $$UserProfileTableUpdateCompanionBuilder,
          (
            UserProfileData,
            BaseReferences<_$AppDatabase, $UserProfileTable, UserProfileData>,
          ),
          UserProfileData,
          PrefetchHooks Function()
        > {
  $$UserProfileTableTableManager(_$AppDatabase db, $UserProfileTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> phoneNumber = const Value.absent(),
                Value<int?> creditScore = const Value.absent(),
                Value<double> walletBalance = const Value.absent(),
                Value<DateTime?> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfileCompanion(
                id: id,
                phoneNumber: phoneNumber,
                creditScore: creditScore,
                walletBalance: walletBalance,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String phoneNumber,
                Value<int?> creditScore = const Value.absent(),
                Value<double> walletBalance = const Value.absent(),
                Value<DateTime?> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfileCompanion.insert(
                id: id,
                phoneNumber: phoneNumber,
                creditScore: creditScore,
                walletBalance: walletBalance,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfileTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfileTable,
      UserProfileData,
      $$UserProfileTableFilterComposer,
      $$UserProfileTableOrderingComposer,
      $$UserProfileTableAnnotationComposer,
      $$UserProfileTableCreateCompanionBuilder,
      $$UserProfileTableUpdateCompanionBuilder,
      (
        UserProfileData,
        BaseReferences<_$AppDatabase, $UserProfileTable, UserProfileData>,
      ),
      UserProfileData,
      PrefetchHooks Function()
    >;
typedef $$StoreCacheTableCreateCompanionBuilder =
    StoreCacheCompanion Function({
      required String id,
      required String name,
      Value<String?> ipAddress,
      Value<int?> port,
      required DateTime lastSeen,
      Value<bool> isTrusted,
      Value<int> rowid,
    });
typedef $$StoreCacheTableUpdateCompanionBuilder =
    StoreCacheCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> ipAddress,
      Value<int?> port,
      Value<DateTime> lastSeen,
      Value<bool> isTrusted,
      Value<int> rowid,
    });

class $$StoreCacheTableFilterComposer
    extends Composer<_$AppDatabase, $StoreCacheTable> {
  $$StoreCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ipAddress => $composableBuilder(
    column: $table.ipAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isTrusted => $composableBuilder(
    column: $table.isTrusted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoreCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $StoreCacheTable> {
  $$StoreCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ipAddress => $composableBuilder(
    column: $table.ipAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isTrusted => $composableBuilder(
    column: $table.isTrusted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoreCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoreCacheTable> {
  $$StoreCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get ipAddress =>
      $composableBuilder(column: $table.ipAddress, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<bool> get isTrusted =>
      $composableBuilder(column: $table.isTrusted, builder: (column) => column);
}

class $$StoreCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoreCacheTable,
          StoreCacheData,
          $$StoreCacheTableFilterComposer,
          $$StoreCacheTableOrderingComposer,
          $$StoreCacheTableAnnotationComposer,
          $$StoreCacheTableCreateCompanionBuilder,
          $$StoreCacheTableUpdateCompanionBuilder,
          (
            StoreCacheData,
            BaseReferences<_$AppDatabase, $StoreCacheTable, StoreCacheData>,
          ),
          StoreCacheData,
          PrefetchHooks Function()
        > {
  $$StoreCacheTableTableManager(_$AppDatabase db, $StoreCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoreCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoreCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoreCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> ipAddress = const Value.absent(),
                Value<int?> port = const Value.absent(),
                Value<DateTime> lastSeen = const Value.absent(),
                Value<bool> isTrusted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoreCacheCompanion(
                id: id,
                name: name,
                ipAddress: ipAddress,
                port: port,
                lastSeen: lastSeen,
                isTrusted: isTrusted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> ipAddress = const Value.absent(),
                Value<int?> port = const Value.absent(),
                required DateTime lastSeen,
                Value<bool> isTrusted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoreCacheCompanion.insert(
                id: id,
                name: name,
                ipAddress: ipAddress,
                port: port,
                lastSeen: lastSeen,
                isTrusted: isTrusted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoreCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoreCacheTable,
      StoreCacheData,
      $$StoreCacheTableFilterComposer,
      $$StoreCacheTableOrderingComposer,
      $$StoreCacheTableAnnotationComposer,
      $$StoreCacheTableCreateCompanionBuilder,
      $$StoreCacheTableUpdateCompanionBuilder,
      (
        StoreCacheData,
        BaseReferences<_$AppDatabase, $StoreCacheTable, StoreCacheData>,
      ),
      StoreCacheData,
      PrefetchHooks Function()
    >;
typedef $$VisualCollisionsTableCreateCompanionBuilder =
    VisualCollisionsCompanion Function({
      Value<int> id,
      required int item1Id,
      required int item2Id,
      Value<int> collisionCount,
      required DateTime lastCollision,
    });
typedef $$VisualCollisionsTableUpdateCompanionBuilder =
    VisualCollisionsCompanion Function({
      Value<int> id,
      Value<int> item1Id,
      Value<int> item2Id,
      Value<int> collisionCount,
      Value<DateTime> lastCollision,
    });

class $$VisualCollisionsTableFilterComposer
    extends Composer<_$AppDatabase, $VisualCollisionsTable> {
  $$VisualCollisionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get item1Id => $composableBuilder(
    column: $table.item1Id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get item2Id => $composableBuilder(
    column: $table.item2Id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get collisionCount => $composableBuilder(
    column: $table.collisionCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCollision => $composableBuilder(
    column: $table.lastCollision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VisualCollisionsTableOrderingComposer
    extends Composer<_$AppDatabase, $VisualCollisionsTable> {
  $$VisualCollisionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get item1Id => $composableBuilder(
    column: $table.item1Id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get item2Id => $composableBuilder(
    column: $table.item2Id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get collisionCount => $composableBuilder(
    column: $table.collisionCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCollision => $composableBuilder(
    column: $table.lastCollision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VisualCollisionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VisualCollisionsTable> {
  $$VisualCollisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get item1Id =>
      $composableBuilder(column: $table.item1Id, builder: (column) => column);

  GeneratedColumn<int> get item2Id =>
      $composableBuilder(column: $table.item2Id, builder: (column) => column);

  GeneratedColumn<int> get collisionCount => $composableBuilder(
    column: $table.collisionCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastCollision => $composableBuilder(
    column: $table.lastCollision,
    builder: (column) => column,
  );
}

class $$VisualCollisionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VisualCollisionsTable,
          VisualCollision,
          $$VisualCollisionsTableFilterComposer,
          $$VisualCollisionsTableOrderingComposer,
          $$VisualCollisionsTableAnnotationComposer,
          $$VisualCollisionsTableCreateCompanionBuilder,
          $$VisualCollisionsTableUpdateCompanionBuilder,
          (
            VisualCollision,
            BaseReferences<
              _$AppDatabase,
              $VisualCollisionsTable,
              VisualCollision
            >,
          ),
          VisualCollision,
          PrefetchHooks Function()
        > {
  $$VisualCollisionsTableTableManager(
    _$AppDatabase db,
    $VisualCollisionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisualCollisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisualCollisionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisualCollisionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> item1Id = const Value.absent(),
                Value<int> item2Id = const Value.absent(),
                Value<int> collisionCount = const Value.absent(),
                Value<DateTime> lastCollision = const Value.absent(),
              }) => VisualCollisionsCompanion(
                id: id,
                item1Id: item1Id,
                item2Id: item2Id,
                collisionCount: collisionCount,
                lastCollision: lastCollision,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int item1Id,
                required int item2Id,
                Value<int> collisionCount = const Value.absent(),
                required DateTime lastCollision,
              }) => VisualCollisionsCompanion.insert(
                id: id,
                item1Id: item1Id,
                item2Id: item2Id,
                collisionCount: collisionCount,
                lastCollision: lastCollision,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VisualCollisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VisualCollisionsTable,
      VisualCollision,
      $$VisualCollisionsTableFilterComposer,
      $$VisualCollisionsTableOrderingComposer,
      $$VisualCollisionsTableAnnotationComposer,
      $$VisualCollisionsTableCreateCompanionBuilder,
      $$VisualCollisionsTableUpdateCompanionBuilder,
      (
        VisualCollision,
        BaseReferences<_$AppDatabase, $VisualCollisionsTable, VisualCollision>,
      ),
      VisualCollision,
      PrefetchHooks Function()
    >;
typedef $$OrdersTableCreateCompanionBuilder =
    OrdersCompanion Function({
      required String id,
      required String shopId,
      required double totalAmount,
      required int status,
      required DateTime createdAt,
      required String itemsJson,
      Value<String?> module,
      Value<int> rowid,
    });
typedef $$OrdersTableUpdateCompanionBuilder =
    OrdersCompanion Function({
      Value<String> id,
      Value<String> shopId,
      Value<double> totalAmount,
      Value<int> status,
      Value<DateTime> createdAt,
      Value<String> itemsJson,
      Value<String?> module,
      Value<int> rowid,
    });

class $$OrdersTableFilterComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shopId => $composableBuilder(
    column: $table.shopId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shopId => $composableBuilder(
    column: $table.shopId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get module => $composableBuilder(
    column: $table.module,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<String> get module =>
      $composableBuilder(column: $table.module, builder: (column) => column);
}

class $$OrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrdersTable,
          Order,
          $$OrdersTableFilterComposer,
          $$OrdersTableOrderingComposer,
          $$OrdersTableAnnotationComposer,
          $$OrdersTableCreateCompanionBuilder,
          $$OrdersTableUpdateCompanionBuilder,
          (Order, BaseReferences<_$AppDatabase, $OrdersTable, Order>),
          Order,
          PrefetchHooks Function()
        > {
  $$OrdersTableTableManager(_$AppDatabase db, $OrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> shopId = const Value.absent(),
                Value<double> totalAmount = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                Value<String?> module = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrdersCompanion(
                id: id,
                shopId: shopId,
                totalAmount: totalAmount,
                status: status,
                createdAt: createdAt,
                itemsJson: itemsJson,
                module: module,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String shopId,
                required double totalAmount,
                required int status,
                required DateTime createdAt,
                required String itemsJson,
                Value<String?> module = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrdersCompanion.insert(
                id: id,
                shopId: shopId,
                totalAmount: totalAmount,
                status: status,
                createdAt: createdAt,
                itemsJson: itemsJson,
                module: module,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrdersTable,
      Order,
      $$OrdersTableFilterComposer,
      $$OrdersTableOrderingComposer,
      $$OrdersTableAnnotationComposer,
      $$OrdersTableCreateCompanionBuilder,
      $$OrdersTableUpdateCompanionBuilder,
      (Order, BaseReferences<_$AppDatabase, $OrdersTable, Order>),
      Order,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ReceiptsTableTableManager get receipts =>
      $$ReceiptsTableTableManager(_db, _db.receipts);
  $$UserProfileTableTableManager get userProfile =>
      $$UserProfileTableTableManager(_db, _db.userProfile);
  $$StoreCacheTableTableManager get storeCache =>
      $$StoreCacheTableTableManager(_db, _db.storeCache);
  $$VisualCollisionsTableTableManager get visualCollisions =>
      $$VisualCollisionsTableTableManager(_db, _db.visualCollisions);
  $$OrdersTableTableManager get orders =>
      $$OrdersTableTableManager(_db, _db.orders);
}
