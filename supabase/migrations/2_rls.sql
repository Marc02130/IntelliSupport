-- Enable Row Level Security (RLS)
ALTER TABLE public.knowledge_domain ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_knowledge_domain ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;

-- Disable RLS for permissions and roles
ALTER TABLE public.search_queries DISABLE ROW LEVEL SECURITY;

-- ALTER TABLE public.permissions DISABLE ROW LEVEL SECURITY;

-- ALTER TABLE public.roles DISABLE ROW LEVEL SECURITY;

-- ALTER TABLE public.role_permissions DISABLE ROW LEVEL SECURITY;

-- Drop any existing policies
DROP POLICY IF EXISTS "Users can view permissions" ON public.permissions;

DROP POLICY IF EXISTS "Users can view roles" ON public.roles;

DROP POLICY IF EXISTS "Admins can manage role permissions" ON public.role_permissions;

-- Set up basic RLS policies
-- -------------------------- Auth Users --------------------------
-- First, ensure authenticated users can read the auth.users table (but only their own record)
CREATE POLICY "Users can read own user data" ON auth.users
    FOR SELECT
    USING (auth.uid() = id);

-- -------------------------- Users --------------------------
-- Enable Row Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Users can read their own data and admins can read all data
CREATE POLICY "Users can view own data and admins view all" ON public.users
    FOR SELECT
    USING (
        auth.uid() = id OR 
        (auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin'
    );

-- Admins can update user data
CREATE POLICY "Admins can update users" ON public.users
    FOR UPDATE
    USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin')
    WITH CHECK ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

-- Users can update their own data
CREATE POLICY "Users can update own data" ON public.users
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- -------------------------- Ticket Comments --------------------------
-- Enable Row Level Security (RLS)
ALTER TABLE public.ticket_comments ENABLE ROW LEVEL SECURITY;

-- Policy for viewing ticket comments
CREATE POLICY "Users can view ticket comments" ON ticket_comments
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM tickets t
            LEFT JOIN team_members tm ON tm.team_id = t.team_id
            WHERE t.id = ticket_comments.ticket_id
            AND (
                -- User is the requester
                t.requester_id = auth.uid()
                -- User is the assignee
                OR t.assignee_id = auth.uid()
                -- User is in the assigned team
                OR tm.user_id = auth.uid()
                -- User is from the same organization
                OR t.organization_id = (SELECT organization_id FROM users WHERE id = auth.uid())
                -- User is admin
                OR EXISTS (
                    SELECT 1 FROM users u 
                    WHERE u.id = auth.uid() 
                    AND u.role = 'admin'
                )
            )
        )
    );

-- Policy for inserting ticket comments
CREATE POLICY "Users can insert ticket comments" ON ticket_comments
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM tickets t
            LEFT JOIN team_members tm ON tm.team_id = t.team_id
            WHERE t.id = ticket_comments.ticket_id
            AND (
                -- User is the requester
                t.requester_id = auth.uid()
                -- User is the assignee
                OR t.assignee_id = auth.uid()
                -- User is in the assigned team
                OR tm.user_id = auth.uid()
                -- User is admin
                OR EXISTS (
                    SELECT 1 FROM users u 
                    WHERE u.id = auth.uid() 
                    AND u.role = 'admin'
                )
            )
        )
    );

-- Policy for updating ticket comments
CREATE POLICY "Users can update own ticket comments" ON ticket_comments
    FOR UPDATE TO authenticated
    USING (
        -- User is the comment author
        author_id = auth.uid()
        -- User is admin
        OR EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = auth.uid() 
            AND u.role = 'admin'
        )
    );

-- Policy for deleting ticket comments
CREATE POLICY "Users can delete own ticket comments" ON ticket_comments
    FOR DELETE TO authenticated
    USING (
        -- User is the comment author
        author_id = auth.uid()
        -- User is admin
        OR EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = auth.uid() 
            AND u.role = 'admin'
        )
    );

