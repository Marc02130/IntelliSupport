CREATE TABLE IF NOT EXISTS cache_metrics (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  cache_key text NOT NULL,
  operation text NOT NULL,
  duration_ms integer NOT NULL,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.cache_metrics TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.cache_metrics TO authenticated;
GRANT SELECT ON cache_metrics TO anon;

-- Add index for querying by cache key
CREATE INDEX IF NOT EXISTS idx_cache_metrics_cache_key 
  ON cache_metrics (cache_key);

-- Add index for querying recent metrics
CREATE INDEX IF NOT EXISTS idx_cache_metrics_created_at 
  ON cache_metrics (created_at DESC);

-- Grant permissions
GRANT SELECT, INSERT ON cache_metrics TO service_role;
GRANT SELECT ON cache_metrics TO authenticated;

-- Enable RLS
ALTER TABLE cache_metrics ENABLE ROW LEVEL SECURITY;

-- Add RLS policies
CREATE POLICY "Anyone can view cache metrics"
  ON cache_metrics FOR SELECT
  USING (true);

CREATE POLICY "Service role can insert cache metrics"
  ON cache_metrics FOR INSERT
  WITH CHECK (true); 