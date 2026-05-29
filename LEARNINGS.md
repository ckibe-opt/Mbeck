# Mbeck Debugging Learnings

> **IMPORTANT**: This document captures hard-won debugging lessons. Read this BEFORE attempting to fix test failures, build errors, or import issues.

---

## 🚨 Lesson 1: NEVER Use PowerShell Regex to Mass-Edit Dart Files

**What happened:** An AI agent spent 30+ tool calls trying to fix test import paths using PowerShell regex replacements (`-replace`, `.Replace()`). Each regex "fix" introduced new bugs:

- `import 'package:mbeck_business/lib/db/db_provider.dart'` — doubled `lib/` path
- `import 'package:shared_preferences/shared_preferences.dart';` injected **inside a function body** instead of at the top of the file
- Duplicate `Supabase.initialize()` calls stacked on top of each other
- `WidgetsFlutterBinding` referenced without an import, causing cascading compilation failures

Each patch created a new error, which triggered another patch, creating an infinite debugging loop across 60+ steps.

**The fix was trivial:** Just **rewrite the 3 broken files from scratch** using `write_to_file` with `Overwrite: true`. Took 3 tool calls instead of 60.

### Rules:
1. **If a file has more than 2-3 broken lines, rewrite it entirely** — don't patch line by line.
2. **Never use PowerShell regex on Dart source files** — whitespace, newlines, and special characters (`{`, `}`, `(`, `)`) in Dart syntax make regex extremely fragile.
3. **After any mass replacement, immediately verify with `flutter test <specific_file>`** — don't run the full suite until individual files compile.

---

## 🚨 Lesson 2: Pre-Existing Failures vs. Your Changes

**What happened:** The agent treated ALL test failures as caused by its changes, including pre-existing failures like:
- `performance_integration_test.dart` failing because `ShopServer.start()` requires `Supabase` initialization that can't be mocked in unit tests
- `device_service_test.dart` asserting persistence of intentionally-temporary IDs

**Rules:**
1. **Before starting work, note how many tests pass/fail** — establish a baseline.
2. **After your changes, only fix tests that YOU broke** — don't chase pre-existing failures.
3. **If a test fails with `Supabase.instance` or `MissingPluginException`, it's a test environment issue, not your bug** — note it and move on.

---

## 🚨 Lesson 3: Import Path Architecture

The Mbeck project has a specific import hierarchy:

| Class | Correct Import |
|-------|---------------|
| `InventoryItem`, `TxnModel`, `TransactionItem`, `ProductVariation`, `ShopThemeConfig` | `package:mbeck_shared/mbeck_shared.dart` |
| `Shop`, `ShopMember`, `Event` | `package:mbeck_business/models/<name>.dart` |
| `DbProvider` | `package:mbeck_business/db/db_provider.dart` |
| `EventService` | `package:mbeck_business/services/event_service.dart` |
| `InventoryService` | `package:mbeck_business/services/inventory_service.dart` |

**Never use relative imports** (`../models/`, `../../lib/`) in test files. Always use `package:` imports.

---

## 🚨 Lesson 4: Test File Setup Order

When writing Flutter tests that use `SharedPreferences`, `Supabase`, or `DbProvider`, the setup order MUST be:

```dart
setUpAll(() async {
  // 1. FIRST: Initialize Flutter bindings
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // 2. SECOND: Mock SharedPreferences BEFORE anything that reads it
  SharedPreferences.setMockInitialValues({});
  
  // 3. THIRD: Mock platform channels
  const MethodChannel('plugins.it_nomads.com/flutter_secure_storage')
      .setMockMethodCallHandler((call) async => null);
  
  // 4. FOURTH: Initialize FFI for sqflite
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  // 5. FIFTH: Initialize in-memory DB
  await DbProvider.init(databaseName: inMemoryDatabasePath);
  
  // 6. LAST: Optional - Initialize Supabase mock (wrap in try/catch)
  try {
    await Supabase.initialize(url: 'https://example.com', anonKey: 'example');
  } catch (_) {}
});
```

**Violating this order** causes `MissingPluginException`, `Binding already initialized`, or `_instance._isInitialized` assertion errors.
