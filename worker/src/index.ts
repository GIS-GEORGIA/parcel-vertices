import { createSession, deleteSession, hashPassword, userFromRequest, verifyPassword } from './auth';
import { NaprError, coarseBbox, countVertices, lookupParcel } from './napr';
import { getProvider } from './payments';
import { DEMO_CODES, PRODUCTS } from './products';

class HttpError extends Error {
  constructor(public status: number, public key: string, public detail?: unknown) {
    super(key);
  }
}

const nowSec = () => Math.floor(Date.now() / 1000);
const CODE_RE = /^[0-9][0-9.]{3,28}[0-9]$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });
}

async function body<T>(request: Request): Promise<T> {
  try {
    return (await request.json()) as T;
  } catch {
    throw new HttpError(400, 'bad_json');
  }
}

async function requireUser(env: Env, request: Request): Promise<string> {
  const id = await userFromRequest(env.DB, request);
  if (!id) throw new HttpError(401, 'unauthorized');
  return id;
}

async function balanceOf(env: Env, userId: string): Promise<number> {
  const r = await env.DB.prepare('SELECT COALESCE(SUM(delta), 0) AS b FROM credit_ledger WHERE user_id = ?')
    .bind(userId)
    .first<{ b: number }>();
  return r?.b ?? 0;
}

async function loadParcel(codeRaw: string) {
  const code = decodeURIComponent(codeRaw).trim();
  if (!CODE_RE.test(code)) throw new HttpError(400, 'err_bad_code');
  try {
    return await lookupParcel(code);
  } catch (e) {
    if (e instanceof NaprError) throw new HttpError(e.key === 'err_not_found' ? 404 : 502, e.key);
    throw e;
  }
}

/** Idempotent: credits an order exactly once (unique index on the ledger enforces it). */
async function fulfill(env: Env, orderId: string): Promise<boolean> {
  const o = await env.DB.prepare('SELECT user_id, credits FROM orders WHERE id = ?')
    .bind(orderId)
    .first<{ user_id: string; credits: number }>();
  if (!o) return false;
  const t = nowSec();
  await env.DB.batch([
    env.DB.prepare(
      "INSERT OR IGNORE INTO credit_ledger (user_id, delta, reason, ref, created_at) VALUES (?, ?, 'purchase', ?, ?)",
    ).bind(o.user_id, o.credits, orderId, t),
    env.DB.prepare("UPDATE orders SET status = 'paid', paid_at = ? WHERE id = ? AND status != 'paid'").bind(t, orderId),
  ]);
  return true;
}

