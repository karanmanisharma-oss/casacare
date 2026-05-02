-- Reconcile pet service catalog drift between legacy and current app columns.
-- CREATE TABLE IF NOT EXISTS is not enough for evolved tables, so every column
-- this seed depends on is added explicitly before data is backfilled.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'pet_service_kind'
  ) THEN
    CREATE TYPE public.pet_service_kind AS ENUM (
      'grooming',
      'vet_visit',
      'feeding',
      'walking',
      'boarding'
    );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.pet_services (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY
);

ALTER TABLE public.pet_services
  ADD COLUMN IF NOT EXISTS service_code TEXT,
  ADD COLUMN IF NOT EXISTS service_name TEXT,
  ADD COLUMN IF NOT EXISTS duration_minutes INTEGER,
  ADD COLUMN IF NOT EXISTS base_price NUMERIC,
  ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS kind public.pet_service_kind,
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS base_price_inr INTEGER,
  ADD COLUMN IF NOT EXISTS duration_min INTEGER;

ALTER TABLE public.pet_services
  ALTER COLUMN active SET DEFAULT TRUE,
  ALTER COLUMN created_at SET DEFAULT NOW();

UPDATE public.pet_services
SET
  service_code = COALESCE(
    service_code,
    'PET_' || upper(regexp_replace(COALESCE(kind::TEXT, name, service_name, id::TEXT), '[^a-zA-Z0-9]+', '_', 'g'))
  ),
  service_name = COALESCE(service_name, name),
  name = COALESCE(name, service_name),
  base_price = COALESCE(base_price, base_price_inr::NUMERIC),
  duration_minutes = COALESCE(duration_minutes, duration_min),
  base_price_inr = COALESCE(base_price_inr, base_price::INTEGER),
  duration_min = COALESCE(duration_min, duration_minutes),
  active = COALESCE(active, TRUE),
  created_at = COALESCE(created_at, NOW())
WHERE service_code IS NULL
   OR service_name IS NULL
   OR name IS NULL
   OR base_price IS NULL AND base_price_inr IS NOT NULL
   OR duration_minutes IS NULL AND duration_min IS NOT NULL
   OR base_price_inr IS NULL AND base_price IS NOT NULL
   OR duration_min IS NULL AND duration_minutes IS NOT NULL
   OR active IS NULL
   OR created_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS pet_services_service_code_key
  ON public.pet_services (service_code);

INSERT INTO public.pet_services (
  service_code,
  service_name,
  kind,
  name,
  description,
  base_price,
  duration_minutes,
  base_price_inr,
  duration_min
) VALUES
  ('PET_GROOM_MOBILE_PREMIUM', 'Premium Grooming - Mobile', 'grooming', 'Premium Grooming - Mobile', 'Mobile copper-sink grooming, hypoallergenic shampoos', 1800, 90, 1800, 90),
  ('PET_GROOM_EXPRESS', 'Express Grooming', 'grooming', 'Express Grooming', 'Bath, brush, nail trim, ear clean', 900, 45, 900, 45),
  ('PET_VET_HOME_EXAM', 'In-Home Vet - General Exam', 'vet_visit', 'In-Home Vet - General Exam', 'Licensed vet, full physical, vaccinations available', 2400, 60, 2400, 60),
  ('PET_VET_HOME_VAX', 'In-Home Vet - Vaccination', 'vet_visit', 'In-Home Vet - Vaccination', 'Annual booster, on-site administration', 800, 30, 800, 30),
  ('PET_FEED_TWICE_DAILY', 'Daily Feeding Routine - Twice', 'feeding', 'Daily Feeding Routine - Twice', 'Two visits per day, fresh water, photo log', 1200, 30, 1200, 30),
  ('PET_WALK_DAILY', 'Walks - Daily', 'walking', 'Walks - Daily', 'Twice-daily walks with photo proof', 600, 30, 600, 30),
  ('PET_BOARD_PREMIUM', 'Boarding - Premium', 'boarding', 'Boarding - Premium', 'In-home boarding while owner is away (per night)', 1500, 1440, 1500, 1440)
ON CONFLICT (service_code) DO UPDATE
SET
  service_name = EXCLUDED.service_name,
  kind = COALESCE(public.pet_services.kind, EXCLUDED.kind),
  name = COALESCE(public.pet_services.name, EXCLUDED.name),
  description = COALESCE(public.pet_services.description, EXCLUDED.description),
  base_price = COALESCE(public.pet_services.base_price, EXCLUDED.base_price),
  duration_minutes = COALESCE(public.pet_services.duration_minutes, EXCLUDED.duration_minutes),
  base_price_inr = COALESCE(public.pet_services.base_price_inr, EXCLUDED.base_price_inr),
  duration_min = COALESCE(public.pet_services.duration_min, EXCLUDED.duration_min);

ALTER TABLE public.pet_services
  ALTER COLUMN service_code SET NOT NULL,
  ALTER COLUMN service_name SET NOT NULL,
  ALTER COLUMN active SET NOT NULL,
  ALTER COLUMN created_at SET NOT NULL;

ALTER TABLE public.pet_services ENABLE ROW LEVEL SECURITY;
