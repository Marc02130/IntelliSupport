-- Seed auth.users table with metadata
INSERT INTO auth.users (
    raw_app_meta_data,
    last_sign_in_at,
    instance_id,
    confirmation_token,
    email_change,
    email_change_token_current,
    email_change_confirm_status,
    email_change_token_new,
    recovery_token,
    id, 
    email, 
    encrypted_password,
    confirmation_sent_at,
    email_confirmed_at, 
    created_at, 
    updated_at, 
    aud, 
    role,
    raw_user_meta_data
)
VALUES 
    -- Marc Breneiser
    (
        '{"provider": "email","providers": ["email"]}',
        NOW(),
        '00000000-0000-0000-0000-000000000000',
        '',
        '',
        '',
        0,
        '',
        '',
        gen_random_uuid(),
        'marc.breneiser@gmail.com',
        crypt('Password1@#', gen_salt('bf')),
        NOW(),
        NOW(),
        NOW(),
        NOW(),
        'authenticated',
        'authenticated',
        jsonb_build_object(
            'full_name', 'Marc AdminOne',
            'role', 'admin'
        )
    ),
    -- Marc Gauntlet
    (
        '{"provider": "email","providers": ["email"]}',
        NOW(),
        '00000000-0000-0000-0000-000000000000',
        '',
        '',
        '',
        0,
        '',
        '',
        gen_random_uuid(),
        'marc.breneiser@gauntletai.com',
        crypt('Password1@#', gen_salt('bf')),
        NOW(),
        NOW(),
        NOW(),
        NOW(),
        'authenticated',
        'authenticated',
        jsonb_build_object(
            'full_name', 'Marc AdminTwo',
            'role', 'admin'
        )
    ),
    -- Agent One
    (
        '{"provider": "email","providers": ["email"]}',
        NOW(),
        '00000000-0000-0000-0000-000000000000',
        '',
        '',
        '',
        0,
        '',
        '',
        gen_random_uuid(),
        'driver-revise-snub@duck.com',
        crypt('Password1@#', gen_salt('bf')),
        NOW(),
        NOW(),
        NOW(),
        NOW(),
        'authenticated',
        'authenticated',
        jsonb_build_object(
            'full_name', 'Marc AgentOne',
            'role', 'agent'
        )
    ),
    -- Agent Two
    (
        '{"provider": "email","providers": ["email"]}',
        NOW(),
        '00000000-0000-0000-0000-000000000000',
        '',
        '',
        '',
        0,
        '',
        '',
        gen_random_uuid(),
        'junkie-quail-saint@duck.com',
        crypt('Password1@#', gen_salt('bf')),
        NOW(),
        NOW(),
        NOW(),
        NOW(),
        'authenticated',
        'authenticated',
        jsonb_build_object(
            'full_name', 'Marc AgentTwo',
            'role', 'agent'
        )
    ),
    -- User One
    (
        '{"provider": "email","providers": ["email"]}',
        NOW(),
        '00000000-0000-0000-0000-000000000000',
        '',
        '',
        '',
        0,
        '',
        '',
        gen_random_uuid(),
        'arise-duct-snore@duck.com',
        crypt('Password1@#', gen_salt('bf')),
        NOW(),
        NOW(),
        NOW(),
        NOW(),
        'authenticated',
        'authenticated',
        jsonb_build_object(
            'full_name', 'Marc UserOne',
            'role', 'customer'
        )
    ),
    -- User Two
    (
        '{"provider": "email","providers": ["email"]}',
        NOW(),
        '00000000-0000-0000-0000-000000000000',
        '',
        '',
        '',
        0,
        '',
        '',
        gen_random_uuid(),
        'spoiling-poem-cozy@duck.com',
        crypt('Password1@#', gen_salt('bf')),
        NOW(),
        NOW(),
        NOW(),
        NOW(),
        'authenticated',
        'authenticated',
        jsonb_build_object(
            'full_name', 'Marc UserTwo',
            'role', 'customer'
        )
    );

-- Create public.users entries for all auth.users
INSERT INTO public.users (id, first_name, last_name, role, email)
SELECT 
    au.id,
    split_part(au.raw_user_meta_data->>'full_name', ' ', 1) as first_name,
    split_part(au.raw_user_meta_data->>'full_name', ' ', 2) as last_name,
    au.raw_user_meta_data->>'role' as role,
    au.email
FROM auth.users au
ON CONFLICT (id) DO UPDATE 
SET 
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    role = EXCLUDED.role,
    email = EXCLUDED.email;

-- Seed Organizations
INSERT INTO public.organizations (id, name, domain, description)
VALUES 
    ('e46d9208-d1c7-458c-856a-78f2c2bbe896', 'Acme Corp', 'acme.com', 'Acme Corp is a company that makes widgets'),
    ('d70cb812-c796-4193-8db5-b3de781a3fb9', 'TechStart Inc', 'techstart.io', 'TechStart Inc is a company that makes widgets'),
    ('3c29c34e-1110-4959-b499-b5f01ce55226', 'DevCorp Labs', 'devcorp.dev', 'DevCorp Labs is a company that makes widgets'),
    ('3c29c34e-1110-4959-b499-b5f01ce55227', 'New User', '', 'New User'),
    ('0ef7b9c5-f2cd-4dd4-9f33-ff71603fec7f', 'IntelliSupport', 'intellisupport.com', 'The world''s leading CRM solution for widget makers');

-- Assign Organizations to Users
UPDATE public.users 
SET organization_id = '0ef7b9c5-f2cd-4dd4-9f33-ff71603fec7f'
WHERE role = 'admin' OR role = 'agent';

UPDATE public.users 
SET organization_id = '3c29c34e-1110-4959-b499-b5f01ce55226'
WHERE id IN (
    SELECT id 
    FROM public.users 
    WHERE role = 'customer' 
    ORDER BY id 
    LIMIT 1
);

UPDATE public.users 
SET organization_id = 'e46d9208-d1c7-458c-856a-78f2c2bbe896'
WHERE role = 'customer' AND organization_id IS NULL;

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

-- Seed Knowledge Domains
INSERT INTO public.knowledge_domain (name, description)
VALUES 
    ('Technical Support', 'General technical support and troubleshooting'),
    ('Billing', 'Billing and subscription related issues'),
    ('Product Features', 'Product functionality and feature inquiries'),
    ('Security', 'Security-related concerns and configurations'),
    ('API Integration', 'API usage and integration support');

-- Assign Knowledge Domains to Agents
INSERT INTO public.user_knowledge_domain (user_id, knowledge_domain_id, expertise, years_experience)
SELECT 
    au.id,
    kd.id,
    CASE 
        WHEN pu.last_name = 'AgentOne' THEN 'expert'
        ELSE 'intermediate'
    END as expertise,
    3
