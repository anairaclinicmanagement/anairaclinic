# Anaira Healthcare v0.8.162 — Staff & Role Management Plugin Control

## Changes
- Added `staff` / Staff & Role Management to Super Admin's module catalogue. Super Admin can enable it per clinic using the existing Per-clinic module access control (`Force enable`), disable it (`Force disable`), or return to plan inheritance.
- Removed the unconditional owner/admin bypass for the Staff & Role Management sidebar link. The link now requires the effective `staff` entitlement and the user's role permission. Desktop sidebar and mobile All Menus share the same filtered links.
- Added Edit role controls to each active staff profile. The selected role is updated only for that profile in the currently selected clinic.
- Added Delete action as a safe soft-delete/deactivation (`staff_profiles.active=false`). The profile remains for audit/history; this does not delete the Supabase Auth identity or historical clinical records.
- No database schema migration and no existing tenant data changes.

## Verification
- `node scripts/verify-project.mjs` — PASS.
- `tsc --noEmit` — not conclusive because project dependencies/types (React, Next.js, lucide-react) are not installed in this environment; compiler reports missing modules and JSX types.
- Production build, browser E2E, live Supabase RLS/update tests — not run.
