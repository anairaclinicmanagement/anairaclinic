'use client';
import { FormEvent, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Activity, ArrowRight, Eye, EyeOff, LockKeyhole, Mail, ShieldCheck } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { setActiveClinicId } from '@/lib/clinic';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [configured, setConfigured] = useState(true);

  useEffect(() => {
    setConfigured(Boolean(supabase));
    if (!supabase) return;
    let alive = true;
    void supabase.auth.getSession().then(async ({ data }) => {
      if (!alive || !data.session?.user) return;
      const user = data.session.user;
      const { data: admin } = await supabase!.from('platform_admins').select('active').eq('user_id', user.id).eq('active', true).maybeSingle();
      if (!alive) return;
      if (admin?.active) { router.replace('/super-admin'); return; }
      const { data: member } = await supabase!.from('clinic_members').select('clinic_id').eq('user_id', user.id).eq('active', true).limit(1).maybeSingle();
      if (!alive) return;
      if (member?.clinic_id) { setActiveClinicId(member.clinic_id); router.replace('/'); }
      else router.replace('/setup');
    });
    return () => { alive = false; };
  }, [router]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(''); setMessage('');
    if (!supabase) { setError('Supabase is not configured. Check NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY in .env.local, then restart the server.'); return; }
    setBusy(true);
    try {
      const identifier = email.trim();
      const isEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(identifier);
      const isPhone = /^\+?[0-9 ()-]{7,20}$/.test(identifier) && identifier.replace(/\D/g, '').length >= 7;
      const digits = identifier.replace(/\D/g, '');
      const normalizedUsername = identifier.toLowerCase();
      const authEmail = isEmail ? normalizedUsername : isPhone ? `login-phone-${digits}@staff.anaira.invalid` : `login-user-${normalizedUsername}@staff.anaira.invalid`;
      const { data, error: authError } = await supabase.auth.signInWithPassword({ email: authEmail, password });
      if (authError) throw authError;
      if (!data.user) throw new Error('Login did not return a user. Please try again.');
      const { data: admin, error: adminError } = await supabase.from('platform_admins').select('active').eq('user_id', data.user.id).eq('active', true).maybeSingle();
      if (adminError) throw new Error(`Signed in, but Super Admin permission could not be checked: ${adminError.message}`);
      if (admin?.active) { router.replace('/super-admin'); router.refresh(); return; }
      const { data: memberships, error: memberError } = await supabase.from('clinic_members').select('clinic_id').eq('user_id', data.user.id).eq('active', true).limit(1).maybeSingle();
      if (memberError) throw new Error(`Signed in, but clinic access could not be loaded: ${memberError.message}`);
      if (memberships?.clinic_id) { setActiveClinicId(memberships.clinic_id); router.replace('/'); router.refresh(); return; }
      setMessage('Login successful, but this account has no active clinic workspace yet. Continue to workspace setup.');
      router.replace('/setup'); router.refresh();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Unable to sign in. Check your email and password.');
    } finally { setBusy(false); }
  }

  async function resetPassword() {
    setError(''); setMessage('');
    if (!supabase) { setError('Supabase is not configured.'); return; }
    if (!email.trim() || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) { setError('Password reset by email is available only when you enter a real email login. For username/phone logins, contact your Managing Director.'); return; }
    setBusy(true);
    try {
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: `${window.location.origin}/login` });
      if (resetError) throw resetError;
      setMessage('If this email belongs to an account, Supabase will send password-reset instructions. Check your inbox and spam folder.');
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Password reset could not be requested.'); }
    finally { setBusy(false); }
  }

  return <main className="login-screen"><section className="login-brand-panel"><div className="login-brand"><img className="login-clinic-logo" src="/anaira-clinic-management-logo.png" alt="Anaira Clinic Management"/><span><b>Anaira</b><small>CLINIC MANAGEMENT</small></span></div><div className="login-brand-copy"><span className="login-kicker">CARE, CONNECTED.</span><h1>Better care starts with a clearer view.</h1><p>One secure workspace for your clinic team, patient visits and day-to-day operations.</p><div className="login-feature"><ShieldCheck size={18}/><span><b>Access protected</b><small>Clinic permissions are verified after sign-in.</small></span></div><div className="login-feature"><LockKeyhole size={18}/><span><b>Private by design</b><small>Patient records stay within authorized clinic access.</small></span></div></div><div className="login-brand-footer"><img src="/anaira-graphics-logo.png" alt="Anaira Graphics & Digital Solution"/><span>Powered by Anaira Graphics &amp; Digital Solution</span><small>© {new Date().getFullYear()}</small></div></section><section className="login-form-panel"><div className="login-form-wrap"><div className="login-mobile-brand"><img className="login-mobile-logo" src="/anaira-clinic-management-logo.png" alt="Anaira Clinic Management"/><span><b>Anaira</b><small>CLINIC MANAGEMENT</small></span></div><div className="login-welcome"><div className="login-kicker">WELCOME BACK</div><h2>Sign in to your account</h2><p>Use your registered clinic or platform administrator account.</p></div>{!configured&&<div className="login-alert error">Supabase configuration is missing. Add the public Supabase URL and publishable/anon key to <code>.env.local</code>.</div>}{error&&<div className="login-alert error" role="alert">{error}</div>}{message&&<div className="login-alert success" role="status">{message}</div>}<form onSubmit={submit} className="login-form"><label htmlFor="login-email">Email, phone number or username</label><div className="login-input-wrap"><Mail size={17}/><input id="login-email" type="text" autoComplete="username" required value={email} onChange={e=>setEmail(e.target.value)} placeholder="Email / 9876543210 / username"/></div><div className="login-password-heading"><label htmlFor="login-password">Password</label><button type="button" className="login-text-button" onClick={()=>void resetPassword()} disabled={busy}>Forgot password?</button></div><div className="login-input-wrap"><LockKeyhole size={17}/><input id="login-password" type={showPassword?'text':'password'} autoComplete="current-password" required value={password} onChange={e=>setPassword(e.target.value)} placeholder="Enter your password"/><button type="button" className="login-eye" onClick={()=>setShowPassword(v=>!v)} aria-label={showPassword?'Hide password':'Show password'}>{showPassword?<EyeOff size={17}/>:<Eye size={17}/>}</button></div><button className="login-submit" type="submit" disabled={busy||!configured}>{busy?'Signing in…':'Sign in securely'} <ArrowRight size={17}/></button></form><p className="login-security-note"><ShieldCheck size={14}/> Your account is authenticated securely by Supabase.</p><p className="login-help">Having trouble? Contact your Anaira Clinic administrator.</p></div></section></main>;
}
