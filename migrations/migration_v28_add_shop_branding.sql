-- Migration: v28_add_shop_branding
-- Description: Adds a JSONB column for custom shop branding/theming

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'shops' AND column_name = 'branding'
  ) THEN
    ALTER TABLE shops ADD COLUMN branding JSONB DEFAULT '{}'::jsonb;
  END IF;
END $$;
