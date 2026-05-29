import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Database service with multi-shop context support
/// 
/// Tracks the currently active shop for scoped queries.
/// The Buyer app may interact with multiple shops simultaneously.
class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  AppDatabase? _database;
  
  /// Currently active shop ID for scoped queries
  String? _currentShopId;
  
  /// Get/set the current shop context
  String? get currentShopId => _currentShopId;
  set currentShopId(String? shopId) {
    if (_currentShopId != shopId) {
      _currentShopId = shopId;
      debugPrint('📂 Database context switched to shop: $shopId');
    }
  }

  DatabaseService._init();

  /// For testing: Inject a mock or in-memory database
  @visibleForTesting
  void testSetDb(AppDatabase db) {
    print('DEBUG: Setting test DB');
    _database = db;
  }

  AppDatabase get db {
    if (_database == null) {
      print('DEBUG: Initializing real AppDatabase');
      _database = AppDatabase();
    }
    return _database!;
  }

  /// Get receipts for the current shop context only
  Future<List<Receipt>> getReceiptsForCurrentShop() async {
    if (_currentShopId == null) {
      return [];
    }
    return await (db.select(db.receipts)
      ..where((t) => t.sellerId.equals(_currentShopId!))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
      ..limit(50))
      .get();
  }

  /// Get receipts for a specific shop
  Future<List<Receipt>> getReceiptsForShop(String shopId) async {
    return await (db.select(db.receipts)
      ..where((t) => t.sellerId.equals(shopId))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
      ..limit(50))
      .get();
  }

  /// Get cached store by ID
  Future<StoreCacheData?> getStoreFromCache(String storeId) async {
    return await (db.select(db.storeCache)
      ..where((t) => t.id.equals(storeId)))
      .getSingleOrNull();
  }

  /// Update or insert store in cache
  Future<void> cacheStore({
    required String id,
    required String name,
    String? ipAddress,
    int? port,
  }) async {
    await db.into(db.storeCache).insertOnConflictUpdate(
      StoreCacheCompanion.insert(
        id: id,
        name: name,
        ipAddress: Value(ipAddress),
        port: Value(port),
        lastSeen: DateTime.now(),
      ),
    );
    debugPrint('💾 Store cached: $name');
  }

  /// Get all cached stores sorted by last seen
  Future<List<StoreCacheData>> getCachedStores() async {
    return await (db.select(db.storeCache)
      ..orderBy([(t) => OrderingTerm.desc(t.lastSeen)]))
      .get();
  }

  /// Mark a store as trusted
  Future<void> markStoreTrusted(String storeId, bool trusted) async {
    await (db.update(db.storeCache)
      ..where((t) => t.id.equals(storeId)))
      .write(StoreCacheCompanion(isTrusted: Value(trusted)));
  }

  /// Get total purchase amount for a specific shop (for loyalty tracking)
  Future<int> getTotalSpentAtShop(String shopId) async {
    final receipts = await getReceiptsForShop(shopId);
    return receipts.fold<int>(0, (sum, r) => sum + r.totalAmount);
  }

  /// Get number of purchases at a specific shop
  Future<int> getPurchaseCountAtShop(String shopId) async {
    final receipts = await getReceiptsForShop(shopId);
    return receipts.length;
  }

  /// Clear context when switching out of a shop
  void clearContext() {
    _currentShopId = null;
    debugPrint('📂 Database context cleared');
  }
}
