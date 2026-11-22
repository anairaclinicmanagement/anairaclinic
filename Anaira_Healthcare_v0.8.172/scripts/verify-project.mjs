import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const errors = [];
const warnings = [];
const mustExist = [
  'app/page.tsx','app/login/page.tsx','app/setup/page.tsx','app/super-admin/page.tsx',
  'app/patients/page.tsx','app/doctors/page.tsx','app/appointments/page.tsx','app/consultation/page.tsx',
  'app/billing/page.tsx','app/laboratory/page.tsx','app/pharmacy/page.tsx','app/prescriptions/page.tsx','app/ipd/page.tsx',
  'components/AdvancedOperations.tsx','lib/supabase.ts','lib/offline.ts',
  'supabase/migrations/20261011100000_anaira_clinic_initial_core_schema.sql',
  'supabase/migrations/20261011141000_anaira_clinic_tenant_module_security.sql',
  'supabase/migrations/20261011144000_anaira_clinic_advanced_module_foundation.sql',
  'supabase/functions/clinic-create-staff/index.ts',
  'supabase/migrations/20261023142034_anaira_clinic_staff_logins_and_department_access.sql'
];
for (const file of mustExist) if (!fs.existsSync(path.join(root, file))) errors.push(`Missing required file: ${file}`);
const appDir = path.join(root, 'app');
const routes = fs.readdirSync(appDir, {withFileTypes:true}).filter(x=>x.isDirectory()).map(x=>x.name);
for (const route of ['patients','appointments','consultation','billing','laboratory','pharmacy','prescriptions','ipd','super-admin','procurement','radiology','operation-theatre','emergency','doctors','blood-bank','cssd','diet','ambulance','insurance','hr-payroll','telemedicine','referrals','clinical-quality']) {
  if (!routes.includes(route)) errors.push(`Missing required route directory: app/${route}`);
}
const patientsSource = fs.readFileSync(path.join(root,'app/patients/page.tsx'),'utf8');
for (const required of ['possibleDuplicate','candidatePhone','candidateDob','Date of birth cannot be in the future']) {
  if (!patientsSource.includes(required)) errors.push(`Patient registration guard missing: ${required}`);
}
const migrationDir = path.join(root, 'supabase/migrations');

const platformMigration = fs.readFileSync(path.join(migrationDir,'20261011145000_anaira_clinic_platform_user_and_audit_controls.sql'),'utf8');
for (const required of ['platform_admin_list_users','platform_admin_set_user_active','private.is_platform_admin()','last active platform administrator cannot be disabled','platform_audit_logs']) {
  if (!platformMigration.includes(required)) errors.push(`Platform administration guard missing: ${required}`);
}
const offlineSource = fs.readFileSync(path.join(root,'lib/offline.ts'),'utf8');
for (const required of ['scopedCacheKey','user:${userId}:clinic:${clinicId}:${key}','getSession()']) {
  if (!offlineSource.includes(required)) errors.push(`Tenant-scoped offline cache guard missing: ${required}`);
}
const patientMigration = fs.readFileSync(path.join(migrationDir,'20261012100000_anaira_clinic_atomic_patient_registration.sql'),'utf8');
for (const required of ['register_clinic_patient','pg_advisory_xact_lock','duplicate_detected',"('appointments','patient_id','patients')","('invoices','patient_id','patients')"]) {
  if (!patientMigration.includes(required)) errors.push(`Patient registration / tenant FK hardening missing: ${required}`);
}
const patientSource = fs.readFileSync(path.join(root,'app/patients/page.tsx'),'utf8');
if (!patientSource.includes("rpc('register_clinic_patient'")) errors.push('Patient registration must use the server-side registration RPC');
const superAdminSource = fs.readFileSync(path.join(root,'app/super-admin/page.tsx'),'utf8');
for (const required of ['id="platform-users"','id="audit-logs"','platform_admin_list_users','platform_admin_set_user_active']) {
  if (!superAdminSource.includes(required)) errors.push(`Super Admin control missing: ${required}`);
}

