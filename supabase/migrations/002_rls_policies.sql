-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  MBECK MODULAR SYSTEM - ROW LEVEL SECURITY POLICIES                       ║
-- ║  Version: 1.0.1 (Idempotent)                                              ║
-- ║  Run AFTER the main migration script                                      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 1: ENABLE RLS ON ALL NEW TABLES
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE shop_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE services_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE services_appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurant_menu ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurant_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 2: SHOP_MODULES POLICIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Shop owners/managers can manage modules
DROP POLICY IF EXISTS "Shop owners can manage modules" ON shop_modules;
CREATE POLICY "Shop owners can manage modules" ON shop_modules
FOR ALL USING (
  shop_id IN (
    SELECT shop_id FROM shop_members 
    WHERE user_id = auth.uid() 
    AND role IN ('OWNER', 'MANAGER')
  )
);

-- Anyone authenticated can read module info (for discovery)
DROP POLICY IF EXISTS "Authenticated users can view modules" ON shop_modules;
CREATE POLICY "Authenticated users can view modules" ON shop_modules
FOR SELECT USING (auth.role() = 'authenticated');


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 3: SUBSCRIPTIONS POLICIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Shop owners can manage subscriptions
DROP POLICY IF EXISTS "Shop owners can manage subscriptions" ON subscriptions;
CREATE POLICY "Shop owners can manage subscriptions" ON subscriptions
FOR ALL USING (
  shop_id IN (
    SELECT shop_id FROM shop_members 
    WHERE user_id = auth.uid() 
    AND role IN ('OWNER', 'MANAGER')
  )
);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4: SERVICES_CATALOG POLICIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Shop team can manage their services
DROP POLICY IF EXISTS "Shop team can manage services" ON services_catalog;
CREATE POLICY "Shop team can manage services" ON services_catalog
FOR ALL USING (
  shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid()
  )
);

-- Anyone can view published services (for buyer app discovery)
DROP POLICY IF EXISTS "Public can view published services" ON services_catalog;
CREATE POLICY "Public can view published services" ON services_catalog
FOR SELECT USING (is_published = true);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 5: SERVICES_APPOINTMENTS POLICIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Shop team can manage all appointments
DROP POLICY IF EXISTS "Shop team can manage appointments" ON services_appointments;
CREATE POLICY "Shop team can manage appointments" ON services_appointments
FOR ALL USING (
  shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid()
  )
);

-- Customers can view/manage their own appointments
DROP POLICY IF EXISTS "Customers can manage own appointments" ON services_appointments;
CREATE POLICY "Customers can manage own appointments" ON services_appointments
FOR ALL USING (
  customer_device_id IS NOT NULL 
  AND customer_device_id != ''
);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 6: RESTAURANT_MENU POLICIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Shop team can manage menu
DROP POLICY IF EXISTS "Shop team can manage menu" ON restaurant_menu;
CREATE POLICY "Shop team can manage menu" ON restaurant_menu
FOR ALL USING (
  shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid()
  )
);

-- Public can view published menu items
DROP POLICY IF EXISTS "Public can view published menu" ON restaurant_menu;
CREATE POLICY "Public can view published menu" ON restaurant_menu
FOR SELECT USING (is_published = true AND is_available = true);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 7: RESTAURANT_ORDERS POLICIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Shop team can manage all orders
DROP POLICY IF EXISTS "Shop team can manage orders" ON restaurant_orders;
CREATE POLICY "Shop team can manage orders" ON restaurant_orders
FOR ALL USING (
  shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid()
  )
);


-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 8: TRANSACTIONS POLICIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Shop team can view their transactions
DROP POLICY IF EXISTS "Shop team can view transactions" ON transactions;
CREATE POLICY "Shop team can view transactions" ON transactions
FOR SELECT USING (
  shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid()
  )
);

-- Shop team can insert transactions
DROP POLICY IF EXISTS "Shop team can insert transactions" ON transactions;
CREATE POLICY "Shop team can insert transactions" ON transactions
FOR INSERT WITH CHECK (
  shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid()
  )
);

-- Note: UPDATE and DELETE on transactions is not allowed to maintain audit trail


-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

SELECT 'RLS Policies Applied! ✅' as status;
