DO $$
BEGIN
    -- Check if we're in a hosted environment by looking for the storage extension
    IF EXISTS (
        SELECT 1 
        FROM pg_available_extensions 
        WHERE name = 'storage'
    ) THEN
        -- Create storage extension
        CREATE EXTENSION IF NOT EXISTS "storage" SCHEMA "extensions";
        
        -- Single bucket for all attachments
        INSERT INTO storage.buckets (id, name, public) 
        VALUES ('attachments', 'attachments', false)
        ON CONFLICT DO NOTHING;
    END IF;
END $$; 