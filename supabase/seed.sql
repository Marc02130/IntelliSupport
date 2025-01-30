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

-- Tickets and Comments
INSERT INTO tickets (subject, description, status, priority, requester_id, organization_id)
SELECT 
    'Performance Issue with Dashboard',
    'The dashboard is loading very slowly, taking more than 30 seconds to display data.',
    'open',
    'high',
    u.id,
    o.id
FROM auth.users u, organizations o
WHERE u.email = 'customer1@techcorp.com' AND o.name = 'TechCorp';

INSERT INTO tickets (subject, description, status, priority, requester_id, organization_id)
SELECT 
    'Cannot Access Admin Panel',
    'Getting "Access Denied" error when trying to access the admin panel.',
    'open',
    'medium',
    u.id,
    o.id
FROM auth.users u, organizations o
WHERE u.email = 'customer2@healthnet.org' AND o.name = 'HealthNet';

-- Add tags to tickets
INSERT INTO ticket_tags (ticket_id, tag_id)
SELECT t.id, tag.id
FROM tickets t, tags tag
WHERE t.subject = 'Performance Issue with Dashboard'
AND tag.name IN ('performance', 'bug');

INSERT INTO ticket_tags (ticket_id, tag_id)
SELECT t.id, tag.id
FROM tickets t, tags tag
WHERE t.subject = 'Cannot Access Admin Panel'
AND tag.name IN ('user-access', 'security');

-- Add comments to tickets
INSERT INTO ticket_comments (ticket_id, content, author_id)
SELECT 
    t.id,
    'Have you cleared your browser cache and tried again?',
    u.id
FROM tickets t, auth.users u
WHERE t.subject = 'Performance Issue with Dashboard'
AND u.email = 'agent1@support.com';

-- Agent Styles
INSERT INTO agent_style (agent_id, style_name, style_description, tone_preferences, language_patterns, effectiveness_metrics)
SELECT 
    u.id,
    'Technical Expert',
    'Detailed technical explanations with clear steps',
    '{"formality": "high", "empathy": "medium", "detail": "high"}'::jsonb,
    ARRAY['I understand the technical challenge', 'Let me explain step by step', 'Here''s what''s happening technically'],
    '{"resolution_rate": 0.92, "satisfaction_score": 4.5}'::jsonb
FROM auth.users u
WHERE u.email = 'agent1@support.com';

INSERT INTO agent_style (agent_id, style_name, style_description, tone_preferences, language_patterns, effectiveness_metrics)
SELECT 
    u.id,
    'Customer Focused',
    'Empathetic and solution-oriented approach',
    '{"formality": "medium", "empathy": "high", "detail": "medium"}'::jsonb,
    ARRAY['I''m here to help', 'I understand your concern', 'Let''s solve this together'],
    '{"resolution_rate": 0.88, "satisfaction_score": 4.8}'::jsonb
FROM auth.users u
WHERE u.email = 'agent2@support.com';

-- More Tickets and Comments
INSERT INTO tickets (subject, description, status, priority, requester_id, organization_id)
SELECT 
    'Integration with CRM Failed',
    'The automated sync with our CRM system stopped working after the latest update.',
    'open',
    'high',
    u.id,
    o.id
FROM auth.users u, organizations o
WHERE u.email = 'customer1@techcorp.com' AND o.name = 'TechCorp';

INSERT INTO tickets (subject, description, status, priority, requester_id, organization_id)
SELECT 
    'Need Additional User Licenses',
    'We need to purchase licenses for 5 new team members.',
    'open',
    'low',
    u.id,
    o.id
FROM auth.users u, organizations o
WHERE u.email = 'customer2@healthnet.org' AND o.name = 'HealthNet';

INSERT INTO tickets (subject, description, status, priority, requester_id, organization_id)
SELECT 
    'Security Vulnerability Report',
    'Found potential XSS vulnerability in the comments section.',
    'open',
    'critical',
    u.id,
    o.id
FROM auth.users u, organizations o
WHERE u.email = 'customer3@edulearn.edu' AND o.name = 'EduLearn';

-- Add tags to new tickets
INSERT INTO ticket_tags (ticket_id, tag_id)
SELECT t.id, tag.id
FROM tickets t, tags tag
WHERE t.subject = 'Integration with CRM Failed'
AND tag.name IN ('integration', 'bug', 'urgent');

INSERT INTO ticket_tags (ticket_id, tag_id)
SELECT t.id, tag.id
FROM tickets t, tags tag
WHERE t.subject = 'Need Additional User Licenses'
AND tag.name IN ('billing', 'user-access');

