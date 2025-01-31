CREATE TABLE IF NOT EXISTS message_feedback (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  message_id uuid REFERENCES message_previews(id),
  user_id uuid REFERENCES auth.users(id),
  feedback_type TEXT NOT NULL,
  feedback_text TEXT,
  effectiveness_score FLOAT,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_message_feedback_message_id 
  ON message_feedback(message_id);

CREATE INDEX idx_message_feedback_created_at 
  ON message_feedback(created_at DESC);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.message_feedback TO service_role;
GRANT SELECT, INSERT ON public.message_feedback TO authenticated;
GRANT SELECT ON public.message_feedback TO anon;

-- Enable RLS
ALTER TABLE message_feedback ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own feedback"
  ON message_feedback FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own feedback"
  ON message_feedback FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role can manage all feedback"
  ON message_feedback FOR ALL
  USING (current_user = 'service_role'); 

--  remove old previews without feedback
CREATE OR REPLACE FUNCTION clean_old_previews_without_feedback() RETURNS void AS $$
BEGIN
  DELETE FROM message_previews 
  WHERE created_at < now() - interval '1 hour'
  AND id NOT IN (
    SELECT message_id 
    FROM message_feedback
  );
END;
$$ LANGUAGE plpgsql;

-- Check learning update configuration

-- Add learning update functions
CREATE OR REPLACE FUNCTION process_message_feedback() RETURNS void AS $$
BEGIN
  -- First collect feedback type counts separately
  WITH feedback_counts AS (
    SELECT 
      message_id,
      feedback_type,
      COUNT(*) as type_count
    FROM message_feedback
    WHERE created_at > NOW() - INTERVAL '5 minutes'
    GROUP BY message_id, feedback_type
  ),
  -- Then aggregate message metrics
  message_metrics AS (
    SELECT 
      mf.message_id,
      COUNT(DISTINCT mf.id) as feedback_count,
      AVG(mf.effectiveness_score) as avg_effectiveness,
      jsonb_object_agg(fc.feedback_type, fc.type_count) as feedback_types,
      array_agg(mf.feedback_text) FILTER (WHERE mf.feedback_text IS NOT NULL) as feedback_texts
    FROM message_feedback mf
    LEFT JOIN feedback_counts fc USING (message_id)
    WHERE mf.created_at > NOW() - INTERVAL '5 minutes'
    GROUP BY mf.message_id
  )
  UPDATE message_previews mp
  SET metadata = jsonb_set(
    COALESCE(metadata, '{}'::jsonb),
    '{learning_metrics}',
    jsonb_build_object(
      'feedback_count', mm.feedback_count,
      'avg_effectiveness', mm.avg_effectiveness,
      'feedback_types', COALESCE(mm.feedback_types, '{}'::jsonb),
      'feedback_texts', to_jsonb(mm.feedback_texts),
      'last_updated', NOW()
    )
  )
  FROM message_metrics mm
  WHERE mp.id = mm.message_id;

  -- Update customer preferences based on feedback
  WITH customer_feedback AS (
    SELECT 
      mp.customer_id,
      mp.style,
      AVG(mf.effectiveness_score) as style_effectiveness
    FROM message_feedback mf
    JOIN message_previews mp ON mp.id = mf.message_id
    WHERE mf.created_at > NOW() - INTERVAL '5 minutes'
    GROUP BY mp.customer_id, mp.style
  )
  UPDATE customer_preferences cp
  SET 
    preferred_style = cf.style,
    metadata = jsonb_set(
      COALESCE(cp.metadata, '{}'::jsonb),
      '{style_effectiveness}',
      to_jsonb(cf.style_effectiveness)
    )
  FROM customer_feedback cf
  WHERE cp.customer_id = cf.customer_id
  AND cf.style_effectiveness >= 4.0; -- Only update if highly effective
END;
$$ LANGUAGE plpgsql;