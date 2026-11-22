# Anaira Healthcare v0.8.24 — OPD/IPD status

## Existing modules
- OPD is present at `/opd` and includes reception parchi/queue workflow and linked-order migrations.
- IPD is present at `/ipd`; it was already a basic module, not a complete hospital inpatient suite.

## IPD improvements in this package
- Role-aware controls: room configuration is shown to clinic owner/admin; admissions, clinical notes and discharge controls are shown to owner/admin/doctor/nurse.
- Edit room details through the existing room form.
- Delete room is implemented as a soft deactivation, with confirmation popup and protection against deactivating a room that has active admissions.
- Edit admission notes through a modal popup.
- Cancel admission through a confirmation popup; the record is retained rather than physically deleted.
- Existing transactional admission and discharge RPCs and clinic scoping remain in place.
- Existing records remain real Supabase records. No fabricated clinical data is automatically inserted into a live clinic database.

## Not yet a full IPD suite
Numbered individual bed allocation, bed transfers, nursing observation/vitals chart, medication administration record, procedure/OT link, discharge medication reconciliation, insurance/TPA IPD billing, deposit/advance billing, and printable discharge summary are not implemented in this patch. These should be separate audited workflows, not represented as complete.

## Applying
Extract the ZIP and preserve `.env.local`. Apply existing migrations in order to the Supabase project. No new migration is required for the UI edits. Database RLS policies must be reviewed in the target project before production; UI role gating is not a substitute for server-side authorization.
