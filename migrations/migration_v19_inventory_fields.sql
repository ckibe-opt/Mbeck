-- Migration v19: Add specification and barcode columns to inventory table
-- Version: 19
-- Description: Adds specification and barcode fields for inventory items

ALTER TABLE inventory ADD COLUMN specification TEXT;
ALTER TABLE inventory ADD COLUMN barcode TEXT;
