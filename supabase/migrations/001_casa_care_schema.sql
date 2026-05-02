-- Casa Care Supabase Schema
-- Paste this entire file into Supabase SQL Editor and run

-- ============ ENUMS ============
CREATE TYPE user_tier AS ENUM ('individual', 'nri', 'corporate', 'field_force');
CREATE TYPE user_role AS ENUM ('customer', 'staff');
CREATE TYPE service_category AS ENUM ('ac', 'ro', 'plumbing', 'carpentry', 'painting', 'nri_property', 'movers', 'amc');
CREATE TYPE ticket_status AS ENUM ('pending', 'assigned', 'open', 'en_route', 'in_progress', 'awaiting_qc', 'rework', 'qc_passed', 'closed');
CREATE TYPE payment_mode AS ENUM ('upi', 'card', 'pay_later', 'cod');
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');
CREATE TYPE qc_verdict AS ENUM ('passed', 'rework_needed', 'dispute_raised');
CREATE TYPE language AS ENUM ('en', 'hi', 'ta', 'te', 'kn', 'ml', 'gu', 'mr', 'pa', 'bn', 'or', 'as', 'ne', 'si', 'ur');

-- ============ USERS & PROFILES ============
CREATE TABLE user_profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  phone TEXT NOT NULL UNIQUE,
  role user_role NOT NULL DEFAULT 'customer',
  tier user_tier NOT NULL,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  address TEXT NOT NULL,
  city TEXT,
  zip_code TEXT,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  language language DEFAULT 'en',
  kyc_doc_url TEXT, -- for NRI/Corporate
  kyc_verified BOOLEAN DEFAULT FALSE,
  profile_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  CONSTRAINT valid_tier CHECK (tier IN ('individual', 'nri', 'corporate', 'field_force')),
  CONSTRAINT staff_requires_kyc CHECK (role <> 'staff' OR kyc_doc_url IS NOT NULL)
);

CREATE INDEX idx_user_profiles_phone ON user_profiles(phone);
CREATE INDEX idx_user_profiles_role ON user_profiles(role);
CREATE INDEX idx_user_profiles_tier ON user_profiles(tier);
CREATE INDEX idx_user_profiles_city ON user_profiles(city);

-- ============ FIELD AGENTS (Technicians) ============
CREATE TABLE field_agents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT UNIQUE,
  email TEXT,
  categories service_category[] NOT NULL, -- certified categories
  availability_status TEXT DEFAULT 'available', -- available | busy | offline
  current_latitude DECIMAL(10, 8),
  current_longitude DECIMAL(11, 8),
  rating DECIMAL(3, 2) DEFAULT 5.0, -- average customer rating
  completed_jobs INT DEFAULT 0,
  rework_count INT DEFAULT 0,
  response_time_seconds INT, -- avg response time to offers
  certified_date TIMESTAMP,
  background_check_passed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_field_agents_status ON field_agents(availability_status);
CREATE INDEX idx_field_agents_rating ON field_agents(rating DESC);

