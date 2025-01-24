-- Add foreign key constraints to tickets table
ALTER TABLE tickets
  ADD CONSTRAINT fk_tickets_requester 
    FOREIGN KEY (requester_id) 
    REFERENCES public.users(id)
    ON DELETE SET NULL,
  ADD CONSTRAINT fk_tickets_assignee
    FOREIGN KEY (assignee_id)
    REFERENCES public.users(id)
    ON DELETE SET NULL,
  ADD CONSTRAINT fk_tickets_teams
    FOREIGN KEY (team_id)
    REFERENCES public.teams(id)
    ON DELETE SET NULL,
  ADD CONSTRAINT fk_tickets_organization
    FOREIGN KEY (organization_id)
    REFERENCES organizations(id)
    ON DELETE SET NULL;

COMMENT ON CONSTRAINT fk_tickets_requester ON tickets IS 'created_by';
COMMENT ON CONSTRAINT fk_tickets_assignee ON tickets IS 'assigned_to';
COMMENT ON CONSTRAINT fk_tickets_organization ON tickets IS 'organization'; 
COMMENT ON CONSTRAINT fk_tickets_teams ON tickets IS 'team';

-- Add foreign key constraints to user_knowledge_domain table
ALTER TABLE user_knowledge_domain
  ADD CONSTRAINT fk_user_knowledge_domain_user
    FOREIGN KEY (user_id) 
    REFERENCES public.users(id)
    ON DELETE CASCADE;

-- Add constraint name for users.organization_id foreign key
ALTER TABLE public.users 
    DROP CONSTRAINT IF EXISTS users_organization_id_fkey,
    ADD CONSTRAINT fk_users_organization 
        FOREIGN KEY (organization_id) 
        REFERENCES organizations(id) 
        ON DELETE SET NULL;

-- Add foreign key for teams.organization_id
ALTER TABLE teams
ADD CONSTRAINT fk_teams_organization
FOREIGN KEY (organization_id)
REFERENCES organizations(id);

-- Add foreign keys for team_members
ALTER TABLE team_members
ADD CONSTRAINT fk_team_members_team
FOREIGN KEY (team_id)
REFERENCES teams(id);

ALTER TABLE team_members
ADD CONSTRAINT fk_team_members_user
FOREIGN KEY (user_id)
REFERENCES users(id);

-- Add foreign keys for team_tags
ALTER TABLE team_tags
ADD CONSTRAINT fk_team_tags_team
FOREIGN KEY (team_id)
REFERENCES teams(id)
ON DELETE CASCADE;

ALTER TABLE team_tags
ADD CONSTRAINT fk_team_tags_tag
FOREIGN KEY (tag_id)
REFERENCES tags(id)
ON DELETE CASCADE;

-- Add foreign keys for search_query_relationships
ALTER TABLE search_query_relationships
ADD CONSTRAINT fk_search_query_relationships_parent_search_query
FOREIGN KEY (parent_search_query_id)
REFERENCES search_queries(id)
ON DELETE CASCADE;

ALTER TABLE search_query_relationships
ADD CONSTRAINT fk_search_query_relationships_child_search_query
FOREIGN KEY (child_search_query_id)
REFERENCES search_queries(id)
ON DELETE CASCADE;

-- Add foreign keys for team_schedules
ALTER TABLE team_schedules
ADD CONSTRAINT fk_team_schedules_team
FOREIGN KEY (team_id)
REFERENCES teams(id)
ON DELETE CASCADE;

ALTER TABLE team_schedules
ADD CONSTRAINT fk_team_schedules_user
FOREIGN KEY (user_id)
REFERENCES users(id)
ON DELETE CASCADE;

-- Add foreign keys for role_permissions
ALTER TABLE role_permissions
ADD CONSTRAINT fk_role_permissions_role
FOREIGN KEY (role_id)
REFERENCES roles(id)
ON DELETE CASCADE;

ALTER TABLE role_permissions
ADD CONSTRAINT fk_role_permissions_permission
FOREIGN KEY (permission_id)
REFERENCES permissions(id)
ON DELETE CASCADE;

-- Add foreign keys for ticket_tags
ALTER TABLE ticket_tags
ADD CONSTRAINT fk_ticket_tags_ticket
FOREIGN KEY (ticket_id)
REFERENCES tickets(id)
ON DELETE CASCADE;

ALTER TABLE ticket_tags
ADD CONSTRAINT fk_ticket_tags_tag
FOREIGN KEY (tag_id)
REFERENCES tags(id)
ON DELETE CASCADE;

-- Add foreign keys for ticket_comments
ALTER TABLE ticket_comments
ADD CONSTRAINT fk_ticket_comments_ticket
FOREIGN KEY (ticket_id)
REFERENCES tickets(id)
ON DELETE CASCADE;

ALTER TABLE ticket_comments
ADD CONSTRAINT fk_ticket_comments_author
FOREIGN KEY (author_id)
REFERENCES users(id)
ON DELETE CASCADE;

-- Add foreign key constraints for sidebar_navigation self-reference
ALTER TABLE public.sidebar_navigation
    ADD CONSTRAINT fk_sidebar_navigation_parent 
    FOREIGN KEY (parent_id) 
    REFERENCES public.sidebar_navigation(id)
    ON DELETE SET NULL;

-- Add foreign key constraint for search query reference
ALTER TABLE public.sidebar_navigation
    ADD CONSTRAINT fk_sidebar_navigation_search_query
    FOREIGN KEY (search_query_id)
    REFERENCES public.search_queries(id)
    ON DELETE SET NULL;