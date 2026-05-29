---
globs: ["test/**/*.dart", "**/*_test.dart"]
description: Rules for debugging Dart/Flutter test failures
---

# Debugging Rules

**BEFORE fixing any test failure, read `LEARNINGS.md` in the project root.**

## Critical Rules

1. **NEVER use PowerShell regex to edit Dart files.** Use `write_to_file` with `Overwrite: true` to rewrite broken files cleanly.

2. **Establish a test baseline FIRST.** Run `flutter test` before making changes. Note the pass/fail count. After your changes, only fix tests YOU broke.

3. **If a test fails with `Supabase.instance` or `MissingPluginException`** — it's a pre-existing test environment issue. Note it and move on.

4. **Import paths:** Use `package:mbeck_shared/mbeck_shared.dart` for shared models. Use `package:mbeck_business/` for app-specific classes. Never use relative imports in tests.

5. **Test setup order matters:** Bindings → SharedPreferences mock → Platform channel mocks → FFI init → DbProvider init → Supabase mock (optional, in try/catch).

6. **If a file has 3+ broken lines, rewrite the entire file** rather than patching line by line.
