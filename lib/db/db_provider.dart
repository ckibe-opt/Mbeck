import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:sqflite/sqflite.dart' as sqflite_base;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import '../services/security_service.dart';
import 'package:uuid/uuid.dart';

class DbProvider {
  static sqlcipher.Database? _db;
  static Future<sqlcipher.Database>? _initFuture;
  static bool _isReadOnly = false;
  static String? _currentShopId;
  static const String _dbNameRaw = 'shop_database_v27.db';
  static const int _version = 34;

  static Future<sqlcipher.Database> get db async {
    if (_db != null) return _db!;
    return _initFuture ??= init(databaseName: null);
  }

  static Future<sqlcipher.Database> init({String? databaseName}) async {
    if (_db != null) return _db!;
    if (_initFuture != null) return _initFuture!;

    final completer = Completer<sqlcipher.Database>();
    _initFuture = completer.future;

    try {
      final database = await _initInternal(databaseName);
      _db = database;
      completer.complete(database);
      return database;
    } catch (e) {
      _initFuture = null;
      completer.completeError(e);
      rethrow;
    }
  }

  static Future<sqlcipher.Database> _initInternal(String? databaseName) async {

    // Attack Strategy: Initialize FFI for Desktop
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      ffi.sqfliteFfiInit();
      sqflite_base.databaseFactory = ffi.databaseFactoryFfi;
    }

    final path = (databaseName == sqlcipher.inMemoryDatabasePath)
        ? sqlcipher.inMemoryDatabasePath
        : ((Platform.isWindows || Platform.isLinux)
            ? join(Directory.current.path, databaseName ?? 'shop_database_live.db')
            : join(await sqlcipher.getDatabasesPath(), databaseName ?? 'shop_database_live.db'));

    final dbKey = await SecurityService().getDatabaseKey();
    final skipEncryption = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    
    sqlcipher.Database? database;
    bool isNewDb = false;
    
    Future<void> onCreate(dynamic db, int version) async {
      isNewDb = true;
      await _createTables(db);
      await _createTransactionItemsTable(db);
      await _ensureShopsTable(db);
    }

    Future<void> onUpgrade(dynamic db, int oldVersion, int newVersion) async {
      print("📊 Database upgrade: $oldVersion → $newVersion");
      if (oldVersion < 14) {
        await _migrateToV14(db);
      }
      await _safeAddColumn(db, 'inventory', 'visual_vector', 'TEXT');
      await _safeAddColumn(db, 'inventory', 'specification', 'TEXT');
      await _safeAddColumn(db, 'inventory', 'barcode', 'TEXT');
      await _safeAddColumn(db, 'txn', 'receiptSignature', 'TEXT');
      
      if (oldVersion < 20) {
         await _ensureShopsTable(db);
      }
      if (oldVersion < 21) {
         await _ensureModuleTables(db);
      }
      
      if (oldVersion < 22) {
         // Add cloud_id to all syncable tables
         await _safeAddColumn(db, 'restaurant_menu', 'cloud_id', 'TEXT');
         await _safeAddColumn(db, 'restaurant_orders', 'cloud_id', 'TEXT');
         await _safeAddColumn(db, 'services_catalog', 'cloud_id', 'TEXT');
         await _safeAddColumn(db, 'services_bookings', 'cloud_id', 'TEXT');
         await _safeAddColumn(db, 'topics', 'cloud_id', 'TEXT'); // If exists
         await _safeAddColumn(db, 'inventory', 'cloud_id', 'TEXT');
         await _safeAddColumn(db, 'txn', 'cloud_id', 'TEXT');
         
         // Backfill UUIDs for existing records
         try {
            final tablesRaw = ['restaurant_menu', 'restaurant_orders', 'services_catalog', 'services_bookings', 'inventory', 'txn'];
            for (final table in tablesRaw) {
               // Check if table exists
               final check = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='$table'");
               if (check.isNotEmpty) {
                  final rows = await db.rawQuery('SELECT id FROM $table WHERE cloud_id IS NULL');
                  for (final row in rows) {
                     // Generate a REAL UUID for Supabase compatibility
                     final uuid = const Uuid().v4();
                     await db.execute('UPDATE $table SET cloud_id = ? WHERE id = ?', [uuid, row['id']]);
                  }
               }
            }
         } catch (e) {
            print('⚠️ Error during migration v22 (cloud_id backfill): $e');
         }
      }

      if (oldVersion < 23) {
        await _migrateToV23_moduleIsolation(db);
      }

      if (oldVersion < 24) {
        await _migrateToV24_servicesActiveColumn(db);
      }

      if (oldVersion < 25) {
        // V25: Add item_name column to transaction_items so non-retail modules
        // (restaurant, services, etc.) can store item display names without
        // relying on a JOIN to the retail inventory table — fixes profit/history
        // data contamination when multiple modules are active on one device.
        await _safeAddColumn(db, 'transaction_items', 'item_name', 'TEXT');
      }

      if (oldVersion < 26) {
        // V26: Lodging flexible billing — weekly & monthly rate columns on room
        // types, and billing_unit column on reservations for receipt display.
        await _safeAddColumn(db, 'lodging_room_types', 'rate_per_week', 'REAL');
        await _safeAddColumn(db, 'lodging_room_types', 'rate_per_month', 'REAL');
        await _safeAddColumn(db, 'lodging_reservations', 'billing_unit', "TEXT DEFAULT 'night'");
      }
      if (oldVersion < 27) {
        // v27: Handled through _runModuleMigrations natively
      }

      if (oldVersion < 28) {
        await _migrateToV28_restaurantInventory(db);
      }

      if (oldVersion < 29) {
        await _migrateToV29_lodgingEnterprise(db);
      }
      
      if (oldVersion < 30) {
        await _migrateToV30_entertainmentEnterprise(db);
      }
      
      if (oldVersion < 31) {
        await _migrateToV31_servicesEnterprise(db);
      }
      
      if (oldVersion < 32) {
        await _migrateToV32_paymentRef(db);
      }

      if (oldVersion < 33) {
        await _migrateToV33_restaurantStaffTracking(db);
      }
      
      if (oldVersion < 34) {
        await _migrateToV34_publishFlags(db);
      }
    }

    // Performance Optimization: Check if the database is already unencrypted SQLite.
    // SQLCipher decryption failures consume massive CPU and lock the JNI thread for 1-2s.
    bool isPlainSqlite = false;
    try {
      final dbFile = File(path);
      if (await dbFile.exists()) {
        final f = await dbFile.open(mode: FileMode.read);
        final header = await f.read(16);
        await f.close();
        final headerString = String.fromCharCodes(header);
        if (headerString.startsWith('SQLite format 3')) {
          isPlainSqlite = true;
          debugPrint("⚡ Detected plain unencrypted SQLite header. Bypassing SQLCipher check.");
        }
      }
    } catch (e) {
      debugPrint("⚠️ Could not read DB header: $e");
    }

