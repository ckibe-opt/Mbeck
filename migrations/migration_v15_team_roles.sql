-- ============================================
-- Migration: Update shop_members for Phase 9 Role System (FIXED)
-- Date: 2026-01-31
-- Purpose: Support new retail roles (Stocker, Supervisor, etc.)
-- Run this version if you got "constraint already exists" error
-- ============================================

-- Step 1: Drop existing constraint
DO $$ 
BEGIN
    -- Try to drop the constraint
    EXECUTE 'ALTER TABLE shop_members DROP CONSTRAINT shop_members_role_check';
    RAISE NOTICE 'Dropped existing role check constraint';
EXCEPTION
    WHEN undefined_object THEN 
        RAISE NOTICE 'No existing constraint to drop';
END $$;

-- Step 2: Add new role constraint with all supported roles
ALTER TABLE shop_members 
ADD CONSTRAINT shop_members_role_check 
CHECK (role IN (
  'OWNER',
  'ADMIN',
  'MANAGER',           -- Alias for ADMIN
  'STAFF',
  'CASHIER',           -- Alias for STAFF
  'STOCKER',           -- NEW: Inventory clerk
  'INVENTORY_CLERK',   -- Alias for STOCKER
  'SHIFT_SUPERVISOR',  -- NEW: Senior cashier
  'SUPERVISOR',        -- Alias for SHIFT_SUPERVISOR
  'INVENTORY_MANAGER', -- NEW: Full inventory control
  'CUSTOM'             -- NEW: Owner-defined permissions
));

-- Step 3: Update existing STAFF members to CASHIER (optional, for clarity)
-- Uncomment if you want to rename existing roles
-- UPDATE shop_members SET role = 'CASHIER' WHERE role = 'STAFF';
-- UPDATE shop_members SET role = 'MANAGER' WHERE role = 'ADMIN';

-- Step 4: Add comment to role column for documentation
COMMENT ON COLUMN shop_members.role IS 'User role: OWNER, MANAGER, CASHIER, STOCKER, SHIFT_SUPERVISOR, INVENTORY_MANAGER, or CUSTOM';

-- Step 5: Create index for role-based queries (performance optimization)
CREATE INDEX IF NOT EXISTS idx_shop_members_role 
ON shop_members(shop_id, role) 
WHERE is_active = true;

-- ============================================
-- Optional: Create team_invitations table
-- ============================================

CREATE TABLE IF NOT EXISTS team_invitations (
  id SERIAL PRIMARY KEY,
  shop_id TEXT REFERENCES shops(id) ON DELETE CASCADE,
  invited_name TEXT NOT NULL,
  invited_role TEXT NOT NULL,
  note TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '7 days',
  accepted_at TIMESTAMP WITH TIME ZONE,
  accepted_by_device_id TEXT
);

CREATE INDEX IF NOT EXISTS idx_team_invitations_shop 
ON team_invitations(shop_id, status);

-- Enable RLS for team_invitations
ALTER TABLE team_invitations ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    -- Try to create policy, ignore if exists
    CREATE POLICY "Allow shop owners to manage invitations"
    ON team_invitations FOR ALL
    USING (true);
EXCEPTION
    WHEN duplicate_object THEN 
        RAISE NOTICE 'RLS policy already exists';
END $$;

-- ============================================
-- Helper Functions
-- ============================================

-- Function: Get team member count by role
CREATE OR REPLACE FUNCTION get_team_role_counts(p_shop_id TEXT)
RETURNS TABLE(role TEXT, count BIGINT) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sm.role,
    COUNT(*)::BIGINT
  FROM shop_members sm
  WHERE sm.shop_id = p_shop_id 
    AND sm.is_active = true
  GROUP BY sm.role
  ORDER BY 
    CASE sm.role
      WHEN 'OWNER' THEN 1
      WHEN 'MANAGER' THEN 2
      WHEN 'ADMIN' THEN 2
      WHEN 'SHIFT_SUPERVISOR' THEN 3
      WHEN 'SUPERVISOR' THEN 3
      WHEN 'INVENTORY_MANAGER' THEN 4
      WHEN 'CASHIER' THEN 5
      WHEN 'STAFF' THEN 5
      WHEN 'STOCKER' THEN 6
      WHEN 'INVENTORY_CLERK' THEN 6
      WHEN 'CUSTOM' THEN 7
      ELSE 999
    END;
END;
$$ LANGUAGE plpgsql;

-- Function: Check if user can edit member
CREATE OR REPLACE FUNCTION can_edit_team_member(
  p_editor_device_id TEXT,
  p_target_device_id TEXT,
  p_shop_id TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  editor_role TEXT;
  target_role TEXT;
BEGIN
  -- Get editor's role
  SELECT role INTO editor_role
  FROM shop_members
  WHERE shop_id = p_shop_id 
    AND device_id = p_editor_device_id
    AND is_active = true;

  -- Get target's role
  SELECT role INTO target_role
  FROM shop_members
  WHERE shop_id = p_shop_id 
    AND device_id = p_target_device_id
    AND is_active = true;

  -- Owner can edit anyone
  IF editor_role = 'OWNER' THEN
    RETURN true;
  END IF;

  -- Cannot edit yourself (for role changes)
  IF p_editor_device_id = p_target_device_id THEN
    RETURN false;
  END IF;

  -- Manager can edit non-management roles
  IF editor_role IN ('MANAGER', 'ADMIN') THEN
    RETURN target_role NOT IN ('OWNER', 'MANAGER', 'ADMIN');
  END IF;

  -- Others cannot edit
  RETURN false;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Verification Queries
-- ============================================

-- Verify constraint update
SELECT 
  conname AS constraint_name,
  pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint 
WHERE conrelid = 'shop_members'::regclass 
  AND conname = 'shop_members_role_check';

-- Verify indexes
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'shop_members'
ORDER BY indexname;

-- Test role counts function (replace with your shop_id)
-- SELECT * FROM get_team_role_counts('your_shop_id_here');

-- ============================================
-- Success Message
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE 'New roles supported: OWNER, MANAGER, CASHIER, STOCKER, SHIFT_SUPERVISOR, INVENTORY_MANAGER, CUSTOM';
END $$;