async function route(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname;
  const method = request.method;

  if (method === 'GET' && path === '/health') return json({ ok: true });

  // ---- auth ----
  if (method === 'POST' && path === '/auth/register') {
    const { email, password } = await body<{ email?: string; password?: string }>(request);
    const e = (email ?? '').trim().toLowerCase();
    if (!EMAIL_RE.test(e) || e.length > 254) throw new HttpError(400, 'err_bad_email');
    if (!password || password.length < 8 || password.length > 200) throw new HttpError(400, 'err_weak_password');
    const id = crypto.randomUUID();
    const { salt, hash } = await hashPassword(password);
    try {
      await env.DB.prepare('INSERT INTO users (id, email, pass_salt, pass_hash, created_at) VALUES (?, ?, ?, ?, ?)')
        .bind(id, e, salt, hash, nowSec())
        .run();
    } catch (err) {
      if (String(err).includes('UNIQUE')) throw new HttpError(409, 'err_email_taken');
      throw err;
    }
    return json({ token: await createSession(env.DB, id), email: e }, 201);
  }

  if (method === 'POST' && path === '/auth/login') {
    const { email, password } = await body<{ email?: string; password?: string }>(request);
    const u = await env.DB.prepare('SELECT id, pass_salt, pass_hash FROM users WHERE email = ?')
      .bind((email ?? '').trim().toLowerCase())
      .first<{ id: string; pass_salt: string; pass_hash: string }>();
    // Same error and similar work for unknown email / wrong password.
    const ok = u ? await verifyPassword(password ?? '', u.pass_salt, u.pass_hash) : false;
    if (!u || !ok) throw new HttpError(401, 'err_bad_credentials');
    return json({ token: await createSession(env.DB, u.id) });
  }

  if (method === 'POST' && path === '/auth/logout') {
    await deleteSession(env.DB, request);
    return json({ ok: true });
  }

  // ---- account ----
  if (method === 'GET' && path === '/me') {
    const uid = await requireUser(env, request);
    const u = await env.DB.prepare('SELECT email FROM users WHERE id = ?').bind(uid).first<{ email: string }>();
    return json({ email: u?.email, balance: await balanceOf(env, uid) });
  }

  if (method === 'GET' && path === '/products') {
    return json({ currency: 'GEL', demo_codes: DEMO_CODES, products: PRODUCTS });
  }

  // ---- parcels ----
  let m = /^\/parcels\/([^/]+)$/.exec(path);
  if (method === 'GET' && m) {
    // Free preview: no exact coordinates (coarse bbox only).
    const uid = await requireUser(env, request);
    const p = await loadParcel(m[1]);
    const unlocked = await env.DB.prepare("SELECT 1 FROM credit_ledger WHERE user_id = ? AND reason = 'unlock' AND ref = ?")
      .bind(uid, p.code)
      .first();
    return json({
      code: p.code,
      address: p.address,
      vertices: countVertices(p.wkt),
      bbox: coarseBbox(p.wkt),
      demo: DEMO_CODES.includes(p.code),
      unlocked: !!unlocked,
      cost: 1,
    });
  }

  m = /^\/parcels\/([^/]+)\/unlock$/.exec(path);
  if (method === 'POST' && m) {
    const uid = await requireUser(env, request);
    // Fetch first so a failed lookup never costs a credit.
    const p = await loadParcel(m[1]);
    const already = await env.DB.prepare("SELECT 1 FROM credit_ledger WHERE user_id = ? AND reason = 'unlock' AND ref = ?")
      .bind(uid, p.code)
      .first();
    if (!already) {
      const t = nowSec();
      if (DEMO_CODES.includes(p.code)) {
        await env.DB.prepare("INSERT OR IGNORE INTO credit_ledger (user_id, delta, reason, ref, created_at) VALUES (?, 0, 'unlock', ?, ?)")
          .bind(uid, p.code, t)
          .run();
      } else {
        // Atomic check-and-spend in one statement; the unique index prevents double charging.
        const r = await env.DB.prepare(
          `INSERT OR IGNORE INTO credit_ledger (user_id, delta, reason, ref, created_at)
           SELECT ?1, -1, 'unlock', ?2, ?3
           WHERE (SELECT COALESCE(SUM(delta), 0) FROM credit_ledger WHERE user_id = ?1) >= 1`,
        )
          .bind(uid, p.code, t)
          .run();
        if (r.meta.changes === 0) throw new HttpError(402, 'err_no_credits');
      }
    }
    return json({ code: p.code, address: p.address, wkt: p.wkt, balance: await balanceOf(env, uid) });
  }

  // ---- orders ----
  if (method === 'POST' && path === '/orders') {
    const uid = await requireUser(env, request);
    const { product_id } = await body<{ product_id?: string }>(request);
    const product = PRODUCTS.find((p) => p.id === product_id);
    if (!product) throw new HttpError(400, 'err_bad_product');
    const provider = getProvider(env);
    const id = crypto.randomUUID();
    const order = { id, amountTetri: product.amountTetri, currency: 'GEL', productId: product.id };
    const { checkoutUrl, providerRef } = await provider.createCheckout(order, env);
    await env.DB.prepare(
      `INSERT INTO orders (id, user_id, product_id, credits, amount_tetri, currency, status, provider, provider_ref, created_at)
       VALUES (?, ?, ?, ?, ?, 'GEL', 'pending', ?, ?, ?)`,
    )
      .bind(id, uid, product.id, product.credits, product.amountTetri, provider.name, providerRef, nowSec())
      .run();
    return json({ order_id: id, checkout_url: checkoutUrl }, 201);
  }

  m = /^\/orders\/([0-9a-f-]{36})$/.exec(path);
  if (method === 'GET' && m) {
    const uid = await requireUser(env, request);
    const o = await env.DB.prepare('SELECT status, credits FROM orders WHERE id = ? AND user_id = ?')
      .bind(m[1], uid)
      .first<{ status: string; credits: number }>();
    if (!o) throw new HttpError(404, 'not_found');
    return json({ ...o, balance: await balanceOf(env, uid) });
  }

  // ---- payment gateway webhook ----
  m = /^\/webhooks\/([a-z]+)$/.exec(path);
  if (method === 'POST' && m) {
    const provider = getProvider(env);
    if (provider.name !== m[1]) throw new HttpError(404, 'not_found');
    const evt = await provider.verifyWebhook(request, env);
    if (!evt) throw new HttpError(400, 'invalid_webhook');
    if (evt.paid) await fulfill(env, evt.orderId);
    return json({ ok: true });
  }

  // ---- mock checkout (local testing only) ----
  m = /^\/mock\/pay\/([0-9a-f-]{36})$/.exec(path);
  if (m && env.PAYMENT_PROVIDER === 'mock') {
    if (method === 'GET') {
      return new Response(
        `<!doctype html><meta charset="utf-8"><title>Mock payment</title>
         <h2>Mock payment (test only)</h2>
         <form method="POST"><button>Pay</button></form>`,
        { headers: { 'Content-Type': 'text/html; charset=utf-8' } },
      );
    }
    if (method === 'POST') {
      const ok = await fulfill(env, m[1]);
      return new Response(ok ? 'Paid. You can return to the app.' : 'Unknown order', { status: ok ? 200 : 404 });
    }
  }

  throw new HttpError(404, 'not_found');
}

function corsHeaders(request: Request, env: Env): Record<string, string> {
  const origin = request.headers.get('Origin');
  const allowed = env.ALLOWED_ORIGINS.split(',').map((s) => s.trim());
  if (!origin || !allowed.includes(origin)) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    Vary: 'Origin',
  };
}

export default {
  async fetch(request, env): Promise<Response> {
    const cors = corsHeaders(request, env);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
    let res: Response;
    try {
      res = await route(request, env);
    } catch (e) {
      if (e instanceof HttpError) {
        res = json({ error: e.key, detail: e.detail }, e.status);
      } else {
        console.error(JSON.stringify({ msg: 'unhandled', error: String(e) }));
        res = json({ error: 'internal' }, 500);
      }
    }
    const out = new Response(res.body, res);
    for (const [k, v] of Object.entries(cors)) out.headers.set(k, v);
    return out;
  },
} satisfies ExportedHandler<Env>;
