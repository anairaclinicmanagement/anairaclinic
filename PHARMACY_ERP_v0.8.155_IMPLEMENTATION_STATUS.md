# Anaira Pharmacy ERP v0.8.155

## Implemented in this source update
- Existing v0.8.154 PO creation and supplier payment voucher UI retained.
- Added GRN posting UI: supplier invoice number/date, medicine, batch, expiry, received/free quantities, purchase/sale rates and GST; calls `receive_pharmacy_grn` and refreshes inventory.
- Added batch-wise purchase return UI with quantity/rate/reason; calls `create_pharmacy_purchase_return` and refreshes inventory.
- Added GRN register listing and live procurement refresh.
- Connected workflows use the clinic-scoped Supabase RPCs already deployed in project `gdyvzvzmybbvufggxjty`.

## Not yet complete
Sales return/refund approval, barcode scan UX, pack/unit conversion, store/ward/OT transfer workflow, stock audit approval/quarantine, validated Schedule H/H1/X register, actual COGS accounting, cashier shift/Z-report are not represented as complete. No legal compliance certification is claimed.

## Verification
Source-level changes only. Run the project's install and `npm run build` in the target environment before production deployment. Test GRN and purchase return with a non-production clinic before live stock operations.
