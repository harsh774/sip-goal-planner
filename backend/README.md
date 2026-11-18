# SIP Goal Planner — API

FastAPI + PostgreSQL service that stores users and their savings goals, keeps a history of every goal change, lists goals with search, filters and totals, and serves a SIP projection endpoint. Overview of the whole project: [`../README.md`](../README.md).

## Run it

Needs Docker and Python 3. From the repository root:

```bash
cp backend/.env.example backend/.env
python3 backend/scripts/generate_secrets.py >> backend/.env
docker compose up --build
```

- Swagger UI: http://localhost:8000/docs
- Health check: http://localhost:8000/health

The API container runs `alembic upgrade head` before starting. PostgreSQL is exposed on **port 5433**, so it doesn't clash with a local PostgreSQL on 5432.

**Without Docker for the API** (database still from compose: `docker compose up -d db`):

```bash
cd backend
uv sync
uv run alembic upgrade head
uv run uvicorn app.main:app --port 8000
```

**Try it in Swagger:**
1. `POST /api/v1/auth/register`.
2. Click **Authorize** and log in with your email as `username`.
3. `POST /api/v1/goals`.
4. `GET /api/v1/goals/{id}/projection`.

## Environment variables

| Variable | Required | Default | Notes |
|---|---|---|---|
| `JWT_SECRET` | yes | — | At least 32 bytes. |
| `DATA_ENCRYPTION_KEY` | yes | — | 32 random bytes, base64. Encrypts personal data at rest. Losing it makes that data unreadable. |
| `EMAIL_HASH_KEY` | yes | — | 32 random bytes, base64. Keys the email lookup hash. Changing it breaks login for existing users. |
| `DATABASE_URL` | no | `postgresql+psycopg://sip:sip@localhost:5433/sip` | Overridden inside docker compose. |
| `JWT_EXPIRE_MINUTES` | no | `60` | |
| `CORS_ORIGINS` | no | `http://localhost:3000` | Comma-separated browser origins. |
| `TRANSPORT_CLIENT_IDS` | no | `1.0.0` | App versions allowed an encryption key (see below). |
| `TRANSPORT_KEY_GRACE_HOURS` | no | `24` | How long a rotated-out encryption key still works. |

`scripts/generate_secrets.py` prints fresh values for the three secrets. The API refuses to start if any of them is missing or malformed.

## Tests

Tests run against a real PostgreSQL database, `sip_test`, which docker compose creates on first start. The schema is built by the Alembic migration itself.

```bash
docker compose up -d db          # from the repository root
cd backend
uv sync
uv run pytest                    # whole suite
uv run pytest tests/test_projection.py::test_shared_vectors   # one test
uv run ruff check . && uv run ruff format --check .
uv run --with pyright pyright app scripts tests alembic   # type check, kept at 0 errors
```

`TEST_DATABASE_URL` overrides the test database location.

**What's covered (108 tests):**
- **Projection maths:**
  - shared vectors in `../shared/projection_vectors.json`, also run by the Flutter client
  - the worked example, zero return and 0% step-up
  - goals under a year and corpus already above target
  - the loop formula matching the closed form, and the plan reaching the target
- **Money conversion:** exact string ↔ integer round-trips; rejecting floats and more than 2 decimal places.
- **Auth:** the full flow, case-insensitive duplicate email, weak passwords, bad tokens, optional last name, password change (current password required).
- **Goals:**
  - ownership: another user's goal returns 404 on every route
  - field-level validation codes, JPY precision, currency lock
  - personal data encrypted at rest (checked with raw SQL)
  - history entries, soft delete, UUIDv7 ordering, the projection endpoint
  - list filters, sorting, paging, name search, and totals converted to one currency
- **Encrypted payloads:** both directions, errors and 204s, tampering, plaintext-query injection, oversized bodies, key rotation and revocation, private keys encrypted at rest.
- **Migrations:** every migration upgrades and downgrades; data backfills.

## Structure

```
app/
  api/            routes (thin) + dependencies (auth, services) + encrypted-payload middleware
  services/       business rules: auth, goals + history + search, projection engine (pure),
                  FX table for totals, transport keys
  repositories/   database access; every goal query is scoped to the user and skips deleted rows
  schemas/        request/response models, validated field types, money ↔ integer conversion
  models/         SQLAlchemy tables and enums
  db/             engine/session, encrypted column types
  core/           settings, crypto, JWT/bcrypt, error handlers
alembic/          migrations
scripts/          secret generation, transport key rotation
tests/
```

