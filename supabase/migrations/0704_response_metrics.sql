-- Function to update response rate metrics
CREATE OR REPLACE FUNCTION update_response_rate_metrics()
RETURNS TRIGGER AS $$
BEGIN
    -- Update response rate metrics in customer preferences
    WITH response_stats AS (
        SELECT 
            COUNT(*) FILTER (WHERE effectiveness_metrics->>'response_received' = 'true') as responses,
            COUNT(*) as total_messages,
            COUNT(*) FILTER (WHERE effectiveness_metrics->>'response_received' = 'true' 
                           AND sent_at > NOW() - INTERVAL '30 days') as recent_responses,
            COUNT(*) FILTER (WHERE sent_at > NOW() - INTERVAL '30 days') as recent_total
        FROM communication_history
        WHERE customer_id = NEW.customer_id
    )
    UPDATE customer_preferences
    SET metadata = jsonb_set(
        metadata,
        '{response_metrics}',
        jsonb_build_object(
            'overall_response_rate', (responses::float / NULLIF(total_messages, 0))::numeric(4,2),
            'recent_response_rate', (recent_responses::float / NULLIF(recent_total, 0))::numeric(4,2),
            'total_messages', total_messages,
            'total_responses', responses,
            'updated_at', NOW()
        )
    )
    FROM response_stats
    WHERE customer_id = NEW.customer_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for response rate tracking
CREATE TRIGGER track_response_rates
    AFTER INSERT OR UPDATE OF effectiveness_metrics ON communication_history
    FOR EACH ROW
    EXECUTE FUNCTION update_response_rate_metrics();

-- Function to track time-based response patterns
CREATE OR REPLACE FUNCTION update_time_based_metrics()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process if we have a response
    IF NEW.effectiveness_metrics->>'response_received' = 'true' THEN
        WITH time_stats AS (
            SELECT 
                EXTRACT(HOUR FROM sent_at) as hour,
                COUNT(*) as messages,
                COUNT(*) FILTER (WHERE effectiveness_metrics->>'response_received' = 'true') as responses,
                AVG((effectiveness_metrics->>'response_time_minutes')::float) as avg_response_time
            FROM communication_history
            WHERE customer_id = NEW.customer_id
            AND sent_at > NOW() - INTERVAL '90 days'
            GROUP BY EXTRACT(HOUR FROM sent_at)
        )
        UPDATE customer_preferences
        SET metadata = jsonb_set(
            metadata,
            '{time_metrics}',
            (
                SELECT jsonb_object_agg(
                    hour::text,
                    jsonb_build_object(
                        'messages', messages,
                        'responses', responses,
                        'response_rate', (responses::float / messages)::numeric(4,2),
                        'avg_response_time', avg_response_time::numeric(4,2)
                    )
                )
                FROM time_stats
            )
        )
        WHERE customer_id = NEW.customer_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for time-based metrics
CREATE TRIGGER track_time_metrics
    AFTER INSERT OR UPDATE OF effectiveness_metrics ON communication_history
    FOR EACH ROW
    EXECUTE FUNCTION update_time_based_metrics();

-- Add index for response tracking
CREATE INDEX IF NOT EXISTS idx_communication_response_tracking
    ON communication_history((effectiveness_metrics->>'response_received'));

COMMENT ON FUNCTION update_response_rate_metrics IS 'Updates customer response rate metrics';
COMMENT ON FUNCTION update_time_based_metrics IS 'Tracks response patterns by time of day'; 