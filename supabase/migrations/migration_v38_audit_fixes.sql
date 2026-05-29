-- =============================================
-- migration_v38_audit_fixes.sql
-- Consolidated remediation for issues found in the May 2026 audit:
--   * marketplace_items table never created in any prior migration
--   * rpc_verify_shop_exists called by client but never defined
--   * log_analytics_event called by client but never defined
--   * increment_item_views typed UUID but inventory.id is BIGINT
--   * migrate_v1_to_shop inserts role 'owner' (lowercase) violating CHECK
--   * exec_sql is a SECURITY DEFINER footgun — lock it down
--   * verification_status must not be writable by sellers themselves
-- Run in Supabase SQL Editor.
-- =============================================

-- ╔══════════════════════════════════════════════╗
-- ║ 1. Marketplace items (unified seller catalog) ║
-- ║    cloud_publish_service.publishShopAndInventory  ║
-- ║    upserts here on every cloud publish.          ║
-- ╚══════════════════════════════════════════════╝
CREATE TABLE IF NOT EXISTS public.marketplace_items (
  id              text PRIMARY KEY,
  shop_id         text NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  module_source   text NOT NULL CHECK (module_source IN
                    ('retail','restaurant','services','lodging','entertainment')),
  name            text NOT NULL,
  description     text,
  price           numeric(12,2),
  original_price  numeric(12,2),
  image_url       text,
  category        text,
  is_published    boolean DEFAULT false,
  stock           integer,
  metadata        jsonb DEFAULT '{}'::jsonb,
  created_at      timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_items_shop      ON public.marketplace_items(shop_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_items_module    ON public.marketplace_items(module_source);
CREATE INDEX IF NOT EXISTS idx_marketplace_items_published ON public.marketplace_items(is_published);

ALTER TABLE public.marketplace_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Shop team can manage marketplace items" ON public.marketplace_items;
CREATE POLICY "Shop team can manage marketplace items" ON public.marketplace_items
FOR ALL USING (
  shop_id IN (SELECT shop_id FROM public.shop_members
              WHERE user_id = auth.uid() AND is_active = true)
) WITH CHECK (
  shop_id IN (SELECT shop_id FROM public.shop_members
              WHERE user_id = auth.uid() AND is_active = true)
);

-- Public discovery: only published items belonging to verified, online shops.
DROP POLICY IF EXISTS "Public can view published marketplace items" ON public.marketplace_items;
CREATE POLICY "Public can view published marketplace items" ON public.marketplace_items
FOR SELECT USING (
  is_published = true
  AND shop_id IN (
    SELECT id FROM public.shops
    WHERE is_published_online = true AND verification_status = 'VERIFIED'
  )
);


-- ╔══════════════════════════════════════════════╗
-- ║ 2. rpc_verify_shop_exists                    ║
-- ║    Used by lib/screens/link_shop_screen.dart  ║
-- ╚══════════════════════════════════════════════╝
DROP FUNCTION IF EXISTS public.rpc_verify_shop_exists(text);
CREATE FUNCTION public.rpc_verify_shop_exists(p_shop_id text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.shops WHERE id = p_shop_id);
$$;

GRANT EXECUTE ON FUNCTION public.rpc_verify_shop_exists(text) TO anon, authenticated;


-- ╔══════════════════════════════════════════════╗
-- ║ 3. log_analytics_event (used by cloud publish)║
-- ║    Provides a minimal sink so client calls    ║
-- ║    succeed instead of throwing on every push. ║
-- ╚══════════════════════════════════════════════╝
CREATE TABLE IF NOT EXISTS public.analytics_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_name  text NOT NULL,
  platform    text,
  shop_id     text,
  user_id     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  details     jsonb DEFAULT '{}'::jsonb,
  created_at  timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_analytics_events_shop   ON public.analytics_events(shop_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_name   ON public.analytics_events(event_name);
CREATE INDEX IF NOT EXISTS idx_analytics_events_time   ON public.analytics_events(created_at);

ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

-- Only the SECURITY DEFINER function inserts here; no direct client access.
DROP POLICY IF EXISTS "No direct access to analytics_events" ON public.analytics_events;
CREATE POLICY "No direct access to analytics_events" ON public.analytics_events
FOR ALL USING (false);

DROP FUNCTION IF EXISTS public.log_analytics_event(text, text, text, jsonb);
CREATE FUNCTION public.log_analytics_event(
  p_event_name text,
  p_platform   text DEFAULT NULL,
  p_shop_id    text DEFAULT NULL,
  p_details    jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.analytics_events (event_name, platform, shop_id, user_id, details)
  VALUES (p_event_name, p_platform, p_shop_id, auth.uid(), COALESCE(p_details, '{}'::jsonb));
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_analytics_event(text, text, text, jsonb)
  TO anon, authenticated;


-- ╔══════════════════════════════════════════════╗
-- ║ 4. Fix increment_item_views type bug          ║
-- ║    inventory.id is BIGINT, not UUID.          ║
-- ╚══════════════════════════════════════════════╝
DROP FUNCTION IF EXISTS public.increment_item_views(text, uuid);

CREATE OR REPLACE FUNCTION public.increment_item_views(
  target_table text,
  target_id    text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF target_table NOT IN
       ('inventory','restaurant_menu','services_catalog','entertainment_assets','lodging_rooms')
  THEN
    RAISE EXCEPTION 'Invalid table %', target_table;
  END IF;

  IF target_table = 'inventory' THEN
    -- inventory.id is BIGINT
    EXECUTE format(
      'UPDATE %I SET online_views = COALESCE(online_views,0) + 1 WHERE id = $1',
      target_table
    ) USING target_id::bigint;
  ELSE
    -- All other tables key by uuid
    EXECUTE format(
      'UPDATE %I SET online_views = COALESCE(online_views,0) + 1 WHERE id = $1',
      target_table
    ) USING target_id::uuid;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.increment_item_views(text, text)
  TO anon, authenticated;


-- ╔══════════════════════════════════════════════╗
-- ║ 5. Fix migrate_v1_to_shop role case            ║
-- ║    CHECK requires uppercase ('OWNER').         ║
-- ║    DROP first because Postgres won't let       ║
-- ║    CREATE OR REPLACE change the return type    ║
-- ║    if the existing function differs.           ║
-- ╚══════════════════════════════════════════════╝
DROP FUNCTION IF EXISTS public.migrate_v1_to_shop(text);

CREATE FUNCTION public.migrate_v1_to_shop(shop_name text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_shop_id uuid;
BEGIN
  INSERT INTO public.shops (name, owner_id)
  VALUES (shop_name, auth.uid())
  RETURNING id INTO new_shop_id;

  INSERT INTO public.shop_members (shop_id, user_id, role)
  VALUES (new_shop_id::text, auth.uid(), 'OWNER');

  RETURN new_shop_id;
END;
$$;


-- ╔══════════════════════════════════════════════╗
-- ║ 6. Lock down exec_sql                         ║
-- ║    SECURITY DEFINER + arbitrary SQL was a      ║
-- ║    full-DB takeover vector if anon had EXECUTE.║
-- ╚══════════════════════════════════════════════╝
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'exec_sql'
  ) THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.exec_sql(text) FROM PUBLIC';
    EXECUTE 'REVOKE ALL ON FUNCTION public.exec_sql(text) FROM anon, authenticated';
  END IF;
END $$;


-- ╔══════════════════════════════════════════════╗
-- ║ 7. Strip seller-side write access to          ║
-- ║    shops.verification_status                   ║
-- ║    Sellers self-marking VERIFIED defeats the   ║
-- ║    public-discovery RLS gate added in v36.     ║
-- ╚══════════════════════════════════════════════╝
REVOKE UPDATE (verification_status) ON public.shops FROM anon, authenticated;
-- Keep service_role full access for admin/back-office tooling.


-- ╔══════════════════════════════════════════════╗
-- ║ 8. Make events.payload_raw NOT NULL going      ║
-- ║    forward so the hash trigger has something   ║
-- ║    deterministic to validate against.          ║
-- ║    Backfill from payload first, then enforce.  ║
-- ╚══════════════════════════════════════════════╝
UPDATE public.events
SET    payload_raw = payload::text
WHERE  payload_raw IS NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='events' AND column_name='payload_raw'
      AND is_nullable='YES'
  ) THEN
    -- Only enforce NOT NULL if we have no NULLs left.
    IF NOT EXISTS (SELECT 1 FROM public.events WHERE payload_raw IS NULL) THEN
      EXECUTE 'ALTER TABLE public.events ALTER COLUMN payload_raw SET NOT NULL';
    END IF;
  END IF;
END $$;


SELECT 'v38 audit-fixes migration applied ✅' AS status;
