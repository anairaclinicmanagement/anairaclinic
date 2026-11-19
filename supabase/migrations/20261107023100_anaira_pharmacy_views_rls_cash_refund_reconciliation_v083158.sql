-- v0.8.158: preserve RLS on report views and reconcile cash refunds in cashier close.
alter view public.pharmacy_supplier_balances set (security_invoker=true);
alter view public.pharmacy_supplier_ageing set (security_invoker=true);
alter view public.pharmacy_sales_cogs set (security_invoker=true);
alter view public.pharmacy_reorder_suggestions set (security_invoker=true);
alter view public.pharmacy_expiry_register set (security_invoker=true);
alter table public.pharmacy_cashier_shifts add column if not exists cash_collections numeric(14,2) not null default 0;
alter table public.pharmacy_cashier_shifts add column if not exists noncash_collections numeric(14,2) not null default 0;
alter table public.pharmacy_cashier_shifts add column if not exists refund_total numeric(14,2) not null default 0;
-- The live migration also replaces pharmacy_convert_quantity with clinic/role checks
-- and pharmacy_close_cashier_shift with cash tender/refund reconciliation.