FROM auth.users au
JOIN public.users pu ON pu.id = au.id
CROSS JOIN public.knowledge_domain kd
WHERE pu.role = 'agent';

-- Seed Tags (if not exists)
INSERT INTO public.tags (id, name)
VALUES 
    (gen_random_uuid(), 'urgent'),
    (gen_random_uuid(), 'bug'),
    (gen_random_uuid(), 'feature-request'),
    (gen_random_uuid(), 'documentation'),
    (gen_random_uuid(), 'billing'),
    (gen_random_uuid(), 'security')
ON CONFLICT (name) DO NOTHING;

-- Seed Sample Tickets
INSERT INTO public.tickets (subject, description, status, priority, requester_id, assignee_id, organization_id)
SELECT 
    'Cannot access dashboard' as subject,
    'Getting 403 error when trying to access the main dashboard' as description,
    'open' as status,
    'high' as priority,
    (SELECT au.id FROM auth.users au JOIN public.users pu ON pu.id = au.id WHERE pu.role = 'customer' LIMIT 1) as requester_id,
    (SELECT au.id FROM auth.users au JOIN public.users pu ON pu.id = au.id WHERE pu.role = 'agent' LIMIT 1) as assignee_id,
    (SELECT id FROM public.organizations LIMIT 1) as organization_id;

INSERT INTO public.tickets (subject, description, status, priority, requester_id, assignee_id, organization_id)
SELECT 
    'Billing cycle question' as subject,
    'Need clarification about the billing cycle start date' as description,
    'pending' as status,
    'medium' as priority,
    (SELECT au.id FROM auth.users au JOIN public.users pu ON pu.id = au.id WHERE pu.role = 'customer' ORDER BY id DESC LIMIT 1) as requester_id,
    (SELECT au.id FROM auth.users au JOIN public.users pu ON pu.id = au.id WHERE pu.role = 'agent' ORDER BY id DESC LIMIT 1) as assignee_id,
    (SELECT id FROM public.organizations ORDER BY id DESC LIMIT 1) as organization_id;

-- Add Tags to Tickets
INSERT INTO public.ticket_tags (ticket_id, tag_id)
SELECT 
    t.id as ticket_id,
    tag.id as tag_id
FROM public.tickets t
CROSS JOIN public.tags tag
WHERE tag.name IN ('urgent', 'bug')
AND t.subject LIKE '%dashboard%';

-- Add Sample Comments
INSERT INTO public.ticket_comments (ticket_id, author_id, content, is_private)
SELECT 
    t.id as ticket_id,
    (SELECT id FROM auth.users WHERE role = 'agent' LIMIT 1) as author_id,
    'I am looking into this issue. Could you please provide your browser version?' as content,
    false as is_private
FROM public.tickets t
WHERE t.subject LIKE '%dashboard%';

INSERT INTO public.ticket_comments (ticket_id, author_id, content, is_private)
SELECT 
    t.id as ticket_id,
    (SELECT id FROM auth.users WHERE role = 'customer' LIMIT 1) as author_id,
    'I am using Chrome version 121.0.6167.185' as content,
    false as is_private
FROM public.tickets t
WHERE t.subject LIKE '%dashboard%';

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

-- Admin Permissions
('66666666-6666-6666-6666-666666666666', 'admin.users.manage', 'Manage users', '55555555-5555-5555-5555-555555555555'),
('77777777-7777-7777-7777-777777777777', 'admin.roles.manage', 'Manage roles', '55555555-5555-5555-5555-555555555555'),
('88888888-8888-8888-8888-888888888888', 'admin.permissions.manage', 'Manage permissions', '55555555-5555-5555-5555-555555555555'),
('99999999-9999-9999-9999-999999999999', 'admin.organizations.manage', 'Manage organizations', '55555555-5555-5555-5555-555555555555'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin.teams.manage', 'Manage teams', '55555555-5555-5555-5555-555555555555'),
('44444444-5555-6666-7777-888888888888', 'admin.navigation.manage', 'Manage navigation items', '33333333-4444-5555-6666-777777777777'),
('55555555-6666-7777-8888-999999999999', 'admin.search_queries.manage', 'Manage search queries', '33333333-4444-5555-6666-777777777777'),

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

-- Create initial teams
INSERT INTO public.teams (id, name, description) VALUES
('11111111-1111-1111-1111-111111111113', 'Technical Support', 'Primary technical support team'),
('22222222-2222-2222-2222-222222222224', 'Billing Support', 'Billing and account support team');

-- Assign agents to teams
INSERT INTO public.team_members (team_id, user_id, role)
SELECT 
    '11111111-1111-1111-1111-111111111113',
    id,
    CASE 
        WHEN email LIKE '%AgentOne%' THEN 'lead'
        ELSE 'member'
    END
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'agent';

-- Add team schedules
INSERT INTO public.team_schedules (team_id, user_id, start_time, end_time)
SELECT 
    '11111111-1111-1111-1111-111111111113',
    id,
    NOW(),
    NOW() + INTERVAL '8 hours'
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'agent';

-- Add search query definitions
INSERT INTO public.search_queries 
(id, name, description, base_table, query_definition, column_definitions, permissions_required, is_active) 
VALUES
(
    'ffffffff-eeee-dddd-cccc-bbbbbbbbbbbb',
    'Search Queries',
    'Manage search query definitions',
    'search_queries',
    jsonb_build_object(
        'select', '*',
        'orderBy', jsonb_build_array(
            jsonb_build_object('id', 'name', 'desc', false)
        )
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Name',
            'accessorKey', 'name',
            'cell', 'info => info.getValue()'
        ),
        jsonb_build_object(
            'header', 'Description',
            'accessorKey', 'description',
            'cell', 'info => info.getValue()'
        ),
        jsonb_build_object(
            'header', 'Base Table',
            'accessorKey', 'base_table',
            'cell', 'info => info.getValue()'
        ),
        jsonb_build_object(
            'header', 'Query Definition',
            'accessorKey', 'query_definition',
            'type', 'json'
        ),
        jsonb_build_object(
            'header', 'Column Definitions',
            'accessorKey', 'column_definitions',
            'type', 'json'
        ),
        jsonb_build_object(
            'header', 'Permissions Required',
            'accessorKey', 'permissions_required',
            'type', 'json'
        ),
        jsonb_build_object(
            'header', 'Active',
            'accessorKey', 'is_active',
            'cell', 'info => info.getValue() ? "🟢" : "🔴"'
        ),
        jsonb_build_object(
            'header', 'Created At',
            'accessorKey', 'created_at',
            'cell', 'info => new Date(info.getValue()).toLocaleDateString()'
        )
    ),
    ARRAY['admin.search_queries.manage'],
    true
),
(
    'aaaaaaaa-0000-4000-a000-000000000001',
    'Tickets by Status',
    'Report showing ticket counts by status',
    'tickets',
    jsonb_build_object(
        'select', '*, count(*) as count',
        'groupBy', ARRAY['status'],
        'orderBy', jsonb_build_array(
            jsonb_build_object('id', 'status', 'desc', false)
        )
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Status',
            'accessorKey', 'status'
        ),
        jsonb_build_object(
            'header', 'Count',
            'accessorKey', 'count'
        )
    ),
    ARRAY['reports.view'],
    true
),
(
    'aaaaaaaa-0000-4000-a000-000000000002',
    'Users',
    'Manage system users',
    'users',
    jsonb_build_object(
        'select', '*, organization_name:organizations!fk_users_organization(id,name)',
        'orderBy', jsonb_build_array(
            jsonb_build_object('id', 'last_name', 'desc', false),
            jsonb_build_object('id', 'first_name', 'desc', false)
        )
    ),
    jsonb_build_array(
        jsonb_build_object('header', 'First Name', 'accessorKey', 'first_name'),
        jsonb_build_object('header', 'Last Name', 'accessorKey', 'last_name'),
        jsonb_build_object('header', 'Email', 'accessorKey', 'email'),
        jsonb_build_object('header', 'Role', 'accessorKey', 'role'),
        jsonb_build_object('header', 'Active', 'accessorKey', 'is_active', 'type', 'boolean'),
        jsonb_build_object(
           'header', 'Organization',
            'accessorKey', 'organization_id',
            'aliasName', 'organization_name',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'organizations',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object('header', 'Created At', 'accessorKey', 'created_at')
    ),
    ARRAY['admin.users.manage'],
    true
)
ON CONFLICT (name) DO NOTHING;

-- Add organization management search query
INSERT INTO public.search_queries (
    ID,
    name,
    description,
    base_table,
    permissions_required,
    column_definitions,
    query_definition,
    is_active
)
VALUES (
    'aac8ccae-fded-4169-ac10-094761cc0d6d',
    'Organization Management',
    'View and manage organizations',
    'organizations',
    ARRAY['admin.organizations.manage'],
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Name',
            'accessorKey', 'name',
            'type', 'text',
            'required', true,
            'searchable', true
        ),
        jsonb_build_object(
            'header', 'Domain',
            'accessorKey', 'domain',
            'type', 'text',
            'required', false,
            'searchable', true
        ),
        jsonb_build_object(
            'header', 'Description',
            'accessorKey', 'description',
            'type', 'text',
            'required', false,
            'searchable', true
        ),
        jsonb_build_object(
            'header', 'Active',
            'accessorKey', 'is_active',
            'type', 'boolean',
            'required', true,
            'searchable', false
        ),
        jsonb_build_object(
            'header', 'Created At',
            'accessorKey', 'created_at',
            'type', 'timestamp with time zone',
            'required', false,
            'searchable', false
        )
    ),
    jsonb_build_object(
        'select', 'id, name, domain, description, is_active, created_at',
        'orderBy', jsonb_build_array(
            jsonb_build_object('id', 'name', 'desc', false)
        )
    ),
    true
);

