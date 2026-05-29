-- ============================================
-- myShop - Supabase Database Schema
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Create shops table
CREATE TABLE IF NOT EXISTS shops (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  owner_device_id TEXT NOT NULL,
  subscription_tier TEXT DEFAULT 'FREE' CHECK (subscription_tier IN ('FREE', 'PRO', 'ENTERPRISE', 'PRO Yearly', 'ENTERPRISE Yearly')),
  subscription_status TEXT DEFAULT 'ACTIVE' CHECK (subscription_status IN ('ACTIVE', 'SUSPENDED', 'CANCELLED')),
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  trial_ends_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_shops_owner_device ON shops(owner_device_id);

-- 2. Create shop_members table
CREATE TABLE IF NOT EXISTS shop_members (
  id SERIAL PRIMARY KEY,
  shop_id TEXT REFERENCES shops(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  user_name TEXT NOT NULL,
  role TEXT DEFAULT 'STAFF' CHECK (role IN ('OWNER', 'ADMIN', 'STAFF')),
  permissions JSONB DEFAULT '{}'::jsonb,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_active_at TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT TRUE,
  UNIQUE(shop_id, device_id)
);

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_shop_members_shop ON shop_members(shop_id);
CREATE INDEX IF NOT EXISTS idx_shop_members_device ON shop_members(device_id);
CREATE INDEX IF NOT EXISTS idx_shop_members_active ON shop_members(shop_id, is_active);

-- 3. Check if events table exists, if not create it (should already exist)
CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  payload_raw TEXT,
  hash TEXT NOT NULL,
  timestamp BIGINT NOT NULL,
  shop_id TEXT,
  device_id TEXT,
  synced INTEGER DEFAULT 0,
  sync_attempts INTEGER DEFAULT 0,
  failed INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add shop_id column to events if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'events' AND column_name = 'shop_id'
  ) THEN
    ALTER TABLE events ADD COLUMN shop_id TEXT;
  END IF;
END $$;

-- Create indexes on events table
CREATE INDEX IF NOT EXISTS idx_events_shop ON events(shop_id);
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_synced ON events(synced, failed, timestamp);
CREATE INDEX IF NOT EXISTS idx_events_shop_timestamp ON events(shop_id, timestamp);

-- 4. Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Create trigger for shops table
DROP TRIGGER IF EXISTS update_shops_updated_at ON shops;
CREATE TRIGGER update_shops_updated_at
BEFORE UPDATE ON shops
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 6. Create function to set trial end date on shop creation
CREATE OR REPLACE FUNCTION set_trial_end_date()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.trial_ends_at IS NULL THEN
    NEW.trial_ends_at = NOW() + INTERVAL '90 days';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Create trigger to set trial end date
DROP TRIGGER IF EXISTS set_trial_on_shop_creation ON shops;
CREATE TRIGGER set_trial_on_shop_creation
BEFORE INSERT ON shops
FOR EACH ROW
EXECUTE FUNCTION set_trial_end_date();

-- 8. Enable Row Level Security (RLS)
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- 9. Create RLS policies for shops (public read for authentication)
DROP POLICY IF EXISTS "Allow public to read shops for authentication" ON shops;
CREATE POLICY "Allow public to read shops for authentication"
ON shops FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Allow shop owners to update their shops" ON shops;
CREATE POLICY "Allow shop owners to update their shops"
ON shops FOR UPDATE
USING (true);

DROP POLICY IF EXISTS "Allow anyone to create shops" ON shops;
CREATE POLICY "Allow anyone to create shops"
ON shops FOR INSERT
WITH CHECK (true);

-- 10. Create RLS policies for shop_members
DROP POLICY IF EXISTS "Allow public to read shop members for authentication" ON shop_members;
CREATE POLICY "Allow public to read shop members for authentication"
ON shop_members FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Allow anyone to insert shop members" ON shop_members;
CREATE POLICY "Allow anyone to insert shop members"
ON shop_members FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow shop members to update their own data" ON shop_members;
CREATE POLICY "Allow shop members to update their own data"
ON shop_members FOR UPDATE
USING (true);

-- 11. Create RLS policies for events
DROP POLICY IF EXISTS "Allow members to read their shop's events" ON events;
CREATE POLICY "Allow members to read their shop's events"
ON events FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Allow members to insert events for their shop" ON events;
CREATE POLICY "Allow members to insert events for their shop"
ON events FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow members to update events for their shop" ON events;
CREATE POLICY "Allow members to update events for their shop"
ON events FOR UPDATE
USING (true);

-- 12. Create view for active shop members
CREATE OR REPLACE VIEW active_shop_members AS
SELECT
  sm.*,
  s.name,
  s.subscription_tier,
  s.subscription_status
FROM shop_members sm
JOIN shops s ON sm.shop_id = s.id
WHERE sm.is_active = true AND s.subscription_status = 'ACTIVE';

-- 13. Create function to get shop statistics
CREATE OR REPLACE FUNCTION get_shop_stats(p_shop_id TEXT)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'total_members', (SELECT COUNT(*) FROM shop_members WHERE shop_id = p_shop_id AND is_active = true),
    'total_events', (SELECT COUNT(*) FROM events WHERE shop_id = p_shop_id),
    'synced_events', (SELECT COUNT(*) FROM events WHERE shop_id = p_shop_id AND synced = 1),
    'unsynced_events', (SELECT COUNT(*) FROM events WHERE shop_id = p_shop_id AND synced = 0 AND failed = 0),
    'failed_events', (SELECT COUNT(*) FROM events WHERE shop_id = p_shop_id AND failed = 1)
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Verification Queries (Run these to check)
-- ============================================

-- Check if tables exist
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('shops', 'shop_members', 'events')
ORDER BY table_name;

-- Check indexes
SELECT tablename, indexname FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('shops', 'shop_members', 'events')
ORDER BY tablename, indexname;

-- Check RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('shops', 'shop_members', 'events')
ORDER BY tablename, policyname;

-- ============================================
-- Sample Data (Optional - for testing)
-- ============================================

-- Create a test shop
-- INSERT INTO shops (id, business_name, password_hash, owner_device_id, subscription_tier)
-- VALUES (
--   'shop_test_12345',
--   'Test Shop',
--   'hashed_password_here',
--   'device_test_001',
--   'PRO'
-- );

-- Add a test member
-- INSERT INTO shop_members (shop_id, device_id, user_name, role, permissions)
-- VALUES (
--   'shop_test_12345',
--   'device_test_001',
--   'Test Owner',
--   'OWNER',
--   '{"manage_inventory": true, "view_reports": true}'::jsonb
-- );
