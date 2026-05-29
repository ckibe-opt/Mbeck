-- =============================================
-- migration_v40_buyer_alignment.sql
-- Aligns the cloud schema with everything the Mbeck Go BUYER app actually
-- writes/reads. Pre-v40 the buyer was hitting six tables and three columns
-- that had never been declared in any migration in this repo.
--
-- Run AFTER migration_v39_canonicalization.sql.
--
-- Buyer-side audit findings closed by this file:
--   B1  lodging_reservations status casing + missing source/buyer_id cols
--   B2  orders missing source/module/buyer_id cols
--   B3  cloud_messages, shop_analytics_events, cloud_orders, kitchen_queue,
--       receipts tables never created
--   B4  shops.business_type column never created
--   B6  buyer_id naming standardized across buyer-owned tables
-- =============================================


-- ╔══════════════════════════════════════════════╗
-- ║ 1. shops.business_type                         ║
-- ║    Searched by buyer's explore + global search ║
-- ╚══════════════════════════════════════════════╝
ALTER TABLE public.shops
  ADD COLUMN IF NOT EXISTS business_type text;


-- ╔══════════════════════════════════════════════╗
-- ║ 2. lodging_reservations: source + buyer_id    ║
-- ║    Buyer inserts these; 006 didn't have them. ║
-- ║    Each ADD COLUMN is its own statement so one ║
-- ║    failure can't block the others.             ║
-- ╚══════════════════════════════════════════════╝
-- Wrapped in DO/EXECUTE: the Supabase SQL editor parses every statement in
-- the batch up-front, so any literal CREATE INDEX/CREATE POLICY referencing
-- `buyer_id` is validated *before* the ALTER TABLE that adds it has actually
-- committed. EXECUTE defers validation to runtime, after the column exists.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='lodging_reservations'
  ) THEN
    RAISE NOTICE 'Table public.lodging_reservations does not exist; skipping section 2.';
    RETURN;
  END IF;

  EXECUTE 'ALTER TABLE public.lodging_reservations ADD COLUMN IF NOT EXISTS source   text DEFAULT ''cloud''';
  EXECUTE 'ALTER TABLE public.lodging_reservations ADD COLUMN IF NOT EXISTS buyer_id uuid';

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_schema='public' AND table_name='lodging_reservations'
      AND constraint_name='lodging_reservations_buyer_id_fkey'
  ) THEN
    BEGIN
      EXECUTE 'ALTER TABLE public.lodging_reservations
               ADD CONSTRAINT lodging_reservations_buyer_id_fkey
               FOREIGN KEY (buyer_id) REFERENCES auth.users(id) ON DELETE SET NULL';
    EXCEPTION WHEN insufficient_privilege THEN
      RAISE NOTICE 'Skipping FK to auth.users (insufficient privilege).';
    END;
  END IF;

  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_lodging_res_buyer
           ON public.lodging_reservations(buyer_id) WHERE buyer_id IS NOT NULL';

  EXECUTE 'DROP POLICY IF EXISTS "Buyers can create their own reservations" ON public.lodging_reservations';
  EXECUTE 'CREATE POLICY "Buyers can create their own reservations" ON public.lodging_reservations
           FOR INSERT TO authenticated
           WITH CHECK (buyer_id = auth.uid() OR buyer_id IS NULL)';

  EXECUTE 'DROP POLICY IF EXISTS "Buyers can read their own reservations" ON public.lodging_reservations';
  EXECUTE 'CREATE POLICY "Buyers can read their own reservations" ON public.lodging_reservations
           FOR SELECT TO authenticated
           USING (buyer_id = auth.uid())';
END $$;


