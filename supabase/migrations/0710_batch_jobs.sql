-- Track batch message generation jobs
CREATE TABLE batch_jobs (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  total_messages INTEGER NOT NULL,
  processed_count INTEGER DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'processing' 
    CHECK (status IN ('processing', 'completed', 'completed_with_errors', 'failed', 'cancelled')),
  results JSONB,
  errors JSONB,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add indexes
CREATE INDEX idx_batch_jobs_user ON batch_jobs(user_id);
CREATE INDEX idx_batch_jobs_status ON batch_jobs(status);

-- Add RLS policy
ALTER TABLE batch_jobs ENABLE ROW LEVEL SECURITY;

-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.batch_jobs TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.batch_jobs TO authenticated;
GRANT SELECT ON batch_jobs TO anon;

-- Add policies
CREATE POLICY "Users can view their own batch jobs"
ON batch_jobs FOR SELECT
TO authenticated
USING (true);  -- Allow all users to view batch jobs for now

CREATE POLICY "Users can create their own batch jobs"
ON batch_jobs FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Create new policy allowing all reads including anonymous
CREATE POLICY "Anyone can view batch jobs"
  ON batch_jobs FOR SELECT
  TO anon, authenticated
  USING (true); 