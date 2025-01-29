-- Drop existing views and materialized views
DROP VIEW IF EXISTS customer_communication_recommendations;
DROP VIEW IF EXISTS customer_communication_trends;
DROP VIEW IF EXISTS customer_communication_insights;
DROP MATERIALIZED VIEW IF EXISTS template_stats_mv;

-- Create a view for easy access to customer communication insights
CREATE OR REPLACE VIEW customer_communication_insights AS
WITH latest_analysis AS (
    SELECT DISTINCT ON (cp.customer_id)
        cp.customer_id,
        cp.metadata->'recommendations' as analysis_recommendations,
        cp.updated_at as analyzed_at
    FROM customer_preferences cp
    WHERE cp.metadata->'recommendations' IS NOT NULL
    ORDER BY cp.customer_id, cp.updated_at DESC
),
communication_stats AS (
    SELECT 
        ch.customer_id,
        COUNT(*) as total_communications,
        COUNT(*) FILTER (WHERE (ch.effectiveness_metrics->>'customer_satisfaction')::float >= 4.2) as successful_communications,
        AVG((ch.effectiveness_metrics->>'customer_satisfaction')::float) as avg_satisfaction,
        jsonb_agg(DISTINCT ch.template_id) FILTER (
            WHERE (ch.effectiveness_metrics->>'customer_satisfaction')::float >= 4.5
        ) as successful_templates,
        jsonb_build_object(
            'early_morning', COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM ch.sent_at) BETWEEN 5 AND 8),
            'morning', COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM ch.sent_at) BETWEEN 9 AND 11),
            'early_afternoon', COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM ch.sent_at) BETWEEN 12 AND 14),
            'late_afternoon', COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM ch.sent_at) BETWEEN 15 AND 17),
            'evening', COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM ch.sent_at) BETWEEN 18 AND 20),
            'night', COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM ch.sent_at) BETWEEN 21 AND 23)
        ) as time_of_day_distribution,
        jsonb_build_object(
            'monday', COUNT(*) FILTER (WHERE EXTRACT(DOW FROM ch.sent_at) = 1),
            'tuesday', COUNT(*) FILTER (WHERE EXTRACT(DOW FROM ch.sent_at) = 2),
            'wednesday', COUNT(*) FILTER (WHERE EXTRACT(DOW FROM ch.sent_at) = 3),
            'thursday', COUNT(*) FILTER (WHERE EXTRACT(DOW FROM ch.sent_at) = 4),
            'friday', COUNT(*) FILTER (WHERE EXTRACT(DOW FROM ch.sent_at) = 5),
            'saturday', COUNT(*) FILTER (WHERE EXTRACT(DOW FROM ch.sent_at) = 6),
            'sunday', COUNT(*) FILTER (WHERE EXTRACT(DOW FROM ch.sent_at) = 0)
        ) as day_distribution,
        AVG(EXTRACT(EPOCH FROM (ch.response_received_at - ch.sent_at))/3600) FILTER (
            WHERE ch.response_received_at > ch.sent_at
        ) as avg_response_time_hours,
        jsonb_build_object(
            'last_7_days', COUNT(*) FILTER (WHERE ch.sent_at > NOW() - INTERVAL '7 days'),
            'last_30_days', COUNT(*) FILTER (WHERE ch.sent_at > NOW() - INTERVAL '30 days'),
            'last_90_days', COUNT(*)
        ) as activity_summary
    FROM communication_history ch
    WHERE ch.sent_at > NOW() - INTERVAL '90 days'
    GROUP BY ch.customer_id
),
template_stats_raw AS (
    SELECT 
        ch.customer_id,
        ch.template_id,
        mt.context_type as style,
        AVG((ch.effectiveness_metrics->>'customer_satisfaction')::float) as avg_satisfaction,
        COUNT(*) as usage_count,
        COUNT(*) FILTER (WHERE ch.response_received_at IS NOT NULL)::float / COUNT(*) as response_rate,
        jsonb_agg(DISTINCT to_char(ch.sent_at, 'Day')) as days_used,
        mode() WITHIN GROUP (ORDER BY EXTRACT(HOUR FROM ch.sent_at)) as preferred_hour
    FROM communication_history ch
    JOIN message_templates mt ON mt.id = ch.template_id
    WHERE ch.sent_at > NOW() - INTERVAL '90 days'
    GROUP BY ch.customer_id, ch.template_id, mt.context_type
),
template_performance AS (
    SELECT 
        customer_id,
        jsonb_agg(
            jsonb_build_object(
                'template_id', template_id,
                'style', style,
                'avg_satisfaction', ROUND(avg_satisfaction::numeric, 2),
                'usage_count', usage_count,
                'response_rate', ROUND(response_rate::numeric, 2),
                'days_used', days_used,
                'preferred_hour', preferred_hour
            )
            ORDER BY avg_satisfaction DESC NULLS LAST, usage_count DESC
        ) as template_stats
    FROM template_stats_raw
    GROUP BY customer_id
)
SELECT DISTINCT ON (u.id)
    u.id as customer_id,
    pu.full_name,
    pu.organization_id,
    cp.preferred_style,
    cp.communication_frequency,
    cs.total_communications,
    cs.successful_communications,
    ROUND((cs.successful_communications::float / NULLIF(cs.total_communications, 0) * 100)::numeric, 2) as success_rate,
    ROUND(cs.avg_satisfaction::numeric, 2) as avg_satisfaction,
    cs.successful_templates,
    cs.time_of_day_distribution,
    cs.day_distribution,
    ROUND(cs.avg_response_time_hours::numeric, 2) as avg_response_time_hours,
    cs.activity_summary,
    tp.template_stats as template_performance,
    la.analysis_recommendations,
    la.analyzed_at,
    CASE 
        WHEN cs.total_communications >= 10 AND cs.avg_satisfaction >= 4.2 THEN 'High'
        WHEN cs.total_communications >= 5 AND cs.avg_satisfaction >= 4.0 THEN 'Medium'
        ELSE 'Low'
    END as confidence_level,
    CASE 
        WHEN cs.avg_satisfaction >= 4.5 THEN 'Excellent'
        WHEN cs.avg_satisfaction >= 4.2 THEN 'Good'
        WHEN cs.avg_satisfaction >= 4.0 THEN 'Fair'
        ELSE 'Needs Improvement'
    END as satisfaction_rating
