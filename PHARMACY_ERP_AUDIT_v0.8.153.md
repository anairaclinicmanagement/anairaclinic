# Anaira Pharmacy ERP — v0.8.153 implementation audit

## Existing, source-confirmed workflows
- Clinic-scoped medicine master and supplier directory.
- Batch stock receipt, batch expiry and rate storage, stock adjustment with audit movement.
- FEFO dispensing, prescription-linked and walk-in pharmacy billing, IPD pharmacy linkage.
- Central invoice payment collection, discount support, print, basic stock/sales exports.
- Single pharmacy workspace, KPI overview and modal Add Medicine / Receive Stock / New Bill.

## Added in v0.8.153 (database transaction layer)
- Purchase Order header and line tables with clinic-scoped numbering, supplier, item quantities, free quantities, rates and tax.
- Goods Receipt Note (GRN) header and line tables with supplier invoice metadata.
- `create_pharmacy_purchase_order`: validates supplier, medicine, quantities and tax; creates PO atomically.
- `receive_pharmacy_grn`: validates supplier/PO, batch/expiry and received quantities; updates batch stock, writes stock movement, updates PO status and supplier payable ledger in one transaction.
- Supplier ledger entries for posted purchases, supplier payments and purchase returns.
- `record_pharmacy_supplier_payment`: owner/admin/accountant-only supplier payment posting, audited.
- `create_pharmacy_purchase_return`: batch-locked quantity validation, stock deduction, stock movement, supplier credit ledger and audit log.
- RLS policies and clinic role checks for all new tables and RPCs.

## Not yet delivered; do not treat as working until a subsequent release adds UI and tests
- Procurement UI screens for PO/GRN, supplier statement/ageing and payment voucher.
- Sales return against original pharmacy invoice with exact batch linkage/refund/credit note.
- Purchase return UI and supplier credit settlement workflow.
- Multi-branch/sub-store transfer and ward/OT/ICU indents.
- Physical stock count sessions with maker-checker approval, quarantine/recall and write-off approval.
- Barcode/GTIN scanner workflow, keyboard-first POS, loose-unit conversion and shift/cash-drawer closing.
- Schedule H/H1/X registers and controlled-drug workflows; these must be configured and reviewed against current applicable law by a qualified compliance owner.
- Reorder suggestions, dead/slow stock, actual batch COGS/profit, GST registers and cashier Z reports.
- Offline-safe transaction queue and multi-counter conflict resolution.

## Release safety
- The migration is additive; it does not rewrite existing invoices, payments, prescriptions or stock history.
- SQL functions are transactional and clinic-scoped. GRN invoice total mismatch is rejected to prevent silent payable/stock mismatch.
- Apply migration to staging first. Run SQL/RLS tests and authenticated end-to-end tests before production.
- Static source verification and ZIP integrity do not establish SQL execution, TypeScript compilation, production build or live tenant-isolation correctness.
