# Anaira Healthcare v0.8.173 — Pharmacy reference workflow

## UI changes
- Pharmacy workspace follows the supplied four-tab layout: Issue Medicine, Stock Management, Purchase, Reports.
- Stock Management includes medicine/category/manufacturer/status filters, batch/expiry table, stock summary and actions.
- Purchase screen supports supplier invoice header, multiple medicine/batch lines, expiry, quantity, purchase and sale rates, calculated GST-inclusive total, recent GRN history and print.
- Existing Issue Medicine workflow and pharmacy invoice centre are retained.

## Supabase integration
- Purchase posts to the existing `receive_pharmacy_grn_to_store` RPC and reads from `pharmacy_goods_receipts` with linked `pharmacy_goods_receipt_items`. It uses the active MAIN-PHARMACY store selected by the database function, updates batch stock, store stock, inventory ledger, supplier ledger and audit logs.
- Dispensing uses the existing store-aware `dispense_pharmacy_sale_for_admission_from_store` RPC with the default main pharmacy store; IPD linkage remains optional.
- No duplicate purchase schema or migration was added. This release reuses the existing production procurement schema.

## Verification
- TypeScript TSX transpile syntax check for `app/pharmacy/page.tsx`: PASS (zero syntax diagnostics).
- Static project verification: PASS (36 routes; 72 local migrations; required project files).
- Connected Supabase project `Anaira Clinic` (`gdyvzvzmybbvufggxjty`) was confirmed `ACTIVE_HEALTHY`.
- Remote schema inspection confirmed RLS-enabled `medications`, `inventory_batches`, `pharmacy_suppliers`, `pharmacy_purchase_orders`, `pharmacy_goods_receipts`, `pharmacy_goods_receipt_items`, `pharmacy_store_stock`, `pharmacy_inventory_ledger`, supplier ledger and returns/shift tables.
- Remote RPC inspection confirmed `receive_pharmacy_grn_to_store`, `create_pharmacy_purchase_order`, `pharmacy_approve_purchase_order`, `dispense_pharmacy_sale_discounted_from_store` and `dispense_pharmacy_sale_for_admission_from_store` are present.
- Remote migration history is ahead of the supplied ZIP: latest remote pharmacy migrations are dated 2026-11-06 (v0.8.160 family). The source ZIP did not contain those later local migration files; no database migration was applied by this change.
- `.env.local` is not included in the ZIP. Frontend runtime still requires the project's URL and publishable/anon key in `.env.local`.
- Full `npm run typecheck`, Next.js production build and authenticated browser E2E have not been run.
