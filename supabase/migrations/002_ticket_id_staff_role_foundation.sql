-- Add reusable ticket IDs and staff-profile foundation for existing databases.

CREATE OR REPLACE FUNCTION generate_ticket_id()
RETURNS TEXT AS $$
BEGIN
  RETURN 'CASA-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 6));
END;
$$ LANGUAGE plpgsql;

ALTER TABLE service_requests
  ALTER COLUMN ticket_id SET DEFAULT generate_ticket_id();

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('user', 'nri', 'corporate', 'staff');
  END IF;
END $$;

ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'staff';

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS role user_role DEFAULT 'user';

UPDATE user_profiles
SET role = 'staff'
WHERE role = 'user'
  AND EXISTS (
    SELECT 1
    FROM field_agents
    WHERE field_agents.user_id = user_profiles.user_id
  );

ALTER TYPE ticket_status ADD VALUE IF NOT EXISTS 'pending' BEFORE 'open';

ALTER TABLE service_requests
  ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_service_requests_assigned_to
  ON service_requests(assigned_to);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_profiles'
      AND policyname = 'Users can create their own profile'
  ) THEN
    CREATE POLICY "Users can create their own profile" ON user_profiles
      FOR INSERT WITH CHECK (auth.uid() = user_id AND role = 'user');
  END IF;
END $$;

CREATE OR REPLACE FUNCTION prevent_user_role_escalation()
RETURNS TRIGGER AS $$
BEGIN
  IF current_user IN ('postgres', 'service_role') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' AND NEW.role <> 'user' THEN
    RAISE EXCEPTION 'Users cannot assign elevated profile roles';
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Users cannot change profile roles';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

REVOKE EXECUTE ON FUNCTION prevent_user_role_escalation() FROM PUBLIC;

DROP TRIGGER IF EXISTS user_profiles_prevent_role_escalation ON user_profiles;
CREATE TRIGGER user_profiles_prevent_role_escalation
  BEFORE INSERT OR UPDATE OF role ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION prevent_user_role_escalation();

CREATE OR REPLACE FUNCTION prevent_unauthorized_service_request_assignment()
RETURNS TRIGGER AS $$
BEGIN
  IF current_user IN ('postgres', 'service_role') THEN
    RETURN NEW;
  END IF;

  IF NEW.assigned_agent_id IS DISTINCT FROM OLD.assigned_agent_id THEN
    RAISE EXCEPTION 'Only service role can change assigned agents';
  END IF;

  IF NEW.assigned_to IS DISTINCT FROM OLD.assigned_to THEN
    IF OLD.assigned_to IS NOT NULL THEN
      RAISE EXCEPTION 'Assigned service requests cannot be reassigned by users';
    END IF;

    IF NEW.assigned_to IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'Only staff can claim service requests for themselves';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM user_profiles
      WHERE user_profiles.user_id = auth.uid()
        AND user_profiles.role = 'staff'
    ) THEN
      RAISE EXCEPTION 'Only staff can claim service requests';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

REVOKE EXECUTE ON FUNCTION prevent_unauthorized_service_request_assignment() FROM PUBLIC;

DROP TRIGGER IF EXISTS service_requests_prevent_unauthorized_assignment ON service_requests;
CREATE TRIGGER service_requests_prevent_unauthorized_assignment
  BEFORE UPDATE OF assigned_to, assigned_agent_id ON service_requests
  FOR EACH ROW
  EXECUTE FUNCTION prevent_unauthorized_service_request_assignment();