INSERT INTO ticket_tags (ticket_id, tag_id)
SELECT t.id, tag.id
FROM tickets t, tags tag
WHERE t.subject = 'Security Vulnerability Report'
AND tag.name IN ('security', 'urgent', 'bug');

-- Add more comments
INSERT INTO ticket_comments (ticket_id, content, author_id)
SELECT 
    t.id,
    'Could you provide the error logs from the integration attempt?',
    u.id
FROM tickets t, auth.users u
WHERE t.subject = 'Integration with CRM Failed'
AND u.email = 'agent2@support.com';

INSERT INTO ticket_comments (ticket_id, content, author_id)
SELECT 
    t.id,
    'I''ll prepare a quote for the additional licenses right away.',
    u.id
FROM tickets t, auth.users u
WHERE t.subject = 'Need Additional User Licenses'
AND u.email = 'agent3@support.com';

-- Message Templates
INSERT INTO message_templates (template_text, context_type, effectiveness_score) VALUES
('I understand you''re experiencing {issue_type}. Let me help you resolve this step by step.', 
 'initial_response', 
 0.85),
('I''ve reviewed your {issue_type} and I''ll need some additional information to better assist you: {required_info}', 
 'information_request', 
 0.78),
('Thank you for providing those details. I''ve identified the root cause: {cause}. Here''s how we can fix it: {solution}', 
 'solution_proposal', 
 0.92),
('Just following up on your {issue_type} ticket. Have you had a chance to try the solution I proposed?', 
 'follow_up', 
 0.75);

-- Customer Preferences
INSERT INTO customer_preferences (customer_id, preferred_style, preferred_times, communication_frequency)
SELECT 
    u.id,
    'technical',
    '{"preferred_hours": ["9:00", "17:00"], "timezone": "UTC"}'::jsonb,
    'daily'
FROM auth.users u
WHERE u.email = 'customer1@techcorp.com';

INSERT INTO customer_preferences (customer_id, preferred_style, preferred_times, communication_frequency)
SELECT 
    u.id,
    'simplified',
    '{"preferred_hours": ["13:00", "20:00"], "timezone": "UTC+1"}'::jsonb,
    'weekly'
FROM auth.users u
WHERE u.email = 'customer2@healthnet.org';

-- Add one more agent style
INSERT INTO agent_style (agent_id, style_name, style_description, tone_preferences, language_patterns, effectiveness_metrics)
SELECT 
    u.id,
    'Security Specialist',
    'Security-focused communication with clear compliance considerations',
    '{"formality": "high", "empathy": "medium", "detail": "very_high", "compliance_focus": "high"}'::jsonb,
    ARRAY['Let me address your security concern', 'Following security best practices', 'To ensure compliance'],
    '{"resolution_rate": 0.95, "satisfaction_score": 4.6, "compliance_score": 0.99}'::jsonb
FROM auth.users u
WHERE u.email = 'agent3@support.com';

-- Add more varied tickets
INSERT INTO tickets (subject, description, status, priority, requester_id, organization_id)
VALUES
-- TechCorp Tickets
(
    'API Rate Limiting Issues',
    'We''re hitting API rate limits during peak hours, causing service disruptions.',
    'open',
    'high',
    (SELECT id FROM auth.users WHERE email = 'customer1@techcorp.com'),
    (SELECT id FROM organizations WHERE name = 'TechCorp')
),
(
    'Feature Request: Batch Processing',
    'Would like to add batch processing capability to reduce API calls.',
    'open',
    'medium',
    (SELECT id FROM auth.users WHERE email = 'customer1@techcorp.com'),
    (SELECT id FROM organizations WHERE name = 'TechCorp')
),

-- HealthNet Tickets
(
    'Data Export Failing',
    'Weekly data export job has been failing for the last 2 runs.',
    'pending',
    'high',
    (SELECT id FROM auth.users WHERE email = 'customer2@healthnet.org'),
    (SELECT id FROM organizations WHERE name = 'HealthNet')
),
(
    'SSO Integration Not Working',
    'Users unable to login through SSO since latest update.',
    'open',
    'urgent',
    (SELECT id FROM auth.users WHERE email = 'customer2@healthnet.org'),
    (SELECT id FROM organizations WHERE name = 'HealthNet')
),

-- EduLearn Tickets
(
    'Performance Degradation in Search',
    'Search functionality taking >10s to return results.',
    'open',
    'high',
    (SELECT id FROM auth.users WHERE email = 'customer3@edulearn.edu'),
    (SELECT id FROM organizations WHERE name = 'EduLearn')
);

