-- =============================================
-- migration_v43_marketplace_extensions.sql
-- Implements tables and RLS for Retail Orders,
-- Restaurant Orders, Services Appointments, and
-- Entertainment Bookings in Supabase.
-- =============================================

-- ╔══════════════════════════════════════════════╗
-- ║ 1. restaurant_orders                         ║
-- ║    Standardize existing table with buyer_id.║
-- ╚══════════════════════════════════════════════╝
ALTER TABLE public.restaurant_orders ADD COLUMN IF NOT EXISTS buyer_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- status CHECK constraint
BEGIN;
  ALTER TABLE public.restaurant_orders DROP CONSTRAINT IF EXISTS restaurant_orders_status_check;
  ALTER TABLE public.restaurant_orders ADD CONSTRAINT restaurant_orders_status_check
    CHECK (status IN ('pending', 'confirmed', 'preparing', 'ready', 'served', 'paid', 'cancelled', 'out_for_delivery', 'completed'));
COMMIT;

CREATE INDEX IF NOT EXISTS idx_restaurant_orders_buyer ON public.restaurant_orders(buyer_id);
CREATE INDEX IF NOT EXISTS idx_restaurant_orders_shop ON public.restaurant_orders(shop_id);
CREATE INDEX IF NOT EXISTS idx_restaurant_orders_status ON public.restaurant_orders(status);

ALTER TABLE public.restaurant_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Buyers can manage their own restaurant orders" ON public.restaurant_orders;
CREATE POLICY "Buyers can manage their own restaurant orders" ON public.restaurant_orders
  FOR ALL TO authenticated USING (buyer_id = auth.uid()) WITH CHECK (buyer_id = auth.uid());

DROP POLICY IF EXISTS "Admins can view all restaurant orders" ON public.restaurant_orders;
CREATE POLICY "Admins can view all restaurant orders" ON public.restaurant_orders
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.shop_members
      WHERE user_id = auth.uid() AND shop_id = public.restaurant_orders.shop_id AND is_active = true
    )
  );


-- ╔══════════════════════════════════════════════╗
-- ║ 2. services_appointments                     ║
-- ║    Standardize existing table with buyer_id  ║
-- ╚══════════════════════════════════════════════╝
ALTER TABLE public.services_appointments ADD COLUMN IF NOT EXISTS buyer_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.services_appointments ADD COLUMN IF NOT EXISTS staff_id int;
ALTER TABLE public.services_appointments ADD COLUMN IF NOT EXISTS deposit_paid numeric(12,2) DEFAULT 0.00;

-- status CHECK constraint
BEGIN;
  ALTER TABLE public.services_appointments DROP CONSTRAINT IF EXISTS services_appointments_status_check;
  ALTER TABLE public.services_appointments ADD CONSTRAINT services_appointments_status_check
    CHECK (status IN ('pending', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show'));
COMMIT;

CREATE INDEX IF NOT EXISTS idx_services_appointments_buyer ON public.services_appointments(buyer_id);
CREATE INDEX IF NOT EXISTS idx_services_appointments_shop ON public.services_appointments(shop_id);
CREATE INDEX IF NOT EXISTS idx_services_appointments_status ON public.services_appointments(status);

ALTER TABLE public.services_appointments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Buyers can manage their own services appointments" ON public.services_appointments;
CREATE POLICY "Buyers can manage their own services appointments" ON public.services_appointments
  FOR ALL TO authenticated USING (buyer_id = auth.uid()) WITH CHECK (buyer_id = auth.uid());

DROP POLICY IF EXISTS "Admins can view all services appointments" ON public.services_appointments;
CREATE POLICY "Admins can view all services appointments" ON public.services_appointments
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.shop_members
      WHERE user_id = auth.uid() AND shop_id = public.services_appointments.shop_id AND is_active = true
    )
  );


-- ╔══════════════════════════════════════════════╗
-- ║ 3. entertainment_bookings                     ║
-- ║    Tracks game/venue ticket bookings.        ║
-- ╚══════════════════════════════════════════════╝
CREATE TABLE IF NOT EXISTS public.entertainment_bookings (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  shop_id           text NOT NULL,
  asset_id          int NOT NULL,
  ticket_quantity   int NOT NULL DEFAULT 1,
  amount_paid       numeric(12,2) NOT NULL,
  booking_date      timestamptz NOT NULL,
  status            text NOT NULL DEFAULT 'confirmed', -- pending, confirmed, completed, cancelled
  notes             text,
  created_at        timestamptz DEFAULT now(),
  updated_at        timestamptz DEFAULT now()
);

-- status CHECK constraint
BEGIN;
  ALTER TABLE public.entertainment_bookings DROP CONSTRAINT IF EXISTS entertainment_bookings_status_check;
  ALTER TABLE public.entertainment_bookings ADD CONSTRAINT entertainment_bookings_status_check
    CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled'));
COMMIT;

CREATE INDEX IF NOT EXISTS idx_entertainment_bookings_buyer ON public.entertainment_bookings(buyer_id);
CREATE INDEX IF NOT EXISTS idx_entertainment_bookings_shop ON public.entertainment_bookings(shop_id);
CREATE INDEX IF NOT EXISTS idx_entertainment_bookings_status ON public.entertainment_bookings(status);

ALTER TABLE public.entertainment_bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Buyers can manage their own entertainment bookings" ON public.entertainment_bookings;
CREATE POLICY "Buyers can manage their own entertainment bookings" ON public.entertainment_bookings
  FOR ALL TO authenticated USING (buyer_id = auth.uid()) WITH CHECK (buyer_id = auth.uid());

DROP POLICY IF EXISTS "Admins can view all entertainment bookings" ON public.entertainment_bookings;
CREATE POLICY "Admins can view all entertainment bookings" ON public.entertainment_bookings
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.shop_members
      WHERE user_id = auth.uid() AND shop_id = public.entertainment_bookings.shop_id AND is_active = true
    )
  );

SELECT 'v43 extensions migration defined ✅' AS status;
