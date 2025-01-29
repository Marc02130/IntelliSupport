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
        'arise-duct-snore@techstart.io',
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
        'spoiling-poem-cozy@acme.com',
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

-- Users (Customers)
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
) VALUES 
-- Customer 1
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
    'customer1@techcorp.com',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Customer One',
        'role', 'customer'
    )
),
-- Customer 2
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
    'customer2@healthnet.org',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Customer Two',
        'role', 'customer'
    )
);

-- Users (Agents)
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
) VALUES 
-- Agent 1
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
    'agent1@support.com',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Agent One',
        'role', 'agent'
    )
),
-- Agent 2
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
    'agent2@support.com',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Agent Two',
        'role', 'agent'
    )
),
-- Agent 3
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
    'agent3@support.com',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Agent Three',
        'role', 'agent'
    )
);

-- Users (Admins)
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
) VALUES 
-- Admin 1
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
    'admin1@support.com',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Admin One',
        'role', 'admin'
    )
),
-- Admin 2
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
    'admin2@support.com',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Admin Two',
        'role', 'admin'
    )
);

-- Additional Customers
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
) VALUES 
-- Customer 3 (TechCorp)
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
    'customer3@techcorp.com',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Customer Three',
        'role', 'customer'
    )
),
-- Customer 4 (HealthNet)
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
    'customer4@healthnet.org',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Customer Four',
        'role', 'customer'
    )
);

-- Customers 10-14 (continuing from Customer 9)
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
) VALUES 
-- Customer 10 (HealthNet)
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
    'maria.med@healthnet.org',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Maria Medical',
        'role', 'customer'
    )
),
-- Customer 11 (EduLearn)
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
    'peter.prof@edulearn.edu',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Peter Professor',
        'role', 'customer'
    )
),
-- Customer 12 (RetailPro)
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
    'lisa.store@retailpro.com',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Lisa Store',
        'role', 'customer'
    )
),
-- Customer 13 (TechCorp)
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
    'mike.sys@techcorp.com',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Mike Systems',
        'role', 'customer'
    )
),
-- Customer 14 (HealthNet)
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
    'rachel.health@healthnet.org',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Rachel Health',
        'role', 'customer'
    )
);

-- Additional Customers (10 more)
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
) VALUES 
-- Customer 5 (TechCorp)
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
    'sarah.tech@techcorp.com',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Sarah Tech',
        'role', 'customer'
    )
),
-- Customer 6 (HealthNet)
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
    'james.health@healthnet.org',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'James Health',
        'role', 'customer'
    )
);

-- Customers 7-14
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
) VALUES 
-- Customer 7 (EduLearn)
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
    'emma.edu@edulearn.edu',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Emma Educator',
        'role', 'customer'
    )
),
-- Customer 8 (RetailPro)
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
    'robert.retail@retailpro.com',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'Robert Retail',
        'role', 'customer'
    )
),
-- Additional customers for each organization...
-- Customer 9 (TechCorp)
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
    'david.dev@techcorp.com',
    crypt('Password1@#', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    NOW(),
    'authenticated',
    'authenticated',
    jsonb_build_object(
        'full_name', 'David Developer',
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
    ('0ef7b9c5-f2cd-4dd4-9f33-ff71603fec7f', 'IntelliSupport', 'intellisupport.com', 'The world''s leading CRM solution for widget makers'),
    ('0ef7b9c5-f2cd-4dd4-9f43-ff71603fec7a', 'TechCorp', 'techcorp.com', 'Enterprise software solutions'),
    ('0ef7b9c5-f2cd-4dd4-9f53-ff71603fec7b', 'HealthNet', 'healthnet.org', 'Healthcare services provider'),
    ('0ef7b9c5-f2cd-4dd4-9f63-ff71603fec7c', 'EduLearn', 'edulearn.edu', 'Online education platform'),
    ('0ef7b9c5-f2cd-4dd4-9f73-ff71603fec7d', 'RetailPro', 'retailpro.com', 'Retail management solutions');

-- Assign Organizations to Users
UPDATE public.users 
SET organization_id = '0ef7b9c5-f2cd-4dd4-9f33-ff71603fec7f'
WHERE role = 'admin' OR role = 'agent';

UPDATE public.users 
SET organization_id = (
    SELECT id 
    FROM public.organizations 
    WHERE domain = SPLIT_PART(public.users.email, '@', 2)
)
WHERE role = 'customer';
