-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom session variable for audit control
SELECT set_config('session.audit_trigger_enabled', 'TRUE', FALSE);

-- Organizations table
CREATE TABLE public.organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    domain VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Create users table
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT,
    first_name TEXT,
    last_name TEXT,
    phone TEXT,
    avatar TEXT,
    is_active BOOLEAN DEFAULT true,
    organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
    role TEXT DEFAULT 'customer' CHECK (role IN ('admin', 'agent', 'customer')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Add computed column for full name
ALTER TABLE public.users 
ADD COLUMN full_name TEXT GENERATED ALWAYS AS 
  (first_name || ' ' || last_name) STORED;

-- Create knowledge domain table
CREATE TABLE public.knowledge_domain (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Junction table for users and knowledge domains
CREATE TABLE public.user_knowledge_domain (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    knowledge_domain_id UUID REFERENCES knowledge_domain(id) ON DELETE CASCADE,
    expertise VARCHAR(20) NOT NULL CHECK (expertise IN ('beginner', 'intermediate', 'expert')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    description TEXT,
    credential TEXT,
    years_experience INTEGER NOT NULL CHECK (years_experience >= 0),
    UNIQUE (user_id, knowledge_domain_id),
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Move teams table creation before tickets table
CREATE TABLE public.teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Then create tickets table with team_id reference
CREATE TABLE public.tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'pending', 'solved', 'closed')),
    priority VARCHAR(20) NOT NULL DEFAULT 'low' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    requester_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    assignee_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
    organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Comments/Replies on tickets
CREATE TABLE public.ticket_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID REFERENCES tickets(id) ON DELETE CASCADE,
    author_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    is_private BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Tags for tickets
CREATE TABLE public.tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Junction table for tickets and tags
CREATE TABLE public.ticket_tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID REFERENCES tickets(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(ticket_id, tag_id),
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Create permissions table
CREATE TABLE public.permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    parent_id UUID REFERENCES public.permissions(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Create roles table
CREATE TABLE public.roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Create role_permissions junction table
CREATE TABLE public.role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID REFERENCES public.roles(id) ON DELETE CASCADE,
    permission_id UUID REFERENCES public.permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(role_id, permission_id),
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Junction table for team and tags
CREATE TABLE public.team_tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(team_id, tag_id),
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Create team_members junction table
CREATE TABLE IF NOT EXISTS team_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID NOT NULL REFERENCES teams(id),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    role TEXT NOT NULL CHECK (role IN ('lead', 'member')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT true,
    UNIQUE(team_id, user_id),
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Create team_schedules table
CREATE TABLE public.team_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID REFERENCES public.teams(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Create search query definition table
CREATE TABLE public.search_queries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    base_table TEXT NOT NULL,
    parent_table TEXT,
    parent_field TEXT,
    query_definition JSONB NOT NULL,
    column_definitions JSONB NOT NULL,
    related_tables JSONB,
    permissions_required TEXT[], -- Array of permission names required to use this query
    is_active BOOLEAN DEFAULT true,
    relationship_type TEXT CHECK (relationship_type IN ('one_to_many', 'many_to_many')),
    relationship_join_table TEXT,
    relationship_local_key TEXT,
    relationship_foreign_key TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Create role_permissions junction table
CREATE TABLE public.search_query_relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_search_query_id UUID REFERENCES public.search_queries(id) ON DELETE CASCADE,
    child_search_query_id UUID REFERENCES public.search_queries(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(parent_search_query_id, child_search_query_id),
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Create sidebar navigation table
CREATE TABLE public.sidebar_navigation (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    icon TEXT,
    parent_id UUID REFERENCES public.sidebar_navigation(id),
    search_query_id UUID REFERENCES public.search_queries(id),
    url TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    permissions_required TEXT[], -- Array of permission names required to view this link
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Create audit log table
CREATE TABLE public.audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    operation TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,
    new_data JSONB,
    changed_fields TEXT[],
    performed_by UUID REFERENCES auth.users(id),
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create comment templates table
CREATE TABLE public.comment_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    content TEXT NOT NULL,
    is_private BOOLEAN DEFAULT false,
    category TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id)
);

-- Replace both ticket_attachments and comment_attachments with a single attachments table
CREATE TABLE public.attachments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    storage_path TEXT NOT NULL,
    filename TEXT NOT NULL,
    size INTEGER NOT NULL,
    mime_type TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES auth.users(id)
);

-- Add indexes
CREATE INDEX idx_comment_templates_category ON comment_templates(category);
CREATE INDEX idx_comment_templates_is_active ON comment_templates(is_active);

COMMENT ON COLUMN search_queries.relationship_type IS 'Type of relationship (one_to_many or many_to_many)';
COMMENT ON COLUMN search_queries.relationship_join_table IS 'For many_to_many, specifies the junction table';
COMMENT ON COLUMN search_queries.relationship_local_key IS 'Column in parent table that links to related data';
COMMENT ON COLUMN search_queries.relationship_foreign_key IS 'Column in child/related table that links back to parent'; 

-- Create indexes for better query performance
CREATE INDEX idx_tickets_requester ON tickets(requester_id);
CREATE INDEX idx_tickets_assignee ON tickets(assignee_id);
CREATE INDEX idx_tickets_organization ON tickets(organization_id);

CREATE INDEX idx_ticket_comments_ticket ON ticket_comments(ticket_id);
CREATE INDEX idx_ticket_comments_author ON ticket_comments(author_id);

CREATE INDEX idx_user_knowledge_domain_user ON user_knowledge_domain(user_id);
CREATE INDEX idx_user_knowledge_domain_domain ON user_knowledge_domain(knowledge_domain_id);

CREATE INDEX idx_permissions_parent ON public.permissions(parent_id);

CREATE INDEX idx_role_permissions_role ON public.role_permissions(role_id);
CREATE INDEX idx_role_permissions_permission ON public.role_permissions(permission_id);

CREATE INDEX idx_team_members_team ON public.team_members(team_id);
CREATE INDEX idx_team_members_user ON public.team_members(user_id);

CREATE INDEX idx_team_schedules_team ON public.team_schedules(team_id);
CREATE INDEX idx_team_schedules_user ON public.team_schedules(user_id);

-- Create index on audit log for better query performance
CREATE INDEX idx_audit_log_table ON audit_log(table_name);
CREATE INDEX idx_audit_log_record ON audit_log(record_id);
CREATE INDEX idx_audit_log_performed_by ON audit_log(performed_by);
CREATE INDEX idx_audit_log_performed_at ON audit_log(performed_at);

-- Add indexes for better performance
CREATE INDEX idx_attachments_entity ON attachments(entity_type, entity_id);
CREATE INDEX idx_attachments_created_by ON attachments(created_by);
