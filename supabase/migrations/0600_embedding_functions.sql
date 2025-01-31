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

-- Function to batch messages
CREATE OR REPLACE FUNCTION batch_messages()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Log start
    INSERT INTO cron_job_logs (job_name, status) 
    VALUES ('batch-messages', 'started');

    BEGIN
        -- Call edge function to batch messages
        PERFORM pg_notify('batch_messages', '{}');

        -- Log success
        INSERT INTO cron_job_logs (job_name, status)
        VALUES ('batch-messages', 'completed');

    EXCEPTION WHEN OTHERS THEN
        -- Log error
        INSERT INTO cron_job_logs (job_name, status, error)
        VALUES ('batch-messages', 'failed', SQLERRM);
        RAISE;
    END;
END;
$$ LANGUAGE plpgsql;

-- Process embedding queue
CREATE OR REPLACE FUNCTION process_embedding_queue()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    batch_size INTEGER := 100;
BEGIN
    -- Log start
    INSERT INTO cron_job_logs (job_name, status) 
    VALUES ('process-embedding-queue', 'started');

    BEGIN
        -- Call edge function to process embeddings
        PERFORM pg_notify('process_embedding_queue', jsonb_build_object(
            'batch_size', batch_size
        )::text);

        -- Log success
        INSERT INTO cron_job_logs (job_name, status)
        VALUES ('process-embedding-queue', 'completed');

    EXCEPTION WHEN OTHERS THEN
        -- Log error
        INSERT INTO cron_job_logs (job_name, status, error)
        VALUES ('process-embedding-queue', 'failed', SQLERRM);
        RAISE;
    END;
END;
$$ LANGUAGE plpgsql;

-- Then update the routing function to use the mapping
CREATE OR REPLACE FUNCTION route_tickets_job()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Log start
    INSERT INTO cron_job_logs (job_name, status) 
    VALUES ('route-tickets', 'started');

    BEGIN
        -- Find unassigned tickets with their tags
        WITH unassigned_tickets AS (
            SELECT 
                t.id, 
                t.organization_id,
                ARRAY_AGG(DISTINCT kd.name) as knowledge_domains -- Get mapped domains
            FROM tickets t
            LEFT JOIN ticket_tags tt ON tt.ticket_id = t.id
            LEFT JOIN tag_knowledge_mappings tkm ON tkm.tag_id = tt.tag_id
            LEFT JOIN knowledge_domain kd ON kd.id = tkm.knowledge_domain_id
            WHERE t.assignee_id IS NULL
            AND t.status = 'open'
            GROUP BY t.id, t.organization_id
        ),
        -- Find available agents with matching expertise
        available_agents AS (
            SELECT 
                u.id as agent_id,
                u.organization_id,
                kd.name as knowledge_domain,
                ukd.expertise,
                COUNT(t.id) as current_ticket_count
            FROM users u
            JOIN user_knowledge_domain ukd ON ukd.user_id = u.id
            JOIN knowledge_domain kd ON kd.id = ukd.knowledge_domain_id
            LEFT JOIN tickets t ON t.assignee_id = u.id AND t.status = 'open'
            WHERE u.role = 'agent'
            AND u.is_active = true
            GROUP BY u.id, u.organization_id, kd.name, ukd.expertise
        )
        UPDATE tickets t
        SET 
            assignee_id = a.agent_id,
            updated_at = NOW()
        FROM unassigned_tickets ut
        JOIN available_agents a ON 
            -- Remove organization match requirement
            -- a.organization_id = ut.organization_id AND 
            a.knowledge_domain = ANY(ut.knowledge_domains)
        WHERE t.id = ut.id
        AND a.current_ticket_count = (
            SELECT MIN(current_ticket_count)
            FROM available_agents a2
            WHERE -- a2.organization_id = ut.organization_id AND
            a2.knowledge_domain = ANY(ut.knowledge_domains)
        );

        -- Log success
        INSERT INTO cron_job_logs (job_name, status)
        VALUES ('route-tickets', 'completed');
    EXCEPTION WHEN OTHERS THEN
        -- Log error
        INSERT INTO cron_job_logs (job_name, status, error)
        VALUES ('route-tickets', 'failed', SQLERRM);
        RAISE;
    END;
