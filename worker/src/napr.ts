/** Server-side port of the maps.gov.ge client (see app lib/napr_client.dart). */
const SEARCH = 'https://maps.gov.ge/map/portal/search';
const GETINFO = 'https://maps.gov.ge/lr/bo/mg/getinfo.alpha';
const HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124 Safari/537.36',
  Accept: 'application/json, text/plain, */*',
  Referer: 'https://maps.gov.ge/map/portal/',
};

export class NaprError extends Error {
  constructor(public key: 'err_not_found' | 'err_denied' | 'err_network' | 'err_no_geom', detail = '') {
    super(detail ? `${key}: ${detail}` : key);
  }
}

export interface Parcel {
  code: string;
  address: string;
  wkt: string;
}

async function text(url: string, form?: Record<string, string>): Promise<string> {
  let res: Response;
  try {
    res = await fetch(url, {
      method: form ? 'POST' : 'GET',
      headers: form ? { ...HEADERS, 'Content-Type': 'application/x-www-form-urlencoded' } : HEADERS,
      body: form ? new URLSearchParams(form).toString() : undefined,
      signal: AbortSignal.timeout(20_000),
    });
  } catch (e) {
    throw new NaprError('err_network', String(e));
  }
  const t = await res.text();
  const head = t.trimStart().slice(0, 400).toLowerCase();
  if (head.includes('<html') && (head.includes('access denied') || head.includes('oops') || head.includes('not be accessed'))) {
    throw new NaprError('err_denied');
  }
  return t;
}

export async function lookupParcel(code: string): Promise<Parcel> {
  const search = JSON.parse(await text(SEARCH, { keyword: code, keyword_description: '' })) as {
    result?: Array<Record<string, unknown>>;
  };
  const results = search.result ?? [];
  let lbl: string | null = null;
  let name = code;
  let address = '';
  for (const r of results) {
    for (const k of ['resultlink', 'details']) {
      let v = r[k] as unknown;
      if (v && typeof v === 'object') {
        const o = v as Record<string, string>;
        v = o.info_link ?? o.geometry_link ?? '';
      }
      if (typeof v === 'string' && v.includes('lbl=')) {
        const cand = v.split('lbl=')[1].split('&')[0];
        if (!lbl || r.name === code) {
          lbl = cand;
          name = String(r.name ?? code);
          address = String(r.descript ?? r.resulttext ?? '');
        }
        break;
      }
    }
    if (lbl && name === code) break;
  }
  if (!lbl) throw new NaprError('err_not_found');

  // The ':' in lbl must stay literal; percent-encoding breaks the service.
  const info = JSON.parse(await text(`${GETINFO}?lbl=${lbl}&lang=ka&res=shp`)) as {
    data?: Array<{ shape?: string }>;
  };
  const wkt = info.data?.find((r) => r.shape)?.shape;
  if (!wkt) throw new NaprError('err_no_geom');
  return { code: name, address, wkt };
}

/** Counts distinct vertices across all rings (closing point of each ring excluded). */
export function countVertices(wkt: string): number {
  let n = 0;
  for (const m of wkt.matchAll(/\(([^()]+)\)/g)) {
    const pts = m[1].split(',').map((p) => p.trim()).filter(Boolean);
    n += pts.length > 1 && pts[0] === pts[pts.length - 1] ? pts.length - 1 : pts.length;
  }
  return n;
}

/** Coarse bounding box (rounded outward to ~100 m) so the free preview can't leak vertex coordinates. */
export function coarseBbox(wkt: string): [number, number, number, number] {
  const nums = [...wkt.matchAll(/(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)/g)].map((m) => [Number(m[1]), Number(m[2])]);
  const lons = nums.map((p) => p[0]);
  const lats = nums.map((p) => p[1]);
  const f = 1000;
  return [
    Math.floor(Math.min(...lons) * f) / f,
    Math.floor(Math.min(...lats) * f) / f,
    Math.ceil(Math.max(...lons) * f) / f,
    Math.ceil(Math.max(...lats) * f) / f,
  ];
}
