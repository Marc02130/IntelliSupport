-- Create delivery status enum
CREATE TYPE delivery_status AS ENUM (
  'pending',
  'scheduled',
  'processing',
  'sent',
  'delivered',
  'failed',
  'bounced',
  'cancelled'
);

-- Update message_deliveries to use enum
-- First, remove the default
ALTER TABLE message_deliveries 
ALTER COLUMN status DROP DEFAULT;

-- Then convert the type
ALTER TABLE message_deliveries 
ALTER COLUMN status TYPE delivery_status 
USING status::delivery_status;

-- Finally, add the default back with the correct type
ALTER TABLE message_deliveries 
ALTER COLUMN status SET DEFAULT 'pending'::delivery_status; 