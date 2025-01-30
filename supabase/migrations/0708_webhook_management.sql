-- Create webhook event types
CREATE TYPE webhook_event_type AS ENUM (
  'delivery_status',
  'message_created',
  'message_updated',
  'batch_status',
  'delivery_metrics',
  'customer_feedback',
  'system_alert'
);

-- Create webhook configurations table
CREATE TABLE webhook_configurations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id UUID REFERENCES organizations(id),
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  secret TEXT NOT NULL,
  event_types webhook_event_type[] NOT NULL,
  is_active BOOLEAN DEFAULT true,
  retry_count INTEGER DEFAULT 3,
  timeout_ms INTEGER DEFAULT 5000,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb,
  
  CONSTRAINT valid_url CHECK (url ~ '^https?://')
);

-- Create webhook delivery tracking table
CREATE TABLE webhook_deliveries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  webhook_id UUID REFERENCES webhook_configurations(id),
  event_type webhook_event_type NOT NULL,
  payload JSONB NOT NULL,
  status TEXT NOT NULL,
  status_code INTEGER,
  response_body TEXT,
  error_message TEXT,
  attempt_count INTEGER DEFAULT 0,
  next_retry_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  duration_ms INTEGER,
  
  CONSTRAINT valid_status CHECK (status IN ('pending', 'success', 'failed', 'retrying'))
);

-- Add indexes
CREATE INDEX idx_webhook_configs_org ON webhook_configurations(organization_id);
CREATE INDEX idx_webhook_configs_active ON webhook_configurations(is_active);
CREATE INDEX idx_webhook_deliveries_status ON webhook_deliveries(status);
CREATE INDEX idx_webhook_deliveries_webhook ON webhook_deliveries(webhook_id);
CREATE INDEX idx_webhook_deliveries_created ON webhook_deliveries(created_at);

-- Add RLS
ALTER TABLE webhook_configurations ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhook_deliveries ENABLE ROW LEVEL SECURITY;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON webhook_configurations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON webhook_deliveries TO authenticated;

-- RLS policies
CREATE POLICY "Users can manage webhooks in their organization"
  ON webhook_configurations
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND organization_id = webhook_configurations.organization_id
    )
  );

CREATE POLICY "Users can view webhook deliveries in their organization"
  ON webhook_deliveries
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM webhook_configurations wc
      JOIN users u ON u.organization_id = wc.organization_id
      WHERE u.id = auth.uid()
      AND wc.id = webhook_deliveries.webhook_id
    )
  );

-- Update trigger for webhook_configurations
CREATE OR REPLACE FUNCTION update_webhook_config_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_webhook_config_timestamp
  BEFORE UPDATE ON webhook_configurations
  FOR EACH ROW
  EXECUTE FUNCTION update_webhook_config_timestamp(); 