END;
$$; 

-- Teams
-- Drop triggers on handle_team_change
DROP TRIGGER IF EXISTS teams_change ON teams;
DROP TRIGGER IF EXISTS team_members_change ON team_members;
DROP TRIGGER IF EXISTS team_tag_change ON team_tags;
DROP TRIGGER IF EXISTS team_schedule_change ON team_schedules;

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
  DELETE FROM embeddings WHERE entity_id = team_id AND entity_type = 'team';
  DELETE FROM embedding_queue WHERE entity_id = team_id AND entity_type = 'team';

  -- Only queue team if it still exists and meets requirements
  IF TG_OP != 'DELETE' OR TG_TABLE_NAME != 'teams' THEN
    INSERT INTO embedding_queue (entity_id, entity_type, content, metadata)
    SELECT DISTINCT ON (t.id)
      t.id,
      'team',
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

-- Create triggers on handle_team_change
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



-- Users
-- Drop triggers for users
DROP TRIGGER IF EXISTS handle_user_change ON public.users;

-- Function to handle public.users changes
CREATE OR REPLACE FUNCTION handle_user_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Only process for admins and agents
  IF NEW.role IN ('admin', 'agent') THEN
    -- Delete existing embedding for this user
    DELETE FROM embeddings WHERE entity_id = NEW.id AND entity_type = 'user';
    DELETE FROM embedding_queue WHERE entity_id = NEW.id AND entity_type = 'user';

    -- Queue new embedding if user has knowledge domains
    INSERT INTO embedding_queue (entity_id, entity_type, content, metadata)
    SELECT 
      u.id,
      'user',
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
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for users
CREATE TRIGGER handle_user_change
  AFTER INSERT OR UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_user_change();

-- Drop trigger
DROP TRIGGER IF EXISTS knowledge_change ON user_knowledge_domain;

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

  -- Only process for admins and agents
  IF EXISTS (
    SELECT 1 FROM auth.users u 
    WHERE u.id = user_id 
    AND u.raw_user_meta_data->>'role' IN ('admin', 'agent')
  ) THEN
    -- Delete existing embeddings
    DELETE FROM embeddings WHERE entity_id = user_id AND entity_type = 'user';
    DELETE FROM embedding_queue WHERE entity_id = user_id AND entity_type = 'user';

    -- Queue new embedding if not deleted and user has knowledge domains
    IF TG_OP != 'DELETE' THEN
      INSERT INTO embedding_queue (entity_id, entity_type, content, metadata)
      SELECT 
        u.id,
        'user',
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
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create Trigger
CREATE TRIGGER knowledge_change
  AFTER INSERT OR UPDATE OR DELETE ON user_knowledge_domain
  FOR EACH ROW
  EXECUTE FUNCTION handle_knowledge_change();



-- Tickets
-- Drop trigger
DROP TRIGGER IF EXISTS ticket_change ON tickets;

-- Function to handle tickets changes
CREATE OR REPLACE FUNCTION handle_ticket_change() 
RETURNS TRIGGER AS $$
BEGIN
  -- Delete existing embedding
  DELETE FROM embeddings WHERE entity_id = NEW.id AND entity_type = 'ticket';
  DELETE FROM embedding_queue WHERE entity_id = NEW.id AND entity_type = 'ticket';

  -- Queue new embedding if ticket has tags
  INSERT INTO embedding_queue (entity_id, entity_type, content, metadata)
  SELECT 
    t.id,
    'ticket',
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

--Create Trigger
CREATE TRIGGER ticket_change
  AFTER INSERT OR UPDATE ON tickets
  FOR EACH ROW
  EXECUTE FUNCTION handle_ticket_change();

-- Drop trigger to handle ticket tags changes
DROP TRIGGER IF EXISTS ticket_tag_change ON ticket_tags;

