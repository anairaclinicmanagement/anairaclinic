-- Clinic-scoped OT procedure catalogue, starter tariffs and full surgery booking.
create table if not exists public.ot_procedure_catalog (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics(id) on delete cascade,
 procedure_code text not null, procedure_name text not null, category text not null, description text,
 default_estimated_cost numeric(14,2) not null default 0 check(default_estimated_cost>=0),
 active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(clinic_id,procedure_code));
alter table public.ot_procedure_catalog enable row level security;
drop policy if exists ot_procedure_catalog_select on public.ot_procedure_catalog;
drop policy if exists ot_procedure_catalog_manage on public.ot_procedure_catalog;
create policy ot_procedure_catalog_select on public.ot_procedure_catalog for select to authenticated using(private.has_clinic_role(clinic_id,array['owner','admin','doctor','nurse','accountant','staff']));
create policy ot_procedure_catalog_manage on public.ot_procedure_catalog for all to authenticated using(private.has_clinic_role(clinic_id,array['owner','admin'])) with check(private.has_clinic_role(clinic_id,array['owner','admin']));
grant select,insert,update,delete on public.ot_procedure_catalog to authenticated;
alter table public.operation_theatre_cases
 add column if not exists procedure_catalog_id uuid references public.ot_procedure_catalog(id) on delete set null,
 add column if not exists procedure_code text, add column if not exists procedure_category text,
 add column if not exists clinical_indication text, add column if not exists booking_notes text,
 add column if not exists patient_history_reviewed boolean not null default false,
 add column if not exists pre_anaesthesia_assessment text, add column if not exists consent_type text,
 add column if not exists estimated_package_cost numeric(14,2) not null default 0;