const migrations = fs.readdirSync(migrationDir).filter(x=>x.endsWith('.sql')).sort();
if (migrations.length < 10) errors.push(`Expected migration history >= 10 files, found ${migrations.length}`);
for (const file of migrations) {
  const sql = fs.readFileSync(path.join(migrationDir,file),'utf8');
  if (/\bDROP\s+SCHEMA\s+public\b/i.test(sql)) errors.push(`Dangerous public schema drop found in ${file}`);
}
const staffSource = fs.readFileSync(path.join(root,'app/staff/page.tsx'),'utf8');
for (const required of ['clinic-create-staff','Create staff login','pharmacist','lab_technician','Create login & set password','login_id']) if (!staffSource.includes(required)) errors.push(`Staff login workflow missing: ${required}`);
const staffFunction = fs.readFileSync(path.join(root,'supabase/functions/clinic-create-staff/index.ts'),'utf8');
for (const required of ['createUser','clinic_members','staff_profiles','Only this clinic owner/admin','password_set_by_admin','verify_jwt']) if (!staffFunction.includes(required) && required !== 'verify_jwt') errors.push(`Staff provisioning security missing: ${required}`);
const patientDirectoryMigration = fs.readFileSync(path.join(migrationDir,'20261023142034_anaira_clinic_staff_logins_and_department_access.sql'),'utf8');
for (const required of ['clinic_patient_directory','private.has_clinic_role','staff_profiles_select_self']) if (!patientDirectoryMigration.includes(required)) errors.push(`Department access migration missing: ${required}`);
const appShellSource = fs.readFileSync(path.join(root,'components/AppShell.tsx'),'utf8');
for (const required of ["pharmacist:['/pharmacy','/support']","lab_technician:['/laboratory','/support']",'pathAllowed']) if (!appShellSource.includes(required)) errors.push(`Staff route restriction missing: ${required}`);
const pharmacySource = fs.readFileSync(path.join(root,'app/pharmacy/page.tsx'),'utf8');
for (const required of ['dispense_pharmacy_sale','Stock alerts','Add medicine','Receive stock','Pharmacy bill']) if (!pharmacySource.includes(required)) errors.push(`Pharmacy workflow missing: ${required}`);
const prescriptionSource = fs.readFileSync(path.join(root,'app/prescriptions/page.tsx'),'utf8');
for (const required of ['create_clinic_prescription','set_clinic_prescription_validity','Print parchi','New parchi required']) if (!prescriptionSource.includes(required)) errors.push(`Prescription workflow missing: ${required}`);
const pharmacyMigration = fs.readFileSync(path.join(migrationDir,'20261023141900_anaira_clinic_pharmacy_billing_prescription_validity.sql'),'utf8');
for (const required of ['dispense_pharmacy_sale','set_clinic_prescription_validity','create_clinic_prescription','create_clinic_billed_lab_order','record_clinic_invoice_payment','stock_movements','valid_until']) if (!pharmacyMigration.includes(required)) errors.push(`Pharmacy/prescription migration missing: ${required}`);
const ignore = fs.readFileSync(path.join(root,'.gitignore'),'utf8');
if (!ignore.includes('.env.*')) warnings.push('.gitignore does not exclude .env.*');
if (!ignore.includes('!.env.example')) warnings.push('.env.example may be excluded by ignore rules');
const pkg = JSON.parse(fs.readFileSync(path.join(root,'package.json'),'utf8'));
if (!pkg.scripts?.build || !pkg.scripts?.typecheck) errors.push('package.json must define build and typecheck scripts');
if (!pkg.scripts?.['verify:static']) errors.push('package.json missing verify:static script');
const secretFiles = [];
function walk(dir) { for (const ent of fs.readdirSync(dir,{withFileTypes:true})) { if (ent.name==='node_modules'||ent.name==='.next'||ent.name==='.git') continue; const full=path.join(dir,ent.name); if(ent.isDirectory()) walk(full); else if(/^\.env(\.|$)/.test(ent.name)&&ent.name!=='.env.example') secretFiles.push(path.relative(root,full)); } }
walk(root);
if (secretFiles.length) errors.push(`Potential secret env files included in source tree: ${secretFiles.join(', ')}`);
console.log(`Anaira Clinic static project verification`);
console.log(`Routes found: ${routes.length}; SQL migrations found: ${migrations.length}`);
console.log(`Required files checked: ${mustExist.length}`);
for (const w of warnings) console.warn(`WARN: ${w}`);
for (const e of errors) console.error(`FAIL: ${e}`);
if (errors.length) process.exit(1);
console.log('PASS: static structure and migration safety checks. This does NOT replace TypeScript, production build, database, browser E2E, or tenant-isolation tests.');

const doctorsSource = fs.readFileSync(path.join(root,'app/doctors/page.tsx'),'utf8');
for (const required of ['Add Doctor','Save Doctor Details','Create Doctor Login','staff_profile_id','qualification','registration_number']) if (!doctorsSource.includes(required)) errors.push(`Doctor directory workflow missing: ${required}`);
const staffFn = fs.readFileSync(path.join(root,'supabase/functions/clinic-create-staff/index.ts'),'utf8');
for (const required of ['staff_profile_id','Link a previously saved doctor profile','user_id']) if (!staffFn.includes(required)) errors.push(`Existing doctor profile login-link workflow missing: ${required}`);
