-- Add missing DELETE policy for activity_log table
-- Without this, RLS silently blocks all DELETE operations on activity_log

CREATE POLICY "activity_log_delete" ON activity_log FOR DELETE TO authenticated USING (true);

-- Prevent manager creation through the app (only via direct DB access)
CREATE OR REPLACE FUNCTION prevent_manager_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.role = 'manager' THEN
    RAISE EXCEPTION 'Manager accounts cannot be created through the app. Use Supabase dashboard directly.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER block_manager_insert
  BEFORE INSERT ON staff
  FOR EACH ROW
  EXECUTE FUNCTION prevent_manager_insert();

-- Fix delete_staff_auth to accept TEXT parameter (PostgREST sends strings as text, not UUID)
CREATE OR REPLACE FUNCTION delete_staff_auth(p_user_id TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM auth.identities WHERE user_id = p_user_id::uuid;
  DELETE FROM auth.sessions WHERE user_id = p_user_id::uuid;
  DELETE FROM auth.refresh_tokens WHERE user_id = p_user_id::uuid;
  DELETE FROM auth.users WHERE id = p_user_id::uuid;
  RETURN FOUND;
END;
$$;

-- Prevent manager deletion through the app (only via direct DB access)
CREATE OR REPLACE FUNCTION prevent_manager_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.role = 'manager' THEN
    RAISE EXCEPTION 'Manager accounts cannot be deleted through the app. Use Supabase dashboard directly.';
  END IF;
  RETURN OLD;
END;
$$;

CREATE TRIGGER block_manager_delete
  BEFORE DELETE ON staff
  FOR EACH ROW
  EXECUTE FUNCTION prevent_manager_delete();
