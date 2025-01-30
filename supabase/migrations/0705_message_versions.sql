-- Create enum for edit types
CREATE TYPE message_edit_type AS ENUM (
  'tone',        -- Adjust tone/formality
  'clarity',     -- Improve clarity/readability
  'length',      -- Adjust message length
  'style',       -- Change writing style
  'grammar',     -- Fix grammar/spelling
  'format',      -- Adjust formatting/structure
  'emphasis',    -- Change emphasis/focus
  'technical',   -- Adjust technical detail level
  'persuasive',  -- Enhance persuasiveness
  'localize'     -- Adapt for cultural/regional context
);

-- Create message_versions table
CREATE TABLE message_versions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  message_id UUID NOT NULL REFERENCES communication_history(id) ON DELETE CASCADE,
  version_number INTEGER NOT NULL,
  content TEXT NOT NULL,
  edit_type message_edit_type NOT NULL,
  edit_instructions TEXT,
  previous_version TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id),
  metadata JSONB DEFAULT '{}'::jsonb,
  
  -- Additional fields for tracking
  effectiveness_score FLOAT,
  selected_for_send BOOLEAN DEFAULT false,
  feedback TEXT,
  
  -- Constraints
  CONSTRAINT valid_version_number CHECK (version_number > 0),
  CONSTRAINT unique_message_version UNIQUE (message_id, version_number)
);

-- Add indexes
CREATE INDEX idx_message_versions_message_id ON message_versions(message_id);
CREATE INDEX idx_message_versions_created_at ON message_versions(created_at);
CREATE INDEX idx_message_versions_edit_type ON message_versions(edit_type);
CREATE INDEX idx_message_versions_metadata ON message_versions USING gin(metadata);

-- Add RLS policies
-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.message_versions TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.message_versions TO authenticated;

ALTER TABLE message_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view versions of messages they have access to"
  ON message_versions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM communication_history ch
      JOIN users u ON u.id = ch.customer_id
      WHERE ch.id = message_versions.message_id
      AND u.id = auth.uid()
    )
  );

CREATE POLICY "Users can create versions for messages they have access to"
  ON message_versions
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM communication_history ch
      JOIN users u ON u.id = ch.customer_id
      WHERE ch.id = message_versions.message_id
      AND u.id = auth.uid()
    )
  );

-- Function to track version effectiveness
CREATE OR REPLACE FUNCTION update_version_effectiveness()
RETURNS TRIGGER AS $$
BEGIN
  -- When a version is selected for sending, update effectiveness
  IF NEW.selected_for_send = true AND OLD.selected_for_send = false THEN
    -- Get effectiveness from communication history
    UPDATE message_versions
    SET effectiveness_score = (
      SELECT (effectiveness_metrics->>'customer_satisfaction')::float
      FROM communication_history
      WHERE id = NEW.message_id
    )
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for effectiveness tracking
CREATE TRIGGER track_version_effectiveness
  AFTER UPDATE ON message_versions
  FOR EACH ROW
  EXECUTE FUNCTION update_version_effectiveness();

-- Add comments
COMMENT ON TABLE message_versions IS 'Tracks versions and edits of customer communications';
COMMENT ON COLUMN message_versions.edit_type IS 'Type of edit performed on the message';
COMMENT ON COLUMN message_versions.metadata IS 'Additional context about the edit (style, model, etc)'; 