# Anaira Healthcare v0.8.109 — IPD Diagnostic Bill RPC Argument Fix

## Root cause
The billing page sent `p_patient_id` to both OPD and IPD diagnostic RPC calls. The IPD RPC `create_ipd_reception_diagnostic_bill_discounted` accepts `p_admission_id` and derives the patient from the active admission; it does not accept `p_patient_id`. Supabase therefore could not resolve the IPD RPC by its named parameters. Both collect-now and credit-mode IPD bills failed before entering the database function.

## Fix
- OPD calls continue sending `p_patient_id`.
- IPD calls send `p_admission_id` and derive the patient server-side.
- Payment-now and pay-later use the same corrected RPC argument selection.
- No schema/data migration required; the existing IPD RPC is already present in the connected Supabase project.

## Verification
- Source-level assertion confirms OPD and IPD arguments are mutually exclusive and match RPC parameter names.
- ZIP integrity checked.
- Production build/browser end-to-end test not run because dependencies are not installed in this workspace.