FROM auth.users u
JOIN public.users pu ON pu.id = u.id
LEFT JOIN customer_preferences cp ON cp.customer_id = u.id
LEFT JOIN latest_analysis la ON la.customer_id = u.id
LEFT JOIN communication_stats cs ON cs.customer_id = u.id
LEFT JOIN template_performance tp ON tp.customer_id = u.id
WHERE u.raw_user_meta_data->>'role' = 'customer'
ORDER BY u.id, cs.total_communications DESC NULLS LAST;

-- Create trends view
CREATE VIEW customer_communication_trends AS
WITH weekly_stats AS (
    SELECT 
        customer_id,
        date_trunc('week', sent_at) as week,
        COUNT(*) as communications,
        AVG((effectiveness_metrics->>'customer_satisfaction')::float) as avg_satisfaction,
        COUNT(*) FILTER (WHERE response_received_at IS NOT NULL) as responses,
        AVG(EXTRACT(EPOCH FROM (response_received_at - sent_at))/3600) as avg_response_time
    FROM communication_history
    WHERE sent_at > NOW() - INTERVAL '90 days'
    GROUP BY customer_id, date_trunc('week', sent_at)
)
SELECT 
    customer_id,
    jsonb_build_object(
        'weekly_volume', jsonb_agg(
            jsonb_build_object(
                'week', week,
                'communications', communications,
                'responses', responses,
                'satisfaction', ROUND(avg_satisfaction::numeric, 2),
                'response_time', ROUND(avg_response_time::numeric, 2)
            ) ORDER BY week
        ),
        'trend_indicators', jsonb_build_object(
            'volume_trend', ROUND(corr(EXTRACT(EPOCH FROM week), communications)::numeric, 2),
            'satisfaction_trend', ROUND(corr(EXTRACT(EPOCH FROM week), avg_satisfaction)::numeric, 2),
            'response_time_trend', ROUND(corr(EXTRACT(EPOCH FROM week), avg_response_time)::numeric, 2)
        )
    ) as trends
