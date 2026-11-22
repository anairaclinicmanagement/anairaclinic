alter table public.lab_tests add column if not exists description text;
alter table public.lab_tests add column if not exists preparation_instructions text;
alter table public.lab_tests add column if not exists turnaround_hours integer;
alter table public.lab_tests add column if not exists modality text;
alter table public.lab_tests add column if not exists fasting_required boolean not null default false;
alter table public.lab_tests add column if not exists contrast_required boolean not null default false;

-- Keep platform/clinic admins in control. Lab and imaging staff can edit only their own catalogue categories.
drop policy if exists lab_tests_module_entitlement on public.lab_tests;
create policy lab_tests_module_entitlement on public.lab_tests as restrictive for all to authenticated
using (
  private.has_clinic_role(clinic_id,array['owner','admin'])
  or (lower(coalesce(category,'')) in ('laboratory','pathology','haematology','hematology','biochemistry','microbiology','serology','cytology','histopathology') and clinic_module_access(clinic_id,'laboratory'))
  or (lower(coalesce(category,'')) in ('x-ray','ultrasound / usg','ct scan','mri','radiology / imaging','ecg','echo','other diagnostic') and (clinic_module_access(clinic_id,'radiology') or clinic_module_access(clinic_id,'laboratory')))
)
with check (
  private.has_clinic_role(clinic_id,array['owner','admin'])
  or (lower(coalesce(category,'')) in ('laboratory','pathology','haematology','hematology','biochemistry','microbiology','serology','cytology','histopathology') and clinic_module_access(clinic_id,'laboratory'))
  or (lower(coalesce(category,'')) in ('x-ray','ultrasound / usg','ct scan','mri','radiology / imaging','ecg','echo','other diagnostic') and (clinic_module_access(clinic_id,'radiology') or clinic_module_access(clinic_id,'laboratory')))
);

drop policy if exists lab_tests_catalogue_edit_scope on public.lab_tests;
create policy lab_tests_catalogue_edit_scope on public.lab_tests as restrictive for update to authenticated
using (
  private.has_clinic_role(clinic_id,array['owner','admin'])
  or (private.has_clinic_role(clinic_id,array['lab_technician']) and lower(coalesce(category,'')) in ('laboratory','pathology','haematology','hematology','biochemistry','microbiology','serology','cytology','histopathology'))
  or (private.has_clinic_role(clinic_id,array['radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician']) and lower(coalesce(category,'')) in ('x-ray','ultrasound / usg','ct scan','mri','radiology / imaging','ecg','echo','other diagnostic'))
)
with check (
  private.has_clinic_role(clinic_id,array['owner','admin'])
  or (private.has_clinic_role(clinic_id,array['lab_technician']) and lower(coalesce(category,'')) in ('laboratory','pathology','haematology','hematology','biochemistry','microbiology','serology','cytology','histopathology'))
  or (private.has_clinic_role(clinic_id,array['radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician']) and lower(coalesce(category,'')) in ('x-ray','ultrasound / usg','ct scan','mri','radiology / imaging','ecg','echo','other diagnostic'))
);

create index if not exists lab_tests_clinic_modality_active_idx on public.lab_tests(clinic_id,modality,active);

