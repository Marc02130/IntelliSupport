-- Enable access to schema
GRANT USAGE ON SCHEMA public TO authenticated;
-- -------------------------- Auth Users --------------------------
-- Drop ALL existing policies
DROP POLICY IF EXISTS "Users can read own user data" ON auth.users;

-- First, ensure authenticated users can read the auth.users table (but only their own record)
CREATE POLICY "Users can read own user data" ON auth.users
    FOR SELECT
    USING (auth.uid() = id);

-- -------------------------- Search Queries --------------------------
-- Drop ALL existing policies
DROP POLICY IF EXISTS "admin_full_access" ON public.search_queries;
DROP POLICY IF EXISTS "search_queries_read_policy" ON public.search_queries;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.search_queries TO authenticated;

-- enable RLS
ALTER TABLE "public"."search_queries" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "search_queries_read_policy" ON "public"."search_queries"
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "admin_full_access" ON "public"."search_queries"
FOR ALL
TO authenticated
USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin')
WITH CHECK ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

-- -------------------------- Search Queries Relationships ---------------
-- Drop ALL existing policies
DROP POLICY IF EXISTS "search_query_relationships_admin_full_access" ON public.search_query_relationships;
DROP POLICY IF EXISTS "search_query_relationships_read_policy" ON public.search_query_relationships;

-- enable RLS
ALTER TABLE "public"."search_query_relationships" ENABLE ROW LEVEL SECURITY;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.search_query_relationships TO authenticated;

CREATE POLICY "search_query_relationships_admin_full_access" 
ON public.search_query_relationships
AS PERMISSIVE FOR ALL
TO authenticated
USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin')
WITH CHECK ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

CREATE POLICY "search_query_relationships_read_policy" 
ON public.search_query_relationships
AS PERMISSIVE FOR SELECT
TO authenticated
USING (true);

-- -------------------------- Users --------------------------
-- Drop ALL existing policies
DROP POLICY IF EXISTS "Users can view own data and admins view all" ON public.users;
DROP POLICY IF EXISTS "Admins can update users" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
DROP POLICY IF EXISTS "Allow service role full access to users" ON public.users;

-- enable RLS
ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE ON public.users TO authenticated;
GRANT ALL ON public.users TO service_role;

-- Users can read their own data and admins can read all data
CREATE POLICY "Users can view own data and admins view all" ON public.users
    FOR SELECT
    TO authenticated
    USING (
        auth.uid() = id OR 
        (auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin'
    );

-- Admins can update all user data
CREATE POLICY "Admins can update users" ON public.users
    FOR UPDATE
    TO authenticated
    USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

-- Users can update their own data
CREATE POLICY "Users can update own data" ON public.users
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id);

-- Allow service role full access
CREATE POLICY "Allow service role full access to users"
    ON public.users
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- -------------------------- Organizations --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Users can view own organization" ON public.organizations;
DROP POLICY IF EXISTS "Admins can manage organizations" ON public.organizations;

-- enable RLS
ALTER TABLE "public"."organizations" ENABLE ROW LEVEL SECURITY;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.organizations TO authenticated;

-- Add RLS policies for organizations
CREATE POLICY "Users can view own organization" ON public.organizations
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE organization_id = organizations.id 
            AND id = auth.uid()
        ) OR
        ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin')
    );

CREATE POLICY "Admins can manage organizations" ON public.organizations
    FOR ALL
    USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin')
    WITH CHECK ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

-- -------------------------- Ticket Comments --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Users can update own ticket comments" ON public.ticket_comments;
DROP POLICY IF EXISTS "Users can delete own ticket comments" ON public.ticket_comments;
DROP POLICY IF EXISTS "Users can insert ticket comments" ON public.ticket_comments;
DROP POLICY IF EXISTS "Users can view ticket comments" ON public.ticket_comments;

-- enable RLS
ALTER TABLE "public"."ticket_comments" ENABLE ROW LEVEL SECURITY;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ticket_comments TO authenticated;

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

