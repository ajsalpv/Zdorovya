-- Zdorovya Migration: Closed Family System & Privacy
-- 1. Add privacy column to medicines
ALTER TABLE public.medicines ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE;

-- 2. Add tracking to reminders
ALTER TABLE public.medicine_reminders ADD COLUMN IF NOT EXISTS confirmed_by_id UUID REFERENCES public.family_members(id);
ALTER TABLE public.medicine_reminders ADD COLUMN IF NOT EXISTS nudge_count INT DEFAULT 0;

-- 3. Seed the 5 family members
-- Family ID (Standardized)
INSERT INTO public.families (id, name) 
VALUES ('00000000-0000-0000-0000-000000000000', 'Our Family')
ON CONFLICT (id) DO NOTHING;

-- Members (Standardized UUIDs)
INSERT INTO public.family_members (id, family_id, name, relationship)
VALUES 
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'Ajsal', 'Brother'),
  ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'Father', 'Father'),
  ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'Mother', 'Mother'),
  ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'Ansil', 'Brother'),
  ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000000', 'Ashhal', 'Brother')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, relationship = EXCLUDED.relationship;

-- 4. Update RLS for Private Data (Basic logic)
DROP POLICY IF EXISTS "Family data selection policy" ON public.medical_records;
CREATE POLICY "Family data selection policy"
ON public.medical_records
FOR SELECT
USING (
  is_private = FALSE 
  OR patient_id IN (SELECT id FROM public.family_members WHERE relationship = 'Father')
);
