# Anaira Healthcare v0.8.70 — Clinic Selection Fallback Fix

## Root cause addressed
Ambulance and Billing only fell back to another clinic membership when the account had exactly one active membership. If the saved localStorage clinic ID was stale or belonged to a clinic the current user no longer belonged to, both pages refused to select a valid clinic.

## Change
Both `components/ClinicalOperations.tsx` and `app/billing/page.tsx` now prefer the saved clinic when it matches an active membership; otherwise they select the first active membership and persist that clinic ID. Queries remain scoped to the resolved clinic. No cross-clinic data merge and no database rows changed.

## Important
This is a source-level fix based on code and database inspection. A real authenticated browser/E2E run is still needed to confirm the current session and RLS behavior.