-- ============ SERVICE PRICING ============
CREATE TABLE service_pricing (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  category service_category NOT NULL UNIQUE,
  base_price DECIMAL(10, 2) NOT NULL,
  currency TEXT DEFAULT 'INR',
  description TEXT,
  typical_duration_minutes INT, -- estimated time on site
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Insert mock pricing
INSERT INTO service_pricing (category, base_price, description, typical_duration_minutes) VALUES
  ('ac', 800, 'AC repair or service', 60),
  ('ro', 500, 'RO filter replacement', 30),
  ('plumbing', 600, 'Plumbing repair', 45),
  ('carpentry', 1200, 'Carpentry work', 120),
  ('painting', 40, 'Painting per sq ft', 480),
  ('nri_property', 2000, 'NRI property inspection', 90),
  ('movers', 5000, 'Local moving service', 240),
  ('amc', 1500, 'Annual maintenance contract', 60);

-- ============ ASSETS (QR-tracked items) ============
CREATE TABLE assets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,
  qr_code TEXT UNIQUE,
  category service_category NOT NULL,
  asset_name TEXT NOT NULL, -- "Living room AC", "Kitchen RO", etc
  serial_number TEXT,
  location_address TEXT,
  purchase_date DATE,
  warranty_expiry DATE,
  last_service_date DATE,
  next_service_due DATE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_assets_user ON assets(user_id);
CREATE INDEX idx_assets_qr ON assets(qr_code);

-- ============ SERVICE REQUESTS (Tickets) ============
CREATE TABLE service_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ticket_id TEXT UNIQUE DEFAULT ('TKT-' || TO_CHAR(NOW(), 'YYMMDD') || '-' || LPAD((FLOOR(RANDOM() * 10000))::INT::TEXT, 4, '0')),
  user_id UUID NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,
  asset_id UUID REFERENCES assets(id) ON DELETE SET NULL,
  category service_category NOT NULL,
  status ticket_status DEFAULT 'pending',
  description TEXT,
  issue_photos TEXT[], -- array of R2 URLs
  issue_latitude DECIMAL(10, 8),
  issue_longitude DECIMAL(11, 8),
  service_address TEXT NOT NULL,
  preferred_slot_start TIMESTAMP,
  preferred_slot_end TIMESTAMP,
  estimated_price DECIMAL(10, 2),
  revised_quote DECIMAL(10, 2),
  revision_reason TEXT,
  revision_approved BOOLEAN,
  assigned_to UUID REFERENCES user_profiles(user_id) ON DELETE SET NULL,
  assigned_agent_id UUID REFERENCES field_agents(id) ON DELETE SET NULL,
  assignment_count INT DEFAULT 0,
  before_photos TEXT[], -- after assignment
  after_photos TEXT[], -- after work
  customer_otp TEXT, -- 4-digit signoff OTP
  customer_satisfied BOOLEAN,
  customer_rating INT, -- 1-5
  customer_comment TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  closed_at TIMESTAMP
);

CREATE INDEX idx_service_requests_user ON service_requests(user_id);
CREATE INDEX idx_service_requests_status ON service_requests(status);
CREATE INDEX idx_service_requests_pending_jobs ON service_requests(status, created_at) WHERE assigned_to IS NULL;
CREATE INDEX idx_service_requests_assigned_to ON service_requests(assigned_to);
CREATE INDEX idx_service_requests_agent ON service_requests(assigned_agent_id);
CREATE INDEX idx_service_requests_category ON service_requests(category);

-- ============ TICKET EVENTS (Audit log) ============
CREATE TABLE ticket_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ticket_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- 'created', 'assigned', 'en_route', 'arrived', 'diagnosed', 'work_started', 'work_completed', 'qc_review', 'qc_passed', 'rework_assigned', 'payment_made', 'closed'
  actor_id UUID, -- user_id or agent_id who triggered
  actor_type TEXT, -- 'customer', 'agent', 'system', 'qc_team'
  location_latitude DECIMAL(10, 8),
  location_longitude DECIMAL(11, 8),
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_ticket_events_ticket ON ticket_events(ticket_id);
CREATE INDEX idx_ticket_events_type ON ticket_events(event_type);

-- ============ QC REVIEWS ============
CREATE TABLE qc_reviews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ticket_id UUID NOT NULL UNIQUE REFERENCES service_requests(id) ON DELETE CASCADE,
  qc_reviewer_id UUID, -- staff member
  verdict qc_verdict DEFAULT 'passed',
  photo_quality BOOLEAN,
  location_verified BOOLEAN,
  time_on_site_reasonable BOOLEAN,
  parts_logged BOOLEAN,
  customer_rating_checked BOOLEAN,
  verification_call_made BOOLEAN,
  reviewer_notes TEXT,
  reviewed_at TIMESTAMP DEFAULT NOW(),
  rework_required_reason TEXT
);

CREATE INDEX idx_qc_reviews_ticket ON qc_reviews(ticket_id);
CREATE INDEX idx_qc_reviews_verdict ON qc_reviews(verdict);

