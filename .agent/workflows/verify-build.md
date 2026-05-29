---
description: Run standard flutter analysis and checks
---
# Verify Build Integrity

1. Run `flutter analyze` in the terminal to check for syntax and linting errors.
// turbo
2. Run `dart format --output=none --set-exit-if-changed .` if needed to enforce formatting.
3. Run `flutter test` in the terminal to catch regressions.
