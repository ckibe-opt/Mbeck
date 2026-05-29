-- =============================================
-- migration_v42_keja_extension.sql
-- Implements tables and RLS for Keja virtual tours pay-to-view
-- and lorry relocation helper ("Tuko Mboka").
-- =============================================

-- ╔══════════════════════════════════════════════╗
-- ║ 1. paid_virtual_tours                        ║
-- ║    Tracks unlocked 360° tours for buyers.    ║
-- ╚══════════════════════════════════════════════╝
CREATE TABLE IF NOT EXISTS public.paid_virtual_tours (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id            uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  marketplace_item_id uuid NOT NULL,
  unlocked_at         timestamptz DEFAULT now(),
  expires_at          timestamptz, -- Null means lifetime unlock
  amount_paid         numeric(12,2) DEFAULT 500.00,
  transaction_ref     text,
  created_at          timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_paid_tours_buyer ON public.paid_virtual_tours(buyer_id);
CREATE INDEX IF NOT EXISTS idx_paid_tours_item ON public.paid_virtual_tours(marketplace_item_id);

ALTER TABLE public.paid_virtual_tours ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Buyers can read their own paid tours" ON public.paid_virtual_tours;
CREATE POLICY "Buyers can read their own paid tours" ON public.paid_virtual_tours
  FOR SELECT TO authenticated USING (buyer_id = auth.uid());

DROP POLICY IF EXISTS "Buyers can insert their own paid tours" ON public.paid_virtual_tours;
CREATE POLICY "Buyers can insert their own paid tours" ON public.paid_virtual_tours
  FOR INSERT TO authenticated WITH CHECK (buyer_id = auth.uid());


-- ╔══════════════════════════════════════════════╗
-- ║ 2. relocation_bookings                       ║
-- ║    Tuko Mboka moving helper bookings.        ║
-- ╚══════════════════════════════════════════════╝
CREATE TABLE IF NOT EXISTS public.relocation_bookings (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id             uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pickup_location      text NOT NULL,
  destination_location text NOT NULL,
  lorry_size           text NOT NULL, -- Small (Pickup), Medium (Canter), Large (Lorry)
  moving_date          timestamptz NOT NULL,
  status               text NOT NULL DEFAULT 'pending',
  price                numeric(12,2),
  notes                text,
  created_at           timestamptz DEFAULT now(),
  updated_at           timestamptz DEFAULT now()
);

-- status CHECK constraint
BEGIN;
  ALTER TABLE public.relocation_bookings DROP CONSTRAINT IF EXISTS relocation_bookings_status_check;
  ALTER TABLE public.relocation_bookings ADD CONSTRAINT relocation_bookings_status_check
    CHECK (status IN ('pending', 'confirmed', 'in_progress', 'completed', 'cancelled'));
COMMIT;

CREATE INDEX IF NOT EXISTS idx_relocation_buyer ON public.relocation_bookings(buyer_id);
CREATE INDEX IF NOT EXISTS idx_relocation_status ON public.relocation_bookings(status);

ALTER TABLE public.relocation_bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Buyers can manage their own relocation bookings" ON public.relocation_bookings;
CREATE POLICY "Buyers can manage their own relocation bookings" ON public.relocation_bookings
  FOR ALL TO authenticated USING (buyer_id = auth.uid()) WITH CHECK (buyer_id = auth.uid());

DROP POLICY IF EXISTS "Admins can view all relocation bookings" ON public.relocation_bookings;
CREATE POLICY "Admins can view all relocation bookings" ON public.relocation_bookings
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.shop_members
      WHERE user_id = auth.uid() AND role IN ('OWNER', 'ADMIN') AND is_active = true
    )
  );

SELECT 'v42 keja-extension migration defined ✅' AS status;
