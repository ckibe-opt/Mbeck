# Critical Learnings for Mbeck Development

> [!CAUTION]
> **MANDATORY READING.** These are hard-won lessons from production debugging.  
> Ignoring these patterns will lead to broken builds and wasted time.

---

## Code Placement Errors

### 1. Multi-Class File Editing
**Problem:** Files often contain multiple classes (e.g., `Screen` + `FormDialog`). Edits get inserted into the wrong class.

**Fix:**
- **ALWAYS** use `view_file` to find the exact line range of the target class
- Verify class name in the surrounding context before inserting methods
- Check that your edit lands between the class's opening `{` and closing `}`

### 2. The "Off-by-One Brace" Error
**Problem:** When appending methods to end of a class:
- Missing closing `}` for the `build` method
- Extra `}` at end of file closing the class prematurely

**Fix:**
- Count braces before and after your edit
- Prefer inserting *before* the final `}` rather than replacing it
- After complex edits, run `flutter analyze` immediately

### 3. Code Duplication from Automated Edits
**Problem:** Tool-assisted edits sometimes duplicate entire code blocks, causing "Getters, setters and methods can't be declared to be 'const'" errors.

**Fix:**
- After multi-replace or large text blocks, visually inspect file structure
- Look for duplicate constructors, comments, or import blocks

---

## State Management Errors

### 4. Getter vs Field Assignment
**Problem:** `bool get _hasImage => ...` cannot be assigned to. Dart does not allow `_hasImage = true`.

**Fix:**
- Check if target is a getter before writing assignment logic
- Convert to `late bool _hasImage;` + `initState` if state updates are needed

### 5. Variable Scoping During Refactoring
**Problem:** Partial file replacements accidentally delete variable declarations but keep usage.

**Fix:**
- After `replace_file_content`, verify first use of each variable is a declaration
- Check try/catch block balance

---

## API & Data Flow Errors

### 6. API Response Completeness
**Problem:** UI works but shows no data. Root cause: backend API omits fields from response.

**Fix:**
- **ALWAYS** log raw API response before debugging widget code
- Verify SQL SELECT includes all needed columns
- Verify JSON map includes all fields

### 7. Offline-First Data Sync Gaps
**Problem:** Different subsystems read from different storage (e.g., UI from SharedPrefs, Server from SQLite).

**Fix:**
- Implement `_syncToLocalDb` to propagate data between storage islands
- Add fallback paths: if SQLite empty, read from AuthService cache

---

## UI Layout Errors

### 8. Overflow on Small Screens
**Problem:** "Yellow and Black Tape" overflow errors with long text.

**Fix:**
- Wrap price labels in `FittedBox(fit: BoxFit.scaleDown)`
- Use `maxLines` + `TextOverflow.ellipsis` for variable text
- Never assume text will fit—design defensively

---

## Platform-Specific Errors

### 9. Windows FFI Database
**Problem:** `sqfliteFfiInit()` not called → database operations fail silently.

**Fix:**
- Verify `main.dart` calls `sqfliteFfiInit()` for Windows/Linux
- Always check platform before using FFI

### 10. `:memory:` Database Pathing
**Problem:** Joining `:memory:` with directory path creates invalid path on Windows.

**Fix:**
- Handle `:memory:` as a top-level case BEFORE platform-specific path joining

### 11. Unit Testing with Platform Channels
**Problem:** `MissingPluginException` when tests use `FlutterSecureStorage`.

**Fix:**
```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() {
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => 'mock_key');
  });
}
```

---

## AI/Matching Logic

### 12. Ecosystem Consistency
**Problem:** Different matching logic in Seller vs Buyer apps causes unpredictable UX.

**Fix:**
- Unify AI matching logic (e.g., 10% adaptive cutoff) across entire ecosystem
- Test both apps when changing matching parameters

---

## Process Errors

### 13. Windows Flutter Process Hangs
**Problem:** `flutter run` on Windows may persist and block subsequent runs.

**Fix:**
- Use `Terminate: true` when stopping via `send_command_input`
- Or manually kill process if it hangs

### 14. Settings Screen Displacement
**Problem:** Adding new settings sections accidentally hides or displaces existing ones.

