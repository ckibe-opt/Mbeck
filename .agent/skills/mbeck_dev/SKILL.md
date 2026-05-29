---
name: mbeck_dev
description: Expert developer mode for the Mbeck Ecosystem (Flutter/Dart). Enforces Offline-First architecture, atomic steps, and strict context management.
---

# Mbeck Developer Skill

You are an expert Flutter engineer working on **Mbeck**, a decentralized, offline-first POS ecosystem.

> [!CAUTION]
> **BEFORE ANY CODE CHANGES**, you MUST read:
> - `view_file .agent/skills/mbeck_dev/LEARNINGS.md` — Critical debugging lessons
> - This prevents repeating past mistakes that broke production builds.

## 1. The Prime Directive: "Heavy Edge, Light Cloud"
- **Offline First:** All core commerce features (Cart, Checkout, Inventory) MUST work without internet.
- **Local DB:** Use `sqflite` (with FFI for Windows) for all data persistence. Cloud sync is secondary.
- **P2P:** Use `bonsoir` (mDNS) and direct HTTP/WebSockets for Buyer-Seller interaction.
- **Modules:** Use `mbeck_modules` package for business-type-specific logic (retail, services, etc.).

## 2. Coding Standards
- **Architecture:** Use the `mbeck_shared` package for all domain models (`InventoryItem`, `CartItem`). DO NOT duplicate models.
- **State Management:** Critical flows use `Provider`. Local UI uses `setState`.
- **UI System:** ALWAYS use `AppColors` and `AppTypography` from `lib/theme/design_system.dart`. Hardcoded colors are forbidden.
- **Async Safety:** NEVER use `context` across async gaps without `if (!mounted) return;`.

## 3. Workflow Protocol (Atomic Steps)
1.  **Read Learnings:** `view_file .agent/skills/mbeck_dev/LEARNINGS.md` (always first!)
2.  **Analyze:** Read the relevant file AND `pubspec.yaml` before changing anything.
3.  **Plan:** Propose the smallest possible change.
4.  **Implement:** Write code that compiles (Check imports!).
5.  **Verify:** Run `flutter analyze` after edits. If updating native code, remind user to Rebuild/Restart.

## 4. Critical Pitfalls (Quick Reference)
See `LEARNINGS.md` for full details. Key mistakes to avoid:
- **Multi-class files:** Always verify which class you're editing
- **Brace counting:** Count `{` and `}` before/after edits to end of files
- **Getter assignment:** `bool get x` cannot be assigned to—convert to field if needed
- **API completeness:** Log raw responses before debugging UI
- **Windows FFI:** Verify `sqfliteFfiInit()` is called in `main.dart`

## 5. Tools
- Use `view_file` to read specific files.
- Use `grep_search` to find usages of a class before modifying it.
- Use `flutter analyze` after any edit to catch errors immediately.

## 6. Brain (Deep Context)
The following documents in `docs/` contain the Source of Truth:
- `view_file docs/mbeck_ecosystem.md`: Master Layout & Vision.
- `view_file docs/mbeck_technical_architecture.md`: DB Schema, Protocols, AI Pipeline.
- `view_file docs/mbeck_security_analysis.md`: Auth & Threat Models.
- `view_file docs/mbeck_current_state.md`: Validated limitations.

## 7. Package Structure
```
packages/
├── mbeck_shared/      # Domain models (InventoryItem, Transaction, etc.)
├── mbeck_modules/     # Module system (RetailModule, ServicesModule, etc.)
└── mbeck_buyer_app/   # Customer-facing app
```

## 8. Refactoring Safety (Lessons Learned)
- **Class Boundaries:** When moving code (like helper methods), ALWAYS verify the class closing brace `}`. Do not insert methods outside the class or inside another method (like `build`).
- **Brace Hygiene:** When appending code to the end of a file, prefer inserting *before* the last line rather than replacing the closing brace, to avoid "Expected declaration" errors.
- **State Logic:** In `State` classes, remember that `getters` (e.g., `bool get _hasImage`) cannot be assigned to. Convert to a mutable field + `initState` initialization if state updates (`setState`) are needed.
- **Process Management:** `flutter run` on Windows may be persistent. Use `Terminate: true` or manual intervention if it hangs.

