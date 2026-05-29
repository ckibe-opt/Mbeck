-- cloud_schema_hardening.sql
-- Hardens the Mbeck Seller cloud schema to match local SQLite definitions

-- 1. UTILITY FUNCTION FOR RLS
CREATE OR REPLACE FUNCTION public.is_shop_member(p_shop_id text)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.shop_members 
    WHERE shop_id = p_shop_id 
    AND (user_id = auth.uid())
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. CREATE MISSING TABLES

-- services_bookings
CREATE TABLE IF NOT EXISTS public.services_bookings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id text REFERENCES public.shops(id),
    local_id integer,
    service_id uuid,
    staff_id integer,
    customer_name text NOT NULL,
    customer_phone text,
    customer_email text,
    start_time bigint NOT NULL,
    end_time bigint NOT NULL,
    status text NOT NULL DEFAULT 'pending',
    notes text,
    deposit_paid numeric DEFAULT 0,
    total_price numeric,
    total_duration_minutes integer,
    addon_ids text,
    recurrence_rule text,
    source_module text DEFAULT 'services',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- restaurant_inventory
CREATE TABLE IF NOT EXISTS public.restaurant_inventory (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id text REFERENCES public.shops(id),
    local_id integer,
    name text NOT NULL,
    category text,
    unit_of_measure text NOT NULL DEFAULT 'pcs',
    stock_level numeric NOT NULL DEFAULT 0,
    cost_per_unit numeric NOT NULL DEFAULT 0,
    min_stock_level numeric NOT NULL DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- restaurant_recipes
CREATE TABLE IF NOT EXISTS public.restaurant_recipes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id text REFERENCES public.shops(id),
    menu_item_id uuid,
    restaurant_inventory_id uuid,
    quantity_required numeric NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- customers
CREATE TABLE IF NOT EXISTS public.customers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id text REFERENCES public.shops(id),
    local_id integer,
    name text NOT NULL,
    phone text,
    id_no text,
    bank_account text,
    notes text,
    agent text,
    store text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- transaction_items
CREATE TABLE IF NOT EXISTS public.transaction_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id text REFERENCES public.shops(id),
    transaction_id uuid REFERENCES public.transactions(id) ON DELETE CASCADE,
    item_id bigint, -- References public.inventory(id)
    item_name text,
    quantity integer NOT NULL DEFAULT 1,
    unit_price numeric NOT NULL,
    subtotal numeric NOT NULL,
    discount numeric DEFAULT 0,
    created_at timestamptz DEFAULT now()
);

-- shop_settings
CREATE TABLE IF NOT EXISTS public.shop_settings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id text REFERENCES public.shops(id) UNIQUE,
    shop_name text,
    branding jsonb DEFAULT '{}'::jsonb,
    updated_at timestamptz DEFAULT now()
);

-- accounting
CREATE TABLE IF NOT EXISTS public.accounting (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id text REFERENCES public.shops(id),
    timestamp bigint,
    cash_total numeric,
    mpesa1 numeric,
    mpesa2 numeric,
    coop numeric,
    equity numeric,
    kcb numeric,
    airtel numeric,
    other_mpesa numeric,
    sales_disparity numeric,
    special_scenarios text,
    created_at timestamptz DEFAULT now()
);

-- supplies
CREATE TABLE IF NOT EXISTS public.supplies (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id text REFERENCES public.shops(id),
    name text NOT NULL,
    category text,
    unit text DEFAULT 'pcs',
    quantity numeric NOT NULL DEFAULT 0,
    cost_per_unit numeric DEFAULT 0,
    min_stock_level numeric DEFAULT 0,
    module text NOT NULL DEFAULT 'restaurant',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- supply_links
CREATE TABLE IF NOT EXISTS public.supply_links (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id text REFERENCES public.shops(id),
    item_id uuid,
    item_type text NOT NULL,
    supply_id uuid REFERENCES public.supplies(id) ON DELETE CASCADE,
    quantity_per_use numeric NOT NULL DEFAULT 1,
    created_at timestamptz DEFAULT now()
);

-- entertainment_asset_types
CREATE TABLE IF NOT EXISTS public.entertainment_asset_types (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id text REFERENCES public.shops(id),
    name text NOT NULL,
    category text NOT NULL DEFAULT 'general',
    asset_type text NOT NULL DEFAULT 'hourly',
    rate_per_hour numeric NOT NULL DEFAULT 0,
    flat_rate numeric DEFAULT 0,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- lodging_room_types
CREATE TABLE IF NOT EXISTS public.lodging_room_types (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id text REFERENCES public.shops(id),
    name text NOT NULL,
    description text,
    capacity integer NOT NULL DEFAULT 2,
    rate_per_night numeric NOT NULL DEFAULT 0,
    rate_per_week numeric,
    rate_per_month numeric,
    amenities text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- customer_ledger
CREATE TABLE IF NOT EXISTS public.customer_ledger (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id text REFERENCES public.shops(id),
    customer_id uuid REFERENCES public.customers(id),
    customer_phone text,
    customer_name text,
    type text NOT NULL DEFAULT 'owing',
    amount numeric NOT NULL DEFAULT 0,
    notes text,
    txn_id uuid REFERENCES public.transactions(id),
    status text NOT NULL DEFAULT 'open',
    created_at timestamptz DEFAULT now(),
    resolved_at timestamptz
);

-- 3. ENABLE RLS & CREATE POLICIES
DO $$ 
DECLARE 
    t text;
BEGIN
    FOR t IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename IN (
            'services_bookings', 'restaurant_inventory', 'restaurant_recipes', 
            'customers', 'transaction_items', 'shop_settings', 'accounting', 
            'supplies', 'supply_links', 'entertainment_asset_types', 
            'lodging_room_types', 'customer_ledger'
        )
    LOOP
        EXECUTE 'ALTER TABLE public.' || t || ' ENABLE ROW LEVEL SECURITY';
        
        -- Policy: Allow members to view their shop's data
        EXECUTE 'DROP POLICY IF EXISTS "Members can view their shop data" ON public.' || t;
        EXECUTE 'CREATE POLICY "Members can view their shop data" ON public.' || t || 
                ' FOR SELECT USING (is_shop_member(shop_id))';
        
        -- Policy: Allow members to insert their shop's data
        EXECUTE 'DROP POLICY IF EXISTS "Members can insert their shop data" ON public.' || t;
        EXECUTE 'CREATE POLICY "Members can insert their shop data" ON public.' || t || 
                ' FOR INSERT WITH CHECK (is_shop_member(shop_id))';
        
        -- Policy: Allow members to update their shop's data
        EXECUTE 'DROP POLICY IF EXISTS "Members can update their shop data" ON public.' || t;
        EXECUTE 'CREATE POLICY "Members can update their shop data" ON public.' || t || 
                ' FOR UPDATE USING (is_shop_member(shop_id)) WITH CHECK (is_shop_member(shop_id))';
        
        -- Policy: Allow members to delete their shop's data
        EXECUTE 'DROP POLICY IF EXISTS "Members can delete their shop data" ON public.' || t;
        EXECUTE 'CREATE POLICY "Members can delete their shop data" ON public.' || t || 
                ' FOR DELETE USING (is_shop_member(shop_id))';
    END LOOP;
END $$;
