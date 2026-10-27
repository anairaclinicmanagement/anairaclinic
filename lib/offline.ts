import { openDB, type DBSchema } from 'idb';
import { supabase } from '@/lib/supabase';
import { getActiveClinicId } from '@/lib/clinic';

type PendingOperation = { id: string; table: string; action: 'insert'|'update'|'delete'; payload: Record<string, unknown>; createdAt: string; status: 'pending'|'error'; error?: string; ownerUserId?: string; clinicId?: string };
interface AnairaOfflineDB extends DBSchema {
  cache: { key: string; value: { key: string; data: unknown; updatedAt: string } };
  queue: { key: string; value: PendingOperation };
}
const DB_NAME = 'anaira-clinic-offline';
async function db() { return openDB<AnairaOfflineDB>(DB_NAME, 1, { upgrade(database) { if (!database.objectStoreNames.contains('cache')) database.createObjectStore('cache', { keyPath: 'key' }); if (!database.objectStoreNames.contains('queue')) database.createObjectStore('queue', { keyPath: 'id' }); } }); }
/**
 * Local cache is always namespaced by authenticated user AND active clinic.
 * Never fall back to a global key: doing so can display one tenant's PHI after
 * a user switches clinic or signs in as a different staff member.
 */
async function scopedCacheKey(key: string): Promise<string | null> {
  const clinicId = getActiveClinicId();
  if (!clinicId || !supabase) return null;
  const { data, error } = await supabase.auth.getSession();
  const userId = data.session?.user?.id;
  if (error || !userId) return null;
  return `user:${userId}:clinic:${clinicId}:${key}`;
}
export async function cacheRead<T>(key: string): Promise<T | null> {
  const scopedKey = await scopedCacheKey(key);
  if (!scopedKey) return null;
  const database = await db(); const item = await database.get('cache', scopedKey);
  return item ? item.data as T : null;
}
export async function cacheWrite(key: string, data: unknown) {
  const scopedKey = await scopedCacheKey(key);
  if (!scopedKey) return;
  const database = await db(); await database.put('cache', { key: scopedKey, data, updatedAt: new Date().toISOString() });
}
export async function queueOperation(operation: Omit<PendingOperation, 'id'|'createdAt'|'status'|'ownerUserId'|'clinicId'>) {
  const database = await db();
  const ownerUserId = typeof operation.payload.created_by === 'string' ? operation.payload.created_by : undefined;
  const clinicId = typeof operation.payload.clinic_id === 'string' ? operation.payload.clinic_id : undefined;
  const item: PendingOperation = { ...operation, id: crypto.randomUUID(), createdAt: new Date().toISOString(), status: 'pending', ownerUserId, clinicId };
  await database.put('queue', item); return item;
}
export async function pendingOperations() { return (await (await db()).getAll('queue')).filter(item => item.status === 'pending'); }
export async function removeQueuedOperation(id: string) { await (await db()).delete('queue', id); }
export async function setQueueError(id: string, error: string) { const database = await db(); const item = await database.get('queue', id); if (item) await database.put('queue', { ...item, status: 'error', error }); }

/** Safe online replay for the currently supported offline insert workflows only. RLS remains authoritative. */
export async function flushOfflineQueue(): Promise<{synced:number;failed:number;skipped:number}> {
  const result={synced:0,failed:0,skipped:0};
  if(typeof navigator==='undefined'||!navigator.onLine||!supabase)return result;
  const clinicId=getActiveClinicId();
  const {data:{user},error:authError}=await supabase.auth.getUser();
  if(authError||!user||!clinicId)return result;
  const items=await pendingOperations();
  for(const item of items){
    if(item.action!=='insert'||!['patients','appointments'].includes(item.table)){await setQueueError(item.id,'This operation type is not enabled for automatic replay.');result.skipped++;continue;}
    if(!item.ownerUserId||item.ownerUserId!==user.id||item.clinicId!==clinicId||item.payload.clinic_id!==clinicId||item.payload.created_by!==user.id){await setQueueError(item.id,'Queued record belongs to another user/clinic or lacks ownership metadata; manual review required.');result.skipped++;continue;}
    if(typeof item.payload.id!=='string'){await setQueueError(item.id,'Queued insert has no stable record ID; manual recovery required.');result.skipped++;continue;}
    const {error}=await supabase.from(item.table).upsert(item.payload,{onConflict:'id'});
    if(!error){await removeQueuedOperation(item.id);result.synced++;continue;}
    if(error.code==='23505'){
      const {data:existing,error:checkError}=await supabase.from(item.table).select('id').eq('id',item.payload.id).eq('clinic_id',clinicId).maybeSingle();
      if(existing&&!checkError){await removeQueuedOperation(item.id);result.synced++;continue;}
    }
    await setQueueError(item.id,`${error.code||'SYNC_ERROR'}: ${error.message}`);result.failed++;
  }
  return result;
}

export async function allQueuedOperations() {
  return (await (await db()).getAll('queue')).sort((a,b)=>a.createdAt.localeCompare(b.createdAt));
}
export async function retryQueuedOperation(id:string) {
  const database=await db(); const item=await database.get('queue',id);
  if(item) await database.put('queue',{...item,status:'pending',error:undefined});
}
export async function discardQueuedOperation(id:string) {
  await (await db()).delete('queue',id);
}
export async function syncQueuedOperations(): Promise<{synced:number;failed:number;remaining:number}> {
  const result=await flushOfflineQueue();
  const remaining=(await (await db()).getAll('queue')).length;
  return {synced:result.synced,failed:result.failed+result.skipped,remaining};
}