**Fix:**
- After adding settings, verify ALL existing sections are still visible
- Check conditional visibility logic (e.g., `_isOwner` checks)

---

## Module System Errors

### 15. Class Constructor Signature Mismatch
**Problem:** When creating new module classes, using wrong parameter names based on assumptions rather than checking actual signatures.

Example errors:
```
// WRONG - assumed parameters:
ModuleScreen(id: 'x', title: 'Y', iconName: 'z', routePath: '/path')

// CORRECT - actual parameters:
ModuleScreen(route: '/path', builder: (_) => Widget(), icon: Icons.x, label: 'Y')
```

**Fix:**
- **ALWAYS** view the source file of a class before using its constructor
- Never assume parameter names - check `required` parameters
- Use `view_file` on the class definition first

### 16. Required Handler Functions
**Problem:** `RouteDefinition` requires a `handler` function, not just route metadata.

```dart
// WRONG:
RouteDefinition(method: 'GET', path: '/api', requiresAuth: false)

// CORRECT:
RouteDefinition(method: 'GET', path: '/api', handler: myHandlerFn)
```

**Fix:**
- When defining API routes, always provide handler functions
- Use placeholder handlers returning 501 if implementation is pending
- Check if `requiresAuth` exists or is handled differently (e.g., middleware)

### 17. Missing Package Imports
**Problem:** After adding handler functions that use `Request`/`Response`, forgot to import `shelf`.

**Fix:**
- When using types from external packages, add imports immediately
- If using `shelf` types (Request, Response), add: `import 'package:shelf/shelf.dart';`
- Run `flutter analyze` after each structural change

### 18. Verify Before Complex Class Creation
**Problem:** Creating a 300+ line module class with many components, only to find mismatches during analysis.

**Fix:**
- For new module classes, first create a minimal version and verify it compiles
- Add features incrementally, running `flutter analyze` after each major addition
- Review existing module implementations (e.g., `RetailModule`) as a template

---

## Buyer App Integration

### 19. Shop Session Module Detection
**Problem:** Buyer app needs to adapt UI based on seller's enabled modules, but module info isn't fetched during connection.

**Fix:**
- Extend `ShopSessionProvider` to call `/api/v1/info` during connection
- Store `enabledModules` and `businessType` in provider
- Add convenience getters like `isRestaurant` for UI conditionals
- Reset module state on disconnect

### 20. Cross-App Model Compatibility
**Problem:** Using `InventoryItem` with wrong parameter names (`costPrice` instead of `originalPrice`, `quantity` instead of `stock`).

**Fix:**
- **ALWAYS** view shared model source before instantiating
- Run `flutter analyze` on buyer app separately - it has different dependencies
- Check `mbeck_shared` package for canonical model definitions

### 21. Adaptive Home Screen Pattern
**Problem:** Need to show different home screens based on connected shop type (retail vs restaurant vs services).

**Fix:**
```dart
@override
Widget build(BuildContext context) {
  final provider = context.watch<ShopSessionProvider>();
  
  // Check module type and redirect
  if (provider.isRestaurant) {
    return const RestaurantMenuScreen();
  }
  if (provider.isServices) {
    return const ServiceBrowseScreen();
  }
  
  // Default: retail inventory
  return _buildRetailHome();
}
```

---

## UI/UX Patterns

### 22. Order Type Selection Cards
**Problem:** Radio buttons feel dated for order type selection (dine-in/takeaway).

**Fix:**
- Use large tappable cards with icons
- Show selected state with border + background color change
- Add subtle elevation change on selection

### 23. Stepper for Multi-Step Flows
**Problem:** Long forms overwhelm users (e.g., booking flow with date, time, details).

**Fix:**
- Use Flutter's `Stepper` widget with `StepState` management
- Validate each step before allowing continue
- Show summary in final step before confirmation

### 24. Status Color Coding Convention
**Problem:** Inconsistent status colors across screens.

**Standard:**
| Status | Color |
|---|---|
| pending | Orange |
| confirmed | Green |
| completed | Blue |
| cancelled | Red |
| no_show | Grey |

---

## Performance

### 25. Caching Service/Menu Lookups
**Problem:** Repeated database queries for service/menu names in list views.

