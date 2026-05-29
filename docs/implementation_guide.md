# MbeckApp — Cloud-Native Credit System
## Step-by-Step Implementation Guide for Autonomous Agent

Version: 1.0  
Owner: MbeckApp Core Team  
Audience: Senior Software Engineer / Autonomous AI Agent  
Scope: Offline-first POS → Cloud → Credit → Lender

---

## 0. Agent Profile (MANDATORY)

Before implementation begins, the executing agent MUST exhibit the following characteristics.

### 0.1 Required Agent Characteristics

The agent is NOT a code generator.  
The agent is a **systems implementer**.

The agent MUST:

1. **Operate Autonomously**
   - Break tasks into sub-tasks without being told
   - Make reasonable engineering trade-offs
   - Avoid asking clarifying questions unless blocked

2. **Reason in Systems, Not Features**
   - Always ask: *“How does this affect credit integrity?”*
   - Optimize for auditability, not convenience
   - Prefer deterministic logic over heuristics

3. **Respect Offline-First Constraints**
   - Never introduce hard cloud dependencies for selling
   - Assume intermittent connectivity
   - Assume low-end Android devices

4. **Treat Data as Financial Evidence**
   - No destructive writes
   - No silent mutations
   - Every correction must be an event

5. **Minimize Surface Area**
   - No unnecessary packages
   - No speculative abstractions
   - Build only what the system needs now

6. **Think Like a Lender**
   - Ask: *“Would I trust this signal with money?”*
   - Prefer boring, explainable metrics
   - Penalize inconsistency harder than low volume

If the agent cannot satisfy the above, STOP.

---

## 1. Phase 1 — Local Event Ledger (FOUNDATION)

### Goal
Convert the existing POS into an **append-only financial ledger**.

Nothing else matters if this is wrong.

---

### 1.1 Create Event Table (SQLite)

Implement the `events` table exactly as specified:

- Append-only
- Never UPDATE payloads
- Only update sync metadata

Key rules:
- Every sale = event
- Every cash count = event
- Every correction = new event

Do NOT sync tables.  
Only sync events.

---

### 1.2 Replace Direct Writes With Events

Refactor:
- Sales
- Inventory changes
- Cash counts

Pattern:
User Action
→ Validate
→ Write Event
→ Derive Local State


Local state (inventory totals, balances) is **derived**, never authoritative.

---

### 1.3 Event Integrity

Each event MUST:
- Have a UUID
- Be hashed
- Be timestamped using device time
- Reference `shop_id` and `device_id`

If event creation fails → action fails.

---

### 1.4 Phase 1 Completion Status ✅

**Status: COMPLETE** (January 2025)

**Implemented Components:**

1. **Event Model** (`lib/models/event.dart`)
   - UUID generation using `uuid` package
   - SHA-256 hashing for integrity
   - Immutable payload structure
   - Sync metadata (synced, sync_attempts, failed)
   - Integrity verification method

2. **Event Service** (`lib/services/event_service.dart`)
   - `emitEvent()` - Primary event emission method
   - `getUnsyncedEvents()` - For Phase 2 sync preparation
   - `markEventSynced()` / `markEventFailed()` - Sync lifecycle management
   - Event querying and integrity verification

3. **Device Service** (`lib/services/device_service.dart`)
   - Persistent `shop_id` and `device_id` management
   - Uses `shared_preferences` for storage
   - Automatic generation on first run

4. **Database Schema** (`lib/db/db_provider.dart`)
   - `events` table with all required fields
   - Indexes on timestamp, event_type, and sync status
   - Database version 13 with migration support
   - In-memory database support for testing

5. **Event Emission Integration**
   - **Sales**: `SALE`, `EXPENSE`, `INCOME` events in `new_transaction_screen.dart`
   - **Inventory**: `INVENTORY_CHANGE` events for stock updates
   - **Cash Counts**: `CASH_COUNT` and `CASH_COUNT_UPDATE` events in `cash_count_screen.dart`
   - **Accounting**: `ACCOUNTING_CLOSING` and `DISPARITY` events in `accounting_screen.dart`
   - **Inventory Management**: `INVENTORY_CREATE`, `INVENTORY_UPDATE`, `INVENTORY_DELETE` events

6. **Architecture Pattern**
   - Events emitted BEFORE database transactions (prevents locking issues)
   - Local state derived from events (backward compatibility maintained)
   - Event-first, state-second pattern enforced

**Key Achievements:**
- ✅ Append-only event ledger operational
- ✅ All critical business actions emit events
- ✅ Event integrity (hashing) verified
- ✅ No database locking conflicts
- ✅ Offline-first maintained (no cloud dependencies)
- ✅ Comprehensive test coverage

**Next Steps:**
- Phase 2: Implement background sync engine to cloud

---

## 2. Phase 2 — Background Sync Engine

### Goal
Safely move financial evidence to the cloud.

---

### 2.1 Sync Rules

- Sync ONLY when:
  - Network exists
  - App is idle OR background worker is running
- Sync in small batches (≤50 events)
- Oldest events first
- Idempotent uploads

---

### 2.2 Failure Handling

If sync fails:
- Increment `sync_attempts`
- Mark event as `failed`
- Retry later

Never drop events.  
Never reorder events.

---

### 2.3 Cloud Endpoint Contract

The agent must implement a backend endpoint that:
- Accepts batched events
- Verifies hashes
- Rejects duplicates
- Stores immutably

