import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../db/db_provider.dart';
import 'device_service.dart';
import 'onboarding_service.dart';
import 'cloud_storage_service.dart';

class CloudPublishService {
  static const String _shopsTable = 'shops';
  static const String _inventoryTable = 'inventory';
  static const String _rateLimitKey = 'cloud_auth_rate_limit_until';
  static const int _backoffMinutes = 15;

  /// Ensure we have a Supabase session, using anonymous auth with backoff.
  /// Returns the authenticated user or null if unavailable.
  static Future<User?> _ensureAuth() async {
    final supabase = Supabase.instance.client;
    final existing = supabase.auth.currentUser;
    if (existing != null) return existing;

    // Check rate-limit backoff
    final prefs = await SharedPreferences.getInstance();
    final backoffUntil = prefs.getInt(_rateLimitKey) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < backoffUntil) {
      final remaining = ((backoffUntil - DateTime.now().millisecondsSinceEpoch) / 60000).ceil();
      debugPrint('⏳ Cloud auth on cooldown (${remaining}m remaining). Skipping.');
      return null;
    }

    debugPrint('� No user found, attempting anonymous auth...');
    try {
      final response = await supabase.auth.signInAnonymously();
      debugPrint('✅ Anonymous auth successful');
      return response.user;
    } on AuthException catch (e) {
      if (e.statusCode == '429' || e.message.toLowerCase().contains('rate limit')) {
        final until = DateTime.now().millisecondsSinceEpoch + (_backoffMinutes * 60 * 1000);
        await prefs.setInt(_rateLimitKey, until);
        debugPrint('⚠️ Rate limited. Backing off for ${_backoffMinutes}m.');
      } else {
        debugPrint('⚠️ Auth error: ${e.message}');
      }
      return null;
    } catch (e, stack) {
      debugPrint('❌ Cloud sync failed: $e');
      debugPrint('Stack trace: $stack');
      return null;
    }
  }

  /// Publishes the current shop details and inventory to the public cloud.
  /// Silently skips if cloud is unavailable (offline-first).
  static Future<void> publishShopAndInventory() async {
    final user = await _ensureAuth();
    if (user == null) {
      debugPrint('☁️ Cloud publish skipped — no auth session.');
      return;
    }
    
    final supabase = Supabase.instance.client;
    try {

    // 1. Get Local Data
    final cloudShopId = await DeviceService.getShopId() ?? user.id;

    // 2. Upsert Shop Details
    final localShops = await DbProvider.query('shops');
    Map<String, dynamic> themeConfig = {};
    String? businessName;
    String? passwordHash;
    bool isPublishedOnline = false;
    String currency = 'KES';
    
    if (localShops.isNotEmpty) {
      final localShop = localShops.first;
      businessName = (localShop['business_name']?.toString() ?? localShop['name']?.toString());
      passwordHash = localShop['password_hash'] ?? localShop['shop_password'];
      isPublishedOnline = localShop['is_published_online'] == 1;
      currency = localShop['currency']?.toString() ?? 'KES';
      
      if (localShop['theme_config'] != null) {
        if (localShop['theme_config'] is String) {
          try {
            themeConfig = json.decode(localShop['theme_config']);
          } catch (e) {
            debugPrint('⚠️ Error decoding theme_config: $e');
          }
        } else if (localShop['theme_config'] is Map) {
          themeConfig = Map<String, dynamic>.from(localShop['theme_config']);
        }
      }
    }

    // Uploads a local image_path to Supabase Storage and returns the public URL.
    // Returns null if the path is empty/unresolvable; returns the same value
    // unchanged if it's already a remote URL.
    Future<String?> resolveImageUrl(String? localPath) async {
      if (localPath == null || localPath.isEmpty) return null;
      if (localPath.startsWith('http')) return localPath;
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fullPath = p.join(appDir.path, p.basename(localPath));
        final cloudUrl = await CloudStorageService.uploadImage(fullPath, folder: 'marketplace');
        return (cloudUrl != null && cloudUrl.startsWith('http')) ? cloudUrl : null;
      } catch (e) {
        debugPrint('⚠️ Image upload failed: $e');
        return null;
      }
    }

    // Resolve any local images in themeConfig to cloud URLs
    if (themeConfig.containsKey('cover_image_url')) {
      themeConfig['cover_image_url'] = await resolveImageUrl(themeConfig['cover_image_url']?.toString());
    }
    
    if (themeConfig.containsKey('environment_images') && themeConfig['environment_images'] is List) {
      List<dynamic> envImages = themeConfig['environment_images'];
      List<String> resolvedEnvs = [];
      for (var img in envImages) {
        final url = await resolveImageUrl(img.toString());
        if (url != null) resolvedEnvs.add(url);
      }
      themeConfig['environment_images'] = resolvedEnvs;
    }

    if (themeConfig.containsKey('module_configs') && themeConfig['module_configs'] is Map) {
      final moduleConfigs = Map<String, dynamic>.from(themeConfig['module_configs']);
      for (var entry in moduleConfigs.entries) {
        if (entry.value is Map) {
          final mCfg = Map<String, dynamic>.from(entry.value);
          if (mCfg.containsKey('hero_image')) {
            mCfg['hero_image'] = await resolveImageUrl(mCfg['hero_image']?.toString());
          }
          if (mCfg.containsKey('environment_images') && mCfg['environment_images'] is List) {
            List<dynamic> mEnvImages = mCfg['environment_images'];
            List<String> resolvedMEnvs = [];
            for (var img in mEnvImages) {
              final url = await resolveImageUrl(img.toString());
              if (url != null) resolvedMEnvs.add(url);
            }
            mCfg['environment_images'] = resolvedMEnvs;
          }
          moduleConfigs[entry.key] = mCfg;
        }
      }
      themeConfig['module_configs'] = moduleConfigs;
    }

    // 🛡️ HARDENING: Prioritize local DB name (source of truth) over potentially stale metadata
    final shopName = businessName ?? user.userMetadata?['business_name'] ?? 'Mbeck Shop';

    debugPrint('☁️ Publishing shop: $shopName ($cloudShopId)... visibility: $isPublishedOnline');

    // Update Supabase user metadata if the name is different to keep ecosystem consistent
    if (user.userMetadata?['business_name'] != shopName) {
      try {
        await supabase.auth.updateUser(UserAttributes(data: {'business_name': shopName}));
      } catch (e) {
        debugPrint('⚠️ Failed to update user metadata: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final isRetailPublished = prefs.getBool('publish_retail') ?? false;
    final isServicesPublished = prefs.getBool('publish_services') ?? false;
    final isMenuPublished = prefs.getBool('publish_menu') ?? false;
    final isLodgingPublished = prefs.getBool('publish_lodging') ?? false;
    final isEntertainmentPublished = prefs.getBool('publish_entertainment') ?? false;

    // Get active modules to sync discovery state
    final activeModules = await OnboardingService.getSelectedModules();

    // Upsert shop. Build the row dynamically so we never overwrite
    // sensitive columns (password_hash) or seller-only columns
    // (verification_status) from the client.
    final shopRow = <String, dynamic>{
      'id': cloudShopId,
      'name': shopName,
      'owner_device_id': await DeviceService.getDeviceId() ?? cloudShopId,
      'owner_id': user.id, // Ensure owner_id is set for RLS compliance
      'updated_at': DateTime.now().toIso8601String(),
      'branding': themeConfig,
      'enabled_modules': activeModules, // Ensure Buyer app can discover all modules
      'currency': currency,
      'is_retail_published': isRetailPublished,
      'is_services_published': isServicesPublished,
      'is_restaurant_published': isMenuPublished,
      'is_lodging_published': isLodgingPublished,
      'is_entertainment_published': isEntertainmentPublished,
      'is_published_online': isPublishedOnline,
      // NOTE: verification_status is intentionally NOT set here.
      // It must be assigned by an admin/back-office flow, never self-claimed.
    };

    // Only forward password_hash if we actually have a real one locally.
    // Previously this column was force-overwritten with 'synced_placeholder',
    // which silently destroyed real auth hashes on every publish.
    if (passwordHash != null && passwordHash.toString().isNotEmpty) {
      shopRow['password_hash'] = passwordHash;
    } else {
      // If we don't have a local password hash, we must check if there is an existing one on the cloud.
      // Since password_hash is NOT NULL, upserting without it on a new shop violates the database constraint.
      try {
        final existingCloudShop = await supabase
            .from(_shopsTable)
            .select('password_hash')
            .eq('id', cloudShopId)
            .maybeSingle();
        if (existingCloudShop != null && existingCloudShop['password_hash'] != null) {
          shopRow['password_hash'] = existingCloudShop['password_hash'];
        } else {
          shopRow['password_hash'] = 'synced_placeholder';
        }
      } catch (e) {
        debugPrint('⚠️ Failed to check/retrieve existing cloud shop password_hash: $e');
        // Fallback to placeholder to satisfy NOT NULL constraint
        shopRow['password_hash'] = 'synced_placeholder';
      }
    }

    await supabase.from(_shopsTable).upsert(shopRow);

    // 3. Upsert Unified Marketplace Items
    final List<Map<String, dynamic>> itemsToUpsert = [];



    Future<void> loadModuleData(String table, String moduleName) async {
      try {
        final db = await DbProvider.db;
        List<Map<String, dynamic>> data;

        // The previous joins only pulled `r.*` / `a.*`, so type-level fields
        // (capacity, rate, amenities, hero gallery image) never reached the
        // cloud. That's why lodging/entertainment cards on the buyer were
        // blank. Now we surface the room-type / asset-type fields explicitly,
        // including a hero image taken from the type's shared gallery.
        if (moduleName == 'lodging') {
          data = await db.rawQuery('''
            SELECT
              rt.id                   AS id,
              rt.id                   AS room_type_id,
              rt.is_published         AS type_published,
              rt.name                 AS type_name,
              rt.description          AS type_description,
              rt.capacity             AS type_capacity,
              rt.rate_per_night       AS type_rate_per_night,
              rt.rate_per_week        AS type_rate_per_week,
              rt.rate_per_month       AS type_rate_per_month,
              rt.amenities            AS type_amenities,
              (SELECT COUNT(*) FROM lodging_rooms WHERE room_type_id = rt.id AND is_active = 1) AS stock,
              (SELECT image_path FROM lodging_room_type_images
               WHERE room_type_id = rt.id
               ORDER BY sort_order LIMIT 1) AS type_hero_image
            FROM lodging_room_types rt
            WHERE rt.is_active = 1
          ''');
        } else if (moduleName == 'entertainment') {
          data = await db.rawQuery('''
            SELECT
              at_.id                  AS id,
              at_.id                  AS asset_type_id,
              at_.is_published        AS type_published,
              at_.name                AS type_name,
              at_.description         AS type_description,
              at_.rate_per_hour       AS type_rate_per_hour,
              at_.flat_rate           AS type_flat_rate,
              at_.asset_type          AS type_asset_type,
              at_.category            AS type_category,
              (SELECT COUNT(*) FROM entertainment_assets WHERE asset_type_id = at_.id AND is_active = 1) AS stock,
              (SELECT image_path FROM entertainment_asset_type_images
               WHERE asset_type_id = at_.id
               ORDER BY sort_order LIMIT 1) AS type_hero_image
            FROM entertainment_asset_types at_
            WHERE at_.is_active = 1
          ''');
        } else {
          data = await DbProvider.query(table);
        }

        for (final row in data) {
          final cloudId = row['cloud_id']?.toString();
          if (cloudId == null || cloudId.isEmpty) continue;

          final int itemPublished = row['type_published'] ?? row['is_published'] ?? 1;
          if (itemPublished == 0) continue;

          // Image fallback chain:
          //   1. item-level image_path / imagePath
          //   2. type-level hero image (lodging/entertainment galleries)
          String? imageUrl = await resolveImageUrl(
            (row['image_path'] ?? row['imagePath'])?.toString(),
          );
          imageUrl ??= await resolveImageUrl(row['type_hero_image']?.toString());

          // Build module-specific metadata. Each module gets ONLY the keys
          // its consumer actually reads (see ModuleMetadata in mbeck_shared).
          final Map<String, dynamic> metadata = {};

          switch (moduleName) {
            case 'retail':
              metadata['barcode']         = row['barcode'];
              metadata['variations_json'] = row['variationsJson'] ?? row['variations_json'];
              break;

            case 'restaurant':
              metadata['preparation_time_mins'] = row['prep_time_minutes'];
              try {
                final itemId = row['id'];
                final groups = await db.query(
                  'restaurant_modifier_groups',
                  where: 'menu_item_id = ?', whereArgs: [itemId],
                );
                final List<Map<String, dynamic>> modifierGroupsWithItems = [];
                for (final group in groups) {
                  final modifiers = await db.query(
                    'restaurant_modifiers',
                    where: 'group_id = ?', whereArgs: [group['id']],
                  );
                  modifierGroupsWithItems.add({
                    'name': group['name'],
                    'min': group['min_selections'],
                    'max': group['max_selections'],
                    'options': modifiers.map((m) => {
                      'name': m['name'],
                      'price': m['price_adjustment'],
                      'available': m['available'],
                    }).toList(),
                  });
                }
                metadata['modifier_groups_json'] = jsonEncode(modifierGroupsWithItems);
              } catch (e) {
                debugPrint('⚠️ Failed to load restaurant modifiers: $e');
              }
              break;

            case 'services':
              metadata['duration_minutes'] = row['duration_minutes'];
              metadata['buffer_minutes']   = row['buffer_minutes'];
              break;

            case 'lodging':
              metadata['capacity']        = row['type_capacity']        ?? row['capacity'];
              metadata['amenities']       = row['type_amenities']       ?? row['amenities'];
              metadata['rate_per_night']  = row['type_rate_per_night']  ?? row['rate_per_night'];
              metadata['rate_per_week']   = row['type_rate_per_week']   ?? row['rate_per_week'];
              metadata['rate_per_month']  = row['type_rate_per_month']  ?? row['rate_per_month'];
              metadata['room_type']       = row['type_name'];
              // Full gallery (uploaded to storage). Limit to 8 to keep payload sane.
              try {
                final typeId = row['room_type_id'];
                if (typeId != null) {
                  final gallery = await db.query(
                    'lodging_room_type_images',
                    where: 'room_type_id = ?', whereArgs: [typeId],
                    orderBy: 'sort_order ASC', limit: 8,
                  );
                  final List<String> urls = [];
                  for (final g in gallery) {
                    final u = await resolveImageUrl(g['image_path']?.toString());
                    if (u != null) urls.add(u);
                  }
                  if (urls.isNotEmpty) metadata['images'] = urls;
                }
              } catch (e) {
                debugPrint('⚠️ Lodging gallery resolve failed: $e');
              }
              break;

            case 'entertainment':
              metadata['rate_per_hour']  = row['type_rate_per_hour']  ?? row['rate_per_hour'];
              metadata['flat_rate']      = row['type_flat_rate']      ?? row['flat_rate'];
              metadata['asset_type']     = row['type_asset_type']     ?? row['asset_type'];
              metadata['type_name']      = row['type_name'];
              try {
                final typeId = row['asset_type_id'];
                if (typeId != null) {
                  final gallery = await db.query(
                    'entertainment_asset_type_images',
                    where: 'asset_type_id = ?', whereArgs: [typeId],
                    orderBy: 'sort_order ASC', limit: 8,
                  );
                  final List<String> urls = [];
                  for (final g in gallery) {
                    final u = await resolveImageUrl(g['image_path']?.toString());
                    if (u != null) urls.add(u);
                  }
                  if (urls.isNotEmpty) metadata['images'] = urls;
                }
              } catch (e) {
                debugPrint('⚠️ Entertainment gallery resolve failed: $e');
              }
              break;
          }

          metadata.removeWhere((k, v) => v == null);

          // Pricing fallback chain — module-aware so we don't accidentally use
          // a per-night rate for a retail item.
          final num price = (() {
            switch (moduleName) {
              case 'retail':
              case 'restaurant':
                return (row['price'] ?? row['sellingPrice'] ?? 0) as num;
              case 'services':
                return (row['price'] ?? 0) as num;
              case 'lodging':
                return (row['type_rate_per_night'] ?? row['rate_per_night'] ?? 0) as num;
              case 'entertainment':
                return (row['type_rate_per_hour']
                     ?? row['rate_per_hour']
                     ?? row['type_flat_rate']
                     ?? row['flat_rate']
                     ?? 0) as num;
              default:
                return 0;
            }
          })();

          itemsToUpsert.add({
            'id': cloudId,
            'shop_id': cloudShopId,
            'module_source': moduleName,
            'name': (row['type_name'] ?? row['name'])?.toString() ?? 'Unnamed Item',
            'description': (row['type_description']
                          ?? row['description']
                          ?? row['specification'])?.toString(),
            'price': price,
            'original_price': row['originalPrice'],
            'image_url': imageUrl,
            'category': (row['type_category'] ?? row['category'])?.toString(),
            'is_published': isPublishedOnline == true && itemPublished == 1,
            'stock': row['stock'],
            'metadata': metadata,
          });
        }
      } catch (e) {
        debugPrint('⚠️ Skipped syncing $table: $e');
      }
    }

    if (activeModules.contains('retail')) await loadModuleData('inventory', 'retail');
    if (activeModules.contains('restaurant')) await loadModuleData('restaurant_menu', 'restaurant');
    if (activeModules.contains('services')) await loadModuleData('services_catalog', 'services');
    if (activeModules.contains('lodging')) await loadModuleData('lodging_rooms', 'lodging');
    if (activeModules.contains('entertainment')) await loadModuleData('entertainment_assets', 'entertainment');

    if (itemsToUpsert.isNotEmpty) {
      const batchSize = 100;
      for (var i = 0; i < itemsToUpsert.length; i += batchSize) {
        final end = (i + batchSize < itemsToUpsert.length) ? i + batchSize : itemsToUpsert.length;
        final batch = itemsToUpsert.sublist(i, end);
        await supabase.from('marketplace_items').upsert(batch);
      }
      debugPrint('✅ Published ${itemsToUpsert.length} items to unified marketplace cloud.');
    } else {
      debugPrint('☁️ No items to publish. Skipping marketplace items.');
    }

    try {
      await supabase.rpc('log_analytics_event', params: {
        'p_event_name': 'SHOP_PUBLISHED',
        'p_platform': 'seller',
        'p_shop_id': cloudShopId,
        'p_details': {
          'items_count': itemsToUpsert.length,
          'shop_name': shopName,
        }
      });
    } catch (e) {
      debugPrint('⚠️ Failed to log analytics: $e');
    }
    } catch (e, stack) {
      debugPrint('❌ Cloud publish error: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }
}