with catalog(test_code,name,category,specimen,price,unit,reference_range,modality,preparation_instructions,turnaround_hours,fasting_required,contrast_required,description) as (values
('CAT-001','Complete Blood Count (CBC)','Laboratory','EDTA blood',350::numeric,null,'As per laboratory reference','', 'Routine haematology',6,false,false,'Routine haematology'),
('CAT-002','Haemoglobin (Hb)','Laboratory','EDTA blood',120::numeric,'g/dL','Lab reference range','', 'Routine',4,false,false,'Routine'),
('CAT-003','ESR','Laboratory','EDTA blood',150::numeric,'mm/hr','Lab reference range','', 'Routine',6,false,false,'Routine'),
('CAT-004','Peripheral Blood Smear','Laboratory','EDTA blood',250::numeric,null,'Microscopy interpretation','', 'Routine',8,false,false,'Routine'),
('CAT-005','Blood Group ABO & Rh','Laboratory','EDTA blood',200::numeric,null,'ABO/Rh typing','', 'Routine',4,false,false,'Routine'),
('CAT-006','Fasting Blood Glucose','Laboratory','Fluoride plasma',100::numeric,'mg/dL','Lab reference range','', 'Fasting sample',4,true,false,'Biochemistry'),
('CAT-007','Post Prandial Blood Glucose','Laboratory','Fluoride plasma',100::numeric,'mg/dL','Lab reference range','', 'Collect as instructed after meal',4,false,false,'Biochemistry'),
('CAT-008','Random Blood Glucose','Laboratory','Fluoride plasma',100::numeric,'mg/dL','Lab reference range','', 'Random sample',4,false,false,'Biochemistry'),
('CAT-009','HbA1c','Laboratory','EDTA blood',450::numeric,'%', 'Lab reference range','', 'Glycaemic monitoring',8,false,false,'Glycaemic monitoring'),
('CAT-010','Liver Function Test (LFT)','Laboratory','Serum',650::numeric,null,'Lab reference range','', 'Biochemistry panel',8,false,false,'Biochemistry panel'),
('CAT-011','Kidney Function Test (KFT/RFT)','Laboratory','Serum',650::numeric,null,'Lab reference range','', 'Biochemistry panel',8,false,false,'Biochemistry panel'),
('CAT-012','Lipid Profile','Laboratory','Serum',600::numeric,null,'Lab reference range','', 'Lipid panel',8,true,false,'Lipid panel'),
('CAT-013','Thyroid Profile (T3/T4/TSH)','Laboratory','Serum',650::numeric,null,'Lab reference range','', 'Thyroid panel',24,false,false,'Thyroid panel'),
('CAT-014','TSH','Laboratory','Serum',350::numeric,'µIU/mL','Lab reference range','', 'Thyroid function',24,false,false,'Thyroid function'),
('CAT-015','Vitamin D (25-OH)','Laboratory','Serum',1200::numeric,'ng/mL','Lab reference range','', 'Vitamin assay',24,false,false,'Vitamin assay'),
('CAT-016','Vitamin B12','Laboratory','Serum',850::numeric,'pg/mL','Lab reference range','', 'Vitamin assay',24,false,false,'Vitamin assay'),
('CAT-017','Serum Calcium','Laboratory','Serum',250::numeric,'mg/dL','Lab reference range','', 'Electrolyte/mineral',8,false,false,'Biochemistry'),
('CAT-018','Serum Electrolytes (Na/K/Cl)','Laboratory','Serum',450::numeric,null,'Lab reference range','', 'Electrolyte panel',8,false,false,'Electrolyte panel'),
('CAT-019','Uric Acid','Laboratory','Serum',250::numeric,'mg/dL','Lab reference range','', 'Biochemistry',8,false,false,'Biochemistry'),
('CAT-020','C-Reactive Protein (CRP)','Laboratory','Serum',450::numeric,'mg/L','Lab reference range','', 'Inflammation marker',8,false,false,'Inflammation marker'),
('CAT-021','Procalcitonin','Laboratory','Serum',1500::numeric,'ng/mL','Lab reference range','', 'Infection marker',12,false,false,'Infection marker'),
('CAT-022','Urine Routine & Microscopy','Laboratory','Urine',200::numeric,null,'Lab reference range','', 'Clean-catch midstream urine preferred',6,false,false,'Urine analysis'),
('CAT-023','Urine Culture & Sensitivity','Laboratory','Urine sterile container',650::numeric,null,'Culture report','', 'Collect before antibiotics when clinically appropriate',48,false,false,'Culture'),
('CAT-024','Stool Routine Examination','Laboratory','Stool',200::numeric,null,'Microscopy interpretation','', 'Fresh sample',6,false,false,'Stool analysis'),
('CAT-025','Stool Occult Blood','Laboratory','Stool',300::numeric,null,'Lab reference range','', 'Follow lab collection instructions',8,false,false,'Stool analysis'),
('CAT-026','Blood Culture','Laboratory','Blood culture bottles',1200::numeric,null,'Culture report','', 'Collection timing per clinician protocol',72,false,false,'Culture'),
('CAT-027','Dengue NS1 Antigen','Laboratory','Serum',700::numeric,null,'Lab reference range','', 'Dengue assay',8,false,false,'Serology'),
('CAT-028','Dengue IgM/IgG','Laboratory','Serum',700::numeric,null,'Lab reference range','', 'Dengue serology',8,false,false,'Serology'),
('CAT-029','Malaria Antigen / Smear','Laboratory','EDTA blood',350::numeric,null,'Lab reference range','', 'Malaria screen',6,false,false,'Malaria screen'),
('CAT-030','Widal Test','Laboratory','Serum',300::numeric,null,'Interpret with clinical findings','', 'Serology',8,false,false,'Serology'),
('CAT-031','HIV 1 & 2 Screening','Laboratory','Serum',500::numeric,null,'Approved assay/reporting protocol','', 'Consent and approved testing workflow required',12,false,false,'Serology'),
('CAT-032','HBsAg','Laboratory','Serum',350::numeric,null,'Lab reference range','', 'Serology',8,false,false,'Serology'),
('CAT-033','Anti-HCV','Laboratory','Serum',500::numeric,null,'Lab reference range','', 'Serology',12,false,false,'Serology'),
('CAT-034','PT/INR','Laboratory','Citrated plasma',450::numeric,null,'Lab reference range','', 'Coagulation',6,false,false,'Coagulation'),
('CAT-035','aPTT','Laboratory','Citrated plasma',450::numeric,null,'Lab reference range','', 'Coagulation',6,false,false,'Coagulation'),
('CAT-036','D-Dimer','Laboratory','Citrated plasma',950::numeric,null,'Lab reference range','', 'Coagulation marker',8,false,false,'Coagulation marker'),
('CAT-037','Serum Amylase','Laboratory','Serum',450::numeric,'U/L','Lab reference range','', 'Biochemistry',8,false,false,'Biochemistry'),
('CAT-038','Serum Lipase','Laboratory','Serum',500::numeric,'U/L','Lab reference range','', 'Biochemistry',8,false,false,'Biochemistry'),
('CAT-039','Iron Studies / Ferritin','Laboratory','Serum',900::numeric,null,'Lab reference range','', 'Iron status',24,false,false,'Iron status'),
('CAT-040','Reticulocyte Count','Laboratory','EDTA blood',300::numeric,'%', 'Lab reference range','', 'Haematology',8,false,false,'Haematology'),
('CAT-041','Urine Pregnancy Test','Laboratory','Urine',150::numeric,null,'Qualitative result','', 'Urine sample',2,false,false,'Pregnancy screening'),
('CAT-042','Serum Beta-hCG','Laboratory','Serum',650::numeric,'mIU/mL','Lab reference range','', 'Hormone assay',24,false,false,'Hormone assay'),
('CAT-043','Semen Analysis','Laboratory','Semen sample',700::numeric,null,'Lab reference range','', 'Collection instructions from laboratory',8,false,false,'Andrology'),
('CAT-044','Sputum AFB Smear','Laboratory','Sputum',250::numeric,null,'Microscopy report','', 'Respiratory specimen protocol',8,false,false,'Microbiology'),
('CAT-045','Sputum Culture','Laboratory','Sputum',700::numeric,null,'Culture report','', 'Collect before antibiotics when appropriate',48,false,false,'Microbiology'),
('CAT-046','Pap Smear Cytology','Laboratory','Cervical sample',800::numeric,null,'Cytology report','', 'Collection by trained clinician',72,false,false,'Cytology'),
('CAT-047','FNAC Cytology','Laboratory','Aspirate specimen',1200::numeric,null,'Cytology report','', 'Procedure and specimen protocol',72,false,false,'Cytology'),
('CAT-048','Histopathology Biopsy','Laboratory','Tissue specimen',1800::numeric,null,'Histopathology report','', 'Fixation and specimen handling protocol',96,false,false,'Histopathology'),
('CAT-049','X-Ray Chest PA','X-Ray','N/A',400::numeric,null,'Radiologist report','X-Ray Chest PA','Confirm pregnancy status when applicable; radiographer protocol',8,false,false,'X-Ray'),
('CAT-050','X-Ray Chest AP','X-Ray','N/A',400::numeric,null,'Radiologist report','X-Ray Chest AP','Portable/AP protocol as ordered',8,false,false,'X-Ray'),
('CAT-051','X-Ray KUB','X-Ray','N/A',500::numeric,null,'Radiologist report','X-Ray KUB','Radiographer protocol',8,false,false,'X-Ray'),
('CAT-052','X-Ray Cervical Spine','X-Ray','N/A',600::numeric,null,'Radiologist report','X-Ray Cervical Spine','Views as ordered by clinician',8,false,false,'X-Ray'),
('CAT-053','X-Ray Lumbar Spine','X-Ray','N/A',700::numeric,null,'Radiologist report','X-Ray Lumbar Spine','Views as ordered by clinician',8,false,false,'X-Ray'),
('CAT-054','X-Ray Knee Joint','X-Ray','N/A',500::numeric,null,'Radiologist report','X-Ray Knee Joint','Side and views as ordered',8,false,false,'X-Ray'),
('CAT-055','USG Whole Abdomen','Ultrasound / USG','N/A',1200::numeric,null,'Radiologist report','USG Whole Abdomen','Fasting/bladder instructions as per radiology protocol',8,true,false,'Ultrasound'),
('CAT-056','USG Pelvis','Ultrasound / USG','N/A',1000::numeric,null,'Radiologist report','USG Pelvis','Bladder preparation as per radiology protocol',8,false,false,'Ultrasound'),
('CAT-057','USG Obstetric / Pregnancy','Ultrasound / USG','N/A',1400::numeric,null,'Radiologist report','USG Obstetric','Gestational details and referral information',8,false,false,'Ultrasound'),
('CAT-058','USG KUB','Ultrasound / USG','N/A',1000::numeric,null,'Radiologist report','USG KUB','Bladder preparation as per radiology protocol',8,false,false,'Ultrasound'),
('CAT-059','USG Thyroid','Ultrasound / USG','N/A',900::numeric,null,'Radiologist report','USG Thyroid','Confirm local protocol',8,false,false,'Ultrasound'),
('CAT-060','USG Doppler Venous','Ultrasound / USG','N/A',1800::numeric,null,'Radiologist report','USG Doppler Venous','Limb and clinical indication required',12,false,false,'Doppler ultrasound'),
('CAT-061','CT Brain Plain','CT Scan','N/A',2500::numeric,null,'Radiologist report','CT Brain Plain','Confirm indication and pregnancy status when applicable',8,false,false,'CT'),
('CAT-062','CT Chest Plain','CT Scan','N/A',3500::numeric,null,'Radiologist report','CT Chest Plain','Confirm indication and pregnancy status when applicable',12,false,false,'CT'),
('CAT-063','CT Abdomen/Pelvis Contrast','CT Scan','N/A',6500::numeric,null,'Radiologist report','CT Abdomen/Pelvis Contrast','Contrast eligibility, renal function and allergy screening by clinician/radiology team',24,false,true,'CT'),
('CAT-064','CT PNS','CT Scan','N/A',2800::numeric,null,'Radiologist report','CT PNS','Protocol per radiologist',12,false,false,'CT'),
('CAT-065','MRI Brain Plain','MRI','N/A',5500::numeric,null,'Radiologist report','MRI Brain Plain','MRI safety screening; verify implants, metal exposure and pregnancy per local protocol',24,false,false,'MRI'),
('CAT-066','MRI Brain with Contrast','MRI','N/A',8500::numeric,null,'Radiologist report','MRI Brain with Contrast','MRI safety and contrast eligibility screening by qualified team',24,false,true,'MRI'),
('CAT-067','MRI Cervical Spine','MRI','N/A',6000::numeric,null,'Radiologist report','MRI Cervical Spine','MRI safety screening; confirm region and clinical indication',24,false,false,'MRI'),
('CAT-068','MRI Lumbar Spine','MRI','N/A',6000::numeric,null,'Radiologist report','MRI Lumbar Spine','MRI safety screening; confirm region and clinical indication',24,false,false,'MRI'),
('CAT-069','MRI Whole Spine Screening','MRI','N/A',10500::numeric,null,'Radiologist report','MRI Whole Spine Screening','MRI safety screening; protocol as ordered by radiologist',24,false,false,'MRI'),
('CAT-070','MRI Knee Joint','MRI','N/A',6500::numeric,null,'Radiologist report','MRI Knee Joint','Side and clinical indication required; MRI safety screening',24,false,false,'MRI'),
('CAT-071','MRI Shoulder Joint','MRI','N/A',6500::numeric,null,'Radiologist report','MRI Shoulder Joint','Side and clinical indication required; MRI safety screening',24,false,false,'MRI'),
('CAT-072','MRI MRCP','MRI','N/A',8500::numeric,null,'Radiologist report','MRI MRCP','Preparation per radiology department protocol',24,false,false,'MRI'),
('CAT-073','MRI Angiography (MRA)','MRI','N/A',9000::numeric,null,'Radiologist report','MRI Angiography','MRI safety and contrast screening if contrast planned',24,false,false,'MRI'),
('CAT-074','MRI Pelvis','MRI','N/A',7500::numeric,null,'Radiologist report','MRI Pelvis','Preparation per radiology department protocol',24,false,false,'MRI'),
('CAT-075','ECG 12 Lead','ECG','N/A',250::numeric,null,'ECG tracing and clinician interpretation','ECG','Record patient symptoms/clinical indication',2,false,false,'ECG'),
('CAT-076','2D Echo','Echo','N/A',1800::numeric,null,'Cardiology report','2D Echo','Cardiology department protocol',12,false,false,'Echocardiography')
)
insert into public.lab_tests(clinic_id,test_code,name,category,specimen,price,unit,reference_range,modality,preparation_instructions,turnaround_hours,fasting_required,contrast_required,description,active)
select c.id,v.test_code,v.name,v.category,v.specimen,v.price,v.unit,v.reference_range,v.modality,v.preparation_instructions,v.turnaround_hours,v.fasting_required,v.contrast_required,v.description,true
from public.clinics c cross join catalog v
where not exists(select 1 from public.lab_tests old where old.clinic_id=c.id and lower(old.name)=lower(v.name));

-- Route ECG and Echo tests to the imaging queue instead of the laboratory queue.
do $$
declare
  d text;
  old text := 'when lower(coalesce(t.category,'''')) like ''%radiology%'' or lower(coalesce(t.category,'''')) like ''%imaging%'' then ''radiology'' else ''laboratory'' end;';
  new text := 'when lower(coalesce(t.category,'''')) like ''%radiology%'' or lower(coalesce(t.category,'''')) like ''%imaging%'' or lower(coalesce(t.category,'''')) like ''%ecg%'' or lower(coalesce(t.category,'''')) like ''%echo%'' then ''radiology'' else ''laboratory'' end;';
begin
  select pg_get_functiondef('public.create_reception_diagnostic_bill(uuid,uuid,uuid[],text,boolean)'::regprocedure) into d;
  if position(old in d)>0 then execute replace(d,old,new); end if;
end $$;