-- ============ PAYMENTS & INVOICES ============
CREATE TABLE invoices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ticket_id UUID NOT NULL UNIQUE REFERENCES service_requests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,
  invoice_number TEXT UNIQUE,
  service_charge DECIMAL(10, 2) NOT NULL,
  parts_charge DECIMAL(10, 2) DEFAULT 0,
  gst_rate DECIMAL(5, 2) DEFAULT 18,
  gst_amount DECIMAL(10, 2),
  total_amount DECIMAL(10, 2) NOT NULL,
  payment_mode payment_mode NOT NULL,
  payment_status payment_status DEFAULT 'pending',
  paid_at TIMESTAMP,
  payment_ref TEXT,
  notes TEXT,
  generated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_invoices_user ON invoices(user_id);
CREATE INDEX idx_invoices_status ON invoices(payment_status);

-- ============ AMC (Annual Maintenance Contracts) ============
CREATE TABLE amc_contracts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,
  asset_id UUID REFERENCES assets(id) ON DELETE SET NULL,
  contract_start DATE NOT NULL,
  contract_end DATE NOT NULL,
  visits_included INT DEFAULT 4,
  visits_remaining INT DEFAULT 4,
  annual_fee DECIMAL(10, 2) NOT NULL,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_amc_user ON amc_contracts(user_id);
CREATE INDEX idx_amc_active ON amc_contracts(active);

-- ============ PREDICTIVE MAINTENANCE ============
CREATE TABLE maintenance_schedule (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,
  next_service_date DATE,
  category service_category,
  reason TEXT, -- e.g., "AC filter change due in 6 months"
  confidence_score DECIMAL(3, 2), -- 0.0-1.0 based on AI prediction
  created_at TIMESTAMP DEFAULT NOW(),
  reminded BOOLEAN DEFAULT FALSE,
  reminder_sent_at TIMESTAMP
);

CREATE INDEX idx_maintenance_user ON maintenance_schedule(user_id);
CREATE INDEX idx_maintenance_asset ON maintenance_schedule(asset_id);
CREATE INDEX idx_maintenance_date ON maintenance_schedule(next_service_date);

-- ============ LOYALTY & WALLET ============
CREATE TABLE loyalty_points (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES user_profiles(user_id) ON DELETE CASCADE,
  points_balance INT DEFAULT 0,
  points_redeemed INT DEFAULT 0,
  last_updated TIMESTAMP DEFAULT NOW()
);

CREATE TABLE loyalty_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,
  ticket_id UUID REFERENCES service_requests(id) ON DELETE SET NULL,
  points_change INT,
  reason TEXT, -- 'service_completed', 'referral', 'review', 'redemption'
  created_at TIMESTAMP DEFAULT NOW()
);

-- ============ ROW LEVEL SECURITY (RLS) ============

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE field_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE qc_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE amc_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_transactions ENABLE ROW LEVEL SECURITY;

-- Storage bucket for persisted KYC documents
INSERT INTO storage.buckets (id, name, public)
VALUES ('kyc-documents', 'kyc-documents', FALSE)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users upload own KYC documents" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'kyc-documents'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

CREATE POLICY "Users view own KYC documents" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'kyc-documents'
    AND auth.uid()::TEXT = (storage.foldername(name))[1]
  );

CREATE OR REPLACE FUNCTION enforce_profile_verification_control()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND auth.uid() = NEW.user_id THEN
    NEW.kyc_verified = FALSE;
    NEW.profile_verified = FALSE;
  END IF;

  IF TG_OP = 'UPDATE' AND auth.uid() = NEW.user_id THEN
    NEW.role = OLD.role;
    NEW.kyc_verified = OLD.kyc_verified;
    NEW.profile_verified = OLD.profile_verified;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_profiles_protect_verification
  BEFORE INSERT OR UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION enforce_profile_verification_control();

-- Policy: Users can only view their own profile
CREATE POLICY "Users view own profile" ON user_profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users insert own profile" ON user_profiles
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND kyc_verified = FALSE
    AND profile_verified = FALSE
  );

