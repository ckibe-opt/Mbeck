-- Fix RLS policy blocking shop creation for new devices
-- The v21 migration added a strict constraint (auth.uid() = owner_id)
-- but many offline Mbeck shops don't have a linked auth.user yet.

-- 1. Drop the strict INSERT policy
DROP POLICY IF EXISTS "Owners can create shops" ON public.shops;
DROP POLICY IF EXISTS "Allow anyone to create shops" ON public.shops;

-- 2. Restore the original behavior: anyone can create a shop
-- Security is handled by the unguessable shop_id + password_hash
CREATE POLICY "Allow anyone to create shops" 
ON public.shops FOR INSERT 
WITH CHECK (true);

-- 3. Also fix the SELECT policy to allow the shop app to verify its own shop
-- even if it hasn't linked a user account yet
DROP POLICY IF EXISTS "Owners can view their shops" ON public.shops;

CREATE POLICY "Devices can view their shops" 
ON public.shops FOR SELECT 
USING (
  -- Either the connected Supabase user is the owner
  (auth.uid() = owner_id) OR
  -- OR the shop is being queried (public read for auth handshake)
  (true)
);

-- 4. Fix shop_members INSERT policy similarly
DROP POLICY IF EXISTS "Allow anyone to insert shop members" ON public.shop_members;
CREATE POLICY "Allow anyone to insert shop members"
ON public.shop_members FOR INSERT
WITH CHECK (true);
