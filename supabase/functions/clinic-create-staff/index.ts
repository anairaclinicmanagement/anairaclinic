import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.4';
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Content-Type': 'application/json' };
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: cors });
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return reply({ error: 'Method not allowed' }, 405);
  const url = Deno.env.get('SUPABASE_URL'), anon = Deno.env.get('SUPABASE_ANON_KEY'), service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anon || !service) return reply({ error: 'Staff provisioning is not configured on the server.' }, 500);
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) return reply({ error: 'Sign in required.' }, 401);
  const caller = createClient(url, anon, { global: { headers: { Authorization: `Bearer ${token}` } }, auth: { persistSession: false, autoRefreshToken: false } });
  const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: { user }, error: userError } = await caller.auth.getUser(token);
  if (userError || !user) return reply({ error: 'Session is invalid or expired.' }, 401);
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply({ error: 'Invalid JSON body.' }, 400); }
  const clinicId = String(body.clinic_id || ''), staffProfileId = String(body.staff_profile_id || '').trim(), fullName = String(body.full_name || '').trim(), email = String(body.email || '').trim().toLowerCase(), phone = String(body.phone || '').trim(), username = String(body.username || '').trim().toLowerCase(), loginId = String(body.login_id || '').trim(), password = String(body.password || ''), role = String(body.role || 'staff');
  const allowed = ['doctor','receptionist','nurse','pharmacist','lab_technician','radiology_technician','xray_technician','ultrasound_technician','ct_mri_technician','accountant','staff'];
  if (!/^[0-9a-f-]{36}$/i.test(clinicId)) return reply({ error: 'Select a valid clinic.' }, 400);
  if (fullName.length < 2 || fullName.length > 160) return reply({ error: 'Name must be 2–160 characters.' }, 400);
  if (email && (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254)) return reply({ error: 'Enter a valid contact email or leave it blank.' }, 400);
  if (password.length < 8 || password.length > 128) return reply({ error: 'Set a password of 8–128 characters.' }, 400);
  if (!loginId || loginId.length > 254) return reply({ error: 'Enter a login ID (email, phone or username).' }, 400);
  if (username && !/^[a-z0-9._-]{3,40}$/.test(username)) return reply({ error: 'Username must be 3–40 characters using letters, numbers, dot, underscore or hyphen.' }, 400);
  const isEmailLogin = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(loginId);
  const isPhoneLogin = /^\+?[0-9 ()-]{7,20}$/.test(loginId) && loginId.replace(/\D/g, '').length >= 7;
  const normalizedUsername = (username || (!isEmailLogin && !isPhoneLogin ? loginId : '')).toLowerCase();
  if (normalizedUsername && !/^[a-z0-9._-]{3,40}$/.test(normalizedUsername)) return reply({ error: 'Username must be 3–40 characters using letters, numbers, dot, underscore or hyphen.' }, 400);
  if (!isEmailLogin && !isPhoneLogin && !normalizedUsername) return reply({ error: 'Login ID must be an email, phone number or username.' }, 400);
  const phoneDigits = (isPhoneLogin ? loginId : phone).replace(/\D/g, '');
  const authEmail = isEmailLogin ? loginId.toLowerCase() : isPhoneLogin ? `login-phone-${phoneDigits}@staff.anaira.invalid` : `login-user-${normalizedUsername}@staff.anaira.invalid`;
  if (!email && !phone && !username && !isEmailLogin && !isPhoneLogin) return reply({ error: 'Provide a contact phone, email or username.' }, 400);
  if (!allowed.includes(role)) return reply({ error: 'Unsupported staff role.' }, 400);
  const { data: membership, error: memberError } = await caller.from('clinic_members').select('role,active').eq('clinic_id', clinicId).eq('user_id', user.id).eq('active', true).maybeSingle();
  if (memberError || !membership || !['owner','admin'].includes(membership.role)) return reply({ error: 'Only this clinic owner/admin can create staff accounts.' }, 403);
  const { data: clinic } = await caller.from('clinics').select('id,platform_status').eq('id', clinicId).maybeSingle();
  if (!clinic || clinic.platform_status === 'suspended') return reply({ error: 'Clinic is unavailable or suspended.' }, 403);
  const { data: created, error: createError } = await admin.auth.admin.createUser({ email: authEmail, password, email_confirm: true, user_metadata: { display_name: fullName, clinic_id: clinicId, clinic_role: role, login_id: loginId } });
  if (createError || !created.user) return reply({ error: createError?.message || 'Could not create login.' }, 409);
  const uid = created.user.id;
  const { error: linkError } = await admin.from('clinic_members').insert({ clinic_id: clinicId, user_id: uid, role, display_name: fullName, active: true });
  if (linkError) { await admin.auth.admin.deleteUser(uid); return reply({ error: `Could not assign clinic role: ${linkError.message}` }, 400); }
  let profileError: { message: string } | null = null;
  if (staffProfileId) {
    // Link a previously saved doctor profile instead of creating a duplicate profile.
    const { data: existingProfile, error: existingError } = await admin.from('staff_profiles').select('id,user_id,role,metadata').eq('id', staffProfileId).eq('clinic_id', clinicId).maybeSingle();
    if (existingError || !existingProfile || existingProfile.role !== 'doctor' || existingProfile.user_id) {
      await admin.from('clinic_members').delete().eq('clinic_id', clinicId).eq('user_id', uid);
      await admin.auth.admin.deleteUser(uid);
      return reply({ error: existingError?.message || 'Doctor profile was not found, is not a doctor, or already has a login.' }, 409);
    }
    const mergedMetadata = { ...(existingProfile.metadata || {}), created_by: user.id, invite_sent: false, password_set_by_admin: true, login_id_type: isEmailLogin ? 'email' : isPhoneLogin ? 'phone' : 'username', department: String(body.department || '').trim() || (existingProfile.metadata || {}).department || null, diagnostic_modality: String(body.diagnostic_modality || '').trim() || null, medical_registration_number: String(body.registration_number || '').trim() || null };
    const { error } = await admin.from('staff_profiles').update({ user_id: uid, email: email || (isEmailLogin ? loginId : null), phone: phone || (isPhoneLogin ? loginId : null), username: normalizedUsername || null, metadata: mergedMetadata }).eq('id', staffProfileId).eq('clinic_id', clinicId).is('user_id', null);
    profileError = error;
  } else {
    const { error } = await admin.from('staff_profiles').insert({ clinic_id: clinicId, user_id: uid, full_name: fullName, role, email: email || (isEmailLogin ? loginId : null), phone: phone || (isPhoneLogin ? loginId : null), username: normalizedUsername || null, staff_code: String(body.staff_code || '').trim() || null, specialty: String(body.specialty || '').trim() || null, room_number: String(body.room_number || '').trim() || null, active: true, metadata: { created_by: user.id, invite_sent: false, password_set_by_admin: true, login_id_type: isEmailLogin ? 'email' : isPhoneLogin ? 'phone' : 'username', department: String(body.department || '').trim() || null, diagnostic_modality: String(body.diagnostic_modality || '').trim() || null, medical_registration_number: String(body.registration_number || '').trim() || null } });
    profileError = error;
  }
  if (profileError) { await admin.from('clinic_members').delete().eq('clinic_id', clinicId).eq('user_id', uid); await admin.auth.admin.deleteUser(uid); return reply({ error: `Could not link/create staff profile: ${profileError.message}` }, 400); }
  await admin.from('audit_logs').insert({ clinic_id: clinicId, actor_user_id: user.id, action: 'create_staff_login', entity_type: 'staff_profile', entity_id: uid, details: { staff_email: email || null, login_id: loginId, role, department: String(body.department || '').trim() || null, diagnostic_modality: String(body.diagnostic_modality || '').trim() || null } });
  return reply({ user_id: uid, email: email || null, phone: phone || (isPhoneLogin ? loginId : null), username: normalizedUsername || null, login_id: loginId, auth_email: authEmail, role, clinic_id: clinicId, status: 'created', invite_sent: false, password_set_by_admin: true }, 201);
});
