/// Database migrations for the module system.
/// 
/// These create the core tables needed to track which modules
/// are installed and enabled for each shop.
class ModuleMigrations {
  /// SQL statements to create module management tables
  static const List<String> coreTableSQL = [
    '''
    -- Tracks which modules are installed for each shop
    CREATE TABLE IF NOT EXISTS shop_modules (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      shop_id TEXT NOT NULL,
      module_id TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      config TEXT,
      installed_at INTEGER NOT NULL,
      updated_at INTEGER,
      UNIQUE(shop_id, module_id)
    );
    ''',
    '''
    -- Tracks feature flag overrides per shop/module
    CREATE TABLE IF NOT EXISTS module_features (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      shop_id TEXT NOT NULL,
      module_id TEXT NOT NULL,
      feature_id TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      updated_at INTEGER,
      UNIQUE(shop_id, module_id, feature_id)
    );
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_shop_modules_shop 
    ON shop_modules(shop_id);
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_module_features_shop_module 
    ON module_features(shop_id, module_id);
    ''',
  ];

  /// Migration version for tracking
  static const int version = 1;

  /// Run all core migrations on a database
  /// 
  /// [db] - The database connection (sqflite Database)
  /// [execute] - Function to execute SQL (for abstraction)
  static Future<void> runCoreMigrations(
    dynamic db,
    Future<void> Function(String sql) execute,
  ) async {
    for (final sql in coreTableSQL) {
      await execute(sql);
    }
  }
}
