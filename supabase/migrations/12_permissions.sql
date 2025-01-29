
-- Seed initial permissions
INSERT INTO public.permissions (id, name, description, parent_id) VALUES
-- Admin Access
('33333333-4444-5555-6666-777777777777', 'admin.access', 'Access to admin', null),

-- UI Permissions
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'dashboard.view', 'Access to view dashboard', null),

-- Sidebar Permissions
('11111111-1111-1111-1111-111111111111', 'sidebar.view', 'Access to view sidebar', null),
('22222222-2222-2222-2222-222222222222', 'sidebar.dashboard', 'Access to dashboard section', '11111111-1111-1111-1111-111111111111'),
('33333333-3333-3333-3333-333333333333', 'sidebar.tickets', 'Access to tickets section', '11111111-1111-1111-1111-111111111111'),
('44444444-4444-4444-4444-444444444444', 'sidebar.reports', 'Access to reports section', '11111111-1111-1111-1111-111111111111'),
('55555555-5555-5555-5555-555555555555', 'sidebar.admin', 'Access to admin section', '11111111-1111-1111-1111-111111111111'),
('55555555-5555-5555-5555-555555555566', 'sidebar.customer', 'Access to customer section', '11111111-1111-1111-1111-111111111111'),

-- Admin Permissions
('66666666-6666-6666-6666-666666666666', 'admin.users.manage', 'Manage users', '55555555-5555-5555-5555-555555555555'),
('77777777-7777-7777-7777-777777777777', 'admin.roles.manage', 'Manage roles', '55555555-5555-5555-5555-555555555555'),
('88888888-8888-8888-8888-888888888888', 'admin.permissions.manage', 'Manage permissions', '55555555-5555-5555-5555-555555555555'),
('99999999-9999-9999-9999-999999999999', 'admin.organizations.manage', 'Manage organizations', '55555555-5555-5555-5555-555555555555'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin.teams.manage', 'Manage teams', '55555555-5555-5555-5555-555555555555'),
('44444444-5555-6666-7777-888888888888', 'admin.navigation.manage', 'Manage navigation items', '33333333-4444-5555-6666-777777777777'),
('55555555-6666-7777-8888-999999999999', 'admin.search_queries.manage', 'Manage search queries', '33333333-4444-5555-6666-777777777777'),
('cccccccc-1111-2222-3333-666666666666', 'admin.templates.manage', 'Manage comment templates', null),
('11111111-1111-cccc-1111-111111111111', 'admin.knowledge.manage', 'Can view and manage knowledge domains', null),

-- Team Permissions
('11111111-2222-3333-4444-555555555551', 'team.view', 'Access to team section', null),
('11111111-2222-3333-4444-555555555552', 'team.view.own', 'View own team', null),
('11111111-2222-3333-4444-555555555553', 'team.view.org', 'View organization teams', null),

-- Reports Permissions
('11111111-2222-3333-4444-555555555555', 'reports.view', 'Access to reports section', null),

-- Ticket Permissions
('22222222-3333-4444-5555-666666666666', 'tickets.create', 'Ability to create tickets', null),
('ffffffff-ffff-ffff-ffff-ffffffffffff', 'tickets.view', 'Access to tickets section', null),
('ffffffff-ffff-ffff-ffff-fffffffffff2', 'tickets.view,internal', 'Access to tickets section', null),
('ffffffff-ffff-ffff-ffff-fffffffffff1', 'tickets.view.customer', 'Access to tickets section', null),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'tickets.view.own', 'View own tickets', null),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'tickets.view.org', 'View organization tickets', null),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'tickets.view.own.customer', 'View own tickets', null),
('cccccccc-cccc-cccc-cccc-ccccccccccc1', 'tickets.view.org.customer', 'View organization tickets', null),
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'tickets.view.all', 'View all tickets', null),
('66666666-7777-8888-9999-aaaaaaaaaaaa', 'tickets.view.assigned', 'View tickets assigned to me', 'ffffffff-ffff-ffff-ffff-ffffffffffff')

ON CONFLICT (name) DO NOTHING;

-- Seed initial roles
INSERT INTO public.roles (id, name, description) VALUES
('11111111-1111-1111-1111-111111111112', 'admin', 'Administrator role with full access'),
('22222222-2222-2222-2222-222222222223', 'agent', 'Support agent role'),
('33333333-3333-3333-3333-333333333334', 'customer', 'Customer role');

-- Admin role permissions
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT 
    '11111111-1111-1111-1111-111111111112',
    id
FROM public.permissions;

-- Agent role permissions
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT 
    '22222222-2222-2222-2222-222222222223',
    id
FROM public.permissions 
WHERE name IN (
    'dashboard.view',
    'tickets.view',
    'tickets.view.internal',
    'tickets.view.own',
    'tickets.view.all',
    'tickets.view.assigned',
    'tickets.create',
    'sidebar.view',
    'reports.view',
    'sidebar.reports',
    'sidebar.tickets',
    'sidebar.dashboard'
);

-- Customer role permissions
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT 
    '33333333-3333-3333-3333-333333333334',
    id
FROM public.permissions 
WHERE name IN (
    'dashboard.view',
    'tickets.view.customer',
    'tickets.view.own.customer',
    'tickets.view.org.customer',
    'tickets.create',
    'reports.view',
    'sidebar.view',
    'sidebar.reports',
    'sidebar.tickets',
    'sidebar.dashboard'
);

-- Assign user roles
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT 
    r.id as role_id,
    p.id as permission_id
FROM auth.users au
JOIN public.roles r ON r.name = au.raw_user_meta_data->>'role'
CROSS JOIN public.permissions p
WHERE p.name IN (
    CASE 
        WHEN au.raw_user_meta_data->>'role' = 'admin' THEN 'admin.access'
        WHEN au.raw_user_meta_data->>'role' = 'agent' THEN 'tickets.view'
        ELSE 'tickets.view.own'
    END
)
ON CONFLICT (role_id, permission_id) DO NOTHING;
