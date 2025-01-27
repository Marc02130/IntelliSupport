-- Function to get list of tables
CREATE OR REPLACE FUNCTION get_tables()
RETURNS TABLE (name text, schema text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT table_name::text, table_schema::text
  FROM information_schema.tables
  WHERE table_schema = 'public'
  ORDER BY table_name;
END;
$$;

-- Function to get table columns
CREATE OR REPLACE FUNCTION get_table_columns(table_name text)
RETURNS TABLE (
  name text,
  data_type text,
  is_nullable boolean,
  column_default text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    column_name::text,
    data_type::text,
    is_nullable::boolean,
    column_default::text
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = $1
  ORDER BY ordinal_position;
END;
$$; 

-- Add get_user_navigation function
CREATE OR REPLACE FUNCTION public.get_user_navigation()
RETURNS TABLE (
    id UUID,
    name TEXT,
    description TEXT,
    icon TEXT,
    parent_id UUID,
    search_query_id UUID,
    url TEXT,
    sort_order INTEGER,
    permissions_required TEXT[],
    is_active BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_organization TEXT;
BEGIN
    -- Get user's organization name
    SELECT o.name INTO user_organization
    FROM users u
    JOIN organizations o ON o.id = u.organization_id
    WHERE u.id = auth.uid();

    RETURN QUERY
    SELECT DISTINCT
        n.id::UUID,
        n.name::TEXT,
        n.description::TEXT,
        n.icon::TEXT,
        n.parent_id::UUID,
        n.search_query_id::UUID,
        n.url::TEXT,
        n.sort_order::INTEGER,
        n.permissions_required::TEXT[],
        n.is_active::BOOLEAN
    FROM sidebar_navigation n
    WHERE n.is_active = true
    AND (
        -- For "New User" organization, only show dashboard
        (user_organization = 'New User' AND n.url = '/') -- Only show dashboard
        OR
        -- For other organizations, show based on permissions
        (user_organization != 'New User' AND EXISTS (
            SELECT 1 
            FROM auth.users u
            JOIN roles r ON r.name = (u.raw_user_meta_data->>'role')::text
            JOIN role_permissions rp ON rp.role_id = r.id
            JOIN permissions p ON p.id = rp.permission_id
            WHERE u.id = auth.uid()
            AND (
                p.name = ANY(n.permissions_required)
                OR n.permissions_required IS NULL 
                OR array_length(n.permissions_required, 1) IS NULL
            )
        ))
    )
    ORDER BY n.sort_order;
END;
$$;

-- Add trigger to set requester_id on ticket creation
CREATE OR REPLACE FUNCTION set_ticket_requester()
RETURNS TRIGGER AS $$
BEGIN
    NEW.requester_id := auth.uid();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_ticket_requester_trigger
    BEFORE INSERT ON tickets
    FOR EACH ROW
    EXECUTE FUNCTION set_ticket_requester();

-- Add trigger to set author_id on comment creation
CREATE OR REPLACE FUNCTION set_comment_author()
RETURNS TRIGGER AS $$
BEGIN
    NEW.author_id := auth.uid();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_comment_author_trigger
    BEFORE INSERT ON ticket_comments
    FOR EACH ROW
    EXECUTE FUNCTION set_comment_author();

-- Function to set ticket organization from requester
CREATE OR REPLACE FUNCTION set_ticket_organization()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Set organization_id from requester's organization
    NEW.organization_id := (
        SELECT organization_id 
        FROM users 
        WHERE id = NEW.requester_id
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to set organization on ticket creation
DROP TRIGGER IF EXISTS set_ticket_organization_trigger ON tickets;

CREATE TRIGGER set_ticket_organization_trigger
    BEFORE INSERT ON tickets
    FOR EACH ROW
    EXECUTE FUNCTION set_ticket_organization();

-- Function to execute SQL expressions for search queries
CREATE OR REPLACE FUNCTION execute_sql(sql_query text)
RETURNS TABLE (result uuid) 
SECURITY DEFINER
AS $$
BEGIN
  RAISE NOTICE 'Executing query: %', sql_query;
  RETURN QUERY EXECUTE sql_query;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::uuid;
  END IF;
EXCEPTION 
  WHEN OTHERS THEN
    RAISE NOTICE 'Error executing query: %', SQLERRM;
    RETURN QUERY SELECT NULL::uuid;
END;
$$ LANGUAGE plpgsql;

-- Add audit trigger function
CREATE OR REPLACE FUNCTION public.set_audit_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- Skip if audit triggers are disabled
    IF current_setting('session.audit_trigger_enabled', TRUE) = 'FALSE' THEN
        RETURN NEW;
    END IF;

    IF (TG_OP = 'INSERT') THEN
        -- Set created_by if column exists
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = TG_TABLE_NAME 
            AND column_name = 'created_by'
        ) THEN
            NEW.created_by := auth.uid();
        END IF;

        -- Set updated_by if column exists
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = TG_TABLE_NAME 
            AND column_name = 'updated_by'
        ) THEN
            NEW.updated_by := auth.uid();
        END IF;

        -- Set created_at if column exists
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = TG_TABLE_NAME 
            AND column_name = 'created_at'
        ) THEN
            NEW.created_at := CURRENT_TIMESTAMP;
        END IF;

        -- Set updated_at if column exists
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = TG_TABLE_NAME 
            AND column_name = 'updated_at'
        ) THEN
            NEW.updated_at := CURRENT_TIMESTAMP;
        END IF;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Set updated_by if column exists
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = TG_TABLE_NAME 
            AND column_name = 'updated_by'
        ) THEN
            NEW.updated_by := auth.uid();
        END IF;

        -- Set updated_at if column exists
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = TG_TABLE_NAME 
            AND column_name = 'updated_at'
        ) THEN
            NEW.updated_at := CURRENT_TIMESTAMP;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add audit triggers to all tables
