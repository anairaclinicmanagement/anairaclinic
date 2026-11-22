# Anaira Healthcare v0.8.165

## Reports & Analytics
- Billing & Collection Report is explicitly anchored and positioned directly after report KPI cards, before the department/shift summary.
- Shows completed payment transactions by payment mode, patient, UHID, invoice, transaction reference, and date range; CSV export remains available.

## Super Admin tenant data reset
- Adds a clinic/hospital-specific reset panel with selectable data categories.
- Requires preview counts, exact clinic-name confirmation, and a second browser confirmation before execution.
- SQL migration adds platform-admin-only preview and reset RPCs. It targets only an explicit allowlist of public tables with a clinic_id column. Clinic identity, subscriptions, memberships, module settings, and platform audit logs are excluded.
- Reset runs transactionally; foreign-key failures roll back the transaction. A verified external database backup is strongly recommended before use.

## Important
- Apply `supabase/migrations/20261119160000_platform_admin_tenant_data_reset.sql` to the connected Supabase project before using the reset panel.
- No live Supabase schema/data was modified by packaging this ZIP.
- Production build and live database reset tests were not run in this environment.
