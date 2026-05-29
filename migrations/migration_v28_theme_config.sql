-- Migration V28: Create Shops Table and Add Theme/Trust
-- Ensure shops table exists
CREATE TABLE IF NOT EXISTS shops (
  id TEXT PRIMARY KEY,
  business_name TEXT,
  owner_device_id TEXT,
  owner_id TEXT,
  chain_id TEXT,
  subscription_tier TEXT DEFAULT 'FREE',
  subscription_status TEXT DEFAULT 'ACTIVE',
  joined_at TEXT,
  trial_ends_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  theme_config TEXT DEFAULT '{}',
  trust_score REAL DEFAULT 0.0
);

-- Migrate legacy shop_settings to shops if needed
-- We assume shop_settings might have some data
INSERT OR IGNORE INTO shops (id, business_name, updated_at, theme_config)
SELECT shop_id, shop_name, updated_at, branding FROM shop_settings;

-- Drop legacy table if desired, or keep for safety. keeping for now.