CREATE TRIGGER set_organizations_audit
    BEFORE INSERT OR UPDATE ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION public.set_audit_fields();

CREATE TRIGGER set_tickets_audit
    BEFORE INSERT OR UPDATE ON tickets
    FOR EACH ROW
    EXECUTE FUNCTION public.set_audit_fields();

CREATE TRIGGER set_ticket_comments_audit
    BEFORE INSERT OR UPDATE ON ticket_comments
    FOR EACH ROW
    EXECUTE FUNCTION public.set_audit_fields();

CREATE TRIGGER set_ticket_tags_audit
    BEFORE INSERT OR UPDATE ON ticket_tags
    FOR EACH ROW
    EXECUTE FUNCTION public.set_audit_fields();

CREATE TRIGGER set_teams_audit
    BEFORE INSERT OR UPDATE ON teams
    FOR EACH ROW
    EXECUTE FUNCTION public.set_audit_fields();

CREATE TRIGGER set_team_members_audit
    BEFORE INSERT OR UPDATE ON team_members
    FOR EACH ROW
    EXECUTE FUNCTION public.set_audit_fields();

CREATE TRIGGER set_team_tags_audit
    BEFORE INSERT OR UPDATE ON team_tags
    FOR EACH ROW
    EXECUTE FUNCTION public.set_audit_fields();

CREATE TRIGGER set_team_schedules_audit
    BEFORE INSERT OR UPDATE ON team_schedules
    FOR EACH ROW
    EXECUTE FUNCTION public.set_audit_fields();

CREATE TRIGGER set_search_queries_audit
    BEFORE INSERT OR UPDATE ON search_queries
    FOR EACH ROW
    EXECUTE FUNCTION public.set_audit_fields();

CREATE TRIGGER set_sidebar_navigation_audit
    BEFORE INSERT OR UPDATE ON sidebar_navigation
    FOR EACH ROW
    EXECUTE FUNCTION public.set_audit_fields();

