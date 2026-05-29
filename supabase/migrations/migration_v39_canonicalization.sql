-- =============================================
-- migration_v39_canonicalization.sql
-- Settles three long-standing schema disagreements that the audit surfaced.
-- Run AFTER migration_v38_audit_fixes.sql.
--
--   1. transactions.type        -> transaction_type
--      transactions.source_module -> module_source
--      (canonicalize on the SQL names that 001/005/006 already declared)
--
--   3. shop_members.role CHECK consolidated to the Phase-9 superset.
--      Manager permissions standardized to the hotfix-3 "full" set.
--
--   4. orders policies fixed so authenticated buyers (who are not shop
--      members) can place orders, but only shop members can read them.
-- =============================================


-- ╔══════════════════════════════════════════════╗
-- ║ 1. Canonicalize transactions column names     ║
-- ╚══════════════════════════════════════════════╝
DO $$
BEGIN
  -- type -> transaction_type
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='transactions' AND column_name='type'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='transactions' AND column_name='transaction_type'
  ) THEN
    EXECUTE 'ALTER TABLE public.transactions RENAME COLUMN type TO transaction_type';
  END IF;

  -- source_module -> module_source
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='transactions' AND column_name='source_module'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='transactions' AND column_name='module_source'
  ) THEN
    EXECUTE 'ALTER TABLE public.transactions RENAME COLUMN source_module TO module_source';
  END IF;
END $$;

-- Re-assert the CHECK constraints (idempotent; matches 005 + 006).
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;
ALTER TABLE public.transactions ADD CONSTRAINT transactions_transaction_type_check
  CHECK (transaction_type IN ('sale','booking','order','refund','session','reservation'));

ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_module_source_check;
ALTER TABLE public.transactions ADD CONSTRAINT transactions_module_source_check
  CHECK (module_source IN ('retail','services','restaurant','entertainment','lodging'));


-- ╔══════════════════════════════════════════════╗
-- ║ 3. shop_members.role canonical set            ║
-- ║                                               ║
-- ║ Active roles emitted by RPCs:                 ║
-- ║   OWNER, MANAGER, CASHIER                     ║
-- ║                                               ║
-- ║ Phase-9 extended roles (kept for forward use):║
-- ║   STOCKER, SHIFT_SUPERVISOR,                  ║
-- ║   INVENTORY_MANAGER, CUSTOM                   ║
-- ║                                               ║
-- ║ Legacy roles kept ONLY for historical rows:   ║
-- ║   ADMIN, STAFF, SUPERVISOR, INVENTORY_CLERK   ║
-- ║   (do not insert these going forward; the     ║
-- ║   RPCs already migrated.)                     ║
-- ╚══════════════════════════════════════════════╝
ALTER TABLE public.shop_members DROP CONSTRAINT IF EXISTS shop_members_role_check;
ALTER TABLE public.shop_members ADD CONSTRAINT shop_members_role_check
  CHECK (role IN (
    -- Active
    'OWNER', 'MANAGER', 'CASHIER',
    -- Phase-9 forward-looking
    'STOCKER', 'SHIFT_SUPERVISOR', 'INVENTORY_MANAGER', 'CUSTOM',
    -- Legacy aliases (data preservation only)
    'ADMIN', 'STAFF', 'SUPERVISOR', 'INVENTORY_CLERK'
  ));

CREATE INDEX IF NOT EXISTS idx_shop_members_role
  ON public.shop_members(shop_id, role) WHERE is_active = true;

-- Standardize MANAGER permissions to the full hotfix-3 set, retroactively.
-- (hotfix-1/-2 left some managers with manage_team:false / manage_settings:false.)
UPDATE public.shop_members
SET permissions = jsonb_build_object(
  'manage_inventory', true,
  'view_reports',     true,
  'manage_team',      true,
  'manage_settings',  true,
  'can_void',         true,
  'can_discount',     true,
  'can_refund',       true
)
WHERE role = 'MANAGER'
  AND (permissions IS NULL
       OR permissions->>'manage_team'     = 'false'
       OR permissions->>'manage_settings' = 'false');

