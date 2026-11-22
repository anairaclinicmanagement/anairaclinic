# Premium Main Dashboard — v0.8.183

- Replaced the basic landing dashboard with a premium responsive clinic operations dashboard.
- Added live clinic-scoped KPIs for patients, today's appointments, active IPD admissions, available/occupied beds, invoice value, and outstanding dues.
- Added today's appointment list, quick actions for core clinic workflows, and billing collection summary.
- Bed occupancy is derived from active `admitted` / `transferred` admissions with assigned bed IDs; available beds are active room beds less occupied bed IDs.
- No demo data or schema migration added.

## Verification
- `node scripts/verify-project.mjs`: PASS (36 routes, 73 migrations, 21 required files).
- `app/page.tsx` TypeScript transpilation diagnostics: 0.
- Production build, live Supabase and browser E2E: not run.
