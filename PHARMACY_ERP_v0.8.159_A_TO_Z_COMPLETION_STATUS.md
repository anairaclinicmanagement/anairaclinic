# Anaira Healthcare Pharmacy ERP v0.8.159 — A-to-Z completion pass

## Implemented in this pass
- Multi-line Purchase Order UI (medicine, ordered quantity, free scheme, purchase rate and GST per line); submits through the existing atomic PO RPC and approval workflow.
- Unit selection in pharmacy billing; selected quantity and price are converted to the medicine's configured stock unit before calling atomic dispensing. Missing conversion rules stop billing instead of silently mis-scaling stock.
- Conversion failures are now inside the billing error handler so the user receives an actionable message.
- COGS view now nets approved/refunded return quantities, allocated invoice-line discount, and recorded refund amount from the batch-level margin calculation.
- Version/package metadata advanced to 0.8.159.

## Database work applied and checked
- Migration `anaira_pharmacy_cogs_discount_return_netting_v083159` applied to Supabase project `gdyvzvzmybbvufggxjty`.
- `pharmacy_sales_cogs` view remains `security_invoker=true`.
- Prior v0.8.158 migrations/views and the purchase approval, sales return/refund, stock and conversion RPCs remain in place.

## Still not safe to mark complete
- Multi-store is not yet the single authoritative inventory source for all sales, ward, OT, IPD and branch dispensing. Current central batch stock and store stock ledger are separate concepts; do not use store transfers for live operations until the inventory issue/consume path is unified.
- Supplier running-balance allocation/payment reconciliation against individual invoices/GRNs is not a full AP subledger yet.
- Cashier shift integration is not yet guaranteed for every central billing payment/refund channel or all historical transactions.
- Drug register requirements and Schedule H/H1/X retention/compliance must be validated by the responsible licensed pharmacist and local rules; no legal compliance certification is claimed.
- Wastage, breakage, recall disposal and expired-stock write-off need a dedicated approval/accounting workflow before their impact can be included in financial COGS.
- No live business transactions were run to avoid mutating clinic data.

## Verification
- Static project verifier: PASS (36 routes, 81 SQL migration files; required-file/static migration checks passed).
- Pharmacy TSX syntax transpilation: PASS (0 syntax diagnostics).
- Full `tsc --noEmit`, production Next.js build and browser E2E: not verified; `node_modules/.bin/next` is missing in this runtime.
- Supabase: v0.8.159 COGS/discount/return migration appears in migration history; `pharmacy_sales_cogs` verified with `security_invoker=true`.
- ZIP integrity: checked after packaging.
