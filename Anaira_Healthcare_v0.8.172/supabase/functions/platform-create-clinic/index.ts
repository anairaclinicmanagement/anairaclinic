import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function respond(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return respond({ error: 'Method not allowed' }, 405);

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const authorization = req.headers.get('Authorization');
  if (!url || !anonKey || !serviceRoleKey) {
    return respond({ error: 'Server provisioning secrets are not configured.' }, 500);
  }
  if (!authorization?.startsWith('Bearer ')) return respond({ error: 'Authentication required.' }, 401);

  const token = authorization.slice('Bearer '.length);
  const caller = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const admin = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await caller.auth.getUser(token);
  if (userError || !userData.user) return respond({ error: 'Invalid or expired Super Admin session.' }, 401);
  const { data: platformAdmin, error: adminCheckError } = await admin
    .from('platform_admins').select('active').eq('user_id', userData.user.id).eq('active', true).maybeSingle();
  if (adminCheckError || !platformAdmin?.active) return respond({ error: 'Platform Super Admin permission required.' }, 403);

  let input: Record<string, unknown>;
  try { input = await req.json(); } catch { return respond({ error: 'Invalid JSON body.' }, 400); }
  const name = typeof input.name === 'string' ? input.name.trim() : '';
  const clinicType = typeof input.clinic_type === 'string' ? input.clinic_type : '';
  const email = typeof input.owner_email === 'string' ? input.owner_email.trim().toLowerCase() : '';
  const phone = typeof input.phone === 'string' ? input.phone.trim() : null;
  const password = typeof input.password === 'string' ? input.password : '';
  const allowedTypes = [
    'general_opd','general_medicine','dental','orthodontics','oral_surgery','periodontics','prosthodontics',
    'eye','ophthalmology','optometry','skin','dermatology','cosmetology','pediatrics','neonatology',
    'gynecology','obstetrics','fertility','orthopedic','sports_medicine','physiotherapy','neurology',
    'cardiology','diabetology','endocrinology','gastroenterology','pulmonology','nephrology','urology',
    'ENT','ent','psychiatry','psychology','oncology','rheumatology','geriatrics','pain_management',
    'ayurveda','homeopathy','unani','siddha','naturopathy','diagnostic_lab','radiology_centre',
    'pathology_lab','imaging_centre','dialysis_centre','vaccination_centre','urgent_care','polyclinic',
    'nursing_home','maternity_home','day_care_centre','rehabilitation_centre','fertility_centre',
    'eye_hospital','dental_hospital','hospital','multi_specialty_hospital','super_specialty_hospital','other'
  ];
  if (name.length < 2 || name.length > 160) return respond({ error: 'Clinic name must contain 2 to 160 characters.' }, 400);
  if (!allowedTypes.includes(clinicType)) return respond({ error: 'Unsupported clinic type.' }, 400);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) return respond({ error: 'Enter a valid owner email address.' }, 400);
  if (password.length < 8 || password.length > 128) return respond({ error: 'Password must be between 8 and 128 characters.' }, 400);

  // Prevent duplicate accounts: the password is only used by Supabase Auth and never written to app tables/logs.
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { display_name: email, provisioned_by_platform_admin: userData.user.id, require_password_change: true },
  });
  if (createError || !created.user) {
    const duplicate = /already|exists|registered/i.test(createError?.message || '');
    return respond({ error: duplicate ? 'This email already has an account. Use a different email or implement a separate secure password-reset flow.' : (createError?.message || 'Could not create the owner login.') }, duplicate ? 409 : 400);
  }

  // Call the clinic provisioning RPC with the caller's JWT so auth.uid() and the DB-side platform-admin guard remain effective.
  const { data: result, error: provisionError } = await caller.rpc('platform_admin_create_clinic', {
    p_name: name,
    p_clinic_type: clinicType,
    p_owner_email: email,
    p_phone: phone || null,
  });
  if (provisionError || !result) {
    // Compensate for the newly created Auth user if the tenant transaction fails.
    const { error: rollbackError } = await admin.auth.admin.deleteUser(created.user.id);
    return respond({ error: provisionError?.message || 'Clinic provisioning failed.', rollback_warning: rollbackError?.message || undefined }, 400);
  }

  return respond({ clinic_id: result.clinic_id, owner_user_id: created.user.id, owner_email: email, status: 'created' }, 201);
});
