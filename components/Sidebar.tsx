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
  {module:'pharmacy',href:'/pharmacy',label:'Pharmacy & Stock',icon:Pill},
  {module:'laboratory',href:'/laboratory',label:'Laboratory',icon:FlaskConical},
  {module:'multi_branch',href:'/branches',label:'Branches',icon:Building2},
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
  {module:'reports',href:'/reports',label:'Reports & Analytics',icon:FileBarChart},
  {module:'offline_sync',href:'/sync',label:'Sync & Recovery',icon:RefreshCw},
  {href:'/settings',label:'Clinic Settings',icon:Settings}
];
type ClinicOption = { clinic_id: string; role: string; clinics?: { name?: string; enabled_modules?: string[]; specialties?: string[]; facility_model?: string } | { name?: string; enabled_modules?: string[]; specialties?: string[]; facility_model?: string }[] | null };
export default function Sidebar() {
 const pathname = usePathname();
 const [clinics,setClinics] = useState<ClinicOption[]>([]);
 const [activeId,setActiveId] = useState<string|null>(null);
 const [email,setEmail] = useState('Not signed in');
 const [role,setRole] = useState('Workspace user');
 const [isPlatformAdmin,setIsPlatformAdmin] = useState(false);
 const [enabledModules,setEnabledModules] = useState<string[]>([]);
 useEffect(()=>{let alive=true;(async()=>{if(!supabase)return;const {data:{user}}=await supabase.auth.getUser();if(!alive)return;if(!user){setEmail('Not signed in');return}setEmail(user.email||'Clinic user');const {data:platformAdmin}=await supabase.from('platform_admins').select('active').eq('user_id',user.id).eq('active',true).maybeSingle();if(alive&&platformAdmin?.active){setIsPlatformAdmin(true)}const {data,error}=await supabase.from('clinic_members').select('clinic_id,role,clinics(name,enabled_modules,specialties,facility_model)').eq('user_id',user.id).eq('active',true);if(!alive||error||!data)return;const options=data as unknown as ClinicOption[];setClinics(options);let selected=getActiveClinicId();if(!selected||!options.some(x=>x.clinic_id===selected)){selected=options[0]?.clinic_id||null;if(selected)setActiveClinicId(selected)}setActiveId(selected);const member=options.find(x=>x.clinic_id===selected);const relation=member?(Array.isArray(member.clinics)?member.clinics[0]:member.clinics):null;setEnabledModules(relation?.enabled_modules||['patients','appointments','consultation','prescriptions','billing']);if(member)setRole(member.role);else if(platformAdmin?.active)setRole('Super Admin')} )();return()=>{alive=false}},[]);
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
 const roleModules: Record<string,string[]> = { owner: ['dashboard','opd','patients','appointments','consultation','prescriptions','billing','pharmacy','laboratory','multi_branch','staff','ipd','radiology','operation_theatre','emergency','blood_bank','cssd','diet','ambulance','procurement','asset_management','insurance','hr_payroll','documents','telemedicine','referrals','clinical_quality','patient_portal','reports','offline_sync'], admin: ['dashboard','opd','patients','appointments','consultation','prescriptions','billing','pharmacy','laboratory','multi_branch','staff','ipd','radiology','operation_theatre','emergency','blood_bank','cssd','diet','ambulance','procurement','asset_management','insurance','hr_payroll','documents','telemedicine','referrals','clinical_quality','patient_portal','reports','offline_sync'], doctor:['opd','patients','appointments','consultation','prescriptions','laboratory','radiology','ipd','reports','referrals','telemedicine'], radiology_technician:['radiology'], xray_technician:['radiology'], ultrasound_technician:['radiology'], ct_mri_technician:['radiology'], nurse:['patients','appointments','ipd','laboratory','prescriptions','reports'], pharmacist:['pharmacy'], lab_technician:['laboratory'], receptionist:['opd','patients','appointments','billing'], accountant:['reports'], staff:[] };
 const isManagementRole=['owner','admin'].includes(role.toLowerCase());
 const visibleLinks = isSuperAdminRoute ? [] : links.filter(link => ((!('module' in link) || typeof link.module !== 'string' || (link.module==='dashboard'&&isManagementRole) || link.href==='/opd' || (link.module==='staff'&&isManagementRole) || enabledModules.includes(link.module) || (link.module==='staff'&&enabledModules.includes('hr_payroll'))) && (isManagementRole || ('module' in link) || link.href==='/support') && (!roleModules[role.toLowerCase()] || !('module' in link) || typeof link.module !== 'string' || roleModules[role.toLowerCase()].includes(link.module))));
 const mobilePriority=['/','/opd','/patients','/billing','/pharmacy'];
 const primaryMobileLinks=mobilePriority.map(href=>visibleLinks.find(x=>x.href===href)).filter((link): link is (typeof visibleLinks)[number] => Boolean(link));
 const mobileLinks=[...primaryMobileLinks,...visibleLinks.filter(x=>!primaryMobileLinks.some(p=>p.href===x.href))];
 const clinicName=(c:ClinicOption)=>{const relation=Array.isArray(c.clinics)?c.clinics[0]:c.clinics;return relation?.name||'Clinic workspace'};
 function switchClinic(id:string){setActiveClinicId(id);setActiveId(id);const member=clinics.find(c=>c.clinic_id===id);const relation=member?(Array.isArray(member.clinics)?member.clinics[0]:member.clinics):null;setEnabledModules(relation?.enabled_modules||['patients','appointments','consultation','prescriptions','billing']);setRole(member?.role||'Workspace user');window.location.assign('/')}
 async function signOut(){if(!supabase)return;await supabase.auth.signOut();window.location.assign('/login')}
 return <aside className="sidebar"><div className="mobile-brand-row"><Link className="brand" href="/"><span className="brand-mark brand-logo-image"><img src="/anaira-clinic-management-logo.png" alt="Anaira Healthcare Management System logo" /></span><span><b>Anaira</b><small>HEALTHCARE MANAGEMENT</small></span></Link><button type="button" className="mobile-header-logout logout-button" onClick={()=>void signOut()} aria-label="Sign out" title="Sign out"><LogOut size={19}/><span>Logout</span></button></div>{!isSuperAdminRoute && <div className="clinic-switch"><span className="clinic-avatar">AC</span><span style={{minWidth:0,flex:1}}><b style={{display:'block',overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{clinics.find(c=>c.clinic_id===activeId)?clinicName(clinics.find(c=>c.clinic_id===activeId)!):'My Clinic'}</b><small>{clinics.length?`${clinics.length} workspace(s)`:'Setup required'}</small></span>{clinics.length>1&&<select aria-label="Switch clinic" value={activeId||''} onChange={e=>switchClinic(e.target.value)} style={{maxWidth:90,fontSize:10}}>{clinics.map(c=><option key={c.clinic_id} value={c.clinic_id}>{clinicName(c)}</option>)}</select>}</div>}<div className="nav-caption">{isSuperAdminRoute?'PLATFORM CONTROL': 'WORKSPACE'}</div><nav>{isSuperAdminRoute ? platformLinks.map(({href,label,icon:Icon})=><Link key={href} href={href} className={`nav-link ${((pathname+((typeof window!=='undefined')?window.location.hash:''))===href || (href.endsWith('#overview')&&pathname==='/super-admin'&&!((typeof window!=='undefined')&&window.location.hash)))?'active':''}`}><Icon size={18}/><span>{label}</span></Link>) : <>{visibleLinks.map(({href,label,icon:Icon})=><Link key={href} href={href} className={`nav-link ${(pathname===href || (href!=='/' && pathname.startsWith(href)))?'active':''}`}><Icon size={18}/><span>{label}</span></Link>)}{isPlatformAdmin&&<Link href="/super-admin" className={`nav-link ${pathname.startsWith('/super-admin')?'active':''}`}><ShieldCheck size={18}/><span>Super Admin</span></Link>}</>}</nav><div className="sidebar-bottom"><div className="user-row"><div className="user-avatar">{email.slice(0,1).toUpperCase()}</div><div style={{minWidth:0}}><b style={{display:'block',maxWidth:140,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{email}</b><small>{['owner','admin'].includes(role.toLowerCase())?'Managing Director / Hospital Admin':role}</small></div><button type="button" className="user-menu logout-button" onClick={()=>void signOut()} aria-label="Sign out" title="Sign out"><LogOut size={16}/></button></div></div><div className="powered-by"><span>Powered by</span><img src="/anaira-graphics-logo.png" alt="Anaira Graphics & Digital Solution"/><small>Anaira Graphics &amp; Digital Solution</small></div>{!isSuperAdminRoute&&<nav className="mobile-bottom-nav" aria-label="Main navigation">{mobileLinks.map(({href,label,icon:Icon})=><Link key={href} href={href} className={`mobile-bottom-link ${(pathname===href||(href!=='/'&&pathname.startsWith(href)))?'active':''}`}><Icon size={19}/><span>{href==='/'?'Home':href==='/opd'?'OPD':href==='/patients'?'Patients':href==='/billing'?'Billing':href==='/pharmacy'?'Pharmacy':label}</span></Link>)}</nav>}</aside>
}
