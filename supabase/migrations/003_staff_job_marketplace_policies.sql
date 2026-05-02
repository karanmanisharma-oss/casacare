-- Staff-facing job marketplace policies.
-- This migration is separate from the enum update so the new ticket_status value
-- can be committed before policies and defaults reference it.

ALTER TABLE service_requests
  ALTER COLUMN status SET DEFAULT 'pending';

UPDATE service_requests
SET status = 'pending'
WHERE status = 'open'
  AND assigned_agent_id IS NULL
  AND assigned_to IS NULL;

DROP POLICY IF EXISTS "QC view all tickets" ON service_requests;

DROP POLICY IF EXISTS "Users create own requests" ON service_requests;
CREATE POLICY "Users create own requests"
ON service_requests FOR INSERT
WITH CHECK (
  auth.uid() = user_id
  AND assigned_to IS NULL
  AND assigned_agent_id IS NULL
);

DROP POLICY IF EXISTS "Users update own requests" ON service_requests;
CREATE POLICY "Users update own requests"
ON service_requests FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (
  auth.uid() = user_id
  AND assigned_to IS NULL
  AND assigned_agent_id IS NULL
);

DROP POLICY IF EXISTS "Staff can view available service requests" ON service_requests;
CREATE POLICY "Staff can view available service requests"
ON service_requests FOR SELECT
USING (
  status = 'pending'
  AND EXISTS (
    SELECT 1
    FROM user_profiles
    WHERE user_profiles.user_id = auth.uid()
      AND user_profiles.role = 'staff'
  )
);

DROP POLICY IF EXISTS "Staff can claim a job" ON service_requests;
CREATE POLICY "Staff can claim a job"
ON service_requests FOR UPDATE
USING (
  status = 'pending'
  AND assigned_to IS NULL
  AND EXISTS (
    SELECT 1
    FROM user_profiles
    WHERE user_profiles.user_id = auth.uid()
      AND user_profiles.role = 'staff'
  )
)
WITH CHECK (
  status = 'pending'
  AND assigned_to = auth.uid()
);