-- Add tags to new tickets
INSERT INTO ticket_tags (ticket_id, tag_id)
SELECT t.id, tag.id
FROM tickets t, tags tag
WHERE t.subject = 'API Rate Limiting Issues'
AND tag.name IN ('performance', 'configuration', 'integration');

INSERT INTO ticket_tags (ticket_id, tag_id)
SELECT t.id, tag.id
FROM tickets t, tags tag
WHERE t.subject = 'Feature Request: Batch Processing'
AND tag.name IN ('feature-request', 'integration');

INSERT INTO ticket_tags (ticket_id, tag_id)
SELECT t.id, tag.id
FROM tickets t, tags tag
WHERE t.subject = 'Data Export Failing'
AND tag.name IN ('bug', 'integration');

INSERT INTO ticket_tags (ticket_id, tag_id)
SELECT t.id, tag.id
FROM tickets t, tags tag
WHERE t.subject = 'SSO Integration Not Working'
AND tag.name IN ('security', 'urgent', 'integration');

INSERT INTO ticket_tags (ticket_id, tag_id)
SELECT t.id, tag.id
FROM tickets t, tags tag
WHERE t.subject = 'Performance Degradation in Search'
AND tag.name IN ('performance', 'urgent');

-- Add comments to new tickets
INSERT INTO ticket_comments (ticket_id, content, author_id, is_private)
SELECT 
    t.id,
    'I''ve checked the API logs and noticed spikes around 2PM UTC. Let''s implement rate limiting on your end first.',
    (SELECT id FROM auth.users WHERE email = 'agent1@support.com'),
    false
FROM tickets t
WHERE t.subject = 'API Rate Limiting Issues';

INSERT INTO ticket_comments (ticket_id, content, author_id, is_private)
SELECT 
    t.id,
    'Internal Note: Need to escalate this to the platform team for rate limit adjustment.',
    (SELECT id FROM auth.users WHERE email = 'agent1@support.com'),
    true
FROM tickets t
WHERE t.subject = 'API Rate Limiting Issues';

INSERT INTO ticket_comments (ticket_id, content, author_id, is_private)
SELECT 
    t.id,
    'This is a great suggestion. I''ve created a feature request ticket with our development team.',
    (SELECT id FROM auth.users WHERE email = 'agent2@support.com'),
    false
FROM tickets t
WHERE t.subject = 'Feature Request: Batch Processing';

INSERT INTO ticket_comments (ticket_id, content, author_id, is_private)
SELECT 
    t.id,
    'Investigating the SSO logs now. Can you confirm if this affects all users or specific roles?',
    (SELECT id FROM auth.users WHERE email = 'agent3@support.com'),
    false
FROM tickets t
WHERE t.subject = 'SSO Integration Not Working';

-- Add ticket routing history
INSERT INTO ticket_routing_history (ticket_id, assigned_to, confidence_score, routing_factors, was_reassigned)
SELECT 
    t.id,
    (SELECT id FROM auth.users WHERE email = 'agent1@support.com'),
    0.92,
    '{"tags": ["performance", "configuration"], "priority": "high", "agent_expertise": ["System Optimization"]}'::jsonb,
    false
FROM tickets t
WHERE t.subject = 'API Rate Limiting Issues';

INSERT INTO ticket_routing_history (ticket_id, assigned_to, confidence_score, routing_factors, was_reassigned)
SELECT 
    t.id,
    (SELECT id FROM auth.users WHERE email = 'agent3@support.com'),
    0.88,
    '{"tags": ["security"], "priority": "urgent", "agent_expertise": ["Security"]}'::jsonb,
    false
FROM tickets t
WHERE t.subject = 'SSO Integration Not Working';

-- Additional Agent Styles
INSERT INTO agent_style (agent_id, style_name, style_description, tone_preferences, language_patterns, effectiveness_metrics)
SELECT 
    u.id,
    'Efficiency Expert',
    'Quick, precise solutions with minimal back-and-forth',
    '{"formality": "medium", "empathy": "low", "detail": "high", "efficiency": "very_high"}'::jsonb,
    ARRAY['Let''s solve this quickly', 'Here''s what you need to do', 'The fastest solution is'],
    '{"resolution_rate": 0.94, "satisfaction_score": 4.2, "avg_resolution_time": "45m"}'::jsonb
FROM auth.users u
WHERE u.email = 'agent2@support.com';

