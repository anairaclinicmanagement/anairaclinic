# Anaira Healthcare Pharmacy ERP — Full Capability Audit (v0.8.157)

## Changes in this pass
- Added Sales Returns workspace: original invoice selection, invoice medicine line, exact batch-allocation selection, return request, owner/admin approval queue.
- Added Unit Conversion master CRUD (medicine + from unit + to unit + factor). It is a master only; conversion is not yet used to calculate dispensing stock.
- Added Schedule H/H1/X operational register entry and listing with patient, prescriber and prescription reference fields. This is not a legal compliance certification.
- Added batch condition controls in the inventory register: saleable, quarantined, damaged, recalled and expired.
- GRN form can now be linked to an open/part-received PO and capture supplier invoice total for reconciliation; backend already supports partial PO receipt.
- Critical dispensing correction: the atomic pharmacy dispense RPC now records exact batch allocation rows against invoice items and only dispenses from unexpired, saleable batches. Discounted and IPD pharmacy sale flows call this base RPC, so new sales gain batch traceability.
- Cashier close calculation corrected to use cash tender only for cash-drawer expected balance and report non-cash tender separately.

## Existing capabilities confirmed in source/database
- Clinic-scoped medicine catalogue with SKU, barcode/GTIN, generic name, strength, dosage form, manufacturer, HSN, GST, unit, reorder threshold and product category.
- Batch stock receipt and FEFO dispensing, expiry/low-stock watch, batch adjustment, and CSV inventory/sales exports.
- Patient and walk-in pharmacy billing, optional prescription and IPD admission linkage, discount handling, central invoice payment integration and invoice print.
- Supplier directory, purchase order creation, GRN posting, supplier ledger entries, supplier payment voucher and batch-wise purchase return.
- Pharmacy store master, sub-store transfer RPC/UI, physical count approval workflow, cashier shift open/close.

## Remaining gaps — not complete / not certified
1. **PO governance:** no maker-checker approval/rejection lifecycle; PO UI currently creates one medicine line per PO.
2. **Supplier accounts:** no complete supplier running balance/ageing buckets, payment allocation to invoices, credit-note settlement or accountant-grade reconciliation.
3. **Sales refund accounting:** approval restores batch stock but does not automatically issue/reconcile cash, UPI or card refund in central billing. Refund must be settled separately.
4. **Historic sales returns:** invoices created before exact batch allocations are captured cannot be returned through the new exact-batch flow; the RPC correctly rejects untraceable invoice lines.
5. **Unit conversion:** conversion master can be configured but strip/tablet, bottle/ml, vial/dose, pack/piece conversion is not wired into dispensing, purchase, stock valuation or prescription quantity checks.
6. **Multi-store:** store and transfer ledger exists, but opening stock allocation, store-specific dispensing/ward indents/OT issue-consumption and branch-level reconciliation are not fully connected to the main `inventory_batches` balance. Do not use as authoritative multi-store stock yet.
7. **Drug compliance:** Schedule H/H1/X register capture is basic. Drug classification master, prescription evidence validation, controlled-substance maker-checker, statutory retention/export and legal review are outstanding. No compliance claim is made.
8. **COGS / profitability:** current stock valuation uses batch purchase rates, but actual invoice-line COGS, weighted/landed cost, margin after discounts/tax, expiry/damage loss and returns-adjusted profit are not complete.
9. **Cashier Z report:** cash-only expected cash is improved, but split tender summary, refunds, cash-in/out, opening/closing denomination count, cashier supervisor sign-off and day-end settlement are outstanding.
10. **Recall/quarantine:** batch condition can be changed, but recall notices, affected patient tracing, supplier notification, quarantine release approval and disposal/write-off accounting are not complete.
11. **Replenishment:** reorder level alert exists; demand forecasting, supplier lead time, min/max, auto-PO suggestions and purchase planning are not complete.
12. **Clinical safety:** no governed drug-interaction/allergy database, substitution approval, partial dispensing/refill workflow or medication reconciliation automation.
13. **Tax/accounting:** GST is captured at item level, but CGST/SGST vs IGST determination, credit/debit notes, statutory registers and audited GST exports need accountant validation.
14. **Operational testing:** no production-grade automated E2E suite for purchase-to-stock-to-sale-to-return, concurrency, negative stock, tenant isolation, cashier reconciliation or failure recovery.
15. **Build certification:** static project check and TSX syntax transpilation pass. Full `tsc --noEmit`, Next production build and browser E2E remain unverified because local dependency/type packages are incomplete in this runtime.

## Database deployment notes
- Target Supabase project: `gdyvzvzmybbvufggxjty` (Anaira Clinic connection).
- Confirmed migrations include procurement/supplier ledger v0.8.154, inventory controls v0.8.156, cashier schema fix, sales-return traceability v0.8.157 and cash-only cashier reconciliation v0.8.157, plus the batch-allocation/quarantine guard added in this pass.
- Table existence and migration history were checked after deployment. No destructive data migration or live stock transfer/count was run.

## Production gate
Before enabling in a live clinic, run a test clinic through: receive GRN → partial PO receipt → FEFO sale → batch return request → approval/restock → separately settled refund → stock count approval → cash shift close. Verify exact stock, invoice, payment, supplier ledger and audit log deltas. Also test unauthorized cross-clinic reads/writes.
