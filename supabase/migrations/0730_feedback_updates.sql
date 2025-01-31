-- Add updated_at column to message_feedback
ALTER TABLE message_feedback 
ADD COLUMN updated_at timestamptz;

-- Set default value for existing rows
UPDATE message_feedback 
SET updated_at = created_at 
WHERE updated_at IS NULL;

-- Make updated_at NOT NULL and set default
ALTER TABLE message_feedback 
ALTER COLUMN updated_at SET NOT NULL,
ALTER COLUMN updated_at SET DEFAULT now();

-- Add trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION update_message_feedback_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_message_feedback_timestamp
  BEFORE UPDATE ON message_feedback
  FOR EACH ROW
  EXECUTE FUNCTION update_message_feedback_timestamp(); 