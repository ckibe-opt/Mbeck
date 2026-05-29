-- AGGRESSIVE FIX: Reset all RLS policies for shop registration
-- Because Mbeck is Offline-First, devices create shops and member rows BEFORE
-- they have a fully authenticated Supabase token. We must allow public inserts.

-- 1. Reset SHOPS table policies
DROP POLICY IF EXISTS "Allow anyone to create shops" ON public.shops;
DROP POLICY IF EXISTS "Owners can create shops" ON public.shops;
DROP POLICY IF EXISTS "Owners can view their shops" ON public.shops;
DROP POLICY IF EXISTS "Allow public to read shops for authentication" ON public.shops;
DROP POLICY IF EXISTS "Devices can view their shops" ON public.shops;

-- Recreate SHOPS minimal required policies
CREATE POLICY "Allow anyone to create shops" 
ON public.shops FOR INSERT 
WITH CHECK (true);

CREATE POLICY "Allow public to read shops for authentication"
ON public.shops FOR SELECT
USING (true);

-- 2. Reset SHOP_MEMBERS table policies
-- We drop ANY known policy names that might restrict inserts
DROP POLICY IF EXISTS "Allow anyone to insert shop members" ON public.shop_members;
DROP POLICY IF EXISTS "Allow public to read shop members for authentication" ON public.shop_members;
DROP POLICY IF EXISTS "Shop members can update their own data" ON public.shop_members;
DROP POLICY IF EXISTS "Shop owners can insert shop members" ON public.shop_members;

-- Recreate SHOP_MEMBERS minimal required policies
-- CRITICAL FIX: Allow the app to insert its own member row during registration
CREATE POLICY "Allow anyone to insert shop members"
ON public.shop_members FOR INSERT
WITH CHECK (true);

CREATE POLICY "Allow public to read shop members for authentication"
ON public.shop_members FOR SELECT
USING (true);

CREATE POLICY "Allow shop members to update their own data"
ON public.shop_members FOR UPDATE
USING (true);
