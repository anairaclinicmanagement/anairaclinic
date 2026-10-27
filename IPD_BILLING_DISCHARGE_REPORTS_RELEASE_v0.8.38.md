# Anaira Healthcare v0.8.38 — IPD Billing, Discharge, Reports & Additional Options

## Included in this update
- Added an admission-linked discharge workflow form for discharge type, final diagnosis, treatment summary, medicines on discharge, follow-up date, investigation summary and doctor's instructions.
- Added draft save and approval actions. Approval is blocked by the database RPC when any non-void/non-refunded admission invoice has an outstanding balance.
- Added a discharge register to the IPD workspace.
- Added IPD admission/bed/billing report summaries and CSV export of the currently filtered admission register.
- Added Additional Options shortcuts for transfer, referrals, consent/OT, patient records, insurance, emergency, staff, reports/audit access and settings/backup access.
- Kept IPD invoices in the existing shared `invoices` table with `admission_id`, so the same invoice register can include OPD and IPD billing.
- Added migration `supabase/migrations/20261026130000_anaira_ipd_discharge_reports_additional.sql`.

## Supabase
The migration was applied to the linked Anaira Healthcare project. It creates `ipd_discharge_records` and `save_ipd_discharge_workflow`, with clinic role checks and audit entries.

## Verification caveats
Static project verification passed before these final changes; it must be rerun. TypeScript/build/browser E2E verification is not certified because the current local environment reports missing type definition packages (`estree`, `json-schema`, `node`, `react`, `react-dom`). Additional Options shortcuts use existing routes where available; consent, documents, audit and backup still depend on the destination module's own complete implementation and permissions. No production-ready claim is made until install/build and live role-based workflows pass.
