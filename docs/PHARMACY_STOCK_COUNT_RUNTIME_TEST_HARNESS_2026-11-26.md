# Pharmacy Stock Count Runtime Test Harness

Added `scripts/tests/pharmacy-stock-count-submit.rollback.sql`.

## What it actually tests
Runs the stock-count submission RPC inside a transaction using a disposable clinic's existing authorized AAL2 test user and a pre-existing store/batch fixture. It asserts:
- exactly one matching store-stock row exists;
- RPC returns a count ID;
- count header status is `pending`;
- count item has expected physical quantity;
- exactly one `pharmacy_store_stock_count_submitted` audit event exists for that count and actor;
- store stock balance remains unchanged during submission.

The script ends with `ROLLBACK`, so its temporary count header, item and audit event are undone.

## Required psql variables
`clinic_id`, `store_id`, `batch_id`, `test_user_id`.

Example (test database only):
```powershell
psql "$env:TEST_DATABASE_URL" -v ON_ERROR_STOP=1 `
  -v clinic_id="<NH3-or-Raghunath-clinic-uuid>" `
  -v store_id="<test-store-uuid>" `
  -v batch_id="<test-batch-uuid>" `
  -v test_user_id="<authorized-test-user-uuid>" `
  -f scripts/tests/pharmacy-stock-count-submit.rollback.sql
```

The test user must already have an owner/admin/pharmacist role in that same clinic and MFA AAL2. Do not use PEHAL identifiers. Do not point the connection string to Anaira POS Local Server Docker DB.

Expected notice:
`PASS: pending count + item + one audit event; stock unchanged.`

This harness has been authored but not executed because disposable fixture IDs and an isolated test DB session were not available. It does not test approval/rejection or cross-clinic denial; those are separate pending harnesses.
