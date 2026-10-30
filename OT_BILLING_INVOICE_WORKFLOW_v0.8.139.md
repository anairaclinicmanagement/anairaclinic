# OT Billing & Payments Integration — v0.8.139

- When an OT case reaches Recovery or Completed, the existing `post_operation_theatre_charge_to_ipd` action now creates a normal IPD-linked invoice and invoice item.
- The invoice appears in the existing Billing & Payments invoice register.
- Existing Billing actions provide invoice printing and full/partial payment recording, with payment status and receipt history.
- The OT case stores `billing_invoice_id` to prevent duplicate invoices on repeat submissions.
- Existing IPD charge-ledger insertion is intentionally not repeated by this invoice flow to avoid double-counting the same OT charge in the IPD final bill.

Migration: `supabase/migrations/20261030223000_ot_invoice_billing_payments_print.sql`

Supabase migration was applied to the connected project. Browser E2E and production build still need to be run in the user's environment.