-- Add permission management search query
INSERT INTO public.search_queries (
    ID,
    name,
    description,
    base_table,
    permissions_required,
    column_definitions,
    query_definition,
    is_active
) VALUES (
    '86ec2ebc-eb64-4403-a154-41407c311afc',
    'Permission Management',
    'View and manage system permissions',
    'permissions',
    ARRAY['admin.permissions.manage'],
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Name',
            'accessorKey', 'name',
            'type', 'text',
            'required', true,
            'searchable', true
        ),
        jsonb_build_object(
            'header', 'Description',
            'accessorKey', 'description',
            'type', 'text',
            'required', false,
            'searchable', true
        ),
        jsonb_build_object(
            'header', 'Parent Permission',
            'accessorKey', 'parent_id',
            'aliasName', 'parent_permission',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'permissions',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
            'header', 'Active',
            'accessorKey', 'is_active',
            'type', 'boolean',
            'required', true,
            'searchable', false
        ),
        jsonb_build_object(
            'header', 'Created At',
            'accessorKey', 'created_at',
            'type', 'timestamp with time zone',
            'required', false,
            'searchable', false
        )
    ),
    jsonb_build_object(
        'select', '*, parent_permission:permissions!fk_permissions_parent(id, name)',
        'orderBy', jsonb_build_array(
            jsonb_build_object('id', 'name', 'desc', false)
        )
    ),
    true
);

-- Add ticket form query definition
INSERT INTO public.search_queries 
(id, name, description, base_table, query_definition, column_definitions, permissions_required, is_active) 
VALUES
(
    'ffffffff-ffff-ffff-ffff-ffffffffffff',
    'New Ticket Form',
    'Form for creating/editing tickets',
    'tickets',
    jsonb_build_object(
        'select', '*'
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Subject',
            'accessorKey', 'subject',
            'type', 'text',
            'required', true
        ),
        jsonb_build_object(
            'header', 'Description',
            'accessorKey', 'description',
            'type', 'textarea',
            'required', true
        ),
        jsonb_build_object(
            'header', 'Priority',
            'accessorKey', 'priority',
            'type', 'select',
            'options', jsonb_build_array('low', 'medium', 'high')
        )
    ),
    ARRAY['tickets.create'],
    true
);

-- Fix My Assigned Tickets query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'My Assigned Tickets',
    'View tickets assigned to me',
    'tickets',
    jsonb_build_object(
        'select', '*, 
        requester:users!fk_tickets_requester(id, full_name, email), 
        assignee:users!fk_tickets_assignee(id, full_name, email),
        team_name:teams!fk_tickets_teams(id, name),
        organization_name:organizations!fk_tickets_organization(id, name)',
        'where', jsonb_build_object(
            'assignee_id', 'auth.uid()'  -- This will filter for tickets assigned to the current user
        )
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Subject',
            'accessorKey', 'subject'
        ),
        jsonb_build_object(
            'header', 'Description',
            'accessorKey', 'description',
            'type', 'textarea'
        ),
        jsonb_build_object(
            'header', 'Status',
            'accessorKey', 'status'
        ),
        jsonb_build_object(
            'header', 'Priority',
            'accessorKey', 'priority',
            'type', 'select',
            'options', jsonb_build_array('low', 'medium', 'high')
        ),
        jsonb_build_object(
           'header', 'Requested by',
            'accessorKey', 'requester_id',
            'aliasName', 'requester',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            )
        ),
        jsonb_build_object(
           'header', 'Assigned to',
            'accessorKey', 'assignee_id',
            'aliasName', 'assignee',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            )
        ),
        jsonb_build_object(
            'header', 'Team',
            'accessorKey', 'team_id',
            'aliasName', 'team_name',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'teams',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
           'header', 'Organization',
            'accessorKey', 'organization_id',
            'aliasName', 'organization_name',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'organizations',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
            'header', 'Created',
            'accessorKey', 'created_at'
        )
    ),
    ARRAY['tickets.view.assigned'],
    true
);

