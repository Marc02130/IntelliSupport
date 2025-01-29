-- Add to Admin navigation
INSERT INTO public.sidebar_navigation 
(id, name, description, icon, parent_id, search_query_id, url, sort_order, permissions_required, is_active) 
VALUES
-- Main navigation (no parent_id)
('11111111-1111-1111-1111-222222222222', 'Dashboard', 'Main dashboard', '📊', null, null, '/', 10, ARRAY['sidebar.dashboard'], true),
('22222222-2222-2222-2222-222222222222', 'Tickets', 'Ticket management', '🎫', null, null, null, 20, ARRAY['sidebar.tickets'], true),
('33333333-3333-3333-3333-222222222222', 'Reports', 'System reports', '📈', null, null, null, 30, ARRAY['sidebar.reports'], true),
('99999999-9999-9999-9999-222222222222', 'Admin', 'Administration', '⚙️', null, null, null, 40, ARRAY['sidebar.admin'], true),

-- Ticket sub-items
('44444444-4444-4444-4444-222222222222', 'My Submitted Tickets', 'View tickets submitted by me', '📝', '22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '/list', 10, ARRAY['tickets.view.own'], true),
('44444444-4444-4444-4444-222222222211', 'Customer Tickets', 'View tickets submitted by me', '📝', '22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb11', '/list', 10, ARRAY['tickets.view.own.customer'], true),
('55555555-5555-5555-5555-222222222222', 'Organization Tickets', 'View organization tickets', '🏢', '22222222-2222-2222-2222-222222222222', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '/list', 20, ARRAY['tickets.view.org'], true),
('55555555-5555-5555-5555-222222222211', 'Customer Org Tickets', 'View organization tickets', '🏢', '22222222-2222-2222-2222-222222222222', 'cccccccc-cccc-cccc-cccc-cccccccccc11', '/list', 20, ARRAY['tickets.view.org.customer'], true),
('66666666-6666-6666-6666-222222222222', 'All Tickets', 'View all tickets', '📋', '22222222-2222-2222-2222-222222222222', 'dddddddd-dddd-dddd-dddd-dddddddddddd', '/list', 30, ARRAY['tickets.view.all'], true),
('77777777-7777-7777-7777-222222222222', 'Submit Ticket', 'Create new ticket', '➕', '22222222-2222-2222-2222-222222222222', 'ffffffff-ffff-ffff-ffff-ffffffffffff', '/datarecord/add', 40, ARRAY['tickets.create'], true),
('88888888-8888-8888-8888-111111111111', 'My Assigned Tickets', 'View tickets assigned to me', '📋', '22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '/list', 15, ARRAY['tickets.view.assigned'], true),
('88888888-8888-8888-8888-222222222211', 'My Team''s Tickets', 'View tickets assigned to my teams', '📋', '22222222-2222-2222-2222-222222222222',  'aaaaaaaa-aaaa-aaaa-aaaa-bbbbbbbbbb11', '/list', 17, ARRAY['tickets.view'], true),

-- Add report items under Reports section
('bbbbbbbb-0000-4000-b000-000000000001', 'Tickets by Status', 'View ticket distribution by status', '📊', '33333333-3333-3333-3333-222222222222', 'aaaaaaaa-0000-4000-a000-000000000001', null, 10, ARRAY['reports.view'], true),

-- Admin sub-items
('aaaaaaaa-bbbb-cccc-dddd-222222222222', 'Knowledge Domains', 'Manage Knowledge Domains', '🧠', '99999999-9999-9999-9999-222222222222', 'aaaaaaaa-0000-4000-a000-000000000003', '/list', 15, ARRAY['admin.knowledge.manage'], true),
('aaaaaaaa-aaaa-aaaa-aaaa-222222222222', 'Users', 'User management', '👥', '99999999-9999-9999-9999-222222222222', 'aaaaaaaa-0000-4000-a000-000000000002', '/list', 10, ARRAY['admin.users.manage'], true),
('bbbbbbbb-bbbb-bbbb-bbbb-222222222222', 'Roles', 'Role management', '🔑', '99999999-9999-9999-9999-222222222222', 'aaaaaaaa-bbbb-cccc-dddd-111111111111', '/list', 20, ARRAY['admin.roles.manage'], true),
('cccccccc-cccc-cccc-cccc-222222222222', 'Permissions', 'Permission management', '🛡️', '99999999-9999-9999-9999-222222222222', 'aaaaaaaa-bbbb-cccc-dddd-222222222222', '/list', 30, ARRAY['admin.permissions.manage'], true),
('dddddddd-dddd-dddd-dddd-222222222222', 'Organizations', 'Organization management', '🏢', '99999999-9999-9999-9999-222222222222', 'aac8ccae-fded-4169-ac10-094761cc0d6d', '/list', 40, ARRAY['admin.organizations.manage'], true),
('ffffffff-ffff-ffff-ffff-222222222222', 'Search Queries', 'Search query management', '🔍', '99999999-9999-9999-9999-222222222222', 'ffffffff-eeee-dddd-cccc-bbbbbbbbbbbb', '/list', 60, ARRAY['admin.search_queries.manage'], true),
('11111111-2222-3333-4444-555555555555', 'Navigation', 'Navigation management', '🧭', '99999999-9999-9999-9999-222222222222', 'ffffffff-eeee-dddd-cccc-111111111111', '/list', 70, ARRAY['admin.navigation.manage'], true),
('eeeeeeee-eeee-eeee-eeee-333333333333', 'Teams', 'Team management', '👥', '99999999-9999-9999-9999-222222222222', 'eeeeeeee-eeee-eeee-eeee-111111111111', '/list', 70, ARRAY['admin.teams.manage'], true),
('cccccccc-1111-2222-3333-555555555555', 'Comment Templates', 'Manage comment templates', '📝', '99999999-9999-9999-9999-222222222222', 'cccccccc-1111-2222-3333-444444444444', '/list', 60, ARRAY['admin.templates.manage'], true);
