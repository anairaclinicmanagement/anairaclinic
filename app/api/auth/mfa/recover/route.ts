import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const FRIENDLY_NAME = 'Anaira Healthcare Authenticator';

// Authenticated self-service recovery: the bearer token determines which
// Auth user can be inspected. The client cannot submit another user's ID.
// Only this application's own unverified TOTP factor is eligible for removal.
export async function POST(request: NextRequest) {
  const authorization = request.headers.get('authorization') || '';
  const token = authorization.startsWith('Bearer ') ? authorization.slice(7).trim() : '';
  if (!token) return NextResponse.json({ error: 'A signed-in session is required.' }, { status: 401 });

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SECRET_KEY;
  if (!url || !anonKey || !serviceRoleKey) {
    return NextResponse.json({
      error: 'MFA recovery is not configured. Add SUPABASE_SERVICE_ROLE_KEY as a server-only Vercel environment variable, then redeploy.'
    }, { status: 503 });
  }

  const authClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
  });
  const { data: verified, error: authError } = await authClient.auth.getUser(token);
  if (authError || !verified.user) {
    return NextResponse.json({ error: 'Your login session is invalid. Sign in again.' }, { status: 401 });
  }

  const userId = verified.user.id;
  const admin = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
  });
  const { data: listed, error: listError } = await admin.auth.admin.mfa.listFactors({ userId });
  if (listError) {
    return NextResponse.json({ error: `Could not inspect your MFA factors: ${listError.message}` }, { status: 502 });
  }

  const pending = (listed?.factors || []).filter((factor) =>
    factor.factor_type === 'totp' &&
    factor.status === 'unverified' &&
    factor.friendly_name === FRIENDLY_NAME
  );

  const removed: string[] = [];
  for (const factor of pending) {
    const { error: deleteError } = await admin.auth.admin.mfa.deleteFactor({ userId, id: factor.id });
    if (deleteError) {
      return NextResponse.json({ error: `Could not clear your incomplete Anaira Healthcare authenticator setup: ${deleteError.message}` }, { status: 502 });
    }
    removed.push(factor.id);
  }

  return NextResponse.json({ ok: true, removedCount: removed.length });
}