-- -------------------------- Permissions --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Enable read access for users and admins" ON public.permissions;
DROP POLICY IF EXISTS "Enable write access for admins only" ON public.permissions;
DROP POLICY IF EXISTS "Admins can manage permissions" ON public.permissions;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.permissions TO authenticated;

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
-- Drop any existing policies
DROP POLICY IF EXISTS "Enable read access for users and admins" ON public.roles;
DROP POLICY IF EXISTS "Enable write access for admins only" ON public.roles;
DROP POLICY IF EXISTS "Admins can manage roles" ON public.roles;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.roles TO authenticated;

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
-- Drop any existing policies
DROP POLICY IF EXISTS "Authenticated users can view navigation items" ON public.sidebar_navigation;
DROP POLICY IF EXISTS "Admins have full access to navigation items" ON public.sidebar_navigation;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sidebar_navigation TO authenticated;

-- Enable RLS
ALTER TABLE public.sidebar_navigation ENABLE ROW LEVEL SECURITY;

-- RLS Policy
CREATE POLICY "Authenticated users can view navigation items" ON public.sidebar_navigation
    FOR SELECT
    USING (auth.role() = 'authenticated');

-- Admin override for all operations
CREATE POLICY "Admins have full access to navigation items" ON public.sidebar_navigation
    USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

-- -------------------------- Tickets --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Users can view their tickets" ON public.tickets;
DROP POLICY IF EXISTS "Users can create tickets" ON public.tickets;
DROP POLICY IF EXISTS "Users can update their tickets" ON public.tickets;
DROP POLICY IF EXISTS "Users can delete their tickets" ON public.tickets;
DROP POLICY IF EXISTS "Admins have full access to tickets" ON public.tickets;
DROP POLICY IF EXISTS "Users can view their organization's tickets" ON public.tickets;
DROP POLICY IF EXISTS "Allow trigger to set organization during insert" ON public.tickets;
DROP POLICY IF EXISTS "Allow service role full access to tickets" ON public.tickets;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tickets TO authenticated;
GRANT ALL ON public.tickets TO service_role;

-- Enable RLS on tickets table
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;

-- Allow trigger to set organization during insert
CREATE POLICY "Allow trigger to set organization during insert" ON public.tickets
    FOR INSERT
    WITH CHECK (true);

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

-- Allow full access to service role
CREATE POLICY "Allow service role full access to tickets"
    ON public.tickets
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- -------------------------- Teams --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Admins can manage teams" ON public.teams;
DROP POLICY IF EXISTS "Users can view teams in their organization" ON public.teams;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.teams TO authenticated;

-- Enable Row Level Security (RLS)
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage teams" ON public.teams
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

CREATE POLICY "Users can view teams in their organization" ON public.teams
    FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND organization_id = public.teams.organization_id
        )
    );

-- -------------------------- Team Tags --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Users can view team tags in their org and admins view all" ON public.team_tags;
DROP POLICY IF EXISTS "Admins can manage team tags" ON public.team_tags;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.team_tags TO authenticated;

-- Enable Row Level Security (RLS)
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

-- -------------------------- Tags --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Allow authenticated users to read tags" ON public.tags;
DROP POLICY IF EXISTS "Allow admins to manage tags" ON public.tags;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tags TO authenticated;

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

-- -------------------------- Ticket Tags --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Admins and agents can manage ticket tags" ON public.ticket_tags;
DROP POLICY IF EXISTS "Users can manage tags on their own tickets" ON public.ticket_tags;
DROP POLICY IF EXISTS "Users can view tags on organization tickets" ON public.ticket_tags;
DROP POLICY IF EXISTS "Team members can manage ticket tags" ON public.ticket_tags;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ticket_tags TO authenticated;

-- Enable RLS
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