create index if not exists ot_procedure_catalog_category_idx on public.ot_procedure_catalog(clinic_id,category,procedure_name);
create index if not exists ot_cases_catalog_idx on public.operation_theatre_cases(clinic_id,procedure_catalog_id);
insert into public.ot_procedure_catalog(clinic_id,procedure_code,procedure_name,category,description,default_estimated_cost)
select c.id,p.code,p.name,p.category,p.description,p.cost from public.clinics c cross join (values
('GS001','Appendectomy','General Surgery','Appendix removal',45000::numeric),('GS002','Open Inguinal Hernia Repair','General Surgery','Inguinal hernia repair',42000),('GS003','Laparoscopic Hernia Repair','General Surgery','Laparoscopic hernia repair',65000),('GS004','Laparoscopic Cholecystectomy','General Surgery','Gallbladder removal',70000),('GS005','Open Cholecystectomy','General Surgery','Open gallbladder removal',65000),('GS006','Haemorrhoidectomy','General Surgery','Haemorrhoid surgery',35000),('GS007','Fistula Surgery','General Surgery','Anal fistula procedure',40000),('GS008','Breast Lump Excision','General Surgery','Breast lump excision',30000),('GS009','Thyroidectomy','General Surgery','Thyroid surgery',85000),('GS010','Hydrocele Surgery','General Surgery','Hydrocelectomy',30000),('GS011','Varicose Vein Surgery','General Surgery','Vein surgery',55000),('GS012','Exploratory Laparotomy','General Surgery','Abdominal exploration',80000),('GS013','Debridement','General Surgery','Wound debridement',18000),('GS014','Incision & Drainage','General Surgery','Abscess drainage',12000),
('OG001','Caesarean Section (C-Section)','Obstetrics & Gynaecology','Lower segment caesarean section',55000),('OG002','Abdominal Hysterectomy','Obstetrics & Gynaecology','Uterus removal',75000),('OG003','Laparoscopic Hysterectomy','Obstetrics & Gynaecology','Laparoscopic uterus removal',110000),('OG004','Ovarian Cystectomy','Obstetrics & Gynaecology','Ovarian cyst removal',65000),('OG005','D&C','Obstetrics & Gynaecology','Dilatation and curettage',18000),('OG006','Tubal Ligation','Obstetrics & Gynaecology','Female sterilisation procedure',22000),('OG007','Ectopic Pregnancy Surgery','Obstetrics & Gynaecology','Ectopic pregnancy surgery',65000),
('OR001','Fracture Fixation (ORIF)','Orthopaedics','Open reduction internal fixation; implant may be extra',95000),('OR002','Closed Reduction & Casting','Orthopaedics','Fracture reduction and cast',18000),('OR003','Knee Arthroscopy','Orthopaedics','Knee arthroscopy',85000),('OR004','Total Knee Replacement','Orthopaedics','Knee arthroplasty; implant cost varies',250000),('OR005','Total Hip Replacement','Orthopaedics','Hip arthroplasty; implant cost varies',275000),('OR006','Implant Removal','Orthopaedics','Orthopaedic implant removal',35000),
('UR001','Ureteroscopy (URS)','Urology','Endoscopic ureteric stone procedure',75000),('UR002','PCNL','Urology','Percutaneous nephrolithotomy',110000),('UR003','TURP','Urology','Prostate resection',85000),('UR004','DJ Stent Insertion / Removal','Urology','Ureteric stent procedure',28000),('UR005','Circumcision','Urology','Circumcision',18000),
('EN001','Tonsillectomy','ENT','Tonsil removal',45000),('EN002','Adenoidectomy','ENT','Adenoid removal',40000),('EN003','Septoplasty','ENT','Nasal septum correction',55000),('EN004','FESS','ENT','Endoscopic sinus surgery',85000),('EN005','Myringoplasty','ENT','Eardrum repair',65000),
('OP001','Cataract Surgery','Ophthalmology','Cataract surgery; lens cost varies',35000),('OP002','Pterygium Excision','Ophthalmology','Pterygium removal',18000),('OP003','Trabeculectomy','Ophthalmology','Glaucoma surgery',55000),
('DE001','Surgical Tooth Extraction','Dental & Maxillofacial','Surgical tooth extraction',5000),('DE002','Impacted Wisdom Tooth Removal','Dental & Maxillofacial','Third molar surgery',12000),('DE003','Dental Implant Placement','Dental & Maxillofacial','Implant placement; prosthesis may be extra',35000),
('NS001','Craniotomy','Neurosurgery','Intracranial surgery; case-specific estimate',350000),('NS002','Spine Decompression','Neurosurgery','Spinal decompression',220000),('NS003','Discectomy','Neurosurgery','Intervertebral disc surgery',180000),
('CV001','Pacemaker Implantation','Cardiac Surgery','Device cost varies',250000),('CV002','CABG','Cardiac Surgery','Coronary artery bypass grafting',450000),('PL001','Skin Graft','Plastic & Reconstructive Surgery','Skin graft',65000),('PL002','Burn Contracture Release','Plastic & Reconstructive Surgery','Contracture release',85000)
) p(code,name,category,description,cost) on conflict(clinic_id,procedure_code) do nothing;
create or replace function public.create_operation_theatre_case_full(
 p_clinic_id uuid,p_patient_id uuid,p_admission_id uuid,p_procedure_catalog_id uuid,p_procedure_name text,p_procedure_code text,p_procedure_category text,p_clinical_indication text,
 p_surgeon_id uuid default null,p_anaesthetist_id uuid default null,p_scheduled_start timestamptz default null,p_scheduled_end timestamptz default null,p_estimated_cost numeric default 0,
 p_operating_room text default null,p_pre_op_diagnosis text default null,p_anaesthesia_type text default null,p_anaesthesia_notes text default null,p_booking_notes text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_case_id uuid:=gen_random_uuid(); v_invoice_id uuid; v_invoice_no text; v_patient uuid;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if not private.has_clinic_role(p_clinic_id,array['owner','admin','doctor','nurse']) then raise exception 'Operation Theatre permission required'; end if;
 if coalesce(length(trim(p_procedure_name)),0)<2 then raise exception 'Select or enter a valid procedure'; end if;
 if coalesce(length(trim(p_clinical_indication)),0)<3 then raise exception 'Clinical indication / reason for surgery is required'; end if;
 if p_estimated_cost is null or p_estimated_cost<0 or p_estimated_cost>100000000 then raise exception 'Enter a valid operation estimate'; end if;
 if p_scheduled_start is not null and p_scheduled_end is not null and p_scheduled_end<=p_scheduled_start then raise exception 'Scheduled end must be after scheduled start'; end if;
 select patient_id into v_patient from public.admissions where id=p_admission_id and clinic_id=p_clinic_id and status in ('admitted','transferred');
 if v_patient is null or v_patient<>p_patient_id then raise exception 'Select an active IPD admission for the same patient'; end if;
 if p_procedure_catalog_id is not null and not exists(select 1 from public.ot_procedure_catalog where id=p_procedure_catalog_id and clinic_id=p_clinic_id and active) then raise exception 'Procedure is not active in this clinic catalogue'; end if;
 if p_surgeon_id is not null and not exists(select 1 from public.staff_profiles where id=p_surgeon_id and clinic_id=p_clinic_id and active) then raise exception 'Surgeon must belong to this clinic'; end if;
 if p_anaesthetist_id is not null and not exists(select 1 from public.staff_profiles where id=p_anaesthetist_id and clinic_id=p_clinic_id and active) then raise exception 'Anaesthetist must belong to this clinic'; end if;
 insert into public.operation_theatre_cases(id,clinic_id,patient_id,admission_id,procedure_catalog_id,procedure_name,procedure_code,procedure_category,clinical_indication,surgeon_id,anaesthetist_id,scheduled_start,scheduled_end,estimated_cost,estimated_package_cost,operating_room,pre_op_diagnosis,anaesthesia_type,anaesthesia_notes,booking_notes,created_by)
 values(v_case_id,p_clinic_id,p_patient_id,p_admission_id,p_procedure_catalog_id,trim(p_procedure_name),nullif(trim(p_procedure_code),''),nullif(trim(p_procedure_category),''),trim(p_clinical_indication),p_surgeon_id,p_anaesthetist_id,p_scheduled_start,p_scheduled_end,p_estimated_cost,p_estimated_cost,nullif(trim(p_operating_room),''),nullif(trim(p_pre_op_diagnosis),''),nullif(trim(p_anaesthesia_type),''),nullif(trim(p_anaesthesia_notes),''),nullif(trim(p_booking_notes),''),v_user);
 if p_estimated_cost>0 then
  v_invoice_id:=gen_random_uuid(); v_invoice_no:='IPD-OT-'||to_char(now() at time zone 'Asia/Kolkata','YYYYMMDD')||'-'||upper(substr(replace(v_invoice_id::text,'-',''),1,8));
  insert into public.invoices(id,clinic_id,patient_id,admission_id,invoice_no,status,subtotal,total_amount,paid_amount,issued_at,created_by) values(v_invoice_id,p_clinic_id,p_patient_id,p_admission_id,v_invoice_no,'issued',p_estimated_cost,p_estimated_cost,0,now(),v_user);
  insert into public.invoice_items(clinic_id,invoice_id,item_type,description,quantity,unit_price,line_total) values(p_clinic_id,v_invoice_id,'ipd_operation','OT: '||trim(p_procedure_name),1,p_estimated_cost,p_estimated_cost);
 end if;
 insert into public.audit_logs(clinic_id,actor_user_id,action,entity_type,entity_id,details) values(p_clinic_id,v_user,'create_operation_theatre_case_full','operation_theatre_case',v_case_id::text,jsonb_build_object('patient_id',p_patient_id,'admission_id',p_admission_id,'procedure',p_procedure_name,'category',p_procedure_category,'estimate',p_estimated_cost,'invoice_id',v_invoice_id));
 return jsonb_build_object('case_id',v_case_id,'invoice_id',v_invoice_id,'invoice_no',v_invoice_no,'estimated_cost',p_estimated_cost,'status','planned');
end $$;
revoke all on function public.create_operation_theatre_case_full(uuid,uuid,uuid,uuid,text,text,text,text,uuid,uuid,timestamptz,timestamptz,numeric,text,text,text,text,text) from public,anon;
grant execute on function public.create_operation_theatre_case_full(uuid,uuid,uuid,uuid,text,text,text,text,uuid,uuid,timestamptz,timestamptz,numeric,text,text,text,text,text) to authenticated;
