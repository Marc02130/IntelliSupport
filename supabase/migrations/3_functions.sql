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

-- Add audit triggers for all tables
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

-- Drop all existing triggers first
DROP TRIGGER IF EXISTS queue_ticket_embedding ON tickets;
DROP TRIGGER IF EXISTS queue_ticket_tag_changes ON ticket_tags;
DROP TRIGGER IF EXISTS queue_team_embedding ON teams;
DROP TRIGGER IF EXISTS queue_user_embedding ON users;
DROP TRIGGER IF EXISTS team_member_change ON team_members;
DROP TRIGGER IF EXISTS team_tag_change ON team_tags;
DROP TRIGGER IF EXISTS team_schedule_change ON team_schedules;
DROP TRIGGER IF EXISTS user_knowledge_change ON user_knowledge_domain;
DROP TRIGGER IF EXISTS ticket_change ON tickets;
DROP TRIGGER IF EXISTS ticket_tag_change ON ticket_tags;
DROP TRIGGER IF EXISTS ticket_comment_change ON ticket_comments;
DROP TRIGGER IF EXISTS auth_user_change ON auth.users;

-- Drop all existing functions
DROP FUNCTION IF EXISTS queue_ticket_for_embedding();
DROP FUNCTION IF EXISTS queue_ticket_on_tag_change();
DROP FUNCTION IF EXISTS queue_resource_for_embedding();
DROP FUNCTION IF EXISTS queue_team_update_on_member_change();
DROP FUNCTION IF EXISTS queue_user_update_on_knowledge_change();
DROP FUNCTION IF EXISTS handle_team_member_change();
DROP FUNCTION IF EXISTS handle_team_tag_change();
DROP FUNCTION IF EXISTS handle_user_knowledge_change();
DROP FUNCTION IF EXISTS handle_team_change();
DROP FUNCTION IF EXISTS handle_user_change();
DROP FUNCTION IF EXISTS handle_ticket_change();

-- Function to handle team changes
CREATE OR REPLACE FUNCTION handle_team_change()
RETURNS TRIGGER AS $$
DECLARE
  team_id uuid;
