-- Add metadata column to message_previews
ALTER TABLE message_previews
  ADD COLUMN IF NOT EXISTS metadata JSONB;

-- Add index for metadata queries
CREATE INDEX IF NOT EXISTS idx_message_previews_metadata 
  ON message_previews USING GIN (metadata);

-- Regrant column permissions
GRANT ALL (metadata) ON message_previews TO service_role;
GRANT SELECT, INSERT, UPDATE (metadata) ON message_previews TO authenticated;
GRANT SELECT (metadata) ON message_previews TO anon; 