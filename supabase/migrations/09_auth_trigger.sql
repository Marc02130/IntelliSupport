-- Create a function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    default_org_id UUID;
BEGIN
    -- Get default organization ID
    SELECT id INTO default_org_id
    FROM public.organizations
    WHERE name = 'New User'
    LIMIT 1;

    -- Insert into public.users
    INSERT INTO public.users (
        id,
        email,
        first_name,
        last_name,
        role,
        organization_id,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        NEW.email,
        split_part(NEW.raw_user_meta_data->>'full_name', ' ', 1),
        split_part(NEW.raw_user_meta_data->>'full_name', ' ', 2),
        COALESCE(NEW.raw_user_meta_data->>'role', 'customer'),
        default_org_id,
        NOW(),
        NOW()
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a trigger to call this function after insert on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Add this after creating the trigger
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Allow the trigger to insert new users
CREATE POLICY "Enable insert for authentication service" ON public.users
    FOR INSERT
    WITH CHECK (true);  -- Allows the trigger to insert

-- Add policy to allow users to insert their own record
CREATE POLICY "Users can insert their own record" ON public.users
    FOR INSERT
    WITH CHECK (auth.uid() = id); 