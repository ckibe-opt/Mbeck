-- ==============================================================================
-- MBECK ENTERPRISE SUBSCRIPTION INHERITANCE TRIGGER
-- ==============================================================================
-- This trigger ensures that when an Enterprise Manager creates a new branch,
-- the new branch automatically inherits their 'ENTERPRISE' subscription tier
-- and 'active' status instead of defaulting to 'FREE'.
-- 
-- Run this query in your Supabase SQL Editor.
-- ==============================================================================

-- 1. Create the inheritance function
CREATE OR REPLACE FUNCTION public.inherit_enterprise_subscription()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if the owner already has an active ENTERPRISE shop
  IF EXISTS (
    SELECT 1 
    FROM public.shops 
    WHERE owner_id = NEW.owner_id 
      AND subscription_tier = 'ENTERPRISE' 
      AND id != NEW.id
  ) THEN
    -- If they do, upgrade this newly created shop automatically
    UPDATE public.shops
    SET subscription_tier = 'ENTERPRISE',
        subscription_status = 'active'
    WHERE id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Bind the trigger to the shops table
DROP TRIGGER IF EXISTS trg_inherit_enterprise_subscription ON public.shops;
CREATE TRIGGER trg_inherit_enterprise_subscription
AFTER INSERT ON public.shops
FOR EACH ROW
EXECUTE FUNCTION public.inherit_enterprise_subscription();