INSERT INTO agent_style (agent_id, style_name, style_description, tone_preferences, language_patterns, effectiveness_metrics)
SELECT 
    u.id,
    'Educational Approach',
    'Teaches while solving to prevent future issues',
    '{"formality": "medium", "empathy": "high", "detail": "very_high", "educational": "high"}'::jsonb,
    ARRAY['Let me explain why this happens', 'This will help prevent future issues', 'Here''s how this works'],
    '{"resolution_rate": 0.89, "satisfaction_score": 4.7, "knowledge_transfer": 0.92}'::jsonb
FROM auth.users u
WHERE u.email = 'agent1@support.com';

-- Additional Customer Preferences
INSERT INTO customer_preferences (customer_id, preferred_style, preferred_times, communication_frequency)
SELECT 
    u.id,
    'detailed',
    '{"preferred_hours": ["14:00", "22:00"], "timezone": "UTC+2", "preferred_days": ["Monday", "Wednesday", "Friday"]}'::jsonb,
    'twice_weekly'
FROM auth.users u
WHERE u.email = 'customer3@techcorp.com';

INSERT INTO customer_preferences (customer_id, preferred_style, preferred_times, communication_frequency)
SELECT 
    u.id,
    'brief',
    '{"preferred_hours": ["8:00", "16:00"], "timezone": "UTC-5", "preferred_days": ["Tuesday", "Thursday"]}'::jsonb,
    'urgent_only'
FROM auth.users u
WHERE u.email = 'customer4@healthnet.org';

-- Additional Message Templates
INSERT INTO message_templates (template_text, context_type, effectiveness_score) VALUES
('Our team has identified a potential security concern: {issue}. Please review and implement the following recommendations: {recommendations}',
 'security_alert',
 0.95),
('Your feature request has been reviewed. Here''s our assessment: {assessment}. Timeline for implementation: {timeline}',
 'feature_response',
 0.88),
('We''ve noticed some unusual patterns in your usage: {patterns}. To optimize performance, we recommend: {recommendations}',
 'optimization_suggestion',
 0.82),
('Regular maintenance is scheduled for {date} from {start_time} to {end_time}. Impact: {impact}. Preparation steps: {steps}',
 'maintenance_notice',
 0.91);

-- Additional Message Templates for Sales/Marketing
INSERT INTO message_templates (template_text, context_type, effectiveness_score) VALUES
('Based on your usage patterns, our {widget_name} widget could help improve your workflow by {benefit}. Would you like to schedule a demo?',
 'upsell_opportunity',
 0.86),
('We noticed you''re using {current_feature}. Our new {widget_name} widget integrates seamlessly and adds {new_capability}.',
 'cross_sell',
 0.83),
('Thanks for your interest in {widget_name}! Here''s a quick overview of how it could benefit your team: {benefits}',
 'product_introduction',
 0.89),
('Early access to our new {widget_name} widget is now available. As a valued customer, you''re invited to try it first: {preview_link}',
 'early_access_invite',
 0.92),
('Your feedback on {widget_name} has been invaluable. We''ve just released these improvements you requested: {updates}',
 'product_update',
 0.94);


-- Customer Preferences for new customers
INSERT INTO customer_preferences (customer_id, preferred_style, preferred_times, communication_frequency)
VALUES
-- Emma (EduLearn)
(
    (SELECT id FROM auth.users WHERE email = 'emma.edu@edulearn.edu'),
    'simplified',
    '{"preferred_hours": ["8:00", "16:00"], "timezone": "UTC-5", "preferred_days": ["Monday", "Wednesday", "Friday"]}'::jsonb,
    'weekly'
),
-- Robert (RetailPro)
(
    (SELECT id FROM auth.users WHERE email = 'robert.retail@retailpro.com'),
    'technical',
    '{"preferred_hours": ["9:00", "18:00"], "timezone": "UTC-4", "preferred_days": ["Tuesday", "Thursday"]}'::jsonb,
    'daily'
),
-- David (TechCorp)
(
    (SELECT id FROM auth.users WHERE email = 'david.dev@techcorp.com'),
    'detailed',
    '{"preferred_hours": ["11:00", "20:00"], "timezone": "UTC-7", "preferred_days": ["Monday", "Tuesday", "Thursday"]}'::jsonb,
    'daily'
);

-- Continue with similar patterns for customers 10-14...

-- Create public.users entries for customers 10-14

