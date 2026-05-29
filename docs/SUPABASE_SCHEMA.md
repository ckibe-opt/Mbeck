# Supabase Schema for Phase 2 - Event Sync

## Overview

This document defines the Supabase database schema required for Phase 2 (Background Sync Engine).

**CRITICAL RULES:**
- Events are **immutable** - never UPDATE payloads
- Only sync metadata can be updated
- Hash verification is mandatory
- Duplicate events are rejected (idempotent)

---

## 1. Events Table

### SQL Schema

```sql
-- Events table (immutable event ledger)
CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  payload TEXT NOT NULL,  -- JSON string
  hash TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  shop_id TEXT,
  device_id TEXT,
  synced INTEGER DEFAULT 1,  -- Always 1 in cloud (synced by definition)
  sync_attempts INTEGER DEFAULT 0,
  failed INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_shop_id ON events(shop_id);
CREATE INDEX IF NOT EXISTS idx_events_device_id ON events(device_id);
CREATE INDEX IF NOT EXISTS idx_events_shop_timestamp ON events(shop_id, timestamp);

-- Unique constraint on hash to prevent duplicates
CREATE UNIQUE INDEX IF NOT EXISTS idx_events_hash ON events(hash);
```

### Table Description

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT (PK) | UUID from device (primary key for idempotency) |
| `event_type` | TEXT | Event type (SALE, CASH_COUNT, etc.) |
| `payload` | TEXT | JSON string of event payload |
| `hash` | TEXT | SHA-256 hash of event (for integrity verification) |
| `timestamp` | INTEGER | Unix timestamp (milliseconds) |
| `shop_id` | TEXT | Shop identifier |
| `device_id` | TEXT | Device identifier |
| `synced` | INTEGER | Always 1 in cloud (synced by definition) |
| `sync_attempts` | INTEGER | Number of sync attempts (for analytics) |
| `failed` | INTEGER | Failure flag (0 = success, 1 = failed) |
| `created_at` | TIMESTAMP | Cloud insertion timestamp |

### Constraints

1. **Primary Key**: `id` (UUID from device ensures idempotency)
2. **Unique Hash**: `hash` must be unique (prevents duplicate events)
3. **NOT NULL**: `id`, `event_type`, `payload`, `hash`, `timestamp`

---

## 2. Row Level Security (RLS)

### Policy: Events are append-only

```sql
-- Enable RLS
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Policy: Only authenticated service role can insert
CREATE POLICY "Service role can insert events"
  ON events
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Policy: Service role can read all events
CREATE POLICY "Service role can read events"
  ON events
  FOR SELECT
  TO service_role
  USING (true);

-- Policy: NO UPDATES allowed (immutable)
-- No UPDATE policy = no updates allowed

-- Policy: NO DELETES allowed (immutable)
-- No DELETE policy = no deletes allowed
```

**Note**: In production, you may want to restrict reads to specific shops/devices based on authentication.

---

## 3. Edge Function: Event Sync Handler (Optional)

For additional validation, you can create a Supabase Edge Function:

```typescript
// supabase/functions/sync-events/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const events = await req.json()

    // Validate batch size
    if (events.length > 50) {
      return new Response(
        JSON.stringify({ error: 'Batch size exceeds 50 events' }),
        { status: 400 }
      )
    }

    // Verify hashes
    for (const event of events) {
      // Hash verification logic (implement based on Event model)
      // If hash doesn't match, reject the event
    }

    // Upsert events (idempotent)
    const { data, error } = await supabase
      .from('events')
      .upsert(events, { onConflict: 'id' })

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500 }
      )
    }

    return new Response(
      JSON.stringify({ synced: events.length }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    )
  }
})
```

---

## 4. Setup Instructions

### Step 1: Create Table

Run the SQL schema in Supabase SQL Editor:

1. Go to Supabase Dashboard → SQL Editor
2. Paste the schema SQL
3. Execute

### Step 2: Configure RLS

Run the RLS policies SQL in Supabase SQL Editor.

### Step 3: Get Credentials

1. Go to Supabase Dashboard → Settings → API
2. Copy:
   - Project URL
   - `service_role` key (for server-side operations)
   - `anon` key (for client-side operations, if needed)

### Step 4: Configure Flutter App

Add to your app's configuration:

```dart
// In main.dart or config file
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);
```

**Security Note**: For production, use environment variables or secure storage for credentials.

---

## 5. Verification Queries

### Check event count by shop

```sql
SELECT shop_id, COUNT(*) as event_count
FROM events
GROUP BY shop_id
ORDER BY event_count DESC;
```

### Check unsynced events (should be 0 in cloud)

```sql
SELECT COUNT(*) as unsynced_count
FROM events
WHERE synced = 0;
```

### Check duplicate hashes (should be 0)

```sql
SELECT hash, COUNT(*) as count
FROM events
GROUP BY hash
HAVING COUNT(*) > 1;
```

### Check events by type

```sql
SELECT event_type, COUNT(*) as count
FROM events
GROUP BY event_type
ORDER BY count DESC;
```

---

## 6. Migration Notes

- **No migrations needed** - this is a new table for Phase 2
- Table is append-only (no UPDATE/DELETE operations)
- Future phases may add related tables (credit_profiles, etc.)

---

## 7. Performance Considerations

- **Batch Size**: Max 50 events per sync (enforced in Flutter app)
- **Indexes**: Optimized for timestamp and shop_id queries
- **Partitioning**: Consider partitioning by timestamp for large datasets
- **Archival**: Old events can be archived but never deleted

---

## End of Schema Documentation