CREATE POLICY "Users update own profile" ON user_profiles
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND role = (SELECT role FROM user_profiles WHERE user_id = auth.uid())
  );

-- Policy: Users can view their own service requests
CREATE POLICY "Users view own requests" ON service_requests
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Staff view pending requests" ON service_requests
  FOR SELECT USING (
    status = 'pending'
    AND assigned_to IS NULL
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'staff'
      AND kyc_verified IS TRUE
    )
  );

CREATE POLICY "Staff view assigned requests" ON service_requests
  FOR SELECT USING (
    assigned_to = auth.uid()
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid()
      AND role = 'staff'
      AND kyc_verified IS TRUE
    )
  );

CREATE POLICY "Users create own requests" ON service_requests
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION claim_service_request(request_id UUID)
RETURNS SETOF service_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  requester UUID := auth.uid();
BEGIN
  IF requester IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = requester
    AND role = 'staff'
    AND kyc_verified IS TRUE
  ) THEN
    RAISE EXCEPTION 'Verified staff profile required';
  END IF;

  RETURN QUERY
  UPDATE public.service_requests
  SET
    assigned_to = requester,
    status = 'assigned',
    updated_at = NOW()
  WHERE id = request_id
    AND status = 'pending'
    AND assigned_to IS NULL
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION claim_service_request(UUID) TO authenticated;

REVOKE UPDATE ON service_requests FROM authenticated;

-- Policy: Users can view their own assets
CREATE POLICY "Users view own assets" ON assets
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users manage own assets" ON assets
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own assets" ON assets
  FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Agents can view their assigned tickets
CREATE POLICY "Agents view assigned tickets" ON service_requests
  FOR SELECT USING (
    assigned_agent_id = (
      SELECT id FROM field_agents WHERE user_id = auth.uid()
    )
  );

-- ============ TRIGGERS (auto-update timestamps) ============

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER assets_updated_at
  BEFORE UPDATE ON assets
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER service_requests_updated_at
  BEFORE UPDATE ON service_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- ============ SEEDING: Mock Agents ============

INSERT INTO auth.users (id, email, phone, phone_confirmed_at, created_at) VALUES
  (gen_random_uuid(), 'rajesh@casacare.in', '+919876543210', NOW(), NOW()),
  (gen_random_uuid(), 'priya@casacare.in', '+919876543211', NOW(), NOW()),
  (gen_random_uuid(), 'amit@casacare.in', '+919876543212', NOW(), NOW()),
  (gen_random_uuid(), 'neha@casacare.in', '+919876543213', NOW(), NOW()),
  (gen_random_uuid(), 'sanjay@casacare.in', '+919876543214', NOW(), NOW());

-- Link agents (run after getting user IDs from above)
-- INSERT INTO field_agents (user_id, name, phone, categories, rating, completed_jobs, certified_date, background_check_passed)
-- VALUES
--   ('user-id-1', 'Rajesh Kumar', '+919876543210', ARRAY['ac', 'ro']::service_category[], 4.8, 127, NOW(), TRUE),
--   ('user-id-2', 'Priya Singh', '+919876543211', ARRAY['plumbing', 'carpentry']::service_category[], 4.9, 89, NOW(), TRUE),
--   ('user-id-3', 'Amit Patel', '+919876543212', ARRAY['ac', 'ro', 'plumbing']::service_category[], 4.6, 156, NOW(), TRUE),
--   ('user-id-4', 'Neha Reddy', '+919876543213', ARRAY['painting', 'carpentry']::service_category[], 4.7, 92, NOW(), TRUE),
--   ('user-id-5', 'Sanjay Verma', '+919876543214', ARRAY['ac', 'ro', 'nri_property']::service_category[], 5.0, 203, NOW(), TRUE);

-- ============ GRANTS (For service role if using) ============
-- GRANT USAGE ON SCHEMA public TO anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO authenticated;

-- ============ END OF SCHEMA ============
