-- Zdorovya Database Schema
-- Run this in the Supabase SQL Editor

-- 1. Enable Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Profiles Table (Extends Supabase Auth)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  role TEXT CHECK (role IN ('admin', 'member')) DEFAULT 'member',
  family_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Family Groups
CREATE TABLE IF NOT EXISTS public.families (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  admin_id UUID REFERENCES public.profiles(id),
  join_code TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Associate profiles with families
ALTER TABLE public.profiles 
ADD CONSTRAINT fk_family 
FOREIGN KEY (family_id) REFERENCES public.families(id);

-- 4. Family Members (People without separate logins, or linking profiles)
CREATE TABLE IF NOT EXISTS public.family_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id), -- Null if just a profile for tracking (e.g. Father)
  name TEXT NOT NULL,
  relationship TEXT NOT NULL, -- 'Father', 'Mother', 'Brother', etc.
  blood_group TEXT,
  conditions TEXT[], -- Array of chronic conditions
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Medical Records
CREATE TABLE IF NOT EXISTS public.medical_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES public.family_members(id) ON DELETE CASCADE,
  uploader_id UUID REFERENCES public.profiles(id),
  type TEXT NOT NULL, -- 'ECG', 'Blood Test', 'Prescription', 'Receipt', etc.
  file_url TEXT NOT NULL,
  extracted_text TEXT,
  metadata JSONB DEFAULT '{}'::jsonb, -- AI extracted data (date, doctor, summary)
  is_private BOOLEAN DEFAULT FALSE,
  record_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Medicines
CREATE TABLE IF NOT EXISTS public.medicines (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES public.family_members(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  dosage TEXT,
  frequency TEXT, -- e.g. "2 times a day"
  duration TEXT,
  stock_quantity INT DEFAULT 0,
  min_stock_alert INT DEFAULT 5,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Reminders (Historical logs and future schedules)
CREATE TABLE IF NOT EXISTS public.medicine_reminders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  medicine_id UUID REFERENCES public.medicines(id) ON DELETE CASCADE,
  scheduled_time TIME NOT NULL,
  taken_at TIMESTAMPTZ,
  status TEXT CHECK (status IN ('pending', 'taken', 'missed')) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT CURRENT_DATE
);

-- 8. Appointments
CREATE TABLE IF NOT EXISTS public.appointments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  family_id UUID REFERENCES public.families(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES public.family_members(id) ON DELETE CASCADE,
  doctor_name TEXT,
  date_time TIMESTAMPTZ NOT NULL,
  notes TEXT,
  location TEXT,
  status TEXT DEFAULT 'scheduled'
);

-- ==========================================
-- ROW LEVEL SECURITY (RLS)
-- ==========================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medical_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicine_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

-- Families: Access if you are the admin or in the family (via profile)
CREATE POLICY "Users can view their own family"
ON public.families
FOR SELECT
USING (
  id IN (SELECT family_id FROM public.profiles WHERE id = auth.uid())
);

-- Profiles: Users can see profiles in their family
CREATE POLICY "Family members can view each other's profiles"
ON public.profiles
FOR SELECT
USING (
  family_id IN (SELECT family_id FROM public.profiles WHERE id = auth.uid())
);

-- Medical Records
CREATE POLICY "Family data selection policy"
ON public.medical_records
FOR SELECT
USING (
  family_id IN (SELECT family_id FROM public.profiles WHERE id = auth.uid())
  AND (
    is_private = FALSE 
    OR uploader_id = auth.uid()
    OR patient_id IN (SELECT id FROM public.family_members WHERE relationship = 'Father')
    OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  )
);

-- Medicines: Shared for family
CREATE POLICY "Family can view medicines"
ON public.medicines
FOR ALL
USING (family_id IN (SELECT family_id FROM public.profiles WHERE id = auth.uid()));

-- Real-time setup
ALTER PUBLICATION supabase_realtime ADD TABLE public.medicine_reminders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.medical_records;
