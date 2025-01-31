CREATE OR REPLACE FUNCTION update_message_effectiveness(
  p_message_id UUID,
  p_feedback_type TEXT,
  p_effectiveness_score FLOAT
) RETURNS void AS $$
BEGIN
  -- Update message metrics immediately
  UPDATE message_previews
  SET metadata = jsonb_set(
    COALESCE(metadata, '{}'::jsonb),
    '{effectiveness}',
    (
      SELECT jsonb_build_object(
        'score', AVG(effectiveness_score),
        'feedback_count', COUNT(*),
        'helpful_count', SUM(CASE WHEN feedback_type = 'helpful' THEN 1 ELSE 0 END),
        'not_helpful_count', SUM(CASE WHEN feedback_type = 'not_helpful' THEN 1 ELSE 0 END),
        'last_updated', NOW()
      )
      FROM message_feedback
      WHERE message_id = p_message_id
    )
  )
  WHERE id = p_message_id;
END;
$$ LANGUAGE plpgsql;

-- Create trigger function that uses NEW row
CREATE OR REPLACE FUNCTION message_feedback_trigger_fn()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM update_message_effectiveness(
    NEW.message_id,
    NEW.feedback_type,
    NEW.effectiveness_score
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger for immediate updates
CREATE TRIGGER message_feedback_effectiveness_trigger
  AFTER INSERT OR UPDATE ON message_feedback
  FOR EACH ROW
  EXECUTE FUNCTION message_feedback_trigger_fn(); 