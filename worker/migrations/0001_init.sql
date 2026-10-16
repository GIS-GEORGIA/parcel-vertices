-- Users and sessions
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  pass_salt TEXT NOT NULL,
  pass_hash TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  expires_at INTEGER NOT NULL
);
CREATE INDEX sessions_user ON sessions(user_id);

-- Append-only credit ledger. Balance = SUM(delta).
-- reason: 'purchase' (+N, ref = order id) | 'unlock' (-1, ref = parcel code) | 'grant'
CREATE TABLE credit_ledger (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL REFERENCES users(id),
  delta INTEGER NOT NULL,
  reason TEXT NOT NULL,
  ref TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX ledger_user ON credit_ledger(user_id);
-- A parcel is charged at most once per user; an order is credited at most once.
CREATE UNIQUE INDEX ledger_unlock_once ON credit_ledger(user_id, ref) WHERE reason = 'unlock';
CREATE UNIQUE INDEX ledger_purchase_once ON credit_ledger(ref) WHERE reason = 'purchase';

CREATE TABLE orders (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  product_id TEXT NOT NULL,
  credits INTEGER NOT NULL,
  amount_tetri INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'GEL',
  status TEXT NOT NULL DEFAULT 'pending', -- pending | paid | failed
  provider TEXT NOT NULL,
  provider_ref TEXT,
  created_at INTEGER NOT NULL,
  paid_at INTEGER
);
CREATE INDEX orders_user ON orders(user_id);
