# Phase 0C Regression Verification — 2026-11-26

## Static checks executed

| Check | Result |
|---|---|
| ZIP integrity | PASS |
| Required source files | PASS |
| Pharmacy stock-count audit verifier | PASS |
| Phase 0C security migration verifier | PASS |
| Migration reconciliation verifier | PASS |
| Project static verifier | PASS |

Project verifier: 37 routes, 81 SQL migrations, 21 required files. It explicitly does not replace TypeScript, production build, database, browser E2E or tenant-isolation tests. No dependency installation was performed.

## Read-only live cloud inspection

Project: Anaira Clinic (`gdyvzvzmybbvufggxjty`).

- RPC signature: `public.pharmacy_submit_store_stock_count(uuid,uuid,uuid,numeric,text)`.
- Owner: `postgres`.
- SECURITY DEFINER: true.
- Function setting: `search_path=""`.
- Existing ACL explicitly includes PUBLIC, anon, authenticated and service_role.
- Candidate migration version `20261126230000` is not recorded in cloud migration history.

`CREATE OR REPLACE FUNCTION` with the same signature preserves the existing function identity/ACL; this proposed migration adds an audit event and does not harden those grants. Any ACL change needs separate review and approval.

## Runtime regression

Not executed: isolated AAL2 test session and disposable NH3/Raghunath fixture identifiers were not available. No live write was attempted.

Required tests: authorized submit; pending header/item; no stock mutation on submit; approve positive/negative variance; reject; invalid store/batch/negative quantity; cross-clinic denial; rollback on audit insert failure; verify ledgers, movements and audit events.

## Safety
- No migration applied and no cloud data changed.
- No production backup was initiated or asserted.
- PEHAL GREWAL untouched.
- Anaira POS Local Server Docker DB untouched.
- No paid Supabase branch created.

## Status
Source migration preparation: completed.
Static verification: completed, PASS.
Live catalog compatibility inspection: completed, read-only.
Authenticated runtime regression: pending / blocked on isolated test credentials and fixtures.
Production migration: pending explicit approval.
