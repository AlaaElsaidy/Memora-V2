-- Update existing patients to have doctor_id from their family members
UPDATE public.patients
SET doctor_id = fm.doctor_id
FROM public.patient_family_relations pfr
JOIN public.family_members fm ON fm.id = pfr.family_member_id
WHERE patients.id = pfr.patient_id
  AND patients.doctor_id IS NULL
  AND fm.doctor_id IS NOT NULL;