-- -------------------------- Comment Templates --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Users can view active comment templates" ON public.comment_templates;
DROP POLICY IF EXISTS "Admins can manage comment templates" ON public.comment_templates;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.comment_templates TO authenticated;

-- Enable RLS
ALTER TABLE public.comment_templates ENABLE ROW LEVEL SECURITY;

-- Policy for viewing comment templates
CREATE POLICY "Users can view active comment templates" ON comment_templates
    FOR SELECT TO authenticated
    USING (is_active = true);

-- Policy for managing comment templates (admin only)
CREATE POLICY "Admins can manage comment templates" ON comment_templates
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = auth.uid()
            AND u.role = 'admin'
        )
    );

-- -------------------------- Team Members --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Admins and Team Leads can manage team members" ON public.team_members;
DROP POLICY IF EXISTS "Users can view team members" ON public.team_members;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.team_members TO authenticated;

-- Enable RLS
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

-- Admins and Team Leads can manage team members
CREATE POLICY "Admins and Team Leads can manage team members" ON public.team_members
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users u WHERE u.id = auth.uid() AND (u.role = 'admin' OR u.role = 'team_lead')
        )
    );

-- Users can view team members in their organization
CREATE POLICY "Users can view team members" ON public.team_members
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.organization_id = team_members.team_id
        )
    );  

-- -------------------------- Audit Log  --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Authenticated can insert audit log" ON public.audit_log;
DROP POLICY IF EXISTS "Authenticated can update audit log" ON public.audit_log;
DROP POLICY IF EXISTS "Authenticated can view audit log" ON public.audit_log;
DROP POLICY IF EXISTS "Allow trigger to insert audit log" ON public.audit_log;
DROP POLICY IF EXISTS "Allow service role full access to audit_log" ON public.audit_log;

-- Grant basic table permissions
GRANT ALL ON public.audit_log TO authenticated, service_role;

-- Enable RLS
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to insert audit logs
CREATE POLICY "Authenticated can insert audit log" ON public.audit_log
    FOR INSERT TO authenticated
    WITH CHECK (true);

-- Allow trigger to insert audit logs
CREATE POLICY "Allow trigger to insert audit log" ON public.audit_log
    FOR INSERT
    WITH CHECK (true);

-- Allow all authenticated users to update audit logs
CREATE POLICY "Authenticated can update audit log" ON public.audit_log
    FOR UPDATE TO authenticated;

-- Allow all authenticated users to view audit logs
CREATE POLICY "Authenticated can view audit log" ON public.audit_log
    FOR SELECT TO authenticated;

-- Allow service role full access to audit_log
CREATE POLICY "Allow service role full access to audit_log"
    ON public.audit_log
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- -------------------------- Team Schedules  --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Admins and Team Leads can manage team schedules" ON public.team_schedules;
DROP POLICY IF EXISTS "Users can view team schedules" ON public.team_schedules;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.team_schedules TO authenticated;

-- Enable RLS
ALTER TABLE public.team_schedules ENABLE ROW LEVEL SECURITY;

-- Admins and Team Leads can manage team schedules
CREATE POLICY "Admins and Team Leads can manage team schedules" ON public.team_schedules
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = auth.uid() 
            AND (u.role = 'admin' OR u.role = 'team_lead')
        )
    );

-- Users can view schedules for teams in their organization
CREATE POLICY "Users can view team schedules" ON public.team_schedules
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 
            FROM users u
            JOIN teams t ON t.organization_id = u.organization_id
            WHERE u.id = auth.uid() 
            AND t.id = team_schedules.team_id
        )
    );

-- -------------------------- Knowledge Domain --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Authenticated users can view knowledge domains" ON public.knowledge_domain;
DROP POLICY IF EXISTS "Admins can manage knowledge domains" ON public.knowledge_domain;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.knowledge_domain TO authenticated;