-- Fix My Submitted Tickets query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'My Submitted Tickets',
    'View tickets submitted by me',
    'tickets',
    jsonb_build_object(
        'select', '*, 
        requester:users!fk_tickets_requester(id, full_name, email), 
        assignee:users!fk_tickets_assignee(id, full_name, email),
        team_name:teams!fk_tickets_teams(id, name),
        organization_name:organizations!fk_tickets_organization(id, name)',
        'where', jsonb_build_object(
            'requester_id', 'auth.uid()'  -- This will filter for the current user's tickets
        )
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Subject',
            'accessorKey', 'subject'
        ),
        jsonb_build_object(
            'header', 'Description',
            'accessorKey', 'description',
            'type', 'textarea'
        ),
        jsonb_build_object(
            'header', 'Status',
            'accessorKey', 'status'
        ),
        jsonb_build_object(
            'header', 'Priority',
            'accessorKey', 'priority',
            'type', 'select',
            'options', jsonb_build_array('low', 'medium', 'high')
        ),
        jsonb_build_object(
           'header', 'Requested by',
            'accessorKey', 'requester_id',
            'aliasName', 'requester',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            )
        ),
        jsonb_build_object(
           'header', 'Assigned to',
            'accessorKey', 'assignee_id',
            'aliasName', 'assignee',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            )
        ),
        jsonb_build_object(
            'header', 'Team',
            'accessorKey', 'team_id',
            'aliasName', 'team_name',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'teams',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
           'header', 'Organization',
            'accessorKey', 'organization_id',
            'aliasName', 'organization_name',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'organizations',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
            'header', 'Created',
            'accessorKey', 'created_at'
        )
    ),
    ARRAY['tickets.view.own'],
    true
);

-- Add Organization Tickets search query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'Organization Tickets',
    'View organization tickets',
    'tickets',
    jsonb_build_object(
        'select', '*, 
        requester:users!fk_tickets_requester(id, full_name, email), 
        assignee:users!fk_tickets_assignee(id, full_name, email),
        team_name:teams!fk_tickets_teams(id, name),
        organization_name:organizations!fk_tickets_organization(id, name)',
        'where', jsonb_build_object(
            'organization_id', '(SELECT organization_id FROM users WHERE id = auth.uid())'
        )
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Subject',
            'accessorKey', 'subject'
        ),
        jsonb_build_object(
            'header', 'Status',
            'accessorKey', 'status'
        ),
        jsonb_build_object(
            'header', 'Priority',
            'accessorKey', 'priority',
            'type', 'select',
            'options', jsonb_build_array('low', 'medium', 'high')
        ),
        jsonb_build_object(
           'header', 'Requested by',
            'accessorKey', 'requester_id',
            'aliasName', 'requester',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            )
        ),
        jsonb_build_object(
           'header', 'Assigned to',
            'accessorKey', 'assignee_id',
            'aliasName', 'assignee',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            )
        ),
        jsonb_build_object(
            'header', 'Team',
            'accessorKey', 'team_id',
            'aliasName', 'team_name',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'teams',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
           'header', 'Organization',
            'accessorKey', 'organization_id',
            'aliasName', 'organization_name',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'organizations',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
            'header', 'Created',
            'accessorKey', 'created_at'
        )
    ),
    ARRAY['tickets.view.org'],
    true
);

-- Fix My Submitted customer Tickets query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb11',
    'Customer My Submitted Tickets',
    'Customer tickets submitted by me',
    'tickets',
    jsonb_build_object(
        'select', '*, 
        requester:users!fk_tickets_requester(id, full_name, email), 
        assignee:users!fk_tickets_assignee(id, full_name, email),
        team_name:teams!fk_tickets_teams(id, name),
        organization_name:organizations!fk_tickets_organization(id, name)',
        'where', jsonb_build_object(
            'requester_id', 'auth.uid()'  -- This will filter for the current user's tickets
        )
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Subject',
            'accessorKey', 'subject'
        ),
        jsonb_build_object(
            'header', 'Description',
            'accessorKey', 'description',
            'type', 'textarea'
        ),
        jsonb_build_object(
            'header', 'Status',
            'accessorKey', 'status'
        ),
        jsonb_build_object(
            'header', 'Priority',
            'accessorKey', 'priority',
            'type', 'select',
            'options', jsonb_build_array('low', 'medium', 'high')
        ),
        jsonb_build_object(
           'header', 'Requested by',
            'accessorKey', 'requester_id',
            'aliasName', 'requester',
            'type', 'uuid',
            'disabled', true,
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            )
        ),
        jsonb_build_object(
           'header', 'Assigned to',
            'accessorKey', 'assignee_id',
            'aliasName', 'assignee',
            'type', 'uuid',
            'disabled', true,
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            )
        ),
        jsonb_build_object(
            'header', 'Team',
            'accessorKey', 'team_id',
            'aliasName', 'team_name',
            'type', 'uuid',
            'disabled', true,
            'foreignKey', jsonb_build_object(
                'table', 'teams',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
           'header', 'Organization',
            'accessorKey', 'organization_id',
            'aliasName', 'organization_name',
            'type', 'uuid',
            'disabled', true,
            'foreignKey', jsonb_build_object(
                'table', 'organizations',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
            'header', 'Created',
            'accessorKey', 'created_at'
        )
    ),
    ARRAY['tickets.view.own.customer'],
    true
);

-- Add Organization customer Tickets search query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'cccccccc-cccc-cccc-cccc-cccccccccc11',
    'Customer Organization Tickets',
    'Customer organization tickets',
    'tickets',
    jsonb_build_object(
        'select', '*, 
        requester:users!fk_tickets_requester(id, full_name, email), 
        assignee:users!fk_tickets_assignee(id, full_name, email),
        team_name:teams!fk_tickets_teams(id, name),
        organization_name:organizations!fk_tickets_organization(id, name)',
        'where', jsonb_build_object(
            'organization_id', '(SELECT organization_id FROM users WHERE id = auth.uid())'
        )
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Subject',
            'accessorKey', 'subject'
        ),
        jsonb_build_object(
            'header', 'Status',
            'accessorKey', 'status'
        ),
        jsonb_build_object(
            'header', 'Priority',
            'accessorKey', 'priority',
            'type', 'select',
            'options', jsonb_build_array('low', 'medium', 'high')
        ),
        jsonb_build_object(
           'header', 'Requested by',
            'accessorKey', 'requester_id',
            'aliasName', 'requester',
            'type', 'uuid',
            'disabled', true,
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            )
        ),
        jsonb_build_object(
           'header', 'Assigned to',
            'accessorKey', 'assignee_id',
            'aliasName', 'assignee',
            'type', 'uuid',
            'disabled', true,
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            )
        ),
        jsonb_build_object(
            'header', 'Team',
            'accessorKey', 'team_id',
            'aliasName', 'team_name',
            'type', 'uuid',
            'disabled', true,
            'foreignKey', jsonb_build_object(
                'table', 'teams',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
           'header', 'Organization',
            'accessorKey', 'organization_id',
            'aliasName', 'organization_name',
            'type', 'uuid',
            'disabled', true,
            'foreignKey', jsonb_build_object(
                'table', 'organizations',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
            'header', 'Created',
            'accessorKey', 'created_at'
        )
    ),
    ARRAY['tickets.view.org.customer'],
    true
);