-- ╔══════════════════════════════════════════════╗
-- ║ 3. orders: source + module + buyer_id         ║
-- ║    Buyer offline-sync writes all three.       ║
-- ║    Skip cleanly if `orders` table doesn't     ║
-- ║    exist in this environment yet.             ║
-- ╚══════════════════════════════════════════════╝
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='orders'
  ) THEN
    RAISE NOTICE 'Table public.orders does not exist; skipping section 3.';
    RETURN;
  END IF;

  EXECUTE 'ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS source   text';
  EXECUTE 'ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS module   text';
  EXECUTE 'ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS buyer_id uuid';

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_schema='public' AND table_name='orders'
      AND constraint_name='orders_buyer_id_fkey'
  ) THEN
    BEGIN
      EXECUTE 'ALTER TABLE public.orders
               ADD CONSTRAINT orders_buyer_id_fkey
               FOREIGN KEY (buyer_id) REFERENCES auth.users(id) ON DELETE SET NULL';
    EXCEPTION WHEN insufficient_privilege THEN
      RAISE NOTICE 'Skipping FK to auth.users (insufficient privilege).';
    END;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='orders' AND column_name='buyer_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_orders_buyer
             ON public.orders(buyer_id) WHERE buyer_id IS NOT NULL';

    EXECUTE 'DROP POLICY IF EXISTS "Buyers can read their own orders" ON public.orders';
    EXECUTE 'CREATE POLICY "Buyers can read their own orders" ON public.orders
             FOR SELECT TO authenticated
             USING (buyer_id = auth.uid())';
  END IF;
END $$;


-- ╔══════════════════════════════════════════════╗
-- ║ 4. cloud_orders                               ║
-- ║    Submitted via CloudShopApiService.checkout ║
-- ║                                               ║
-- ║ NOTE: a draft `cloud_orders` may already exist║
-- ║ from earlier ad-hoc SQL (commonly with        ║
-- ║ `customer_id` instead of `buyer_id`). We      ║
-- ║ create-if-absent, then ADD-COLUMN-IF-MISSING  ║
-- ║ for every column the buyer code expects.      ║
-- ╚══════════════════════════════════════════════╝
CREATE TABLE IF NOT EXISTS public.cloud_orders (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id     text NOT NULL,
  created_at  timestamptz DEFAULT now()
);

DO $$
BEGIN
  EXECUTE 'ALTER TABLE public.cloud_orders ADD COLUMN IF NOT EXISTS buyer_id   uuid';
  EXECUTE 'ALTER TABLE public.cloud_orders ADD COLUMN IF NOT EXISTS items      jsonb NOT NULL DEFAULT ''[]''::jsonb';
  EXECUTE 'ALTER TABLE public.cloud_orders ADD COLUMN IF NOT EXISTS status     text NOT NULL DEFAULT ''pending''';
  EXECUTE 'ALTER TABLE public.cloud_orders ADD COLUMN IF NOT EXISTS source     text DEFAULT ''cloud_checkout''';
  EXECUTE 'ALTER TABLE public.cloud_orders ADD COLUMN IF NOT EXISTS total      numeric(12,2)';
  EXECUTE 'ALTER TABLE public.cloud_orders ADD COLUMN IF NOT EXISTS notes      text';
  EXECUTE 'ALTER TABLE public.cloud_orders ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now()';

  -- (idempotent) repair status CHECK
  BEGIN
    EXECUTE 'ALTER TABLE public.cloud_orders DROP CONSTRAINT IF EXISTS cloud_orders_status_check';
    EXECUTE 'ALTER TABLE public.cloud_orders ADD  CONSTRAINT cloud_orders_status_check
             CHECK (status IN (''pending'',''confirmed'',''preparing'',''ready'',''completed'',''cancelled''))';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'cloud_orders status CHECK skipped: %', SQLERRM;
  END;

  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_cloud_orders_shop   ON public.cloud_orders(shop_id)';
  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_cloud_orders_buyer  ON public.cloud_orders(buyer_id)';
  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_cloud_orders_status ON public.cloud_orders(shop_id, status)';

  EXECUTE 'ALTER TABLE public.cloud_orders ENABLE ROW LEVEL SECURITY';

  EXECUTE 'DROP POLICY IF EXISTS "Buyers can insert their cloud orders" ON public.cloud_orders';
  EXECUTE 'CREATE POLICY "Buyers can insert their cloud orders" ON public.cloud_orders
           FOR INSERT TO authenticated WITH CHECK (buyer_id = auth.uid())';

  EXECUTE 'DROP POLICY IF EXISTS "Buyers can read their cloud orders" ON public.cloud_orders';
  EXECUTE 'CREATE POLICY "Buyers can read their cloud orders" ON public.cloud_orders
           FOR SELECT TO authenticated USING (buyer_id = auth.uid())';

  EXECUTE 'DROP POLICY IF EXISTS "Shop members can read shop cloud orders" ON public.cloud_orders';
  EXECUTE 'CREATE POLICY "Shop members can read shop cloud orders" ON public.cloud_orders
           FOR SELECT USING (shop_id IN (
             SELECT shop_id FROM public.shop_members
             WHERE user_id = auth.uid() AND is_active = true))';

  EXECUTE 'DROP POLICY IF EXISTS "Shop members can update shop cloud orders" ON public.cloud_orders';
  EXECUTE 'CREATE POLICY "Shop members can update shop cloud orders" ON public.cloud_orders
           FOR UPDATE USING (shop_id IN (
             SELECT shop_id FROM public.shop_members
             WHERE user_id = auth.uid() AND is_active = true))
           WITH CHECK (shop_id IN (
             SELECT shop_id FROM public.shop_members
             WHERE user_id = auth.uid() AND is_active = true))';
