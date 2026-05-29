-- Create table for storing offline orders from Buyer App
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY,
  shop_id TEXT NOT NULL,
  items_json TEXT NOT NULL,
  total_amount NUMERIC NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT DEFAULT 'pending', -- pending, processed, cancelled
  buyer_info TEXT -- Optional JSON for buyer details
);

-- Index for faster shop lookups (Seller Pull)
CREATE INDEX IF NOT EXISTS idx_orders_shop_id ON orders(shop_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

-- Enable RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Policy: Buyers can insert their own orders (if auth enabled)
-- For now, allow public insert (demo mode) or authenticated
CREATE POLICY "Enable insert for authenticated users only" ON orders FOR INSERT TO authenticated WITH CHECK (true);

-- Policy: Shops can view their own orders
-- Assuming auth.uid() == shop_owner_id or similar logic, 
-- but for now we'll allow access if shop_id matches metadata or just open for V1
CREATE POLICY "Enable read for shops" ON orders FOR SELECT USING (true);