-- -------------------------- Organizations --------------------------
-- Drop any existing organization policies
DROP POLICY IF EXISTS "Users can view own organization" ON public.organizations;
DROP POLICY IF EXISTS "Admins can manage organizations" ON public.organizations;

-- Add RLS policies for organizations
CREATE POLICY "Users can view own organization" ON public.organizations
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE organization_id = organizations.id 
            AND id = auth.uid()
        ) OR
        (auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin'
    );

CREATE POLICY "Admins can manage organizations" ON public.organizations
    FOR ALL
    USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin')
    WITH CHECK ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

-- -------------------------- Search Queries --------------------------
-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can view search queries they have permission for" ON public.search_queries;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.search_queries;
DROP POLICY IF EXISTS "Enable update for admins" ON public.search_queries;

-- RLS Policy
CREATE POLICY "Users can view search queries they have permission for" ON public.search_queries
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 
            FROM public.role_permissions rp
            JOIN public.permissions p ON p.id = rp.permission_id
            JOIN auth.users au ON au.id = auth.uid()
            WHERE au.raw_user_meta_data->>'role' IN (
                SELECT name FROM public.roles r WHERE r.id = rp.role_id
            )
            AND p.name = ANY(permissions_required)
        )
    ); 

-- Update RLS policies to check is_active status
CREATE POLICY "Enable read access for authenticated users" 
ON public.search_queries
FOR SELECT 
TO authenticated
USING (
  is_active = true OR 
  EXISTS (
    SELECT 1 FROM auth.users 
    WHERE id = auth.uid() 
    AND raw_user_meta_data->>'role' = 'admin'
  )
);

-- Only admins can update search queries
CREATE POLICY "Enable update for admins" 
ON public.search_queries
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM auth.users 
    WHERE id = auth.uid() 
    AND raw_user_meta_data->>'role' = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM auth.users 
    WHERE id = auth.uid() 
    AND raw_user_meta_data->>'role' = 'admin'
  )
); 

-- -------------------------- Permissions --------------------------
-- Enable Row Level Security (RLS)
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;

-- Add RLS policies
-- Create RLS policies for permissions
CREATE POLICY "Enable read access for users and admins" ON public.permissions
    FOR SELECT
    TO authenticated
    USING (auth.role() = 'authenticated');

CREATE POLICY "Enable write access for admins only" ON public.permissions
    FOR ALL
    USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

CREATE POLICY "Admins can manage permissions" ON public.permissions
    FOR ALL USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

-- -------------------------- Roles --------------------------
-- Enable Row Level Security (RLS)
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

-- Add RLS policies
-- Create RLS policies for roles
CREATE POLICY "Enable read access for users and admins" ON public.roles
    FOR SELECT
    TO authenticated
    USING (auth.role() = 'authenticated');

CREATE POLICY "Enable write access for admins only" ON public.roles
    FOR ALL
    USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

CREATE POLICY "Admins can manage roles" ON public.roles
    FOR ALL USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

-- -------------------------- Sidebar Navigation --------------------------
-- Enable RLS
ALTER TABLE public.sidebar_navigation ENABLE ROW LEVEL SECURITY;

-- RLS Policy
DROP POLICY IF EXISTS "Users can view navigation items they have permission for" ON public.sidebar_navigation;

CREATE POLICY "Authenticated users can view navigation items" ON public.sidebar_navigation
    FOR SELECT
    USING (auth.role() = 'authenticated');

-- -------------------------- Tickets --------------------------
-- Enable RLS on tickets table
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;

-- Only authenticated users can view tickets they're involved with
CREATE POLICY "Users can view their tickets" ON public.tickets
    FOR SELECT
    USING (
        auth.uid() = requester_id OR
        auth.uid() = assignee_id OR
        -- Include tickets assigned to teams the user is a member of
        EXISTS (
            SELECT 1 FROM team_members tm
            WHERE tm.team_id = tickets.team_id
            AND tm.user_id = auth.uid()
            AND tm.is_active = true
        ) OR
        tickets.organization_id = (
            SELECT organization_id
            FROM public.users
            WHERE id = auth.uid()
        )
    );

