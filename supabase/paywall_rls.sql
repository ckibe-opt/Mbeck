-- ============================================================
-- Paywall RLS: messages + shop_analytics_events
-- Run in Supabase SQL Editor
-- ============================================================

-- ── 1. Create messages table in Supabase (cloud messaging) ──
CREATE TABLE IF NOT EXISTS messages (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id     TEXT        NOT NULL,
  sender      TEXT        NOT NULL,  -- 'buyer' | 'seller'
  content     TEXT        NOT NULL,
  read        BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Sellers (PRO/ENTERPRISE) can read their own shop messages
CREATE POLICY "pro_shops_read_messages"
ON messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM shops
    WHERE shops.id = messages.shop_id
      AND shops.subscription_tier IN ('PRO', 'ENTERPRISE')
  )
);

-- Anyone can insert a message (buyer sending to a shop)
CREATE POLICY "anyone_insert_messages"
ON messages FOR INSERT
WITH CHECK (true);

-- Only shop members can update (mark as read)
CREATE POLICY "shop_members_update_messages"
ON messages FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM shops
    WHERE shops.id = messages.shop_id
      AND shops.subscription_tier IN ('PRO', 'ENTERPRISE')
  )
);

-- ── 2. Add SELECT restriction to shop_analytics_events ──
-- (INSERT policy already exists: buyer_insert_events)
-- Only PRO/ENTERPRISE shops can read their own analytics
CREATE POLICY "pro_shops_read_analytics"
ON shop_analytics_events FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM shops
    WHERE shops.id = shop_analytics_events.shop_id
      AND shops.subscription_tier IN ('PRO', 'ENTERPRISE')
  )
);
