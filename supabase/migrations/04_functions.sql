-- Cron jobs
-- Schedule jobs without extra whitespace
SELECT cron.schedule(
  'process-embedding-queue',
  '*/5 * * * *',
  'SELECT process_embedding_queue_job();'
);

SELECT cron.schedule(
  'route-tickets',
  '*/5 * * * *',
  'SELECT route_tickets_job();'
);



-- Functions
-- Function to get list of tables
CREATE OR REPLACE FUNCTION get_tables()
RETURNS TABLE (name text, schema text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT table_name::text, table_schema::text
  FROM information_schema.tables
  WHERE table_schema = 'public'
  ORDER BY table_name;
END;
$$;


-- Function to get table columns
CREATE OR REPLACE FUNCTION get_table_columns(table_name text)
RETURNS TABLE (
  name text,
  data_type text,
  is_nullable boolean,
  column_default text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    column_name::text,
    data_type::text,
    is_nullable::boolean,
    column_default::text
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = $1
  ORDER BY ordinal_position;
END;
$$; 


-- Function to execute SQL expressions for search queries
CREATE OR REPLACE FUNCTION execute_sql(sql_query text)
RETURNS TABLE (result uuid) 
SECURITY DEFINER
AS $$
BEGIN
  RAISE NOTICE 'Executing query: %', sql_query;
  RETURN QUERY EXECUTE sql_query;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::uuid;
  END IF;
EXCEPTION 
  WHEN OTHERS THEN
    RAISE NOTICE 'Error executing query: %', SQLERRM;
    RETURN QUERY SELECT NULL::uuid;
END;
$$ LANGUAGE plpgsql;


-- Add get_user_navigation function
CREATE OR REPLACE FUNCTION public.get_user_navigation()
RETURNS TABLE (
    id UUID,
    name TEXT,
    description TEXT,
    icon TEXT,
    parent_id UUID,
    search_query_id UUID,
    url TEXT,
    sort_order INTEGER,
    permissions_required TEXT[],
    is_active BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_organization TEXT;
BEGIN
    -- Get user's organization name
    SELECT o.name INTO user_organization
    FROM users u
    JOIN organizations o ON o.id = u.organization_id
    WHERE u.id = auth.uid();

    RETURN QUERY
    SELECT DISTINCT
        n.id::UUID,
        n.name::TEXT,
        n.description::TEXT,
        n.icon::TEXT,
        n.parent_id::UUID,
        n.search_query_id::UUID,
        n.url::TEXT,
        n.sort_order::INTEGER,
        n.permissions_required::TEXT[],
        n.is_active::BOOLEAN
    FROM sidebar_navigation n
    WHERE n.is_active = true
    AND (
        -- For "New User" organization, only show dashboard
        (user_organization = 'New User' AND n.url = '/') -- Only show dashboard
        OR
        -- For other organizations, show based on permissions
        (user_organization != 'New User' AND EXISTS (
            SELECT 1 
            FROM auth.users u
            JOIN roles r ON r.name = (u.raw_user_meta_data->>'role')::text
            JOIN role_permissions rp ON rp.role_id = r.id
            JOIN permissions p ON p.id = rp.permission_id
            WHERE u.id = auth.uid()
            AND (
                p.name = ANY(n.permissions_required)
                OR n.permissions_required IS NULL 
                OR array_length(n.permissions_required, 1) IS NULL
            )
        ))
    )
    ORDER BY n.sort_order;
END;
$$;


-- Function to get communication recommendations
CREATE OR REPLACE FUNCTION get_communication_recommendations(customer_id_input UUID)
RETURNS TABLE (
    recommended_times JSONB,
    recommended_style TEXT,
    recommended_frequency TEXT,
    suggested_templates UUID[],
    effectiveness_metrics JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH customer_history AS (
        -- Get recent successful communications
        SELECT 
            ch.sent_at,
            ch.template_id,
            ch.effectiveness_metrics,
            ch.message_text
        FROM communication_history ch
        WHERE ch.customer_id = customer_id_input
        AND (ch.effectiveness_metrics->>'customer_satisfaction')::float > 4.0
        AND ch.sent_at > NOW() - INTERVAL '90 days'
    ),
    time_analysis AS (
        -- Analyze successful communication times
        SELECT 
            jsonb_build_object(
                'hour_preferences', jsonb_agg(DISTINCT EXTRACT(HOUR FROM sent_at)),
                'day_preferences', jsonb_agg(DISTINCT EXTRACT(DOW FROM sent_at)),
                'timezone', cp.preferred_times->>'timezone'
            ) as time_patterns
        FROM customer_history ch
        CROSS JOIN customer_preferences cp
        WHERE cp.customer_id = customer_id_input
        GROUP BY cp.preferred_times->>'timezone'
    ),
    template_success AS (
        -- Find most successful message templates
        SELECT 
            template_id,
            AVG((effectiveness_metrics->>'customer_satisfaction')::float) as avg_satisfaction,
            COUNT(*) as usage_count
        FROM customer_history
        WHERE template_id IS NOT NULL
        GROUP BY template_id
        HAVING COUNT(*) > 1
        ORDER BY avg_satisfaction DESC, usage_count DESC
        LIMIT 5
    )
    SELECT 
        (SELECT time_patterns FROM time_analysis),
        cp.preferred_style,
        cp.communication_frequency,
        ARRAY(SELECT template_id FROM template_success),
        jsonb_build_object(
            'avg_satisfaction', (
                SELECT AVG((effectiveness_metrics->>'customer_satisfaction')::float)
                FROM customer_history
            ),
            'response_rate', (
                SELECT COUNT(*) FILTER (WHERE effectiveness_metrics->>'response_received' = 'true')::float / 
                       NULLIF(COUNT(*), 0)
                FROM customer_history
            ),
            'best_performing_templates', (
                SELECT jsonb_agg(jsonb_build_object(
                    'template_id', template_id,
                    'avg_satisfaction', avg_satisfaction,
                    'usage_count', usage_count
                ))
                FROM template_success
            )
        )
    FROM customer_preferences cp
    WHERE cp.customer_id = customer_id_input;
END;
$$ LANGUAGE plpgsql;


-- Function to test GPT-4 message generation
CREATE OR REPLACE FUNCTION test_message_generation(
    customer_id_input UUID,
    context_type TEXT,  -- e.g., 'initial_response', 'follow_up', 'solution_proposal'
    additional_context JSONB DEFAULT '{}'
) RETURNS TABLE (
    generated_message TEXT,
    used_template_id UUID,
    customer_context JSONB,
    generation_metadata JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH customer_context AS (
        -- Get customer preferences and history
        SELECT 
            cp.preferred_style,
            cp.preferred_times,
            cp.communication_frequency,
            cp.metadata->'recommendations' as recommendations,
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'message', ch.message_text,
                        'sent_at', ch.sent_at,
                        'effectiveness', ch.effectiveness_metrics
                    ) ORDER BY ch.sent_at DESC
                )
                FROM communication_history ch
                WHERE ch.customer_id = customer_id_input
                LIMIT 5
            ) as recent_communications,
            u.full_name,
            u.organization_id
        FROM customer_preferences cp
        JOIN users u ON u.id = cp.customer_id
        WHERE cp.customer_id = customer_id_input
    ),
    best_template AS (
        -- Find best performing template for this context
        SELECT 
            mt.id as template_id,
            mt.template_text,
            AVG((ch.effectiveness_metrics->>'customer_satisfaction')::float) as avg_satisfaction
        FROM message_templates mt
        LEFT JOIN communication_history ch ON ch.template_id = mt.id
        WHERE mt.context_type = context_type
        GROUP BY mt.id, mt.template_text
        ORDER BY avg_satisfaction DESC NULLS LAST
        LIMIT 1
    )
    SELECT 
        -- This would be replaced with actual GPT-4 call in production
        CASE 
            WHEN bt.template_text IS NOT NULL THEN
                replace(
                    replace(bt.template_text, '{customer_name}', cc.full_name),
                    '{style}', cc.preferred_style
                )
            ELSE
                'Default message for ' || cc.full_name || 
                ' using ' || cc.preferred_style || ' style'
        END as generated_message,
        bt.template_id,
        jsonb_build_object(
            'customer_name', cc.full_name,
            'preferred_style', cc.preferred_style,
            'preferred_times', cc.preferred_times,
            'communication_frequency', cc.communication_frequency,
            'recommendations', cc.recommendations,
            'recent_communications', cc.recent_communications,
            'organization_id', cc.organization_id,
            'additional_context', additional_context
        ) as customer_context,
        jsonb_build_object(
            'context_type', context_type,
            'template_satisfaction', bt.avg_satisfaction,
            'generation_time', CURRENT_TIMESTAMP,
            'test_mode', true
        ) as generation_metadata
    FROM customer_context cc
    LEFT JOIN best_template bt ON true;
END;
$$ LANGUAGE plpgsql;


-- Function to analyze and generate communication recommendations
-- To test
-- SELECT * FROM analyze_communication_patterns('a3981e8c-9840-4536-a395-5a7bee9c9dfd', 90);
CREATE OR REPLACE FUNCTION analyze_communication_patterns(
    customer_id_input UUID,
    lookback_days INTEGER DEFAULT 90
) RETURNS TABLE (
    recommended_times JSONB,
    recommended_styles JSONB,
    recommended_frequency TEXT,
    effectiveness_metrics JSONB,
    confidence_score FLOAT
) AS $$
DECLARE
    total_communications INTEGER;
    successful_communications INTEGER;
    freq TEXT;
BEGIN
    -- Get communication counts with higher satisfaction threshold
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE (ch.effectiveness_metrics->>'customer_satisfaction')::float >= 4.2)
    INTO 
        total_communications,
        successful_communications
    FROM communication_history ch
    WHERE ch.customer_id = customer_id_input
    AND ch.sent_at > NOW() - (lookback_days || ' days')::INTERVAL;

    -- Get frequency recommendation with improved gap analysis
    WITH gap_analysis AS (
        SELECT 
            sent_at,
            EXTRACT(EPOCH FROM (sent_at - LAG(sent_at) OVER (ORDER BY sent_at)))/3600 as gap_hours,
            (ch.effectiveness_metrics->>'customer_satisfaction')::float as satisfaction
        FROM communication_history ch
        WHERE ch.customer_id = customer_id_input
        AND ch.effectiveness_metrics->>'customer_satisfaction' IS NOT NULL
        ORDER BY sent_at DESC
    )
    SELECT 
        CASE 
            WHEN AVG(gap_hours) < 24 AND MAX(satisfaction) >= 4.5 THEN 'daily'
            WHEN AVG(gap_hours) < 168 OR MAX(satisfaction) >= 4.7 THEN 'weekly'
            ELSE 'monthly'
        END
    INTO freq
    FROM gap_analysis
    WHERE gap_hours IS NOT NULL;

    RETURN QUERY
    WITH time_analysis AS (
        -- Analyze successful communication times with satisfaction weighting
        SELECT 
            jsonb_build_object(
                'hour_preferences', (
                    SELECT jsonb_agg(hour_data)
                    FROM (
                        SELECT 
                            EXTRACT(HOUR FROM ch.sent_at) as hour,
                            COUNT(*) as frequency,
                            AVG((ch.effectiveness_metrics->>'customer_satisfaction')::float) as avg_satisfaction
                        FROM communication_history ch
                        WHERE ch.customer_id = customer_id_input
                        AND ch.sent_at > NOW() - (lookback_days || ' days')::INTERVAL
                        AND (ch.effectiveness_metrics->>'customer_satisfaction')::float >= 4.2
                        GROUP BY EXTRACT(HOUR FROM ch.sent_at)
                        ORDER BY avg_satisfaction DESC, frequency DESC
                    ) hour_data
                ),
                'day_preferences', (
                    SELECT jsonb_agg(day_data)
                    FROM (
                        SELECT 
                            EXTRACT(DOW FROM ch.sent_at) as day,
                            COUNT(*) as frequency,
                            AVG((ch.effectiveness_metrics->>'customer_satisfaction')::float) as avg_satisfaction
                        FROM communication_history ch
                        WHERE ch.customer_id = customer_id_input
                        AND ch.sent_at > NOW() - (lookback_days || ' days')::INTERVAL
                        AND (ch.effectiveness_metrics->>'customer_satisfaction')::float >= 4.2
                        GROUP BY EXTRACT(DOW FROM ch.sent_at)
                        ORDER BY avg_satisfaction DESC, frequency DESC
                    ) day_data
                ),
                'response_times', (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'sent_at', ch.sent_at,
                            'response_time', 
                            GREATEST(0, EXTRACT(EPOCH FROM (ch.response_received_at - ch.sent_at))/3600),
                            'satisfaction', (ch.effectiveness_metrics->>'customer_satisfaction')::float
                        ) ORDER BY ch.sent_at DESC
                    )
                    FROM communication_history ch
                    WHERE ch.customer_id = customer_id_input
                    AND ch.sent_at > NOW() - (lookback_days || ' days')::INTERVAL
                    AND (ch.effectiveness_metrics->>'customer_satisfaction')::float >= 4.2
                    AND ch.response_received_at > ch.sent_at
                )
            ) as timing_data
    ),
    style_analysis AS (
        -- Rest of the function remains the same...
        SELECT 
            jsonb_build_object(
                'effective_styles', (
                    SELECT jsonb_agg(style_data)
                    FROM (
                        SELECT 
                            mt.context_type as style,
                            ch.template_id,
                            AVG((ch.effectiveness_metrics->>'customer_satisfaction')::float) as avg_satisfaction,
                            COUNT(*) as usage_count,
                            bool_and((ch.effectiveness_metrics->>'response_received')::boolean) as consistent_responses
                        FROM communication_history ch
                        JOIN message_templates mt ON mt.id = ch.template_id
                        WHERE ch.customer_id = customer_id_input
                        AND ch.effectiveness_metrics IS NOT NULL
                        GROUP BY mt.context_type, ch.template_id
                        HAVING AVG((ch.effectiveness_metrics->>'customer_satisfaction')::float) >= 4.2
                        ORDER BY avg_satisfaction DESC, usage_count DESC
                    ) style_data
                ),
                'top_templates', (
                    SELECT jsonb_agg(DISTINCT ch.template_id ORDER BY ch.template_id)
                    FROM communication_history ch
                    WHERE ch.customer_id = customer_id_input
                    AND (ch.effectiveness_metrics->>'customer_satisfaction')::float >= 4.5
                )
            ) as style_data
    )
    SELECT 
        (SELECT timing_data FROM time_analysis),
        (SELECT style_data FROM style_analysis),
        freq,
        jsonb_build_object(
            'total_communications', total_communications,
            'successful_communications', successful_communications,
            'success_rate', 
            CASE 
                WHEN total_communications > 0 THEN 
                    (((successful_communications::float / total_communications) * 100)::numeric)::float
                ELSE 0
            END,
            'average_satisfaction', (
                SELECT (AVG((ch.effectiveness_metrics->>'customer_satisfaction')::float)::numeric)::float
                FROM communication_history ch
                WHERE ch.customer_id = customer_id_input
                AND ch.sent_at > NOW() - (lookback_days || ' days')::INTERVAL
            ),
            'satisfaction_trend', (
                SELECT jsonb_agg(trend ORDER BY period)
                FROM (
                    SELECT 
                        date_trunc('week', ch.sent_at) as period,
                        (AVG((ch.effectiveness_metrics->>'customer_satisfaction')::float)::numeric)::float as avg_satisfaction,
                        COUNT(*) as communications_count
                    FROM communication_history ch
                    WHERE ch.customer_id = customer_id_input
                    AND ch.sent_at > NOW() - (lookback_days || ' days')::INTERVAL
                    GROUP BY date_trunc('week', ch.sent_at)
                ) trend
            )
        ),
        -- Enhanced confidence score calculation
        (
            CASE 
                WHEN total_communications = 0 THEN 0
                ELSE LEAST(
                    (successful_communications::float / 5) * -- Data volume factor (normalized to 5)
                    (successful_communications::float / total_communications) * -- Success rate factor
                    CASE 
                        WHEN EXISTS (
                            SELECT 1 FROM communication_history ch
                            WHERE ch.customer_id = customer_id_input
                            AND ch.sent_at > NOW() - INTERVAL '7 days'
                        ) THEN 1.2 -- Boost if recent data exists
                        ELSE 1.0
                    END,
                    1.0
                )
            END
        )::numeric::float;
