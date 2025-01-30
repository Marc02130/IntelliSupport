-- drop audit triggers
DROP TRIGGER IF EXISTS set_organizations_audit ON organizations;
DROP TRIGGER IF EXISTS set_tickets_audit ON tickets;
DROP TRIGGER IF EXISTS set_ticket_comments_audit ON ticket_comments;
DROP TRIGGER IF EXISTS set_ticket_tags_audit ON ticket_tags;
DROP TRIGGER IF EXISTS set_teams_audit ON teams;
DROP TRIGGER IF EXISTS set_team_members_audit ON team_members;
DROP TRIGGER IF EXISTS set_team_tags_audit ON team_tags;
DROP TRIGGER IF EXISTS set_team_schedules_audit ON team_schedules;
DROP TRIGGER IF EXISTS set_search_queries_audit ON search_queries;
DROP TRIGGER IF EXISTS set_sidebar_navigation_audit ON sidebar_navigation;
DROP TRIGGER IF EXISTS set_permissions_audit ON permissions;
DROP TRIGGER IF EXISTS set_roles_audit ON roles;
DROP TRIGGER IF EXISTS set_role_permissions_audit ON role_permissions;

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

-- create audit triggers
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

CREATE TRIGGER set_roles_audit
    AFTER INSERT OR UPDATE OR DELETE ON roles
    FOR EACH ROW EXECUTE FUNCTION set_audit_fields();

CREATE TRIGGER set_permissions_audit
    AFTER INSERT OR UPDATE OR DELETE ON permissions
    FOR EACH ROW EXECUTE FUNCTION set_audit_fields();

CREATE TRIGGER set_role_permissions_audit
    AFTER INSERT OR UPDATE OR DELETE ON role_permissions
    FOR EACH ROW EXECUTE FUNCTION set_audit_fields();


-- DROP audit log triggers for all tables
DROP TRIGGER IF EXISTS audit_organizations ON organizations;
DROP TRIGGER IF EXISTS audit_tickets ON tickets;
DROP TRIGGER IF EXISTS audit_ticket_comments ON ticket_comments;
DROP TRIGGER IF EXISTS audit_ticket_tags ON ticket_tags;
DROP TRIGGER IF EXISTS audit_teams ON teams;
DROP TRIGGER IF EXISTS audit_team_members ON team_members;
DROP TRIGGER IF EXISTS audit_team_tags ON team_tags;
DROP TRIGGER IF EXISTS audit_team_schedules ON team_schedules;
DROP TRIGGER IF EXISTS audit_search_queries ON search_queries;
DROP TRIGGER IF EXISTS audit_sidebar_navigation ON sidebar_navigation;
DROP TRIGGER IF EXISTS audit_roles ON roles;
DROP TRIGGER IF EXISTS audit_permissions ON permissions;
DROP TRIGGER IF EXISTS audit_role_permissions ON role_permissions;
DROP TRIGGER IF EXISTS message_audit_trigger ON communication_history;

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
        entity_type,
        entity_id,
        action,
        old_data,
        new_data,
        metadata,
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
        jsonb_build_object(
            'changed_fields', changed_fields,
            'schema', TG_TABLE_SCHEMA,
            'trigger_name', TG_NAME
        ),
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

-- Add audit log triggers for all tables
CREATE TRIGGER audit_organizations
    AFTER INSERT OR UPDATE OR DELETE ON organizations
    FOR EACH ROW 
    EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_tickets
    AFTER INSERT OR UPDATE OR DELETE ON tickets
    FOR EACH ROW 
    EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_ticket_comments
    AFTER INSERT OR UPDATE OR DELETE ON ticket_comments
    FOR EACH ROW 
    EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_ticket_tags
    AFTER INSERT OR UPDATE OR DELETE ON ticket_tags
    FOR EACH ROW 
    EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_teams
    AFTER INSERT OR UPDATE OR DELETE ON teams
    FOR EACH ROW 
    EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_team_members
    AFTER INSERT OR UPDATE OR DELETE ON team_members
    FOR EACH ROW 
    EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_team_tags
    AFTER INSERT OR UPDATE OR DELETE ON team_tags
    FOR EACH ROW 
    EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_team_schedules
    AFTER INSERT OR UPDATE OR DELETE ON team_schedules
    FOR EACH ROW 
    EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_search_queries
    AFTER INSERT OR UPDATE OR DELETE ON search_queries
    FOR EACH ROW 
    EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_sidebar_navigation
    AFTER INSERT OR UPDATE OR DELETE ON sidebar_navigation
    FOR EACH ROW 
    EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_roles
    AFTER INSERT OR UPDATE OR DELETE ON roles
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_permissions
    AFTER INSERT OR UPDATE OR DELETE ON permissions
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_role_permissions
    AFTER INSERT OR UPDATE OR DELETE ON role_permissions
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

CREATE TRIGGER audit_message_changes_trigger
    AFTER INSERT OR UPDATE OR DELETE ON communication_history
    FOR EACH ROW
    EXECUTE FUNCTION process_audit_log();
