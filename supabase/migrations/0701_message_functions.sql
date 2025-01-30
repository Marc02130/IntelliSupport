-- Message effectiveness tracking trigger
CREATE OR REPLACE FUNCTION track_message_effectiveness()
RETURNS TRIGGER AS $$
BEGIN
    -- Update effectiveness metrics when response is received
    IF NEW.response_received_at IS NOT NULL AND OLD.response_received_at IS NULL THEN
        -- Update message template effectiveness
        UPDATE message_templates
        SET 
            effectiveness_score = (
                SELECT AVG((effectiveness_metrics->>'customer_satisfaction')::float)
                FROM communication_history
                WHERE template_id = NEW.template_id
                AND effectiveness_metrics->>'customer_satisfaction' IS NOT NULL
            ),
            usage_count = usage_count + 1,
            last_used_at = NOW()
        WHERE id = NEW.template_id;

        -- Update customer preferences based on successful patterns
        UPDATE customer_preferences
        SET metadata = jsonb_set(
            COALESCE(metadata, '{}'::jsonb),
            '{successful_patterns}',
            (
                SELECT jsonb_agg(pattern)
                FROM (
                    SELECT jsonb_build_object(
                        'time_of_day', EXTRACT(HOUR FROM sent_at),
                        'day_of_week', EXTRACT(DOW FROM sent_at),
                        'style_used', template_style,
                        'avg_satisfaction', AVG((effectiveness_metrics->>'customer_satisfaction')::float)
                    ) as pattern
                    FROM communication_history
                    WHERE customer_id = NEW.customer_id
                    AND (effectiveness_metrics->>'customer_satisfaction')::float >= 4.0
                    GROUP BY 
                        EXTRACT(HOUR FROM sent_at),
                        EXTRACT(DOW FROM sent_at),
                        template_style
                ) patterns
            )
        )
        WHERE customer_id = NEW.customer_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for message effectiveness tracking
DROP TRIGGER IF EXISTS message_effectiveness_trigger ON communication_history;
CREATE TRIGGER message_effectiveness_trigger
    AFTER UPDATE ON communication_history
    FOR EACH ROW
    EXECUTE FUNCTION track_message_effectiveness();

-- Rename view to be more specific about its real-time nature
CREATE OR REPLACE VIEW realtime_message_metrics AS
WITH hourly_stats AS (
    SELECT 
        template_id,
        EXTRACT(HOUR FROM sent_at)::text as hour,
        COUNT(*) as count
    FROM communication_history
    GROUP BY template_id, EXTRACT(HOUR FROM sent_at)
)
SELECT 
    ch.template_id,
    COUNT(*) as total_uses,
    AVG((effectiveness_metrics->>'customer_satisfaction')::float) as avg_satisfaction,
    AVG(EXTRACT(EPOCH FROM (response_received_at - sent_at))/3600) as avg_response_time_hours,
    COUNT(CASE WHEN response_received_at IS NOT NULL THEN 1 END)::float / COUNT(*) as response_rate,
    (
        SELECT jsonb_object_agg(hour, count)
        FROM hourly_stats hs
        WHERE hs.template_id = ch.template_id
    ) as hourly_distribution
FROM communication_history ch
GROUP BY ch.template_id;

COMMENT ON VIEW realtime_message_metrics IS 
'Real-time metrics for message templates, used for immediate feedback and monitoring. 
Unlike template_stats_mv which provides historical analysis, this view gives current metrics 
without time window restrictions.';

-- Keep existing template_stats_mv in 02_views.sql for historical analysis
COMMENT ON MATERIALIZED VIEW template_stats_mv IS 
'Historical analysis of template performance over 90-day periods, refreshed periodically. 
Used for trend analysis and recommendations, while realtime_message_metrics handles current monitoring.';

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_communication_history_effectiveness 
ON communication_history ((effectiveness_metrics->>'customer_satisfaction'));

CREATE INDEX IF NOT EXISTS idx_communication_history_template_response 
ON communication_history (template_id) 
WHERE response_received_at IS NOT NULL; 