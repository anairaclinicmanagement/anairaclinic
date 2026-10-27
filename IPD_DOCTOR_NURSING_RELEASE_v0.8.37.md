# Anaira Clinic v0.8.37 — Doctor & Nursing IPD workflows

## Included
- Doctor & Clinical Details modal now saves admission-linked visit entries, initial assessment, diagnosis, progress notes, doctor orders, treatment plans, consultant notes, and follow-up dates using `create_ipd_clinical_record`.
- Added clinic-scoped `ipd_clinical_records` table, role-gated RPC, audit event, and read policy in Supabase migration.
- Added individual physical-bed register with current patient/admission, available/occupied status, and transfer/admit actions.
- Nursing chart form continues to save vitals, nursing notes, intake/output, MAR, injection/IV, monitoring, and shift handover via the existing RPC; chart entries display in the nursing register.
- Added migration `20261026120000_anaira_ipd_doctor_clinical_records.sql`.

## Important
The migration is applied to the connected Supabase project. Run local dependency installation, TypeScript check and production build before deployment. Test with real authenticated doctor/nurse roles and clinic data; do not use demo records as clinical data. This is not a medical-device or clinical-safety certification.
