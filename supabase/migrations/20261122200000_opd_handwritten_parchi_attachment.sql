-- Store a doctor-written OPD parchi scan against the existing clinic-scoped visit.
alter table public.opd_visits
  add column if not exists handwritten_parchi_image_url text;

update storage.buckets
set file_size_limit = 10485760,
    allowed_mime_types = array['image/png','image/jpeg','image/webp','image/svg+xml','application/pdf']
where id = 'clinic-assets';

drop policy if exists clinic_assets_owner_admin_insert on storage.objects;
create policy clinic_assets_clinical_staff_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'clinic-assets'
  and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and private.has_clinic_role(((storage.foldername(name))[1])::uuid, array['owner','admin','doctor'])
);