-- Customer Preferences for customers 10-14
INSERT INTO customer_preferences (customer_id, preferred_style, preferred_times, communication_frequency)
VALUES
-- Maria (HealthNet)
(
    (SELECT id FROM auth.users WHERE email = 'maria.med@healthnet.org'),
    'detailed',
    '{"preferred_hours": ["7:00", "15:00"], "timezone": "UTC-5", "preferred_days": ["Monday", "Tuesday", "Wednesday"]}'::jsonb,
    'daily'
),
-- Peter (EduLearn)
(
    (SELECT id FROM auth.users WHERE email = 'peter.prof@edulearn.edu'),
    'technical',
    '{"preferred_hours": ["13:00", "21:00"], "timezone": "UTC-6", "preferred_days": ["Tuesday", "Thursday", "Friday"]}'::jsonb,
    'twice_weekly'
),
-- Lisa (RetailPro)
(
    (SELECT id FROM auth.users WHERE email = 'lisa.store@retailpro.com'),
    'simplified',
    '{"preferred_hours": ["8:00", "17:00"], "timezone": "UTC-7", "preferred_days": ["Monday", "Wednesday", "Friday"]}'::jsonb,
    'weekly'
),
-- Mike (TechCorp)
(
    (SELECT id FROM auth.users WHERE email = 'mike.sys@techcorp.com'),
    'technical',
    '{"preferred_hours": ["10:00", "19:00"], "timezone": "UTC-8", "preferred_days": ["Tuesday", "Thursday"]}'::jsonb,
    'daily'
),
-- Rachel (HealthNet)
(
    (SELECT id FROM auth.users WHERE email = 'rachel.health@healthnet.org'),
    'detailed',
    '{"preferred_hours": ["9:00", "18:00"], "timezone": "UTC-5", "preferred_days": ["Monday", "Wednesday", "Friday"]}'::jsonb,
    'urgent_only'
);

-- Communication History
INSERT INTO communication_history (customer_id, message_text, template_id, sent_at, response_received_at, effectiveness_metrics)
SELECT 
    (SELECT id FROM auth.users WHERE email = 'customer1@techcorp.com'),
    'I understand you''re experiencing performance issues with the dashboard. Let me help you resolve this step by step.',
    mt.id,
    NOW() - INTERVAL '2 days',
    NOW() - INTERVAL '1 day',
    '{"response_time_minutes": 45, "resolution_achieved": true, "customer_satisfaction": 4}'::jsonb
FROM tickets t, message_templates mt
WHERE t.subject = 'Performance Issue with Dashboard'
AND mt.context_type = 'initial_response';

-- Additional Communication History
INSERT INTO communication_history (customer_id, message_text, template_id, sent_at, response_received_at, effectiveness_metrics)
SELECT 
    (SELECT id FROM auth.users WHERE email = 'customer2@healthnet.org'),
    'We''ve identified the root cause of the performance issue. It appears to be related to the recent database optimization.',
    mt.id,
    NOW() - INTERVAL '3 days',
    NOW() - INTERVAL '2 days 23 hours',
    '{"response_time_minutes": 15, "resolution_achieved": true, "customer_satisfaction": 5, "solution_implemented": true}'::jsonb
FROM tickets t, message_templates mt
WHERE t.subject = 'Performance Degradation in Search'
AND mt.context_type = 'solution_proposal';

-- Continue with all existing queries, just adding customer_id...
INSERT INTO communication_history (customer_id, message_text, template_id, sent_at, response_received_at, effectiveness_metrics)
SELECT 
    (SELECT id FROM auth.users WHERE email = 'customer2@healthnet.org'),
    'Your SSO integration issue has been escalated to our security team. They''re investigating the root cause.',
    mt.id,
    NOW() - INTERVAL '1 day',
    NOW() - INTERVAL '23 hours',
    '{"response_time_minutes": 30, "resolution_achieved": false, "escalation_needed": true}'::jsonb
FROM tickets t, message_templates mt
WHERE t.subject = 'SSO Integration Not Working'
AND mt.context_type = 'initial_response';

-- Keep all other existing queries, just adding customer_id to each...

-- Additional Communication History entries
INSERT INTO communication_history (customer_id, message_text, template_id, sent_at, response_received_at, effectiveness_metrics)
VALUES
-- Maria's communications
(
    (SELECT id FROM auth.users WHERE email = 'maria.med@healthnet.org'),
    'Based on your usage patterns, our Healthcare Analytics Widget could improve patient data processing by 40%.',
    (SELECT id FROM message_templates WHERE context_type = 'upsell_opportunity'),
    NOW() - INTERVAL '8 days',
    NOW() - INTERVAL '7 days 23 hours',
    '{"response_time_minutes": 35, "interest_level": "high", "demo_scheduled": true, "potential_value": 12000}'::jsonb
),
(
    (SELECT id FROM auth.users WHERE email = 'maria.med@healthnet.org'),
    'The new HIPAA compliance features in our Security Widget would streamline your audit processes.',
    (SELECT id FROM message_templates WHERE context_type = 'product_introduction'),
    NOW() - INTERVAL '6 days',
    NOW() - INTERVAL '5 days 22 hours',
    '{"response_time_minutes": 42, "compliance_interest": true, "follow_up_scheduled": true}'::jsonb
),