-- Add audit logging function
CREATE OR REPLACE FUNCTION public.process_audit_log()
RETURNS TRIGGER AS $$
DECLARE
    old_data JSONB := NULL;
    new_data JSONB := NULL;
    changed_fields TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Skip if audit triggers are disabled
    IF current_setting('session.audit_trigger_enabled', TRUE) = 'FALSE' THEN
        RETURN NEW;
    END IF;

    -- Set old/new data based on operation
    IF (TG_OP = 'DELETE') THEN
        old_data := to_jsonb(OLD);
    ELSIF (TG_OP = 'UPDATE') THEN
        old_data := to_jsonb(OLD);
        new_data := to_jsonb(NEW);
        -- Calculate changed fields
        SELECT ARRAY_AGG(key)
        INTO changed_fields
        FROM jsonb_each(new_data)
        WHERE new_data->key IS DISTINCT FROM old_data->key;
    ELSE
        new_data := to_jsonb(NEW);
    END IF;

    -- Insert audit log entry
    INSERT INTO audit_log (
        table_name,
        record_id,
        operation,
        old_data,
        new_data,
        changed_fields,
        performed_by,
        performed_at
    ) VALUES (
        TG_TABLE_NAME::TEXT,
        CASE
            WHEN TG_OP = 'DELETE' THEN (old_data->>'id')::UUID
            ELSE (new_data->>'id')::UUID
        END,
        TG_OP,
        old_data,
        new_data,
        changed_fields,
        auth.uid(),
        CURRENT_TIMESTAMP
    );

    -- Return appropriate record based on operation
    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add audit triggers for important tables (excluding users)
CREATE TRIGGER audit_tickets
    AFTER INSERT OR UPDATE OR DELETE ON tickets
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_ticket_comments
    AFTER INSERT OR UPDATE OR DELETE ON ticket_comments
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_tags
    AFTER INSERT OR UPDATE OR DELETE ON tags
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_teams
    AFTER INSERT OR UPDATE OR DELETE ON teams
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_team_members
    AFTER INSERT OR UPDATE OR DELETE ON team_members
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_search_queries
    AFTER INSERT OR UPDATE OR DELETE ON search_queries
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_sidebar_navigation
    AFTER INSERT OR UPDATE OR DELETE ON sidebar_navigation
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_roles
    AFTER INSERT OR UPDATE OR DELETE ON roles
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_permissions
    AFTER INSERT OR UPDATE OR DELETE ON permissions
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_role_permissions
    AFTER INSERT OR UPDATE OR DELETE ON role_permissions
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

-- Remove the audit trigger from users table
DROP TRIGGER IF EXISTS set_users_audit ON users;
DROP TRIGGER IF EXISTS audit_users ON users;
DROP TRIGGER IF EXISTS audit_ticket_tags ON ticket_tags;

-- Create trigger function to validate entity references
CREATE OR REPLACE FUNCTION validate_attachment_entity()
RETURNS TRIGGER AS $$
BEGIN
    -- Just check if the referenced entity exists in either table
    IF NOT EXISTS (
        SELECT 1 FROM tickets WHERE id = NEW.entity_id
        UNION
        SELECT 1 FROM ticket_comments WHERE id = NEW.entity_id
    ) THEN
        RAISE EXCEPTION 'Invalid entity reference';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER check_attachment_entity
    BEFORE INSERT OR UPDATE ON attachments
    FOR EACH ROW
    EXECUTE FUNCTION validate_attachment_entity();

