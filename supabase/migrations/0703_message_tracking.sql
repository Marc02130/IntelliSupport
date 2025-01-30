-- Track message effectiveness and metrics
CREATE OR REPLACE FUNCTION update_message_metrics()
RETURNS TRIGGER AS $$
BEGIN
    -- Update effectiveness metrics when a response is received
    IF NEW.response_received_at IS NOT NULL AND OLD.response_received_at IS NULL THEN
        NEW.effectiveness_metrics = jsonb_build_object(
            'response_time_minutes', 
            EXTRACT(EPOCH FROM (NEW.response_received_at - NEW.sent_at))/60,
            'response_received', true,
            'updated_at', NOW()
        ) || COALESCE(OLD.effectiveness_metrics, '{}'::jsonb);
    END IF;

    -- Update customer satisfaction if provided
    IF NEW.effectiveness_metrics ? 'customer_satisfaction' THEN
        -- Update customer preferences based on successful communications
        INSERT INTO customer_preferences (
            customer_id,
            preferred_style,
            communication_frequency,
            metadata
        )
        VALUES (
            NEW.customer_id,
            (SELECT preferred_style FROM customer_preferences WHERE customer_id = NEW.customer_id),
            (SELECT communication_frequency FROM customer_preferences WHERE customer_id = NEW.customer_id),
            jsonb_build_object(
                'last_satisfaction_score', NEW.effectiveness_metrics->>'customer_satisfaction',
                'last_successful_contact', NEW.sent_at
            )
        )
        ON CONFLICT (customer_id) 
        DO UPDATE SET
            metadata = customer_preferences.metadata || 
                      jsonb_build_object(
                          'last_satisfaction_score', NEW.effectiveness_metrics->>'customer_satisfaction',
                          'last_successful_contact', NEW.sent_at
                      );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for communication_history table
CREATE TRIGGER track_message_effectiveness
    BEFORE UPDATE ON communication_history
    FOR EACH ROW
    EXECUTE FUNCTION update_message_metrics();

-- Function to analyze communication patterns
CREATE OR REPLACE FUNCTION update_communication_patterns()
RETURNS TRIGGER AS $$
BEGIN
    -- Update customer preferences based on successful communication patterns
    WITH successful_communications AS (
        SELECT 
            EXTRACT(HOUR FROM sent_at) as hour,
            COUNT(*) as message_count,
            AVG((effectiveness_metrics->>'customer_satisfaction')::float) as avg_satisfaction
        FROM communication_history
        WHERE customer_id = NEW.customer_id
        AND (effectiveness_metrics->>'customer_satisfaction')::float >= 4.0
        AND sent_at > NOW() - INTERVAL '30 days'
        GROUP BY EXTRACT(HOUR FROM sent_at)
        HAVING COUNT(*) >= 3
        ORDER BY avg_satisfaction DESC, message_count DESC
        LIMIT 5
    )
    UPDATE customer_preferences
    SET preferred_times = jsonb_build_object(
        'successful_hours', (SELECT array_agg(hour) FROM successful_communications),
        'updated_at', NOW()
    )
    WHERE customer_id = NEW.customer_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to analyze patterns after each communication
CREATE TRIGGER analyze_communication_patterns
    AFTER INSERT OR UPDATE ON communication_history
    FOR EACH ROW
    EXECUTE FUNCTION update_communication_patterns();

-- Function to track message template effectiveness
CREATE OR REPLACE FUNCTION update_template_effectiveness()
RETURNS TRIGGER AS $$
BEGIN
    -- Update template effectiveness score based on customer satisfaction
    IF NEW.template_id IS NOT NULL AND NEW.effectiveness_metrics ? 'customer_satisfaction' THEN
        UPDATE message_templates
        SET 
            effectiveness_score = (
                effectiveness_score * 0.7 + 
                (NEW.effectiveness_metrics->>'customer_satisfaction')::float * 0.3
            ),
            updated_at = NOW()
        WHERE id = NEW.template_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for template effectiveness
CREATE TRIGGER track_template_effectiveness
    AFTER UPDATE ON communication_history
    FOR EACH ROW
    EXECUTE FUNCTION update_template_effectiveness();

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_communication_history_customer_sent 
    ON communication_history(customer_id, sent_at);
    
CREATE INDEX IF NOT EXISTS idx_communication_history_template 
    ON communication_history(template_id);

CREATE INDEX IF NOT EXISTS idx_communication_history_effectiveness 
    ON communication_history USING gin(effectiveness_metrics);

COMMENT ON FUNCTION update_message_metrics IS 'Tracks message effectiveness and updates customer preferences';
COMMENT ON FUNCTION update_communication_patterns IS 'Analyzes successful communication patterns to optimize timing';
COMMENT ON FUNCTION update_template_effectiveness IS 'Updates message template effectiveness scores based on customer satisfaction'; 