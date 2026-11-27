# Phase 0C — Live SECURITY DEFINER Review
Date: 2026-11-26
Project: Anaira Clinic Cloud (`gdyvzvzmybbvufggxjty`)
Scope: Read-only catalog inspection. No migration or data write performed.

## Live inventory snapshot
- `public`: 106 SECURITY DEFINER functions; 14 currently have EXECUTE available to `anon`; 105 to `authenticated`.
- `private`: 4 SECURITY DEFINER functions; 0 `anon`; 4 `authenticated`.
- All 110 inspected SECURITY DEFINER functions have pinned `search_path` configuration; one exception among the public functions is pinned to `public` rather than the empty search path: `validate_ipd_admission_package_scope()`.
- Five authenticated-executable functions without `auth.uid()` / `auth.jwt()` text are trigger functions, not RPC entrypoints. They operate on trigger `NEW`/`OLD` records. The six anon-executable trigger functions are: `pharmacy_assign_payment_shift`, `pharmacy_assign_refund_shift`, `pharmacy_sync_batch_quantity_to_main_store`, `prevent_ipd_bed_double_allocation`, `release_ipd_room_allocation_beds_on_admission_change`, `validate_ipd_admission_package_scope`.
- Eight anon-executable non-trigger RPCs are listed below. Static review found auth/MFA and clinic-role guards in their own definitions except `pharmacy_decide_sales_return_to_store`, which checks MFA then delegates to `pharmacy_decide_sales_return`; the delegate explicitly checks authenticated user and owner/admin clinic role before changing stock/return status.

## Eight anon-executable non-trigger RPCs
1. `create_pharmacy_purchase_return_from_store`
2. `dispense_pharmacy_sale_discounted_from_store`
3. `dispense_pharmacy_sale_for_admission_from_store`
4. `dispense_pharmacy_sale_from_store`
5. `pharmacy_approve_store_stock_count`
6. `pharmacy_decide_sales_return_to_store`
7. `pharmacy_submit_store_stock_count`
8. `receive_pharmacy_grn_to_store`

## Trigger-function note
PostgreSQL trigger functions are invoked through attached triggers, not ordinary RPC calls. Their EXECUTE ACLs should still be least-privilege hardened, but must not be treated as user-callable business RPCs. Before changing ACLs, verify each trigger attachment and ensure application workflows still execute correctly.

## Specific search_path finding
`public.validate_ipd_admission_package_scope()` is SECURITY DEFINER and currently has `search_path=public`. Its body uses schema-qualified references, but the prepared source migration proposes pinning its search_path to empty. Keep that change in the prepared migration; do not apply to production without the required approval and validation.

## Authorization review
- `pharmacy_approve_store_stock_count`: AAL2 + non-null user + `private.has_clinic_role(... owner,admin)`.
- `pharmacy_submit_store_stock_count`: AAL2 + non-null user + `private.has_clinic_role(... owner,admin,pharmacist)` + clinic-scoped store/batch checks.
- `pharmacy_decide_sales_return_to_store`: AAL2; delegates to `pharmacy_decide_sales_return`, which independently checks AAL2 + non-null user + owner/admin clinic role.
- The remaining five RPCs were found to contain authentication/MFA and known clinic-role helper text in static inspection. Their complete business authorization logic still requires dedicated workflow regression testing.

## Disposition
- No broad revoke or ACL change was executed.
- The previously prepared ACL hardening migration remains NOT APPLIED.
- This is a static/catalog review, not a penetration test or proof that every authorization path is correct.
- PEHAL GREWAL data was not read or modified by this review; no test writes were performed.
- Anaira POS Local Server DB was not accessed.
