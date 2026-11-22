-- Anaira Clinic role workspaces, diagnostic catalogue categories and high-concurrency query indexes.
alter table public.lab_tests add column if not exists category text not null default 'Laboratory';
create index if not exists lab_tests_clinic_category_name_idx on public.lab_tests(clinic_id, category, lower(name)) where active=true;
create index if not exists clinic_members_user_active_idx on public.clinic_members(user_id, active, clinic_id);
create index if not exists staff_profiles_clinic_role_active_idx on public.staff_profiles(clinic_id, role, active);
create index if not exists patients_clinic_created_id_idx on public.patients(clinic_id, created_at desc, id) where archived_at is null;
create index if not exists appointments_clinic_status_time_idx on public.appointments(clinic_id, status, appointment_at desc);
create index if not exists invoices_clinic_created_idx on public.invoices(clinic_id, created_at desc, id);
create index if not exists payments_clinic_paid_at_idx on public.payments(clinic_id, paid_at desc);
create index if not exists lab_orders_clinic_status_time_idx on public.lab_orders(clinic_id, status, ordered_at desc);
create index if not exists lab_order_items_clinic_order_status_idx on public.lab_order_items(clinic_id, lab_order_id, status);
create index if not exists inventory_batches_clinic_med_expiry_idx on public.inventory_batches(clinic_id, medication_id, expiry_date, received_at) where quantity_on_hand>0;
create index if not exists opd_visits_clinic_status_issued_idx on public.opd_visits(clinic_id, status, issued_at desc);

-- Staff role allowlists remain tenant-scoped. Imaging roles can maintain diagnostic catalog/worklists.
drop policy if exists lab_tests_insert_role on public.lab_tests;
drop policy if exists lab_tests_update_role on public.lab_tests;
drop policy if exists lab_tests_select_role on public.lab_tests;
create policy lab_tests_select_role on public.lab_tests for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician']));
create policy lab_tests_insert_role on public.lab_tests for insert to authenticated with check (private.has_clinic_role(clinic_id,array['owner','admin','doctor','lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician']));
create policy lab_tests_update_role on public.lab_tests for update to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician'])) with check (private.has_clinic_role(clinic_id,array['owner','admin','doctor','lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician']));

-- General patient billing is operated by reception. Pharmacists use the dedicated
-- SECURITY DEFINER dispensing RPC for pharmacy invoices/stock so they do not gain
-- general reception billing write access.
drop policy if exists invoices_insert_role on public.invoices;
drop policy if exists invoices_update_role on public.invoices;
drop policy if exists invoice_items_insert_role on public.invoice_items;
drop policy if exists invoice_items_update_role on public.invoice_items;
drop policy if exists payments_insert_role on public.payments;
drop policy if exists payments_update_role on public.payments;
create policy invoices_insert_role on public.invoices for insert to authenticated with check (private.has_clinic_role(clinic_id,array['owner','admin','receptionist']));
create policy invoices_update_role on public.invoices for update to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','receptionist'])) with check (private.has_clinic_role(clinic_id,array['owner','admin','receptionist']));
create policy invoice_items_insert_role on public.invoice_items for insert to authenticated with check (private.has_clinic_role(clinic_id,array['owner','admin','receptionist']));
create policy invoice_items_update_role on public.invoice_items for update to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','receptionist'])) with check (private.has_clinic_role(clinic_id,array['owner','admin','receptionist']));
create policy payments_insert_role on public.payments for insert to authenticated with check (private.has_clinic_role(clinic_id,array['owner','admin','receptionist']));
create policy payments_update_role on public.payments for update to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','receptionist'])) with check (private.has_clinic_role(clinic_id,array['owner','admin','receptionist']));

-- Hide general reception invoices from pharmacy-only accounts; pharmacists see only pharmacy sale lines and payments.
drop policy if exists invoices_select_role on public.invoices;
drop policy if exists invoice_items_select_role on public.invoice_items;
drop policy if exists payments_select_role on public.payments;
create policy invoices_select_role on public.invoices for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','receptionist']) or (private.has_clinic_role(clinic_id,array['pharmacist']) and exists(select 1 from public.invoice_items ii where ii.clinic_id=invoices.clinic_id and ii.invoice_id=invoices.id and ii.item_type='pharmacy')));
create policy invoice_items_select_role on public.invoice_items for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','receptionist']) or (private.has_clinic_role(clinic_id,array['pharmacist']) and item_type='pharmacy'));
create policy payments_select_role on public.payments for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','receptionist']) or (private.has_clinic_role(clinic_id,array['pharmacist']) and exists(select 1 from public.invoice_items ii where ii.clinic_id=payments.clinic_id and ii.invoice_id=payments.invoice_id and ii.item_type='pharmacy')));

-- Add imaging roles to the diagnostic worklist's clinic-scoped read/write policies.
drop policy if exists lab_orders_select_role on public.lab_orders;
drop policy if exists lab_order_items_select_role on public.lab_order_items;
drop policy if exists lab_orders_insert_role on public.lab_orders;
drop policy if exists lab_orders_update_role on public.lab_orders;
drop policy if exists lab_order_items_insert_role on public.lab_order_items;
drop policy if exists lab_order_items_update_role on public.lab_order_items;
create policy lab_orders_select_role on public.lab_orders for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician']));
create policy lab_order_items_select_role on public.lab_order_items for select to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician']));
create policy lab_orders_insert_role on public.lab_orders for insert to authenticated with check (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician']));
create policy lab_orders_update_role on public.lab_orders for update to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician'])) with check (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician']));
create policy lab_order_items_insert_role on public.lab_order_items for insert to authenticated with check (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician']));
create policy lab_order_items_update_role on public.lab_order_items for update to authenticated using (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician'])) with check (private.has_clinic_role(clinic_id,array['owner','admin','doctor','receptionist','lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician']));
