'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Building2, ShieldCheck, Users } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { setActiveClinicId } from '@/lib/clinic';

export default function SetupPage() {
  const router = useRouter();
  const [message, setMessage] = useState('Checking your clinic access…');
  useEffect(() => {
    let alive = true;
    void (async () => {
      if (!supabase) { setMessage('Clinic sign-in is unavailable because Supabase is not configured.'); return; }
      const { data: { user } } = await supabase.auth.getUser();
      if (!alive) return;
      if (!user) { router.replace('/login'); return; }
      const { data: platformAdmin, error: platformError } = await supabase.from('platform_admins').select('active').eq('user_id', user.id).eq('active', true).maybeSingle();
      if (!alive) return;
      if (!platformError && platformAdmin?.active) { router.replace('/super-admin'); return; }
      const { data: memberships, error } = await supabase.from('clinic_members').select('clinic_id,role').eq('user_id', user.id).eq('active', true).limit(20);
      if (!alive) return;
      if (error) { setMessage(`Could not verify your clinic access: ${error.message}`); return; }
      if (memberships?.length) {
        const preferred = memberships.find(m => ['owner','admin'].includes(String(m.role).toLowerCase())) || memberships[0];
        setActiveClinicId(preferred.clinic_id);
        router.replace(['owner','admin'].includes(String(preferred.role).toLowerCase()) ? '/staff' : '/');
        return;
      }
      setMessage('Is account ko abhi kisi hospital/clinic se assign nahi kiya gaya hai. Super Admin se clinic create karwa kar is email ko Managing Director / Hospital Admin ke roop mein assign karwayein. Staff roles hospital ke Doctors & Staff page se banenge.');
    })();
    return () => { alive = false; };
  }, [router]);
  return <main className="login-screen"><section className="login-form-panel" style={{width:'100%',maxWidth:760,margin:'auto'}}><div className="login-form-wrap"><div className="login-brand-mark"><Building2 size={24}/></div><div className="login-welcome"><div className="login-kicker">ANAIRA HEALTHCARE ACCESS</div><h2>Hospital workspace access</h2><p>{message}</p></div><div className="login-alert success"><ShieldCheck size={16} style={{display:'inline',marginRight:8}}/>Super Admin clinic provisioning ke baad clinic owner ko Managing Director / Hospital Admin access milta hai.</div><div className="login-alert"><Users size={16} style={{display:'inline',marginRight:8}}/>Reception, doctor, pharmacy aur laboratory ke separate logins: <b>Doctors & Staff</b> page par create honge.</div><button className="login-submit" onClick={() => router.replace('/login')}>Go to sign in</button></div></section></main>;
}
