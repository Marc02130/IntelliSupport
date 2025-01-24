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
BEGIN
    RETURN QUERY
    WITH RECURSIVE user_permissions AS (
        -- Get all permissions for the user's role
        SELECT DISTINCT p.name::text AS permission_name
        FROM auth.users u
        JOIN roles r ON r.name = (u.raw_user_meta_data->>'role')::text
        JOIN role_permissions rp ON rp.role_id = r.id
        JOIN permissions p ON p.id = rp.permission_id
        WHERE u.id = auth.uid()
    )
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
        -- Check if user has ANY of the required permissions
        EXISTS (
            SELECT 1 FROM user_permissions up 
            WHERE up.permission_name = ANY(n.permissions_required::text[])
        )
        OR
        -- Or if no permissions are required
        n.permissions_required IS NULL 
        OR 
        array_length(n.permissions_required, 1) IS NULL
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

-- Add trigger to set organization_id on ticket creation
CREATE OR REPLACE FUNCTION set_ticket_organization()
RETURNS TRIGGER AS $$
BEGIN
    NEW.organization_id := (
        SELECT organization_id 
        FROM public.users 
        WHERE id = NEW.requester_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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