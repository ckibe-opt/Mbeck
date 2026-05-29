-- =============================================
-- migration_v36_online_marketplace.sql
-- Enables the B2C Mbeck Go Marketplace Ecosystem
-- Run in Supabase SQL Editor
-- =============================================

-- 1. Shops Table
ALTER TABLE public.shops 
ADD COLUMN IF NOT EXISTS is_published_online BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNVERIFIED', 'PENDING', 'VERIFIED', 'REJECTED')),
ADD COLUMN IF NOT EXISTS online_views INTEGER DEFAULT 0;

-- 2. Inventory 
ALTER TABLE public.inventory 
ADD COLUMN IF NOT EXISTS online_views INTEGER DEFAULT 0;

-- 3. Restaurant Menu
ALTER TABLE public.restaurant_menu 
ADD COLUMN IF NOT EXISTS online_views INTEGER DEFAULT 0;

-- 4. Services Catalog
ALTER TABLE public.services_catalog 
ADD COLUMN IF NOT EXISTS online_views INTEGER DEFAULT 0;

-- 5. Entertainment Assets
ALTER TABLE public.entertainment_assets 
ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS online_views INTEGER DEFAULT 0;

-- 6. Lodging Rooms
ALTER TABLE public.lodging_rooms 
ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS online_views INTEGER DEFAULT 0;

-- 7. Analytics RPC for Shop Views (Mbeck Go)
CREATE OR REPLACE FUNCTION public.increment_shop_views(target_shop_id TEXT)
RETURNS void AS $$
BEGIN
  UPDATE shops SET online_views = COALESCE(online_views, 0) + 1 WHERE id = target_shop_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Analytics RPC for Item Views (Mbeck Go)
CREATE OR REPLACE FUNCTION public.increment_item_views(target_table TEXT, target_id UUID)
RETURNS void AS $$
BEGIN
  -- Validate target_table to prevent SQL injection
  IF target_table NOT IN ('inventory', 'restaurant_menu', 'services_catalog', 'entertainment_assets', 'lodging_rooms') THEN
    RAISE EXCEPTION 'Invalid table %', target_table;
  END IF;

  EXECUTE format('UPDATE %I SET online_views = COALESCE(online_views, 0) + 1 WHERE id = $1', target_table) USING target_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Marketplace Discovery Policies (Public Read for Mbeck Go)
-- Shops
DROP POLICY IF EXISTS "Public can view verified published shops" ON shops;
CREATE POLICY "Public can view verified published shops" ON shops
FOR SELECT USING (is_published_online = true AND verification_status = 'VERIFIED');

-- Inventory
DROP POLICY IF EXISTS "Public can view published inventory items" ON inventory;
CREATE POLICY "Public can view published inventory items" ON inventory
FOR SELECT USING (
  is_published = true AND
  shop_id IN (SELECT id FROM shops WHERE is_published_online = true AND verification_status = 'VERIFIED')
);

-- Entertainment Assets
DROP POLICY IF EXISTS "Public can view published entertainment" ON entertainment_assets;
CREATE POLICY "Public can view published entertainment" ON entertainment_assets
FOR SELECT USING (
  is_published = true AND
  shop_id IN (SELECT id FROM shops WHERE is_published_online = true AND verification_status = 'VERIFIED')
);

-- Lodging Rooms
DROP POLICY IF EXISTS "Public can view published lodging" ON lodging_rooms;
CREATE POLICY "Public can view published lodging" ON lodging_rooms
FOR SELECT USING (
  is_published = true AND
  shop_id IN (SELECT id FROM shops WHERE is_published_online = true AND verification_status = 'VERIFIED')
);

-- Restaurant Menu
DROP POLICY IF EXISTS "Public can view published restaurant menu" ON restaurant_menu;
CREATE POLICY "Public can view published restaurant menu" ON restaurant_menu
FOR SELECT USING (
  is_published = true AND
  shop_id IN (SELECT id FROM shops WHERE is_published_online = true AND verification_status = 'VERIFIED')
);

-- Services Catalog
DROP POLICY IF EXISTS "Public can view published services" ON services_catalog;
CREATE POLICY "Public can view published services" ON services_catalog
FOR SELECT USING (
  is_published = true AND
  shop_id IN (SELECT id FROM shops WHERE is_published_online = true AND verification_status = 'VERIFIED')
);

SELECT 'Online Marketplace schemas and analytics successfully initialized! 🚀' as status;
