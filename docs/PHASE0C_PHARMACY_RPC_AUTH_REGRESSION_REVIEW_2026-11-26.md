# Phase 0C — Pharmacy RPC Authorization Regression Review
Date: 2026-11-26
Project: Anaira Clinic Cloud (`gdyvzvzmybbvufggxjty`)
Mode: Read-only catalog and function-definition review. No writes or ACL changes.

## Critical ACL observation
All eight anon-executable non-trigger pharmacy RPCs have explicit ACL entries granting EXECUTE to `PUBLIC`, `anon`, `authenticated`, and `service_role`. Therefore the `anon` privilege is not merely an inherited assumption. The functions contain internal authentication/MFA and clinic-role checks, but exposed execute permission is still broader than necessary. The prepared Phase 0C migration's revoke from `PUBLIC` and `anon`, while retaining `authenticated`, is directionally appropriate. Do not apply it until the test/approval gate is met.

## RPC review matrix
| RPC | AAL2 text | Auth UID text | Role helper | Clinic-scope indicator | Audit log text | Read-only disposition |
|---|---:|---:|---:|---:|---:|---|
| create_pharmacy_purchase_return_from_store | Yes | Yes | Yes | Yes | No | Inspect audit trail and item/GRN/store invariants in workflow test |
| dispense_pharmacy_sale_discounted_from_store | Yes | Yes | Yes | Yes | Yes | Validate discount bounds, stock locking and payment state |
| dispense_pharmacy_sale_for_admission_from_store | Yes | No | Yes | Yes | No | Wrapper delegates to discounted dispense RPC; role helper supplies auth context. Verify invoice admission link and audit inheritance |
| dispense_pharmacy_sale_from_store | Yes | Yes | Yes | Yes | Yes | Validate batch allocation, negative-stock prevention and payment reconciliation |
| pharmacy_approve_store_stock_count | Yes | Yes | Yes | Yes | Yes | Owner/admin only; locks pending count row; verify zero/negative edge cases and ledger reconciliation |
| pharmacy_decide_sales_return_to_store | Yes | Yes | No | Yes | No | Delegates to `pharmacy_decide_sales_return`, which checks AAL2, non-null user and owner/admin role; verify double-stock-credit prevention |
| pharmacy_submit_store_stock_count | Yes | Yes | Yes | Yes | No | Owner/admin/pharmacist; validates active store and stocked batch; verify duplicate pending counts |
| receive_pharmacy_grn_to_store | Yes | Yes | Yes | Yes | Yes | Verify PO/supplier/store matching, duplicate invoice handling, batch quantity and ledger parity |

Static indicators are not proof of correctness. `has_auth_context_text` is intentionally not used as the only authorization test: `dispense_pharmacy_sale_for_admission_from_store` delegates to a guarded RPC, and `pharmacy_decide_sales_return_to_store` delegates to a guarded decision RPC.

## Regression scenarios required before production ACL change
Run only on NH3 demo tenant or a separately approved non-production database. Do not write test records to PEHAL GREWAL.
1. Unauthenticated/anon call to each of the eight RPCs must fail after ACL hardening.
2. Authenticated user without clinic membership must fail.
3. Authenticated user belonging to a different clinic must fail when passing NH3 clinic_id.
4. Authenticated user without AAL2 must fail.
5. Wrong clinic/store/batch/patient/admission/GRN identifiers must fail without cross-tenant reads or writes.
6. Role matrix: owner/admin/pharmacist as intended; receptionist/accountant/doctor/nurse and unrelated roles must be denied where not authorized.
7. Pharmacy dispense: insufficient stock, concurrent dispense, invalid prescription, inactive store, invalid discount, and payment failure must not create partial sale or negative stock.
8. Purchase return/GRN: invalid supplier, mismatched GRN/PO, duplicate supplier invoice, invalid item quantity and wrong store must fail atomically.
9. Stock count: duplicate pending count, approval by pharmacist, approval by non-admin, rejected count, and physical quantity lower than zero must behave correctly.
10. Sales return: repeated approval must not credit stock twice; rejected return must not change stock; store and central inventory ledger must reconcile.
11. Confirm audit logs are written for every stock/billing mutation, either in wrapper or delegated function.
12. Re-run all six trigger workflows after trigger ACL hardening (payment shift, refund shift, batch sync, bed double-allocation, room-allocation release, admission-package scope validation).

## Findings / next decisions
- The eight RPCs are currently EXECUTE-granted to PUBLIC and anon in their explicit ACL.
- Internal MFA and clinic-role guards exist in static inspection, but they do not justify leaving anon EXECUTE enabled.
- Two wrappers intentionally lack a direct role-helper call but delegate to functions that enforce authorization.
- `create_pharmacy_purchase_return_from_store` has no direct `audit_logs` text in its definition; verify whether its transaction writes an audit event through another mechanism before sign-off.
- `pharmacy_submit_store_stock_count` similarly has no direct audit-log text; approval does write an audit event.
- Do not blanket revoke authenticated from trigger functions without checking each trigger binding and testing execution.
- Prepared migration `20261126210000_phase0c_security_definer_acl_hardening.sql` remains NOT APPLIED.
