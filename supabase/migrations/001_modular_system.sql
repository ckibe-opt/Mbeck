-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  MBECK MODULAR SYSTEM - SUPABASE MIGRATION                                ║
-- ║  Version: 1.0.0                                                           ║
-- ║  Date: 2026-02-08                                                         ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
--
-- INSTRUCTIONS:
-- 1. Go to Supabase Dashboard > SQL Editor
-- 2. Paste and run this entire script
-- 3. Verify tables created in Table Editor
-- 4. Run the RLS policies script next


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 1: UPDATE EXISTING SHOPS TABLE (Add Module Columns)
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE shops 
ADD COLUMN IF NOT EXISTS enabled_modules text[] DEFAULT ARRAY['retail'],
ADD COLUMN IF NOT EXISTS shop_type text DEFAULT 'retail',
ADD COLUMN IF NOT EXISTS currency text DEFAULT 'KES';

-- Mark all existing shops as having retail module
UPDATE shops 
SET enabled_modules = ARRAY['retail'], 
    shop_type = 'retail'
WHERE enabled_modules IS NULL OR array_length(enabled_modules, 1) IS NULL;


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2: SHOP_MODULES TABLE (Installation Tracking)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS shop_modules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id text REFERENCES shops(id) ON DELETE CASCADE,
  module_id text NOT NULL CHECK (module_id IN ('retail', 'services', 'restaurant')),
  installed_at timestamptz DEFAULT now(),
  module_version text DEFAULT '1.0.0',
  is_active boolean DEFAULT true,
  UNIQUE(shop_id, module_id)
);

-- Create entries for existing shops (all have retail)
INSERT INTO shop_modules (shop_id, module_id, is_active)
SELECT id, 'retail', true FROM shops
ON CONFLICT (shop_id, module_id) DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 3: SUBSCRIPTIONS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id text REFERENCES shops(id) ON DELETE CASCADE,
  modules text[] DEFAULT ARRAY['retail'],
  total_monthly_cost decimal(10,2) DEFAULT 0,
  billing_cycle_start date,
  billing_cycle_end date,
  payment_status text DEFAULT 'free' CHECK (payment_status IN ('free', 'paid', 'pending', 'failed')),
  payment_method text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(shop_id)
);

-- Create subscription entries for existing shops
INSERT INTO subscriptions (shop_id, modules, payment_status)
SELECT id, ARRAY['retail'], 'free' FROM shops
ON CONFLICT (shop_id) DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4: UPDATE INVENTORY TABLE (Add Cloud Columns)
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE inventory
ADD COLUMN IF NOT EXISTS category text,
ADD COLUMN IF NOT EXISTS barcode text,
ADD COLUMN IF NOT EXISTS is_published boolean DEFAULT false;


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 5: SERVICES MODULE TABLES
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS services_catalog (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id text NOT NULL,
  service_name text NOT NULL,
  description text,
  duration_minutes integer DEFAULT 30,
  price decimal(10,2) NOT NULL,
  category text,
  is_published boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS services_appointments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id text NOT NULL,
  service_id uuid REFERENCES services_catalog(id) ON DELETE SET NULL,
  customer_device_id text,
  customer_name text,
  customer_phone text,
  appointment_time timestamptz NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled', 'no_show')),
  notes text,
  total_amount decimal(10,2),
  created_at timestamptz DEFAULT now()
);

-- Performance index for appointment lookups
CREATE INDEX IF NOT EXISTS idx_appointments_shop_time 
ON services_appointments(shop_id, appointment_time);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 6: RESTAURANT MODULE TABLES
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS restaurant_menu (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id text NOT NULL,
  item_name text NOT NULL,
  description text,
  category text DEFAULT 'main' CHECK (category IN ('appetizer', 'main', 'side', 'dessert', 'beverage', 'special')),
  price decimal(10,2) NOT NULL,
  is_available boolean DEFAULT true,
  is_published boolean DEFAULT false,
  preparation_time_mins integer DEFAULT 15,
  image_url text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS restaurant_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id text NOT NULL,
  table_number text,
  order_type text DEFAULT 'dine_in' CHECK (order_type IN ('dine_in', 'takeaway', 'delivery')),
  order_items jsonb NOT NULL DEFAULT '[]',
  subtotal decimal(10,2),
  tax_amount decimal(10,2) DEFAULT 0,
  total_amount decimal(10,2) NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'preparing', 'ready', 'served', 'paid', 'cancelled')),
  customer_name text,
  customer_phone text,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Performance index for order queue
CREATE INDEX IF NOT EXISTS idx_orders_shop_status 
ON restaurant_orders(shop_id, status, created_at);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 7: UNIVERSAL TRANSACTIONS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id text NOT NULL,
  transaction_type text NOT NULL CHECK (transaction_type IN ('sale', 'booking', 'order', 'refund')),
  module_source text CHECK (module_source IN ('retail', 'services', 'restaurant')),
  total_amount decimal(10,2) NOT NULL,
  currency text DEFAULT 'KES',
  payment_method text,
  customer_device_id text,
  customer_name text,
  module_data jsonb,
  local_signature text,
  created_at timestamptz DEFAULT now()
);

-- Performance index for analytics
CREATE INDEX IF NOT EXISTS idx_transactions_shop_date 
ON transactions(shop_id, created_at);


-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION: Check all tables created
-- ═══════════════════════════════════════════════════════════════════════════

-- Run this query to verify:
-- SELECT table_name FROM information_schema.tables 
-- WHERE table_schema = 'public' 
-- AND table_name IN ('shop_modules', 'subscriptions', 'services_catalog', 
--                    'services_appointments', 'restaurant_menu', 'restaurant_orders', 'transactions');

SELECT 'Migration Complete! ✅' as status;
