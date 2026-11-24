import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

// Recovery is deliberately limited to the one Anaira Healthcare platform
// administrator and to unverified TOTP factors only. Never expose the
// service-role key to the browser.
const RECOVERY_USER_ID = '198137fa-8682-432f-8b7a-e99aebe89ddd';
const RECOVERY_EMAIL = 'techanaira@gmail.com';
const FRIENDLY_NAME = 'Anaira Healthcare Authenticator';

export async function POST(request: NextRequest) {
  const authorization = request.headers.get('authorization') || '';
  const token = authorization.startsWith('Bearer ') ? authorization.slice(7).trim() : '';
  if (!token) return NextResponse.json({ error: 'A signed-in session is required.' }, { status: 401 });

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SECRET_KEY;
  if (!url || !anonKey || !serviceRoleKey) {
    return NextResponse.json({
      error: 'MFA recovery is not configured on the server. Add SUPABASE_SERVICE_ROLE_KEY as a Vercel server-only environment variable.'
    }, { status: 503 });
  }

  const authClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
  });
  const { data: verified, error: authError } = await authClient.auth.getUser(token);
  if (authError || !verified.user) return NextResponse.json({ error: 'Your login session is invalid. Sign in again.' }, { status: 401 });

  if (verified.user.id !== RECOVERY_USER_ID || verified.user.email?.toLowerCase() !== RECOVERY_EMAIL) {
    return NextResponse.json({ error: 'This recovery action is not enabled for this account.' }, { status: 403 });
  }

  const admin = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
  });
  const { data: listed, error: listError } = await admin.auth.admin.mfa.listFactors({ userId: RECOVERY_USER_ID });
  if (listError) return NextResponse.json({ error: `Could not inspect MFA factors: ${listError.message}` }, { status: 502 });

  const pending = (listed?.factors || []).filter((factor) =>
    factor.factor_type === 'totp' &&
    factor.status === 'unverified' &&
    factor.friendly_name === FRIENDLY_NAME
  );

  const removed: string[] = [];
  for (const factor of pending) {
    const { error: deleteError } = await admin.auth.admin.mfa.deleteFactor({
      userId: RECOVERY_USER_ID,
      id: factor.id
    });
    if (deleteError) {
      return NextResponse.json({ error: `Could not clear incomplete MFA setup: ${deleteError.message}` }, { status: 502 });
    }
    removed.push(factor.id);
  }

  return NextResponse.json({ ok: true, removedCount: removed.length });
}
