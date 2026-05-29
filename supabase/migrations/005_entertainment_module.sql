-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  MBECK ENTERTAINMENT MODULE - SUPABASE MIGRATION                         ║
-- ║  Version: 1.0.0                                                          ║
-- ║  Date: 2026-02-10                                                        ║
-- ║  Run AFTER 001_modular_system.sql and 002_rls_policies.sql               ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
--
-- INSTRUCTIONS:
-- 1. Go to Supabase Dashboard > SQL Editor
-- 2. Paste and run this entire script
-- 3. Verify tables created in Table Editor


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 1: UPDATE CHECK CONSTRAINTS TO ALLOW 'entertainment'
-- ═══════════════════════════════════════════════════════════════════════════

-- shop_modules: allow 'entertainment' as a valid module_id
ALTER TABLE shop_modules DROP CONSTRAINT IF EXISTS shop_modules_module_id_check;
ALTER TABLE shop_modules ADD CONSTRAINT shop_modules_module_id_check 
  CHECK (module_id IN ('retail', 'services', 'restaurant', 'entertainment'));

-- transactions: allow 'entertainment' as a module_source
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_module_source_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_module_source_check 
  CHECK (module_source IN ('retail', 'services', 'restaurant', 'entertainment'));

-- transactions: allow 'session' as a transaction_type
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_transaction_type_check 
  CHECK (transaction_type IN ('sale', 'booking', 'order', 'refund', 'session'));


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2: ENTERTAINMENT ASSETS TABLE (Cloud Sync)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS entertainment_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id text NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  local_id integer,                          -- maps to SQLite row id
  name text NOT NULL,
  category text NOT NULL DEFAULT 'general',  -- 'Pool', 'Gaming', 'Swimming', etc.
  asset_type text NOT NULL DEFAULT 'hourly' CHECK (asset_type IN ('hourly', 'flat')),
  rate_per_hour decimal(10,2) NOT NULL DEFAULT 0,
  flat_rate decimal(10,2) DEFAULT 0,
  description text,
  image_url text,
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ent_assets_shop ON entertainment_assets(shop_id);
CREATE INDEX IF NOT EXISTS idx_ent_assets_category ON entertainment_assets(shop_id, category);
CREATE INDEX IF NOT EXISTS idx_ent_assets_active ON entertainment_assets(shop_id, is_active);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 3: ENTERTAINMENT SESSIONS TABLE (Cloud Sync)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS entertainment_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id text NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  local_id integer,                          -- maps to SQLite row id
  asset_id uuid REFERENCES entertainment_assets(id) ON DELETE SET NULL,
  customer_name text,
  started_at timestamptz NOT NULL,
  ended_at timestamptz,
  billing_type text NOT NULL DEFAULT 'hourly' CHECK (billing_type IN ('hourly', 'flat')),
  rate decimal(10,2) NOT NULL DEFAULT 0,
  total_amount decimal(10,2) DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ent_sessions_shop ON entertainment_sessions(shop_id);
CREATE INDEX IF NOT EXISTS idx_ent_sessions_asset ON entertainment_sessions(asset_id);
CREATE INDEX IF NOT EXISTS idx_ent_sessions_status ON entertainment_sessions(shop_id, status);
CREATE INDEX IF NOT EXISTS idx_ent_sessions_started ON entertainment_sessions(shop_id, started_at);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4: ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE entertainment_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE entertainment_sessions ENABLE ROW LEVEL SECURITY;

