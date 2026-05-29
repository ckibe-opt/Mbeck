-- Migration v17: Add Supabase Auth Support
-- Adds user_id and phone_number to shop_members for Phone OTP authentication
-- Maintains backward compatibility with device_id

-- Add user_id column (references Supabase auth.users)
ALTER TABLE shop_members
ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Add phone_number column
ALTER TABLE shop_members
ADD COLUMN phone_number TEXT;

-- Create index for fast user lookups
CREATE INDEX IF NOT EXISTS idx_shop_members_user_id ON shop_members(user_id);
CREATE INDEX IF NOT EXISTS idx_shop_members_phone ON shop_members(phone_number);

-- Add constraint: Either device_id OR user_id must be present
-- (Allow gradual migration from device-based to user-based auth)
ALTER TABLE shop_members
ADD CONSTRAINT check_auth_method CHECK (
  (device_id IS NOT NULL) OR (user_id IS NOT NULL)
);

-- Comments for documentation
COMMENT ON COLUMN shop_members.user_id IS 'Supabase Auth user ID (UUID). Replaces device_id for user accounts.';
COMMENT ON COLUMN shop_members.phone_number IS 'User phone number for OTP authentication (E.164 format: +254712345678)';
