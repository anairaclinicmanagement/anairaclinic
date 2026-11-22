# Anaira Healthcare v0.8.133 — Assets, Maintenance & Procurement

## Delivered
- Replaced the generic Assets & Maintenance workflow wrapper with dedicated asset register, maintenance work-order and service-history screens.
- Added tenant-scoped asset create, maintenance work-order create/status updates, service log entry and next-service date update.
- Replaced generic Procurement wrapper with supplier master, purchase requisitions, purchase orders with item line/GST calculation, and goods receipt registers.
- Added a database migration for additional asset/work-order fields and tenant-scoped supplier, requisition, service-log and goods-receipt tables with RLS policies.

## Database
- Target: Anaira Clinic Supabase project `gdyvzvzmybbvufggxjty`.
- Migration: `20261030180000_assets_maintenance_procurement_workflows.sql`.
- Existing clinic_assets, maintenance_work_orders, purchase_orders and purchase_order_items reused; no existing rows were deleted.

## Scope notes
- Purchase order form currently creates one line item per PO submission; line-item editing/multiple-line UI is a follow-up.
- GRN captures receipt metadata/status; stock ledger deduction/increment and automatic asset creation are not yet wired.
- Requisition items currently capture summary/purpose and estimate, not a structured item list.
- Vendor invoice settlement/AP ledger and AMC contracts are not included in this release.
