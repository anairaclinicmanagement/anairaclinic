'use client';
import { useEffect, useState } from 'react';
import { Cloud, CloudOff } from 'lucide-react';
import { flushOfflineQueue, pendingOperations } from '@/lib/offline';
export default function OfflineStatus() {
  const [online, setOnline] = useState(true); const [pending,setPending]=useState(0); const [syncing,setSyncing]=useState(false);
  useEffect(() => { let alive=true; const refreshQueue=async()=>{try{const q=await pendingOperations();if(alive)setPending(q.length)}catch{}}; const sync=async()=>{setOnline(navigator.onLine);if(navigator.onLine){setSyncing(true);try{await flushOfflineQueue()}finally{if(alive)setSyncing(false)}}await refreshQueue()}; const update=()=>{setOnline(navigator.onLine);if(navigator.onLine)void sync();else void refreshQueue()}; void sync();window.addEventListener('online',update);window.addEventListener('offline',update);window.addEventListener('focus',update);return()=>{alive=false;window.removeEventListener('online',update);window.removeEventListener('offline',update);window.removeEventListener('focus',update)}; }, []);
  return <span className={`status-pill ${online ? 'online' : 'offline'}`} title={pending?`${pending} queued item(s) need attention`:syncing?'Syncing queued records':'Connection status'}>{online ? <Cloud size={14}/> : <CloudOff size={14}/>} {syncing?'Syncing…':online?'Online':'Offline mode'}{pending?` · ${pending} pending`:''}</span>;
}
