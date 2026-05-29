-- ============================================
-- Migration v33: Add Yearly Subscription Plans
-- ============================================

-- 1. Drop the existing CHECK constraint from the shops table
ALTER TABLE shops DROP CONSTRAINT IF EXISTS shops_subscription_tier_check;

-- 2. Add the new CHECK constraint that includes the yearly plans
ALTER TABLE shops ADD CONSTRAINT shops_subscription_tier_check 
  CHECK (subscription_tier IN ('FREE', 'PRO', 'ENTERPRISE', 'PRO Yearly', 'ENTERPRISE Yearly'));

-- 3. Verify the change by selecting the table definition or running a test insert that rolls back
-- (Optional verification step usually removed for automated migrations)