FROM weekly_stats
GROUP BY customer_id;

-- Create materialized view for template stats
CREATE MATERIALIZED VIEW template_stats_mv AS
SELECT 
    ch.customer_id,
    ch.template_id,
    mt.context_type as style,
    AVG((ch.effectiveness_metrics->>'customer_satisfaction')::float) as avg_satisfaction,
    COUNT(*) as usage_count,
    COUNT(*) FILTER (WHERE ch.response_received_at IS NOT NULL)::float / COUNT(*) as response_rate,
    jsonb_agg(DISTINCT to_char(ch.sent_at, 'Day')) as days_used,
    mode() WITHIN GROUP (ORDER BY EXTRACT(HOUR FROM ch.sent_at)) as preferred_hour
FROM communication_history ch
JOIN message_templates mt ON mt.id = ch.template_id
WHERE ch.sent_at > NOW() - INTERVAL '90 days'
GROUP BY ch.customer_id, ch.template_id, mt.context_type;

-- Create index on materialized view
CREATE UNIQUE INDEX ON template_stats_mv (customer_id, template_id);

-- Create recommendations view
CREATE VIEW customer_communication_recommendations AS
WITH ranked_templates AS (
    SELECT 
        t.*,
        ROW_NUMBER() OVER (
            PARTITION BY t.customer_id 
            ORDER BY t.avg_satisfaction DESC NULLS LAST, t.usage_count DESC
        ) as rank
    FROM template_stats_mv t
    WHERE t.avg_satisfaction >= 4.2
)
SELECT 
    ci.customer_id,
    ci.full_name,
    ci.organization_id,
    ci.preferred_style,
    ci.communication_frequency,
    ci.total_communications,
    ci.successful_communications,
    ci.success_rate,
    ci.avg_satisfaction,
    ci.successful_templates,
    ci.time_of_day_distribution,
    ci.day_distribution,
    ci.avg_response_time_hours,
    ci.activity_summary,
    ci.template_performance,
    ci.analysis_recommendations,
    ci.analyzed_at,
    ci.confidence_level,
    ci.satisfaction_rating,
    jsonb_build_object(
        'suggested_templates', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'template_id', t.template_id,
                    'style', t.style,
                    'avg_satisfaction', ROUND(t.avg_satisfaction::numeric, 2),
                    'usage_count', t.usage_count,
                    'response_rate', ROUND(t.response_rate::numeric, 2),
                    'days_used', t.days_used,
                    'preferred_hour', t.preferred_hour
                )
                ORDER BY t.rank
            )
            FROM ranked_templates t
            WHERE t.customer_id = ci.customer_id
            AND t.rank <= 3
        ),
        'best_times', jsonb_build_object(
            'hour', (
                SELECT k 
                FROM jsonb_each_text(ci.time_of_day_distribution) e(k,v)
                ORDER BY (v::int) DESC
                LIMIT 1
            ),
            'day', (
                SELECT k 
                FROM jsonb_each_text(ci.day_distribution) e(k,v)
                ORDER BY (v::int) DESC
                LIMIT 1
            )
        ),
        'action_items', jsonb_build_array(
            CASE 
                WHEN ci.success_rate < 50 THEN 'Increase communication frequency'
                WHEN ci.avg_satisfaction < 4.0 THEN 'Review communication style'
                ELSE 'Maintain current approach'
            END
        )
    ) as recommendations
FROM customer_communication_insights ci;

-- Add comments
COMMENT ON VIEW customer_communication_insights IS 
'Provides comprehensive analysis of customer communication patterns, preferences, and effectiveness metrics';

COMMENT ON VIEW customer_communication_trends IS
'Provides weekly trend analysis of communication patterns and effectiveness';

COMMENT ON VIEW customer_communication_recommendations IS
'Provides personalized communication recommendations based on historical performance';

COMMENT ON MATERIALIZED VIEW template_stats_mv IS
'Cached analysis of template performance metrics';

-- Add materialized view for customer insights
CREATE MATERIALIZED VIEW customer_communication_insights_mv AS
SELECT * FROM customer_communication_insights;

-- Create unique index
CREATE UNIQUE INDEX ON customer_communication_insights_mv (customer_id);
