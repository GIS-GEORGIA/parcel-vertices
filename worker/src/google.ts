import { randomHex, sha256Hex, upsertGoogleUser, createSession } from './auth';

const nowSec = () => Math.floor(Date.now() / 1000);
const esc = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

function page(message: string, status = 200): Response {
  return new Response(
    `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Parcel Vertices</title>
     <body style="font-family:system-ui;max-width:28rem;margin:4rem auto;padding:0 1rem"><h2>Parcel Vertices</h2><p>${message}</p>`,
    { status, headers: { 'Content-Type': 'text/html; charset=utf-8' } },
  );
}

/** Step 1 (called by the app): create an attempt and return the Google URL to open in a browser. */
export async function begin(env: Env): Promise<{ attempt_id: string; poll_secret: string; url: string }> {
  const id = crypto.randomUUID();
  const secret = randomHex(32);
  const t = nowSec();
  await env.DB.batch([
    env.DB.prepare('DELETE FROM login_attempts WHERE expires_at < ?').bind(t),
    env.DB.prepare('INSERT INTO login_attempts (id, secret_hash, expires_at) VALUES (?, ?, ?)').bind(
      id,
      await sha256Hex(secret),
      t + 600,
    ),
  ]);
  const params = new URLSearchParams({
    client_id: env.GOOGLE_CLIENT_ID,
    redirect_uri: `${env.PUBLIC_BASE_URL}/auth/google/callback`,
    response_type: 'code',
    scope: 'openid email profile',
    state: id,
    prompt: 'select_account',
  });
  return { attempt_id: id, poll_secret: secret, url: `https://accounts.google.com/o/oauth2/v2/auth?${params}` };
}

/** Step 2 (browser redirect from Google): verify the code, find/create the user, mark the attempt done. */
export async function callback(url: URL, env: Env): Promise<Response> {
  const state = url.searchParams.get('state') ?? '';
  const attempt = await env.DB.prepare("SELECT id FROM login_attempts WHERE id = ? AND status = 'pending' AND expires_at > ?")
    .bind(state, nowSec())
    .first();
  if (!attempt) return page('This sign-in link has expired. Start again in the app.', 400);
  const mark = (status: string, userId: string | null = null) =>
    env.DB.prepare('UPDATE login_attempts SET status = ?, user_id = ? WHERE id = ?').bind(status, userId, state).run();

  const code = url.searchParams.get('code');
  if (url.searchParams.get('error') || !code) {
    await mark('denied');
    return page('Sign-in was cancelled. You can close this page.');
  }
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: env.GOOGLE_CLIENT_ID,
      client_secret: env.GOOGLE_CLIENT_SECRET,
      redirect_uri: `${env.PUBLIC_BASE_URL}/auth/google/callback`,
      grant_type: 'authorization_code',
    }),
  });
  if (!res.ok) {
    console.error(JSON.stringify({ msg: 'google_token_failed', status: res.status }));
    await mark('failed');
    return page('Google sign-in failed. Please try again.', 502);
  }
  // The ID token comes straight from Google's token endpoint over TLS, so its claims are trusted after these checks.
  const { id_token } = (await res.json()) as { id_token?: string };
  let claims: { aud?: string; iss?: string; exp?: number; sub?: string; email?: string; email_verified?: boolean; name?: string };
  try {
    const b64 = (id_token ?? '').split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    claims = JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    await mark('failed');
    return page('Google sign-in failed. Please try again.', 502);
  }
  const ok =
    claims.aud === env.GOOGLE_CLIENT_ID &&
    (claims.iss === 'https://accounts.google.com' || claims.iss === 'accounts.google.com') &&
    (claims.exp ?? 0) > nowSec() &&
    claims.email_verified === true &&
    !!claims.sub &&
    !!claims.email;
  if (!ok) {
    await mark('failed');
    return page('Google account could not be verified.', 400);
  }
  const uid = await upsertGoogleUser(env.DB, { sub: claims.sub!, email: claims.email!, name: claims.name });
  await mark('done', uid);
  return page(
    `Signed in as <b>${esc(claims.email!)}</b>. Return to the app; you can close this page.<br><small>If you did not start this sign-in, just close the page.</small>`,
  );
}

/** Step 3 (polled by the app): hand out a session exactly once. */
export async function poll(env: Env, attemptId: string, secret: string): Promise<{ status: string; token?: string } | null> {
  const row = await env.DB.prepare('SELECT secret_hash, status, user_id FROM login_attempts WHERE id = ? AND expires_at > ?')
    .bind(attemptId, nowSec())
    .first<{ secret_hash: string; status: string; user_id: string | null }>();
  if (!row || row.secret_hash !== (await sha256Hex(secret))) return null;
  if (row.status === 'pending') return { status: 'pending' };
  // Only the request that deletes the row gets a session.
  const del = await env.DB.prepare('DELETE FROM login_attempts WHERE id = ?').bind(attemptId).run();
  if (row.status !== 'done' || !row.user_id || del.meta.changes !== 1) {
    return { status: row.status === 'done' ? 'failed' : row.status };
  }
  return { status: 'ok', token: await createSession(env.DB, row.user_id) };
}
