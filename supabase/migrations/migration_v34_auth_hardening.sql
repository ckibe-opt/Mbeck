-- =============================================
-- migration_v34_auth_hardening.sql
-- Server-side password verification & tighter RLS
-- Run in Supabase SQL Editor
-- =============================================

-- 1. Install pgcrypto for future bcrypt migration
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =============================================
-- 2. Server-side password verification
-- Keeps password_hash values inside the DB
-- =============================================
CREATE OR REPLACE FUNCTION verify_shop_password(
  p_shop_id TEXT,
  p_password TEXT,
  p_check_admin BOOLEAN DEFAULT FALSE
) RETURNS TABLE(
  shop_id TEXT,
  shop_name TEXT,
  is_valid BOOLEAN,
  matched_role TEXT  -- 'shop', 'admin', or '' if invalid
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_shop RECORD;
  v_hash TEXT;
  v_salt TEXT := 'myshop_salt_2025_v1';
BEGIN
  SELECT s.id, s.name, s.password_hash, s.admin_password_hash
  INTO v_shop FROM shops s WHERE s.id = p_shop_id;

  IF v_shop IS NULL THEN
    RETURN QUERY SELECT p_shop_id, ''::TEXT, FALSE, ''::TEXT;
    RETURN;
  END IF;

  -- Compute hash using same algorithm as Flutter client
  v_hash := encode(digest(p_password || v_salt, 'sha256'), 'hex');

  -- Check admin password first if requested
  IF p_check_admin AND v_shop.admin_password_hash IS NOT NULL THEN
    IF v_hash = v_shop.admin_password_hash THEN
      RETURN QUERY SELECT v_shop.id, v_shop.name, TRUE, 'admin'::TEXT;
      RETURN;
    END IF;
  END IF;

  -- Check shop password
  IF v_hash = v_shop.password_hash THEN
    RETURN QUERY SELECT v_shop.id, v_shop.name, TRUE, 'shop'::TEXT;
    RETURN;
  END IF;

  -- Both failed
  RETURN QUERY SELECT v_shop.id, v_shop.name, FALSE, ''::TEXT;
END;
$$;

-- =============================================
-- 3. Server-side shop creation (hashing in DB)
-- =============================================
CREATE OR REPLACE FUNCTION create_shop_secure(
  p_shop_id TEXT,
  p_name TEXT,
  p_password TEXT,
  p_admin_password TEXT,
  p_owner_device_id TEXT,
  p_owner_name TEXT,
  p_owner_user_id UUID DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_salt TEXT := 'myshop_salt_2025_v1';
  v_password_hash TEXT;
  v_admin_hash TEXT;
  v_shop RECORD;
  v_member RECORD;
BEGIN
  -- Hash passwords server-side
  v_password_hash := encode(digest(p_password || v_salt, 'sha256'), 'hex');
  v_admin_hash := encode(digest(p_admin_password || v_salt, 'sha256'), 'hex');

  INSERT INTO shops (id, name, password_hash, admin_password_hash, owner_device_id, owner_id,
                     subscription_tier, subscription_status)
  VALUES (p_shop_id, p_name, v_password_hash, v_admin_hash, p_owner_device_id, p_owner_user_id,
          'FREE', 'ACTIVE')
  RETURNING * INTO v_shop;

  INSERT INTO shop_members (shop_id, device_id, user_id, user_name, role, permissions)
  VALUES (p_shop_id, p_owner_device_id, p_owner_user_id, p_owner_name, 'OWNER',
          '{"manage_inventory":true,"view_reports":true,"manage_team":true,"manage_settings":true,"can_void":true,"can_discount":true,"can_refund":true}'::jsonb)
  RETURNING * INTO v_member;

  RETURN jsonb_build_object('shop', row_to_json(v_shop), 'member', row_to_json(v_member));
END;
$$;

-- =============================================
-- 4. Server-side join shop (verify + insert member)
-- =============================================
CREATE OR REPLACE FUNCTION join_shop_secure(
  p_shop_id TEXT,
  p_password TEXT,
  p_device_id TEXT,
  p_user_name TEXT,
  p_join_as_manager BOOLEAN DEFAULT FALSE,
  p_admin_password TEXT DEFAULT NULL,
  p_user_id UUID DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
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
  -- Fetch shop
  SELECT * INTO v_shop FROM shops WHERE id = p_shop_id;
  IF v_shop IS NULL THEN
    RAISE EXCEPTION 'Shop not found. Please check the Shop ID.';
  END IF;

  -- Rate limit check
  IF NOT check_rate_limit(p_device_id) THEN
    RAISE EXCEPTION 'Too many failed login attempts. Please try again in 15 minutes.';
  END IF;

  -- Verify shop password
  v_hash := encode(digest(p_password || v_salt, 'sha256'), 'hex');
  IF v_hash != v_shop.password_hash THEN
    PERFORM record_auth_attempt(p_device_id, p_shop_id, FALSE);
    RAISE EXCEPTION 'Incorrect shop password. Please try again.';
  END IF;

  -- Default role
  v_role := 'CASHIER';
  v_permissions := '{"manage_inventory":false,"view_reports":false,"manage_team":false,"manage_settings":false}'::jsonb;

  -- Check admin password if joining as manager
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
    v_permissions := '{"manage_inventory":true,"view_reports":true,"manage_team":false,"manage_settings":false,"can_void":true,"can_discount":true}'::jsonb;
  END IF;

  -- Check if device already member
  SELECT * INTO v_existing FROM shop_members
  WHERE shop_id = p_shop_id AND device_id = p_device_id;

  IF v_existing IS NOT NULL THEN
    -- Reactivate + optionally upgrade
    UPDATE shop_members SET
      is_active = TRUE,
      last_active_at = NOW(),
      role = CASE WHEN p_join_as_manager AND v_existing.role != 'OWNER' THEN v_role ELSE v_existing.role END,
      permissions = CASE WHEN p_join_as_manager AND v_existing.role != 'OWNER' THEN v_permissions ELSE v_existing.permissions END
    WHERE id = v_existing.id
    RETURNING * INTO v_member;
  ELSE
    -- New member
    INSERT INTO shop_members (shop_id, device_id, user_id, user_name, role, permissions)
    VALUES (p_shop_id, p_device_id, p_user_id, p_user_name, v_role, v_permissions)
    RETURNING * INTO v_member;
  END IF;

  -- Record success
  PERFORM record_auth_attempt(p_device_id, p_shop_id, TRUE);

  RETURN jsonb_build_object(
    'shop', jsonb_build_object('id', v_shop.id, 'name', v_shop.name, 'subscription_tier', v_shop.subscription_tier, 'subscription_status', v_shop.subscription_status),
    'member', row_to_json(v_member)
  );
END;
$$;

-- =============================================
-- 5. Server-side login (verify + reactivate)
-- =============================================
CREATE OR REPLACE FUNCTION login_shop_secure(
  p_shop_id TEXT,
  p_password TEXT,
  p_device_id TEXT
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_salt TEXT := 'myshop_salt_2025_v1';
  v_shop RECORD;
  v_hash TEXT;
  v_existing RECORD;
BEGIN
  -- Fetch shop
  SELECT * INTO v_shop FROM shops WHERE id = p_shop_id;
  IF v_shop IS NULL THEN
    RAISE EXCEPTION 'Shop not found. Please check the Shop ID.';
  END IF;

  -- Rate limit check
  IF NOT check_rate_limit(p_device_id) THEN
    RAISE EXCEPTION 'Too many failed login attempts. Please try again in 15 minutes.';
  END IF;

  -- Verify password (either shop or admin)
  v_hash := encode(digest(p_password || v_salt, 'sha256'), 'hex');
  IF v_hash != v_shop.password_hash AND v_hash != COALESCE(v_shop.admin_password_hash, '') THEN
    PERFORM record_auth_attempt(p_device_id, p_shop_id, FALSE);
    RAISE EXCEPTION 'Incorrect password. Please try again.';
  END IF;

  -- Check device is registered
  SELECT * INTO v_existing FROM shop_members
  WHERE shop_id = p_shop_id AND device_id = p_device_id;

  IF v_existing IS NULL THEN
    RAISE EXCEPTION 'Device is not registered to this shop. Please "Join Shop" instead.';
  END IF;

  -- Reactivate
  UPDATE shop_members SET is_active = TRUE, last_active_at = NOW()
  WHERE id = v_existing.id;

  -- Record success
  PERFORM record_auth_attempt(p_device_id, p_shop_id, TRUE);

  RETURN jsonb_build_object(
    'shop', jsonb_build_object('id', v_shop.id, 'name', v_shop.name, 'subscription_tier', v_shop.subscription_tier, 'subscription_status', v_shop.subscription_status),
    'member', row_to_json(v_existing)
  );
END;
$$;

-- =============================================
-- 6. Rate-limiting table
-- =============================================
CREATE TABLE IF NOT EXISTS auth_attempts (
  id SERIAL PRIMARY KEY,
  identifier TEXT NOT NULL,     -- device_id or IP
  shop_id TEXT,
  attempted_at TIMESTAMPTZ DEFAULT NOW(),
  success BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_auth_attempts_lookup
ON auth_attempts(identifier, attempted_at);

-- Auto-cleanup old records (older than 24h)
CREATE OR REPLACE FUNCTION cleanup_old_auth_attempts()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM auth_attempts WHERE attempted_at < NOW() - INTERVAL '24 hours';
END;
$$;

-- Rate-limit check function (max 5 failures in 15 min)
CREATE OR REPLACE FUNCTION check_rate_limit(p_identifier TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
  v_count INT;
BEGIN
  SELECT COUNT(*) INTO v_count FROM auth_attempts
  WHERE identifier = p_identifier
    AND success = FALSE
    AND attempted_at > NOW() - INTERVAL '15 minutes';
  RETURN v_count < 5;
END;
$$;

-- Record an attempt
CREATE OR REPLACE FUNCTION record_auth_attempt(
  p_identifier TEXT,
  p_shop_id TEXT,
  p_success BOOLEAN
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO auth_attempts (identifier, shop_id, success)
  VALUES (p_identifier, p_shop_id, p_success);
END;
$$;

-- =============================================
-- 7. Secure shop view (no password hashes)
-- =============================================
CREATE OR REPLACE VIEW shops_public AS
SELECT id, name, subscription_tier, subscription_status, created_at, updated_at
FROM shops;

-- Grant access to the public view
GRANT SELECT ON shops_public TO anon, authenticated;

-- =============================================
-- 8. RLS for auth_attempts table
-- =============================================
ALTER TABLE auth_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Functions only" ON auth_attempts;
CREATE POLICY "Functions only" ON auth_attempts
FOR ALL USING (false); -- Only SECURITY DEFINER functions can access
