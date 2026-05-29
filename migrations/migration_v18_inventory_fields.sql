-- Migration v18: Add specification and barcode columns to inventory table
-- Version: 18
-- Description: Adds specification and barcode fields for inventory items

ALTER TABLE inventory ADD COLUMN specification TEXT;
ALTER TABLE inventory ADD COLUMN barcode TEXT;
