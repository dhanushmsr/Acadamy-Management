# King SaaS — Backend (MongoDB / Beanie)

Parallel implementation of the same API, on MongoDB Atlas instead of
Postgres. Both backends are now kept in sync feature-for-feature; the
`backend/` (Postgres) folder is a separate, independently-running track,
not a replacement.

## The connection is already live
`app/core/config.py` has your real Atlas connection string hardcoded as
the default `mongodb_url` — no `.env` file is required for this to run.
Drop a `.env` later (see `.env.example`) to override it without editing
code.

**Before this works from anywhere other than your current machine**:
in Atlas → Network Access, your IP is whitelisted for *local*
connections only. Any server you deploy this to has a different IP and
will be refused until you either add that specific IP or, simpler for a
small live app, allow access from anywhere (0.0.0.0/0).

## What's ported and working
- `app/models.py` — the full schema (platform, roster, messaging,
  batches/classes/attendance, courses/lessons/assignments, puzzles,
  games/ratings, tournaments, payments, notifications), as Beanie
  documents. Four entities are embedded in a parent instead of getting
  their own collection (BroadcastRecipient, Lesson, GameReview,
  TournamentRegistration) — the reasoning for each is in the file's
  docstring.
- `auth.py`, `academies.py` (+ student counts), `users.py`, `team.py`
  (academy admins adding their own coaches), `students.py` (full CRUD),
  `batches.py`, `payments.py` (mark-paid triggers the receipt email) —
  same endpoints, same permissions, same JSON response shapes as
  Postgres. The Flutter app talks to either backend with zero changes.
- `app/integrations/email.py` — identical to the Postgres version, one
  shared invoice template with every academy's branding passed in
  dynamically at send time. See `app/routers/payments.py` for how it's
  called.
- `app/db.py` — Motor client + Beanie startup, wired into `main.py`'s
  lifespan hook.

## What's next (same gap on both backends now)
- `messages.py` — not yet ported. The logic actually changes here, not
  just the query syntax: recipients are embedded in Broadcast, not
  their own collection, so "list broadcasts with delivery status"
  becomes reading one document instead of a join.
- `me.py` (student dashboard) — not yet ported; the attendance %/
  win-rate/puzzle-count aggregation queries need rewriting for Mongo.
- Attendance marking, courses/lessons, puzzles, games, tournaments,
  notifications — modeled, no routers yet, on either backend.
- Super Admin can't yet act *inside* another academy's data — same gap
  as Postgres, needs an explicit `?academy_id=` override added per
  academy-scoped endpoint.

## Run it
```
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```
Open http://localhost:8000/health — if that returns `{"status": "ok"}`,
the app started and Beanie initialized. Open http://localhost:8000/docs
for interactive API docs.

## Payment receipts and WhatsApp setup
Same steps as `backend/README.md` (Gmail App Password for SMTP, Meta
WABA + one approved template for WhatsApp) — the setup is identical
regardless of which database is underneath.

First login: there's no signup route for `super_admin` on purpose —
insert that first user directly (via `mongosh`, Compass, or a one-off
script using `hash_password()` from `app/core/security.py`).
