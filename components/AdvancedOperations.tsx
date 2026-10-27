'use client';

import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import { Activity, AlertTriangle, ArrowRight, CheckCircle2, ClipboardList, Plus, RefreshCw, Save, Search, ShieldAlert } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { getActiveClinicId } from '@/lib/clinic';

type ModuleKey = 'radiology'|'operation_theatre'|'emergency'|'blood_bank'|'cssd'|'diet_nutrition'|'ambulance'|'procurement'|'assets'|'support'|'documents'|'telemedicine'|'referrals'|'clinical_quality'|'insurance'|'hr_payroll'|'patient_portal';
type WorkItem = {id:string;clinic_id:string;branch_id:string|null;patient_id:string|null;module_key:ModuleKey;title:string;status:string;priority:string;due_at:string|null;details:Record<string,unknown>;created_at:string;updated_at:string};
type Patient = {id:string;uhid:string;first_name:string;middle_name?:string|null;last_name?:string|null};
type Branch = {id:string;name:string;code?:string|null};
const modules: {key:ModuleKey;label:string;description:string;fields:string;statuses:string[]}[] = [
 {key:'radiology',label:'Radiology / RIS',description:'Imaging requests, modality scheduling, reporting hand-off and PACS reference tracking.',fields:'Modality, body region, imaging notes, report/PACS reference',statuses:['open','scheduled','in_progress','pending_review','verified','completed','cancelled']},
 {key:'operation_theatre',label:'Operation Theatre',description:'Surgery scheduling, pre-op checks, theatre handover and post-op completion tracking.',fields:'Procedure, surgeon, anaesthetist, pre-op checklist, theatre notes',statuses:['open','scheduled','in_progress','pending_review','approved','completed','cancelled']},
 {key:'emergency',label:'Emergency / Casualty',description:'Triage handover, urgent assessment, stabilisation and disposition tracking.',fields:'Triage level, arrival mode, chief complaint, disposition',statuses:['open','in_progress','pending_review','approved','completed','dispatched','cancelled']},
 {key:'blood_bank',label:'Blood Bank',description:'Blood component unit work items, reservation/issue handover and screening references.',fields:'Unit code, blood group, component type, expiry, screening status',statuses:['open','pending_review','approved','reserved','issued','completed','rejected','cancelled']},
 {key:'cssd',label:'CSSD / Sterilisation',description:'Sterilisation cycle, load traceability, quality result and department handover.',fields:'Cycle number, sterilizer, cycle type, load, parameters, result',statuses:['open','in_progress','pending_review','approved','rejected','completed']},
 {key:'diet_nutrition',label:'Diet & Nutrition',description:'Patient diet orders, restrictions, nutrition review and meal-service handover.',fields:'Diet type, restrictions, calories, start/end, dietitian notes',statuses:['open','scheduled','in_progress','approved','completed','cancelled']},
 {key:'ambulance',label:'Ambulance',description:'Dispatch, pickup, destination, crew/vehicle and trip status tracking.',fields:'Vehicle, driver, pickup, destination, dispatch/arrival notes',statuses:['open','dispatched','in_progress','pending_review','completed','cancelled']},
 {key:'procurement',label:'Procurement',description:'Purchase requests, approvals, supplier follow-up and receiving workflow.',fields:'Supplier, request/order number, items, estimate, expected delivery',statuses:['open','pending_review','approved','in_progress','completed','rejected','cancelled']},
 {key:'assets',label:'Assets & Maintenance',description:'Equipment register work, calibration, repair and preventive-maintenance jobs.',fields:'Asset code, category, serial, location, calibration/service due',statuses:['open','scheduled','in_progress','pending_review','approved','completed','cancelled']},
 {key:'support',label:'Support Centre',description:'Clinic support tickets, technical issues, billing questions and resolution notes.',fields:'Category, affected module, steps to reproduce, resolution',statuses:['open','in_progress','pending_review','resolved','closed','cancelled']},
 {key:'documents',label:'Document Centre',description:'Document collection, consent and records workflow; store secure Storage references, not public links.',fields:'Document category, storage reference, consent status, sensitivity',statuses:['open','pending_review','approved','completed','rejected','cancelled']},
 {key:'telemedicine',label:'Telemedicine',description:'Remote consultation scheduling, consent, session handover and follow-up.',fields:'Session provider/reference, consent, start time, follow-up',statuses:['open','scheduled','in_progress','pending_review','completed','cancelled']},
 {key:'referrals',label:'CRM / Referrals',description:'Referral source, referring provider, follow-up and outcome tracking.',fields:'Referral source, provider, reason, next follow-up, outcome',statuses:['open','scheduled','in_progress','pending_review','completed','cancelled']},
 {key:'clinical_quality',label:'Clinical Quality',description:'Clinical quality checks, documentation gaps, incidents and corrective actions.',fields:'Check type, severity, finding, corrective action, reviewer',statuses:['open','in_progress','pending_review','approved','resolved','closed']},
 {key:'insurance',label:'Insurance / TPA',description:'Pre-authorisation and claim documentation handover, queries and settlement follow-up.',fields:'Insurer/TPA, policy reference, pre-auth number, claim status, amount',statuses:['open','pending_review','approved','in_progress','resolved','rejected','closed']},
 {key:'hr_payroll',label:'HR & Payroll',description:'Staff requests, onboarding tasks, roster follow-ups and payroll approval tracking.',fields:'Employee, task type, period, approval notes',statuses:['open','pending_review','approved','in_progress','completed','rejected','cancelled']},
 {key:'patient_portal',label:'Patient Portal',description:'Patient portal requests, feedback, communication consent and access support.',fields:'Request type, consent status, contact preference, resolution notes',statuses:['open','in_progress','pending_review','resolved','closed','cancelled']}
];
const statusLabels: Record<string,string> = {open:'Open',scheduled:'Scheduled',in_progress:'In progress',pending_review:'Pending review',approved:'Approved',collected:'Collected',processing:'Processing',verified:'Verified',completed:'Completed',cancelled:'Cancelled',rejected:'Rejected',dispatched:'Dispatched',resolved:'Resolved',closed:'Closed',reserved:'Reserved',issued:'Issued'};
export default function AdvancedOperations({initialModule='radiology'}:{initialModule?:ModuleKey}) {
 const [moduleKey,setModuleKey]=useState<ModuleKey>(initialModule);
 const [rows,setRows]=useState<WorkItem[]>([]);
 const [patients,setPatients]=useState<Patient[]>([]);
 const [branches,setBranches]=useState<Branch[]>([]);
 const [showForm,setShowForm]=useState(false);
 const [query,setQuery]=useState('');
 const [message,setMessage]=useState('');
 const [error,setError]=useState('');
 const [busy,setBusy]=useState(false);
 const [clinicId,setClinicId]=useState<string|null>(null);
 const [form,setForm]=useState({title:'',patient_id:'',branch_id:'',priority:'normal',due_at:'',details:''});
 const current=modules.find(m=>m.key===moduleKey)!;
 const load=useCallback(async()=>{
  setError(''); const c=getActiveClinicId(); setClinicId(c);
  if(!supabase){setError('Supabase configuration is missing. Set the public URL and publishable key.');return}
  if(!c){setError('No active clinic selected. Sign in and select a clinic workspace first.');return}
  const [{data:items,error:itemError},{data:people,error:patientError},{data:branchRows,error:branchError}]=await Promise.all([
   supabase.from('hospital_work_items').select('id,clinic_id,branch_id,patient_id,module_key,title,status,priority,due_at,details,created_at,updated_at').eq('clinic_id',c).eq('module_key',moduleKey).order('created_at',{ascending:false}).limit(300),
   supabase.from('patients').select('id,uhid,first_name,middle_name,last_name').eq('clinic_id',c).is('archived_at',null).order('first_name').limit(500),
   supabase.from('clinic_branches').select('id,name,code').eq('clinic_id',c).eq('active',true).order('name')
  ]);
  if(itemError){setError(itemError.message);return}
  setRows((items||[]) as WorkItem[]); setPatients((people||[]) as Patient[]); setBranches((branchRows||[]) as Branch[]);
  if(branchError)setMessage(`Branch selector could not load: ${branchError.message}`);
  if(patientError)setMessage(`Records loaded; patient selector could not load: ${patientError.message}`);
 },[moduleKey]);
 useEffect(()=>{void load()},[load]);
 const filtered=useMemo(()=>rows.filter(r=>`${r.title} ${r.status} ${r.priority} ${JSON.stringify(r.details||{})}`.toLowerCase().includes(query.toLowerCase())),[rows,query]);
 async function create(e:FormEvent<HTMLFormElement>){
  e.preventDefault(); setError('');setMessage('');
  if(!supabase||!clinicId){setError('Select an active clinic before creating a record.');return}
  if(form.title.trim().length<2){setError('Please enter a descriptive title.');return}
  let details:Record<string,unknown>={};
  if(form.details.trim()){try{const parsed=JSON.parse(form.details);if(!parsed||Array.isArray(parsed)||typeof parsed!=='object')throw new Error();details=parsed as Record<string,unknown>}catch{setError('Details must be valid JSON, for example: {"category":"CT","notes":"urgent"}');return}}
  setBusy(true);
  try{
   const {data:{user}}=await supabase.auth.getUser();
   const payload={clinic_id:clinicId,branch_id:form.branch_id||null,patient_id:form.patient_id||null,module_key:moduleKey,title:form.title.trim(),priority:form.priority,due_at:form.due_at?new Date(form.due_at).toISOString():null,details,created_by:user?.id||null,updated_by:user?.id||null};
   const {data,error:e2}=await supabase.from('hospital_work_items').insert(payload).select('id,clinic_id,branch_id,patient_id,module_key,title,status,priority,due_at,details,created_at,updated_at').single();
   if(e2)throw e2;
   setRows(prev=>[data as WorkItem,...prev]);setForm({title:'',patient_id:'',branch_id:'',priority:'normal',due_at:'',details:''});setShowForm(false);setMessage('Record created and saved to the clinic database.');
  }catch(e){setError(e instanceof Error?e.message:'Unable to create record. Check permissions and migration status.')}finally{setBusy(false)}
 }
 async function transition(item:WorkItem,status:string){
  if(!supabase||!clinicId)return;setError('');setMessage('');
  const note=window.prompt('Optional audit note for this status change:')||null;
  const {data,error:e}=await supabase.rpc('update_hospital_work_item_status',{p_clinic_id:clinicId,p_item_id:item.id,p_status:status,p_notes:note});
  if(e){setError(e.message);return}
  setRows(prev=>prev.map(r=>r.id===item.id?{...r,status:String((data as {status?:string})?.status||status),updated_at:new Date().toISOString()}:r));
  setMessage(`Workflow updated: ${item.title} → ${statusLabels[status]||status}.`);
 }
 return <><div className="page-heading"><div><div className="eyebrow">HOSPITAL OPERATIONS · TENANT-SCOPED</div><h1>{current.label}</h1><p>{current.description}</p></div><button className="secondary-button" onClick={()=>void load()}><RefreshCw size={15}/> Refresh</button></div>
 {error&&<div className="notice"><ShieldAlert size={16} style={{display:'inline',marginRight:8,verticalAlign:'middle'}}/>{error}</div>}{message&&<div className="notice-success">{message}</div>}
 <div className="module-grid">{modules.map(m=><button key={m.key} type="button" className={`module-tile ${m.key===moduleKey?'module-tile-active':''}`} onClick={()=>{setModuleKey(m.key);setMessage('');setError('')}}><span>{m.label}</span><small>{m.key.replaceAll('_',' ')}</small></button>)}</div>
 <section className="panel"><div className="panel-heading"><div><h2>Workflow register</h2><p>{filtered.length} record(s) · {current.fields}</p></div><button className="primary-button" onClick={()=>setShowForm(v=>!v)}><Plus size={15}/>{showForm?'Close':'Create record'}</button></div>
 {showForm&&<form onSubmit={create} className="advanced-form"><div className="form-grid"><div className="field" style={{gridColumn:'1 / -1'}}><label>Title / reference *</label><input required minLength={2} maxLength={240} value={form.title} onChange={e=>setForm({...form,title:e.target.value})} placeholder={`${current.label} task, order or case`}/></div><div className="field"><label>Branch (optional)</label><select value={form.branch_id} onChange={e=>setForm({...form,branch_id:e.target.value})}><option value="">Clinic-wide / not assigned</option>{branches.map(b=><option key={b.id} value={b.id}>{b.name}{b.code?` · ${b.code}`:''}</option>)}</select></div><div className="field"><label>Related patient (optional)</label><select value={form.patient_id} onChange={e=>setForm({...form,patient_id:e.target.value})}><option value="">No patient linked</option>{patients.map(p=><option key={p.id} value={p.id}>{[p.first_name,p.middle_name,p.last_name].filter(Boolean).join(' ')} · {p.uhid}</option>)}</select></div><div className="field"><label>Priority</label><select value={form.priority} onChange={e=>setForm({...form,priority:e.target.value})}><option value="low">Low</option><option value="normal">Normal</option><option value="high">High</option><option value="urgent">Urgent</option></select></div><div className="field"><label>Due / scheduled time</label><input type="datetime-local" value={form.due_at} onChange={e=>setForm({...form,due_at:e.target.value})}/></div><div className="field" style={{gridColumn:'1 / -1'}}><label>Structured details (JSON)</label><textarea rows={4} value={form.details} onChange={e=>setForm({...form,details:e.target.value})} placeholder={'{"category":"example","notes":"handover notes","reference":"REF-001"}'}/><small>Use the fields listed above the register. Store document references here; do not paste public links or secrets.</small></div></div><div className="form-actions"><button type="button" className="secondary-button" onClick={()=>setShowForm(false)}>Cancel</button><button className="primary-button" disabled={busy}><Save size={15}/>{busy?'Saving…':'Save record'}</button></div></form>}
 <div className="panel-toolbar"><div className="search-mini"><Search size={14}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="Search title, status or details" aria-label="Search workflow records"/></div><span className="tag">{rows.length} total</span></div>
 <div className="table-wrap"><table className="data-table"><thead><tr><th>Reference</th><th>Branch</th><th>Patient</th><th>Priority</th><th>Status</th><th>Due</th><th>Last updated</th><th>Next action</th></tr></thead><tbody>{filtered.map(r=><tr key={r.id}><td><b>{r.title}</b><small style={{display:'block',marginTop:4,color:'#80918a'}}>{r.id.slice(0,8).toUpperCase()} · {Object.keys(r.details||{}).length} detail field(s)</small></td><td>{branches.find(b=>b.id===r.branch_id)?.name||'Clinic-wide'}</td><td>{patients.find(p=>p.id===r.patient_id)?`${patients.find(p=>p.id===r.patient_id)?.first_name||''} ${patients.find(p=>p.id===r.patient_id)?.last_name||''}`:'—'}</td><td><span className={`tag ${r.priority==='urgent'?'urgent':r.priority==='high'?'waiting':''}`}>{r.priority}</span></td><td><span className={`tag ${['completed','resolved','closed','verified','approved'].includes(r.status)?'completed':r.status==='cancelled'?'cancelled':'waiting'}`}>{statusLabels[r.status]||r.status}</span></td><td>{r.due_at?new Date(r.due_at).toLocaleString('en-IN'):'—'}</td><td>{new Date(r.updated_at||r.created_at).toLocaleString('en-IN')}</td><td><select aria-label={`Update status for ${r.title}`} value={r.status} onChange={e=>void transition(r,e.target.value)}>{current.statuses.map(s=><option key={s} value={s}>{statusLabels[s]||s}</option>)}</select></td></tr>)}{!filtered.length&&<tr><td colSpan={8} className="table-empty"><ClipboardList size={20} style={{display:'block',margin:'0 auto 8px'}}/>No workflow records yet. Create the first record for this module.</td></tr>}</tbody></table></div></section>
 <div className="notice" style={{marginTop:16}}><AlertTriangle size={16} style={{display:'inline',marginRight:8,verticalAlign:'middle'}}/>This release provides tenant-scoped workflow registers and audit-tracked status changes. Medical-device integrations, actual file upload/storage, blood-unit compatibility testing, PACS/DICOM exchange and provider delivery still require their dedicated integration and clinical validation before production use.</div>
 </>;
}
