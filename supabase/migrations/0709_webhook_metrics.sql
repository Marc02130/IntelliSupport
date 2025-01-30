-- Create webhook metrics view
CREATE VIEW webhook_metrics AS
WITH delivery_stats AS (
  SELECT
    webhook_id,
    wc.organization_id,
    COUNT(*) as total_deliveries,
    COUNT(CASE WHEN status = 'success' THEN 1 END) as successful_deliveries,
    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_deliveries,
    AVG(CASE WHEN status = 'success' THEN duration_ms END) as avg_duration_ms,
    AVG(attempt_count) as avg_attempts,
    MAX(attempt_count) as max_attempts,
    COUNT(CASE WHEN attempt_count > 1 THEN 1 END) as retried_deliveries
  FROM webhook_deliveries wd
  JOIN webhook_configurations wc ON wc.id = wd.webhook_id
  WHERE wd.created_at > NOW() - INTERVAL '24 hours'
  AND EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND organization_id = wc.organization_id
  )
  GROUP BY webhook_id,
    wc.organization_id
)
SELECT
  wc.id as webhook_id,
  wc.organization_id,
  wc.name,
  wc.url,
  wc.is_active,
  COALESCE(ds.total_deliveries, 0) as deliveries_24h,
  COALESCE(ds.successful_deliveries, 0) as successful_24h,
  COALESCE(ds.failed_deliveries, 0) as failed_24h,
  ROUND(COALESCE(ds.avg_duration_ms, 0)) as avg_duration_ms,
  ROUND(COALESCE(ds.avg_attempts, 0), 2) as avg_attempts,
  COALESCE(ds.max_attempts, 0) as max_attempts,
  COALESCE(ds.retried_deliveries, 0) as retried_24h,
  CASE 
    WHEN ds.total_deliveries > 0 
    THEN ROUND(CAST((ds.successful_deliveries::numeric / ds.total_deliveries) * 100 AS numeric), 2)
    ELSE 0
  END as success_rate
FROM webhook_configurations wc
LEFT JOIN delivery_stats ds ON ds.webhook_id = wc.id
WHERE EXISTS (
  SELECT 1 FROM users
  WHERE id = auth.uid()
  AND organization_id = wc.organization_id
);

-- Grant access to metrics view
GRANT SELECT ON webhook_metrics TO authenticated; 