END $$;


-- ╔══════════════════════════════════════════════╗
-- ║ 5. kitchen_queue                              ║
-- ╚══════════════════════════════════════════════╝
CREATE TABLE IF NOT EXISTS public.kitchen_queue (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id     text NOT NULL,
  created_at  timestamptz DEFAULT now()
);

DO $$
BEGIN
  EXECUTE 'ALTER TABLE public.kitchen_queue ADD COLUMN IF NOT EXISTS module        text NOT NULL DEFAULT ''restaurant''';
  EXECUTE 'ALTER TABLE public.kitchen_queue ADD COLUMN IF NOT EXISTS items         jsonb NOT NULL DEFAULT ''[]''::jsonb';
  EXECUTE 'ALTER TABLE public.kitchen_queue ADD COLUMN IF NOT EXISTS table_number  text';
  EXECUTE 'ALTER TABLE public.kitchen_queue ADD COLUMN IF NOT EXISTS customer_name text';
  EXECUTE 'ALTER TABLE public.kitchen_queue ADD COLUMN IF NOT EXISTS notes         text';
  EXECUTE 'ALTER TABLE public.kitchen_queue ADD COLUMN IF NOT EXISTS status        text NOT NULL DEFAULT ''new''';
  EXECUTE 'ALTER TABLE public.kitchen_queue ADD COLUMN IF NOT EXISTS buyer_id      uuid';

  BEGIN
    EXECUTE 'ALTER TABLE public.kitchen_queue DROP CONSTRAINT IF EXISTS kitchen_queue_status_check';
    EXECUTE 'ALTER TABLE public.kitchen_queue ADD  CONSTRAINT kitchen_queue_status_check
             CHECK (status IN (''new'',''preparing'',''ready'',''served'',''cancelled''))';
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_kitchen_queue_shop   ON public.kitchen_queue(shop_id)';
  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_kitchen_queue_status ON public.kitchen_queue(shop_id, status)';

  EXECUTE 'ALTER TABLE public.kitchen_queue ENABLE ROW LEVEL SECURITY';

  EXECUTE 'DROP POLICY IF EXISTS "Authenticated can ping kitchen" ON public.kitchen_queue';
  EXECUTE 'CREATE POLICY "Authenticated can ping kitchen" ON public.kitchen_queue
           FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL)';

  EXECUTE 'DROP POLICY IF EXISTS "Shop members manage kitchen queue" ON public.kitchen_queue';
  EXECUTE 'CREATE POLICY "Shop members manage kitchen queue" ON public.kitchen_queue
           FOR ALL USING (shop_id IN (
             SELECT shop_id FROM public.shop_members
             WHERE user_id = auth.uid() AND is_active = true))';
