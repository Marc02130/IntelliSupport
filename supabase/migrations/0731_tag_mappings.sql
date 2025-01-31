-- Create tag to knowledge domain mapping table
CREATE TABLE IF NOT EXISTS tag_knowledge_mappings (
    tag_id uuid REFERENCES tags(id),
    knowledge_domain_id uuid REFERENCES knowledge_domain(id),
    PRIMARY KEY (tag_id, knowledge_domain_id)
);

-- Add some initial mappings
INSERT INTO tag_knowledge_mappings (tag_id, knowledge_domain_id)
SELECT t.id, kd.id
FROM tags t
CROSS JOIN knowledge_domain kd
WHERE 
    (t.name = 'bug' AND kd.name = 'Technical Support') OR
    (t.name = 'integration' AND kd.name = 'API Integration') OR
    (t.name = 'security' AND kd.name = 'Security') OR
    (t.name = 'billing' AND kd.name = 'Billing') OR
    (t.name = 'performance' AND kd.name = 'System Optimization') OR
    (t.name = 'configuration' AND kd.name = 'Platform Architecture') OR
    (t.name = 'user-access' AND kd.name = 'Data Privacy');