-- Add All Tickets search query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'All Tickets',
    'View all tickets',
    'tickets',
    jsonb_build_object(
        'select', '*, 
        requester:users!fk_tickets_requester(id, full_name, email), 
        assignee:users!fk_tickets_assignee(id, full_name, email),
        team_name:teams!fk_tickets_teams(id, name),
        organization_name:organizations!fk_tickets_organization(id, name)'
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Subject',
            'accessorKey', 'subject'
        ),
        jsonb_build_object(
            'header', 'Status',
            'accessorKey', 'status'
        ),
        jsonb_build_object(
            'header', 'Priority',
            'accessorKey', 'priority',
            'type', 'select',
            'options', jsonb_build_array('low', 'medium', 'high')
        ),
        jsonb_build_object(
           'header', 'Requested by',
            'accessorKey', 'requester_id',
            'aliasName', 'requester',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            )
        ),
        jsonb_build_object(
           'header', 'Assigned to',
            'accessorKey', 'assignee_id',
            'aliasName', 'assignee',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            )
        ),
        jsonb_build_object(
            'header', 'Team',
            'accessorKey', 'team_id',
            'aliasName', 'team_name',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'teams',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
           'header', 'Organization',
            'accessorKey', 'organization_id',
            'aliasName', 'organization_name',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'organizations',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
            'header', 'Created',
            'accessorKey', 'created_at'
        )
    ),
    ARRAY['tickets.view.all'],
    true
);

-- Add Teams search query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'eeeeeeee-eeee-eeee-eeee-111111111111',
    'Teams Management',
    'Team management',
    'teams',
    jsonb_build_object(
        'select', '*, 
        organization:organizations!fk_teams_organization(id, name),
        member_count:team_members!fk_team_members_team(count)::int,
        tags:team_tags!fk_team_tags_team(tag:tags!fk_team_tags_tag(name))'
    ),jsonb_build_array(
        jsonb_build_object(
            'header', 'Name',
            'accessorKey', 'name',
            'type', 'text',
            'required', true
        ),
        jsonb_build_object(
            'header', 'Description',
            'accessorKey', 'description',
            'type', 'text'
        ),
        jsonb_build_object(
            'header', 'Organization',
            'accessorKey', 'organization_id',
            'aliasName', 'organization',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'organizations',
                'value', 'id',
                'label', 'name'
            ),
            'required', true
        ),
        jsonb_build_object(
            'header', 'Members',
            'accessorKey', 'member_count',
            'aliasName', 'member_count',
            'type', 'computed',
            'computedType', 'count',
            'sourceTable', 'team_members',
            'sourceKey', 'team_id'
        ),
        jsonb_build_object(
            'header', 'Tags',
            'accessorKey', 'tags',
            'aliasName', 'tags',
            'type', 'computed',
            'computedType', 'array',
            'sourceTable', 'team_tags',
            'sourceKey', 'team_id',
            'through', jsonb_build_object(
                'table', 'tags',
                'key', 'id',
                'field', 'name'
            )
        ),
        jsonb_build_object(
            'header', 'Active',
            'accessorKey', 'is_active',
            'type', 'boolean',
            'required', true
        )
    ),
    ARRAY['teams.view'],
    true
);

-- Add child search query for Team Members
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    parent_table,
    parent_field,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'eeeeeeee-eeee-eeee-eeee-222222222222',
    'Team Members Management',
    'Team member management',
    'team_members',
    'teams',
    'team_id',
    jsonb_build_object(
        'select', 'id, team_id, user_id, role, is_active,
        user:users!fk_team_members_user(id, full_name, email)'
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Member',
            'accessorKey', 'user_id',
            'aliasName', 'user',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            ),
            'required', true
        ),
        jsonb_build_object(
            'header', 'Role',
            'accessorKey', 'role',
            'type', 'select',
            'options', jsonb_build_array('lead', 'member')
        )
    ),
    ARRAY['teams.view'],
    true
);

-- Add child search query for Team Tags
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    parent_table,
    parent_field,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'eeeeeeee-eeee-eeee-eeee-333333333333',
    'Team Tags Management',
    'Team tags management',
    'team_tags',
    'teams',
    'team_id',
    jsonb_build_object(
        'select', 'tag_id, team_id, 
        tag_name:tags!fk_team_tags_tag(id, name)'
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Tag',
            'accessorKey', 'tag_id',
            'aliasName', 'tag_name',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'tags',
                'value', 'id',
                'label', 'name'
            ),
            'required', true
        )
    ),
    ARRAY['teams.view'],
    true
);

-- Add child search query for Team Schedules
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    parent_table,
    parent_field,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'eeeeeeee-eeee-eeee-eeee-444444444444',
    'Team Schedules Management',
    'Team schedule management',
    'team_schedules',
    'teams',
    'team_id',
    jsonb_build_object(
        'select', 'id, team_id, user_id, start_time, end_time,
        user_name:users!fk_team_schedules_user(id, full_name)'
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Member',
            'accessorKey', 'user_id',
            'aliasName', 'user_name',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            ),
            'required', true
        ),
        jsonb_build_object(
            'header', 'Start Time',
            'accessorKey', 'start_time',
            'type', 'datetime',
            'required', true
        ),
        jsonb_build_object(
            'header', 'End Time',
            'accessorKey', 'end_time',
            'type', 'datetime',
            'required', true
        )
    ),
    ARRAY['teams.view'],
    true
);

-- Add Role Management search query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'aaaaaaaa-bbbb-cccc-dddd-111111111111',
    'Role Management',
    'Manage system roles',
    'roles',
    jsonb_build_object(
        'select', '*'
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Name',
            'accessorKey', 'name',
            'type', 'text',
            'required', true
        ),
        jsonb_build_object(
            'header', 'Description',
            'accessorKey', 'description',
            'type', 'text'
        ),
        jsonb_build_object(
            'header', 'Active',
            'accessorKey', 'is_active',
            'type', 'boolean',
            'required', true
        )
    ),
    ARRAY['admin.roles.manage'],
    true
);