-- Function to handle ticket tags changes
CREATE OR REPLACE FUNCTION handle_ticket_tag_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete existing embedding
  DELETE FROM embeddings WHERE entity_id = CASE 
    WHEN TG_OP = 'DELETE' THEN OLD.ticket_id
    ELSE NEW.ticket_id
  END AND entity_type = 'ticket';

  DELETE FROM embedding_queue WHERE entity_id = CASE 
    WHEN TG_OP = 'DELETE' THEN OLD.ticket_id
    ELSE NEW.ticket_id
  END AND entity_type = 'ticket';

  -- Queue new embedding if not deleted and has tags
  IF TG_OP != 'DELETE' THEN
    INSERT INTO embedding_queue (entity_id, entity_type, content, metadata)
    SELECT 
        t.id,
        'ticket',
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

-- Create trigger to handle ticket tags changes
CREATE TRIGGER ticket_tag_change
  AFTER INSERT OR UPDATE OR DELETE ON ticket_tags
  FOR EACH ROW
  EXECUTE FUNCTION handle_ticket_tag_change();

-- Drop trigger to handle ticket comments changes
DROP TRIGGER IF EXISTS ticket_comment_change ON ticket_comments;

-- Function to handle ticket comments changes
CREATE OR REPLACE FUNCTION handle_ticket_comment_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete existing embedding and queue entries
  DELETE FROM embeddings WHERE entity_id = NEW.ticket_id AND entity_type = 'ticket';
  DELETE FROM embedding_queue WHERE entity_id = NEW.ticket_id AND entity_type = 'ticket';

  -- Queue new embedding if ticket has tags
  INSERT INTO embedding_queue (entity_id, entity_type, content, metadata)
  SELECT 
    t.id,
    'ticket',
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

-- Create trigger to handle ticket comments changes
CREATE TRIGGER ticket_comment_change
  AFTER INSERT OR UPDATE ON ticket_comments
  FOR EACH ROW
  EXECUTE FUNCTION handle_ticket_comment_change();



-- Communication History
-- Drop trigger for Customer history embeddings (using customer_id)
DROP TRIGGER IF EXISTS customer_history_embedding_trigger ON communication_history;

-- Customer history embeddings (using customer_id)
CREATE OR REPLACE FUNCTION handle_customer_history() 
RETURNS TRIGGER AS $$
BEGIN
    -- Only process if:
    -- 1. It's a customer
    -- 2. Customer has preferences
    -- 3. Has recent history
    IF EXISTS (
        SELECT 1 
        FROM auth.users u
        JOIN customer_preferences cp ON cp.customer_id = u.id
        WHERE u.id = NEW.customer_id
        AND u.raw_user_meta_data->>'role' = 'customer'
        AND EXISTS (
            SELECT 1 
            FROM communication_history ch
            WHERE ch.customer_id = u.id
            AND ch.sent_at > NOW() - INTERVAL '30 days'
        )
    ) THEN
        -- Delete existing embeddings
        DELETE FROM embeddings WHERE entity_id = NEW.customer_id AND entity_type = 'customer_history';
        DELETE FROM embedding_queue WHERE entity_id = NEW.customer_id AND entity_type = 'customer_history';

        -- Queue new embedding
        INSERT INTO embedding_queue (entity_id, entity_type, content, metadata)
        SELECT 
            u.id,
            'customer_history',
            -- Content combines preferences and communication history
            cp.preferred_style || ' - ' || 
            COALESCE(
                (
                    SELECT string_agg(ch.message_text, ' | ' ORDER BY ch.sent_at DESC)
                    FROM (
                        SELECT message_text, sent_at 
                        FROM communication_history ch
                        WHERE ch.customer_id = u.id
                        ORDER BY sent_at DESC
                        LIMIT 5
                    ) ch
                ), 
                ''
            ),
        jsonb_build_object(
            'id', u.id,
                'type', 'customer',
                'preferences', jsonb_build_object(
                    'style', cp.preferred_style,
                    'times', cp.preferred_times,
                    'frequency', cp.communication_frequency
                ),
                'communication_history', (
                    SELECT jsonb_agg(history ORDER BY history->>'sent_at' DESC)
                    FROM (
                        SELECT jsonb_build_object(
                            'message', ch.message_text,
                            'sent_at', ch.sent_at,
                            'effectiveness', ch.effectiveness_metrics
                        ) as history
                        FROM communication_history ch
                        WHERE ch.customer_id = u.id
                        ORDER BY ch.sent_at DESC
                        LIMIT 10
                    ) recent_history
                ),
                'last_updated', CURRENT_TIMESTAMP
            )
        FROM auth.users u
        JOIN customer_preferences cp ON cp.customer_id = u.id
        WHERE u.id = NEW.customer_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for Customer history embeddings (using customer_id)
