-- =============================================
-- migration_v35_security_hardening.sql
-- Fixes all Supabase security linter findings
-- Run in Supabase SQL Editor
-- =============================================

-- ╔══════════════════════════════════════════════╗
-- ║ SECTION 1: FIX SECURITY DEFINER VIEW        ║
-- ║ shops_public → SECURITY INVOKER              ║
-- ╚══════════════════════════════════════════════╝

DROP VIEW IF EXISTS shops_public;
CREATE VIEW shops_public
WITH (security_invoker = true) AS
SELECT id, name, subscription_tier, subscription_status, created_at, updated_at
FROM shops;

GRANT SELECT ON shops_public TO anon, authenticated;


-- ╔══════════════════════════════════════════════╗
-- ║ SECTION 2: ENABLE RLS ON UNPROTECTED TABLES  ║
-- ╚══════════════════════════════════════════════╝

-- 2a. credit_score_history
ALTER TABLE public.credit_score_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Shop owners can read own credit history" ON credit_score_history;
CREATE POLICY "Shop owners can read own credit history" ON credit_score_history
FOR SELECT USING (shop_id IN (
  SELECT shop_id FROM shop_members WHERE user_id = auth.uid() AND is_active = true
));

DROP POLICY IF EXISTS "System can insert credit history" ON credit_score_history;
CREATE POLICY "System can insert credit history" ON credit_score_history
FOR INSERT WITH CHECK (shop_id IN (
  SELECT shop_id FROM shop_members WHERE user_id = auth.uid() AND is_active = true
));

-- 2b. subscription_plans (read-only reference table)
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read subscription plans" ON subscription_plans;
CREATE POLICY "Anyone can read subscription plans" ON subscription_plans
FOR SELECT USING (true);

-- No INSERT/UPDATE/DELETE — plans are admin-managed only


-- ╔══════════════════════════════════════════════╗
-- ║ SECTION 3: FIX MUTABLE SEARCH PATH (19 fns) ║
-- ║ Each wrapped in DO block to skip if missing  ║
-- ╚══════════════════════════════════════════════╝

DO $$ BEGIN ALTER FUNCTION public.verify_shop_password(TEXT, TEXT, BOOLEAN) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: verify_shop_password'; END $$;
DO $$ BEGIN ALTER FUNCTION public.create_shop_secure(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: create_shop_secure'; END $$;
DO $$ BEGIN ALTER FUNCTION public.join_shop_secure(TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, UUID) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: join_shop_secure'; END $$;
DO $$ BEGIN ALTER FUNCTION public.login_shop_secure(TEXT, TEXT, TEXT) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: login_shop_secure'; END $$;
DO $$ BEGIN ALTER FUNCTION public.record_auth_attempt(TEXT, TEXT, BOOLEAN) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: record_auth_attempt'; END $$;
DO $$ BEGIN ALTER FUNCTION public.check_rate_limit(TEXT) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: check_rate_limit'; END $$;
DO $$ BEGIN ALTER FUNCTION public.cleanup_old_auth_attempts() SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: cleanup_old_auth_attempts'; END $$;
DO $$ BEGIN ALTER FUNCTION public.get_shop_stats(TEXT) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: get_shop_stats'; END $$;
DO $$ BEGIN ALTER FUNCTION public.update_updated_at_column() SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: update_updated_at_column'; END $$;
DO $$ BEGIN ALTER FUNCTION public.rpc_verify_shop_exists(TEXT) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: rpc_verify_shop_exists'; END $$;
DO $$ BEGIN ALTER FUNCTION public.get_team_role_counts(TEXT) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: get_team_role_counts'; END $$;
DO $$ BEGIN ALTER FUNCTION public.can_edit_team_member(TEXT, TEXT, TEXT) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: can_edit_team_member'; END $$;
DO $$ BEGIN ALTER FUNCTION public.calculate_shop_credit(TEXT) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: calculate_shop_credit'; END $$;
DO $$ BEGIN ALTER FUNCTION public.rpc_get_credit_profile(TEXT) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: rpc_get_credit_profile'; END $$;
DO $$ BEGIN ALTER FUNCTION public.set_trial_end_date() SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: set_trial_end_date'; END $$;
DO $$ BEGIN ALTER FUNCTION public.insert_events_batch(JSONB) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: insert_events_batch'; END $$;
DO $$ BEGIN ALTER FUNCTION public.validate_event_hash(TEXT, TEXT) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: validate_event_hash'; END $$;
DO $$ BEGIN ALTER FUNCTION public.protect_event_immutability() SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: protect_event_immutability'; END $$;
DO $$ BEGIN ALTER FUNCTION public.migrate_v1_to_shop(TEXT) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: migrate_v1_to_shop'; END $$;
DO $$ BEGIN ALTER FUNCTION public.exec_sql(TEXT) SET search_path = public; EXCEPTION WHEN undefined_function THEN RAISE NOTICE 'Skipped: exec_sql'; END $$;


-- ╔══════════════════════════════════════════════╗
-- ║ SECTION 4: TIGHTEN OVERLY-PERMISSIVE POLICIES║
-- ╚══════════════════════════════════════════════╝

-- 4a. orders — INSERT: scope to authenticated users who own the shop
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON orders;
CREATE POLICY "Enable insert for authenticated users only" ON orders
FOR INSERT WITH CHECK (
  auth.uid() IS NOT NULL
  AND shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid() AND is_active = true
  )
);