-- Users can create tickets for themselves
CREATE POLICY "Users can create tickets" ON public.tickets
    FOR INSERT
    WITH CHECK (
        auth.uid() = requester_id
    );

-- Users can update tickets they're involved with
CREATE POLICY "Users can update their tickets" ON public.tickets
    FOR UPDATE
    USING (
        auth.uid() = requester_id OR
        auth.uid() = assignee_id OR
        -- Include tickets assigned to teams the user is a member of
        EXISTS (
            SELECT 1 FROM team_members tm
            WHERE tm.team_id = tickets.team_id
            AND tm.user_id = auth.uid()
            AND tm.is_active = true
        ) OR
        tickets.organization_id = (
            SELECT organization_id
            FROM public.users
            WHERE id = auth.uid()
        )
    );

-- Users can delete their own tickets
CREATE POLICY "Users can delete their tickets" ON public.tickets
    FOR DELETE
    USING (auth.uid() = requester_id);

-- Admin override for all operations
CREATE POLICY "Admins have full access to tickets" ON public.tickets
    USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

-- -------------------------- Teams --------------------------
-- Enable Row Level Security (RLS)
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage teams" ON teams
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

CREATE POLICY "Users can view teams in their organization" ON teams
    FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND organization_id = teams.organization_id
        )
    );

-- -------------------------- Team Tags --------------------------
ALTER TABLE team_tags ENABLE ROW LEVEL SECURITY;

-- Users can view team tags in their organization and admins can view all
CREATE POLICY "Users can view team tags in their org and admins view all" ON team_tags
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users u
            JOIN teams t ON t.organization_id = u.organization_id
            WHERE u.id = auth.uid() 
            AND t.id = team_tags.team_id
        ) OR 
        (auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin'
    );

-- Only admins can modify team tags
CREATE POLICY "Admins can manage team tags" ON team_tags
    FOR ALL
    USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin')
    WITH CHECK ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

-- Enable RLS for tags
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all authenticated users to read tags
CREATE POLICY "Allow authenticated users to read tags" ON public.tags
    FOR SELECT
    TO authenticated
    USING (true);

-- Allow admins to manage tags
CREATE POLICY "Allow admins to manage tags" ON public.tags
    FOR ALL
    USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin')
    WITH CHECK ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

-- Enable RLS for ticket_tags
ALTER TABLE public.ticket_tags ENABLE ROW LEVEL SECURITY;

-- Allow admins and agents to manage all ticket tags
CREATE POLICY "Admins and agents can manage ticket tags" ON public.ticket_tags
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = auth.uid()
            AND (u.role = 'admin' OR u.role = 'agent')
        )
    );

-- Allow users to manage tags on their own tickets
CREATE POLICY "Users can manage tags on their own tickets" ON public.ticket_tags
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM tickets t
            WHERE t.id = ticket_tags.ticket_id
            AND t.requester_id = auth.uid()
        )
    );

-- Allow users to view tags on their organization's tickets
CREATE POLICY "Users can view tags on organization tickets" ON public.ticket_tags
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM tickets t
            JOIN users u ON u.organization_id = t.organization_id
            WHERE t.id = ticket_tags.ticket_id
            AND u.id = auth.uid()
        )
    );

-- Allow team members to manage tags on their team's tickets
CREATE POLICY "Team members can manage ticket tags" ON public.ticket_tags
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM tickets t
            JOIN team_members tm ON tm.team_id = t.team_id
            WHERE t.id = ticket_tags.ticket_id
            AND tm.user_id = auth.uid()
            AND tm.is_active = true
        )
    );