-- Peter's communications
(
    (SELECT id FROM auth.users WHERE email = 'peter.prof@edulearn.edu'),
    'Our new Education Analytics Dashboard shows promising results for student engagement tracking.',
    (SELECT id FROM message_templates WHERE context_type = 'product_update'),
    NOW() - INTERVAL '7 days',
    NOW() - INTERVAL '6 days 23 hours',
    '{"response_time_minutes": 28, "feature_adoption": true, "satisfaction_score": 4.8}'::jsonb
),
(
    (SELECT id FROM auth.users WHERE email = 'peter.prof@edulearn.edu'),
    'Would you like early access to our new Curriculum Planning Widget? It integrates with your existing workflows.',
    (SELECT id FROM message_templates WHERE context_type = 'early_access_invite'),
    NOW() - INTERVAL '5 days',
    NOW() - INTERVAL '4 days 22 hours',
    '{"response_time_minutes": 45, "early_access_accepted": true}'::jsonb
),

-- Lisa's communications
(
    (SELECT id FROM auth.users WHERE email = 'lisa.store@retailpro.com'),
    'The Inventory Optimization Widget could help prevent the stockout issues you mentioned.',
    (SELECT id FROM message_templates WHERE context_type = 'solution_proposal'),
    NOW() - INTERVAL '6 days',
    NOW() - INTERVAL '5 days 23 hours',
    '{"response_time_minutes": 32, "solution_implemented": true, "roi_projected": 15000}'::jsonb
),
(
    (SELECT id FROM auth.users WHERE email = 'lisa.store@retailpro.com'),
    'Our new POS Integration Widget supports real-time inventory updates across all channels.',
    (SELECT id FROM message_templates WHERE context_type = 'cross_sell'),
    NOW() - INTERVAL '4 days',
    NOW() - INTERVAL '3 days 22 hours',
    '{"response_time_minutes": 38, "integration_interest": true}'::jsonb
),

-- Mike's communications
(
    (SELECT id FROM auth.users WHERE email = 'mike.sys@techcorp.com'),
    'The System Performance Widget has identified several optimization opportunities in your infrastructure.',
    (SELECT id FROM message_templates WHERE context_type = 'optimization_suggestion'),
    NOW() - INTERVAL '5 days',
    NOW() - INTERVAL '4 days 23 hours',
    '{"response_time_minutes": 25, "optimization_implemented": true, "performance_improvement": "35%"}'::jsonb
),
(
    (SELECT id FROM auth.users WHERE email = 'mike.sys@techcorp.com'),
    'Would you like to beta test our new Cloud Resource Optimization Widget?',
    (SELECT id FROM message_templates WHERE context_type = 'early_access_invite'),
    NOW() - INTERVAL '3 days',
    NOW() - INTERVAL '2 days 22 hours',
    '{"response_time_minutes": 40, "beta_participation": true}'::jsonb
),

-- Rachel's communications
(
    (SELECT id FROM auth.users WHERE email = 'rachel.health@healthnet.org'),
    'Our Patient Data Analytics Widget could help streamline your reporting processes.',
    (SELECT id FROM message_templates WHERE context_type = 'product_introduction'),
    NOW() - INTERVAL '4 days',
    NOW() - INTERVAL '3 days 23 hours',
    '{"response_time_minutes": 30, "demo_scheduled": true, "potential_value": 18000}'::jsonb
),
(
    (SELECT id FROM auth.users WHERE email = 'rachel.health@healthnet.org'),
    'The latest security updates include enhanced PHI protection features you requested.',
    (SELECT id FROM message_templates WHERE context_type = 'product_update'),
    NOW() - INTERVAL '2 days',
    NOW() - INTERVAL '1 day 23 hours',
    '{"response_time_minutes": 35, "feature_activated": true, "compliance_score": 0.98}'::jsonb
),

-- Additional communications for existing customers
(
    (SELECT id FROM auth.users WHERE email = 'sarah.tech@techcorp.com'),
    'The new API Management Widget includes the batch processing feature you requested.',
    (SELECT id FROM message_templates WHERE context_type = 'feature_response'),
    NOW() - INTERVAL '3 days',
    NOW() - INTERVAL '2 days 23 hours',
    '{"response_time_minutes": 28, "feature_satisfaction": 4.9, "implementation_started": true}'::jsonb
),
(
    (SELECT id FROM auth.users WHERE email = 'sarah.tech@techcorp.com'),
    'Would you like to schedule a technical review of the new rate limiting features?',
    (SELECT id FROM message_templates WHERE context_type = 'follow_up'),
    NOW() - INTERVAL '1 day',
    NOW() - INTERVAL '22 hours',
    '{"response_time_minutes": 42, "technical_review_scheduled": true}'::jsonb
),

