-- =============================================
-- migration_v45_fix_shops_rls.sql
-- Fixes password hash exposure in the shops table 
-- by dropping public select policy and recreating 
-- a secure shops_public view.
-- =============================================

-- 1. Drop the overly permissive public policy on shops table
-- This prevents attackers from querying the password_hash via the REST API.
DROP POLICY IF EXISTS "Public can view verified published shops" ON public.shops;

-- 2. Recreate shops_public view as SECURITY DEFINER (default) to bypass restricted RLS,
-- while safely exposing only non-sensitive columns for published and verified shops.
DROP VIEW IF EXISTS public.shops_public;

CREATE VIEW public.shops_public AS
SELECT 
    id, 
    name, 
    branding, 
    enabled_modules, 
    shop_type,
    currency,
    is_retail_published, 
    is_restaurant_published, 
    is_services_published, 
    is_lodging_published, 
    is_entertainment_published, 
    is_published_online, 
    verification_status, 
    online_views, 
    subscription_tier, 
    subscription_status, 
    created_at, 
    updated_at
FROM public.shops
WHERE is_published_online = true 
  AND verification_status = 'VERIFIED';

-- 3. Grant public read access to the secure view
GRANT SELECT ON public.shops_public TO anon, authenticated;

SELECT 'Migration v45 (Password Hash Fix) Complete! ✅' as status;
