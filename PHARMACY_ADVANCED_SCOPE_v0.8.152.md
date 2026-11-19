# Anaira Pharmacy — Advanced Pharmacy Capability Audit (v0.8.152)

## Existing workflows confirmed in source
- Clinic-scoped medicine catalogue with generic name, strength, dosage form, manufacturer, SKU, HSN, unit, category, reorder level and item GST.
- Batch stock receipt with batch number, expiry, quantity, purchase rate, sale rate and supplier name.
- Stock batch visibility, low-stock and expiry alerts; expired batches excluded from dispensing.
- Pharmacy billing for clinic patients and walk-in customers; optional valid prescription and optional IPD admission linkage.
- Discount percentage/fixed amount and reason; FEFO stock deduction through the existing dispensing RPC.
- Invoice printing, payment recording through the central billing integration, supplier directory, sales/inventory CSV reports and clinic pharmacy settings.
- Admin/Owner settings and reports remain role-restricted; Pharmacist can perform daily pharmacy workflows.

## Advanced pharmacy capabilities to build next (not represented as implemented in this release)
1. Procurement: purchase requisitions, supplier quotations, purchase orders, GRN against PO, supplier tax invoice capture, invoice-rate variance and free-scheme quantities.
2. Supplier accounts: supplier ledger, payable ageing, payment vouchers, debit notes and purchase-return settlement.
3. Returns: patient sales return linked to original invoice and exact batch, refund/credit note, distributor saleable/expiry/damage return and supplier credit reconciliation.
4. Drug master: barcode/GTIN, salt/composition, brand alternatives, manufacturer catalogue, therapeutic class, drug schedule, storage condition, high-alert/look-alike-sound-alike flags and controlled-drug metadata.
5. Compliance: Schedule H/H1/X workflow and registers where applicable, prescriber/patient details and prescription evidence; narcotic/psychotropic registers only with validated legal workflow and permissions. Retention and access rules must be confirmed by compliance counsel.
6. Inventory control: rack/bin locations, multi-store and sub-store transfers, ward/OT/ICU indents, stock count, adjustment approval, quarantine/recall, damaged/expired write-off and complete immutable stock movement ledger.
7. Counter POS: barcode scanner, keyboard shortcuts, salt search, FEFO batch chooser, strip/tablet/loose-unit conversion, split tender, credit customer ledger, thermal receipt and cash drawer/shift closing.
8. Replenishment: min/max and reorder point, lead-time/sales-velocity suggestions, auto-draft PO, supplier-wise purchase recommendation and stockout forecast.
9. Clinical integration: OPD/IPD prescription queue, substitution approval, partial dispensing, refill history, medication reconciliation and allergy/interaction warnings sourced from a governed clinical drug database.
10. Analytics/accounts: gross margin using actual batch COGS, fast/slow/non-moving, dead stock, expiry exposure, purchase-vs-sales, GST registers/exports, daily Z report, cashier reconciliation and branch-wise reporting.
11. Enterprise controls: multi-branch stock, role/permission matrix, maker-checker approvals, audit trail, backup/export and offline-safe counter operation.

## Important implementation boundary
The current pharmacy source has a working baseline, but it is not yet a complete retail/hospital pharmacy ERP. Advanced modules above require schema design, audited RPC transactions, RLS/role tests and end-to-end verification. Do not expose a button or claim a capability until its complete transaction workflow is implemented and tested. GST rates and drug-schedule compliance must be configured against current official rules and reviewed by the responsible professional.

## v0.8.152 UI change
Add Medicine, Receive Stock and New Bill now open centred modal dialogs with internal scrolling, close/cancel controls and backdrop dismissal. Forms retain their existing Supabase save/receive/dispense handlers.
