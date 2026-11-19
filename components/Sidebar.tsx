'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { getActiveClinicId, setActiveClinicId } from '@/lib/clinic';
import { Activity, CalendarDays, ClipboardPlus, CreditCard, FlaskConical, LayoutDashboard, Pill, Settings, Users, Stethoscope, Building2, BedDouble, ShieldCheck, LogOut, ActivitySquare, FileBarChart, Siren, ScanLine, HeartPulse, Truck, Package, Wrench, LifeBuoy, FileText, Video, GitBranch, ClipboardCheck, Wallet, UserCog, RefreshCw, Hospital, SlidersHorizontal, Headset, Database, ReceiptText } from 'lucide-react';
const links = [
  {module:'dashboard',href:'/',label:'Dashboard',icon:LayoutDashboard},
  {module:'patients',href:'/patients',label:'Patients',icon:Users},
  {module:'appointments',href:'/appointments',label:'Appointments & Queue',icon:CalendarDays},
  {module:'opd',href:'/opd',label:'OPD',icon:ReceiptText},
  {module:'consultation',href:'/consultation',label:'Consultation / EMR',icon:Stethoscope},
  {module:'prescriptions',href:'/prescriptions',label:'Prescription',icon:ReceiptText},
  {module:'billing',href:'/billing',label:'Billing & Payments',icon:CreditCard},
  {module:'reports',href:'/reports',label:'Reports & Analytics',icon:FileBarChart},
  {module:'pharmacy',href:'/pharmacy',label:'Pharmacy & Stock',icon:Pill},
  {module:'laboratory',href:'/laboratory',label:'Laboratory',icon:FlaskConical},
  {module:'multi_branch',href:'/branches',label:'Branches',icon:Building2},
  {module:'staff',href:'/doctors',label:'Doctors',icon:Stethoscope},
  {module:'staff',href:'/staff',label:'Staff & Role Management',icon:Users},
  {module:'ipd',href:'/ipd',label:'IPD / Bed Management',icon:BedDouble},
  {module:'ipd',href:'/hospital-services',label:'Hospital Services Overview',icon:Hospital},
  {module:'radiology',href:'/radiology',label:'Radiology / RIS',icon:ScanLine},
  {module:'operation_theatre',href:'/operation-theatre',label:'Operation Theatre',icon:ActivitySquare},
  {module:'emergency',href:'/emergency',label:'Emergency / Casualty',icon:Siren},
  {module:'blood_bank',href:'/blood-bank',label:'Blood Bank',icon:HeartPulse},
  {module:'cssd',href:'/cssd',label:'CSSD / Sterilisation',icon:ClipboardCheck},
  {module:'diet',href:'/diet',label:'Diet & Nutrition',icon:Activity},
  {module:'ambulance',href:'/ambulance',label:'Ambulance',icon:Truck},
  {module:'procurement',href:'/procurement',label:'Procurement',icon:Package},
  {module:'asset_management',href:'/assets',label:'Assets & Maintenance',icon:Wrench},
  {module:'insurance',href:'/insurance',label:'Insurance / TPA',icon:Wallet},
  {module:'hr_payroll',href:'/hr-payroll',label:'HR & Payroll',icon:UserCog},
  {module:'documents',href:'/documents',label:'Document Centre',icon:FileText},
  {module:'telemedicine',href:'/telemedicine',label:'Telemedicine',icon:Video},
  {module:'referrals',href:'/referrals',label:'Referrals & CRM',icon:GitBranch},
  {module:'clinical_quality',href:'/clinical-quality',label:'Clinical Quality',icon:ClipboardCheck},
  {href:'/support',label:'Support Centre',icon:LifeBuoy},
  {module:'patient_portal',href:'/patient-portal',label:'Patient Portal Requests',icon:Users},
  {module:'offline_sync',href:'/sync',label:'Sync & Recovery',icon:RefreshCw},
  {href:'/settings',label:'Clinic Settings',icon:Settings}
];
type ClinicOption = { clinic_id: string; role: string; clinics?: { name?: string; enabled_modules?: string[]; specialties?: string[]; facility_model?: string } | { name?: string; enabled_modules?: string[]; specialties?: string[]; facility_model?: string }[] | null };
async function getClinicMenuModules(clinicId: string, clinicModules?: string[] | null): Promise<string[]> {
 const base = Array.isArray(clinicModules) ? clinicModules : [];
 const client = supabase;
 if (!client) return base;
 const now = new Date().toISOString();
 const { data: subscriptions } = await client.from('clinic_subscriptions').select('plan_id,status,ends_at,trial_ends_at,created_at').eq('clinic_id', clinicId).in('status', ['active','trialing','trial','approved']).order('created_at', { ascending: false }).limit(5);
 const subscription = (subscriptions || []).find((item: any) => (!item.ends_at || item.ends_at > now) && (!item.trial_ends_at || item.trial_ends_at > now));
 let planModules: string[] | null = null;
 if (subscription?.plan_id) {
  const { data: plan } = await client.from('clinic_plans').select('enabled_modules,active').eq('id', subscription.plan_id).maybeSingle();
  if (plan?.active && Array.isArray(plan.enabled_modules)) planModules = plan.enabled_modules;
 }
 const { data: overrides } = await client.from('clinic_module_overrides').select('module_code,enabled,expires_at').eq('clinic_id', clinicId);
 const allowed = new Set(planModules === null ? base : base.filter(code => planModules!.includes(code)));
 (overrides || []).forEach((item: any) => { if (!item.expires_at || item.expires_at > now) { if (item.enabled) allowed.add(item.module_code); else allowed.delete(item.module_code); } });
 return [...allowed];
}
export default function Sidebar() {
 const pathname = usePathname();
 const [clinics,setClinics] = useState<ClinicOption[]>([]);
 const [activeId,setActiveId] = useState<string|null>(null);
 const [email,setEmail] = useState('Not signed in');
 const [role,setRole] = useState('Workspace user');
 const [isPlatformAdmin,setIsPlatformAdmin] = useState(false);
 const [enabledModules,setEnabledModules] = useState<string[]>([]);
 const [mobileMenuOpen,setMobileMenuOpen] = useState(false);
 useEffect(()=>{let alive=true;const client=supabase;(async()=>{if(!client)return;const {data:{user}}=await client.auth.getUser();if(!alive)return;if(!user){setEmail('Not signed in');return}setEmail(user.email||'Clinic user');const {data:platformAdmin}=await client.from('platform_admins').select('active').eq('user_id',user.id).eq('active',true).maybeSingle();if(alive&&platformAdmin?.active){setIsPlatformAdmin(true);setRole('Super Admin')}const {data,error}=await client.from('clinic_members').select('clinic_id,role,clinics(name,enabled_modules,specialties,facility_model)').eq('user_id',user.id).eq('active',true);if(!alive||error||!data)return;const options=data as unknown as ClinicOption[];setClinics(options);let selected=getActiveClinicId();if(!selected||!options.some(x=>x.clinic_id===selected)){selected=options[0]?.clinic_id||null;if(selected)setActiveClinicId(selected)}setActiveId(selected);const member=options.find(x=>x.clinic_id===selected);const relation=member?(Array.isArray(member.clinics)?member.clinics[0]:member.clinics):null;if(selected && member){const resolved=await getClinicMenuModules(selected, relation?.enabled_modules);if(alive)setEnabledModules(resolved)}else setEnabledModules([]);if(member)setRole(member.role);else if(platformAdmin?.active)setRole('Super Admin')} )();return()=>{alive=false}},[]);
 // Keep navigation in sync with plan/plugin changes without requiring logout or a hard refresh.
 useEffect(() => {
  const client = supabase;
  if (!activeId || !client) return;
  let alive = true;
  const refreshEntitlements = async () => {
   const { data: clinic, error } = await client.from('clinics').select('enabled_modules').eq('id', activeId).maybeSingle();
   if (!alive) return;
   if (error) {
    console.error('Failed to refresh clinic modules:', error);
    return;
   }
   const resolved = await getClinicMenuModules(activeId, clinic?.enabled_modules || []);
   if (alive) setEnabledModules(resolved);
  };
  void refreshEntitlements();
  const onFocus = () => { void refreshEntitlements(); };
  const onVisibility = () => { if (document.visibilityState === 'visible') void refreshEntitlements(); };
  window.addEventListener('focus', onFocus);
  document.addEventListener('visibilitychange', onVisibility);
  const channel = client.channel(`sidebar-entitlements-${activeId}`)
   .on('postgres_changes', { event: '*', schema: 'public', table: 'clinics', filter: `id=eq.${activeId}` }, () => { void refreshEntitlements(); })
   .on('postgres_changes', { event: '*', schema: 'public', table: 'clinic_subscriptions', filter: `clinic_id=eq.${activeId}` }, () => { void refreshEntitlements(); })
   .on('postgres_changes', { event: '*', schema: 'public', table: 'clinic_module_overrides', filter: `clinic_id=eq.${activeId}` }, () => { void refreshEntitlements(); })
   .subscribe();
  return () => {
   alive = false;
   window.removeEventListener('focus', onFocus);
   document.removeEventListener('visibilitychange', onVisibility);
   void client.removeChannel(channel);
  };
 }, [activeId]);
 const isSuperAdminRoute = isPlatformAdmin && pathname.startsWith('/super-admin');
 const platformLinks = [
  {href:'/super-admin#overview',label:'Platform Dashboard',icon:LayoutDashboard},
  {href:'/super-admin#clinics',label:'Clinics & Hospitals',icon:Building2},
  {href:'/super-admin#subscriptions',label:'Plans & Subscriptions',icon:Wallet},
  {href:'/super-admin#modules',label:'Module Access',icon:SlidersHorizontal},
  {href:'/super-admin#feature-flags',label:'Feature Flags',icon:SlidersHorizontal},
  {href:'/super-admin#platform-users',label:'Platform Users',icon:UserCog},
  {href:'/super-admin#audit-logs',label:'Audit Logs',icon:ReceiptText},
  {href:'/super-admin#support',label:'Support Tickets',icon:Headset},
  {href:'/super-admin#settings',label:'Platform Settings',icon:Settings},
  {href:'/super-admin#recovery',label:'Backup & Recovery',icon:Database},
 ];
 const roleModules: Record<string,string[]> = { owner: ['dashboard','opd','patients','appointments','consultation','prescriptions','billing','pharmacy','laboratory','multi_branch','staff','doctors','ipd','radiology','operation_theatre','emergency','blood_bank','cssd','diet','ambulance','procurement','asset_management','insurance','hr_payroll','documents','telemedicine','referrals','clinical_quality','patient_portal','reports','offline_sync'], admin: ['dashboard','opd','patients','appointments','consultation','prescriptions','billing','pharmacy','laboratory','multi_branch','staff','doctors','ipd','radiology','operation_theatre','emergency','blood_bank','cssd','diet','ambulance','procurement','asset_management','insurance','hr_payroll','documents','telemedicine','referrals','clinical_quality','patient_portal','reports','offline_sync'], doctor:['opd','patients','appointments','consultation','prescriptions','laboratory','radiology','ipd','reports','referrals','telemedicine'], radiology_technician:['radiology'], xray_technician:['radiology'], ultrasound_technician:['radiology'], ct_mri_technician:['radiology'], nurse:['patients','appointments','ipd','laboratory','prescriptions','reports'], pharmacist:['pharmacy'], lab_technician:['laboratory'], receptionist:['opd','patients','appointments','billing'], accountant:['reports'], staff:['dashboard','opd','patients','appointments','consultation','prescriptions','billing','pharmacy','laboratory','ipd','radiology','emergency','reports'] };
 const isManagementRole=['owner','admin'].includes(role.toLowerCase());
 const visibleLinks = isSuperAdminRoute ? [] : links.filter(link => { const moduleCode = 'module' in link && typeof link.module === 'string' ? link.module : null; const isCoreDashboard = moduleCode === 'dashboard'; const isSupport = link.href === '/support'; const entitlementCode = moduleCode === 'opd' ? 'appointments' : moduleCode; const moduleEnabled = moduleCode ? (isCoreDashboard || enabledModules.includes(entitlementCode!) || (moduleCode === 'staff' && enabledModules.includes('hr_payroll'))) : isSupport; const roleAllowed = !roleModules[role.toLowerCase()] || !moduleCode || roleModules[role.toLowerCase()].includes(moduleCode); return moduleEnabled && roleAllowed && (isManagementRole || moduleCode !== null || isSupport); });
 const mobileSourceLinks = isSuperAdminRoute ? platformLinks : visibleLinks;
 const mobilePriority=['/','/opd','/patients','/appointments'];
 const primaryMobileLinks=mobilePriority.map(href=>visibleLinks.find(x=>x.href===href)).filter((link): link is (typeof visibleLinks)[number] => Boolean(link)).slice(0,4);
 const mobileMenuLinks = isSuperAdminRoute ? platformLinks : [...visibleLinks, ...(isPlatformAdmin ? [{href:'/super-admin',label:'Super Admin Control',icon:ShieldCheck}] : [])];
 const clinicName=(c:ClinicOption)=>{const relation=Array.isArray(c.clinics)?c.clinics[0]:c.clinics;return relation?.name||'Clinic workspace'};
 function switchClinic(id:string){setActiveClinicId(id);setActiveId(id);const member=clinics.find(c=>c.clinic_id===id);const relation=member?(Array.isArray(member.clinics)?member.clinics[0]:member.clinics):null;void getClinicMenuModules(id, relation?.enabled_modules).then(setEnabledModules);setRole(member?.role||'Workspace user');window.location.assign('/')}
 async function signOut(){const client=supabase;if(!client)return;await client.auth.signOut();window.location.assign('/login')}
 return <aside className="sidebar"><div className="mobile-brand-row"><Link className="brand" href="/"><span className="brand-mark brand-logo-image"><img src="/anaira-clinic-management-logo.png" alt="Anaira Healthcare Management System logo" /></span><span><b>Anaira</b><small>HEALTHCARE MANAGEMENT</small></span></Link><button type="button" className="mobile-header-logout logout-button" onClick={()=>void signOut()} aria-label="Sign out" title="Sign out"><LogOut size={19}/><span>Logout</span></button></div>{!isSuperAdminRoute && <div className="clinic-switch"><span className="clinic-avatar">AC</span><span style={{minWidth:0,flex:1}}><b style={{display:'block',overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{clinics.find(c=>c.clinic_id===activeId)?clinicName(clinics.find(c=>c.clinic_id===activeId)!):'My Clinic'}</b><small>{clinics.length?`${clinics.length} workspace(s)`:'Setup required'}</small></span>{clinics.length>1&&<select aria-label="Switch clinic" value={activeId||''} onChange={e=>switchClinic(e.target.value)} style={{maxWidth:90,fontSize:10}}>{clinics.map(c=><option key={c.clinic_id} value={c.clinic_id}>{clinicName(c)}</option>)}</select>}</div>}<div className="nav-caption">{isSuperAdminRoute?'PLATFORM CONTROL': 'WORKSPACE'}</div><nav>{isSuperAdminRoute ? platformLinks.map(({href,label,icon:Icon})=><Link key={href} href={href} className={`nav-link ${((pathname+((typeof window!=='undefined')?window.location.hash:''))===href || (href.endsWith('#overview')&&pathname==='/super-admin'&&!((typeof window!=='undefined')&&window.location.hash)))?'active':''}`}><Icon size={18}/><span>{label}</span></Link>) : <>{visibleLinks.map(({href,label,icon:Icon})=><Link key={href} href={href} className={`nav-link ${(pathname===href || (href!=='/' && pathname.startsWith(href)))?'active':''}`}><Icon size={18}/><span>{label}</span></Link>)}{isPlatformAdmin&&<Link href="/super-admin" className={`nav-link ${pathname.startsWith('/super-admin')?'active':''}`}><ShieldCheck size={18}/><span>Super Admin</span></Link>}</>}</nav><div className="sidebar-bottom"><div className="user-row"><div className="user-avatar">{email.slice(0,1).toUpperCase()}</div><div style={{minWidth:0}}><b style={{display:'block',maxWidth:140,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{email}</b><small>{['owner','admin'].includes(role.toLowerCase())?'Managing Director / Hospital Admin':role}</small></div><button type="button" className="user-menu logout-button" onClick={()=>void signOut()} aria-label="Sign out" title="Sign out"><LogOut size={16}/></button></div></div><div className="powered-by"><span>Powered by</span><img src="/anaira-graphics-logo.png" alt="Anaira Graphics & Digital Solution"/><small>Anaira Graphics &amp; Digital Solution</small></div><>{mobileMenuOpen&&<div className="mobile-menu-backdrop" onClick={()=>setMobileMenuOpen(false)}><section className="mobile-menu-sheet" onClick={e=>e.stopPropagation()}><div className="mobile-menu-heading"><div><b>{isSuperAdminRoute?'Super Admin Menu':'All Workspace Menus'}</b><small>{role} · {mobileMenuLinks.length} available pages</small></div><button type="button" onClick={()=>setMobileMenuOpen(false)} aria-label="Close menu">×</button></div><div className="mobile-menu-list">{mobileMenuLinks.map(({href,label,icon:Icon})=><Link key={href} href={href} onClick={()=>setMobileMenuOpen(false)} className={`mobile-menu-item ${(pathname===href.split('#')[0]||(href!=='/'&&pathname.startsWith(href.split('#')[0])))?'active':''}`}><Icon size={19}/><span>{label}</span></Link>)}</div></section></div>}<nav className="mobile-bottom-nav" aria-label="Main navigation">{(isSuperAdminRoute?platformLinks.slice(0,4):primaryMobileLinks).map(({href,label,icon:Icon})=><Link key={href} href={href} className={`mobile-bottom-link ${(pathname===href.split('#')[0]||(href!=='/'&&pathname.startsWith(href.split('#')[0])))?'active':''}`}><Icon size={19}/><span>{href==='/'?'Home':label}</span></Link>)}<button type="button" className={`mobile-bottom-link mobile-more-button ${mobileMenuOpen?'active':''}`} onClick={()=>setMobileMenuOpen(v=>!v)} aria-expanded={mobileMenuOpen}><SlidersHorizontal size={19}/><span>All Menus</span></button></nav></></aside>
}
