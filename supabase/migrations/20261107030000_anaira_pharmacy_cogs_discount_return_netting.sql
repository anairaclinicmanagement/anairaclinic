create or replace view public.pharmacy_sales_cogs as
select a.clinic_id,a.invoice_id,i.invoice_no,a.invoice_item_id,a.medication_id,m.name as medicine_name,
 sum(greatest(a.dispensed_quantity-coalesce(ret.returned_qty,0),0))::numeric(14,3) as sold_quantity,
 sum(greatest(a.dispensed_quantity-coalesce(ret.returned_qty,0),0)*b.purchase_rate)::numeric(14,2) as cogs,
 sum(greatest(a.dispensed_quantity*ii.unit_price-
   case when coalesce(ii.quantity,0)>0 then coalesce(ii.discount_amount,0)*a.dispensed_quantity/ii.quantity else 0 end-
   coalesce(ret.refunded_value,0),0))::numeric(14,2) as gross_sales,
 (sum(greatest(a.dispensed_quantity*ii.unit_price-
   case when coalesce(ii.quantity,0)>0 then coalesce(ii.discount_amount,0)*a.dispensed_quantity/ii.quantity else 0 end-
   coalesce(ret.refunded_value,0),0))-
  sum(greatest(a.dispensed_quantity-coalesce(ret.returned_qty,0),0)*b.purchase_rate))::numeric(14,2) as gross_margin,
 min(a.created_at) as dispensed_at
from public.pharmacy_dispense_allocations a
join public.inventory_batches b on b.id=a.batch_id and b.clinic_id=a.clinic_id
join public.invoices i on i.id=a.invoice_id and i.clinic_id=a.clinic_id
join public.invoice_items ii on ii.id=a.invoice_item_id and ii.clinic_id=a.clinic_id
join public.medications m on m.id=a.medication_id and m.clinic_id=a.clinic_id
left join lateral (
 select coalesce(sum(r.quantity),0) returned_qty,coalesce(sum(r.refund_amount),0) refunded_value
 from public.pharmacy_sales_returns r where r.allocation_id=a.id and r.clinic_id=a.clinic_id and r.status in ('approved','refunded')
) ret on true
group by a.clinic_id,a.invoice_id,i.invoice_no,a.invoice_item_id,a.medication_id,m.name;
alter view public.pharmacy_sales_cogs set (security_invoker=true);
