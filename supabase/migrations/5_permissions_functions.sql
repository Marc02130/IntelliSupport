-- Create a function to check permissions
CREATE OR REPLACE FUNCTION public.check_navigation_permissions(nav_id UUID)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.role_permissions rp
        JOIN public.permissions p ON p.id = rp.permission_id
        JOIN public.roles r ON r.id = rp.role_id
        JOIN public.users u ON u.id = auth.uid() AND r.name = u.role
        JOIN public.sidebar_navigation sn ON sn.id = nav_id
        WHERE p.name = ANY(sn.permissions_required)
    );
END;
$$;

-- Create function to get navigation items for a user's role
CREATE OR REPLACE FUNCTION public.get_user_navigation(p_role text)
RETURNS TABLE (
    id uuid,
    name varchar(255),
    icon text,
    parent_id uuid,
    search_query_id uuid,
    url text,
    sort_order integer,
    permissions_required text[]
) 
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    WITH user_permissions AS (
        SELECT p.name as permission_name
        FROM public.role_permissions rp
        JOIN public.permissions p ON p.id = rp.permission_id
        JOIN public.roles r ON r.id = rp.role_id
        WHERE r.name = p_role
    )
    SELECT 
        sn.id,
        sn.name,
        sn.icon,
        sn.parent_id,
        sn.search_query_id,
        sn.url,
        sn.sort_order,
        sn.permissions_required
    FROM public.sidebar_navigation sn
    WHERE sn.is_active = true
        AND (
            sn.permissions_required IS NULL 
            OR sn.permissions_required = '{}'
            OR EXISTS (
                SELECT 1 
                FROM user_permissions up
                WHERE up.permission_name = ANY(sn.permissions_required)
            )
        )
    ORDER BY sn.sort_order;
$$; 