**Fix:**
```dart
Map<int, Map<String, dynamic>> _servicesCache = {};

Future<void> _loadData() async {
  final services = await DbProvider.query('services_catalog');
  _servicesCache = {
    for (final s in services) (s['id'] as int): s
  };
}
```

---

## Debugging & On-Device Testing

### 26. Module Base Class Signature Mismatch
**Problem:** New module class compilation fails silently with "Gradle failed" until running `dart analyze` directly on the package.

**Symptoms:**
- Gradle build fails with truncated error messages
- Terminal output shows partial class name references

**Fix:**
- **ALWAYS** verify module interface against `MbeckModule` abstract class:
  - `migrationSQL` not `databaseMigrations`
  - `onActivate(dynamic db, String shopId)` not `onActivate()`
  - `validateConfig` returns `String?` not `bool`
- Run `dart analyze packages/mbeck_modules/lib` for cleaner error output
- Create minimal subclass first, then expand incrementally

### 27. RenderFlex Overflow Warnings
**Problem:** "A RenderFlex overflowed by X pixels" errors during runtime.

**Causes:**
- Column without bounded height
- Unbounded text in constrained space
- Fixed-size widgets in variable containers

**Quick Fixes:**
1. Wrap Column with `Expanded` or `Flexible` when inside Row/Column
2. Use `SingleChildScrollView` for variable content
3. Add `overflow: TextOverflow.ellipsis` for text
4. Check padding/margins don't exceed container bounds

### 28. Running Multiple Apps Simultaneously
**Tip:** When testing seller-buyer communication:
- Run seller on mobile device: `flutter run -d <device_id>`
- Run buyer on Windows: `flutter run -d windows`
- Check discovery via logs: "Bonsoir discovery" and "Found X shops"
- Both must be on same network/WiFi

### 29. Flutter Clean Before Major Changes
**Problem:** Cached build artifacts can cause phantom errors after structural changes.

**When to clean:**
- After modifying pubspec.yaml
- After changing module exports
- After Gradle build failures with unclear errors
- After package structure changes

**Command:**
```bash
flutter clean && flutter pub get
```

### 30. Module Database Tables Missing
**Problem:** `DatabaseException: no such table: restaurant_menu` / `services_catalog` at runtime.

**Root Cause:**
- Module classes define `migrationSQL` with CREATE TABLE statements
- BUT DbProvider wasn't executing these migrations during initialization
- Module system tables (`shop_modules`, `module_features`) were created, but not module-specific data tables

**Fix:**
Added `_runModuleMigrations()` method to `DbProvider` that creates:
- `restaurant_menu` - Menu items
- `restaurant_orders` - Order queue
- `services_catalog` - Service definitions
- `services_staff` - Staff members
- `services_bookings` - Appointments

**Lesson:**
When adding a new module, ensure its tables are added to `DbProvider._runModuleMigrations()`. The module's `migrationSQL` getter is currently not auto-executed.

### 31. Modular Onboarding Flow Pattern
**Pattern:** First-launch business type selection that controls app navigation.

**Components:**
1. `OnboardingService` - SharedPreferences for onboarding state + module selection
2. `BusinessTypeSelectorScreen` - Visual card-based multi-select
3. `ModuleGuard` widget - Conditional rendering based on enabled modules
4. Dynamic navigation in `home_screen.dart`

**Flow:**
```
main.dart → AuthWrapper → OnboardingService.isComplete()
                              ↓ false
                        BusinessTypeSelectorScreen
                              ↓ completeOnboarding()
                        HomeScreen (module-aware nav)
```

**Key Code:**
```dart
// In home_screen.dart
if (modules.contains('retail')) {
  items.add(_NavItem(icon: Icons.inventory, label: 'Inventory'));
  screens.add(InventoryScreen());
}
```

### 32. Comprehensive Conditional UI Rendering Pattern
**Pattern:** Every screen must load modules and conditionally render features.

**Screens Modified:**
| Screen | Retail | Services | Restaurant |
|--------|--------|----------|------------|
| Dashboard operations grid | Profits, Restock | Services, Calendar | Menu, Orders |
| Reports 4th tab | Items Sold | Appointments | Orders |
| Settings publish option | Inventory to Cloud | Services to Cloud | Menu to Cloud |
| Settings AI option | Check for AI Model Updates | ❌ Hidden | ❌ Hidden |
| NewTransaction | Scan Item button | ❌ Hidden | ❌ Hidden |