    try {
      if (skipEncryption || isPlainSqlite) {
        database = await sqflite_base.openDatabase(
          path,
          version: _version,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON;');
          },
          onCreate: onCreate,
          onUpgrade: onUpgrade,
        );
      } else {
        database = await sqlcipher.openDatabase(
          path,
          password: dbKey,
          version: _version,  // Up to date version
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON;');
          },
          onCreate: onCreate,
          onUpgrade: onUpgrade,
        );
      }
    } catch (e) {
      debugPrint("⚠️ Failed to open database with encryption properties: $e");
      try {
        // Fallback 1: It might be a plain unencrypted database from an older app version
        database = await sqflite_base.openDatabase(
          path,
          version: _version,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON;');
          },
          onCreate: onCreate,
          onUpgrade: onUpgrade,
        );
        debugPrint("✅ Success: Opened database as plain unencrypted SQLite.");
      } catch (e2) {
        debugPrint("❌ Critical error: Could not open database as plain SQLite either: $e2");
        
        // Fallback 2: The database is either corrupted or the encryption key is permanently lost.
        // We must move it aside to prevent the app from being permanently bricked.
        try {
          final file = File(path);
          if (await file.exists()) {
            final corruptedPath = "${path}_corrupted_${DateTime.now().millisecondsSinceEpoch}";
            await file.rename(corruptedPath);
            debugPrint("♻️ Renamed unreadable database to $corruptedPath.");
          }
          
          debugPrint("✨ Creating a fresh encrypted database...");
          database = await sqlcipher.openDatabase(
            path,
            password: dbKey,
            version: 33,
            onConfigure: (db) async {
              await db.execute('PRAGMA foreign_keys = ON;');
            },
            onCreate: onCreate,
            onUpgrade: onUpgrade,
          );
        } catch (e3) {
          debugPrint("💀 Fatal error recreating fresh database: $e3");
          rethrow;
        }
      }
    }

    final String dbIdentifier = databaseName ?? 'shop_database_live.db';
    bool needsSchemaChecks = true;
    if (dbIdentifier != sqlcipher.inMemoryDatabasePath && !isNewDb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastCheckedVer = prefs.getInt('db_schema_checked_version_$dbIdentifier') ?? 0;
        if (lastCheckedVer == _version) {
          // Double check if a vital table exists to handle half-migrated or corrupted database state
          final tablesCheck = await database.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='lodging_rooms'"
          );
          if (tablesCheck.isNotEmpty) {
            needsSchemaChecks = false;
          }
        }
      } catch (e) {
        debugPrint("⚠️ Error reading db schema cache: $e");
      }
    }

    if (needsSchemaChecks) {
      // Run ALL migrations and safety nets BEFORE exposing _db
      // This prevents race conditions where queries run before columns exist
      await _ensureInventoryVectorsTable(database);
      await _ensureVisualCollisionsTable(database);
      await _ensureEventsTable(database);
      await _ensureShopSettingsTable(database);
      await _ensureShopsTable(database);
      await _ensureModuleTables(database);
      await _runModuleMigrations(database);
      await _ensureMessagesTable(database);
      
      await _safeAddColumn(database, 'inventory', 'specification', 'TEXT');
      await _safeAddColumn(database, 'inventory', 'barcode', 'TEXT');
      await _safeAddColumn(database, 'inventory', 'visual_vector', 'TEXT');
      await _safeAddColumn(database, 'inventory', 'variationsJson', 'TEXT');
      
      // Ensure module isolation columns exist (safety net for all db paths)
      await _safeAddColumn(database, 'txn', 'source_module', "TEXT DEFAULT 'retail'");
      await _safeAddColumn(database, 'inventory', 'source_module', "TEXT DEFAULT 'retail'");
      await database.execute('CREATE INDEX IF NOT EXISTS idx_txn_module ON txn(source_module)');
      await database.execute('CREATE INDEX IF NOT EXISTS idx_inventory_module ON inventory(source_module)');
      // V25 safety net: item_name column for non-retail module item display names
      await _safeAddColumn(database, 'transaction_items', 'item_name', 'TEXT');
      // V26 safety net: lodging flexible billing columns
      await _safeAddColumn(database, 'lodging_room_types', 'rate_per_week', 'REAL');
      await _safeAddColumn(database, 'lodging_room_types', 'rate_per_month', 'REAL');
      await _safeAddColumn(database, 'lodging_reservations', 'billing_unit', "TEXT DEFAULT 'night'");
      // V27 safety net: customer_phone on transactions
      await _safeAddColumn(database, 'txn', 'customer_phone', 'TEXT');
      // V32 safety net: payment_ref (M-Pesa code) on transactions and split bills
      await _safeAddColumn(database, 'txn', 'payment_ref', 'TEXT');
      await _safeAddColumn(database, 'restaurant_split_bills', 'payment_ref', 'TEXT');
      // V34 safety net: client_id on txn and restaurant_orders so buyer app can filter
      // its own receipts and active orders without relying on the details text field.
      await _safeAddColumn(database, 'txn', 'client_id', 'TEXT');
      await _safeAddColumn(database, 'restaurant_orders', 'client_id', 'TEXT');
      await database.execute('CREATE INDEX IF NOT EXISTS idx_txn_client ON txn(client_id)');
      // V34b: client_id on lodging and entertainment for buyer booking history
      await _safeAddColumn(database, 'lodging_reservations', 'client_id', 'TEXT');
      await _safeAddColumn(database, 'entertainment_sessions', 'client_id', 'TEXT');
      
      // V36 Online Marketplace Integration
      await _safeAddColumn(database, 'shops', 'is_published_online', 'INTEGER DEFAULT 0');
      await _safeAddColumn(database, 'shops', 'verification_status', "TEXT DEFAULT 'UNVERIFIED'");
      await _safeAddColumn(database, 'shops', 'online_views', 'INTEGER DEFAULT 0');
      
      await _safeAddColumn(database, 'inventory', 'is_published', 'INTEGER DEFAULT 0');
      await _safeAddColumn(database, 'inventory', 'online_views', 'INTEGER DEFAULT 0');
      
      await _safeAddColumn(database, 'restaurant_menu', 'is_published', 'INTEGER DEFAULT 0');
      await _safeAddColumn(database, 'restaurant_menu', 'online_views', 'INTEGER DEFAULT 0');
      
      await _safeAddColumn(database, 'services_catalog', 'is_published', 'INTEGER DEFAULT 0');
      await _safeAddColumn(database, 'services_catalog', 'online_views', 'INTEGER DEFAULT 0');
      
      await _safeAddColumn(database, 'lodging_rooms', 'is_published', 'INTEGER DEFAULT 0');
      await _safeAddColumn(database, 'lodging_rooms', 'online_views', 'INTEGER DEFAULT 0');
      
      await _safeAddColumn(database, 'entertainment_assets', 'is_published', 'INTEGER DEFAULT 0');
      await _safeAddColumn(database, 'entertainment_assets', 'online_views', 'INTEGER DEFAULT 0');

      // v37: Type-level publishing
      await _safeAddColumn(database, 'lodging_room_types', 'is_published', 'INTEGER DEFAULT 0');
      await _safeAddColumn(database, 'entertainment_asset_types', 'is_published', 'INTEGER DEFAULT 0');

      // v38: Cloud<->local id reconciliation. Cloud lodging_reservations.room_id
      // is a UUID; local lodging_reservations.room_id is an INTEGER FK. We mirror
      // the cloud UUID into a separate column so push/pull can round-trip safely
      // without corrupting the local FK.
      await _safeAddColumn(database, 'lodging_reservations', 'room_cloud_id', 'TEXT');

      // Customer ledger for owing/prepaid/pending tracking
      await database.execute('''
        CREATE TABLE IF NOT EXISTS customer_ledger (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER,
          customer_phone TEXT,
          customer_name TEXT,
          type TEXT NOT NULL DEFAULT 'owing',
          amount REAL NOT NULL DEFAULT 0,
          notes TEXT,
          txn_id INTEGER,
          status TEXT NOT NULL DEFAULT 'open',
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          resolved_at INTEGER,
          FOREIGN KEY (customer_id) REFERENCES customer(id),
          FOREIGN KEY (txn_id) REFERENCES txn(id)
        )
      ''');
      await database.execute('CREATE INDEX IF NOT EXISTS idx_ledger_customer ON customer_ledger(customer_phone)');
      await database.execute('CREATE INDEX IF NOT EXISTS idx_ledger_customer_id ON customer_ledger(customer_id)');
      await database.execute('CREATE INDEX IF NOT EXISTS idx_ledger_type ON customer_ledger(type, status)');

      if (dbIdentifier != sqlcipher.inMemoryDatabasePath) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('db_schema_checked_version_$dbIdentifier', _version);
        } catch (e) {
          debugPrint("⚠️ Failed to cache db schema version: $e");
        }
      }
    }

    // Only NOW expose the database — all columns are guaranteed to exist
    return database;
  }
  
  static Future<void> deleteAllData() async {
    final dbClient = await db;
    final tables = await dbClient.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    
    await dbClient.transaction((txn) async {
      for (final table in tables) {
        final tableName = table['name'] as String;
        await txn.delete(tableName);
      }
    });
  }

  static Future<void> _safeAddColumn(dynamic db, String table, String column, String type) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final hasColumn = columns.any((col) => col['name'] == column);

      if (!hasColumn) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
        print("    ✓ Added column '$column' to '$table'");
      }
    } catch (e) {
      print("    ⚠️ Error adding column '$column' to '$table': $e");
    }
  }

  static Future<void> _ensureInventoryVectorsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_vectors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemId INTEGER,
        vector TEXT,
        createdAt INTEGER,
        FOREIGN KEY (itemId) REFERENCES inventory (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_vec_item ON inventory_vectors(itemId)');
  }

  static Future<void> _ensureMessagesTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL,
        sender TEXT NOT NULL DEFAULT 'buyer',
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
        read INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_client ON messages(client_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_ts ON messages(timestamp)');
  }

  static Future<void> _ensureVisualCollisionsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS visual_collisions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item1_id INTEGER,
        item2_id INTEGER,
        collision_count INTEGER DEFAULT 1,
        last_collision INTEGER,
        disambiguation_prompt TEXT,
        FOREIGN KEY (item1_id) REFERENCES inventory (id) ON DELETE CASCADE,
        FOREIGN KEY (item2_id) REFERENCES inventory (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_collision_items ON visual_collisions(item1_id, item2_id)');
  }

  static Future<void> _ensureEventsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY,
        event_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        payload_raw TEXT,
        hash TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        shop_id TEXT,
        device_id TEXT,
        synced INTEGER DEFAULT 0,
        sync_attempts INTEGER DEFAULT 0,
        failed INTEGER DEFAULT 0
      )
    ''');
    await _safeAddColumn(db, 'events', 'payload_raw', 'TEXT');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_synced ON events(synced, failed, timestamp)');
  }

  static Future<void> _ensureShopSettingsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shop_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shop_id TEXT,
        shop_name TEXT,
        branding TEXT,
        updated_at INTEGER
      )
    ''');
  }

  static Future<void> _ensureShopsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shops (
        id TEXT PRIMARY KEY,
        business_name TEXT,
        theme_config TEXT,
        trust_score REAL,
        subscription_tier TEXT,
        updated_at INTEGER
      )
    ''');
    // Columns expected by InitialCloudSyncService._pullShopInfo()
    await _safeAddColumn(db, 'shops', 'name', 'TEXT');
    await _safeAddColumn(db, 'shops', 'enabled_modules', 'TEXT');
    await _safeAddColumn(db, 'shops', 'settings', 'TEXT');
  }

  /// Module system tables for tracking installed modules and feature flags
  static Future<void> _ensureModuleTables(dynamic db) async {
    // Tracks which modules are installed for each shop
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shop_modules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shop_id TEXT NOT NULL,
        module_id TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        config TEXT,
        installed_at INTEGER NOT NULL,
        updated_at INTEGER,
        UNIQUE(shop_id, module_id)
      )
    ''');
    
    // Tracks feature flag overrides per shop/module
    await db.execute('''
      CREATE TABLE IF NOT EXISTS module_features (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shop_id TEXT NOT NULL,
        module_id TEXT NOT NULL,
        feature_id TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER,
        UNIQUE(shop_id, module_id, feature_id)
      )
    ''');
    
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shop_modules_shop ON shop_modules(shop_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_module_features_shop_module ON module_features(shop_id, module_id)');
  }

  /// Run database migrations for all registered modules
  /// This ensures module-specific tables (restaurant_menu, services_catalog, etc.) exist
  static Future<void> _runModuleMigrations(dynamic db) async {
    try {
      // Import module registry to get all modules
      // Note: We manually list migrations here to avoid circular dependencies
      
      // -- RETAIL MODULE ENTERPRISE ENHANCEMENTS --
      await db.execute('''
        CREATE TABLE IF NOT EXISTS retail_returns (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          original_txn_id TEXT,
          item_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          refund_amount REAL NOT NULL,
          reason_code TEXT,
          status TEXT DEFAULT 'completed',
          cloud_id TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS retail_suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          contact_name TEXT,
          email TEXT,
          phone TEXT,
          address TEXT,
          cloud_id TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS retail_purchase_orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL,
          status TEXT DEFAULT 'draft',
          total_cost REAL DEFAULT 0,
          eta_date INTEGER,
          cloud_id TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          FOREIGN KEY (supplier_id) REFERENCES retail_suppliers(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS retail_po_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          po_id INTEGER NOT NULL,
          inventory_id INTEGER NOT NULL,
          quantity_ordered INTEGER NOT NULL,
          quantity_received INTEGER DEFAULT 0,
          unit_cost REAL NOT NULL,
          FOREIGN KEY (po_id) REFERENCES retail_purchase_orders(id),
          FOREIGN KEY (inventory_id) REFERENCES inventory(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS retail_promotions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          target_item_id INTEGER,
          target_category TEXT,
          discount_value REAL NOT NULL,
          min_spend REAL DEFAULT 0,
          start_date INTEGER,
          end_date INTEGER,
          is_active INTEGER DEFAULT 1,
          cloud_id TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS retail_stock_audits (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          inventory_id INTEGER NOT NULL,
          expected_stock INTEGER NOT NULL,
          actual_stock INTEGER NOT NULL,
          difference INTEGER NOT NULL,
          reason TEXT,
          performed_by TEXT,
          cloud_id TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          FOREIGN KEY (inventory_id) REFERENCES inventory(id)
        )
      ''');

      
      // Restaurant module tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS restaurant_menu (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cloud_id TEXT,
          name TEXT NOT NULL,
          description TEXT,
          price REAL NOT NULL,
          category TEXT,
          image_path TEXT,
          available INTEGER NOT NULL DEFAULT 1,
          prep_time_minutes INTEGER DEFAULT 10,
          modifiers_json TEXT,
          sort_order INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS restaurant_orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cloud_id TEXT,
          order_number TEXT NOT NULL UNIQUE,
          order_type TEXT NOT NULL DEFAULT 'dine_in',
          table_number TEXT,
          customer_name TEXT,
          customer_phone TEXT,
          items_json TEXT NOT NULL,
          subtotal REAL NOT NULL,
          tax REAL DEFAULT 0,
          total REAL NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          notes TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS restaurant_order_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_id INTEGER NOT NULL,
          menu_item_id INTEGER,
          menu_item_name TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1,
          unit_price REAL NOT NULL,
          subtotal REAL NOT NULL,
          modifiers_json TEXT,
          item_note TEXT,
          status TEXT DEFAULT 'pending',
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          FOREIGN KEY (order_id) REFERENCES restaurant_orders (id) ON DELETE CASCADE
        )
      ''');
      
      // Column expected by EventProcessor for ORDER_CREATED events
      await _safeAddColumn(db, 'restaurant_orders', 'total_amount', 'REAL DEFAULT 0');

      // Staff accountability tracking — who performed each status transition
      await _safeAddColumn(db, 'restaurant_orders', 'created_by', 'TEXT');
      await _safeAddColumn(db, 'restaurant_orders', 'preparing_by', 'TEXT');
      await _safeAddColumn(db, 'restaurant_orders', 'ready_by', 'TEXT');
      await _safeAddColumn(db, 'restaurant_orders', 'served_by', 'TEXT');
      await _safeAddColumn(db, 'restaurant_orders', 'completed_by', 'TEXT');

      // Fix existing orders created from rings that got default 'takeaway'
      try {
        await db.rawUpdate("UPDATE restaurant_orders SET order_type = 'dine_in' WHERE order_type = 'takeaway'");
      } catch (_) {}

      // Restaurant Enterprise Enhancements (v27)
      
      // 1. Split Bills & Folio Merging logic
      await _safeAddColumn(db, 'restaurant_orders', 'split_type', 'TEXT'); // 'even', 'item', 'custom'
      await _safeAddColumn(db, 'restaurant_orders', 'parent_order_id', 'INTEGER'); // For merged/sub-orders

      // 2. Kitchen Course Firing pacing & Staff Accountability
      await _safeAddColumn(db, 'restaurant_order_items', 'course_id', 'INTEGER DEFAULT 1'); // 1=Appetizer, 2=Main
      await _safeAddColumn(db, 'restaurant_order_items', 'fired_at', 'INTEGER'); // Timestamp when pushed to kitchen
      await _safeAddColumn(db, 'restaurant_order_items', 'preparing_by', 'TEXT');
      await _safeAddColumn(db, 'restaurant_order_items', 'ready_by', 'TEXT');
      await _safeAddColumn(db, 'restaurant_order_items', 'served_by', 'TEXT');
      
      // 3. Recipes & Ingredient Costing (Join between Menu and Retail Inventory)
      // This is now properly isolated via V28 migration constraints
      await db.execute('''
        CREATE TABLE IF NOT EXISTS restaurant_inventory (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cloud_id TEXT,
          name TEXT NOT NULL,
          category TEXT,
          unit_of_measure TEXT NOT NULL DEFAULT 'pcs',
          stock_level REAL NOT NULL DEFAULT 0,
          cost_per_unit REAL NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');
      await _safeAddColumn(db, 'restaurant_inventory', 'min_stock_level', 'REAL NOT NULL DEFAULT 0');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS restaurant_recipes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          menu_item_id INTEGER NOT NULL,
          restaurant_inventory_id INTEGER NOT NULL,
          quantity_required REAL NOT NULL,
          cloud_id TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          FOREIGN KEY (menu_item_id) REFERENCES restaurant_menu(id) ON DELETE CASCADE,
          FOREIGN KEY (restaurant_inventory_id) REFERENCES restaurant_inventory(id) ON DELETE CASCADE
        )
      ''');
      await _safeAddColumn(db, 'restaurant_orders', 'source_module', "TEXT DEFAULT 'restaurant'");
      await _safeAddColumn(db, 'restaurant_menu', 'source_module', "TEXT DEFAULT 'restaurant'");

      await db.execute('CREATE INDEX IF NOT EXISTS idx_menu_category ON restaurant_menu(category)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_status ON restaurant_orders(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_created ON restaurant_orders(created_at)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_order_items_order ON restaurant_order_items(order_id)');

      // Restaurant floor plan tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS restaurant_floor_plan (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_number TEXT NOT NULL,
          label TEXT,
          shape TEXT DEFAULT 'round',
          seats INTEGER DEFAULT 4,
          x REAL DEFAULT 0.5,
          y REAL DEFAULT 0.5,
          zone TEXT DEFAULT 'Main Hall',
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');

      // Services module tables

      // Service categories (with representative image)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS service_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          image_path TEXT,
          description TEXT,
          sort_order INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS services_catalog (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cloud_id TEXT,
          name TEXT NOT NULL,
          description TEXT,
          duration_minutes INTEGER NOT NULL DEFAULT 30,
          price REAL NOT NULL,
          category TEXT,
          category_id INTEGER,
          staff_ids TEXT,
          active INTEGER NOT NULL DEFAULT 1,
          image_path TEXT,
          is_published INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          FOREIGN KEY (category_id) REFERENCES service_categories (id)
        )
      ''');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS services_staff (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          role TEXT,
          phone TEXT,
          email TEXT,
          available_days TEXT DEFAULT '1,2,3,4,5',
          work_hours_start TEXT DEFAULT '09:00',
          work_hours_end TEXT DEFAULT '17:00',
          break_start TEXT,
          break_end TEXT,
          active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS services_staff_shifts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cloud_id TEXT UNIQUE,
          staff_id INTEGER,
          start_time INTEGER,
          end_time INTEGER,
          status TEXT,
          is_recurring INTEGER,
          created_at INTEGER,
          updated_at INTEGER,
          FOREIGN KEY (staff_id) REFERENCES services_staff (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_services_shifts_staff ON services_staff_shifts(staff_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_services_shifts_start ON services_staff_shifts(start_time)');

      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS services_bookings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cloud_id TEXT,
          service_id INTEGER NOT NULL,
          staff_id INTEGER,
          customer_name TEXT NOT NULL,
          customer_phone TEXT,
          customer_email TEXT,
          start_time INTEGER NOT NULL,
          end_time INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          notes TEXT,
          deposit_paid REAL DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');
      
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bookings_start_time ON services_bookings(start_time)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bookings_status ON services_bookings(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_bookings_staff ON services_bookings(staff_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_services_category ON services_catalog(category)');

      // V31+: buffer_minutes on catalog, addon_ids on bookings
      await _safeAddColumn(db, 'services_catalog', 'buffer_minutes', 'INTEGER NOT NULL DEFAULT 0');
      await _safeAddColumn(db, 'services_catalog', 'source_module', "TEXT DEFAULT 'services'");
      await _safeAddColumn(db, 'services_bookings', 'addon_ids', 'TEXT');
      await _safeAddColumn(db, 'services_bookings', 'total_price', 'REAL');
      await _safeAddColumn(db, 'services_bookings', 'total_duration_minutes', 'INTEGER');
      await _safeAddColumn(db, 'services_bookings', 'recurrence_rule', 'TEXT');

      // Addons table (up-sells applied to bookings)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS services_addons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          parent_service_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          price_added REAL NOT NULL DEFAULT 0,
          duration_added_minutes INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (parent_service_id) REFERENCES services_catalog(id) ON DELETE CASCADE
        )
      ''');

      // Rooms table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS services_rooms (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          capacity INTEGER NOT NULL DEFAULT 1,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');

      // Shared supplies/stock table for consumables (flour, hair products, etc.)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplies (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          category TEXT,
          unit TEXT DEFAULT 'pcs',
          quantity REAL NOT NULL DEFAULT 0,
          cost_per_unit REAL DEFAULT 0,
          min_stock_level REAL DEFAULT 0,
          module TEXT NOT NULL DEFAULT 'restaurant',
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_supplies_module ON supplies(module)');

      // Recipe/BOM links: maps menu items or services to their supply ingredients
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supply_links (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item_id INTEGER NOT NULL,
          item_type TEXT NOT NULL,
          supply_id INTEGER NOT NULL,
          quantity_per_use REAL NOT NULL DEFAULT 1,
          FOREIGN KEY (supply_id) REFERENCES supplies(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_supply_links_item ON supply_links(item_type, item_id)');

      // Entertainment module tables

      // Asset types (templates with shared images, rate, billing)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS entertainment_asset_types (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cloud_id TEXT,
          name TEXT NOT NULL,
          category TEXT NOT NULL DEFAULT 'general',
          asset_type TEXT NOT NULL DEFAULT 'hourly',
          rate_per_hour REAL NOT NULL DEFAULT 0,
          flat_rate REAL DEFAULT 0,
          description TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          is_published INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');

      // Asset type images (shared gallery per type)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS entertainment_asset_type_images (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          asset_type_id INTEGER NOT NULL,
          image_path TEXT NOT NULL,
          sort_order INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          FOREIGN KEY (asset_type_id) REFERENCES entertainment_asset_types (id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ent_type_images ON entertainment_asset_type_images(asset_type_id, sort_order)',
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS entertainment_assets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cloud_id TEXT,
          name TEXT NOT NULL,
          category TEXT NOT NULL DEFAULT 'general',
          asset_type TEXT NOT NULL DEFAULT 'hourly',
          asset_type_id INTEGER,
          rate_per_hour REAL NOT NULL DEFAULT 0,
          flat_rate REAL DEFAULT 0,
          description TEXT,
          image_path TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          is_published INTEGER NOT NULL DEFAULT 1,
          sort_order INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          FOREIGN KEY (asset_type_id) REFERENCES entertainment_asset_types (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS entertainment_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cloud_id TEXT,
          asset_id INTEGER NOT NULL,
          customer_name TEXT,
          started_at INTEGER NOT NULL,
          ended_at INTEGER,
          billing_type TEXT NOT NULL DEFAULT 'hourly',
          rate REAL NOT NULL DEFAULT 0,
          total_amount REAL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'active',
          notes TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          FOREIGN KEY (asset_id) REFERENCES entertainment_assets (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_ent_assets_category ON entertainment_assets(category)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ent_assets_active ON entertainment_assets(is_active)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ent_sessions_asset ON entertainment_sessions(asset_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ent_sessions_status ON entertainment_sessions(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ent_sessions_started ON entertainment_sessions(started_at)');

      // Ensure new FK columns exist on pre-existing tables
      await _safeAddColumn(db, 'services_catalog', 'category_id', 'INTEGER');
      await _safeAddColumn(db, 'entertainment_assets', 'asset_type_id', 'INTEGER');
      // Note: lodging_rooms.room_type_id is added after lodging tables are created (below)

      // Ensure source_module columns exist for sync routing
      await _safeAddColumn(db, 'services_catalog', 'source_module', "TEXT DEFAULT 'services'");
      await _safeAddColumn(db, 'services_bookings', 'source_module', "TEXT DEFAULT 'services'");
      await _safeAddColumn(db, 'entertainment_assets', 'source_module', "TEXT DEFAULT 'entertainment'");
      await _safeAddColumn(db, 'entertainment_sessions', 'source_module', "TEXT DEFAULT 'entertainment'");
      // Note: lodging source_module columns are added after lodging tables are created (below)

      // Auto-migrate: create service_categories from existing distinct category strings
      try {
        final existingCats = await db.rawQuery(
          "SELECT DISTINCT category FROM services_catalog WHERE category IS NOT NULL AND category != ''",
        );
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final row in existingCats) {
          final catName = row['category'] as String;
          final existing = await db.rawQuery(
            'SELECT id FROM service_categories WHERE name = ?', [catName],
          );
          if (existing.isEmpty) {
            final catId = await db.insert('service_categories', {
              'name': catName,
              'created_at': now,
              'updated_at': now,
            });
            await db.rawUpdate(
              'UPDATE services_catalog SET category_id = ? WHERE category = ?',
              [catId, catName],
            );
          }
        }
        debugPrint('📋 Service category migration completed');
      } catch (e) {
        debugPrint('⚠️ Service category migration skipped: $e');
      }

      // Auto-migrate: create entertainment_asset_types from existing distinct name+category combos
      try {
        final existingTypes = await db.rawQuery(
          'SELECT DISTINCT name, category, asset_type, rate_per_hour, flat_rate, description FROM entertainment_assets WHERE is_active = 1',
        );
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final row in existingTypes) {
          final typeName = row['name'] as String;
          final category = row['category'] as String;
          final existing = await db.rawQuery(
            'SELECT id FROM entertainment_asset_types WHERE name = ? AND category = ?', [typeName, category],
          );
          if (existing.isEmpty) {
            final typeId = await db.insert('entertainment_asset_types', {
              'cloud_id': const Uuid().v4(),
              'name': typeName,
              'category': category,
              'asset_type': row['asset_type'] ?? 'hourly',
              'rate_per_hour': row['rate_per_hour'] ?? 0,
              'flat_rate': row['flat_rate'] ?? 0,
              'description': row['description'],
              'is_active': 1,
              'created_at': now,
              'updated_at': now,
            });
            await db.rawUpdate(
              'UPDATE entertainment_assets SET asset_type_id = ? WHERE name = ? AND category = ?',
              [typeId, typeName, category],
            );
          }
        }
        debugPrint('🎮 Entertainment asset type migration completed');
      } catch (e) {
        debugPrint('⚠️ Entertainment asset type migration skipped: $e');
      }

      // Lodging module tables

      // Room types (templates with shared images, rate, amenities)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS lodging_room_types (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cloud_id TEXT,
          name TEXT NOT NULL,
          description TEXT,
          capacity INTEGER NOT NULL DEFAULT 2,
          rate_per_night REAL NOT NULL DEFAULT 0,
          amenities TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          is_published INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS lodging_rooms (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cloud_id TEXT,
          name TEXT NOT NULL,
          room_type TEXT NOT NULL DEFAULT 'standard',
          room_type_id INTEGER,
          floor TEXT,
          capacity INTEGER NOT NULL DEFAULT 2,
          rate_per_night REAL NOT NULL DEFAULT 0,
          amenities TEXT,
          description TEXT,
          image_path TEXT,
          status TEXT NOT NULL DEFAULT 'available',
          is_active INTEGER NOT NULL DEFAULT 1,
          is_published INTEGER NOT NULL DEFAULT 1,
          sort_order INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          FOREIGN KEY (room_type_id) REFERENCES lodging_room_types (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS lodging_reservations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cloud_id TEXT,
          room_id INTEGER NOT NULL,
          customer_id INTEGER,
          guest_name TEXT NOT NULL,
          guest_phone TEXT,
          guest_email TEXT,
          guest_id_number TEXT,
          check_in_date INTEGER NOT NULL,
          check_out_date INTEGER NOT NULL,
          actual_check_in INTEGER,
          actual_check_out INTEGER,
          nights INTEGER NOT NULL DEFAULT 1,
          rate_per_night REAL NOT NULL DEFAULT 0,
          extras_total REAL NOT NULL DEFAULT 0,
          total_amount REAL NOT NULL DEFAULT 0,
          amount_paid REAL NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'pending',
          notes TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          FOREIGN KEY (room_id) REFERENCES lodging_rooms (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_lodging_rooms_type ON lodging_rooms(room_type)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_lodging_rooms_status ON lodging_rooms(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_lodging_rooms_active ON lodging_rooms(is_active)');
      // Indexes for lodging performance
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lodging_reservations_room ON lodging_reservations(room_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lodging_reservations_dates ON lodging_reservations(check_in_date, check_out_date)',
      );
      await db.execute('CREATE INDEX IF NOT EXISTS idx_lodging_res_status ON lodging_reservations(status)');

      // Ensure lodging columns exist (must be AFTER CREATE TABLE above)
      await _safeAddColumn(db, 'lodging_rooms', 'room_type_id', 'INTEGER');
      await _safeAddColumn(db, 'lodging_rooms', 'source_module', "TEXT DEFAULT 'lodging'");
      await _safeAddColumn(db, 'lodging_reservations', 'source_module', "TEXT DEFAULT 'lodging'");
      await _safeAddColumn(db, 'lodging_reservations', 'customer_id', 'INTEGER');

      // Room type images (shared gallery per type)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS lodging_room_type_images (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          room_type_id INTEGER NOT NULL,
          image_path TEXT NOT NULL,
          sort_order INTEGER DEFAULT 0,
          caption TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
          FOREIGN KEY (room_type_id) REFERENCES lodging_room_types (id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_room_type_images ON lodging_room_type_images(room_type_id, sort_order)',
      );

      // Auto-migrate: create room_types from existing distinct room_type strings
      try {
        final existingTypes = await db.rawQuery(
          'SELECT DISTINCT room_type FROM lodging_rooms WHERE room_type IS NOT NULL',
        );
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final row in existingTypes) {
          final typeName = row['room_type'] as String;
          // Check if type already exists
          final existing = await db.rawQuery(
            'SELECT id FROM lodging_room_types WHERE name = ?', [typeName],
          );
          if (existing.isEmpty) {
            // Get representative room for defaults
            final repRoom = await db.rawQuery(
              'SELECT capacity, rate_per_night, amenities, description FROM lodging_rooms WHERE room_type = ? LIMIT 1',
              [typeName],
            );
            final rep = repRoom.isNotEmpty ? repRoom.first : <String, dynamic>{};
            final typeId = await db.insert('lodging_room_types', {
              'cloud_id': const Uuid().v4(),
              'name': typeName,
              'capacity': rep['capacity'] ?? 2,
              'rate_per_night': rep['rate_per_night'] ?? 0,
              'amenities': rep['amenities'],
              'description': rep['description'],
              'created_at': now,
              'updated_at': now,
            });
            // Link existing rooms to this type
            await db.rawUpdate(
              'UPDATE lodging_rooms SET room_type_id = ? WHERE room_type = ?',
              [typeId, typeName],
            );
          }
        }
        debugPrint('🏨 Room type migration completed');
      } catch (e) {
        debugPrint('⚠️ Room type migration skipped: $e');
      }

      // Migration: Normalize inconsistent txn.type values
      // Historical records may have 'expense', 'Outgoing', or 'outgoing' — normalize to 'outgoing'
      try {
        final fixed = await db.rawUpdate(
          "UPDATE txn SET type = 'outgoing' WHERE type IN ('expense', 'Outgoing')"
        );
        if (fixed > 0) {
          debugPrint('🔧 Normalized $fixed expense records to type=outgoing');
        }
      } catch (e) {
        debugPrint('⚠️ txn type normalization skipped: $e');
      }
      
      debugPrint('✅ Module migrations completed');
    } catch (e) {
      debugPrint('⚠️ Error running module migrations: $e');
      // Don't rethrow - tables may already exist
    }
  }

  /// V23 Migration: Module isolation — add source_module to inventory & txn
  static Future<void> _migrateToV23_moduleIsolation(dynamic db) async {
    print('🔧 Running v23 migration: Module data isolation');
    
    // 1. Add source_module column to inventory and txn
    await _safeAddColumn(db, 'inventory', 'source_module', "TEXT DEFAULT 'retail'");
    await _safeAddColumn(db, 'txn', 'source_module', "TEXT DEFAULT 'retail'");
    
    // 2. Create indexes for fast module-scoped queries
    await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_module ON inventory(source_module)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_txn_module ON txn(source_module)');
    
    // 3. Backfill existing data using heuristics
    try {
      // 3a. Tag inventory items that match restaurant_menu names as 'restaurant'
      final menuCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='restaurant_menu'"
      );
      if (menuCheck.isNotEmpty) {
        final tagged = await db.rawUpdate('''
           UPDATE inventory SET source_module = 'restaurant' 
           WHERE (source_module IS NULL OR source_module = 'retail')
             AND name IN (SELECT name FROM restaurant_menu)
         ''');
        if (tagged > 0) print('  ✓ Tagged $tagged inventory items as restaurant');
      }
      
      // 3b. Tag transactions with "Restaurant Order" in details as 'restaurant'
      final taggedTxn = await db.rawUpdate('''
        UPDATE txn SET source_module = 'restaurant' 
        WHERE (source_module IS NULL OR source_module = 'retail')
        AND details LIKE '%Restaurant Order%'
      ''');
      if (taggedTxn > 0) print('  ✓ Tagged $taggedTxn transactions as restaurant');
      
      // 3c. Everything else stays 'retail' (the default)
      await db.rawUpdate(
        "UPDATE inventory SET source_module = 'retail' WHERE source_module IS NULL"
      );
      await db.rawUpdate(
        "UPDATE txn SET source_module = 'retail' WHERE source_module IS NULL"
      );
      
      print('✅ v23 migration complete: Module isolation applied');
    } catch (e) {
      print('⚠️ v23 backfill error (non-fatal): $e');
    }
  }

  static Future<void> _createTables(dynamic db) async {
    await db.execute('''
      CREATE TABLE customer (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        id_no TEXT,
        bank_account TEXT,
        notes TEXT,
        agent TEXT,
        store TEXT,
        createdAt INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE txn (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cloud_id TEXT,
        customerId INTEGER,
        itemId INTEGER,
        type TEXT,
        totalAmount INTEGER,
        details TEXT,
        denominationLogId INTEGER,
        timestamp INTEGER,
        receiptSignature TEXT,
        source_module TEXT DEFAULT 'retail',
        payment_ref TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cloud_id TEXT,
        name TEXT NOT NULL,
        category TEXT,
        sellingPrice REAL,
        originalPrice REAL,
        stock INTEGER DEFAULT 0,
        imagePath TEXT,
        visual_vector TEXT,
        specification TEXT,
        barcode TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE accounting (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER,
        cashTotal INTEGER,
        mpesa1 INTEGER,
        mpesa2 INTEGER,
        coop INTEGER,
        equity INTEGER,
        kcb INTEGER,
        airtel INTEGER,
        otherMpesa INTEGER,
        salesDisparity INTEGER,
        specialScenarios TEXT
      )
    ''');

    await _ensureInventoryVectorsTable(db);
    await _ensureVisualCollisionsTable(db);
    await _ensureEventsTable(db);
    await _ensureShopSettingsTable(db);
    
    // Ensure topics table exists (referenced in migrations)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS topics (
        id TEXT PRIMARY KEY,
        name TEXT,
        cloud_id TEXT
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_txn_timestamp ON txn(timestamp)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_name ON inventory(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_txn_type ON txn(type)');
    await _createTransactionItemsTable(db);
  }

  static Future<void> _createTransactionItemsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transactionId INTEGER NOT NULL,
        itemId INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unitPrice INTEGER NOT NULL,
        subtotal INTEGER NOT NULL,
        discount INTEGER DEFAULT 0,
        FOREIGN KEY (transactionId) REFERENCES txn(id) ON DELETE CASCADE,
        FOREIGN KEY (itemId) REFERENCES inventory(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transaction_items_txn_id ON transaction_items(transactionId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transaction_items_item_id ON transaction_items(itemId)');
  }

  static Future<void> _migrateToV14(dynamic db) async {
    print("🔄 Migrating to v14: Cart Architecture");
    await _createTransactionItemsTable(db);
    try {
      final legacyTxns = await db.rawQuery('''
        SELECT id, itemId, totalAmount 
        FROM txn 
        WHERE itemId IS NOT NULL 
          AND itemId != 0
          AND NOT EXISTS (
            SELECT 1 FROM transaction_items ti WHERE ti.transactionId = txn.id
          )
      ''');
      
      if (legacyTxns.isNotEmpty) {
        await db.transaction((txn) async {
          for (final row in legacyTxns) {
            await txn.insert('transaction_items', {
              'transactionId': row['id'],
              'itemId': row['itemId'],
              'quantity': 1,
              'unitPrice': row['totalAmount'],
              'subtotal': row['totalAmount'],
              'discount': 0,
            });
          }
        });
      }
    } catch (e) {
      print("  ⚠️ Error during migration: $e");
    }
  }

  static Future<void> reloadDatabase({String? databaseName}) async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    await Future.delayed(const Duration(milliseconds: 200));
    await init(databaseName: databaseName);
  }

  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _currentShopId = null;
    }
    _initFuture = null;
  }

  // ===== MULTI-SHOP DATABASE SUPPORT =====
  
  /// Get the currently loaded shop ID
  static String? get currentShopId => _currentShopId;
  
  /// Switch to a different shop's database
  /// 
  /// This is called when:
  /// 1. User selects a shop in AuthService.selectShop()
  /// 2. Enterprise owner visits another shop (Ghost Mode)
  /// 
  /// Each shop has its own database file: shop_{id}.db
  static Future<void> switchToShopDatabase(String shopId, {bool readOnly = false}) async {
    if (_currentShopId == shopId && _db != null) {
      _isReadOnly = readOnly;
      debugPrint('📂 Already using database for shop: $shopId (readOnly: $readOnly)');
      return;
    }
    
    debugPrint('🔄 Switching database to shop: $shopId (readOnly: $readOnly)');
    
    // Close current database
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _initFuture = null;
    
    // Generate database filename
    final safeId = shopId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final dbName = 'shop_$safeId.db';
    
    // Initialize with new database
    await init(databaseName: dbName);
    _currentShopId = shopId;
    _isReadOnly = readOnly;
    
    debugPrint('✅ Switched to database: $dbName (readOnly: $readOnly)');
  }
  
  /// Switch back to home shop's database (always writable)
  static Future<void> switchToHomeDatabase() async {
    // Import DeviceService dynamically to avoid circular deps
    final homeShopId = await _getHomeShopId();
    await switchToShopDatabase(homeShopId, readOnly: false);
  }
  
  /// Whether the current database is in read-only mode (ghost mode)
  static bool get isReadOnly => _isReadOnly;

  /// Helper to get home shop ID (avoids circular import)
  static Future<String> _getHomeShopId() async {
    // We can't directly import DeviceService here due to potential circular deps
    // So we use SharedPreferences directly
    final prefs = await SharedPreferences.getInstance();
    final homeShopId = prefs.getString('home_shop_id') ?? 
                       prefs.getString('shop_id');
    if (homeShopId != null && homeShopId.isNotEmpty) {
      return homeShopId;
    }
    // Fallback: generate new shop ID
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return 'shop_${timestamp}_$random';
  }
  
  // =====================================

  static void _guardReadOnly(String operation) {
    if (_isReadOnly) {
      throw Exception('🔒 Database is in read-only mode (Ghost Mode). '
          'Cannot perform $operation on a foreign shop\'s data.');
    }
  }

  static Future<int> insert(String table, Map<String, dynamic> values) async {
    _guardReadOnly('INSERT into $table');
    final dbClient = await db;
    return await dbClient.insert(table, values, conflictAlgorithm: sqlcipher.ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> query(
    String table, {
    String? orderBy,
    String? where,
    List<Object?>? whereArgs,
    int? limit,
  }) async {
    final dbClient = await db;
    return await dbClient.query(table, orderBy: orderBy, where: where, whereArgs: whereArgs, limit: limit);
  }

  static Future<List<Map<String, dynamic>>> queryRaw(String sql, [List<Object?>? arguments]) async {
    final dbClient = await db;
    return await dbClient.rawQuery(sql, arguments);
  }

  static Future<int> update(String table, Map<String, dynamic> values, {String? where, List<Object?>? whereArgs}) async {
    _guardReadOnly('UPDATE on $table');
    final dbClient = await db;
    return await dbClient.update(table, values, where: where, whereArgs: whereArgs);
  }

  static Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    _guardReadOnly('DELETE from $table');
    final dbClient = await db;
    return await dbClient.delete(table, where: where, whereArgs: whereArgs);
  }

  static Future<void> transaction(Future<void> Function(dynamic) action) async {
    _guardReadOnly('TRANSACTION');
    final database = await db;
    await database.transaction(action);
  }

  static Future<Map<String, dynamic>> getDatabaseStats() async {
    final dbClient = await db;
    final inventoryCount = await dbClient.rawQuery('SELECT COUNT(*) as count FROM inventory');
    final txnCount = await dbClient.rawQuery('SELECT COUNT(*) as count FROM txn');
    final vectorsCount = await dbClient.rawQuery('SELECT COUNT(*) as count FROM inventory_vectors');
    final collisionsCount = await dbClient.rawQuery('SELECT COUNT(*) as count FROM visual_collisions');
    final itemsWithVectors = await dbClient.rawQuery('SELECT COUNT(*) as count FROM inventory WHERE visual_vector IS NOT NULL');

    return {
      'total_inventory': inventoryCount.first['count'],
      'total_transactions': txnCount.first['count'],
      'ai_memory_vectors': vectorsCount.first['count'],
      'items_with_ai': itemsWithVectors.first['count'],
      'collision_pairs': collisionsCount.first['count'],
    };
  }

  /// Migration v24: Rename services_catalog.active → is_active for cloud sync compatibility
  static Future<void> _migrateToV24_servicesActiveColumn(dynamic db) async {
    try {
      print('📋 Migration v24: Renaming services_catalog.active → is_active');
      
      // Check if table exists
      final tableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='services_catalog'"
      );
      if (tableCheck.isEmpty) {
        print('⏩ services_catalog table does not exist, skipping migration');
        return;
      }

      // Check if column already renamed
      final columnCheck = await db.rawQuery('PRAGMA table_info(services_catalog)');
      final hasIsActive = columnCheck.any((col) => col['name'] == 'is_active');
      final hasActive = columnCheck.any((col) => col['name'] == 'active');
      
      if (hasIsActive && !hasActive) {
        print('✅ Column already renamed, skipping migration');
        return;
      }

      if (!hasActive) {
        print('⚠️ Neither active nor is_active column found, adding is_active');
        await _safeAddColumn(db, 'services_catalog', 'is_active', 'INTEGER NOT NULL DEFAULT 1');
        return;
      }

      // Rename column: SQLite doesn't support ALTER COLUMN RENAME before 3.25.0
      // Use the safer approach: add new column, copy data, drop old
      print('📋 Adding is_active column...');
      await _safeAddColumn(db, 'services_catalog', 'is_active', 'INTEGER NOT NULL DEFAULT 1');
      
      print('📋 Copying data from active → is_active...');
      await db.execute('UPDATE services_catalog SET is_active = active');
      
      // Note: We can't drop the old 'active' column in SQLite without recreating the table
      // For safety, we'll leave the old column in place (it will be ignored by the API)
      print('✅ Migration v24 complete (old active column retained for compatibility)');
    } catch (e) {
      print('⚠️ Error in migration v24: $e');
      // Don't rethrow - allow app to continue even if migration fails
    }
  }

  static Future<void> _migrateToV28_restaurantInventory(dynamic db) async {
    print("📊 V28: Isolating Restaurant Inventory from Retail Module");
    
    // We intentionally drop the V27 recipes table because it was tied to the foreign key of `inventory`
    await db.execute('DROP TABLE IF EXISTS restaurant_recipes');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cloud_id TEXT,
        name TEXT NOT NULL,
        category TEXT,
        unit_of_measure TEXT NOT NULL DEFAULT 'pcs',
        stock_level REAL NOT NULL DEFAULT 0,
        min_stock_level REAL NOT NULL DEFAULT 0,
        cost_per_unit REAL NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        menu_item_id INTEGER NOT NULL,
        restaurant_inventory_id INTEGER NOT NULL,
        quantity_required REAL NOT NULL,
        cloud_id TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
        FOREIGN KEY (menu_item_id) REFERENCES restaurant_menu(id) ON DELETE CASCADE,
        FOREIGN KEY (restaurant_inventory_id) REFERENCES restaurant_inventory(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _migrateToV29_lodgingEnterprise(dynamic db) async {
    print("📊 V29: Adding Lodging Folios, Groups, and Channel Hooks");
    
    // Subsystem A: Folios
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lodging_folios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reservation_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        billing_address TEXT,
        subtotal REAL NOT NULL DEFAULT 0,
        is_master INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (reservation_id) REFERENCES lodging_reservations(id) ON DELETE CASCADE
      );
    ''');
    
    // Subsystem B: Groups
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lodging_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contract_name TEXT,
        total_rooms_allocated INTEGER NOT NULL,
        rooms_picked_up INTEGER NOT NULL DEFAULT 0,
        cutoff_date INTEGER NOT NULL,
        master_folio_id INTEGER
      );
    ''');

    // Subsystem C: Rate Plans
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lodging_rate_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        base_rate REAL NOT NULL,
        includes_breakfast INTEGER DEFAULT 0,
        is_refundable INTEGER DEFAULT 1,
        start_date INTEGER,
        end_date INTEGER
      );
    ''');

    // Subsystem D: Channel Logs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lodging_channel_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        synced_at INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending'
      );
    ''');
    
    // Add columns dynamically safely
    await _safeAddColumn(db, 'lodging_reservations', 'folio_id', 'INTEGER REFERENCES lodging_folios(id)');
    await _safeAddColumn(db, 'lodging_reservations', 'group_id', 'INTEGER REFERENCES lodging_groups(id)');
    await _safeAddColumn(db, 'lodging_reservations', 'rate_plan_id', 'INTEGER REFERENCES lodging_rate_plans(id)');
  }

  static Future<void> _migrateToV30_entertainmentEnterprise(dynamic db) async {
    print("📊 V30: Adding Entertainment Pre-paid limits, Tabs, Pause rules, and Pricing rules");
    
    await _safeAddColumn(db, 'entertainment_sessions', 'max_duration_seconds', 'INTEGER');
    await _safeAddColumn(db, 'entertainment_sessions', 'total_paused_seconds', 'INTEGER DEFAULT 0');
    await _safeAddColumn(db, 'entertainment_sessions', 'last_paused_at', 'INTEGER');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS entertainment_tabs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        external_order_id TEXT NOT NULL,
        external_module TEXT NOT NULL,
        amount REAL NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES entertainment_sessions (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS entertainment_pricing_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_id INTEGER,
        category TEXT,
        day_of_week INTEGER,
        start_time TEXT,
        end_time TEXT,
        rate_per_hour REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      );
    ''');
  }

  static Future<void> _migrateToV31_servicesEnterprise(dynamic db) async {
    print("📊 V31: Adding Services Enterprise Rooms, Buffers, Add-ons, and Recurrence");
    
    // Subsystem A: Multi-Resource Constraints (Rooms)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS services_rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        capacity INTEGER NOT NULL DEFAULT 1,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
      );
    ''');
    
    await _safeAddColumn(db, 'services_bookings', 'room_id', 'INTEGER REFERENCES services_rooms(id)');
    
    // Subsystem B: Buffer Times
    await _safeAddColumn(db, 'services_catalog', 'buffer_minutes', 'INTEGER DEFAULT 0');
    
    // Subsystem C: Service Add-ons
    await db.execute('''
      CREATE TABLE IF NOT EXISTS services_addons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_service_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price_added REAL NOT NULL DEFAULT 0,
        duration_added_minutes INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (parent_service_id) REFERENCES services_catalog(id) ON DELETE CASCADE
      );
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS services_booking_addons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        booking_id INTEGER NOT NULL,
        addon_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        duration_minutes INTEGER NOT NULL,
        FOREIGN KEY (booking_id) REFERENCES services_bookings(id) ON DELETE CASCADE
      );
    ''');
    
    // Subsystem D: Recurring Appointments
    await _safeAddColumn(db, 'services_bookings', 'recurrence_rule', 'TEXT');
  }

  static Future<void> _migrateToV32_paymentRef(dynamic db) async {
    print("📊 V32: Adding payment_ref column for M-Pesa/external payment codes");
    await _safeAddColumn(db, 'txn', 'payment_ref', 'TEXT');
    await _safeAddColumn(db, 'restaurant_split_bills', 'payment_ref', 'TEXT');
  }

  static Future<void> _migrateToV33_restaurantStaffTracking(dynamic db) async {
    print("📊 V33: Adding staff tracking columns to restaurant_order_items");
    await _safeAddColumn(db, 'restaurant_order_items', 'preparing_by', 'TEXT');
    await _safeAddColumn(db, 'restaurant_order_items', 'ready_by', 'TEXT');
    await _safeAddColumn(db, 'restaurant_order_items', 'served_by', 'TEXT');
  }

  static Future<void> _migrateToV34_publishFlags(dynamic db) async {
    print("📊 V34: Adding is_published flag to services, lodging, and entertainment schemas");
    await _safeAddColumn(db, 'services_catalog', 'is_published', 'INTEGER NOT NULL DEFAULT 1');
    await _safeAddColumn(db, 'lodging_room_types', 'is_published', 'INTEGER NOT NULL DEFAULT 1');
    await _safeAddColumn(db, 'lodging_rooms', 'is_published', 'INTEGER NOT NULL DEFAULT 1');
    await _safeAddColumn(db, 'entertainment_asset_types', 'is_published', 'INTEGER NOT NULL DEFAULT 1');
    await _safeAddColumn(db, 'entertainment_assets', 'is_published', 'INTEGER NOT NULL DEFAULT 1');
  }
}