END;
$$ LANGUAGE plpgsql;


-- drop trigger for set ticket requester
DROP TRIGGER IF EXISTS set_ticket_requester_trigger ON tickets;

-- Add trigger to set requester_id on ticket creation
CREATE OR REPLACE FUNCTION set_ticket_requester()
RETURNS TRIGGER AS $$
BEGIN
    NEW.requester_id := auth.uid();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to set requester_id on ticket creation
CREATE TRIGGER set_ticket_requester_trigger
    BEFORE INSERT ON tickets
    FOR EACH ROW
    EXECUTE FUNCTION set_ticket_requester();


-- drop set comment author trigger
DROP TRIGGER IF EXISTS set_comment_author_trigger ON ticket_comments;

-- Add trigger to set author_id on comment creation
CREATE OR REPLACE FUNCTION set_comment_author()
RETURNS TRIGGER AS $$
BEGIN
    NEW.author_id := auth.uid();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- create set comment author trigger
CREATE TRIGGER set_comment_author_trigger
    BEFORE INSERT ON ticket_comments
    FOR EACH ROW
    EXECUTE FUNCTION set_comment_author();


-- drop trigger to set organization on ticket creation
DROP TRIGGER IF EXISTS set_ticket_organization_trigger ON tickets;

-- Function to set ticket organization from requester
CREATE OR REPLACE FUNCTION set_ticket_organization()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Set organization_id from requester's organization
    NEW.organization_id := (
        SELECT organization_id 
        FROM users 
        WHERE id = NEW.requester_id
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to set organization on ticket creation
CREATE TRIGGER set_ticket_organization_trigger
    BEFORE INSERT ON tickets
    FOR EACH ROW
    EXECUTE FUNCTION set_ticket_organization();

-- Drop trigger
DROP TRIGGER IF EXISTS check_attachment_entity ON attachments;

-- Create trigger function to validate entity references
CREATE OR REPLACE FUNCTION validate_attachment_entity()
RETURNS TRIGGER AS $$
BEGIN
    -- Just check if the referenced entity exists in either table
    IF NOT EXISTS (
        SELECT 1 FROM tickets WHERE id = NEW.entity_id
        UNION
        SELECT 1 FROM ticket_comments WHERE id = NEW.entity_id
    ) THEN
        RAISE EXCEPTION 'Invalid entity reference';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- create trigger
CREATE TRIGGER check_attachment_entity
    BEFORE INSERT OR UPDATE ON attachments
    FOR EACH ROW
    EXECUTE FUNCTION validate_attachment_entity();


-- Drop trigger for message metrics
DROP TRIGGER IF EXISTS message_metrics_trigger ON communication_history;

-- Functions for tracking message metrics
CREATE OR REPLACE FUNCTION track_message_metrics()
RETURNS trigger AS $$
BEGIN
    -- For new messages
    IF TG_OP = 'INSERT' THEN
        -- Update customer preferences if satisfaction is high
        IF (NEW.effectiveness_metrics->>'customer_satisfaction')::float >= 4.2 THEN
            UPDATE customer_preferences
            SET metadata = jsonb_set(
                COALESCE(metadata, '{}'::jsonb),
                '{successful_patterns}',
                COALESCE(
                    (
                        SELECT jsonb_agg(stats)
                        FROM (
                            SELECT 
                                EXTRACT(HOUR FROM sent_at) as hour,
                                COUNT(*) as message_count,
                                AVG((effectiveness_metrics->>'customer_satisfaction')::float) as avg_satisfaction
                            FROM communication_history
                            WHERE customer_id = NEW.customer_id
                            AND (effectiveness_metrics->>'customer_satisfaction')::float >= 4.2
                            GROUP BY EXTRACT(HOUR FROM sent_at)
                            ORDER BY hour
                        ) stats
                    ),
                    '[]'::jsonb
                )
            )
            WHERE customer_id = NEW.customer_id;
        END IF;

    -- For updated messages (e.g., when response is received)
    ELSIF TG_OP = 'UPDATE' THEN
        -- Calculate response time if response just received
        IF NEW.response_received_at IS NOT NULL AND OLD.response_received_at IS NULL THEN
            -- Update response time metrics
            UPDATE customer_preferences
            SET metadata = jsonb_set(
                COALESCE(metadata, '{}'::jsonb),
                '{response_metrics}',
                COALESCE(
                    (
                        SELECT to_jsonb(stats)
                        FROM (
                            SELECT 
                                AVG(EXTRACT(EPOCH FROM (response_received_at - sent_at))/3600) as avg_response_hours,
                                COUNT(*) as total_responses,
                                MIN(EXTRACT(EPOCH FROM (response_received_at - sent_at))/3600) as min_response_hours,
                                MAX(EXTRACT(EPOCH FROM (response_received_at - sent_at))/3600) as max_response_hours
                            FROM communication_history
                            WHERE customer_id = NEW.customer_id
                            AND response_received_at IS NOT NULL
                        ) stats
                    ),
                    '{}'::jsonb
                )
            )
            WHERE customer_id = NEW.customer_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for message metrics
CREATE TRIGGER message_metrics_trigger
    AFTER INSERT OR UPDATE ON communication_history
    FOR EACH ROW
    EXECUTE FUNCTION track_message_metrics();
    
-- Create refresh function
CREATE OR REPLACE FUNCTION refresh_customer_insights()
RETURNS trigger AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY customer_communication_insights_mv;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger for refresh template stats
DROP TRIGGER IF EXISTS refresh_template_stats_trigger ON communication_history;

-- Create refresh function for template stats
CREATE OR REPLACE FUNCTION refresh_template_stats()
RETURNS trigger AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY template_stats_mv;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to refresh template stats
CREATE TRIGGER refresh_template_stats_trigger
    AFTER INSERT OR UPDATE OR DELETE ON communication_history
    FOR EACH STATEMENT
    EXECUTE FUNCTION refresh_template_stats();


-- Drop existing triggers
DROP TRIGGER IF EXISTS template_metrics_trigger ON message_templates;
DROP TRIGGER IF EXISTS template_usage_trigger ON communication_history;

-- Add metadata column to message_templates if it doesn't exist
ALTER TABLE message_templates 
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS effectiveness_score FLOAT DEFAULT 0,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Function to track template metrics
CREATE OR REPLACE FUNCTION track_template_metrics()
RETURNS trigger AS $$
DECLARE
    usage_metrics jsonb;
    effectiveness float;
BEGIN
    -- Prevent recursive trigger execution
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    -- Get effectiveness score
    SELECT AVG((effectiveness_metrics->>'customer_satisfaction')::float)
    INTO effectiveness
    FROM communication_history
    WHERE template_id = NEW.id
    AND effectiveness_metrics->>'customer_satisfaction' IS NOT NULL;

    -- Get usage metrics
    SELECT jsonb_build_object(
        'total_uses', COUNT(*),
        'successful_uses', COUNT(*) FILTER (
            WHERE (effectiveness_metrics->>'customer_satisfaction')::float >= 4.2
        ),
        'response_rate', (
            COUNT(*) FILTER (WHERE response_received_at IS NOT NULL)::float / 
            NULLIF(COUNT(*), 0)
        ),
        'avg_response_time', (
            AVG(EXTRACT(EPOCH FROM (response_received_at - sent_at))/3600)
            FILTER (WHERE response_received_at IS NOT NULL)
        )
    )
    INTO usage_metrics
    FROM communication_history
    WHERE template_id = NEW.id;

    -- Update template
    UPDATE message_templates
    SET 
        effectiveness_score = COALESCE(effectiveness, 0),
        metadata = jsonb_set(
            COALESCE(metadata, '{}'::jsonb),
            '{usage_metrics}',
            COALESCE(usage_metrics, '{}'::jsonb)
        ),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to track template usage
CREATE OR REPLACE FUNCTION track_template_usage()
RETURNS trigger AS $$
BEGIN
    -- Skip if no template_id or recursive trigger
    IF NEW.template_id IS NULL OR pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    -- Update template metadata with latest usage
    UPDATE message_templates
    SET 
        metadata = jsonb_set(
            COALESCE(metadata, '{}'::jsonb),
            '{last_usage}',
            jsonb_build_object(
                'customer_id', NEW.customer_id,
                'sent_at', NEW.sent_at,
                'effectiveness', NEW.effectiveness_metrics,
                'response_received', (NEW.response_received_at IS NOT NULL)
            )::jsonb
        ),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.template_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER template_metrics_trigger
    AFTER INSERT OR UPDATE ON message_templates
    FOR EACH ROW
    EXECUTE FUNCTION track_template_metrics();

CREATE TRIGGER template_usage_trigger
    AFTER INSERT OR UPDATE ON communication_history
    FOR EACH ROW
    EXECUTE FUNCTION track_template_usage();

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_communication_history_template_effectiveness 
ON communication_history (template_id, (effectiveness_metrics->>'customer_satisfaction'));

CREATE INDEX IF NOT EXISTS idx_communication_history_template_response 
ON communication_history (template_id, response_received_at);
