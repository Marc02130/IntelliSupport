
-- Create initial teams
INSERT INTO public.teams (id, name, description, organization_id) VALUES
('11111111-1111-1111-1111-111111111113', 'Technical Support', 'Primary technical support team', '0ef7b9c5-f2cd-4dd4-9f33-ff71603fec7f'),
('22222222-2222-2222-2222-222222222224', 'Billing Support', 'Billing and account support team', '0ef7b9c5-f2cd-4dd4-9f33-ff71603fec7f'),
('12222222-2222-2222-2222-222222222225', 'Technical Team', 'Handle technical issues', '0ef7b9c5-f2cd-4dd4-9f33-ff71603fec7f'),
('33333333-3333-3333-3333-333333333335', 'Account Team', 'Handle account and billing', '0ef7b9c5-f2cd-4dd4-9f33-ff71603fec7f'),
('44444444-4444-4444-4444-444444444446', 'Security Team', 'Handle security issues', '0ef7b9c5-f2cd-4dd4-9f33-ff71603fec7f');

-- Seed Tags (if not exists)
INSERT INTO public.tags (name)
VALUES 
    ('urgent'),
    ('bug'),
    ('feature-request'),
    ('documentation'),
    ('billing'),
    ('security'),
    ('performance'),
    ('integration'),
    ('documentation'),
    ('user-access'),
    ('configuration')
ON CONFLICT (name) DO NOTHING;

-- Assign members to teams
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

INSERT INTO team_members (team_id, user_id, role) 
SELECT t.id, u.id, 'lead'
FROM teams t, auth.users u 
WHERE t.name = 'Technical Team' AND u.email = 'admin1@support.com';

INSERT INTO team_members (team_id, user_id, role) 
SELECT t.id, u.id, 'lead'
FROM teams t, auth.users u 
WHERE t.name = 'Billing Support' AND u.email = 'marc.breneiser@gauntletai.com';

INSERT INTO team_members (team_id, user_id, role)
SELECT t.id, u.id, 'member'
FROM teams t, auth.users u
WHERE t.name = 'Technical Team' AND u.email IN ('agent1@support.com', 'agent2@support.com');

INSERT INTO team_members (team_id, user_id, role)
SELECT t.id, u.id, 'lead'
FROM teams t, auth.users u
WHERE t.name = 'Account Team' AND u.email = 'admin2@support.com';

INSERT INTO team_members (team_id, user_id, role)
SELECT t.id, u.id, 'member'
FROM teams t, auth.users u
WHERE t.name = 'Account Team' AND u.email = 'agent3@support.com';


-- Add team schedules
-- Technical Team - Mid Shift
INSERT INTO team_schedules (team_id, user_id, start_time, end_time)
SELECT 
    t.id,
    u.id,
    NOW()::date + '10:00'::time,  -- Today at 10 AM
    NOW()::date + '18:00'::time   -- Today at 6 PM
FROM teams t, auth.users u
WHERE t.name = 'Billing Support' 
AND u.email = 'marc.breneiser@gauntletai.com';

INSERT INTO public.team_schedules (team_id, user_id, start_time, end_time)
SELECT 
    '11111111-1111-1111-1111-111111111113',
    id,
    NOW(),
    NOW() + INTERVAL '8 hours'
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'agent';

INSERT INTO team_schedules (team_id, user_id, start_time, end_time)
SELECT 
    t.id,
    u.id,
    NOW()::date + '08:00'::time,  -- Today at 8 AM
    NOW()::date + '16:00'::time   -- Today at 4 PM
FROM teams t, auth.users u
WHERE t.name = 'Technical Team' 
AND u.email = 'agent1@support.com';

-- Technical Team - Mid Shift
INSERT INTO team_schedules (team_id, user_id, start_time, end_time)
SELECT 
    t.id,
    u.id,
    NOW()::date + '10:00'::time,  -- Today at 10 AM
    NOW()::date + '18:00'::time   -- Today at 6 PM
FROM teams t, auth.users u
WHERE t.name = 'Technical Team' 
AND u.email = 'agent2@support.com';

-- Account Team - Late Shift
INSERT INTO team_schedules (team_id, user_id, start_time, end_time)
SELECT 
    t.id,
    u.id,
    NOW()::date + '12:00'::time,  -- Today at 12 PM
    NOW()::date + '20:00'::time   -- Today at 8 PM
FROM teams t, auth.users u
WHERE t.name = 'Account Team' 
AND u.email = 'agent3@support.com';

-- Admin Flexible Hours
INSERT INTO team_schedules (team_id, user_id, start_time, end_time)
SELECT 
    t.id,
    u.id,
    NOW()::date + '09:00'::time,  -- Today at 9 AM
    NOW()::date + '17:00'::time   -- Today at 5 PM
FROM teams t, auth.users u
WHERE t.name IN ('Technical Team', 'Account Team')
AND u.email LIKE 'admin%';


-- Team tags
INSERT INTO team_tags (team_id, tag_id)
SELECT t.id, tag.id
FROM teams t, tags tag
WHERE t.name = 'Technical Team' 
AND tag.name IN ('bug', 'performance', 'integration', 'configuration');

INSERT INTO team_tags (team_id, tag_id)
SELECT t.id, tag.id
FROM teams t, tags tag
WHERE t.name = 'Account Team' 
AND tag.name IN ('billing', 'user-access');

INSERT INTO team_tags (team_id, tag_id)
SELECT t.id, tag.id
FROM teams t, tags tag
WHERE t.name = 'Security Team' 
AND tag.name IN ('security', 'user-access');

INSERT INTO team_tags (team_id, tag_id)
SELECT '11111111-1111-1111-1111-111111111113', tag.id
FROM tags tag
WHERE tag.name IN ('security', 'urgent', 'bug');

INSERT INTO team_tags (team_id, tag_id)
SELECT '22222222-2222-2222-2222-222222222224', tag.id
FROM tags tag
WHERE tag.name IN ('billing');
