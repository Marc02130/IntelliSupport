-- Function to queue a message for generation
CREATE OR REPLACE FUNCTION queue_message_generation(
    p_customer_id UUID,
    p_context_type TEXT,
    p_input_context JSONB
) RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    -- Insert into message_generation_logs and get the ID
    INSERT INTO message_generation_logs (
        customer_id,
        context_type,
        input_context,
        status,
        started_at
    ) VALUES (
        p_customer_id,
        p_context_type,
        p_input_context,
        'queued',
        NOW()
    )
    RETURNING id INTO v_log_id;

    -- Notify the message generation service
    PERFORM pg_notify(
        'message_generation',
        json_build_object(
            'log_id', v_log_id,
            'customer_id', p_customer_id,
            'context_type', p_context_type
        )::text
    );

    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to process message generation queue
CREATE OR REPLACE FUNCTION process_message_queue()
RETURNS void AS $$
BEGIN
    -- Log start
    INSERT INTO cron_job_logs (job_name, status) 
    VALUES ('process-message-queue', 'started');

    BEGIN
        -- Call edge function to process messages
        PERFORM pg_notify('process_message_queue', '{}');

        -- Log success
        INSERT INTO cron_job_logs (job_name, status)
        VALUES ('process-message-queue', 'completed');

    EXCEPTION WHEN OTHERS THEN
        -- Log error
        INSERT INTO cron_job_logs (job_name, status, error)
        VALUES ('process-message-queue', 'failed', SQLERRM);
        RAISE;
    END;
END;
$$ LANGUAGE plpgsql;
