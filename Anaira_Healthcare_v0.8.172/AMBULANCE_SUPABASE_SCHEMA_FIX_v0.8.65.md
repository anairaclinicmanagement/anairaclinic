# Anaira Healthcare v0.8.65 — Ambulance Supabase schema compatibility fix

Fixes runtime errors reported on `/ambulance` and `/billing`:
- `column ambulance_trips.pickup_address does not exist`
- older databases may use `pickup_location`, `dropoff_location`, `dispatched_at`, `arrived_at`, and `completed_at` instead of the current app's names.

## Apply migration
Apply `supabase/migrations/20261028220000_ambulance_address_schema_compat.sql` to the existing Supabase project using the Supabase SQL Editor or the project's normal migration workflow. It is additive/idempotent and backfills the current address/time columns from legacy columns. Do not reset the database.

After applying, reload `/ambulance` and `/billing`. This package fixes the schema mismatch; a live Supabase connection was not available for remote execution from this environment.
