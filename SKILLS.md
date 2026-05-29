# Antigravity Toolbox (SKILLS.md)

This document lists the tools, commands, and skills the agent has permission to use in the Mbeck workspace:

## Core Skills
- **`mbeck_dev`**: Expert developer mode for analyzing Flutter code, reading `LEARNINGS.md`, enforcing offline-first strategies, and implementing changes atomically. 
  - *Location*: `.agent/skills/mbeck_dev/SKILL.md`

## Permitted Commands & Workflows
- **Flutter & Dart CLI**: Permission to run `flutter pub get`, `flutter analyze`, `flutter test`, `dart format`, etc.
- **SQLite Database Utilities**: Permission to read and analyze local SQLite databases for debugging syncing issues.
- **mDNS / Bonsoir Debugging**: Network analysis to verify P2P broadcast functionality on LAN.
- **Git Actions**: Permission to review git diffs, resolve merge conflicts, and manage branch changes for the project.

## Prohibited Actions
- Bypassing the local `sqflite` architecture or hardcoding network-dependent flows for critical commerce features.
- Introducing large multi-file refactors without user checkpointing.
- Duplicating domain models from `mbeck_shared` into local apps.
