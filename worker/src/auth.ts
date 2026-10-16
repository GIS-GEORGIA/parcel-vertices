const SESSION_DAYS = 90;
const enc = new TextEncoder();

export function randomHex(bytes: number): string {
  return [...crypto.getRandomValues(new Uint8Array(bytes))].map((b) => b.toString(16).padStart(2, '0')).join('');
}

export async function sha256Hex(s: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', enc.encode(s));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** Creates a session; only the SHA-256 of the token is stored. */
export async function createSession(db: D1Database, userId: string): Promise<string> {
  const token = randomHex(32);
  const expires = Math.floor(Date.now() / 1000) + SESSION_DAYS * 86400;
  await db
    .prepare('INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (?, ?, ?)')
    .bind(await sha256Hex(token), userId, expires)
    .run();
  return token;
}

export async function userFromRequest(db: D1Database, request: Request): Promise<string | null> {
  const m = /^Bearer ([0-9a-f]{64})$/.exec(request.headers.get('Authorization') ?? '');
  if (!m) return null;
  const row = await db
    .prepare('SELECT user_id FROM sessions WHERE token_hash = ? AND expires_at > ?')
    .bind(await sha256Hex(m[1]), Math.floor(Date.now() / 1000))
    .first<{ user_id: string }>();
  return row?.user_id ?? null;
}

export async function deleteSession(db: D1Database, request: Request): Promise<void> {
  const m = /^Bearer ([0-9a-f]{64})$/.exec(request.headers.get('Authorization') ?? '');
  if (m) await db.prepare('DELETE FROM sessions WHERE token_hash = ?').bind(await sha256Hex(m[1])).run();
}

/** Finds the user for a verified Google identity, linking an existing row by email or creating one. */
export async function upsertGoogleUser(
  db: D1Database,
  c: { sub: string; email: string; name?: string },
): Promise<string> {
  const email = c.email.trim().toLowerCase();
  const bySub = await db.prepare('SELECT id FROM users WHERE google_sub = ?').bind(c.sub).first<{ id: string }>();
  if (bySub) return bySub.id;
  // Safe to link by email: password login no longer exists, and Google verified the address.
  const byEmail = await db.prepare('SELECT id FROM users WHERE email = ?').bind(email).first<{ id: string }>();
  if (byEmail) {
    await db.prepare('UPDATE users SET google_sub = ?, name = ? WHERE id = ?').bind(c.sub, c.name ?? null, byEmail.id).run();
    return byEmail.id;
  }
  const id = crypto.randomUUID();
  await db
    .prepare("INSERT INTO users (id, email, pass_salt, pass_hash, google_sub, name, created_at) VALUES (?, ?, '', '', ?, ?, ?)")
    .bind(id, email, c.sub, c.name ?? null, Math.floor(Date.now() / 1000))
    .run();
  return id;
}
