---
description: Mbeck Offline-First & Architecture Standards
always_on: true
---
# Always On Rules for Mbeck

1. **Heavy Edge, Light Cloud**: Local `sqflite` databases are the primary source of truth. Offline functionality is mandatory.
2. **Atomic Steps**: Make minimal, reversible changes and frequently verify builds.
3. **No Direct Cloud Logic**: Do not bypass local databases for P2P or basic offline operations.