-- Enable RLS
ALTER TABLE public.knowledge_domain ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to view knowledge domains
CREATE POLICY "Authenticated users can view knowledge domains" ON public.knowledge_domain
    FOR SELECT
    TO authenticated
    USING (true);

-- Allow admins to manage knowledge domains
CREATE POLICY "Admins can manage knowledge domains" ON public.knowledge_domain
    FOR ALL
    USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin')
    WITH CHECK ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

-- -------------------------- User Knowledge Domain --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Authenticated users can view user knowledge domains" ON public.user_knowledge_domain;
DROP POLICY IF EXISTS "Admins can manage user knowledge domains" ON public.user_knowledge_domain;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_knowledge_domain TO authenticated;

-- Enable RLS
ALTER TABLE public.user_knowledge_domain ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to view user knowledge domains
CREATE POLICY "Authenticated users can view user knowledge domains" ON public.user_knowledge_domain
    FOR SELECT
    TO authenticated
    USING (true);

-- Allow admins to manage user knowledge domains
CREATE POLICY "Admins can manage user knowledge domains" ON public.user_knowledge_domain
    FOR ALL
    USING ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin')
    WITH CHECK ((auth.jwt()->>'user_metadata')::jsonb->>'role' = 'admin');

-- -------------------------- Attachments --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Users can view attachments for accessible entities" ON public.attachments;
DROP POLICY IF EXISTS "Users can add attachments to accessible entities" ON public.attachments;
DROP POLICY IF EXISTS "Users can delete their own attachments" ON public.attachments;

-- Grant basic table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.attachments TO authenticated;

-- Enable RLS
ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;

-- Allow users to view attachments for entities they can access
CREATE POLICY "Users can view attachments for accessible entities" ON public.attachments
    FOR SELECT
    USING (
        CASE entity_type
        WHEN 'ticket' THEN
            EXISTS (
                SELECT 1 FROM tickets t
                WHERE t.id = entity_id
                AND (
                    -- Ticket requester
                    t.requester_id = auth.uid()
                    -- Ticket assignee
                    OR t.assignee_id = auth.uid()
                    -- Same organization
                    OR t.organization_id IN (SELECT organization_id FROM users WHERE id = auth.uid())
                    -- Admin or agent
                    OR EXISTS (
                        SELECT 1 FROM users 
                        WHERE id = auth.uid() 
                        AND role IN ('admin', 'agent')
                    )
                )
            )
        WHEN 'comment' THEN
            EXISTS (
                SELECT 1 FROM ticket_comments tc
                JOIN tickets t ON t.id = tc.ticket_id
                WHERE tc.id = entity_id
                AND (
                    -- Ticket requester
                    t.requester_id = auth.uid()
                    -- Ticket assignee
                    OR t.assignee_id = auth.uid()
                    -- Same organization
                    OR t.organization_id IN (SELECT organization_id FROM users WHERE id = auth.uid())
                    -- Admin or agent
                    OR EXISTS (
                        SELECT 1 FROM users 
                        WHERE id = auth.uid() 
                        AND role IN ('admin', 'agent')
                    )
                )
            )
        END
    );

-- Allow users to add attachments to entities they can access
CREATE POLICY "Users can add attachments to accessible entities" ON public.attachments
    FOR INSERT
    WITH CHECK (
        CASE entity_type
        WHEN 'ticket' THEN
            EXISTS (
                SELECT 1 FROM tickets t
                WHERE t.id = entity_id
                AND (
                    -- Ticket requester
                    t.requester_id = auth.uid()
                    -- Ticket assignee
                    OR t.assignee_id = auth.uid()
                    -- Same organization
                    OR t.organization_id IN (SELECT organization_id FROM users WHERE id = auth.uid())
                    -- Admin or agent
                    OR EXISTS (
                        SELECT 1 FROM users 
                        WHERE id = auth.uid() 
                        AND role IN ('admin', 'agent')
                    )
                )
            )
        WHEN 'comment' THEN
            EXISTS (
                SELECT 1 FROM ticket_comments tc
                JOIN tickets t ON t.id = tc.ticket_id
                WHERE tc.id = entity_id
                AND (
                    -- Comment author
                    tc.author_id = auth.uid()
                    -- Ticket assignee
                    OR t.assignee_id = auth.uid()
                    -- Same organization
                    OR t.organization_id IN (SELECT organization_id FROM users WHERE id = auth.uid())
                    -- Admin or agent
                    OR EXISTS (
                        SELECT 1 FROM users 
                        WHERE id = auth.uid() 
                        AND role IN ('admin', 'agent')
                    )
                )
            )
        END
    );