BEGIN
  -- Get the team_id based on the trigger source
  IF TG_TABLE_NAME = 'teams' THEN
    team_id := NEW.id;
  ELSIF TG_TABLE_NAME = 'team_members' THEN
    team_id := NEW.team_id;
  ELSIF TG_TABLE_NAME = 'team_tags' THEN
    team_id := NEW.team_id;
  ELSIF TG_TABLE_NAME = 'team_schedules' THEN
    team_id := NEW.team_id;
  END IF;

  -- Delete existing embedding for this team
  DELETE FROM embeddings WHERE entity_id = team_id;
  DELETE FROM embedding_queue WHERE entity_id = team_id;

  -- Only queue team if it still exists and meets requirements
  IF TG_OP != 'DELETE' OR TG_TABLE_NAME != 'teams' THEN
    INSERT INTO embedding_queue (entity_id, content, metadata)
    SELECT DISTINCT ON (t.id)
      t.id,
      t.name || ' ' || COALESCE(t.description, ''),
      jsonb_build_object(
        'id', t.id,
        'name', t.name,
        'type', 'team',
        'tags', (
          SELECT array_agg(tags.name)
          FROM team_tags tt
          JOIN tags ON tags.id = tt.tag_id
          WHERE tt.team_id = t.id
        ),
        'members', (
          SELECT jsonb_agg(
            jsonb_build_object(
              'user_id', tm.user_id,
              'role', tm.role,
              'schedule', (
                SELECT jsonb_build_object(
                  'start_time', ts.start_time,
                  'end_time', ts.end_time
                )
                FROM team_schedules ts
                WHERE ts.team_id = t.id 
                AND ts.user_id = tm.user_id
              ),
              'knowledge_domains', (
                SELECT jsonb_agg(
                  jsonb_build_object(
                    'domain', kd.name,
                    'expertise', ukd.expertise
                  )
                )
                FROM user_knowledge_domain ukd
                JOIN knowledge_domain kd ON kd.id = ukd.knowledge_domain_id
                WHERE ukd.user_id = tm.user_id
              )
            )
          )
          FROM team_members tm
          WHERE tm.team_id = t.id
          AND tm.is_active = true
          AND EXISTS (
            SELECT 1 
            FROM user_knowledge_domain ukd
            WHERE ukd.user_id = tm.user_id
          )
        ),
        'is_active', t.is_active,
        'organization_id', t.organization_id,
        'last_updated', CURRENT_TIMESTAMP
      )
    FROM teams t
    WHERE t.id = team_id
    -- Team must have tags
    AND EXISTS (
      SELECT 1 FROM team_tags tt WHERE tt.team_id = t.id
    )
    -- Team must have members with knowledge domains
    AND EXISTS (
      SELECT 1 
      FROM team_members tm
      JOIN user_knowledge_domain ukd ON ukd.user_id = tm.user_id
      WHERE tm.team_id = t.id
      AND tm.is_active = true
    )
    -- Team must have schedule
    AND EXISTS (
      SELECT 1 FROM team_schedules ts WHERE ts.team_id = t.id
    );
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Function to handle public.users changes
CREATE OR REPLACE FUNCTION handle_user_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete existing embedding for this user
  DELETE FROM embeddings WHERE entity_id = NEW.id;
  DELETE FROM embedding_queue WHERE entity_id = NEW.id;

  -- Queue new embedding if user has knowledge domains
  INSERT INTO embedding_queue (entity_id, content, metadata)
  SELECT 
    u.id,
    u.full_name,
    jsonb_build_object(
      'id', u.id,
      'type', 'user',
      'name', u.full_name,
      'knowledge_domains', (
        SELECT jsonb_agg(
          jsonb_build_object(
            'domain', kd.name,
            'expertise', ukd.expertise
          )
        )
        FROM user_knowledge_domain ukd
        JOIN knowledge_domain kd ON kd.id = ukd.knowledge_domain_id
        WHERE ukd.user_id = u.id
      ),
      'organization_id', u.organization_id,
      'last_updated', CURRENT_TIMESTAMP
    )
  FROM users u
  WHERE u.id = NEW.id
  -- Only process users that have knowledge domains
  AND EXISTS (
    SELECT 1 
    FROM user_knowledge_domain ukd
    WHERE ukd.user_id = u.id
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to handle user_knowledge_domain changes
CREATE OR REPLACE FUNCTION handle_knowledge_change()
RETURNS TRIGGER AS $$
DECLARE
  user_id uuid;
BEGIN
  -- Get the user_id based on operation
  user_id := CASE 
    WHEN TG_OP = 'DELETE' THEN OLD.user_id
    ELSE NEW.user_id
  END;

  -- Delete existing embeddings
  DELETE FROM embeddings WHERE entity_id = user_id;
  DELETE FROM embedding_queue WHERE entity_id = user_id;

  -- Queue new embedding if not deleted and user has knowledge domains
  IF TG_OP != 'DELETE' THEN
    INSERT INTO embedding_queue (entity_id, content, metadata)
    SELECT 
      u.id,
      u.full_name || ' - ' || COALESCE(
        (SELECT string_agg(
          kd.name || ' (' || ukd.expertise || ')',
          ', '
        )
        FROM user_knowledge_domain ukd
        JOIN knowledge_domain kd ON kd.id = ukd.knowledge_domain_id
        WHERE ukd.user_id = u.id),
      ''),
      jsonb_build_object(
        'id', u.id,
        'type', 'user',
        'name', u.full_name,
        'knowledge_domains', (
          SELECT jsonb_agg(
            jsonb_build_object(
              'domain', kd.name,
              'expertise', ukd.expertise
            )
          )
          FROM user_knowledge_domain ukd
          JOIN knowledge_domain kd ON kd.id = ukd.knowledge_domain_id
          WHERE ukd.user_id = u.id
        ),
        'organization_id', u.organization_id,
        'last_updated', CURRENT_TIMESTAMP
      )
    FROM users u
    WHERE u.id = user_id
    -- Only process users that have knowledge domains
    AND EXISTS (
      SELECT 1 
      FROM user_knowledge_domain ukd
      WHERE ukd.user_id = u.id
    );
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Function to handle tickets changes
CREATE OR REPLACE FUNCTION handle_ticket_change() 
RETURNS TRIGGER AS $$
BEGIN
  -- Delete existing embedding
  DELETE FROM embeddings WHERE entity_id = NEW.id;
  DELETE FROM embedding_queue WHERE entity_id = NEW.id;

  -- Queue new embedding if ticket has tags
  INSERT INTO embedding_queue (entity_id, content, metadata)
  SELECT 
    t.id,
    t.subject || ' ' || COALESCE(t.description, ''),
    jsonb_build_object(
      'id', t.id,
      'type', 'ticket',
      'subject', t.subject,
      'description', t.description,
      'status', t.status,
      'priority', t.priority,
      'tags', (
        SELECT array_agg(tags.name)
        FROM ticket_tags tt
        JOIN tags ON tags.id = tt.tag_id
        WHERE tt.ticket_id = t.id
      ),
      'team_id', t.team_id,
      'assigned_to', t.assignee_id,
      'requested_by', t.requester_id,
      'organization_id', t.organization_id,
      'comments', (
        SELECT jsonb_agg(
          jsonb_build_object(
            'content', c.content,
            'author_id', c.author_id,
            'created_at', c.created_at
          ) ORDER BY c.created_at DESC
        )
        FROM ticket_comments c
        WHERE c.ticket_id = t.id
      ),
      'last_updated', CURRENT_TIMESTAMP
    )
  FROM tickets t
  WHERE t.id = NEW.id
  -- Ticket must have tags
  AND EXISTS (
    SELECT 1 FROM ticket_tags WHERE ticket_id = t.id
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to handle ticket tags changes
CREATE OR REPLACE FUNCTION handle_ticket_tag_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete existing embedding
  DELETE FROM embeddings WHERE entity_id = CASE 
    WHEN TG_OP = 'DELETE' THEN OLD.ticket_id
    ELSE NEW.ticket_id
  END;

  -- Queue new embedding if not deleted and has tags
  IF TG_OP != 'DELETE' THEN
    INSERT INTO embedding_queue (entity_id, content, metadata)
    SELECT 
      t.id,
      t.subject || ' ' || COALESCE(t.description, ''),
      jsonb_build_object(
        'id', t.id,
        'type', 'ticket',
        'subject', t.subject,
        'description', t.description,
        'status', t.status,
        'priority', t.priority,
        'tags', (
          SELECT array_agg(tags.name)
          FROM ticket_tags tt
          JOIN tags ON tags.id = tt.tag_id
          WHERE tt.ticket_id = t.id
        ),
        'team_id', t.team_id,
        'assigned_to', t.assignee_id,
        'requested_by', t.requester_id,
        'organization_id', t.organization_id,
        'comments', (
          SELECT jsonb_agg(
            jsonb_build_object(
              'content', c.content,
              'author_id', c.author_id,
              'created_at', c.created_at
            ) ORDER BY c.created_at DESC
          )
          FROM ticket_comments c
          WHERE c.ticket_id = t.id
        ),
        'last_updated', CURRENT_TIMESTAMP
      )
    FROM tickets t
    WHERE t.id = NEW.ticket_id
    -- Ticket must have tags
    AND EXISTS (
      SELECT 1 FROM ticket_tags WHERE ticket_id = t.id
    );
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Function to handle ticket comments changes
CREATE OR REPLACE FUNCTION handle_ticket_comment_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete existing embedding and queue entries
  DELETE FROM embeddings WHERE entity_id = NEW.ticket_id;
  DELETE FROM embedding_queue WHERE entity_id = NEW.ticket_id;

  -- Queue new embedding if ticket has tags
  INSERT INTO embedding_queue (entity_id, content, metadata)
  SELECT 
    t.id,
    t.subject || ' ' || COALESCE(t.description, '') || ' ' || COALESCE(
      (SELECT string_agg(content, ' ')
       FROM (
         SELECT c.content 
         FROM ticket_comments c
         WHERE c.ticket_id = t.id
         ORDER BY c.created_at DESC
       ) ordered_comments),
    ''),
    jsonb_build_object(
      'id', t.id,
      'type', 'ticket',
      'subject', t.subject,
      'description', t.description,
      'status', t.status,
      'priority', t.priority,
      'tags', (
        SELECT array_agg(tags.name)
        FROM ticket_tags tt
        JOIN tags ON tags.id = tt.tag_id
        WHERE tt.ticket_id = t.id
      ),
      'team_id', t.team_id,
      'assigned_to', t.assignee_id,
      'requested_by', t.requester_id,
      'organization_id', t.organization_id,
      'comments', (
        SELECT jsonb_agg(
          jsonb_build_object(
            'content', c.content,
            'author_id', c.author_id,
            'created_at', c.created_at
          ) ORDER BY c.created_at DESC
        )
        FROM ticket_comments c
        WHERE c.ticket_id = t.id
      ),
      'last_updated', CURRENT_TIMESTAMP
    )
  FROM tickets t
  WHERE t.id = NEW.ticket_id
  -- Ticket must have tags
  AND EXISTS (
    SELECT 1 FROM ticket_tags WHERE ticket_id = t.id
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER ticket_change
  AFTER INSERT OR UPDATE ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION handle_ticket_change();

CREATE TRIGGER ticket_tag_change
  AFTER INSERT OR UPDATE OR DELETE ON ticket_tags
  FOR EACH ROW
  EXECUTE FUNCTION handle_ticket_tag_change();

CREATE TRIGGER ticket_comment_change
  AFTER INSERT OR UPDATE ON ticket_comments
  FOR EACH ROW
  EXECUTE FUNCTION handle_ticket_comment_change();

-- Create triggers for teams
CREATE TRIGGER teams_change
  AFTER INSERT OR UPDATE ON teams
  FOR EACH ROW
  EXECUTE FUNCTION handle_team_change();

CREATE TRIGGER team_members_change
  AFTER INSERT OR UPDATE OR DELETE ON team_members
  FOR EACH ROW
  EXECUTE FUNCTION handle_team_change();

CREATE TRIGGER team_tag_change
  AFTER INSERT OR UPDATE OR DELETE ON team_tags
  FOR EACH ROW
  EXECUTE FUNCTION handle_team_change();

CREATE TRIGGER team_schedule_change
  AFTER INSERT OR UPDATE OR DELETE ON team_schedules
  FOR EACH ROW
  EXECUTE FUNCTION handle_team_change();

-- Create triggers for users
CREATE TRIGGER user_change
  AFTER INSERT OR UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_user_change();

CREATE TRIGGER knowledge_change
  AFTER INSERT OR UPDATE OR DELETE ON user_knowledge_domain
  FOR EACH ROW
  EXECUTE FUNCTION handle_knowledge_change();

-- Function to process embeddings in a transaction
CREATE OR REPLACE FUNCTION process_embedding(
  p_content text,
  p_embedding vector(3072),
  p_entity_type text,
  p_entity_id uuid,
  p_metadata jsonb,
  p_queue_id uuid
) RETURNS void AS $$
BEGIN
  -- Insert into embeddings
  INSERT INTO embeddings (
    content,
    embedding,
    entity_type,
    entity_id,
    metadata
  ) VALUES (
    p_content,
    p_embedding,
    p_entity_type,
    p_entity_id,
    p_metadata
  );

  -- Delete from queue
  DELETE FROM embedding_queue WHERE id = p_queue_id;

EXCEPTION WHEN OTHERS THEN
  RAISE;
END;
$$ LANGUAGE plpgsql;

-- Create the match_documents function
create or replace function match_documents (
  query_embedding vector(3072),
  match_count int,
  filter jsonb default '{}'
) returns table (
  id uuid,
  content text,
  metadata jsonb,
  embedding vector(3072),
  similarity float
)
language plpgsql
as $$
begin
  return query
  select
    embeddings.id,
    embeddings.content,
    embeddings.metadata,
    embeddings.embedding,
    1 - (embeddings.embedding <=> query_embedding) as similarity
  from embeddings
  where embeddings.metadata @> filter
  order by embeddings.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- Function to clean up test data
CREATE OR REPLACE FUNCTION cleanup_test_data(test_org_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete test embeddings
  DELETE FROM embeddings 
  WHERE metadata->>'organization_id' = test_org_id;

  -- Delete test teams
  DELETE FROM teams
  WHERE id IN (
    SELECT entity_id::uuid
    FROM embeddings
    WHERE metadata->>'organization_id' = test_org_id
    AND entity_type = 'team'
  );
END;
$$;

-- Function to process embedding queue
CREATE OR REPLACE FUNCTION process_embedding_queue_job()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Call edge function to process embedding queue
  PERFORM
    net.http_post(
      url := current_setting('app.settings.service_url') || '/functions/v1/process-embedding-queue',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
        'Content-Type', 'application/json'
      ),
      body := '{}'
    );
END;
$$;

-- Function to route unassigned tickets
CREATE OR REPLACE FUNCTION route_tickets_job()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Call edge function to route tickets
  PERFORM
    net.http_post(
      url := current_setting('app.settings.service_url') || '/functions/v1/route-tickets-job',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
        'Content-Type', 'application/json'
      ),
      body := '{}'
    );
END;
$$;

-- Schedule the jobs
SELECT cron.schedule(
  'process-embedding-queue',  -- job name
  '*/5 * * * *',           -- every 5 minutes
  'SELECT process_embedding_queue_job();'
);

SELECT cron.schedule(
  'route-tickets',           -- job name
  '*/5 * * * *',           -- every 5 minutes
  'SELECT route_tickets_job();'
);

-- Unschedule if exists (useful for migrations)
SELECT cron.unschedule('process-embedding-queue');
SELECT cron.unschedule('route-tickets');