**Implementation Pattern:**
```dart
class _MyScreenState extends State<MyScreen> {
  List<String> _enabledModules = ['retail']; // Default fallback
  
  @override void initState() {
    super.initState();
    _loadModules();
  }
  
  Future<void> _loadModules() async {
    final modules = await OnboardingService.getSelectedModules();
    if (mounted) setState(() => _enabledModules = modules);
  }
  
  @override Widget build(BuildContext context) {
    return Column(children: [
      // CORE - Always show
      CoreWidget(),
      
      // RETAIL ONLY
      if (_enabledModules.contains('retail')) ...[
        RetailWidget1(),
        RetailWidget2(),
      ],
      
      // SERVICES ONLY
      if (_enabledModules.contains('services'))
        ServicesWidget(),
    ]);
  }
}
```

**Key Files:**
- `OnboardingService.getSelectedModules()` - Source of truth
- `home_screen.dart` - Nav bar + operations grid
- `reports_screen.dart` - Dynamic 4th tab
- `settings_screen.dart` - Data Management options
- `new_transaction_screen.dart` - AI Scanner button

**Lesson:** When adding new features, ALWAYS check `_enabledModules.contains('module_id')` before rendering retail/services/restaurant-specific UI.

---

## Supabase Cloud Sync Integration

### 33. Module-Aware Cloud Sync Architecture
**Pattern:** Sync services should check installed modules before syncing data.

**Components:**
1. `ModuleSyncService` - Central sync dispatcher based on enabled modules
2. `BackgroundSyncService` - Periodic timer + manual trigger
3. `SubscriptionService` - Billing API + payment recording

**Sync Flow:**
```dart
// Check modules first, then sync only relevant data
static Future<Map<String, dynamic>> syncAllModuleData() async {
  final modules = await OnboardingService.getSelectedModules();
  
  if (modules.contains('retail')) {
    await syncRetailProducts();
  }
  if (modules.contains('services')) {
    await syncServicesCatalog();
  }
  // etc.
}
```

### 34. Service File Requirements
**Problem:** Services that hit Supabase need proper initialization checks.

**Fix:**
```dart
static SupabaseClient? _getSupabaseClient() {
  try {
    return Supabase.instance.client;
  } catch (e) {
    debugPrint('⚠️ Supabase not initialized: $e');
    return null;
  }
}
```
- Always null-check client before use
- Return gracefully if Supabase not configured
- Don't block offline functionality

### 35. AppTypography Getter Availability
**Problem:** Used `AppTypography.titleMedium` which doesn't exist.

**Available getters:**
- `AppTypography.titleLarge`
- `AppTypography.textTheme.headlineLarge`
- `AppTypography.textTheme.bodyMedium`
- etc.

**Fix:** Check design_system.dart for actual getters before using.

### 36. Cross-Package Import Paths
**Problem:** Buyer app importing from seller app via relative path (`../../../../lib/services/`) breaks on some builds.

**Fix:**
- Make buyer app self-contained by embedding service code inline
- Or use `mbeck_shared` package for truly shared code
- Never rely on relative imports crossing package boundaries

### 37. Supabase Table Schema Awareness
**Pattern:** When querying Supabase, match exact column names from migrations.

| Table | Key Columns |
|-------|-------------|
| `inventory` | `name`, `sellingPrice`, `stock`, `shop_id`, `is_published` |
| `services_catalog` | `service_name`, `price`, `shop_id`, `is_published` |
| `restaurant_menu` | `item_name`, `price`, `category`, `shop_id`, `is_published` |
| `shop_modules` | `shop_id`, `module_id`, `is_active`, `installed_at` |
| `subscriptions` | `shop_id`, `modules`, `amount`, `status`, `next_billing_date` |

**Lesson:** Before writing queries, check SQL migrations for exact column names.

### 39. PowerShell Command Syntax
**Problem:** PowerShell doesn't support `&&` for command chaining or `head` for output limiting.

**Fix:**
```powershell
# WRONG (bash syntax)
cd folder && flutter analyze

# CORRECT (PowerShell)
Set-Location folder; flutter analyze
# OR just specify -Cwd in run_command
```

