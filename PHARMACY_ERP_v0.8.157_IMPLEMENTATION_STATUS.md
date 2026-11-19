# Anaira Pharmacy ERP v0.8.157 — Implementation Status

## Implemented in this update
- Sales return request and Owner/Admin approval UI using original invoice, invoice item and exact dispensed batch allocation.
- Exact batch allocation capture added to atomic dispensing; saleable/unexpired stock only. Discounted and IPD sales use this base RPC.
- Batch condition actions: saleable, quarantined, damaged, recalled and expired.
- GRN can be linked to open/part-received PO and accepts supplier invoice total for reconciliation.
- Unit conversion master CRUD and Schedule H/H1/X operational register entry/listing.
- Cashier close calculation now separates cash from non-cash tender for cash drawer expected balance.
- Full gap audit is in `PHARMACY_ERP_v0.8.157_FULL_AUDIT.md`.

## Verified
- Connected Supabase project `gdyvzvzmybbvufggxjty`: relevant migration history and table presence checked.
- Dispensing RPC inspected after deployment: confirmed it writes `pharmacy_dispense_allocations` and filters non-saleable batches.
- `node scripts/verify-project.mjs`: PASS (36 routes; 78 source migrations).
- TypeScript TSX syntax transpilation for `app/pharmacy/page.tsx`: 0 syntax diagnostics.
- ZIP integrity checked after packaging.

## Not verified / still incomplete
- `npm run build` cannot run here: `next: not found` in local dependency installation.
- Full `tsc --noEmit`, browser E2E and live transaction tests not completed.
- Sales return approval restores stock but does not execute cash/UPI/card refund; settle refund separately in central billing.
- Unit conversion master is not wired into stock/dispensing quantities.
- Multi-store balances are not yet the authoritative source for ward/OT/branch dispensing; central inventory and store ledger need a unified issue/consume model.
- PO maker-checker approval, multi-line PO editor, supplier ageing/running balance, COGS/profit, full Z report/refund settlement, and statutory drug-register validation remain incomplete.
- No legal compliance certification is claimed for Schedule H/H1/X.
