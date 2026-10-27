-- Facility profile branding assets. Metadata stays in clinics.clinic_profile JSONB.
-- Apply after the existing Anaira Clinic migrations.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('clinic-assets', 'clinic-assets', true, 5242880, array['image/png','image/jpeg','image/webp','image/svg+xml'])
on conflict (id) do update set public = true, file_size_limit = 5242880, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists clinic_assets_public_read on storage.objects;
create policy clinic_assets_public_read on storage.objects
for select to public using (bucket_id = 'clinic-assets');

drop policy if exists clinic_assets_owner_admin_insert on storage.objects;
create policy clinic_assets_owner_admin_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'clinic-assets'
  and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and private.has_clinic_role(((storage.foldername(name))[1])::uuid, array['owner','admin'])
);

drop policy if exists clinic_assets_owner_admin_update on storage.objects;
create policy clinic_assets_owner_admin_update on storage.objects
for update to authenticated
using (
  bucket_id = 'clinic-assets'
  and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and private.has_clinic_role(((storage.foldername(name))[1])::uuid, array['owner','admin'])
)
with check (
  bucket_id = 'clinic-assets'
  and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and private.has_clinic_role(((storage.foldername(name))[1])::uuid, array['owner','admin'])
);

drop policy if exists clinic_assets_owner_admin_delete on storage.objects;
create policy clinic_assets_owner_admin_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'clinic-assets'
  and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and private.has_clinic_role(((storage.foldername(name))[1])::uuid, array['owner','admin'])
);
