# SIP Goal Planner — High-Level Design

Status: draft. Items marked *(decision)* are proposals open to change before implementation.
UI design: [Claude Design canvas "SIP Goal Planner"](https://claude.ai/artifact/JZnvpb88MrMFeTfF3ij4zz) (21 artboards: auth, goal list, goal form, results; desktop and phone; loading, empty, slow, error states).

## 1. Purpose

An investor enters a financial goal and sees:

1. The monthly SIP needed to reach the target by the goal date.
2. How that SIP changes if it steps up by a fixed percentage each year.
3. What the target is worth in today's money after inflation.

Plus a year-by-year corpus projection, a growth chart, and a comparison of the level and step-up plans.

Example: "₹1 crore in 12 years, ₹20,000 already invested, 12% a year."

## 2. Scope

**In scope**

- Email/password registration and login with JWT; each user sees only their own goals.
- Goal CRUD: name, goal type, target amount, target date, current corpus, expected return %, annual step-up %, inflation %. Delete is a soft delete.
- Goal history: every create, update and delete recorded in a log.
- Encryption at rest for personal data: email, display name, goal name, history entries.
- All plan maths in the client: live form preview, per-goal SIPs, totals, results screen.
- Projection endpoint on the server (required by the brief): required monthly SIP (level and step-up), inflation-adjusted target, yearly corpus table. Not used by the app.
- Goal list with each goal's required SIP and the total monthly SIP across goals.
- **Currency per goal** (11 currencies): each goal is saved in its own currency; the user's default currency (account menu) pre-fills new goals.
- My goals page: total monthly SIP shown in **one currency the user picks**, converted at a fixed, dated rate table.
- English only.
- Input validation with field-level error messages.
- Database migrations; Swagger UI working out of the box.
- Loading, empty, error and slow-network states; layouts down to phone-width browsers.
- Compliance: returns labelled as illustrative assumptions; disclaimer "Mutual fund investments are subject to market risks."

**Out of scope**

- Password reset ("Forgot password?" link in the design is hidden), email verification, refresh tokens, social login.
- Translations: the design's language picker is removed.
- Converting a goal's own numbers to another currency (see D9). Only the My goals total is converted.
- Live exchange rates.
- Real fund data, NAVs, or tax calculations.
- Stretch goal (LLM free-text goal entry) unless core work finishes early.
- Hosting: deferred (see §6).

## 3. Architecture

```
┌──────────────────────────────────────────────┐
│  Flutter web client                          │
│   ├─ UI (screens from the design canvas)     │
│   ├─ Projection engine (Dart) ─ ALL maths    │
│   ├─ FX table ─ My goals total only          │
│   └─ money formatting per goal currency      │
└──────────────────────┬───────────────────────┘
                       │ HTTPS, JSON (money as strings), Bearer <JWT>
┌──────────────────────▼───────────────────────┐
│  FastAPI                     Swagger at /docs │
│   ├─ Auth router (+ default currency)        │
│   ├─ Goals router ─ CRUD, history, soft del. │
│   ├─ Goal service ─ writes goal_logs         │
│   ├─ Crypto ─ AES-256-GCM, HMAC email index  │
│   └─ Projection service (Python) ─ brief's   │
│      endpoint, not called by the app         │
└──────────────────────┬───────────────────────┘
                       │ SQLAlchemy 2.0 (sync) + Alembic
┌──────────────────────▼───────────────────────┐
│  PostgreSQL 16: users, goals, goal_logs      │
│  UUIDv7 keys · text · bigint · enums         │
└──────────────────────────────────────────────┘

shared/projection_vectors.json ── test cases run by BOTH engines
```

| Component | Responsibility |
|---|---|
| Flutter client | Clean architecture (presentation / domain / data per feature), flutter_bloc state, Dio network client used only by data-layer datasources. UI, client-side validation, token storage, money formatting. |
| Dart projection engine + FX table | Every number the app shows: form preview, per-goal SIPs, My goals total (converted at fixed dated rates), results screen. |
| Auth router | Register, login (OAuth2 password flow), current user, update default currency. |
| Goals router + goal service | CRUD scoped to the authenticated user; soft delete; history. Every write and its log row commit in one transaction. |
| Crypto | Encrypts personal-data columns at rest; HMAC index for email lookup. |
| Money serializer | API strings ↔ `bigint` hundredths (money) and basis points (rates), via `Decimal`. |
| Python projection service | `GET /goals/{id}/projection` for the brief and Swagger. Same formulas, same test vectors. |
| PostgreSQL | Users, goals, goal history. No computed results stored. |

## 4. Key decisions

| # | Decision | Reason |
|---|---|---|
| D1 | Client: **Flutter web**; API: FastAPI + PostgreSQL (users, goals) | Confirmed. Must be responsive down to phone-width browser viewports. |
| D2 | **Maths in the client**; server stores goals only, plus a projection endpoint the app does not call | Confirmed. Instant results with no round trip; the endpoint keeps the brief's backend requirement and its tests. Drift between the Dart and Python engines is caught by one shared set of test vectors both suites must pass. |
| D3 | Projections never stored | Stored results go stale when a goal is edited or time passes. |
| D4 | Effective monthly rate `(1+R)^(1/12) − 1` | Confirmed. 12% a year compounds to exactly 12% a year. The design's explainer copy is reworded to match. |
| D5 | SIP paid at the start of each month (annuity due) | Matches the design ("on the first day of each month") and how Indian SIPs are debited. |
| D6 | Other users' goals return 404, not 403 | Does not reveal that the goal exists. |
| D7 | Money and rates travel as **strings**, are converted with `Decimal` in the serializer, and are stored as **`bigint` × 100** (hundredths; rates in basis points). Maths uses floating point. | Confirmed. No float error in storage or transport; exact round-trips. Float error in the maths is far below one unit, and the SIP is rounded **up** so the target is still met. |
| D8 | English only; server errors carry a `code` plus English `message` | Confirmed. Codes keep client field mapping stable. |
| D9 | Each goal stores its own currency, fixed at creation; its numbers never change when the user's default changes | Confirmed. Return and inflation assumptions are market-specific, so converting a ₹ goal into $ would mislead. Relabelling would be wrong. |
| D10 | My goals total converted into a user-picked currency using a fixed, dated rate table in the client *(decision)* | Confirmed as one currency the user selects. Static table: no external service, deterministic tests; shown as "approximate, at rates from <date>". Live rates are the upgrade path. |
| D11 | Encrypt personal-data columns (email, display name, goal name, history) with AES-256-GCM; email lookup via HMAC-SHA256 index | Confirmed. Protects personal data if the database or a backup leaks. Amounts and dates stay plain `bigint`/`date` so `CHECK` constraints still work. Cost: encrypted columns can't be searched or sorted in SQL. |
| D12 | Primary keys are UUIDv7, generated in the app | Confirmed. Time-ordered ids keep B-tree inserts sequential; PostgreSQL 16 has no native generator. |
| D13 | `text` for all strings, `bigint` for all numbers, native enums for fixed sets | Confirmed. Lengths and ranges enforced in schemas and `CHECK` constraints. |
| D14 | Goal history in an append-only `goal_logs` table, written by the service in the same transaction; deletes are soft | Confirmed. Full audit trail; `ON DELETE RESTRICT` everywhere means no row can disappear out from under its history. |

## 5. Trade-offs (for DESIGN.md)

1. **Client-side maths vs server-only** — chose client: instant results, no round trip, works while the network is slow. Cost: the formula exists twice (Dart for the app, Python for the brief's endpoint); shared test vectors keep them identical.
2. **Column encryption vs plain storage** — chose encryption for personal data: a leaked database or backup exposes no emails or goal names. Cost: no SQL search or sort on those columns, key management, and a little CPU per row.
3. *(alternative)* **Integer storage vs `numeric`** — `bigint` hundredths: exact, fast, simple; the serializer owns the conversion.

## 6. Runtime and deployment

- Local: `docker compose up` starts PostgreSQL and the API; the API runs `alembic upgrade head` on start.
- Local: the Flutter web app runs separately (`flutter run -d chrome`), pointing at the API via `--dart-define=API_BASE_URL=...`.
- Hosting is deferred (GitHub Pages or Vercel for the web build). Both serve static files only, so the API and PostgreSQL would need a separate host. The design stays host-agnostic: API URL is a build-time define, CORS origins come from env.
- Configuration via environment variables: `DATABASE_URL`, `JWT_SECRET`, `JWT_EXPIRE_MINUTES`, `CORS_ORIGINS`, `DATA_ENCRYPTION_KEY`, `EMAIL_HASH_KEY`. The API refuses to start without the two keys; `.env.example` documents how to generate them.

## 7. Non-functional

- **Security:** passwords hashed with bcrypt; personal-data columns encrypted at rest (D11); JWT HS256, 60-minute expiry; all goal queries filtered by `user_id` and `deleted_at IS NULL`. Token in browser localStorage (XSS risk accepted and documented; httpOnly cookie + CSRF is the stronger alternative).
- **Errors:** `{"detail": [{"field": ..., "code": ..., "message": ...}]}` for validation, `{"detail": "..."}` otherwise.
- **Network:** per-request timeout 15 s (wrapped manually; Dio's connect timeout is unreliable on web); "slow connection" notice after 3 s; retry on error screens.
- **Accessibility:** design's contrast and 44 px touch targets kept.
- **Testing:** pytest against a real PostgreSQL test database; Dart unit tests for the client engine; both run `shared/projection_vectors.json`.

See [LLD.md](LLD.md) for formulas, schemas, endpoints and client structure.