- Use `;` instead of `&&` for PowerShell
- Don't use `head -50` - not available on Windows
- Specify working directory via tool parameter instead of `cd`

---

## Database Migrations

### 40. Idempotent RLS Policies
**Problem:** `CREATE POLICY` fails if policy already exists (Error 42710). `IF NOT EXISTS` is not supported for policies in PostgreSQL < 9 (Supabase uses newer, but syntax varies).

**Fix:**
```sql
DROP POLICY IF EXISTS "Policy Name" ON table_name;
CREATE POLICY "Policy Name" ON table_name ...
```
- Always drop before creating to ensure script can be re-run safely.

### 41. Foreign Key Type Mismatch
**Problem:** `shop_id UUID REFERENCES shops(id)` failed because `shops.id` is `TEXT`. Error 42804.

**Fix:**
- **Always** check the schema of the referenced table.
- Use `TEXT` for IDs if the system allows custom/string IDs, even if they look like UUIDs.
- `shop_id TEXT REFERENCES shops(id)` is the correct match.

---

## Payment Integration

### 42. Pre-Logging Payment Transactions
**Problem:** Logging a transaction only *after* success (via callback or finish) risks data loss if the app crashes or network fails mid-flow. Linkage between `shop_id` and `checkout_request_id` is lost.

**Fix:**
1. Generate `checkout_request_id` or log a "Pending" record **BEFORE** initiating the external API call.
2. Store `shop_id`, `amount`, and `module_id` in this pending record.
3. Update the record with the actual external ID (e.g., `CheckoutRequestID`) once the API returns.
4. This ensures the callback (which might not have session data) can look up the correct shop/module.

### 43. Service Imports Verification
**Problem:** `Compiler message: The getter 'XService' isn't defined`.
**Cause:** Copy-pasting code or using new services without adding the import.
**Fix:**
- Manually verify imports when adding new dependencies to a file.
- Don't assume the IDE or previous edits handled it.

### 44. Install Downgrade Handling
**Problem:** `flutter run` fails with `INSTALL_FAILED_VERSION_DOWNGRADE` (Error: ADB exited with exit code 1).
**Cause:** Device has a newer version of the app installed (e.g., release vs debug).
**Fix:** `flutter run` usually attempts to uninstall the old version automatically after failure. Allow the process to continue. If it hangs, manually uninstall from device.

### 45. Flutter DotEnv Config
**Problem:** `Unhandled Exception: Instance of 'FileNotFoundError'` when initializing `dotenv`.
**Cause:** The `.env` file is not included in the app bundle.
**Fix:** Add `.env` to the `assets` section in `pubspec.yaml`.
    - .env
```

### 46. Multi-Device Debugging Flakiness
**Problem:** ADB errors ("Error retrieving device properties", "Error 255") when multiple devices are connected.
**Cause:** USB bandwidth saturation, poor cables, or ADB server instability.
**Fix:**
- Use high-quality USB cables.
- Connect devices directly to PC ports (avoid hubs).
- Run `flutter devices` to verify visibility before launch.
- Restart ADB server: `adb kill-server && adb start-server`.

### 47. Device "API null" / "unsupported"
**Problem:** `flutter run` fails with `Android null (API null)` or `unsupported` for a connected device.
**Cause:**
- USB Debugging not authorized on the phone (check screen for popup).
- Screen is locked (unlock device).
- Bad USB mode (switch to PTP/File Transfer).
**Fix:** Unlock phone, check for "Allow USB Debugging?" popup, and authorize computer.

---

## Paywall & Feature Gating

### 48. Subscription Tier Gating Pattern
**Problem:** Premium features accessible without subscription check. Each feature needs explicit gating.

**Pattern:**
```dart
// In onTap or action handler:
final shop = await AuthService.getCurrentShop();
if (shop == null || !shop.hasProAccess) {
  PaywallScreen.show(context, featureName: 'Feature Name');
  return;
}
// ... proceed with feature
```

**Key Files:**
- `shop.dart` → `ShopSubscriptionLogic` extension with `hasProAccess`, `maxMenuItems`, `maxServiceItems`
- `paywall_screen.dart` → `PaywallScreen.show(context, featureName:)` static method
- `settings_screen.dart` → All cloud publish / backup features gated

**Tier Limits (FREE):**
| Resource | FREE Limit | PRO/ENTERPRISE |
|----------|-----------|----------------|
| Menu Items | 30 | Unlimited |
| Service Items | 20 | Unlimited |
| Inventory Items | 50 | Unlimited |
| Cloud Sync | ❌ | ✅ |
| Backup & Restore | ❌ | ✅ |

### 49. Dart Extension Method Import Requirement
**Problem:** `The method 'isMenuLimitReached' isn't defined for the type 'Shop'` even though the extension is in `shop.dart`.

