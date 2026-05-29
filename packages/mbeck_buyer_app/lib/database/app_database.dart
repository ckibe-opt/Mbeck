import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// Table for storing Receipts (Validation of purchases)
class Receipts extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get sellerId => text()();
  TextColumn get sellerName => text()();
  TextColumn get itemsJson => text()(); // JSON blob of items
  IntColumn get totalAmount => integer()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get signature => text()(); // Ed25519 signature
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get module => text().nullable()(); // e.g. 'retail', 'restaurant', 'services'
  TextColumn get notes => text().nullable()(); // Transaction notes

  @override
  Set<Column> get primaryKey => {id};
}

// Table for User Profile & Credit Score
class UserProfile extends Table {
  TextColumn get id => text()();
  TextColumn get phoneNumber => text()();
  IntColumn get creditScore => integer().nullable()();
  RealColumn get walletBalance => real().withDefault(const Constant(0.0))();
  DateTimeColumn get lastUpdated => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Cache for nearby stores found via mDNS or Cloud
class StoreCache extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get ipAddress => text().nullable()(); // Local IP for p2p
  IntColumn get port => integer().nullable()();
  DateTimeColumn get lastSeen => dateTime()();
  BoolColumn get isTrusted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// Table for visual collisions to track frequent mismatches
class VisualCollisions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get item1Id => integer()();
  IntColumn get item2Id => integer()();
  IntColumn get collisionCount => integer().withDefault(const Constant(1))();
  DateTimeColumn get lastCollision => dateTime()();
}

// Table for storing Offline Orders (Pending Sync)
class Orders extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get shopId => text()();
  RealColumn get totalAmount => real()();
  IntColumn get status => integer()(); // 0=PendingSync, 1=Synced, 2=Completed
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get itemsJson => text()(); // JSON blob of items
  TextColumn get module => text().nullable()(); // e.g. 'retail', 'restaurant'

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Receipts, UserProfile, StoreCache, VisualCollisions, Orders])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  // Named constructor for testing
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 5;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'mbeck_buyer_db');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // Migration from v1 to v2: Add VisualCollisions table
        await m.createTable(visualCollisions);
      }
      if (from < 3) {
        // Migration from v2 to v3: Add Orders table
        await m.createTable(orders);
      }
      if (from < 4) {
        // Migration from v3 to v4: Add module and notes columns to Receipts
        await customStatement('ALTER TABLE receipts ADD COLUMN module TEXT');
        await customStatement('ALTER TABLE receipts ADD COLUMN notes TEXT');
      }
      if (from < 5) {
        // Migration from v4 to v5: Add module column to Orders
        await customStatement('ALTER TABLE orders ADD COLUMN module TEXT');
      }
    },
  );
}
