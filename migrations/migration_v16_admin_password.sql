-- ============================================
-- Migration: Admin Password System
-- Date: 2026-01-31
-- Purpose: Add separate admin password for manager-level access
-- ============================================

-- Add admin_password_hash column to shops table
ALTER TABLE shops 
ADD COLUMN IF NOT EXISTS admin_password_hash TEXT;

-- Add comment for documentation
COMMENT ON COLUMN shops.admin_password_hash IS 
'Hashed admin password for manager-level access. Required when joining as MANAGER role.';

-- Update existing shops to use same hash for both (backward compatibility)
-- This allows existing shops to work without breaking
UPDATE shops 
SET admin_password_hash = password_hash 
WHERE admin_password_hash IS NULL;

-- Verification query
SELECT 
  id,
  business_name,
  password_hash IS NOT NULL as has_shop_password,
  admin_password_hash IS NOT NULL as has_admin_password,
  created_at
FROM shops
ORDER BY created_at DESC
LIMIT 5;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Admin password column added successfully!';
    RAISE NOTICE 'Existing shops use same password for both shop and admin access';
    RAISE NOTICE 'New shops can set separate admin passwords';
END $$;