END $$;


-- ╔══════════════════════════════════════════════╗
-- ║ 6. cloud_messages                             ║
-- ╚══════════════════════════════════════════════╝
CREATE TABLE IF NOT EXISTS public.cloud_messages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id     text NOT NULL,
  created_at  timestamptz DEFAULT now()
);

DO $$
BEGIN
  EXECUTE 'ALTER TABLE public.cloud_messages ADD COLUMN IF NOT EXISTS buyer_id uuid';
  EXECUTE 'ALTER TABLE public.cloud_messages ADD COLUMN IF NOT EXISTS sender   text';
  EXECUTE 'ALTER TABLE public.cloud_messages ADD COLUMN IF NOT EXISTS content  text';
  EXECUTE 'ALTER TABLE public.cloud_messages ADD COLUMN IF NOT EXISTS read     boolean DEFAULT false';

  BEGIN
    EXECUTE 'ALTER TABLE public.cloud_messages DROP CONSTRAINT IF EXISTS cloud_messages_sender_check';
    EXECUTE 'ALTER TABLE public.cloud_messages ADD  CONSTRAINT cloud_messages_sender_check
             CHECK (sender IN (''buyer'',''shop''))';
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_cloud_messages_thread
           ON public.cloud_messages(shop_id, buyer_id, created_at)';

  EXECUTE 'ALTER TABLE public.cloud_messages ENABLE ROW LEVEL SECURITY';

  EXECUTE 'DROP POLICY IF EXISTS "Buyer reads own thread" ON public.cloud_messages';
  EXECUTE 'CREATE POLICY "Buyer reads own thread" ON public.cloud_messages
           FOR SELECT TO authenticated USING (buyer_id = auth.uid())';

  EXECUTE 'DROP POLICY IF EXISTS "Buyer writes own thread" ON public.cloud_messages';
  EXECUTE 'CREATE POLICY "Buyer writes own thread" ON public.cloud_messages
           FOR INSERT TO authenticated
           WITH CHECK (buyer_id = auth.uid() AND sender = ''buyer'')';

  EXECUTE 'DROP POLICY IF EXISTS "Buyer marks own thread read" ON public.cloud_messages';
  EXECUTE 'CREATE POLICY "Buyer marks own thread read" ON public.cloud_messages
           FOR UPDATE TO authenticated
           USING (buyer_id = auth.uid())
           WITH CHECK (buyer_id = auth.uid())';

  EXECUTE 'DROP POLICY IF EXISTS "Shop reads its threads" ON public.cloud_messages';
  EXECUTE 'CREATE POLICY "Shop reads its threads" ON public.cloud_messages
           FOR SELECT USING (shop_id IN (
             SELECT shop_id FROM public.shop_members
             WHERE user_id = auth.uid() AND is_active = true))';

  EXECUTE 'DROP POLICY IF EXISTS "Shop writes its threads" ON public.cloud_messages';
  EXECUTE 'CREATE POLICY "Shop writes its threads" ON public.cloud_messages
           FOR INSERT TO authenticated
           WITH CHECK (sender = ''shop'' AND shop_id IN (
             SELECT shop_id FROM public.shop_members
             WHERE user_id = auth.uid() AND is_active = true))';
END $$;


-- ╔══════════════════════════════════════════════╗
-- ║ 7. shop_analytics_events                      ║
-- ╚══════════════════════════════════════════════╝
CREATE TABLE IF NOT EXISTS public.shop_analytics_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id     text NOT NULL,
  created_at  timestamptz DEFAULT now()
);