A request flows `route → service → repository → model`. Routes hold no logic, and services never touch HTTP.

## API

All routes are under `/api/v1`. Everything except register and login needs `Authorization: Bearer <token>`.

| Method | Path | Notes |
|---|---|---|
| POST | `/auth/register` | 201; 409 `email_taken`; `last_name` optional |
| POST | `/auth/login` | OAuth2 password form; `username` = email |
| GET / PATCH | `/auth/me` | PATCH: `first_name`, `last_name`, `default_currency` |
| POST | `/auth/me/password` | 204; needs `current_password` |
| GET | `/goals` | paged: `page`, `page_size`, `sort` (`newest`, `target_date`, `target_amount`); filters: `currency`, `goal_type`, `min/max_target_amount`, `target_year_from/to`; `q` searches names |
| POST | `/goals` | 201 |
| GET | `/goals/summary` | count, total monthly SIP and total target in `in_currency`, converted at a fixed dated rate table |
| GET / PATCH / DELETE | `/goals/{id}` | DELETE is a soft delete; another user's goal → 404 |
| GET | `/goals/{id}/history` | every create, update and delete, oldest first |
| GET | `/goals/{id}/projection` | level and step-up SIP, today's value, yearly table; `?as_of=YYYY-MM-DD` |
| GET | `/crypto/public-key` | public; `?client_id=<app version>` |

**Errors:**
- Validation failures return `422 {"detail": [{"field", "code", "message"}]}`. The `code` values are stable, so the client can rely on them.
- Other errors return `{"detail": "..."}`.

## Encrypted payloads (optional)

Requests carrying `X-Enc-Key` are decrypted by `app/api/encrypted_transport.py` and their
responses encrypted with the same per-request AES key (RSA-OAEP-SHA256 key wrap,
AES-256-GCM payloads). Requests without it pass through, so Swagger works as usual.
Public keys: `GET /api/v1/crypto/public-key?client_id=1.0.0` (the app version).
Protocol and key lifecycle: `docs/LLD.md` §5a.

Revoking the active key is fine: the next public-key request issues a new version.

```bash
uv run python scripts/rotate_transport_key.py 1.0.0            # new key version, old one retired
uv run python scripts/rotate_transport_key.py 1.0.0 --revoke 1 # reject key version 1 now
```

## Data conventions

- **Money and percentages:** strings in JSON (`"2500000.50"`, `"12.5"`). They're parsed with `Decimal` and stored as `bigint`, scaled by 100:
  - money in hundredths of a unit
  - rates in basis points
  - more than 2 decimal places is rejected, not rounded (for JPY, no decimals at all)
- **Currency:** each goal keeps the currency it was created in; it can't be changed later. New goals default to the user's `default_currency`.
- **Ids:** UUIDv7, generated in the app. They're time-ordered, so sorting by id sorts by creation time.
- **Encryption:** email, first and last name, goal name and history entries are encrypted with AES-256-GCM. Login finds users by an HMAC-SHA256 hash of the email. Because of this, names can't be searched in SQL: search narrows by the other filters in SQL, then matches decrypted names. At-rest key rotation isn't implemented yet.
- **Defaults:** new goals default to 2% inflation.
- **History:** goal changes are written to `goal_logs` in the same transaction as the change. A `created` or `deleted` entry is a full snapshot; an `updated` entry holds only the fields that changed.

## Projection maths

The full derivation is in `../docs/LLD.md` §1. In short:

- **Monthly rate:** `i = (1 + R)^(1/12) − 1`, so 12% a year compounds to exactly 12% a year.
- **Payment timing:** each SIP is paid at the start of its month.
- **Step-up:** applied once a year.
- **Required first SIP:** `P0 = gap / Σ (1+s)^⌊m/12⌋ (1+i)^(n−m)`.
  - The same formula handles zero return, 0% step-up and goals under a year.
  - It's rounded **up** so the plan still reaches the target: to a whole unit, or to 0.01 when the target or corpus has decimals.
  - Every other amount is rounded half-up to 2 decimal places.
- **Today's money:** `target / (1 + inflation)^(months/12)`.

The Flutter client runs the same engine in Dart and does every calculation the app shows. This endpoint exists because the brief requires one, and both versions are tested against the same shared vectors.

## Assumptions

- "Today" is the server's local date. `?as_of=` gives repeatable results.
- A goal must be at least 1 month away, and at most 100 years.
- Limits: return 0–30%, yearly step-up 0–25%, inflation 0–12%, matching the design's sliders.
- Returns are illustrative assumptions, not guarantees. Mutual fund investments are subject to market risks.
