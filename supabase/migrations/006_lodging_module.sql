-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  LODGING MODULE - SUPABASE MIGRATION                                     ║
-- ║  Version: 1.0.1                                                          ║
-- ║  Run AFTER 005_entertainment_module.sql                                  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 1: UPDATE CHECK CONSTRAINTS TO ALLOW 'lodging'
-- ═══════════════════════════════════════════════════════════════════════════

-- shop_modules: allow 'lodging' as a valid module_id
ALTER TABLE shop_modules DROP CONSTRAINT IF EXISTS shop_modules_module_id_check;
ALTER TABLE shop_modules ADD CONSTRAINT shop_modules_module_id_check
  CHECK (module_id IN ('retail', 'services', 'restaurant', 'entertainment', 'lodging'));

-- transactions: allow 'lodging' as a module_source
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_module_source_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_module_source_check
  CHECK (module_source IN ('retail', 'services', 'restaurant', 'entertainment', 'lodging'));

-- transactions: allow 'reservation' as a transaction_type
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_transaction_type_check
  CHECK (transaction_type IN ('sale', 'booking', 'order', 'refund', 'session', 'reservation'));


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2: LODGING ROOMS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS lodging_rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id text NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  local_id integer,
  name text NOT NULL,
  room_type text NOT NULL DEFAULT 'standard',
  floor text,
  capacity integer NOT NULL DEFAULT 2,
  rate_per_night decimal(10,2) NOT NULL DEFAULT 0,
  amenities text,
  description text,
  image_url text,
  status text NOT NULL DEFAULT 'available'
    CHECK (status IN ('available', 'occupied', 'cleaning', 'maintenance')),
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lodging_rooms_shop ON lodging_rooms(shop_id);
CREATE INDEX IF NOT EXISTS idx_lodging_rooms_type ON lodging_rooms(shop_id, room_type);
CREATE INDEX IF NOT EXISTS idx_lodging_rooms_status ON lodging_rooms(shop_id, status);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 3: LODGING RESERVATIONS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS lodging_reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id text NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  local_id integer,
  room_id uuid REFERENCES lodging_rooms(id) ON DELETE SET NULL,
  guest_name text NOT NULL,
  guest_phone text,
  guest_email text,
  guest_id_number text,
  check_in_date timestamptz NOT NULL,
  check_out_date timestamptz NOT NULL,
  actual_check_in timestamptz,
  actual_check_out timestamptz,
  nights integer NOT NULL DEFAULT 1,
  rate_per_night decimal(10,2) NOT NULL DEFAULT 0,
  extras_total decimal(10,2) NOT NULL DEFAULT 0,
  total_amount decimal(10,2) NOT NULL DEFAULT 0,
  amount_paid decimal(10,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'confirmed', 'checked_in', 'checked_out', 'cancelled')),
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lodging_res_shop ON lodging_reservations(shop_id);
CREATE INDEX IF NOT EXISTS idx_lodging_res_room ON lodging_reservations(room_id);
CREATE INDEX IF NOT EXISTS idx_lodging_res_status ON lodging_reservations(shop_id, status);
CREATE INDEX IF NOT EXISTS idx_lodging_res_checkin ON lodging_reservations(shop_id, check_in_date);
CREATE INDEX IF NOT EXISTS idx_lodging_res_checkout ON lodging_reservations(shop_id, check_out_date);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4: ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE lodging_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE lodging_reservations ENABLE ROW LEVEL SECURITY;

-- Rooms: shop members can view
DROP POLICY IF EXISTS "Shop members can view lodging rooms" ON lodging_rooms;
CREATE POLICY "Shop members can view lodging rooms" ON lodging_rooms
FOR SELECT USING (
  shop_id IN (
    SELECT shop_id FROM shop_members
    WHERE user_id = auth.uid()
  )
);

-- Rooms: managers can manage
DROP POLICY IF EXISTS "Shop managers can manage lodging rooms" ON lodging_rooms;
CREATE POLICY "Shop managers can manage lodging rooms" ON lodging_rooms
FOR ALL USING (
  shop_id IN (
    SELECT shop_id FROM shop_members
    WHERE user_id = auth.uid()
    AND role IN ('OWNER', 'MANAGER')
  )
);

-- Reservations: shop members can view
DROP POLICY IF EXISTS "Shop members can view reservations" ON lodging_reservations;
CREATE POLICY "Shop members can view reservations" ON lodging_reservations
FOR SELECT USING (
  shop_id IN (
    SELECT shop_id FROM shop_members
    WHERE user_id = auth.uid()
  )
);

-- Reservations: shop members can create
DROP POLICY IF EXISTS "Shop members can create reservations" ON lodging_reservations;
CREATE POLICY "Shop members can create reservations" ON lodging_reservations
FOR INSERT WITH CHECK (
  shop_id IN (
    SELECT shop_id FROM shop_members
    WHERE user_id = auth.uid()
  )
);

-- Reservations: shop members can update (status changes, check-in/out)
DROP POLICY IF EXISTS "Shop members can update reservations" ON lodging_reservations;
CREATE POLICY "Shop members can update reservations" ON lodging_reservations
FOR UPDATE USING (
  shop_id IN (
    SELECT shop_id FROM shop_members
    WHERE user_id = auth.uid()
  )
);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 5: UPDATE SUBSCRIPTION PLANS TO INCLUDE LODGING
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE subscription_plans
SET included_modules = ARRAY['retail', 'restaurant', 'services', 'entertainment', 'lodging']
WHERE id IN ('pro', 'enterprise');


-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

SELECT 'Lodging Module Migration Complete! 🏨✅' as status;