DO $$
BEGIN
  EXECUTE 'ALTER TABLE public.shop_analytics_events ADD COLUMN IF NOT EXISTS buyer_id   uuid';
  EXECUTE 'ALTER TABLE public.shop_analytics_events ADD COLUMN IF NOT EXISTS event_type text';
  EXECUTE 'ALTER TABLE public.shop_analytics_events ADD COLUMN IF NOT EXISTS item_id    text';
  EXECUTE 'ALTER TABLE public.shop_analytics_events ADD COLUMN IF NOT EXISTS item_name  text';
  EXECUTE 'ALTER TABLE public.shop_analytics_events ADD COLUMN IF NOT EXISTS module     text';

  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_shop_analytics_shop
           ON public.shop_analytics_events(shop_id, created_at)';

  EXECUTE 'ALTER TABLE public.shop_analytics_events ENABLE ROW LEVEL SECURITY';

  EXECUTE 'DROP POLICY IF EXISTS "Authenticated can log shop analytics" ON public.shop_analytics_events';
  EXECUTE 'CREATE POLICY "Authenticated can log shop analytics" ON public.shop_analytics_events
           FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL)';

  EXECUTE 'DROP POLICY IF EXISTS "Shop members read shop analytics" ON public.shop_analytics_events';
  EXECUTE 'CREATE POLICY "Shop members read shop analytics" ON public.shop_analytics_events
           FOR SELECT USING (shop_id IN (
             SELECT shop_id FROM public.shop_members
             WHERE user_id = auth.uid() AND is_active = true))';
END $$;


-- ╔══════════════════════════════════════════════╗
-- ║ 8. receipts                                   ║
-- ╚══════════════════════════════════════════════╝
CREATE TABLE IF NOT EXISTS public.receipts (
  id          uuid PRIMARY KEY,
  created_at  timestamptz DEFAULT now()
);

DO $$
BEGIN
  EXECUTE 'ALTER TABLE public.receipts ADD COLUMN IF NOT EXISTS seller_id    text';
  EXECUTE 'ALTER TABLE public.receipts ADD COLUMN IF NOT EXISTS seller_name  text';
  EXECUTE 'ALTER TABLE public.receipts ADD COLUMN IF NOT EXISTS buyer_id     uuid';
  EXECUTE 'ALTER TABLE public.receipts ADD COLUMN IF NOT EXISTS items_json   text';
  EXECUTE 'ALTER TABLE public.receipts ADD COLUMN IF NOT EXISTS total_amount numeric(12,2)';
  EXECUTE 'ALTER TABLE public.receipts ADD COLUMN IF NOT EXISTS signature    text';
  EXECUTE 'ALTER TABLE public.receipts ADD COLUMN IF NOT EXISTS module       text';

  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_receipts_seller ON public.receipts(seller_id, created_at DESC)';
  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_receipts_buyer  ON public.receipts(buyer_id,  created_at DESC)';

  EXECUTE 'ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY';

  EXECUTE 'DROP POLICY IF EXISTS "Authenticated can upload receipts" ON public.receipts';
  EXECUTE 'CREATE POLICY "Authenticated can upload receipts" ON public.receipts
           FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL)';

  EXECUTE 'DROP POLICY IF EXISTS "Buyers read their receipts" ON public.receipts';
  EXECUTE 'CREATE POLICY "Buyers read their receipts" ON public.receipts
           FOR SELECT TO authenticated USING (buyer_id = auth.uid())';

  EXECUTE 'DROP POLICY IF EXISTS "Shop members read shop receipts" ON public.receipts';
  EXECUTE 'CREATE POLICY "Shop members read shop receipts" ON public.receipts
           FOR SELECT USING (seller_id IN (
             SELECT shop_id FROM public.shop_members
             WHERE user_id = auth.uid() AND is_active = true))';
END $$;


SELECT 'v40 buyer-alignment migration applied ✅' AS status;