-- Rebind join_shop_secure to issue the full manager permission set going forward,
-- matching hotfix-3 (which was the latest pasted intent in the audit).
CREATE OR REPLACE FUNCTION public.join_shop_secure(
  p_shop_id TEXT,
  p_password TEXT,
  p_device_id TEXT,
  p_user_name TEXT,
  p_join_as_manager BOOLEAN DEFAULT FALSE,
  p_admin_password TEXT DEFAULT NULL,
  p_user_id UUID DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_salt TEXT := 'myshop_salt_2025_v1';
  v_shop RECORD;
  v_hash TEXT;
  v_admin_hash TEXT;
  v_role TEXT;
  v_permissions JSONB;
  v_existing RECORD;
  v_member RECORD;
BEGIN
  SELECT * INTO v_shop FROM shops WHERE id = p_shop_id;
  IF v_shop IS NULL THEN RAISE EXCEPTION 'Shop not found. Please check the Shop ID.'; END IF;

  IF NOT check_rate_limit(p_device_id) THEN
    RAISE EXCEPTION 'Too many failed login attempts. Please try again in 15 minutes.';
  END IF;

  v_hash := encode(digest(p_password || v_salt, 'sha256'), 'hex');
  IF v_hash != v_shop.password_hash THEN
    PERFORM record_auth_attempt(p_device_id, p_shop_id, FALSE);
    RAISE EXCEPTION 'Incorrect shop password. Please try again.';
  END IF;

  v_role := 'CASHIER';
  v_permissions := '{"manage_inventory":false,"view_reports":false,"manage_team":false,"manage_settings":false}'::jsonb;

  IF p_join_as_manager THEN
    IF p_admin_password IS NULL OR p_admin_password = '' THEN
      RAISE EXCEPTION 'Admin password is required for Manager access.';
    END IF;
    v_admin_hash := encode(digest(p_admin_password || v_salt, 'sha256'), 'hex');
    IF v_admin_hash != COALESCE(v_shop.admin_password_hash, v_shop.password_hash) THEN
      PERFORM record_auth_attempt(p_device_id, p_shop_id, FALSE);
      RAISE EXCEPTION 'Incorrect ADMIN password.';
    END IF;
    v_role := 'MANAGER';
    -- Hotfix-3: full manager permissions
    v_permissions := '{
      "manage_inventory": true, "view_reports": true,
      "manage_team": true, "manage_settings": true,
      "can_void": true, "can_discount": true, "can_refund": true
    }'::jsonb;
  END IF;

  SELECT * INTO v_existing FROM shop_members
  WHERE shop_id = p_shop_id AND device_id = p_device_id;

  IF v_existing IS NOT NULL THEN
    UPDATE shop_members SET
      is_active = TRUE,
      last_active_at = NOW(),
      role = CASE WHEN p_join_as_manager AND v_existing.role != 'OWNER' THEN v_role ELSE v_existing.role END,
      permissions = CASE WHEN p_join_as_manager AND v_existing.role != 'OWNER' THEN v_permissions ELSE v_existing.permissions END
    WHERE id = v_existing.id
    RETURNING * INTO v_member;
  ELSE
    INSERT INTO shop_members (shop_id, device_id, user_id, user_name, role, permissions)
    VALUES (p_shop_id, p_device_id, p_user_id, p_user_name, v_role, v_permissions)
    RETURNING * INTO v_member;
  END IF;

  PERFORM record_auth_attempt(p_device_id, p_shop_id, TRUE);

  RETURN jsonb_build_object(
    'shop',   jsonb_build_object('id', v_shop.id, 'name', v_shop.name,
                                 'subscription_tier', v_shop.subscription_tier,
                                 'subscription_status', v_shop.subscription_status),
    'member', row_to_json(v_member)
  );
END;
$$;


-- ╔══════════════════════════════════════════════╗
-- ║ 4. Fix orders policies                        ║
-- ║                                               ║
-- ║ Decision: buyers are authenticated users from ║
-- ║ the Mbeck Go buyer app. They are NOT members  ║
-- ║ of the seller's shop, so v35-hardening's      ║
-- ║ "must be in shop_members" gate broke them.    ║
-- ║ Restore broad authenticated INSERT, and tight- ║
-- ║ scope SELECT to shop members only.            ║
-- ╚══════════════════════════════════════════════╝

-- Wipe any conflicting policies first
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.orders;
DROP POLICY IF EXISTS "Enable read for shops"                      ON public.orders;
DROP POLICY IF EXISTS "Buyers can insert their own orders"         ON public.orders;
DROP POLICY IF EXISTS "Shop members can read their orders"         ON public.orders;

-- Buyers (any authenticated user) can place an order on any shop_id.
-- We rely on shop_id validation in the buyer app + edge function.
CREATE POLICY "Buyers can insert their own orders" ON public.orders
FOR INSERT TO authenticated
WITH CHECK (auth.uid() IS NOT NULL);

-- Sellers (shop members only) can read their orders.
CREATE POLICY "Shop members can read their orders" ON public.orders
FOR SELECT USING (
  shop_id IN (
    SELECT shop_id FROM public.shop_members
    WHERE user_id = auth.uid() AND is_active = true
  )
);

-- Sellers can also update order status (process / cancel) for their own shop.
DROP POLICY IF EXISTS "Shop members can update their orders" ON public.orders;
CREATE POLICY "Shop members can update their orders" ON public.orders
FOR UPDATE USING (
  shop_id IN (
    SELECT shop_id FROM public.shop_members
    WHERE user_id = auth.uid() AND is_active = true
  )
) WITH CHECK (
  shop_id IN (
    SELECT shop_id FROM public.shop_members
    WHERE user_id = auth.uid() AND is_active = true
  )
);


SELECT 'v39 canonicalization migration applied ✅' AS status;
