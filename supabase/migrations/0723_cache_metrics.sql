-- Track cache performance metrics
CREATE TABLE cache_metrics (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  cache_key text NOT NULL,
  operation text NOT NULL CHECK (operation IN ('hit', 'miss', 'expired', 'error')),
  duration_ms integer,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Add indexes
CREATE INDEX idx_cache_metrics_operation ON cache_metrics(operation);
CREATE INDEX idx_cache_metrics_created_at ON cache_metrics(created_at);

-- Enable RLS
ALTER TABLE cache_metrics ENABLE ROW LEVEL SECURITY;

-- Grant permissions
GRANT SELECT, INSERT ON cache_metrics TO service_role; 
