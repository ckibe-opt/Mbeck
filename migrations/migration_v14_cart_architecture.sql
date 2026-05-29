-- Migration v14: Native Multi-Item (Cart) Architecture
-- This migration refactors the transaction system to support multiple items per transaction
-- Date: 2026-01-29

-- Step 1: Create the new transaction_items table
CREATE TABLE IF NOT EXISTS transaction_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transactionId INTEGER NOT NULL,
  itemId INTEGER NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unitPrice INTEGER NOT NULL,
  subtotal INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  FOREIGN KEY (transactionId) REFERENCES txn(id) ON DELETE CASCADE,
  FOREIGN KEY (itemId) REFERENCES inventory(id) ON DELETE CASCADE
);

-- Step 2: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_transaction_items_txn_id ON transaction_items(transactionId);
CREATE INDEX IF NOT EXISTS idx_transaction_items_item_id ON transaction_items(itemId);

-- Step 3: Migrate existing legacy transactions
-- For transactions that have itemId set, create a corresponding transaction_item entry
INSERT INTO transaction_items (transactionId, itemId, quantity, unitPrice, subtotal, discount)
SELECT 
  id as transactionId,
  itemId,
  1 as quantity, -- Default quantity for legacy transactions
  totalAmount as unitPrice, -- For legacy, assume unitPrice = totalAmount
  totalAmount as subtotal,
  0 as discount
FROM txn
WHERE itemId IS NOT NULL 
  AND itemId != 0
  AND NOT EXISTS (
    SELECT 1 FROM transaction_items ti WHERE ti.transactionId = txn.id
  );

-- Step 4: Note: We keep the itemId column in txn table for backward compatibility
-- but new transactions should NOT use it. The column will be deprecated in a future migration.
-- For now, we leave it to avoid breaking existing queries during transition.

-- Migration complete
-- After this migration:
-- - New transactions should use transaction_items table
-- - Old transactions are migrated to transaction_items
-- - The system supports both old (single-item) and new (multi-item) transaction structures
