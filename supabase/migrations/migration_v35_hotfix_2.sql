-- =============================================
-- migration_v35_hotfix_2.sql
-- Fixes missing digest() function error 
-- by adding 'extensions' schema to search_path
-- Run in Supabase SQL Editor
-- =============================================

-- ╔══════════════════════════════════════════════╗
-- ║ FIX: Add extensions to search_path           ║
-- ║                                               ║
-- ║ The pgcrypto extension lives in the 'extensions'║
-- ║ schema. If search_path is only 'public',     ║
-- ║ digest() will not be found.                  ║
-- ╚══════════════════════════════════════════════╝

-- 1. create_shop_secure
CREATE OR REPLACE FUNCTION create_shop_secure(
  p_shop_id TEXT,
  p_name TEXT,
  p_password TEXT,
  p_admin_password TEXT,
  p_owner_device_id TEXT,
  p_owner_name TEXT,
  p_owner_user_id UUID DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_salt TEXT := 'myshop_salt_2025_v1';
  v_password_hash TEXT;
  v_admin_hash TEXT;
  v_shop RECORD;
  v_member RECORD;
BEGIN
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

-- 2. join_shop_secure
CREATE OR REPLACE FUNCTION join_shop_secure(
  p_shop_id TEXT,
  p_password TEXT,
  p_device_id TEXT,
  p_user_name TEXT,
  p_join_as_manager BOOLEAN DEFAULT FALSE,
  p_admin_password TEXT DEFAULT NULL,
  p_user_id UUID DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
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
  IF v_shop IS NULL THEN
    RAISE EXCEPTION 'Shop not found. Please check the Shop ID.';
  END IF;

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
    v_permissions := '{"manage_inventory":true,"view_reports":true,"manage_team":false,"manage_settings":false,"can_void":true,"can_discount":true}'::jsonb;
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
    'shop', jsonb_build_object('id', v_shop.id, 'name', v_shop.name, 'subscription_tier', v_shop.subscription_tier, 'subscription_status', v_shop.subscription_status),
    'member', row_to_json(v_member)
  );
END;
$$;

-- 3. login_shop_secure
CREATE OR REPLACE FUNCTION login_shop_secure(
  p_shop_id TEXT,
  p_password TEXT,
  p_device_id TEXT
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_salt TEXT := 'myshop_salt_2025_v1';
  v_shop RECORD;
  v_hash TEXT;
  v_existing RECORD;
BEGIN
  SELECT * INTO v_shop FROM shops WHERE id = p_shop_id;
  IF v_shop IS NULL THEN
    RAISE EXCEPTION 'Shop not found. Please check the Shop ID.';
  END IF;

  IF NOT check_rate_limit(p_device_id) THEN
    RAISE EXCEPTION 'Too many failed login attempts. Please try again in 15 minutes.';
  END IF;

  v_hash := encode(digest(p_password || v_salt, 'sha256'), 'hex');
  IF v_hash != v_shop.password_hash AND v_hash != COALESCE(v_shop.admin_password_hash, '') THEN
    PERFORM record_auth_attempt(p_device_id, p_shop_id, FALSE);
    RAISE EXCEPTION 'Incorrect password. Please try again.';
  END IF;

  SELECT * INTO v_existing FROM shop_members
  WHERE shop_id = p_shop_id AND device_id = p_device_id;

  IF v_existing IS NULL THEN
    RAISE EXCEPTION 'Device is not registered to this shop. Please "Join Shop" instead.';
  END IF;

  UPDATE shop_members SET is_active = TRUE, last_active_at = NOW()
  WHERE id = v_existing.id;

  PERFORM record_auth_attempt(p_device_id, p_shop_id, TRUE);

  RETURN jsonb_build_object(
    'shop', jsonb_build_object('id', v_shop.id, 'name', v_shop.name, 'subscription_tier', v_shop.subscription_tier, 'subscription_status', v_shop.subscription_status),
    'member', row_to_json(v_existing)
  );
END;
$$;

-- 4. verify_shop_password
CREATE OR REPLACE FUNCTION verify_shop_password(
  p_shop_id TEXT,
  p_password TEXT,
  p_check_admin BOOLEAN DEFAULT FALSE
) RETURNS TABLE(
  shop_id TEXT,
  shop_name TEXT,
  is_valid BOOLEAN,
  matched_role TEXT
) LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions
AS $$
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

  v_hash := encode(digest(p_password || v_salt, 'sha256'), 'hex');

  IF p_check_admin AND v_shop.admin_password_hash IS NOT NULL THEN
    IF v_hash = v_shop.admin_password_hash THEN
      RETURN QUERY SELECT v_shop.id, v_shop.name, TRUE, 'admin'::TEXT;
      RETURN;
    END IF;
  END IF;

  IF v_hash = v_shop.password_hash THEN
    RETURN QUERY SELECT v_shop.id, v_shop.name, TRUE, 'shop'::TEXT;
    RETURN;
  END IF;

  RETURN QUERY SELECT v_shop.id, v_shop.name, FALSE, ''::TEXT;
END;
$$;

-- ╔══════════════════════════════════════════════╗
-- ║ DONE                                         ║
-- ╚══════════════════════════════════════════════╝
SELECT 'v35 Hotfix 2 Applied! Added extensions to search_path ✅' as status;
