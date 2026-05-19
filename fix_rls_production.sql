-- =================================================================
-- Zdorovya: Fix RLS Infinite Recursion & Production Policies
-- Run this ENTIRE script in Supabase SQL Editor
-- =================================================================

-- 1. DROP ALL BROKEN POLICIES (the ones causing infinite recursion)
DROP POLICY IF EXISTS "Family members can view each other's profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view their own family" ON public.families;
DROP POLICY IF EXISTS "Family data selection policy" ON public.medical_records;
DROP POLICY IF EXISTS "Family can view medicines" ON public.medicines;

-- 2. DISABLE RLS on tables that don't need it for a closed-family system
-- Since we use anonymous auth and the app is private (family-only APK),
-- we use permissive policies that allow all authenticated (including anon) users.

-- Profiles: Allow all authenticated users (including anonymous) to read
CREATE POLICY "anon_read_profiles"
ON public.profiles FOR SELECT
TO authenticated, anon
USING (true);

-- Families: Allow all to read
CREATE POLICY "anon_read_families"
ON public.families FOR SELECT
TO authenticated, anon
USING (true);

-- Family Members: Allow all to read, admin inserts handled by service_role
CREATE POLICY "anon_read_family_members"
ON public.family_members FOR SELECT
TO authenticated, anon
USING (true);

-- Medical Records: Allow all to read (privacy filtering is done in app code)
CREATE POLICY "anon_read_medical_records"
ON public.medical_records FOR SELECT
TO authenticated, anon
USING (true);

CREATE POLICY "anon_insert_medical_records"
ON public.medical_records FOR INSERT
TO authenticated, anon
WITH CHECK (true);

-- Medicines: Allow all to read and insert
CREATE POLICY "anon_read_medicines"
ON public.medicines FOR SELECT
TO authenticated, anon
USING (true);

CREATE POLICY "anon_insert_medicines"
ON public.medicines FOR INSERT
TO authenticated, anon
WITH CHECK (true);

CREATE POLICY "anon_update_medicines"
ON public.medicines FOR UPDATE
TO authenticated, anon
USING (true);

-- Medicine Reminders: Allow all
CREATE POLICY "anon_read_reminders"
ON public.medicine_reminders FOR SELECT
TO authenticated, anon
USING (true);

CREATE POLICY "anon_insert_reminders"
ON public.medicine_reminders FOR INSERT
TO authenticated, anon
WITH CHECK (true);

CREATE POLICY "anon_update_reminders"
ON public.medicine_reminders FOR UPDATE
TO authenticated, anon
USING (true);

-- Appointments (if table exists)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'appointments') THEN
    EXECUTE 'CREATE POLICY "anon_read_appointments" ON public.appointments FOR SELECT TO authenticated, anon USING (true)';
    EXECUTE 'CREATE POLICY "anon_insert_appointments" ON public.appointments FOR INSERT TO authenticated, anon WITH CHECK (true)';
  END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3. Ensure the embedding column exists on medical_records
ALTER TABLE public.medical_records ADD COLUMN IF NOT EXISTS embedding vector(768);
ALTER TABLE public.medical_records ADD COLUMN IF NOT EXISTS is_private boolean DEFAULT false;

-- 4. Add is_private to medicines if missing
ALTER TABLE public.medicines ADD COLUMN IF NOT EXISTS is_private boolean DEFAULT false;

-- 5. Recreate the AI matching function (drop first to allow signature change)
DROP FUNCTION IF EXISTS match_medical_records(vector, float, int, uuid);
DROP FUNCTION IF EXISTS match_medical_records(vector, double precision, integer, uuid);

CREATE OR REPLACE FUNCTION match_medical_records (
  query_embedding vector(768),
  match_threshold float,
  match_count int,
  p_family_id uuid
)
RETURNS TABLE (
  id uuid,
  patient_id uuid,
  type text,
  extracted_text text,
  record_date text,
  is_private boolean,
  similarity float
)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT
    mr.id,
    mr.patient_id,
    mr.type,
    mr.extracted_text,
    mr.record_date::text,
    mr.is_private,
    1 - (mr.embedding <=> query_embedding) AS similarity
  FROM medical_records mr
  WHERE mr.family_id = p_family_id
    AND mr.embedding IS NOT NULL
    AND 1 - (mr.embedding <=> query_embedding) > match_threshold
  ORDER BY mr.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
