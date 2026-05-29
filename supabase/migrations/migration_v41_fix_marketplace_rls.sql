-- =============================================
-- migration_v41_fix_marketplace_rls.sql
-- Fixes RLS policies to ensure shop owners can manage their marketplace items
-- even if their user_id is not yet explicitly linked in shop_members.
-- Also grants authenticated users read access to storage.buckets to prevent
-- 403 errors during CloudStorageService._ensureBucketExists().
-- =============================================

-- ╔══════════════════════════════════════════════╗
-- ║ 1. Fix marketplace_items RLS                  ║
-- ╚══════════════════════════════════════════════╝
DROP POLICY IF EXISTS "Shop team can manage marketplace items" ON public.marketplace_items;

CREATE POLICY "Shop team can manage marketplace items" ON public.marketplace_items
FOR ALL USING (
  shop_id IN (
    SELECT shop_id FROM public.shop_members
    WHERE user_id = auth.uid() AND is_active = true
  )
  OR shop_id IN (
    SELECT id FROM public.shops
    WHERE owner_id = auth.uid()
  )
) WITH CHECK (
  shop_id IN (
    SELECT shop_id FROM public.shop_members
    WHERE user_id = auth.uid() AND is_active = true
  )
  OR shop_id IN (
    SELECT id FROM public.shops
    WHERE owner_id = auth.uid()
  )
);

-- ╔══════════════════════════════════════════════╗
-- ║ 2. Allow clients to list storage buckets      ║
-- ╚══════════════════════════════════════════════╝
DROP POLICY IF EXISTS "Authenticated users can list buckets" ON storage.buckets;

CREATE POLICY "Authenticated users can list buckets" ON storage.buckets
FOR SELECT TO authenticated USING (true);

SELECT 'v41 fix-marketplace-rls migration applied ✅' AS status;
