-- =============================================
-- migration_v44_online_store.sql
-- Adds branding and module toggles to the shops table
-- to power the Mbeck Go "Business Hub"
-- =============================================

ALTER TABLE public.shops
ADD COLUMN IF NOT EXISTS theme_config JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS is_retail_published BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS is_restaurant_published BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS is_lodging_published BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS is_services_published BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS is_entertainment_published BOOLEAN DEFAULT false;

SELECT 'v44 online store migration defined ✅' AS status;
