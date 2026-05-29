# Debugging Guide: Mbeck V1.1.0 Integration Release

This guide is intended for AI agents to verify and troubleshoot the changes introduced in V1.1.0 ("Integration Release").

## 1. Database Layer (SQLite)

The core change is the introduction/update of the `shops` table.

- **Checkpoint**: Run `SELECT * FROM shops;` in a shell or via a script.
- **Expected Columns**: `id`, `business_name`, `theme_config` (TEXT/JSON), `trust_score` (REAL).
- **Common Issues**:
    - **Missing Table**: If `DbProvider` didn't execute `migration_v28`, the app will crash on `loadShopInfo`. Check `lib/db/db_provider.dart` for migration logic.
    - **JSON Parsing**: `theme_config` is stored as a String in SQLite. Ensure `Shop.fromMap` or `ShopAppearanceScreen` used `jsonDecode`.

## 2. Model Serialization

The `Shop` model was modified to include `themeConfig` and `trustScore`.

- **Verification Logic**:
  ```dart
  final shop = Shop.fromMap({'theme_config': '{"layout":"Grid"}', 'trust_score': 4.5, ...});
  print(shop.themeConfig['layout']); // Should be 'Grid'
  ```
- **Common Issues**:
    - **Num vs Double**: Sqflite sometimes returns `int` for whole numbers. Ensure `.toDouble()` is used for `trustScore`.
    - **Map Casting**: Ensure `Map<String, dynamic>.from(map['theme_config'])` is used to avoid type errors.

## 3. Cloud Sync (Supabase)

`CloudPublishService` now sends `theme_config`.

- **Verification Logic**: Check debug logs for `☁️ Publishing shop...`.
- **Payload Inspection**:
    - The upsert payload should contain a `theme_config` key.
    - **Security**: Verify `user.id` is used as the `shop_id` in cloud tables to prevent cross-ownership issues.
- **Common Issues**: 
    - **Empty Theme**: If `localShops` query in the service is empty, `themeConfig` will be `{}`, effectively resetting the cloud theme.

## 4. UI Components

### Theme (ShopAppearanceScreen)
- **State Check**: Ensure `_hasChanges` becomes `true` when a preset is tapped.
- **Saving**: Verify that clicking save triggers both `db.update('shops', ...)` AND `CloudPublishService.publishShopAndInventory()`.

### Trust Score (HomeScreen/TrustScoreWidget)
- **Rendering**: The Shield icon color should be `#FFD700` (Gold) if score >= 4.0, else `#C0C0C0` (Silver).
- **Data Flow**: `HomeScreen` fetches the score from `AuthService.getCurrentShop()`. If the score is always 0.0, check if the local DB has the `trust_score` column populated.

## 5. Critical Troubleshooting Snippet

If the app stalls on startup, it's likely a migration deadlock. Clear the DB to reset state:
```powershell
# Reset local DB for fresh migration testing
rm $env:LOCALAPPDATA\shop_database_live.db
```
*(Note: Use with caution, deletes all local inventory)*