-- Add Role Permissions child search query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    parent_table,
    parent_field,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'aaaaaaaa-bbbb-cccc-dddd-222222222222',
    'Role Permissions',
    'Manage role permissions',
    'role_permissions',
    'roles',
    'role_id',
    jsonb_build_object(
        'select', 'id, role_id, permission_id,
        permission:permissions!fk_role_permissions_permission(id, name, description)'
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Permission',
            'accessorKey', 'permission_id',
            'aliasName', 'permission',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'permissions',
                'value', 'id',
                'label', 'name'
            ),
            'required', true
        )
    ),
    ARRAY['admin.roles.manage'],
    true
);

-- Add Navigation Management search query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'ffffffff-eeee-dddd-cccc-111111111111',
    'Navigation Management',
    'Manage sidebar navigation items',
    'sidebar_navigation',
    jsonb_build_object(
        'select', '*, 
        search_query:search_queries!fk_sidebar_navigation_search_query(id, name)',
        'orderBy', jsonb_build_array(
            jsonb_build_object('id', 'sort_order', 'desc', false)
        )
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Name',
            'accessorKey', 'name',
            'type', 'text',
            'required', true
        ),
        jsonb_build_object(
            'header', 'Description',
            'accessorKey', 'description',
            'type', 'textarea'
        ),
        jsonb_build_object(
            'header', 'Icon',
            'accessorKey', 'icon',
            'type', 'text'
        ),
        jsonb_build_object(
            'header', 'Search Query',
            'accessorKey', 'search_query_id',
            'aliasName', 'search_query',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'search_queries',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
            'header', 'URL',
            'accessorKey', 'url',
            'type', 'text'
        ),
        jsonb_build_object(
            'header', 'Sort Order',
            'accessorKey', 'sort_order',
            'type', 'number',
            'required', true
        ),
        jsonb_build_object(
            'header', 'Required Permissions',
            'accessorKey', 'permissions_required',
            'type', 'json'
        ),
        jsonb_build_object(
            'header', 'Active',
            'accessorKey', 'is_active',
            'type', 'boolean'
        )
    ),
    ARRAY['admin.navigation.manage'],
    true
);

-- Add Knowledge Domain Management search query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'aaaaaaaa-0000-4000-a000-000000000003',
    'Knowledge Domain Management',
    'Manage knowledge domains and expertise levels',
    'knowledge_domain',
    jsonb_build_object(
        'select', '*',
        'orderBy', jsonb_build_array(
            jsonb_build_object('id', 'name', 'desc', false)
        )
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Name',
            'accessorKey', 'name',
            'type', 'text',
            'required', true
        ),
        jsonb_build_object(
            'header', 'Description',
            'accessorKey', 'description',
            'type', 'textarea'
        ),
        jsonb_build_object(
            'header', 'Active',
            'accessorKey', 'is_active',
            'type', 'boolean'
        )
    ),
    ARRAY['admin.knowledge.manage'],
    true
);

-- First, insert main navigation items
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

-- Add report items under Reports section
('bbbbbbbb-0000-4000-b000-000000000001',   'Tickets by Status', 'View ticket distribution by status', '📊', '33333333-3333-3333-3333-222222222222', 'aaaaaaaa-0000-4000-a000-000000000001', null, 10, ARRAY['reports.view'], true),

-- Admin sub-items
('aaaaaaaa-bbbb-cccc-dddd-222222222222', 'Knowledge Domains', 'Manage Knowledge Domains', '🧠', '99999999-9999-9999-9999-222222222222', 'aaaaaaaa-0000-4000-a000-000000000003', '/list', 15, ARRAY['admin.knowledge.manage'], true),
('aaaaaaaa-aaaa-aaaa-aaaa-222222222222', 'Users', 'User management', '👥', '99999999-9999-9999-9999-222222222222', 'aaaaaaaa-0000-4000-a000-000000000002', '/list', 10, ARRAY['admin.users.manage'], true),
('bbbbbbbb-bbbb-bbbb-bbbb-222222222222', 'Roles', 'Role management', '🔑', '99999999-9999-9999-9999-222222222222', 'aaaaaaaa-bbbb-cccc-dddd-111111111111', '/list', 20, ARRAY['admin.roles.manage'], true),
('cccccccc-cccc-cccc-cccc-222222222222', 'Permissions', 'Permission management', '🛡️', '99999999-9999-9999-9999-222222222222', 'aaaaaaaa-bbbb-cccc-dddd-222222222222', '/list', 30, ARRAY['admin.permissions.manage'], true),
('dddddddd-dddd-dddd-dddd-222222222222', 'Organizations', 'Organization management', '🏢', '99999999-9999-9999-9999-222222222222', 'aac8ccae-fded-4169-ac10-094761cc0d6d', '/list', 40, ARRAY['admin.organizations.manage'], true),
('ffffffff-ffff-ffff-ffff-222222222222', 'Search Queries', 'Search query management', '🔍', '99999999-9999-9999-9999-222222222222', 'ffffffff-eeee-dddd-cccc-bbbbbbbbbbbb', '/list', 60, ARRAY['admin.search_queries.manage'], true),
('11111111-2222-3333-4444-555555555555', 'Navigation', 'Navigation management', '🧭', '99999999-9999-9999-9999-222222222222', 'ffffffff-eeee-dddd-cccc-111111111111', '/list', 70, ARRAY['admin.navigation.manage'], true),
('eeeeeeee-eeee-eeee-eeee-333333333333', 'Teams', 'Team management', '👥', '99999999-9999-9999-9999-222222222222', 'eeeeeeee-eeee-eeee-eeee-111111111111', '/list', 70, ARRAY['admin.teams.manage'], true);

-- Update Teams search query
UPDATE search_queries 
SET query_definition = jsonb_build_object(
    'select', '*, 
    organization:organizations!fk_teams_organization(id, name),
    member_count:team_members!fk_team_members_team(count)::int,
    tags:team_tags!fk_team_tags_team(tag:tags!fk_team_tags_tag(name))'
)
WHERE id = 'eeeeeeee-eeee-eeee-eeee-111111111111';

