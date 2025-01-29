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
        user_details:users!fk_team_members_user(id, full_name, email)'
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Member',
            'accessorKey', 'user_id',
            'aliasName', 'user_details',
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

INSERT INTO search_queries (
    id,
    parent_table,
    parent_field,
    name,
    description,
    base_table,
    query_definition,
    column_definitions,
    permissions_required,
    is_active
) VALUES (
    'aaaaaaaa-0000-4000-a000-000000000004',
    'users',
    'user_id',
    'User Knowledge Domains',
    'Manage user knowledge domains and expertise levels',
    'user_knowledge_domain',
    jsonb_build_object(
        'select', '*, 
        user_domain:knowledge_domain!fk_user_knowledge_domain_knowledge(id, name)',
        'orderBy', jsonb_build_array(
            jsonb_build_object('id', 'expertise', 'desc', true)
        )
    ),
    jsonb_build_array(
        jsonb_build_object(
            'header', 'Knowledge Domain',
            'accessorKey', 'knowledge_domain_id',
            'aliasName', 'user_domain',
            'type', 'uuid',
            'foreignKey', jsonb_build_object(
                'table', 'knowledge_domain',
                'value', 'id',
                'label', 'name'
            )
        ),  -- Added missing closing parenthesis here
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

('aaaaaaaa-0000-4000-a000-000000000002', 'aaaaaaaa-0000-4000-a000-000000000004'),

-- IntelliSUppot comment template
('aaaaaaaa-bbbb-cccc-dddd-444444444444', 'cccccccc-1111-2222-3333-444444444444');
