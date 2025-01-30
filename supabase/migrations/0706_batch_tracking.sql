-- Create batch_runs table
CREATE TABLE batch_runs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id UUID REFERENCES organizations(id),
  context_type TEXT NOT NULL,
  total_messages INTEGER,
  successful_messages INTEGER,
  failed_messages INTEGER,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  status TEXT DEFAULT 'running',
  error_details JSONB,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Create message_deliveries table
CREATE TABLE message_deliveries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  message_id UUID REFERENCES communication_history(id),
  version_id UUID REFERENCES message_versions(id),
  customer_id UUID REFERENCES users(id),
  batch_run_id UUID REFERENCES batch_runs(id),
  channel TEXT NOT NULL,
  content TEXT NOT NULL,
  scheduled_for TIMESTAMPTZ NOT NULL,
  sent_at TIMESTAMPTZ,
  status TEXT DEFAULT 'pending',
  error_details JSONB,
  delivery_metadata JSONB,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add indexes
CREATE INDEX idx_message_deliveries_status ON message_deliveries(status);
CREATE INDEX idx_message_deliveries_scheduled ON message_deliveries(scheduled_for);
CREATE INDEX idx_message_deliveries_customer ON message_deliveries(customer_id);

-- Add RLS for message_deliveries
ALTER TABLE message_deliveries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view deliveries in their organization"
  ON message_deliveries
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND organization_id = (
        SELECT organization_id FROM users WHERE id = message_deliveries.customer_id
      )
    )
  );

CREATE POLICY "Users can create deliveries for their organization"
  ON message_deliveries
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND organization_id = (
        SELECT organization_id FROM users WHERE id = message_deliveries.customer_id
      )
    )
  );

-- Add RLS policies
-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.batch_runs TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.batch_runs TO authenticated;

ALTER TABLE batch_runs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view batch runs in their organization"
  ON batch_runs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND organization_id = batch_runs.organization_id
    )
  );

CREATE POLICY "Users can create batch runs in their organization"
  ON batch_runs
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND organization_id = batch_runs.organization_id
    )
  );
