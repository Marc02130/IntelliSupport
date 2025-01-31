-- Message Generation Performance
WITH metrics AS (
  SELECT 
    id,
    duration_ms,
    metadata->>'context_duration' as context_ms,
    metadata->>'cache_duration' as cache_ms,
    metadata->>'total_duration' as total_ms,
    status,
    created_at
  FROM message_previews
  WHERE created_at > NOW() - INTERVAL '24 hours'
)
SELECT
  status,
  COUNT(*) as count,
  ROUND(AVG(duration_ms)::numeric, 2) as avg_duration_ms,
  ROUND(percentile_cont(0.95) WITHIN GROUP (ORDER BY duration_ms)::numeric, 2) as p95_duration_ms,
  ROUND(AVG(NULLIF(context_ms::int, 0))::numeric, 2) as avg_context_ms,
  ROUND(AVG(NULLIF(cache_ms::int, 0))::numeric, 2) as avg_cache_ms
FROM metrics
GROUP BY status
ORDER BY count DESC;

-- Cache Performance
SELECT
  operation,
  COUNT(*) as total,
  ROUND(AVG(duration_ms)::numeric, 2) as avg_duration_ms,
  ROUND(percentile_cont(0.95) WITHIN GROUP (ORDER BY duration_ms)::numeric, 2) as p95_duration_ms,
  COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
FROM cache_metrics 
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY operation
ORDER BY total DESC;

-- Performance by Time of Day
SELECT 
  EXTRACT(HOUR FROM created_at) as hour,
  COUNT(*) as requests,
  ROUND(AVG(duration_ms)::numeric, 2) as avg_duration_ms,
  ROUND(percentile_cont(0.95) WITHIN GROUP (ORDER BY duration_ms)::numeric, 2) as p95_duration_ms
FROM message_previews
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour;

-- Error Analysis
SELECT 
  error,
  COUNT(*) as occurrences,
  MIN(created_at) as first_seen,
  MAX(created_at) as last_seen,
  ROUND(AVG(duration_ms)::numeric, 2) as avg_duration_ms
FROM message_previews
WHERE status = 'error'
  AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY error
ORDER BY occurrences DESC;

-- Cache Hit Rate Over Time
WITH intervals AS (
  SELECT 
    date_trunc('hour', created_at) as interval_start,
    operation,
    COUNT(*) as ops
  FROM cache_metrics
  WHERE created_at > NOW() - INTERVAL '24 hours'
  GROUP BY date_trunc('hour', created_at), operation
)
SELECT 
  interval_start,
  SUM(CASE WHEN operation = 'hit' THEN ops ELSE 0 END) as hits,
  SUM(ops) as total,
  ROUND(100.0 * SUM(CASE WHEN operation = 'hit' THEN ops ELSE 0 END) / SUM(ops), 2) as hit_rate
FROM intervals
GROUP BY interval_start
ORDER BY interval_start DESC;

-- Slow Queries Analysis
SELECT 
  id,
  message_text,
  customer_id,
  style,
  duration_ms,
  metadata->>'context_duration' as context_ms,
  created_at
FROM message_previews
WHERE status = 'completed'
  AND created_at > NOW() - INTERVAL '24 hours'
  AND duration_ms > 3000  -- Queries taking more than 3 seconds
ORDER BY duration_ms DESC
LIMIT 10;

-- Batch Job Performance
WITH job_metrics AS (
  SELECT 
    status,
    avg_duration_ms,
    p95_duration_ms,
    cache_hits,
    cache_misses,
    rate_limit_hits,
    total_messages,
    processed_count,
    results->>'avg_context_ms' as avg_context_ms,
    results->>'avg_openai_ms' as avg_openai_ms,
    results->'performance'->>'context_p95' as p95_context_ms,
    results->'performance'->>'openai_p95' as p95_openai_ms,
    EXTRACT(EPOCH FROM (completed_at - started_at)) as total_duration_sec
  FROM batch_jobs
  WHERE created_at > NOW() - INTERVAL '24 hours'
)
SELECT
  status,
  COUNT(*) as jobs,
  ROUND(AVG(total_messages)) as avg_batch_size,
  ROUND(AVG(avg_duration_ms)) as avg_msg_duration_ms,
  ROUND(AVG(p95_duration_ms)) as avg_p95_duration_ms,
  ROUND(AVG(avg_context_ms::numeric)) as avg_context_ms,
  ROUND(AVG(p95_context_ms::numeric)) as p95_context_ms,
  ROUND(AVG(avg_openai_ms::numeric)) as avg_openai_ms,
  ROUND(AVG(p95_openai_ms::numeric)) as p95_openai_ms,
  ROUND(AVG(cache_hits * 100.0 / NULLIF(cache_hits + cache_misses, 0)), 2) as cache_hit_rate,
  ROUND(AVG(total_duration_sec)) as avg_job_duration_sec,
  SUM(rate_limit_hits) as total_rate_limits
FROM job_metrics
GROUP BY status
ORDER BY jobs DESC;

-- Batch Processing Throughput
SELECT 
  date_trunc('hour', created_at) as hour,
  COUNT(*) as jobs,
  SUM(total_messages) as total_messages,
  SUM(processed_count) as processed_messages,
  ROUND(AVG(avg_duration_ms)) as avg_duration_ms,
  SUM(cache_hits) as cache_hits,
  SUM(cache_misses) as cache_misses
FROM batch_jobs
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour DESC;

-- Error Analysis by Type
WITH error_details AS (
  SELECT 
    id,
    errors->'details' as details
  FROM batch_jobs
  WHERE status = 'completed_with_errors'
    AND created_at > NOW() - INTERVAL '24 hours'
)
SELECT 
  details->>'type' as error_type,
  COUNT(*) as occurrences,
  array_agg(DISTINCT details->>'message') as unique_messages
FROM error_details
CROSS JOIN LATERAL jsonb_array_elements(details) as error
GROUP BY error_type
ORDER BY occurrences DESC; 