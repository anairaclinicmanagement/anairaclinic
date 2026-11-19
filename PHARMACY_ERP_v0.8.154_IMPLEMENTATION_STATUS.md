# Anaira Pharmacy ERP v0.8.154

## Included in this release
- Connected Supabase migration `20261106202407_anaira_pharmacy_erp_procurement_supplier_ledger_returns_v083154`.
- Clinic-scoped PO, PO item, GRN, GRN item, supplier ledger, purchase return and return item tables.
- RPC workflows for PO creation, GRN receipt (including partial receipt and batch stock movement), supplier payment voucher and purchase return.
- Pharmacy workspace Procurement & Ledger tab: create PO, post supplier payment voucher, view PO register and supplier ledger.
- Package version bumped from 0.8.153 to 0.8.154.

## Not represented as complete
Sales return/refund, barcode scanner POS, pack/unit conversion, multi-store/ward/OT transfers, stock count approval/quarantine, statutory drug register validation, COGS/profit accounting and cashier shift/Z-report remain outstanding implementation work. Existing pharmacy billing remains the v0.8.153 workflow. Schedule H/H1/X functionality is not a legal compliance certification.

## Database verification
Applied to Supabase project `gdyvzvzmybbvufggxjty` using the Anaira clinic connection. `list_migrations` returned version `20261106202407` and the schema verification query returned all seven procurement tables.