Cloud NEVER modifies events.

---

### 2.4 Phase 2 Completion Status ✅

**Status: COMPLETE** (January 2025)

**Implemented Components:**

1. **Sync Service** (`lib/services/sync_service.dart`)
   - Batch sync logic (max 50 events per batch)
   - Oldest events first ordering
   - Network connectivity checking
   - Idempotent uploads using event UUID
   - Hash verification before sync
   - Retry logic with `sync_attempts` tracking
   - Never drops or reorders events

2. **Network Connectivity** (`connectivity_plus` package)
   - Real-time network state checking
   - Graceful handling of offline scenarios
   - Non-blocking sync attempts

3. **Supabase Integration** (`supabase_flutter` package)
   - Cloud database connection
   - Idempotent upsert operations
   - Configurable via environment variables
   - Graceful degradation if not configured

4. **Lifecycle Integration** (`lib/widgets/sync_lifecycle_listener.dart`)
   - Automatic sync on app resume
   - Background sync when app becomes active
   - Non-blocking (doesn't affect UI)
   - Integrated into app root widget

5. **Manual Sync** (`lib/screens/settings_screen.dart`)
   - Manual sync trigger in Settings
   - Sync status display (synced/total events)
   - User feedback on sync results

6. **Supabase Schema** (`SUPABASE_SCHEMA.md`)
   - Complete SQL schema documentation
   - Row Level Security (RLS) policies
   - Indexes for performance
   - Verification queries
   - Setup instructions

7. **Test Coverage** (`test/sync_service_test.dart`)
   - Network connectivity tests
   - Batch size limit tests
   - Event ordering tests
   - Integrity verification tests
   - Sync status tests

**Key Achievements:**
- ✅ Background sync engine operational
- ✅ Idempotent uploads (no duplicates)
- ✅ Hash verification before sync
- ✅ Never drops or reorders events
- ✅ Graceful offline handling
- ✅ Non-blocking sync (doesn't affect POS usage)
- ✅ Comprehensive documentation

**Configuration Required:**
- Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` environment variables
- Run SQL schema in Supabase (see `SUPABASE_SCHEMA.md`)
- Configure RLS policies

**Next Steps:**
- Phase 3: Implement cloud credit engine

---

## 3. Phase 3 — Cloud Credit Engine

### Goal
Transform raw behavior into lender-grade risk signals.

---

### 3.1 Credit Computation Location

IMPORTANT:
- Credit scores are computed in the cloud
- Device holds a READ-ONLY mirror

Reason:
- Prevent tampering
- Ensure lender trust

---

### 3.2 Implement Scorers (Exactly)

The following scorers MUST exist:

1. Sales Consistency (25)
2. Cash Discipline (25)
3. Usage Reliability (20)
4. Stock Health (20)
5. Growth Trend (10)

Rules:
- Scores must be explainable
- No ML at this stage
- Same input → same output

---

### 3.3 Disqualifiers (Hard Stops)

If ANY trigger:
- Frequent shortages
- Missing daily closings
- Deleted sales events
- Clock tampering patterns

Then:
credit_score = 0
status = suspended


No negotiation.

---

## 4. Phase 4 — Credit Profile Sync (Device)

### Goal
Expose trust transparently to the vendor.

---

### 4.1 Read-Only Credit Tables

On device:
- `credit_profile`
- `active_loans`

Rules:
- Never locally modify
- Only overwrite from cloud
- Display exactly what lender sees

---

### 4.2 UX Principle

The credit screen MUST:
- Show score
- Show breakdown
- Show how to improve
- Never promise money

Language should be:
> “Based on your shop behavior…”

Not:
> “You qualify because…”

---

## 5. Phase 5 — Loan Lifecycle (Cloud-Controlled)

### Goal
Allow money flow without becoming a bank.

---

### 5.1 Loan Offer Flow

1. Cloud detects eligibility
2. Cloud generates offer
3. Device displays offer
4. Vendor accepts
5. Cloud calls lender API
6. Lender disburses via M-Pesa

The device NEVER talks to lenders directly.

---

### 5.2 Repayment Enforcement

When loan is active:
- Daily closing becomes mandatory
- POS warns on missed days
- Cloud tracks balance

Optional:
- Auto-deduct percentage from sales

---

## 6. Phase 6 — Package Refactor (Finance-First)

### Goal
Monetize trust, not features.

---

### 6.1 Package Logic

Access is earned, not bought.

Packages unlock:
- Cloud sync
- Credit visibility
- Loan eligibility
- Higher limits

AI scanning is NEVER gated.
It is infrastructure.

---

### 6.2 Package Progression

BASIC → VERIFIED → CREDIT-READY → BUSINESS → ENTERPRISE


Movement depends on:
- Usage
- Discipline
- Consistency

---

## 7. Non-Goals (IMPORTANT)

The agent must NOT:
- Add ML credit models
- Upload images or AI vectors
- Introduce real-time cloud dependency
- Build dashboards prematurely
- Optimize prematurely

---

## 8. Definition of Done

The system is complete when:

- A shop can sell offline for 30 days
- Sync later
- Receive a credit score
- Be offered a loan
- Repay via enforced behavior
- Without human intervention

If any step requires manual cleanup, the design failed.

---

## 9. Mental Model Summary

POS = Evidence Generator
Cloud = Auditor + Risk Engine
Lender = Capital Provider
Vendor = Behavior Subject


You are not building an app.

You are building **financial truth**.