-- Enable realtime for message previews
create table message_previews (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id),
  message_text text not null,
  preview_text text,
  customer_id uuid not null,
  duration_ms integer,
  style text,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'completed', 'error')),
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Enable row level security
ALTER TABLE message_previews FORCE ROW LEVEL SECURITY;
alter table message_previews enable row level security;

-- Grant table permissions
GRANT ALL ON public.message_previews TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.message_previews TO authenticated;
GRANT SELECT ON public.message_previews TO anon;


-- Add correct policies
CREATE POLICY "Service role can manage all previews"
  ON message_previews FOR ALL
  USING (CURRENT_USER = 'service_role'::name);

CREATE POLICY "Users can view their own previews"
  ON message_previews FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own previews"
  ON message_previews FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own previews"
  ON message_previews FOR UPDATE
  USING (auth.uid() = user_id); 

-- Enable realtime
alter publication supabase_realtime add table message_previews;