-- Add search query for My Team's Tickets
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'aaaaaaaa-aaaa-aaaa-aaaa-bbbbbbbbbb11',
    'My Team''s Tickets',
    'View tickets assigned to my teams',
    'tickets',
    jsonb_build_object(
        'select', '*, 
        requester:users!fk_tickets_requester(id, full_name),
        team_name:teams!fk_tickets_teams(id, name),
        organization:organizations!fk_tickets_organization(id, name)',
        'where', jsonb_build_object(
            'team_id', '(select team_id as team_id from team_members where user_id = auth.uid())'
        )
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Subject',
            'accessorKey', 'subject',
            'type', 'text'
        ),
        jsonb_build_object(
            'header', 'Description',
            'accessorKey', 'description',
            'type', 'textarea'
        ),
        jsonb_build_object(
            'header', 'Status',
            'accessorKey', 'status',
            'type', 'select',
            'options', jsonb_build_array('open', 'pending', 'solved', 'closed')
        ),
        jsonb_build_object(
            'header', 'Priority',
            'accessorKey', 'priority',
            'type', 'select',
            'options', jsonb_build_array('low', 'medium', 'high', 'urgent')
        ),
        jsonb_build_object(
            'header', 'Requester',
            'accessorKey', 'requester_id',
            'aliasName', 'requester',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'users',
                'value', 'id',
                'label', 'full_name'
            )
        ),
        jsonb_build_object(
           'header', 'Organization',
            'accessorKey', 'organization_id',
            'aliasName', 'organization_name',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'organizations',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
            'header', 'Team',
            'accessorKey', 'team_id',
            'aliasName', 'team_name',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'teams',
                'value', 'id',
                'label', 'name'
            )
        ),
        jsonb_build_object(
            'header', 'Created',
            'accessorKey', 'created_at',
            'type', 'datetime'
        )
    ),
    ARRAY['tickets.view'],
    true
);

-- Add sidebar navigation for My Team's Tickets
INSERT INTO public.sidebar_navigation 
(id, name, description, icon, parent_id, search_query_id, url, sort_order, permissions_required, is_active) 
VALUES
(
    '88888888-8888-8888-8888-222222222211',
    'My Team''s Tickets',
    'View tickets assigned to my teams',
    '📋',
    '22222222-2222-2222-2222-222222222222',  -- Parent is Tickets section
    'aaaaaaaa-aaaa-aaaa-aaaa-bbbbbbbbbb11',
    '/list',
    17,  -- Between My Assigned (15) and Organization Tickets (20)
    ARRAY['tickets.view'],
    true
);

-- Add Ticket Tags child search query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    parent_table,
    parent_field,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'aaaaaaaa-bbbb-cccc-dddd-333333333333',
    'Ticket Tags',
    'Manage ticket tags',
    'ticket_tags',
    'tickets',
    'ticket_id',
    jsonb_build_object(
        'select', 'id, ticket_id, tag_id,
        tag:tags!fk_ticket_tags_tag(id, name)'
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Tag',
            'accessorKey', 'tag_id',
            'aliasName', 'tag',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'tags',
                'value', 'id',
                'label', 'name'
            ),
            'required', true
        )
    ),
    ARRAY['tickets.view'],
    true
);

-- Update Ticket Comments child search query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    parent_table,
    parent_field,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'aaaaaaaa-bbbb-cccc-dddd-444444444444',
    'Ticket Comments',
    'Manage ticket comments',
    'ticket_comments',
    'tickets',
    'ticket_id',
    jsonb_build_object(
        'select', 'id, ticket_id, author_id, content, is_private, created_at,
        author:users!fk_ticket_comments_author(id, full_name)',
        'defaultValues', jsonb_build_object(
            'author_id', 'auth.uid()'
        )
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Content',
            'accessorKey', 'content',
            'type', 'textarea',
            'required', true
        ),
        jsonb_build_object(
            'header', 'Internal Note',
            'accessorKey', 'is_private',
            'type', 'boolean'
        )
    ),
    ARRAY['tickets.view.internal'],
    true
);

-- Update Customer Ticket Comments search query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    parent_table,
    parent_field,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'aaaaaaaa-bbbb-cccc-dddd-444444444443',
    'Customer Ticket Comments',
    'Manage ticket comments',
    'ticket_comments',
    'tickets',
    'ticket_id',
    jsonb_build_object(
        'select', 'id, ticket_id, author_id, content, created_at,
        author:users!fk_ticket_comments_author(id, full_name)',
        'defaultValues', jsonb_build_object(
            'author_id', 'auth.uid()',
            'is_private', 'false'
        ),
        'where', 'NOT is_private'  -- Only show non-private comments
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Content',
            'accessorKey', 'content',
            'type', 'textarea',
            'required', true
        )
    ),
    ARRAY['tickets.view'],
    true
);

-- Add Comment Templates Management search query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'cccccccc-1111-2222-3333-444444444444',  -- Fixed UUID format
    'Comment Templates',
    'Manage comment templates',
    'comment_templates',
    jsonb_build_object(
        'select', '*',
        'orderBy', jsonb_build_array(
            jsonb_build_object('id', 'category', 'desc', false),
            jsonb_build_object('id', 'sort_order', 'desc', false)
        )
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Name',
            'accessorKey', 'name',
            'type', 'text',
            'required', true
        ),
        jsonb_build_object(
            'header', 'Content',
            'accessorKey', 'content',
            'type', 'textarea',
            'required', true
        ),
        jsonb_build_object(
            'header', 'Category',
            'accessorKey', 'category',
            'type', 'text'
        ),
        jsonb_build_object(
            'header', 'Private',
            'accessorKey', 'is_private',
            'type', 'boolean'
        ),
        jsonb_build_object(
            'header', 'Sort Order',
            'accessorKey', 'sort_order',
            'type', 'number'
        ),
        jsonb_build_object(
            'header', 'Active',
            'accessorKey', 'is_active',
            'type', 'boolean'
        )
    ),
    ARRAY['admin.templates.manage'],
    true
);

-- Add to Admin navigation
INSERT INTO sidebar_navigation 
(id, name, description, icon, parent_id, search_query_id, url, sort_order, permissions_required, is_active)
VALUES (
    'cccccccc-1111-2222-3333-555555555555',  -- Fixed UUID format
    'Comment Templates',
    'Manage comment templates',
    '📝',
    '99999999-9999-9999-9999-222222222222',  -- Admin section
    'cccccccc-1111-2222-3333-444444444444',  -- Match search query ID
    '/list',
    60,
    ARRAY['admin.templates.manage'],
    true
);

-- Add permission for template management
INSERT INTO permissions (id, name, description)
VALUES ('cccccccc-1111-2222-3333-666666666666', 'admin.templates.manage', 'Manage comment templates');  -- Fixed UUID format

-- Grant permission to admin role
INSERT INTO role_permissions (role_id, permission_id)
SELECT 
    r.id,
    p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'admin'
AND p.name = 'admin.templates.manage';

-- Add relationships between search queries
INSERT INTO search_query_relationships (parent_search_query_id, child_search_query_id) VALUES 
-- Teams and its child queries
('eeeeeeee-eeee-eeee-eeee-111111111111', 'eeeeeeee-eeee-eeee-eeee-222222222222'),  -- Team Members
('eeeeeeee-eeee-eeee-eeee-111111111111', 'eeeeeeee-eeee-eeee-eeee-333333333333'),  -- Team Tags
('eeeeeeee-eeee-eeee-eeee-111111111111', 'eeeeeeee-eeee-eeee-eeee-444444444444'),  -- Team Schedules

-- Roles and its child queries
('aaaaaaaa-bbbb-cccc-dddd-111111111111', 'aaaaaaaa-bbbb-cccc-dddd-222222222222'),  -- Role Permissions

