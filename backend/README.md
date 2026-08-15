# King SaaS — Backend (FastAPI + PostgreSQL)

Multi-tenant academy platform: Super Admin manages academies + academy
admin accounts and can see roster size per academy; each academy admin
(and coach) manages their own students, batches, WhatsApp messaging, and
fees, and marking a fee paid emails the parent a receipt.

## What's here
- `app/models.py` — full schema: platform layer (Academy, User,
  AuditLog), roster (Parent, Student), messaging (Broadcast,
  BroadcastRecipient), batches/classes/attendance, courses/lessons/
  assignments, puzzles, games/ratings, tournaments, payments,
  notifications. Same schema as `backend-mongo/`, as SQL tables instead
  of Mongo documents.
- `app/routers/auth.py` — a single `POST /auth/login` for every role
- `app/routers/academies.py` — super-admin CRUD, audit logging on
  update, and each academy's active student count
- `app/routers/users.py` — super-admin create/enable/disable/delete
  for academy_admin/coach accounts
- `app/routers/team.py` — lets an *academy admin* add their own
  coaches, scoped to their academy, without going through the platform
  Super Admin
- `app/routers/students.py` — full CRUD: create (auto-links or creates
  the parent), list (`?include_inactive=true` for past students),
  update, soft-delete
- `app/routers/batches.py` — create/list batches
- `app/routers/payments.py` — create a fee, list fees, and
  `POST /payments/{id}/mark-paid` — which also sends the receipt email
- `app/routers/messages.py` — WhatsApp broadcasts (see below)
- `app/integrations/whatsapp.py` / `app/integrations/email.py` — the
  two outbound-communication integrations, each swappable for a
  different provider without touching any calling code
- `app/core/deps.py` — `require_role()`, the dependency that enforces
  permissions on the server, independent of whatever the client shows

## Payment receipt emails — one template, dynamic per academy
`render_invoice_html()` in `app/integrations/email.py` is the ONLY
invoice template in the codebase. Every academy-identifying value
(name, logo, address, phone, tagline) is passed in as a parameter, read
fresh from that academy's row at send time — nothing is hardcoded or
duplicated per academy. Update an academy's logo in its profile and the
next receipt uses it automatically.

Setup (SMTP, works with a Gmail App Password so there's no separate
signup):
1. On the Gmail account you want emails to come from: enable 2-Step
   Verification, then create an App Password at
   myaccount.google.com/apppasswords (your normal Gmail password won't
   work — Google blocks plain SMTP login for security).
2. Fill in `SMTP_USERNAME`, `SMTP_PASSWORD` (the app password),
   `SMTP_FROM_EMAIL` in `.env`.
3. Trigger: `POST /payments/{id}/mark-paid`. If the parent has no email
   on file, or SMTP fails, the payment still gets marked paid — the
   email is best-effort, not a condition of the payment being recorded.

## WhatsApp messaging — one-time setup required
Business-initiated WhatsApp messages must go through a template Meta
has pre-approved (a WhatsApp policy, not something this code can route
around). Before "Send Message" will actually deliver anything:

1. Create a Meta Business Account and a WhatsApp Business Account (WABA)
   at business.facebook.com, and a test/production phone number.
2. In WhatsApp Manager, create ONE template named to match
   `WHATSAPP_TEMPLATE_NAME` (default `academy_custom_message`), category
   **Utility**, with a single body variable, e.g. body text: `{{1}}`.
3. Generate a permanent access token (System User) and grab your Phone
   Number ID from WhatsApp Manager, fill both into `.env`.
4. Every recipient's phone number must be stored in E.164 format
   (`+91...`).

Meta bills per delivered template message, so cost scales with
recipient count. Business Solution Providers (Twilio, Gupshup, AiSensy,
Interakt, WATI) wrap the same API with easier onboarding — swapping one
in only touches `app/integrations/whatsapp.py`.

## Run it locally
1. `python -m venv venv && source venv/bin/activate`
2. `pip install -r requirements.txt`
3. Start a local Postgres, copy `.env.example` to `.env`, fill in
   `DATABASE_URL` (and SMTP/WhatsApp settings when you're ready for those)
4. `uvicorn app.main:app --reload`
5. Open http://localhost:8000/docs for interactive API docs
6. First login: there's no signup route for `super_admin` on purpose —
   insert that first user directly (`psql` or a one-off script using
   `hash_password()` from `app/core/security.py`)

## Known gaps / next steps
- Super Admin can't yet act *inside* another academy's data (view/edit
  its students, mark its payments) — right now every academy-scoped
  endpoint uses the caller's own `academy_id`, so a true cross-academy
  override needs an explicit `?academy_id=` param added to each one.
- Swap `Base.metadata.create_all()` for real Alembic migrations before
  this touches production data.
- Attendance marking, courses/lessons/assignments, puzzles, games,
  tournaments, and notifications are modeled but have no routers yet —
  same shape as students.py/batches.py, add them the same way.
- Wire up real email invites (instead of a returned temp password) for
  new academy-admin/coach accounts.
- Add a webhook receiver for WhatsApp delivery/read receipts.
- Add Postgres Row-Level Security policies on tenant-scoped tables.
- Add refresh-token support (access tokens currently just expire).
