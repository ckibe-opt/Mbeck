-- Migration v29: Create Global Product Vectors for Community Sharing
-- Enables the "Global Knowledge Graph" feature.

-- 1. Enable pgvector extension if not exists
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Create the global_product_vectors table
CREATE TABLE IF NOT EXISTS global_product_vectors (
  id BIGSERIAL PRIMARY KEY,
  barcode TEXT, -- UPC/EAN if available
  product_name TEXT NOT NULL,
  category TEXT,
  
  -- The core component: 1280-dimensional embedding (EfficientNet)
  -- We use the native 'vector' type for similarity search.
  vector_embedding vector(1280), 
  
  -- Quality control metrics
  contributor_count INTEGER DEFAULT 1, -- How many shops have voted for this vector
  confidence_score FLOAT DEFAULT 0.5, -- 0.0 to 1.0 (internal trust score)
  
  -- Metadata for brand, packaging, etc.
  metadata JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create Indexes
-- HNSW index for fast approximate nearest neighbor search (Cosine Distance)
CREATE INDEX IF NOT EXISTS idx_global_vectors_embedding 
ON global_product_vectors USING hnsw (vector_embedding vector_cosine_ops);

-- Standard index for barcode lookups
CREATE INDEX IF NOT EXISTS idx_global_vectors_barcode ON global_product_vectors(barcode);

-- 4. RLS Policies
ALTER TABLE global_product_vectors ENABLE ROW LEVEL SECURITY;

-- Allow public read (so any user can find a match)
CREATE POLICY "Public read access global vectors"
ON global_product_vectors FOR SELECT
USING (true);

-- Allow authenticated users to insert (contribution)
-- In practice, we might use an RPC to handle aggregation, but this enables direct inserts if needed.
CREATE POLICY "Auth insert global vectors"
ON global_product_vectors FOR INSERT
TO authenticated
WITH CHECK (true);

-- 5. RPC Function for similarity search
-- This simplifies the client-side call
CREATE OR REPLACE FUNCTION match_global_vectors(
  query_embedding vector(1280),
  match_threshold float,
  match_count int
)
RETURNS TABLE (
  id bigint,
  product_name text,
  barcode text,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    v.id,
    v.product_name,
    v.barcode,
    1 - (v.vector_embedding <=> query_embedding) as similarity
  FROM global_product_vectors v
  WHERE 1 - (v.vector_embedding <=> query_embedding) > match_threshold
  ORDER BY v.vector_embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