-- My Submitted Tickets
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-bbbb-cccc-dddd-333333333333'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-bbbb-cccc-dddd-444444444444'),

-- My Submitted Tickets (Customer)
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb11', 'aaaaaaaa-bbbb-cccc-dddd-333333333333'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb11', 'aaaaaaaa-bbbb-cccc-dddd-444444444443'),

-- Organization Tickets
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'aaaaaaaa-bbbb-cccc-dddd-333333333333'),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'aaaaaaaa-bbbb-cccc-dddd-444444444444'),

-- Organization Tickets (Customer)
('cccccccc-cccc-cccc-cccc-cccccccccc11', 'aaaaaaaa-bbbb-cccc-dddd-333333333333'),
('cccccccc-cccc-cccc-cccc-cccccccccc11', 'aaaaaaaa-bbbb-cccc-dddd-444444444443'),

-- All Tickets
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'aaaaaaaa-bbbb-cccc-dddd-333333333333'),
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'aaaaaaaa-bbbb-cccc-dddd-444444444444'),

-- My Assigned Tickets
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-bbbb-cccc-dddd-333333333333'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-bbbb-cccc-dddd-444444444444'),

-- My Team's Tickets
('aaaaaaaa-aaaa-aaaa-aaaa-bbbbbbbbbb11', 'aaaaaaaa-bbbb-cccc-dddd-333333333333'),
('aaaaaaaa-aaaa-aaaa-aaaa-bbbbbbbbbb11', 'aaaaaaaa-bbbb-cccc-dddd-444444444444'),

-- IntelliSUppot comment template
('aaaaaaaa-bbbb-cccc-dddd-444444444444', 'cccccccc-1111-2222-3333-444444444444');

-- Update Navigation Management search query
UPDATE search_queries 
SET query_definition = jsonb_build_object(
    'select', '*, 
    search_query:search_queries!fk_sidebar_navigation_search_query(id, name)',
    'orderBy', jsonb_build_array(
        jsonb_build_object('id', 'sort_order', 'desc', false)
    )
)
WHERE id = 'ffffffff-eeee-dddd-cccc-111111111111';

-- Add initial comment templates
INSERT INTO comment_templates (
    id,
    name,
    content,
    category,
    is_private,
    sort_order,
    is_active
) VALUES 
-- General templates
(
    'cccccccc-1111-2222-3333-000000000001',
    'Ticket Acknowledgment',
    'Thank you for submitting your ticket. We have received your request and will begin working on it shortly.',
    'General',
    false,
    10,
    true
),
(
    'cccccccc-1111-2222-3333-000000000002',
    'Status Update Request',
    'Could you please provide an update on this issue? Has there been any change in status?',
    'General',
    false,
    20,
    true
),
-- Internal notes
(
    'cccccccc-1111-2222-3333-000000000003',
    'Internal Escalation Note',
    'This ticket requires escalation due to [reason]. Please review and advise.',
    'Internal',
    true,
    30,
    true
),
(
    'cccccccc-1111-2222-3333-000000000004',
    'Internal Handover Note',
    'Handing over this ticket. Current status: [status]. Next steps needed: [steps].',
    'Internal',
    true,
    40,
    true
),
-- Resolution templates
(
    'cccccccc-1111-2222-3333-000000000005',
    'Resolution Confirmation',
    'We believe this issue has been resolved. Please confirm if the solution meets your needs.',
    'Resolution',
    false,
    50,
    true
),
(
    'cccccccc-1111-2222-3333-000000000006',
    'Closing Note',
    'As we haven''t heard back from you, we''ll be closing this ticket. Feel free to reopen if you need further assistance.',
    'Resolution',
    false,
    60,
    true
),
-- Follow-up templates
(
    'cccccccc-1111-2222-3333-000000000007',
    'Additional Information Request',
    'To better assist you, we need the following additional information:\n- [detail 1]\n- [detail 2]',
    'Follow-up',
    false,
    70,
    true
),
(
    'cccccccc-1111-2222-3333-000000000008',
    'Progress Update',
    'We wanted to update you on the progress of your ticket. Currently, we are [status] and expect [next steps].',
    'Follow-up',
    false,
    80,
    true
);

-- Add Knowledge Domain Management permission
INSERT INTO permissions (id, name, description)
VALUES ('11111111-1111-cccc-1111-111111111111', 'admin.knowledge.manage', 'Can view and manage knowledge domains');

-- Add permission to admin role
INSERT INTO role_permissions (role_id, permission_id)
VALUES ('11111111-1111-1111-1111-111111111112', '11111111-1111-cccc-1111-111111111111');

-- Add User Knowledge Domains search query
INSERT INTO search_queries (
    id,
    name,
    description,
    base_table,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'aaaaaaaa-0000-4000-a000-000000000004',
    'User Knowledge Domains',
    'Manage user knowledge domains and expertise levels',
    'user_knowledge_domain',
    jsonb_build_object(
        'select', '*, 
        user:users!fk_user_knowledge_domain_user(id, email, full_name),
        domain:knowledge_domain!fk_user_knowledge_domain_knowledge(id, name)',
        'orderBy', jsonb_build_array(
            jsonb_build_object('id', 'expertise', 'desc', true)
        )
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'User',
            'accessorKey', 'user',
            'type', 'object',
            'subColumns', jsonb_build_array(
                jsonb_build_object(
                    'header', 'Name',
                    'accessorKey', 'full_name',
                    'type', 'text'
                ),
                jsonb_build_object(
                    'header', 'Email',
                    'accessorKey', 'email',
                    'type', 'text'
                )
            )
        ),
        jsonb_build_object(
            'header', 'Domain',
            'accessorKey', 'domain',
            'type', 'object',
            'subColumns', jsonb_build_array(
                jsonb_build_object(
                    'header', 'Name',
                    'accessorKey', 'name',
                    'type', 'text'
                )
            )
        ),
        jsonb_build_object(
            'header', 'Expertise',
            'accessorKey', 'expertise',
            'type', 'select',
            'options', jsonb_build_array('beginner', 'intermediate', 'expert')
        ),
        jsonb_build_object(
            'header', 'Years Experience',
            'accessorKey', 'years_experience',
            'type', 'number'
        ),
        jsonb_build_object(
            'header', 'Description',
            'accessorKey', 'description',
            'type', 'textarea'
        ),
        jsonb_build_object(
            'header', 'Credentials',
            'accessorKey', 'credential',
            'type', 'text'
        )
    ),
    ARRAY['admin.users.manage'],
    true
);

-- Add search query relationship
INSERT INTO search_query_relationships (parent_search_query_id, child_search_query_id)
VALUES ('aaaaaaaa-0000-4000-a000-000000000002', 'aaaaaaaa-0000-4000-a000-000000000004');