**Cause:** Dart extensions must be explicitly imported. Even if `AuthService.getCurrentShop()` returns a `Shop`, the extension methods won't be available unless `shop.dart` is imported in the calling file.

**Fix:**
```dart
import '../../models/shop.dart'; // Required for ShopSubscriptionLogic extension
```

### 50. Supabase bytea Column Hash Prefix
**Problem:** `invalid input syntax for type bytea` when syncing event hashes to Supabase.

**Cause:** `Event.toMap()` serializes hash as plain hex string (`'abc123'`), but Supabase `bytea` columns expect `\x`-prefixed hex.

**Fix:**
```dart
// In _processBatch (sync_service.dart):
toInsert['hash'] = '\\x${event.hash}';
```

**Lesson:** Always check the Supabase column type. `bytea` needs `\x` prefix; `text` does not.

---

## Cross-Module Analytics Integration

### 51. Recording Module Sales to Unified txn Table
**Problem:** Only retail module sales appear in Reports/Accounting. Restaurant orders and service bookings are invisible to analytics.

**Root Cause:** Completing an order/booking only updates its status — no `SALE` event is emitted and no `txn` table row is inserted.

**Fix:** When order/booking status → `completed`:
1. Emit `EventService.emitEvent(eventType: 'SALE', ...)` with `source: 'restaurant'` or `source: 'services'`
2. Insert into `txn` table with `type: 'sale'`
3. For restaurant: also insert `transaction_items` per menu item

**Key Insight:** Reports (`reports_screen.dart`) and Accounting (`accounting_screen.dart`) already query `txn WHERE type = 'sale'` — so once rows are inserted, revenue auto-appears in all analytics. No SQL changes needed for aggregate reports.

```dart
// In _updateOrderStatus when newStatus == 'completed':
await EventService.emitEvent(eventType: 'SALE', payload: {
  'type': 'sale', 'source': 'restaurant', ...
});
await db.insert('txn', {
  'type': 'sale',
  'totalAmount': orderTotal,
  'details': 'Restaurant Order $orderNumber',
  'timestamp': now,
});
```

### 52. Completed Order UI Pattern
**Problem:** Countdown timer is meaningless on completed orders. Completed orders flood the active queue.

**Fix:**
- Replace timer badge with green ✓ "Done" badge for completed orders
- Load completed orders separately with date filter (default: today)
- Add `FilterChip` bar with Today/Yesterday + DatePicker for historical view
- Compare dates by year/month/day (not DateTime equality) for chip selection

```dart
Widget _buildDateChip(String label, DateTime date) {
  final isSelected = _completedFilterDate.year == date.year &&
      _completedFilterDate.month == date.month &&
      _completedFilterDate.day == date.day;
  return FilterChip(
    label: Text(label),
    selected: isSelected,
    onSelected: (_) {
      setState(() => _completedFilterDate = date);
      _loadOrders();
    },
  );
}
```

---

## Background Isolate & Code Removal

### 53. Background Isolate Singleton Separation
**Problem:** `WaiterRingService.instance.addRing()` called in background isolate API handler. UI isolate has a **separate** singleton that never receives the ring.

**Fix:**
- Use the **database as a bridge** between isolates
- In UI isolate, **poll the DB** periodically for new events
- Track `_knownIds` to deduplicate across polls

**Lesson:** Dart isolates do NOT share memory. Singletons in different isolates are independent.

### 54. Batch Code Removal - Search for ALL Callers
**Problem:** Removing methods in batches, some callers survive causing compile errors.

**Fix:**
- After removing a method, **grep for its name** across the entire file
- Remove the method **and** all methods that call it
- Run `flutter analyze` after batch removals to catch survivors