-- Google-only sign-in. Legacy password columns stay (non-destructive) but are no longer used.
ALTER TABLE users ADD COLUMN google_sub TEXT;
ALTER TABLE users ADD COLUMN name TEXT;
CREATE UNIQUE INDEX users_google_sub ON users(google_sub) WHERE google_sub IS NOT NULL;

-- One row per "Sign in with Google" attempt started by the app (polled by the app, completed by the browser callback).
CREATE TABLE login_attempts (
  id TEXT PRIMARY KEY,
  secret_hash TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- pending | done | denied | failed
  user_id TEXT,
  expires_at INTEGER NOT NULL
);
