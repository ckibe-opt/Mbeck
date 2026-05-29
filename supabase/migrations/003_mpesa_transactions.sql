-- Migration: 003_mpesa_transactions.sql
-- Purpose: Store M-Pesa transaction logs
-- Fixed: Changed shop_id from UUID to TEXT to match shops table schema

DROP TABLE IF EXISTS public.mpesa_transactions;

CREATE TABLE public.mpesa_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id TEXT REFERENCES public.shops(id) ON DELETE SET NULL,
    account_reference TEXT,
    merchant_request_id TEXT,
    checkout_request_id TEXT UNIQUE,
    result_code INTEGER,
    result_desc TEXT,
    amount DECIMAL(12, 2),
    mpesa_receipt_number TEXT,
    transaction_date BIGINT, -- Stored as YYYYMMDDHHmmss
    phone_number TEXT,
    status TEXT CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
    raw_response JSONB, -- Store full callback
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_mpesa_checkout ON public.mpesa_transactions(checkout_request_id);
CREATE INDEX IF NOT EXISTS idx_mpesa_receipt ON public.mpesa_transactions(mpesa_receipt_number);
CREATE INDEX IF NOT EXISTS idx_mpesa_shop ON public.mpesa_transactions(shop_id);

-- RLS Policies
ALTER TABLE public.mpesa_transactions ENABLE ROW LEVEL SECURITY;

-- Shop Owners can view their own transactions
CREATE POLICY "Shop owners can view their transactions"
ON public.mpesa_transactions
FOR SELECT
USING (auth.uid() IN (
    SELECT owner_id FROM public.shops WHERE id = mpesa_transactions.shop_id
));

-- Authenticated users (Edge Functions) can insert
CREATE POLICY "System can insert mpesa logs"
ON public.mpesa_transactions
FOR INSERT
WITH CHECK (true);

-- Also allow updates (for linking checkout_id)
CREATE POLICY "System can update mpesa logs"
ON public.mpesa_transactions
FOR UPDATE
USING (true)
WITH CHECK (true);

-- Grant access
GRANT ALL ON public.mpesa_transactions TO service_role;
GRANT ALL ON public.mpesa_transactions TO authenticated;
