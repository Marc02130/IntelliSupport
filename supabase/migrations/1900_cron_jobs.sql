-- cron jobs
SELECT cron.schedule(
  'process-embedding-queue',
  '*/5 * * * *',
  'SELECT process_embedding_queue();'  
);

SELECT cron.schedule(
  'route-tickets',
  '*/5 * * * *',
  'SELECT route_tickets_job();'
);

SELECT cron.schedule(
  'batch-messages',
  '0 * * * *',  
  'SELECT batch_messages();'
);

-- Clean up old logs daily
SELECT cron.schedule(
  'cleanup-old-logs',
  '0 0 * * *',  -- Every day at midnight
  $$
  DELETE FROM message_generation_logs 
  WHERE started_at < NOW() - INTERVAL '30 days';
  
  DELETE FROM cron_job_logs 
  WHERE created_at < NOW() - INTERVAL '30 days';
  $$
);

-- Update customer insights weekly
SELECT cron.schedule(
  'update-customer-insights',
  '0 0 * * 0',  -- Every Sunday at midnight
  $$
  WITH recent_communications AS (
    SELECT 
      customer_id,
      COUNT(*) as message_count,
      AVG((effectiveness_metrics->>'customer_satisfaction')::float) as avg_satisfaction,
      MODE() WITHIN GROUP (ORDER BY template_style) as preferred_style,
      MODE() WITHIN GROUP (ORDER BY EXTRACT(HOUR FROM sent_at)) as preferred_hour
    FROM communication_history
    WHERE sent_at > NOW() - INTERVAL '30 days'
    GROUP BY customer_id
  )
  UPDATE customer_communication_insights ci
  SET
    message_frequency = rc.message_count::float / 30,
    satisfaction_trend = rc.avg_satisfaction,
    preferred_style = rc.preferred_style,
    preferred_times = jsonb_build_object('hour', rc.preferred_hour),
    updated_at = NOW()
  FROM recent_communications rc
  WHERE ci.customer_id = rc.customer_id;
  $$
);

-- Schedule the message queue processing
SELECT cron.schedule(
    'process-message-queue',
    '0 * * * *',  -- Every hour
    $$SELECT process_message_queue();$$
);

-- Add webhook processing job
SELECT cron.schedule(
  'process-webhook-queue',
  '*/5 * * * *',  -- Every 5 minutes
  $$
  WITH pending_webhooks AS (
    SELECT id 
    FROM webhook_deliveries
    WHERE status = 'retrying'
    AND next_retry_at <= NOW()
    LIMIT 100
    FOR UPDATE SKIP LOCKED
  )
  UPDATE webhook_deliveries wd
  SET status = 'processing'
  FROM pending_webhooks pw
  WHERE wd.id = pw.id;
  $$
);

-- Add webhook cleanup job
SELECT cron.schedule(
  'cleanup-webhook-logs',
  '0 0 * * *',  -- Daily at midnight
  $$
  DELETE FROM webhook_deliveries
  WHERE created_at < NOW() - INTERVAL '30 days'
  AND status IN ('success', 'failed');
  $$
); 


-- Create a scheduled job to run every hour instead of using a trigger
SELECT cron.schedule(
  'cleanup-old-previews',
  '0 * * * *',  -- Run every hour
  'SELECT clean_old_previews_without_feedback()'
); 

-- Check if this has learning update jobs configured 

-- Add rapid learning updates
SELECT cron.schedule(
  'rapid-learning-updates',
  '*/5 * * * *',  -- Every 5 minutes
  'SELECT process_message_feedback();'
); 