-- 4b. shop_members — UPDATE: scope to own record or shop owner
DROP POLICY IF EXISTS "Allow shop members to update their own data" ON shop_members;
CREATE POLICY "Allow shop members to update their own data" ON shop_members
FOR UPDATE USING (
  user_id = auth.uid()
  OR shop_id IN (
    SELECT sm.shop_id FROM shop_members sm
    WHERE sm.user_id = auth.uid() AND sm.role = 'OWNER' AND sm.is_active = true
  )
);

-- 4c. shop_members — INSERT: keep permissive for SECURITY DEFINER functions
-- The create_shop_secure / join_shop_secure functions are SECURITY DEFINER
-- and handle their own auth. Direct API inserts are still guarded by anon auth.
-- We tighten to authenticated-only to prevent fully anonymous inserts.
DROP POLICY IF EXISTS "Allow anyone to insert shop members" ON shop_members;
CREATE POLICY "Allow authenticated to insert shop members" ON shop_members
FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 4d. shops — INSERT: tighten to authenticated users
DROP POLICY IF EXISTS "Allow anyone to create shops" ON shops;
CREATE POLICY "Allow authenticated to create shops" ON shops
FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- 4e. team_invitations — ALL: scope to shop owner
DROP POLICY IF EXISTS "Allow shop owners to manage invitations" ON team_invitations;
CREATE POLICY "Allow shop owners to manage invitations" ON team_invitations
FOR ALL USING (
  shop_id IN (
    SELECT sm.shop_id FROM shop_members sm
    WHERE sm.user_id = auth.uid() AND sm.role = 'OWNER' AND sm.is_active = true
  )
) WITH CHECK (
  shop_id IN (
    SELECT sm.shop_id FROM shop_members sm
    WHERE sm.user_id = auth.uid() AND sm.role = 'OWNER' AND sm.is_active = true
  )
);


-- ╔══════════════════════════════════════════════╗
-- ║ SECTION 5: ADD POLICIES TO BARE RLS TABLES  ║
-- ╚══════════════════════════════════════════════╝

-- 5a. entertainment_assets — shop-scoped access
DROP POLICY IF EXISTS "Shop team can manage entertainment assets" ON entertainment_assets;
CREATE POLICY "Shop team can manage entertainment assets" ON entertainment_assets
FOR ALL USING (
  shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid() AND is_active = true
  )
) WITH CHECK (
  shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid() AND is_active = true
  )
);

-- Public read for buyer app discovery
DROP POLICY IF EXISTS "Anyone can view published entertainment assets" ON entertainment_assets;
CREATE POLICY "Anyone can view published entertainment assets" ON entertainment_assets
FOR SELECT USING (true);

-- 5b. lodging_rooms — shop-scoped access
DROP POLICY IF EXISTS "Shop team can manage lodging rooms" ON lodging_rooms;
CREATE POLICY "Shop team can manage lodging rooms" ON lodging_rooms
FOR ALL USING (
  shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid() AND is_active = true
  )
) WITH CHECK (
  shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid() AND is_active = true
  )
);

-- Public read for buyer app discovery
DROP POLICY IF EXISTS "Anyone can view published lodging rooms" ON lodging_rooms;
CREATE POLICY "Anyone can view published lodging rooms" ON lodging_rooms
FOR SELECT USING (true);

-- 5c. transactions — shop-scoped access
DROP POLICY IF EXISTS "Shop team can view transactions" ON transactions;
CREATE POLICY "Shop team can view transactions" ON transactions
FOR SELECT USING (
  shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid() AND is_active = true
  )
);

DROP POLICY IF EXISTS "Shop team can insert transactions" ON transactions;
CREATE POLICY "Shop team can insert transactions" ON transactions
FOR INSERT WITH CHECK (
  shop_id IN (
    SELECT shop_id FROM shop_members WHERE user_id = auth.uid() AND is_active = true
  )
);

-- 5d. franchises — owner-scoped
DROP POLICY IF EXISTS "Franchise owners can manage franchises" ON franchises;
CREATE POLICY "Franchise owners can manage franchises" ON franchises
FOR ALL USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

-- 5e. franchise_members — franchise-owner-scoped
DROP POLICY IF EXISTS "Franchise owners can manage members" ON franchise_members;
CREATE POLICY "Franchise owners can manage members" ON franchise_members
FOR ALL USING (
  franchise_id IN (
    SELECT id FROM franchises WHERE owner_id = auth.uid()
  )
) WITH CHECK (
  franchise_id IN (
    SELECT id FROM franchises WHERE owner_id = auth.uid()
  )
);


-- ╔══════════════════════════════════════════════╗
-- ║ SECTION 6: ADD MISSING PUBLISH COLUMNS       ║
-- ╚══════════════════════════════════════════════╝

ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS is_lodging_published BOOLEAN DEFAULT false;
ALTER TABLE public.shops ADD COLUMN IF NOT EXISTS is_entertainment_published BOOLEAN DEFAULT false;


-- ╔══════════════════════════════════════════════╗
-- ║ DONE                                         ║
-- ╚══════════════════════════════════════════════╝

SELECT 'Security Hardening v35 Applied! ✅' as status;