-- Emma's additional communications
(
    (SELECT id FROM auth.users WHERE email = 'emma.edu@edulearn.edu'),
    'The Learning Analytics Widget shows a 25% improvement in student engagement metrics.',
    (SELECT id FROM message_templates WHERE context_type = 'optimization_suggestion'),
    NOW() - INTERVAL '4 days',
    NOW() - INTERVAL '3 days 23 hours',
    '{"response_time_minutes": 33, "insights_implemented": true, "impact_score": 4.7}'::jsonb
),
(
    (SELECT id FROM auth.users WHERE email = 'emma.edu@edulearn.edu'),
    'Our new Curriculum Integration Widget could streamline your content delivery process.',
    (SELECT id FROM message_templates WHERE context_type = 'cross_sell'),
    NOW() - INTERVAL '2 days',
    NOW() - INTERVAL '1 day 22 hours',
    '{"response_time_minutes": 38, "demo_requested": true, "potential_value": 9000}'::jsonb
),

-- Robert's additional communications
(
    (SELECT id FROM auth.users WHERE email = 'robert.retail@retailpro.com'),
    'The latest Retail Analytics Dashboard shows potential revenue opportunities in your evening shifts.',
    (SELECT id FROM message_templates WHERE context_type = 'optimization_suggestion'),
    NOW() - INTERVAL '5 days',
    NOW() - INTERVAL '4 days 23 hours',
    '{"response_time_minutes": 29, "analysis_reviewed": true, "projected_impact": 25000}'::jsonb
),
(
    (SELECT id FROM auth.users WHERE email = 'robert.retail@retailpro.com'),
    'Would you like to explore our new Inventory Forecasting Widget? It integrates with your existing POS.',
    (SELECT id FROM message_templates WHERE context_type = 'product_introduction'),
    NOW() - INTERVAL '3 days',
    NOW() - INTERVAL '2 days 22 hours',
    '{"response_time_minutes": 36, "demo_scheduled": true, "potential_value": 15000}'::jsonb
),

-- David's additional communications
(
    (SELECT id FROM auth.users WHERE email = 'david.dev@techcorp.com'),
    'Our new Development Analytics Widget identified several optimization opportunities in your CI/CD pipeline.',
    (SELECT id FROM message_templates WHERE context_type = 'optimization_suggestion'),
    NOW() - INTERVAL '6 days',
    NOW() - INTERVAL '5 days 23 hours',
    '{"response_time_minutes": 31, "optimization_implemented": true, "efficiency_gain": "28%"}'::jsonb
),
(
    (SELECT id FROM auth.users WHERE email = 'david.dev@techcorp.com'),
    'The Code Quality Widget integration is showing positive results. Would you like to review the metrics?',
    (SELECT id FROM message_templates WHERE context_type = 'follow_up'),
    NOW() - INTERVAL '4 days',
    NOW() - INTERVAL '3 days 23 hours',
    '{"response_time_minutes": 27, "review_scheduled": true, "quality_improvement": "15%"}'::jsonb
),

-- James's additional communications
(
    (SELECT id FROM auth.users WHERE email = 'james.health@healthnet.org'),
    'The Health Analytics Widget suggests optimizing your patient scheduling workflow.',
    (SELECT id FROM message_templates WHERE context_type = 'optimization_suggestion'),
    NOW() - INTERVAL '7 days',
    NOW() - INTERVAL '6 days 23 hours',
    '{"response_time_minutes": 34, "workflow_optimized": true, "efficiency_gain": "20%"}'::jsonb
),
(
    (SELECT id FROM auth.users WHERE email = 'james.health@healthnet.org'),
    'Would you like to preview our new Patient Engagement Widget? It integrates with your existing portal.',
    (SELECT id FROM message_templates WHERE context_type = 'early_access_invite'),
    NOW() - INTERVAL '5 days',
    NOW() - INTERVAL '4 days 22 hours',
    '{"response_time_minutes": 39, "preview_scheduled": true, "potential_value": 20000}'::jsonb
)
;

