const ITERATIONS = 100_000; // Workers' PBKDF2 maximum
const SESSION_DAYS = 90;

const enc = new TextEncoder();

function toHex(buf: ArrayBuffer | Uint8Array): string {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}
function fromHex(h: string): Uint8Array {
  return Uint8Array.from(h.match(/../g) ?? [], (b) => parseInt(b, 16));
}

async function pbkdf2(password: string, salt: Uint8Array): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt, iterations: ITERATIONS }, key, 256);
  return new Uint8Array(bits);
}

export async function hashPassword(password: string): Promise<{ salt: string; hash: string }> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  return { salt: toHex(salt), hash: toHex(await pbkdf2(password, salt)) };
}

export async function verifyPassword(password: string, saltHex: string, hashHex: string): Promise<boolean> {
  const actual = await pbkdf2(password, fromHex(saltHex));
  const expected = fromHex(hashHex);
  return actual.byteLength === expected.byteLength && crypto.subtle.timingSafeEqual(actual, expected);
}

async function sha256Hex(s: string): Promise<string> {
  return toHex(await crypto.subtle.digest('SHA-256', enc.encode(s)));
}

/** Creates a session; only the SHA-256 of the token is stored. */
export async function createSession(db: D1Database, userId: string): Promise<string> {
  const token = toHex(crypto.getRandomValues(new Uint8Array(32)));
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
