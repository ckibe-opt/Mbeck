---
description: Dart and Flutter best practices for Mbeck
glob: "**/*.dart"
---
# Dart & Flutter Rules

1. **Async Safety**: Never use `context` across async gaps without `if (!mounted) return;`.
2. **State Management**: Use `Provider` for globals and `setState` for local UI state.
3. **UI/UX Consistency**: Exclusively use `AppColors` and `AppTypography` from `lib/theme/design_system.dart`. Hardcoded values are prohibited.
