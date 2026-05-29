-- Migration for AI Vector Cloud Sync
-- Enables buyer app to query shop product vectors for matching

-- Product Vectors Table (stores AI embeddings for cross-app matching)
CREATE TABLE IF NOT EXISTS product_vectors (
  id BIGSERIAL PRIMARY KEY,
  shop_id TEXT NOT NULL,
  item_id INTEGER NOT NULL,
  item_name TEXT NOT NULL,
  category TEXT,
  price NUMERIC(10, 2),
  vector_data JSONB NOT NULL, -- 1280-dimensional embedding
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Composite unique constraint
  UNIQUE(shop_id, item_id)
);

-- Indexes for fast querying
CREATE INDEX IF NOT EXISTS idx_product_vectors_shop_id ON product_vectors(shop_id);
CREATE INDEX IF NOT EXISTS idx_product_vectors_created_at ON product_vectors(created_at DESC);

-- Enable Row Level Security
ALTER TABLE product_vectors ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read vectors (for buyer app)
CREATE POLICY "Public read access for product vectors"
ON product_vectors FOR SELECT
USING (true);

-- Policy: Authenticated users can only insert/update their own shop's vectors
CREATE POLICY "Shop owners can manage their vectors"
ON product_vectors FOR ALL
USING (auth.uid()::text = shop_id OR auth.jwt() ->> 'shop_id' = shop_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_product_vectors_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at
CREATE TRIGGER set_product_vectors_updated_at
BEFORE UPDATE ON product_vectors
FOR EACH ROW
EXECUTE FUNCTION update_product_vectors_updated_at();

-- Comments
COMMENT ON TABLE product_vectors IS 'Stores AI vector embeddings for product matching in buyer app';
COMMENT ON COLUMN product_vectors.vector_data IS '1280-dimensional EfficientNet embedding (JSONB for fast querying)';
COMMENT ON COLUMN product_vectors.shop_id IS 'References shop from shop_members table';