CREATE TRIGGER customer_history_embedding_trigger
    AFTER INSERT OR UPDATE ON communication_history
    FOR EACH ROW
    EXECUTE FUNCTION handle_customer_history();

-- Drop trigger for customer preferences
DROP TRIGGER IF EXISTS customer_preferences_embedding_trigger ON customer_preferences;

-- Keep handle_customer_preferences (unchanged)
CREATE OR REPLACE FUNCTION handle_customer_preferences() 
RETURNS TRIGGER AS $$
BEGIN
    -- Only process if it's a customer
    IF EXISTS (
        SELECT 1 
        FROM auth.users u
        WHERE u.id = NEW.customer_id
        AND u.raw_user_meta_data->>'role' = 'customer'
    ) THEN
        -- Delete existing embeddings
        DELETE FROM embeddings WHERE entity_id = NEW.customer_id AND entity_type = 'customer_preferences';
        DELETE FROM embedding_queue WHERE entity_id = NEW.customer_id AND entity_type = 'customer_preferences';

        -- Queue new embedding
        INSERT INTO embedding_queue (entity_id, entity_type, content, metadata)
        SELECT 
            u.id,
            'customer_preferences',
            -- Content combines customer info and preferences only
            u.full_name || ' - ' || 
            NEW.preferred_style || ' - ' ||
            NEW.communication_frequency,
            jsonb_build_object(
                'id', u.id,
                'type', 'customer',
                'name', u.full_name,
                'preferences', jsonb_build_object(
                    'style', NEW.preferred_style,
                    'times', NEW.preferred_times,
                    'frequency', NEW.communication_frequency
                ),
            'organization_id', u.organization_id,
                'last_updated', CURRENT_TIMESTAMP
        )
    FROM users u
        WHERE u.id = NEW.customer_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for customer preferences
CREATE TRIGGER customer_preferences_embedding_trigger
    AFTER INSERT OR UPDATE ON customer_preferences
    FOR EACH ROW
    EXECUTE FUNCTION handle_customer_preferences();

-- Drop trigger for organization embeddings
DROP TRIGGER IF EXISTS organization_embeddings_trigger ON organizations;

-- Organization embeddings with ticket tag requirement
CREATE OR REPLACE FUNCTION handle_organization_embeddings()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process if organization has:
    -- 1. Tickets with tags
    -- 2. Recent comments (within last 30 days)
    IF EXISTS (
        SELECT 1 
        FROM tickets t
        JOIN ticket_tags tt ON tt.ticket_id = t.id
        JOIN ticket_comments tc ON tc.ticket_id = t.id
        WHERE t.organization_id = NEW.id
        AND tc.created_at > NOW() - INTERVAL '30 days'
    ) THEN
        INSERT INTO embedding_queue (entity_id, entity_type, content, metadata)
        SELECT 
        NEW.id,
            'organization',
            NEW.name || ' - ' || NEW.description || ' - ' || NEW.domain,
        jsonb_build_object(
            'id', NEW.id,
                'type', 'organization',
                'domain', NEW.domain,
                'customer_count', (
                    SELECT COUNT(*) FROM users 
                    WHERE organization_id = NEW.id 
                    AND role = 'customer'
                ),
                'common_issues', (
                    SELECT jsonb_agg(DISTINCT tag.name)
                    FROM tickets t
                    JOIN ticket_tags tt ON tt.ticket_id = t.id
                    JOIN tags tag ON tag.id = tt.tag_id
                    WHERE t.organization_id = NEW.id
                    GROUP BY t.organization_id
                ),
                'last_updated', CURRENT_TIMESTAMP
            )
        FROM organizations
        WHERE id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for organization embeddings
CREATE TRIGGER organization_embeddings_trigger
    AFTER INSERT OR UPDATE ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION handle_organization_embeddings();

