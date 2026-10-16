# parcel-vertices-api (Cloudflare Worker)

Accounts, credits and the paywall for coordinates. Cadastre lookups happen here, so the app never gets exact vertices before a parcel is unlocked (and the browser CORS problem with maps.gov.ge disappears).

## Local run
```bash
npm install
npm run db:local        # apply migrations to the local D1
npm run dev             # http://localhost:8787
npm run check           # type-check
```

## API (Bearer token from /auth/*)
| Method | Path | Notes |
|---|---|---|
| POST | /auth/register, /auth/login, /auth/logout | email + password (min 8) |
| GET | /me | email, credit balance |
| GET | /products | prices (tetri), demo codes |
| GET | /parcels/:code | free preview: address, vertex count, coarse bbox |
| POST | /parcels/:code/unlock | demo codes free; otherwise 1 credit, charged once per user and parcel; returns WKT |
| POST | /orders `{product_id}` | returns `checkout_url` |
| GET | /orders/:id | status + balance (app polls this) |
| POST | /webhooks/:provider | gateway callback; only this marks orders paid |

Prices live in `src/products.ts`. Credits are an append-only ledger (`credit_ledger`); unique indexes make unlocks and order fulfilment idempotent.

## Adding a payment gateway (Flitt / Keepz)
Implement `PaymentProvider` in `src/payments.ts` (`createCheckout`, `verifyWebhook` with signature check) and register it in `getProvider()`. Store gateway secrets with `wrangler secret put`, never in `wrangler.jsonc`.

## Deploy (needs your Cloudflare account)
```bash
npx wrangler login
npx wrangler d1 create parcel-vertices       # put the returned id into wrangler.jsonc
npx wrangler d1 migrations apply parcel-vertices --remote
# set PUBLIC_BASE_URL, PAYMENT_PROVIDER, ALLOWED_ORIGINS in wrangler.jsonc
npx wrangler deploy
```
Production runs with `PAYMENT_PROVIDER=disabled` (orders return 503). Never deploy with `mock`: it lets anyone credit themselves. For local testing put `PAYMENT_PROVIDER=mock` in `worker/.dev.vars` (gitignored).
