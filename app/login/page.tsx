'use client';
import { FormEvent, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Activity, ArrowRight, Eye, EyeOff, LockKeyhole, Mail, ShieldCheck, Smartphone } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { setActiveClinicId } from '@/lib/clinic';

type MfaStage = 'credentials' | 'challenge' | 'enroll';
type TotpFactor = { id: string; friendly_name?: string | null; status?: string };

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [configured, setConfigured] = useState(true);
  const [stage, setStage] = useState<MfaStage>('credentials');
  const [factorId, setFactorId] = useState('');
  const [challengeId, setChallengeId] = useState('');
  const [totpCode, setTotpCode] = useState('');
  const [qrCode, setQrCode] = useState('');
  const [manualSecret, setManualSecret] = useState('');

  function showFailure(cause: unknown) {
    setError(cause instanceof Error ? cause.message : 'Security verification failed. Please try again.');
  }

  async function continueToWorkspace() {
    if (!supabase) throw new Error('Supabase is not configured.');
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) throw new Error('Your login session could not be verified. Please sign in again.');
    const { data: admin, error: adminError } = await supabase.from('platform_admins').select('active').eq('user_id', user.id).eq('active', true).maybeSingle();
    if (adminError) throw new Error(`Super Admin permission could not be checked: ${adminError.message}`);
    if (admin?.active) { router.replace('/super-admin'); router.refresh(); return; }
    const { data: member, error: memberError } = await supabase.from('clinic_members').select('clinic_id').eq('user_id', user.id).eq('active', true).limit(1).maybeSingle();
    if (memberError) throw new Error(`Clinic access could not be loaded: ${memberError.message}`);
    if (member?.clinic_id) { setActiveClinicId(member.clinic_id); router.replace('/'); router.refresh(); return; }
    router.replace('/setup'); router.refresh();
  }

  async function prepareMfa() {
    if (!supabase) throw new Error('Supabase is not configured.');
    const { data: aal, error: aalError } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (aalError) throw aalError;
    const { data: factors, error: factorError } = await supabase.auth.mfa.listFactors();
    if (factorError) throw factorError;
    const totpFactors = (factors?.totp || []) as TotpFactor[];
    const verified = totpFactors.filter((factor: TotpFactor) => factor.status === 'verified');
    if (verified.length > 0 && aal?.currentLevel === 'aal2') { await continueToWorkspace(); return; }
    if (verified.length > 0) {
      const selected = verified[0];
      const { data: challenge, error: challengeError } = await supabase.auth.mfa.challenge({ factorId: selected.id });
      if (challengeError) throw challengeError;
      setFactorId(selected.id);
      setChallengeId(challenge.id);
      setStage('challenge');
      setMessage('Password accepted. Enter the current 6-digit code from your authenticator app.');
      return;
    }

    // A previous enrollment may remain unverified if the browser was closed
    // before the first OTP. The browser-side unenroll API can reject this
    // recovery path. Use a server-only Admin MFA endpoint, strictly scoped to
    // this platform-admin user and this named unverified TOTP factor.
    const pendingFactors = totpFactors.filter((factor: TotpFactor) => factor.status === 'unverified');
    if (pendingFactors.length > 0) {
      const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
      if (sessionError || !sessionData.session?.access_token) {
        throw new Error('Your authenticated session is missing. Please sign in again.');
      }
      const recoveryResponse = await fetch('/api/auth/mfa/recover', {
        method: 'POST',
        headers: { Authorization: `Bearer ${sessionData.session.access_token}` },
        cache: 'no-store',
      });
      const recoveryResult = await recoveryResponse.json().catch(() => ({}));
      if (!recoveryResponse.ok || recoveryResult.ok !== true) {
        throw new Error(recoveryResult.error || 'The incomplete authenticator setup could not be recovered.');
      }
    }

    const { data: enrollment, error: enrollError } = await supabase.auth.mfa.enroll({
      factorType: 'totp',
      friendlyName: 'Anaira Healthcare Authenticator',
    });
    if (enrollError) throw enrollError;
    setFactorId(enrollment.id);
    setQrCode(enrollment.totp.qr_code);
    setManualSecret(enrollment.totp.secret);
    setStage('enroll');
    setMessage('MFA is mandatory. Scan this QR code with Google Authenticator, Microsoft Authenticator, Authy or 1Password, then enter its 6-digit code.');
  }

  useEffect(() => {
    setConfigured(Boolean(supabase));
    if (!supabase) return;
    let alive = true;
    void (async () => {
      const { data: { session }, error: sessionError } = await supabase!.auth.getSession();
      if (!alive || sessionError || !session?.user) return;
      setBusy(true);
      try { await prepareMfa(); }
      catch (cause) { if (alive) showFailure(cause); }
      finally { if (alive) setBusy(false); }
    })();
    return () => { alive = false; };
  // This runs once on mount; prepareMfa uses the current Supabase session.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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
      await prepareMfa();
    } catch (cause) { showFailure(cause); }
    finally { setBusy(false); }
  }

  async function verifyTotp(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(''); setMessage('');
    if (!supabase || !factorId || !totpCode.trim()) return;
    setBusy(true);
    try {
      let activeChallengeId = challengeId;
      if (!activeChallengeId) {
        const { data, error: challengeError } = await supabase.auth.mfa.challenge({ factorId });
        if (challengeError) throw challengeError;
        activeChallengeId = data.id;
        setChallengeId(data.id);
      }
      const { error: verifyError } = await supabase.auth.mfa.verify({ factorId, challengeId: activeChallengeId, code: totpCode.replace(/\s/g, '') });
      if (verifyError) throw verifyError;
      setTotpCode('');
      await continueToWorkspace();
    } catch (cause) { showFailure(cause); }
    finally { setBusy(false); }
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
    } catch (cause) { showFailure(cause); }
    finally { setBusy(false); }
  }

  const mfaMode = stage !== 'credentials';
  // Supabase Auth already returns a data URI for TOTP QR codes in supported SDK versions.
  // Keep it intact; only wrap raw SVG markup as a fallback.
  const qrImageSrc = qrCode.trim().startsWith('data:')
    ? qrCode
    : qrCode.trim().startsWith('<svg')
      ? `data:image/svg+xml;charset=utf-8,${encodeURIComponent(qrCode)}`
      : '';
  return <main className="login-screen">
    <section className="login-brand-panel">
      <div className="login-brand"><img className="login-clinic-logo" src="/anaira-clinic-management-logo.png" alt="Anaira Healthcare Management System"/><span><b>Anaira</b><small>HEALTHCARE MANAGEMENT</small></span></div>
      <div className="login-brand-copy"><span className="login-kicker">CARE, CONNECTED.</span><h1>Better care starts with a clearer view.</h1><p>One secure workspace for your clinic team, patient visits and day-to-day operations.</p>
        <div className="login-feature"><ShieldCheck size={18}/><span><b>Multi-factor protected</b><small>Password plus authenticator verification is required.</small></span></div>
        <div className="login-feature"><LockKeyhole size={18}/><span><b>Private by design</b><small>Patient records stay within authorized clinic access.</small></span></div>
      </div>
      <div className="login-brand-footer"><img src="/anaira-graphics-logo.png" alt="Anaira Graphics & Digital Solution"/><span>Powered by Anaira Graphics &amp; Digital Solution</span><small>© {new Date().getFullYear()}</small></div>
    </section>
    <section className="login-form-panel"><div className="login-form-wrap">
      <div className="login-mobile-brand"><img className="login-mobile-logo" src="/anaira-clinic-management-logo.png" alt="Anaira Healthcare Management System"/><span><b>Anaira</b><small>HEALTHCARE MANAGEMENT</small></span></div>
      <div className="login-welcome"><div className="login-kicker">{mfaMode ? 'SECOND FACTOR REQUIRED' : 'WELCOME BACK'}</div><h2>{stage === 'enroll' ? 'Set up your authenticator' : stage === 'challenge' ? 'Verify it’s you' : 'Sign in to your account'}</h2><p>{mfaMode ? 'Your password alone cannot open the hospital workspace.' : 'Use your registered clinic or platform administrator account.'}</p></div>
      {!configured&&<div className="login-alert error">Supabase configuration is missing. Add the public Supabase URL and publishable/anon key to <code>.env.local</code>.</div>}
      {error&&<div className="login-alert error" role="alert">{error}</div>}
      {message&&<div className="login-alert success" role="status">{message}</div>}
      {stage === 'credentials' && <form onSubmit={submit} className="login-form">
        <label htmlFor="login-email">Email, phone number or username</label><div className="login-input-wrap"><Mail size={17}/><input id="login-email" type="text" autoComplete="username" required value={email} onChange={e=>setEmail(e.target.value)} placeholder="Email / 9876543210 / username"/></div>
        <div className="login-password-heading"><label htmlFor="login-password">Password</label><button type="button" className="login-text-button" onClick={()=>void resetPassword()} disabled={busy}>Forgot password?</button></div>
        <div className="login-input-wrap"><LockKeyhole size={17}/><input id="login-password" type={showPassword?'text':'password'} autoComplete="current-password" required value={password} onChange={e=>setPassword(e.target.value)} placeholder="Enter your password"/><button type="button" className="login-eye" onClick={()=>setShowPassword(v=>!v)} aria-label={showPassword?'Hide password':'Show password'}>{showPassword?<EyeOff size={17}/>:<Eye size={17}/>}</button></div>
        <button className="login-submit" type="submit" disabled={busy||!configured}>{busy?'Checking credentials…':'Continue securely'} <ArrowRight size={17}/></button>
      </form>}
      {stage === 'enroll' && <form onSubmit={verifyTotp} className="login-form mfa-form">
        <div className="mfa-qr-wrap"><img className="mfa-qr" src={qrImageSrc} alt="Authenticator setup QR code"/></div>
        <div className="mfa-secret"><b>Can’t scan the QR code?</b><code>{manualSecret}</code></div>
        <label htmlFor="mfa-enroll-code">6-digit authenticator code</label><div className="login-input-wrap"><Smartphone size={17}/><input id="mfa-enroll-code" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9 ]{6,8}" maxLength={8} required value={totpCode} onChange={e=>setTotpCode(e.target.value.replace(/[^0-9 ]/g,''))} placeholder="000000"/></div>
        <button className="login-submit" type="submit" disabled={busy||totpCode.replace(/\D/g,'').length!==6}>{busy?'Verifying authenticator…':'Enable MFA & continue'} <ShieldCheck size={17}/></button>
      </form>}
      {stage === 'challenge' && <form onSubmit={verifyTotp} className="login-form mfa-form">
        <div className="mfa-icon"><Smartphone size={30}/></div>
        <label htmlFor="mfa-code">Authenticator code</label><div className="login-input-wrap"><LockKeyhole size={17}/><input id="mfa-code" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9 ]{6,8}" maxLength={8} required autoFocus value={totpCode} onChange={e=>setTotpCode(e.target.value.replace(/[^0-9 ]/g,''))} placeholder="Enter 6-digit code"/></div>
        <button className="login-submit" type="submit" disabled={busy||totpCode.replace(/\D/g,'').length!==6}>{busy?'Verifying…':'Verify & open workspace'} <ArrowRight size={17}/></button>
        <button type="button" className="login-text-button" disabled={busy} onClick={async()=>{setBusy(true);try{await supabase?.auth.signOut();setStage('credentials');setMessage('You have been signed out. Sign in again to retry.');}catch(cause){showFailure(cause)}finally{setBusy(false)}}}>Use another account</button>
      </form>}
      <p className="login-security-note"><ShieldCheck size={14}/> Protected by Supabase Auth MFA (AAL2). Password-only access is blocked.</p>
      <p className="login-help">Having trouble? Contact your Anaira Healthcare administrator.</p>
      <div className="login-mobile-powered"><img src="/anaira-graphics-logo.png" alt="Anaira Graphics & Digital Solution"/><span><small>Powered by</small><b>Anaira Graphics &amp; Digital Solution</b></span></div>
    </div></section>
  </main>;
}
