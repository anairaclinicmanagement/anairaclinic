# Pharmacy invoice print & role access fix — v0.8.105

- Fixed pharmacy invoice printing query: `invoice_items` does not have a `created_at` column, so the previous `.order('created_at')` caused the print request to fail.
- Open the print window synchronously from the button click to avoid popup-blocker failures after asynchronous Supabase reads.
- Reuse the clinic-scoped patient directory already loaded for pharmacy instead of requiring a direct patient-table read for pharmacist role.
- Display the actual Supabase error in the pharmacy UI if invoice loading fails.
- Print uses the saved pharmacy store name, logo, address, phone, email, drug licence and GSTIN settings where available.
- No database schema or billing/payment calculations changed. The existing invoice/payment RPC remains shared by pharmacist and authorized admin roles.

Validation: ZIP integrity and package JSON validation performed. Full Next.js build/browser print test not run because `node_modules` is not installed in this environment.
