-- Add variationsJson column for product variations (sizes, volumes)
-- Example: [{"id":1,"name":"500ml","priceModifier":0,"stock":10},{"id":2,"name":"1L","priceModifier":50,"stock":5}]

ALTER TABLE inventory ADD COLUMN variationsJson TEXT;
