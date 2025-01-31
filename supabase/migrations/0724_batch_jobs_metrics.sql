-- Add metrics columns to batch_jobs
ALTER TABLE batch_jobs 
  -- Track individual message durations
  ADD COLUMN IF NOT EXISTS avg_duration_ms INTEGER,
  ADD COLUMN IF NOT EXISTS p95_duration_ms INTEGER,
  -- Track cache performance
  ADD COLUMN IF NOT EXISTS cache_hits INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cache_misses INTEGER DEFAULT 0,
  -- Track detailed progress
  ADD COLUMN IF NOT EXISTS queued_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS processing_count INTEGER DEFAULT 0,
  -- Track rate limiting
  ADD COLUMN IF NOT EXISTS rate_limit_hits INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS concurrency INTEGER DEFAULT 5;

-- Add index for performance monitoring
CREATE INDEX IF NOT EXISTS idx_batch_jobs_metrics 
  ON batch_jobs(status, created_at)
  WHERE status IN ('processing', 'completed', 'completed_with_errors'); 