# Anaira Healthcare v0.8.78 — Emergency New Patient & OPD Handoff

- Added New Patient registration entry points on Emergency / Casualty.
- Registers through the existing tenant-authorized `register_clinic_patient` RPC, preserving server-side duplicate detection and audit logging.
- Newly registered patient is immediately selected in the emergency visit form and appears in the shared patient list.
- Added Send selected patient to OPD action; OPD reads `patient_id` query parameter and preselects the patient in the OPD registration form.
- Emergency patient creation does not automatically create an OPD visit; staff explicitly use Send selected patient to OPD and complete complaint/department/doctor fields in OPD.
- Existing emergency visit and OPD creation workflows retained.

Verification: run `npm run typecheck`, `npm run build`, and test patient registration + OPD handoff against the configured Supabase project before production use.
