-- ==============================================================================
-- MBECK GO REST API CATALOG SYNC TRIGGER
-- ==============================================================================
-- This script natively bridges your Mbeck Business offline background sync engine 
-- to your Mbeck Go live REST database by autonomously extracting INVENTORY_UPDATE 
-- payloads and materializing them into cleanly readable columns in `inventory`.
-- 
-- 1. Copy this entire script
-- 2. Go to your Supabase Dashboard
-- 3. Open the "SQL Editor"
-- 4. Paste and hit "Run"
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.process_background_sync_events()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  p JSONB;
  v_id          BIGINT;
  v_name        TEXT;
  v_selling     NUMERIC;
  v_original    NUMERIC;
  v_stock       INTEGER;
  v_image       TEXT;
  v_category    TEXT;
  v_barcode     TEXT;
  v_published   BOOLEAN;
BEGIN
  -- Only process inventory-shaped events.
  IF NEW.event_type NOT IN ('INVENTORY_CREATE', 'INVENTORY_UPDATE') THEN
    RETURN NEW;
  END IF;

  p := NEW.payload;
  IF p IS NULL THEN
    RETURN NEW;
  END IF;

  -- The seller emits two payload shapes:
  --   INVENTORY_CREATE -> { id, name, sellingPrice, originalPrice, stock, ... }
  --   INVENTORY_UPDATE -> { id, newName, newSellingPrice, newOriginalPrice, newStock, ... }
  -- We must accept both. COALESCE resolves whichever variant is present.
  v_id        := NULLIF(p->>'id','')::bigint;
  v_name      := COALESCE(p->>'newName',          p->>'name');
  v_selling   := COALESCE(NULLIF(p->>'newSellingPrice','')::numeric,
                          NULLIF(p->>'sellingPrice','')::numeric, 0);
  v_original  := COALESCE(NULLIF(p->>'newOriginalPrice','')::numeric,
                          NULLIF(p->>'originalPrice','')::numeric, 0);
  v_stock     := COALESCE(NULLIF(p->>'newStock','')::integer,
                          NULLIF(p->>'stock','')::integer, 0);
  v_image     := p->>'imagePath';
  v_category  := p->>'category';
  v_barcode   := p->>'barcode';

  -- is_published may arrive as 0/1 (SQLite int) or true/false (jsonb bool).
  v_published := COALESCE(
    CASE jsonb_typeof(p->'is_published')
      WHEN 'boolean' THEN (p->'is_published')::boolean
      WHEN 'number'  THEN ((p->>'is_published')::int = 1)
      WHEN 'string'  THEN (lower(p->>'is_published') IN ('1','true','t'))
      ELSE NULL
    END,
    false
  );

  -- Skip rows we cannot key (id null) or that are missing the required name on CREATE.
  IF v_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF NEW.event_type = 'INVENTORY_CREATE' AND (v_name IS NULL OR v_name = '') THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.inventory (
    id, shop_id, name,
    "sellingPrice", "originalPrice", stock,
    "imagePath", category, barcode,
    is_published, created_at
  ) VALUES (
    v_id, NEW.shop_id, COALESCE(v_name, ''),
    v_selling, v_original, v_stock,
    v_image, v_category, v_barcode,
    v_published, NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    -- Don't blank existing fields if this UPDATE event omitted them.
    name           = COALESCE(EXCLUDED.name,           public.inventory.name),
    "sellingPrice" = COALESCE(EXCLUDED."sellingPrice", public.inventory."sellingPrice"),
    "originalPrice"= COALESCE(EXCLUDED."originalPrice",public.inventory."originalPrice"),
    stock          = COALESCE(EXCLUDED.stock,          public.inventory.stock),
    "imagePath"    = COALESCE(EXCLUDED."imagePath",    public.inventory."imagePath"),
    category       = COALESCE(EXCLUDED.category,       public.inventory.category),
    barcode        = COALESCE(EXCLUDED.barcode,        public.inventory.barcode),
    is_published   = EXCLUDED.is_published;

  RETURN NEW;
END;
$$;

-- Bind the automation trigger to dynamically run on every background upload
DROP TRIGGER IF EXISTS trg_materialize_sync_events ON public.events;
CREATE TRIGGER trg_materialize_sync_events
AFTER INSERT ON public.events
FOR EACH ROW
EXECUTE FUNCTION public.process_background_sync_events();