-- Assets: shop members can read, owners/managers can write
DROP POLICY IF EXISTS "Shop members can view assets" ON entertainment_assets;
CREATE POLICY "Shop members can view assets" ON entertainment_assets
FOR SELECT USING (
  shop_id IN (
    SELECT shop_id FROM shop_members 
    WHERE user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Shop managers can manage assets" ON entertainment_assets;
CREATE POLICY "Shop managers can manage assets" ON entertainment_assets
FOR ALL USING (
  shop_id IN (
    SELECT shop_id FROM shop_members 
    WHERE user_id = auth.uid() 
    AND role IN ('OWNER', 'MANAGER')
  )
);

-- Sessions: shop members can read and create, managers can update/delete
DROP POLICY IF EXISTS "Shop members can view sessions" ON entertainment_sessions;
CREATE POLICY "Shop members can view sessions" ON entertainment_sessions
FOR SELECT USING (
  shop_id IN (
    SELECT shop_id FROM shop_members 
    WHERE user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Shop members can create sessions" ON entertainment_sessions;
CREATE POLICY "Shop members can create sessions" ON entertainment_sessions
FOR INSERT WITH CHECK (
  shop_id IN (
    SELECT shop_id FROM shop_members 
    WHERE user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Shop members can update sessions" ON entertainment_sessions;
CREATE POLICY "Shop members can update sessions" ON entertainment_sessions
FOR UPDATE USING (
  shop_id IN (
    SELECT shop_id FROM shop_members 
    WHERE user_id = auth.uid()
  )
);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 5: SUBSCRIPTION TIERS
-- ═══════════════════════════════════════════════════════════════════════════

-- Subscription plans table (defines available tiers)
CREATE TABLE IF NOT EXISTS subscription_plans (
  id text PRIMARY KEY,
  name text NOT NULL,
  description text,
  included_modules text[] NOT NULL DEFAULT ARRAY['retail'],
  max_team_members integer DEFAULT 3,
  max_assets integer,              -- NULL = unlimited
  max_devices integer DEFAULT 2,
  cloud_sync boolean DEFAULT false,
  priority_support boolean DEFAULT false,
  monthly_price_kes decimal(10,2) NOT NULL DEFAULT 0,
  annual_price_kes decimal(10,2),  -- discounted annual price
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Seed the three tiers
INSERT INTO subscription_plans (id, name, description, included_modules, max_team_members, max_assets, max_devices, cloud_sync, priority_support, monthly_price_kes, annual_price_kes) VALUES

-- FREE tier: single module, basic features
('free', 'Free', 'Get started with one module at no cost', 
 ARRAY['retail'], 
 3, 10, 2, false, false, 0, 0),

-- PRO tier: up to 2 modules, cloud sync, more capacity
('pro', 'Pro', 'For growing businesses that need more power', 
 ARRAY['retail', 'restaurant', 'services', 'entertainment'], 
 10, 50, 5, true, false, 799, 7990),

-- ENTERPRISE tier: unlimited modules, priority support, full features
('enterprise', 'Enterprise', 'For multi-unit businesses like Feroz', 
 ARRAY['retail', 'restaurant', 'services', 'entertainment'], 
 50, NULL, 20, true, true, 1999, 19990)

ON CONFLICT (id) DO UPDATE SET
  included_modules = EXCLUDED.included_modules,
  max_team_members = EXCLUDED.max_team_members,
  max_assets = EXCLUDED.max_assets,
  max_devices = EXCLUDED.max_devices,
  cloud_sync = EXCLUDED.cloud_sync,
  priority_support = EXCLUDED.priority_support,
  monthly_price_kes = EXCLUDED.monthly_price_kes,
  annual_price_kes = EXCLUDED.annual_price_kes;


-- Link shops to plans
ALTER TABLE subscriptions 
ADD COLUMN IF NOT EXISTS plan_id text REFERENCES subscription_plans(id) DEFAULT 'free',
ADD COLUMN IF NOT EXISTS max_modules integer DEFAULT 1;

-- Backfill existing subscriptions to free plan
UPDATE subscriptions 
SET plan_id = 'free', max_modules = 1
WHERE plan_id IS NULL;


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 6: ANALYTICS VIEW (Entertainment Revenue)
-- ═══════════════════════════════════════════════════════════════════════════

-- Daily entertainment revenue view
CREATE OR REPLACE VIEW entertainment_daily_revenue AS
SELECT 
  s.shop_id,
  a.category,
  a.name as asset_name,
  DATE(s.ended_at) as session_date,
  COUNT(*) as session_count,
  SUM(s.total_amount) as total_revenue,
  AVG(EXTRACT(EPOCH FROM (s.ended_at - s.started_at)) / 60) as avg_duration_minutes
FROM entertainment_sessions s
JOIN entertainment_assets a ON s.asset_id = a.id
WHERE s.status = 'completed'
GROUP BY s.shop_id, a.category, a.name, DATE(s.ended_at);


-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Run this to verify:
-- SELECT table_name FROM information_schema.tables 
-- WHERE table_schema = 'public' 
-- AND table_name IN ('entertainment_assets', 'entertainment_sessions', 'subscription_plans');

SELECT 'Entertainment Module Migration Complete! 🎮✅' as status;