-- Add message templates
INSERT INTO message_templates (
    id,
    template_text,
    context_type,
    metadata,
    effectiveness_score
) VALUES 
(
    'e3a805a6-520c-4e00-931c-9a35d98d90e4',
    'Hi {customer_name}, following up on your recent {request_type}. We''ve made some updates you might be interested in.',
    'follow_up',
    jsonb_build_object(
        'variables', ARRAY['customer_name', 'request_type'],
        'suggested_use', 'Feature updates and improvements'
    ),
    4.5
),
(
    'd72265d0-f807-4e30-b592-514fef924e97',
    'Thanks for your feedback! We''ve implemented the changes you suggested.',
    'confirmation',
    jsonb_build_object(
        'variables', ARRAY[]::text[],
        'suggested_use', 'Confirming implemented changes'
    ),
    4.7
);

-- Then add communication history records
INSERT INTO communication_history (
    id,
    customer_id,
    message_text,
    template_id,
    sent_at,
    response_received_at,
    effectiveness_metrics
) VALUES 
-- Last week communications
(
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'peter.prof@edulearn.edu'),
    'Hi John, following up on your recent feature request. We''ve made some updates you might be interested in.',
    'e3a805a6-520c-4e00-931c-9a35d98d90e4',
    NOW() - INTERVAL '7 days',
    NOW() - INTERVAL '6 days 23 hours',
    jsonb_build_object(
        'customer_satisfaction', 4.5,
        'response_received', true,
        'response_time_hours', 1,
        'engagement_level', 'high'
    )
),
(
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'peter.prof@edulearn.edu'),
    'Thanks for your feedback! We''ve implemented the changes you suggested.',
    'd72265d0-f807-4e30-b592-514fef924e97',
    NOW() - INTERVAL '5 days',
    NOW() - INTERVAL '4 days 22 hours',
        jsonb_build_object(
        'customer_satisfaction', 4.8,
        'response_received', true,
        'response_time_hours', 2,
        'engagement_level', 'high'
    )
),
-- Last month communications
(
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'peter.prof@edulearn.edu'),
    'Monthly product update: New features and improvements',
    'e3a805a6-520c-4e00-931c-9a35d98d90e4',
    NOW() - INTERVAL '30 days',
    NOW() - INTERVAL '29 days 20 hours',
    jsonb_build_object(
        'customer_satisfaction', 4.2,
        'response_received', true,
        'response_time_hours', 4,
        'engagement_level', 'medium'
    )
),
(
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'peter.prof@edulearn.edu'),
    'Early access invitation to our new analytics dashboard',
    'd72265d0-f807-4e30-b592-514fef924e97',
    NOW() - INTERVAL '25 days',
    NOW() - INTERVAL '24 days 23 hours',
    jsonb_build_object(
        'customer_satisfaction', 4.7,
        'response_received', true,
        'response_time_hours', 1,
        'engagement_level', 'high'
    )
),
-- Two months ago
(
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'peter.prof@edulearn.edu'),
    'Quick check-in on your experience with the latest features',
    'e3a805a6-520c-4e00-931c-9a35d98d90e4',
    NOW() - INTERVAL '60 days',
    NOW() - INTERVAL '59 days 22 hours',
        jsonb_build_object(
        'customer_satisfaction', 4.0,
        'response_received', true,
        'response_time_hours', 2,
        'engagement_level', 'medium'
    )
),
-- Different times of day to establish patterns
(
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'peter.prof@edulearn.edu'),
    'Morning update on your pending requests',
    'e3a805a6-520c-4e00-931c-9a35d98d90e4',
    NOW() - INTERVAL '15 days' + INTERVAL '9 hours',
    NOW() - INTERVAL '14 days 22 hours',
    jsonb_build_object(
        'customer_satisfaction', 4.6,
        'response_received', true,
        'response_time_hours', 2,
        'engagement_level', 'high'
    )
),
(
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'peter.prof@edulearn.edu'),
    'Afternoon follow-up on feature usage',
    'd72265d0-f807-4e30-b592-514fef924e97',
    NOW() - INTERVAL '10 days' + INTERVAL '14 hours',
    NOW() - INTERVAL '9 days 22 hours',
        jsonb_build_object(
        'customer_satisfaction', 4.4,
        'response_received', true,
        'response_time_hours', 2,
        'engagement_level', 'medium'
    )
),
(
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'peter.prof@edulearn.edu'),
    'Evening summary of today''s updates',
    'e3a805a6-520c-4e00-931c-9a35d98d90e4',
    NOW() - INTERVAL '20 days' + INTERVAL '16 hours',
    NOW() - INTERVAL '19 days 22 hours',
        jsonb_build_object(
        'customer_satisfaction', 4.3,
        'response_received', true,
        'response_time_hours', 2,
        'engagement_level', 'medium'
    )
);