-- Drop trigger for ticket patterns
DROP TRIGGER IF EXISTS ticket_patterns_trigger ON tickets;

-- Ticket patterns with tag requirement
CREATE OR REPLACE FUNCTION handle_ticket_patterns()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process if:
    -- 1. Ticket has tags
    -- 2. Has recent comments
    IF EXISTS (
        SELECT 1 
        FROM ticket_tags tt 
        JOIN ticket_comments tc ON tc.ticket_id = NEW.id
        WHERE tt.ticket_id = NEW.id
        AND tc.created_at > NOW() - INTERVAL '30 days'
    ) THEN
        INSERT INTO embedding_queue (entity_id, entity_type, content, metadata)
        SELECT 
            NEW.organization_id,
            'organization_ticket_patterns',
            string_agg(t.subject || ' - ' || t.description, ' | '),
            jsonb_build_object(
                'id', NEW.organization_id,
                'type', 'ticket_patterns',
                'common_priorities', jsonb_agg(DISTINCT t.priority),
                'frequent_tags', (
                    SELECT jsonb_agg(tag_counts)
                    FROM (
                        SELECT tag.name, COUNT(*) as count
                        FROM ticket_tags tt
                        JOIN tags tag ON tag.id = tt.tag_id
                        WHERE tt.ticket_id IN (SELECT id FROM tickets WHERE organization_id = NEW.organization_id)
                        GROUP BY tag.name
                        ORDER BY count DESC
                        LIMIT 5
                    ) tag_counts
                ),
                'last_updated', CURRENT_TIMESTAMP
            )
        FROM tickets t
        WHERE t.organization_id = NEW.organization_id
        AND EXISTS (
            SELECT 1 FROM ticket_tags tt WHERE tt.ticket_id = t.id
        )
        GROUP BY t.organization_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for ticket patterns
CREATE TRIGGER ticket_patterns_trigger
    AFTER INSERT OR UPDATE ON tickets
    FOR EACH ROW
    EXECUTE FUNCTION handle_ticket_patterns();

-- Drop trigger for interaction patterns
DROP TRIGGER IF EXISTS interaction_patterns_trigger ON ticket_comments;

-- Interaction patterns based on ticket comments and customer preferences
CREATE OR REPLACE FUNCTION handle_interaction_patterns()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process if:
    -- 1. Customer has preferences
    -- 2. Ticket has tags
    -- 3. Has recent comments
    IF EXISTS (
        SELECT 1 
        FROM customer_preferences cp
        JOIN tickets t ON t.requester_id = cp.customer_id
        JOIN ticket_tags tt ON tt.ticket_id = t.id
        JOIN ticket_comments tc ON tc.ticket_id = t.id
        WHERE t.id = NEW.ticket_id
        AND tc.created_at > NOW() - INTERVAL '30 days'
    ) THEN
        INSERT INTO embedding_queue (entity_id, entity_type, content, metadata)
        SELECT 
            t.requester_id,
            'customer_interactions_patterns',
            string_agg(tc.content, ' | '),
            jsonb_build_object(
                'id', t.requester_id,
                'type', 'interaction_patterns',
                'preferences', (
                    SELECT jsonb_build_object(
                        'style', cp.preferred_style,
                        'times', cp.preferred_times,
                        'frequency', cp.communication_frequency
                    )
                    FROM customer_preferences cp
                    WHERE cp.customer_id = t.requester_id
                ),
                'response_patterns', (
                    SELECT jsonb_agg(jsonb_build_object(
                        'time_of_day', date_part('hour', tc.created_at),
                        'content_length', length(tc.content),
                        'is_private', tc.is_private
                    ))
                    FROM ticket_comments tc
                    WHERE tc.ticket_id = t.id
                    GROUP BY date_part('hour', tc.created_at)
                ),
                'last_updated', CURRENT_TIMESTAMP
            )
        FROM tickets t
        JOIN ticket_comments tc ON tc.ticket_id = t.id
        WHERE t.id = NEW.ticket_id
        GROUP BY t.requester_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for interaction patterns