-- Function to queue team/user content for embedding
CREATE OR REPLACE FUNCTION queue_resource_for_embedding()
RETURNS TRIGGER AS $$
BEGIN
    -- Handle teams
    IF TG_TABLE_NAME = 'teams' THEN
        INSERT INTO embedding_queue (
            entity_id,
            content,
            metadata
        ) VALUES (
            NEW.id,
            NEW.name || ' ' || COALESCE(NEW.description, ''),
            jsonb_build_object(
                'type', 'team',
                'id', NEW.id,
                'organization_id', NEW.organization_id,
                'name', NEW.name,
                'is_active', NEW.is_active,
                'last_updated', NEW.updated_at,
                'tags', (SELECT array_agg(t.name) FROM team_tags tt JOIN tags t ON t.id = tt.tag_id WHERE tt.team_id = NEW.id),
                'members', (
                    SELECT jsonb_agg(jsonb_build_object(
                        'user_id', tm.user_id,
                        'role', tm.role,
                        'is_active', tm.is_active,
                        'last_updated', tm.updated_at
                    ))
                    FROM team_members tm
                    WHERE tm.team_id = NEW.id
                ),
                'schedule', (
                    SELECT jsonb_agg(jsonb_build_object(
                        'user_id', ts.user_id,
                        'start_time', ts.start_time,
                        'end_time', ts.end_time,
                        'is_active', true,
                        'last_updated', ts.updated_at
                    ))
                    FROM team_schedules ts
                    WHERE ts.team_id = NEW.id
                )
            )
        );
    -- Handle users
    ELSIF TG_TABLE_NAME = 'users' THEN
        INSERT INTO embedding_queue (
            entity_id,
            content,
            metadata
        ) VALUES (
            NEW.id,
            NEW.email,  -- Use email for content
            jsonb_build_object(
                'type', 'user',
                'id', NEW.id,
                'organization_id', NEW.organization_id,
                'last_updated', NEW.updated_at,
                'knowledge_domains', COALESCE(
                    (SELECT jsonb_agg(jsonb_build_object(
                        'id', kd.id,
                        'description', kd.description,
                        'is_active', kd.is_active,
                        'last_updated', kd.updated_at,
                        'years_experience', ukd.years_experience,
                        'expertise', ukd.expertise,
                        'credentials', ukd.credential
                    ))
                    FROM user_knowledge_domain ukd
                    JOIN knowledge_domain kd ON kd.id = ukd.knowledge_domain_id
                    WHERE ukd.user_id = NEW.id),
                    '[]'::jsonb  -- Default to empty array if no knowledge domains
                )
            )
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for teams and users
CREATE TRIGGER queue_team_embedding
    AFTER INSERT OR UPDATE OF name, description, is_active
    ON teams
    FOR EACH ROW
    EXECUTE FUNCTION queue_resource_for_embedding();

CREATE TRIGGER queue_user_embedding
    AFTER INSERT OR UPDATE OF is_active
    ON users
    FOR EACH ROW
    EXECUTE FUNCTION queue_resource_for_embedding();

-- Function to update team embedding when members change
CREATE OR REPLACE FUNCTION queue_team_update_on_member_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Queue the team for re-embedding when members change
    INSERT INTO embedding_queue (
        entity_id,
        content,
        metadata
    )
    SELECT 
        t.id,
        t.name || ' ' || COALESCE(t.description, ''),
        jsonb_build_object(
            'type', 'team',
            'id', t.id,
            'organization_id', t.organization_id,
            'name', t.name,
            'is_active', t.is_active,
            'last_updated', t.updated_at,
            'tags', (SELECT array_agg(tags.name) FROM team_tags tt JOIN tags ON tags.id = tt.tag_id WHERE tt.team_id = t.id),
            'members', (
                SELECT jsonb_agg(jsonb_build_object(
                    'user_id', tm.user_id,
                    'role', tm.role,
                    'is_active', tm.is_active,
                    'last_updated', tm.updated_at
                ))
                FROM team_members tm
                WHERE tm.team_id = t.id
            ),
            'schedule', (
                SELECT jsonb_agg(jsonb_build_object(
                    'user_id', ts.user_id,
                    'start_time', ts.start_time,
                    'end_time', ts.end_time,
                    'is_active', true,
                    'last_updated', ts.updated_at
                ))
                FROM team_schedules ts
                WHERE ts.team_id = t.id
            )
        )
    FROM teams t
    WHERE t.id = NEW.team_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update user embedding when knowledge domains change
CREATE OR REPLACE FUNCTION queue_user_update_on_knowledge_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Queue the user for re-embedding when knowledge domains change
    INSERT INTO embedding_queue (
        entity_id,
        content,
        metadata
    )
    SELECT 
        u.id,
        u.email,  -- Changed from knowledge domain string_agg to email
        jsonb_build_object(
            'type', 'user',
            'id', u.id,
            'organization_id', u.organization_id,
            'last_updated', u.updated_at,
            'knowledge_domains', COALESCE(
                (SELECT jsonb_agg(jsonb_build_object(
                    'id', kd.id,
                    'description', kd.description,
                    'is_active', kd.is_active,
                    'last_updated', kd.updated_at,
                    'years_experience', ukd.years_experience,
                    'expertise', ukd.expertise,
                    'credentials', ukd.credential
                ))
                FROM user_knowledge_domain ukd
                JOIN knowledge_domain kd ON kd.id = ukd.knowledge_domain_id
                WHERE ukd.user_id = u.id),
                '[]'::jsonb  -- Default to empty array if no knowledge domains
            )
        )
    FROM users u
    WHERE u.id = NEW.user_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to queue ticket content for embedding
CREATE OR REPLACE FUNCTION queue_ticket_for_embedding()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO embedding_queue (
        entity_id,
        content,
        metadata
    ) VALUES (
        NEW.id,
        NEW.subject || ' ' || COALESCE(NEW.description, ''),
        jsonb_build_object(
            'type', 'ticket',
            'id', NEW.id,
            'organization_id', NEW.organization_id,
            'last_updated', NEW.updated_at,
            'status', NEW.status,
            'assigned_to', NEW.assignee_id,
            'requested_by', NEW.requester_id,
            'team_id', NEW.team_id,
            'tags', (SELECT array_agg(t.name) FROM ticket_tags tt JOIN tags t ON t.id = tt.tag_id WHERE tt.ticket_id = NEW.id),
            'priority', NEW.priority,
            'subject', NEW.subject,
            'description', NEW.description
        )
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for tickets
CREATE TRIGGER queue_ticket_embedding
    AFTER INSERT OR UPDATE OF subject, description, status, assignee_id, team_id, priority
    ON tickets
    FOR EACH ROW
    EXECUTE FUNCTION queue_ticket_for_embedding();

-- Function to handle ticket tag changes
CREATE OR REPLACE FUNCTION queue_ticket_on_tag_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Queue the associated ticket for re-embedding when tags change
    INSERT INTO embedding_queue (
        entity_id,
        content,
        metadata
    )
    SELECT 
        t.id,
        t.subject || ' ' || COALESCE(t.description, ''),
        jsonb_build_object(
            'type', 'ticket',
            'id', t.id,
            'organization_id', t.organization_id,
            'last_updated', t.updated_at,
            'status', t.status,
            'assigned_to', t.assignee_id,
            'requested_by', t.requester_id,
            'team_id', t.team_id,
            'tags', (SELECT array_agg(tags.name) FROM ticket_tags tt JOIN tags ON tags.id = tt.tag_id WHERE tt.ticket_id = t.id),
            'priority', t.priority,
            'subject', t.subject,
            'description', t.description
        )
    FROM tickets t
    WHERE t.id = CASE 
        WHEN TG_OP = 'DELETE' THEN OLD.ticket_id
        ELSE NEW.ticket_id
    END;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create trigger for ticket tag changes
CREATE TRIGGER queue_ticket_tag_changes
    AFTER INSERT OR UPDATE OR DELETE
    ON ticket_tags
    FOR EACH ROW
    EXECUTE FUNCTION queue_ticket_on_tag_change();

-- Policy to allow authenticated users to insert into embedding_queue
CREATE POLICY "Allow authenticated users to insert into embedding_queue"
ON embedding_queue
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy to allow authenticated users to read their own queue entries
CREATE POLICY "Allow users to read their own queue entries"
ON embedding_queue
FOR SELECT
TO authenticated
USING (
  auth.uid() IN (
    SELECT tm.user_id 
    FROM team_members tm
    JOIN teams t ON t.id = tm.team_id
    WHERE t.organization_id = (embedding_queue.metadata->>'organization_id')::uuid
  )
);

-- Policy to allow authenticated users to delete their own queue entries
CREATE POLICY "Allow users to delete their own queue entries"
ON embedding_queue
FOR DELETE
TO authenticated
USING (
  auth.uid() IN (
    SELECT tm.user_id 
    FROM team_members tm
    JOIN teams t ON t.id = tm.team_id
    WHERE t.organization_id = (metadata->>'organization_id')::uuid
  )
);