-- Allow users to delete their own attachments
CREATE POLICY "Users can delete their own attachments" ON public.attachments
    FOR DELETE
    USING (created_by = auth.uid());

-- -------------------------- Storage Policies --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Authenticated users can upload attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users can view attachments they have access to" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own attachments" ON storage.objects;

-- Policy for uploading files
CREATE POLICY "Authenticated users can upload attachments"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'attachments' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy for viewing files
CREATE POLICY "Users can view attachments they have access to"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'attachments' AND
    EXISTS (
        SELECT 1 FROM attachments a
        WHERE a.storage_path = storage.objects.name
        AND (
            CASE a.entity_type
            WHEN 'ticket' THEN
                EXISTS (
                    SELECT 1 FROM tickets t
                    WHERE t.id = a.entity_id
                    AND (
                        t.requester_id = auth.uid()
                        OR t.assignee_id = auth.uid()
                        OR t.organization_id IN (SELECT organization_id FROM users WHERE id = auth.uid())
                        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'agent'))
                    )
                )
            WHEN 'comment' THEN
                EXISTS (
                    SELECT 1 FROM ticket_comments tc
                    JOIN tickets t ON t.id = tc.ticket_id
                    WHERE tc.id = a.entity_id
                    AND (
                        t.requester_id = auth.uid()
                        OR t.assignee_id = auth.uid()
                        OR t.organization_id IN (SELECT organization_id FROM users WHERE id = auth.uid())
                        OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'agent'))
                    )
                )
            END
        )
    )
);

-- Policy for deleting files
CREATE POLICY "Users can delete their own attachments"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'attachments' AND
    EXISTS (
        SELECT 1 FROM attachments a
        WHERE a.storage_path = storage.objects.name
        AND a.created_by = auth.uid()
    )
);

-- -------------------------- Ticket Routing History --------------------------
-- Drop any existing policies
DROP POLICY IF EXISTS "Users can view routing history for accessible tickets" ON public.ticket_routing_history;
DROP POLICY IF EXISTS "Only system/admin can manage routing history" ON public.ticket_routing_history;
DROP POLICY IF EXISTS "Allow service role full access to routing history" ON public.ticket_routing_history;

-- Add RLS policies
ALTER TABLE public.ticket_routing_history ENABLE ROW LEVEL SECURITY;

-- Grant permissions to authenticated users and service role
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ticket_routing_history TO authenticated, service_role;

-- Allow full access to service role
CREATE POLICY "Allow service role full access to routing history"
    ON public.ticket_routing_history
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Routing history policies for authenticated users
CREATE POLICY "Users can view routing history for accessible tickets" 
    ON ticket_routing_history
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM tickets t
            WHERE t.id = ticket_id
            AND (
                t.requester_id = auth.uid()
                OR t.assignee_id = auth.uid()
                OR t.organization_id IN (SELECT organization_id FROM users WHERE id = auth.uid())
                OR EXISTS (
                    SELECT 1 FROM users 
                    WHERE id = auth.uid() 
                    AND role IN ('admin', 'agent')
                )
            )
        )
    );

-- Only system/admin can insert routing history
CREATE POLICY "Only system/admin can manage routing history" ON ticket_routing_history
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE id = auth.uid()
            AND role = 'admin'
        )
    ); 