CREATE TRIGGER interaction_patterns_trigger
    AFTER INSERT OR UPDATE ON ticket_comments
    FOR EACH ROW
    EXECUTE FUNCTION handle_interaction_patterns();

-- Drop Trigger track message edits and effectiveness for fine-tuning
DROP TRIGGER IF EXISTS message_edits_trigger ON communication_history;

-- Track message edits and effectiveness for fine-tuning
CREATE OR REPLACE FUNCTION handle_message_edits() 
RETURNS TRIGGER AS $$
BEGIN
    -- Only process if message was edited and has effectiveness metrics
    IF NEW.message_text != OLD.message_text AND NEW.effectiveness_metrics IS NOT NULL THEN
        -- Queue for fine-tuning
        INSERT INTO embedding_queue (entity_id, entity_type, content, metadata)
        SELECT 
            NEW.id,
            'message_edit',
            NEW.message_text,
            jsonb_build_object(
                'type', 'message_edit',
                'original_text', OLD.message_text,
                'edited_text', NEW.message_text,
                'effectiveness', NEW.effectiveness_metrics,
                'template_id', NEW.template_id,
                'customer_id', NEW.customer_id,
                'last_updated', CURRENT_TIMESTAMP
            );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create Trigger track message edits and effectiveness for fine-tuning
CREATE TRIGGER message_edits_trigger
    AFTER UPDATE ON communication_history
    FOR EACH ROW
    EXECUTE FUNCTION handle_message_edits();

-- Drop trigger track timing and style effectiveness
DROP TRIGGER IF EXISTS communication_effectiveness_trigger ON communication_history;

-- Track timing and style effectiveness
CREATE OR REPLACE FUNCTION handle_communication_effectiveness() 
RETURNS TRIGGER AS $$
BEGIN
    -- Only process if we have effectiveness metrics
    IF NEW.effectiveness_metrics IS NOT NULL THEN
        -- Update customer preferences based on successful communications
        UPDATE customer_preferences
        SET 
            preferred_times = jsonb_set(
                preferred_times,
                '{successful_hours}',
                COALESCE(
                    preferred_times->'successful_hours', '[]'::jsonb
                ) || to_jsonb(EXTRACT(HOUR FROM NEW.sent_at))
            ),
            updated_at = CURRENT_TIMESTAMP
        WHERE customer_id = NEW.customer_id
        AND (NEW.effectiveness_metrics->>'customer_satisfaction')::float > 4.0;
        
        -- Queue for style analysis
        INSERT INTO embedding_queue (entity_id, entity_type, content, metadata)
        SELECT 
            NEW.id,
            'message_style_analysis',
            NEW.message_text,
            jsonb_build_object(
                'type', 'style_analysis',
                'effectiveness', NEW.effectiveness_metrics,
                'customer_id', NEW.customer_id,
                'sent_at', NEW.sent_at,
                'template_id', NEW.template_id,
                'last_updated', CURRENT_TIMESTAMP
            );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger track timing and style effectiveness
CREATE TRIGGER communication_effectiveness_trigger
    AFTER INSERT OR UPDATE ON communication_history
    FOR EACH ROW
    EXECUTE FUNCTION handle_communication_effectiveness();

-- Drop trigger to update recommendations on communication changes
DROP TRIGGER IF EXISTS update_recommendations_trigger ON communication_history;

-- Function to handle recommendation updates
-- Update the function to handle null metadata
CREATE OR REPLACE FUNCTION update_customer_recommendations()
RETURNS TRIGGER AS $$
BEGIN
    -- Update customer preferences with new recommendations
    UPDATE customer_preferences
    SET 
        metadata = jsonb_set(
            COALESCE(metadata, '{}'::jsonb),
            '{recommendations}',
            (
                SELECT to_jsonb(recommendations.*)
                FROM analyze_communication_patterns(NEW.customer_id) recommendations
            )
        ),
        updated_at = CURRENT_TIMESTAMP
    WHERE customer_id = NEW.customer_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update recommendations on communication changes
CREATE TRIGGER update_recommendations_trigger 
    AFTER INSERT OR UPDATE ON communication_history
    FOR EACH ROW
    EXECUTE FUNCTION update_customer_recommendations();

