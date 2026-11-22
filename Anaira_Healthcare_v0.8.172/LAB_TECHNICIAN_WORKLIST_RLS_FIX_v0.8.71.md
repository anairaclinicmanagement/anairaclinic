# Anaira Healthcare v0.8.71 — Lab Technician Worklist RLS Fix

## Root cause found
The connected Supabase project contains 9 lab orders, including fully paid orders for NH3 Clinic. The `lab_orders_select_role` and `lab_order_items_select_role` policies determine paid status by joining `invoices`. The invoice SELECT policy does not grant lab technicians general invoice visibility, so that nested invoice check can hide otherwise-paid worklist rows. The `lab_orders_module_entitlement` and `lab_order_items_module_entitlement` restrictive policies also gate rows through `clinic_module_access`.

## Fix
Migration `20261028240000_lab_technician_paid_worklist_rls_fix.sql` adds a SECURITY DEFINER predicate that verifies the signed-in user is an active lab technician for the same active clinic, the order is in the laboratory department, the invoice is fully paid, and the clinic subscription includes laboratory. Explicit permissive SELECT policies then use that predicate for both orders and their items. No patient data or order data is rewritten.

## Verification status
- Live Supabase inspection: 9 orders in NH3 Clinic; fully paid invoice links confirmed; laboratory module is present in the clinic plan.
- A preceding restrictive-policy/function migration was accepted by Supabase. Applying the additional permissive SELECT policy directly through the connected migration tool was blocked, so this ZIP includes the complete follow-up migration for deployment through the project's normal migration process.
- Static project verification is run when packaging. Authenticated browser/E2E test as the actual lab technician has not been run from this environment.
