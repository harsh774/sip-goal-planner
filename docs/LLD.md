# SIP Goal Planner — Low-Level Design

Status: draft. Read with [HLD.md](HLD.md). Items marked *(decision)* are open to change.

## 1. Financial maths

Implemented twice with identical behaviour:

- Dart: `frontend/lib/features/projection/domain/engine/projection_calculator.dart`. **Primary.** Produces every number the app shows: form preview, goal list SIPs and total, results screen.
- Python: `backend/app/services/projection.py`. Serves `GET /goals/{id}/projection` (required by the brief; used from Swagger and tests). The app does not call it.

The server never stores computed results; it stores only goals and their history. Both engines are pure; the "as of" date is a parameter. Both must pass every case in `shared/projection_vectors.json` (§7).

### 1.1 Inputs

| Symbol | Meaning |
|---|---|
| `T` | target amount |
| `C0` | current corpus |
| `R` | expected annual return (decimal, e.g. 0.12) |
| `s` | annual step-up (decimal) |
| `π` | annual inflation (decimal) |
| `n` | whole months from `as_of` to `target_date`, minimum 1 |

`n` counts calendar months; if the target day-of-month is earlier than the `as_of` day, the last partial month is dropped.

### 1.2 Formulas

Monthly rate (effective):

```
i = (1 + R)^(1/12) − 1
```

Growth of the existing corpus:

```
FV_c = C0 · (1 + i)^n
```

Gap the SIP must fill:

```
G = T − FV_c
if G ≤ 0: required SIP = 0, on_track = true
```

SIP with annual step-up, paid at the start of each month. Payment in month `m` (0-based) is `P0 · (1+s)^⌊m/12⌋` and compounds for `n − m` months:

```
F  = Σ_{m=0}^{n−1} (1 + s)^⌊m/12⌋ · (1 + i)^(n − m)
P0 = G / F
```

- Level SIP is the same formula with `s = 0`.
- Works unchanged for `i = 0`, goals under 12 months, and partial final years.
- With `s = 0` it must equal the closed form `G / ( ((1+i)^n − 1) / i · (1+i) )` (for `i > 0`), or `G / n` (for `i = 0`).

Target in today's money:

```
today_value = T / (1 + π)^(n/12)
```

### 1.3 Number representation and rounding

| Where | Money | Rates (%) |
|---|---|---|
| API request/response (JSON) | string, e.g. `"2500000.50"` | string, e.g. `"12.5"` |
| Serializer → DB | `Decimal(s) × 100` → `int` (hundredths) | `Decimal(s) × 100` → `int` (basis points: 12.5% → `1250`) |
| DB | `bigint` | `bigint` |
| DB → serializer | `int / 100` → `Decimal` → string with 2 decimals (`"2500000.50"`) | same (`"12.50"`) |
| Client domain | `int` hundredths in entities | `int` basis points |
| Maths (both engines) | `double` / `float` | `bp / 10000` as `double` / `float` |

- Strings are parsed with `Decimal`, never `float`, so `"0.1"` stores exactly `10`.
- More than 2 decimal places is rejected, not rounded (`code: too_many_decimals`). For `JPY` (0 minor digits) any fraction is rejected.
- The scale is 100 for every currency, including `JPY`; `CURRENCY_DECIMALS` only governs validation and display.
- Required SIP: computed in floating point, rounded **up** to the next whole currency unit so the plan still reaches the target.
- Table values and `today_value`: rounded to 2 decimals for display.

### 1.4 Year-by-year schedule

Simulated month by month with the rounded SIP: `balance = (balance + sip) · (1 + i)`, starting from `balance = C0`. One row per goal year; the last may cover fewer than 12 months. Produced for both plans.

| Field | Meaning (design column) |
|---|---|
| `year` | 1-based goal year ("Year") |
| `calendar_year` | calendar year the row ends in ("· 2027") |
| `months` | months in the row (12, or fewer for the last) |
| `monthly_sip` | SIP during this year ("Monthly SIP") |
| `invested_to_date` | `C0` + all SIPs so far ("Put in so far") |
| `growth_to_date` | `closing_balance − invested_to_date` ("Growth so far") |
| `closing_balance` | corpus at end of the row ("Total worth") |
| `goal_pct` | `closing_balance / T · 100`, capped display at 100 ("Goal reached") |

### 1.5 Plan summary (per plan)

| Field | Meaning |
|---|---|
| `first_year_sip` | SIP in year 1 |
| `final_year_sip` | SIP in the last year |
| `total_invested` | `C0` + all SIPs |
| `growth` | final balance − `total_invested` |
| `final_balance` | balance at the target date (≥ `T`) |

### 1.6 Worked example (reference vector)

Target 1,00,00,000, 144 months, `C0` = 20,000, `R` = 12%, `π` = 6%:

| Output | Value |
|---|---|
| `i` | 0.0094888 |
| `G` | 99,22,080 |
| Level SIP | 32,205 (exact 32,204.55) |
| Step-up SIP at 10%, first year | 20,519 (exact 20,518.76) |
| Today's value | 49,69,693.64 |

## 2. Repository layout

```
backend/
  app/
    main.py              app, routers, exception handlers, CORS
    core/config.py       settings from env (pydantic-settings)
    core/security.py     bcrypt hashing, JWT encode/decode
    core/crypto.py       AES-256-GCM encrypt/decrypt, HMAC email index
    db/session.py        engine, SessionLocal, get_db
    db/types.py          EncryptedText, EncryptedJSON (SQLAlchemy TypeDecorators)
    models/              User, Goal, GoalLog, enums.py
    schemas/             Pydantic models; money.py (string ↔ int hundredths)
    api/deps.py          get_current_user
    api/routes/auth.py
    api/routes/goals.py
    services/goal_service.py   create/update/delete + writes GoalLog in the same transaction
    services/projection.py
  alembic/
  tests/
  Dockerfile
frontend/                Flutter web app (§6)
shared/
  projection_vectors.json
docker-compose.yml       db + api
docs/
```

## 3. Data model

### Enums

Defined once in Python (`app/models/enums.py`) as `StrEnum`s and stored as native PostgreSQL enum types via `sqlalchemy.Enum(..., name=..., values_callable=lambda e: [m.value for m in e])`. The same classes type the Pydantic schemas, so Swagger lists the allowed values.

| PostgreSQL type | Python enum | Values |
|---|---|---|
| `currency_code` | `Currency` | `INR`, `USD`, `EUR`, `GBP`, `AED`, `SGD`, `AUD`, `CAD`, `JPY`, `CNY`, `BRL` |
| `goal_type` | `GoalType` | `home`, `education`, `retirement`, `car`, `wedding`, `travel`, `emergency_fund`, `other` |
| `goal_action` | `GoalAction` | `created`, `updated`, `deleted` |

- The initial Alembic migration creates all types before the tables; downgrade drops them after.
- Adding a value later needs its own migration with `ALTER TYPE ... ADD VALUE` (autogenerate does not detect enum value changes).
- Each currency also carries its minor-unit digits (`JPY` = 0, others = 2) for rounding and display, in a `CURRENCY_DECIMALS` map next to the enum.
- The Flutter client mirrors both enums in `domain/entities` with `fromJson`/`toJson` on the string value; an unknown value fails parsing loudly rather than defaulting.

### Conventions

- All primary keys: `uuid` holding a **UUIDv7**, generated in Python (`uuid6.uuid7()`; PostgreSQL 16 has no native `uuidv7()`). Time-ordered, so inserts stay index-friendly and ids sort by creation.
- No `varchar`: every string column is `text`. Length limits live in the Pydantic schemas (and in `CHECK (char_length(...))` where the column is not encrypted).
- No `numeric`: money and rates are `bigint` (§1.3).
- Timestamps: `timestamptz`, UTC.

### Encryption at rest

| Column | Stored as | Why |
|---|---|---|
| `users.email` | `text`: AES-256-GCM ciphertext | personal data |
| `users.email_hash` | `text`: HMAC-SHA256 hex of the lowercased email, **unique** | login lookup and uniqueness without decrypting |
| `users.first_name`, `users.last_name` | `text`: ciphertext | personal data |
| `goals.name` | `text`: ciphertext | free text, may name family members ("Aanya's education") |
| `goal_logs.changes` | `text`: ciphertext of the JSON diff | contains old/new names |

- `core/crypto.py`: `encrypt(plaintext: str) -> str` returns `"v1:" + base64(nonce ‖ ciphertext ‖ tag)` with a random 12-byte nonce; `decrypt` reverses it. The `v1:` prefix allows key rotation later.
- `EncryptedText` / `EncryptedJSON` TypeDecorators encrypt on bind and decrypt on load, so models and services handle plaintext.
- Keys from env: `DATA_ENCRYPTION_KEY` (32 bytes, base64) and `EMAIL_HASH_KEY` (separate HMAC key). The app refuses to start without them.
- Amounts, rates and dates stay plaintext `bigint` / `date`: not identifying on their own, and needed for `CHECK` constraints.
- Passwords are not encrypted; they are hashed with bcrypt (one-way).

### users

| Column | Type | Notes |
|---|---|---|
| `id` | uuid (v7) | PK |
| `email` | text | encrypted, stored lowercased before encryption |
| `email_hash` | text | unique |
| `password_hash` | text | bcrypt |
| `first_name` | text | encrypted; required at registration (1–50 chars) |
| `last_name` | text | encrypted; required at registration (1–50 chars). Migration 0002 split existing display names into these two columns. |
| `default_currency` | `currency_code` | default `INR`. Pre-fills new goals and the My goals total. |
| `created_at` | timestamptz | default now() |

### goals

| Column | Type | Notes |
|---|---|---|
| `id` | uuid (v7) | PK |
| `user_id` | uuid | FK → users.id, **ON DELETE RESTRICT**, indexed with `deleted_at` |
| `name` | text | encrypted |
| `goal_type` | `goal_type` | |
| `currency` | `currency_code` | set on create, cannot be changed |
| `target_amount` | bigint | hundredths; CHECK > 0 |
| `target_date` | date | |
| `current_corpus` | bigint | hundredths; default 0, CHECK ≥ 0 |
| `expected_return_bp` | bigint | basis points; CHECK 0–3000 |
| `annual_step_up_bp` | bigint | basis points; default 0, CHECK 0–2500 |
| `inflation_bp` | bigint | basis points; default 600, CHECK 0–1200 |
| `created_at` | timestamptz | default now() |
| `updated_at` | timestamptz | set on every write |
| `deleted_at` | timestamptz | null = active. Soft delete. |

A goal's amounts are always in its own `currency` (HLD D9). "Target date in the future" is enforced in the API, not the DB. Every goal query filters `deleted_at IS NULL`; a deleted goal returns 404.

### goal_logs

One row per change to a goal, written by `goal_service` in the same transaction as the change (not a DB trigger: triggers can't encrypt).

| Column | Type | Notes |
|---|---|---|
| `id` | uuid (v7) | PK; time-ordered, so it also orders the history |
| `goal_id` | uuid | FK → goals.id, ON DELETE RESTRICT, indexed |
| `user_id` | uuid | FK → users.id, ON DELETE RESTRICT; who made the change |
| `action` | `goal_action` | `created`, `updated`, `deleted` |
| `changes` | text | encrypted JSON. `created`: full snapshot. `updated`: only changed fields, `{"field": {"old": ..., "new": ...}}`. `deleted`: full snapshot. Values in API string form. |
| `created_at` | timestamptz | default now() |

- An update that changes nothing writes no log row.
- Logs are append-only: no update or delete endpoint.

## 4. API

Base path `/api/v1` *(decision)*. All routes except register and login require `Authorization: Bearer <token>`.

| Method | Path | Request | Success | Errors |
|---|---|---|---|---|
| POST | `/auth/register` | `{first_name, last_name, email, password}` | 201 `User` | 409 `email_taken`, 422 |
| POST | `/auth/login` | form `username`, `password` (OAuth2) | 200 `{access_token, token_type}` | 401 |
| GET | `/auth/me` | — | 200 `User` | 401 |
| PATCH | `/auth/me` | `{default_currency?, first_name?, last_name?}` | 200 `User` | 401, 422 |
| GET | `/goals` | query: `page` (≥1), `page_size` (1–100, default 10), `sort` (`newest` \| `target_date` \| `target_amount`), filters `currency`, `goal_type`, `min_target_amount`, `max_target_amount`, `target_year_from`, `target_year_to` | 200 `{items: [Goal], page, page_size, total, total_pages}` | 401, 422 |
| GET | `/goals/summary` | same filters, plus `in_currency` (default: the user's) and `as_of` | 200 `{count, currency, total_monthly_sip, total_target, converted, rates_as_of}` | 401, 422 |
| POST | `/goals` | `GoalCreate` | 201 `Goal` | 401, 422 |
| GET | `/goals/{id}` | — | 200 `Goal` | 401, 404 |
| PATCH | `/goals/{id}` | `GoalUpdate` (all optional) | 200 `Goal` | 401, 404, 422 |
| DELETE | `/goals/{id}` | — | 204 (soft delete + `deleted` log) | 401, 404 |
| GET | `/goals/{id}/history` | — | 200 `[GoalLogEntry]`, oldest first | 401, 404 |
| GET | `/goals/{id}/projection` | — | 200 `Projection` | 401, 404 |

- `User` = `{id, email, first_name, last_name, default_currency}`.
- Amount filters compare raw amounts in each goal's own currency, so the client enables them only when a currency filter is set. Year filters become date bounds, so the `(user_id, target_date)` index can be used.
- The dashboard makes three calls: `sort=target_date&page_size=3` for "Reaching soon", the filtered page, and `/goals/summary` with the same filters.
- `Goal` = `{id, name, goal_type, currency, target_amount, target_date, current_corpus, expected_return_pct, annual_step_up_pct, inflation_pct, created_at, updated_at}`; amounts and percentages are strings (§1.3).
- `GoalCreate` includes `currency` (defaults to the user's `default_currency`); `GoalUpdate` rejects `currency`.
- `GoalLogEntry` = `{id, action, changes, created_at}`.
- The goal list returns stored data only; each card's SIP is computed by the client (§6). The cross-goal total needs every matching goal, so `/goals/summary` computes it on the server, using the Python engine (same shared vectors) and the fixed FX table in `app/services/fx.py`.
- Login uses the OAuth2 password form so the Swagger "Authorize" button works.

### Projection response

```json
{
  "as_of": "2026-11-18",
  "months": 144,
  "currency": "INR",
  "monthly_rate": 0.0094888,
  "target_amount": "10000000.00",
  "current_corpus": "20000.00",
  "corpus_future_value": "77919.52",
  "gap": "9922080.48",
  "today_value": "4969693.64",
  "on_track": false,
  "assumptions_note": "Returns are illustrative assumptions, not guaranteed.",
  "level":   { "first_year_sip": "32205.00", "final_year_sip": "32205.00", "total_invested": "...", "growth": "...", "final_balance": "...", "rows": [ ... ] },
  "step_up": { "step_up_pct": "10.00", "first_year_sip": "20519.00", "final_year_sip": "...", "total_invested": "...", "growth": "...", "final_balance": "...", "rows": [ ... ] }
}
```

Money in the response uses the same string format as goals.

## 5. Validation

Server returns `{"detail": [{"field", "code", "message"}]}`. The client maps each `code` to the field and shows `message`.

| Field | Rule | `code` | English message |
|---|---|---|---|
| `email` | valid email | `email_invalid` | "Enter a valid email address." |
| `email` | not registered | `email_taken` | "This email already has an account." |
| `password` | ≥ 8 chars, ≥ 1 letter, ≥ 1 digit | `password_weak` | "Use at least 8 characters, including a letter and a number." |
| `name` | 1–100 chars, trimmed | `name_required` | "Name is required." |
| `goal_type` | allowed value | `goal_type_invalid` | "Choose a goal type." |
| money, percentages | string parseable as a decimal number | `not_a_number` | "Enter a number." |
| money, percentages | ≤ 2 decimal places (0 for `JPY` money) | `too_many_decimals` | "Use at most 2 decimal places." |
| `target_amount` | > 0, ≤ 1,000,000,000,000 | `amount_positive` | "Target amount must be greater than 0." |
| `current_corpus` | ≥ 0 | `amount_negative` | "Amount already invested cannot be negative." |
| `target_date` | > today | `date_past` | "Target date must be in the future." |
| `expected_return_pct` | 0–30 | `return_range` | "Expected return must be between 0% and 30%." |
| `annual_step_up_pct` | 0–25 | `step_up_range` | "Yearly increase must be between 0% and 25%." |
| `inflation_pct` | 0–12 | `inflation_range` | "Inflation must be between 0% and 12%." |
| `currency`, `default_currency` | allowed value | `currency_invalid` | "Unsupported currency." |
| `currency` on PATCH goal | not allowed | `currency_locked` | "A goal's currency can't be changed. Create a new goal instead." |

Confirm-password matching is client-only.

## 6. Client (Flutter web)

### 6.1 Structure

Clean architecture, feature-first. Dependencies point inward: `presentation → domain ← data`. `domain` is plain Dart with no Flutter, Dio or JSON imports.

```
frontend/lib/
  main.dart                     bootstraps DI, runs App
  app/
    app.dart                    MaterialApp.router, global BlocProviders
    router.dart                 go_router; redirects on AuthBloc state
    theme/                      design tokens (§6.2), ThemeData
  core/
    di/injection.dart           get_it registrations (manual, no codegen)
    network/
      dio_client.dart           builds the Dio instance
      api_client.dart           get/post/patch/delete wrapper used by datasources
      interceptors/
        auth_interceptor.dart   adds Authorization: Bearer <token>
        unauthorized_interceptor.dart  on 401: clear token, notify session stream
      api_exception.dart        typed exceptions thrown by ApiClient
      endpoints.dart            path constants
    error/
      failure.dart              sealed Failure hierarchy (domain-facing)
      result.dart               sealed Result<T> = Success<T> | Err<T>(Failure)
    storage/token_storage.dart  shared_preferences wrapper
    format/money_formatter.dart formatMoney(amount, Currency)
    usecase/usecase.dart        abstract UseCase<T, Params>
  features/
    auth/
      data/
        datasources/auth_remote_datasource.dart
        models/user_model.dart, token_model.dart      JSON ↔ entity
        repositories/auth_repository_impl.dart
      domain/
        entities/user.dart, currency.dart
        repositories/auth_repository.dart             abstract
        usecases/login.dart, register.dart, get_me.dart, logout.dart,
                 update_default_currency.dart
      presentation/
        bloc/auth_bloc.dart (+ _event, _state)
        pages/login_page.dart, register_page.dart
        widgets/
    goals/
      data/      datasources/goals_remote_datasource.dart, models/, repositories/
      domain/    entities/goal.dart, goal_type.dart, money.dart (int hundredths +
                          Currency; parse/format API strings)
                 repositories/goals_repository.dart
                 usecases/get_goals.dart, get_goal.dart, create_goal.dart,
                          update_goal.dart, delete_goal.dart
      presentation/
        bloc/goal_list_bloc.dart, goal_form_bloc.dart
        pages/goal_list_page.dart, goal_form_page.dart
        widgets/
    projection/
      domain/                   no data layer: nothing here calls the network
        entities/projection.dart, schedule_row.dart, plan.dart, goal_totals.dart
        engine/projection_calculator.dart   Dart engine (§1), pure
        fx/fx_rates.dart                    fixed rates table + as-of date
        usecases/calculate_projection.dart, calculate_goal_totals.dart
      presentation/
        bloc/projection_bloc.dart, plan_preview_cubit.dart
        pages/goal_plan_page.dart
        widgets/ chart, yearly table, comparison table, explainer
  shared/widgets/               disclaimer, loading skeleton, empty view,
                                error view + retry, slow-network notice
```

#### Layer rules

| Layer | Holds | May import |
|---|---|---|
| `domain` | entities, abstract repositories, use cases, projection engine | `core/error`, `core/usecase` only |
| `data` | remote datasources, JSON models (`extends`/maps to entities), repository implementations | `domain`, `core/network`, `core/storage` |
| `presentation` | Blocs/Cubits, pages, widgets | `domain` (use cases, entities), `core/format`, `shared` |

- Datasources call `ApiClient` and return models or throw `ApiException`.
- Repository implementations catch `ApiException`, map to `Failure`, return `Result<T>`. Nothing above `data` sees Dio or `ApiException`.
- Blocs call use cases only, never repositories or datasources.

#### Network client (Dio)

`DioClient` builds one `Dio`, registered as a singleton in `get_it`:

- `BaseOptions`: `baseUrl` from `const String.fromEnvironment('API_BASE_URL')`, JSON content type, `receiveTimeout` and `sendTimeout` 15 s. `connectTimeout` is not relied on (unreliable on web).
- Interceptors, in order: `AuthInterceptor` (reads `TokenStorage`), `UnauthorizedInterceptor` (on 401 clears the token and pushes to a `SessionExpired` stream that `AuthBloc` listens to), `LogInterceptor` in debug builds only.

`ApiClient` wraps it for datasources:

```dart
Future<dynamic> get(String path, {Map<String, dynamic>? query, CancelToken? cancel});
Future<dynamic> post(String path, {Object? body, CancelToken? cancel});
Future<dynamic> postForm(String path, Map<String, String> fields);   // OAuth2 login
Future<dynamic> patch(String path, {Object? body});
Future<void>    delete(String path);
```

Each call adds an overall `.timeout(15 s)` and converts every `DioException` / `TimeoutException` into one `ApiException`:

| `ApiException` | From | `Failure` |
|---|---|---|
| `TimeoutApiException` | timeout | `NetworkFailure(timeout: true)` |
| `NetworkApiException` | connection error | `NetworkFailure()` |
| `UnauthorizedApiException` | 401 | `AuthFailure()` |
| `NotFoundApiException` | 404 | `NotFoundFailure()` |
| `ConflictApiException(code)` | 409 | `ValidationFailure({'email': code})` |
| `ValidationApiException(fieldErrors)` | 422 `{detail:[{field,code,message}]}` | `ValidationFailure(fieldErrors)` |
| `ServerApiException` | 5xx, anything else | `ServerFailure()` |

#### State management (flutter_bloc)

| Bloc / Cubit | Events / methods | States |
|---|---|---|
| `AuthBloc` | `AppStarted`, `LoginRequested`, `RegisterRequested`, `LogoutRequested`, `DefaultCurrencyChanged`, `SessionExpired` | `AuthUnknown`, `Unauthenticated`, `AuthSubmitting`, `Authenticated(user)`, `AuthFailed(failure)` |
| `GoalListBloc` | `GoalsRequested`, `GoalsRefreshed`, `TotalCurrencyChanged`, `GoalDeleted` | `GoalListLoading(isSlow)`, `GoalListEmpty`, `GoalListLoaded(goals, perGoalPlans, totals, totalCurrency)`, `GoalListError(failure)`. Per-goal SIPs and totals come from `CalculateGoalTotals`; changing the total currency recomputes locally, no request. |
| `GoalFormBloc` | `FormStarted(goal?)`, `FieldChanged`, `Submitted` | one `GoalFormState` with field values, field errors, `status` (editing / submitting / success / failure) |
| `PlanPreviewCubit` | `update(GoalDraft)` | `PreviewHidden` (invalid input) / `PreviewReady(projection)`; uses the local engine, no network |
| `ProjectionBloc` | `ProjectionRequested(goalId)`, `PlanModeToggled` | `ProjectionLoading(isSlow)`, `ProjectionLoaded(goal, projection, mode)`, `ProjectionError(failure)`. Fetches the goal with `GetGoal`, then runs `CalculateProjection` locally. |

- States use `equatable`.
- Slow network: a loading bloc starts a 3 s `Timer` when it emits `Loading`; if no result yet, it re-emits `Loading(isSlow: true)`. The timer is cancelled on result and in `close()`.
- `GoalFormBloc` uses `bloc_concurrency`'s `droppable()` on `Submitted` so double taps send one request.
- Retry buttons re-dispatch the original request event.
- English UI only; the design's language picker is removed from the account menu.
- `Money` parses API strings (`"2500000.50"`) into `int` hundredths without going through `double`, and serialises back to the same string form. Form inputs are kept as strings until submit.
- FX: `fx_rates.dart` holds `ratesPerUsd: Map<Currency, double>` and `ratesAsOf`, from one public reference snapshot noted in the README. `convert(amount, from, to) = amount / ratesPerUsd[from] * ratesPerUsd[to]`. Used only for the My goals total, never for a goal's own numbers.
- Money formatter takes the currency code explicitly: `formatMoney(amount, currency)`. Locale per currency follows the design: INR → `en-IN` (lakh/crore), GBP → `en-GB`, others → `en-US`.
- The account menu's currency control is labelled "Default currency for new goals".
- Chart: `fl_chart` line chart; two series (level, step-up), dashed goal line, hover/tap tooltip with year, SIP, put in, worth, goal %.

### 6.2 Design tokens (from the canvas)

| Token | Value |
|---|---|
| background | `#0b0b0c` |
| layer / layer2 / field | `#161618` / `#1f1f22` / `#232327` |
| border / border-strong | `#2e2e33` / `#6b6b70` |
| text / text2 / text3 | `#f2f0ea` / `#b3b0a8` / `#8f8c84` |
| accent (gold) / hover / on-accent | `#d4af37` / `#e2c15a` / `#0b0b0c` |
| danger / danger-bg | `#ff6b6b` / `#2d1215` |
| success / success-bg | `#42be65` / `#0e2a17` |
| series 1 (level) / series 2 (step-up) | `#5b8def` / `#b38c25` |
| font | IBM Plex Sans 300/400/600 |
| shape | square corners; fields with bottom border; 48 px primary button; 32 px pill chips |

### 6.3 Screens

| Screen | Content | States |
|---|---|---|
| Log in / Create account | email, password (show/hide), confirm password on register, side panel of three benefits (hidden on phone) | submitting, field errors with summary banner, `email_taken` with "Log in instead" |
| My goals | summary strip (goal count, total monthly SIP and total of targets in a currency picked from a dropdown beside the total, defaulting to the user's default currency; "Approximate, at rates from <date>" when goals use other currencies); cards: type icon, name, target by date, level SIP, step-up line, saved % and time left, "See full plan" | loading skeleton, slow notice, empty (CTA + templates: Home, Education, Retirement, Emergency fund), error + retry |
| New / Edit goal | goal type chips, name, currency (create only; read-only on edit), target amount (number + slider), target date, already invested; assumptions: return (8 / 10 / 12% chips + field), step-up slider 0–25, inflation slider 0–12; live preview panel (Dart engine); phone: preview as a bottom bar that opens a sheet | field errors with count banner, preview hidden while invalid, saving |
| Goal plan (results) | header (name, target by date, time left, Edit, Delete; Delete confirms first); goal details; plan toggle level / step-up with hero SIP; "what makes up your target" (put in vs growth); today's money card; chart; yearly table; comparison table; "How we work this out" with the user's numbers; disclaimers | loading, slow notice, error + retry (goal is saved), on-track message when SIP is 0 |

Every amount is formatted in the currency of the goal it belongs to; only the My goals total uses the picked currency.

### 6.4 Network states

- Every request wrapped in a 15 s timeout.
- If still pending after 3 s, show the slow-connection notice from the design.
- Timeout or no connection → error view with retry; form input is never lost.
- 401 → clear token, route to log in.

### 6.5 Layout

- Content max width 1120 px, centred; two columns on desktop, one below 640 px.
- Yearly and comparison tables scroll horizontally on narrow screens.
- Disclaimer "Mutual fund investments are subject to market risks." on every screen footer; results add "This is not investment advice."

## 7. Tests

### 7.1 Shared vectors (`shared/projection_vectors.json`)

Each case: inputs (`as_of`, `target_date`, `T`, `C0`, `R`, `s`, `π`) and expected outputs (`months`, `level_sip`, `step_up_first_sip`, `today_value`, `on_track`). Run by both pytest and `flutter test`; values must match exactly after rounding.

| Case | Expectation |
|---|---|
| Worked example (§1.6) | 32,205 / 20,519 / 49,69,693.64 |
| Zero return | SIP = ceil(G / n) |
| Step-up 0% | Level SIP = step-up SIP = closed form |
| Goal under 1 year (7 months) | One schedule row, `months = 7` |
| Corpus already exceeds target | SIP 0, `on_track = true` |
| 30% return, 25% step-up | Upper bounds compute without overflow |

### 7.2 Backend (pytest)

| # | Test | Expectation |
|---|---|---|
| 1 | Shared vectors | All pass |
| 2 | Schedule reaches target | Final balance ≥ T for both plans |
| 3 | Closed form agreement | Loop result = closed form when `s = 0` |
| 4 | Auth flow | Register → login → `/auth/me` |
| 5 | Weak password, duplicate email | 422 `password_weak`; 409 `email_taken` |
| 6 | Ownership | User B gets 404 on user A's goal and its projection |
| 7 | Validation | Negative amount, past date, 31% return → 422 with field codes |
| 8 | Unauthenticated | `/goals` without token → 401 |
| 9 | Currency rules | PATCH goal with `currency` → 422 `currency_locked`; `currency=XYZ` → 422 |
| 10 | Money serializer | `"0.10"` stores `10` and returns `"0.10"`; `"1.234"` → 422 `too_many_decimals`; JPY `"100.5"` → 422 |
| 11 | Encryption at rest | Raw SQL on `users.email` and `goals.name` returns `v1:` ciphertext, not the plaintext; API returns plaintext; login works via `email_hash` with mixed-case email |
| 12 | History log | Create → 1 `created` row; PATCH two fields → `updated` row with exactly those two old/new pairs; PATCH with no change → no row |
| 13 | Soft delete | DELETE → 204; goal gone from list and GET → 404; `deleted_at` set; `deleted` log row written; history still readable in DB |
| 14 | UUIDv7 | Created ids have version 7 and sort in creation order |

### 7.3 Client (flutter test)

- Dart engine: shared vectors.
- `CalculateGoalTotals`: INR + USD goals, total in USD = USD SIP + converted INR SIP, flagged approximate; all-INR goals in INR → not flagged.
- `Money`: `"0.10"` ↔ `10`; `"2500000.50"` round-trips exactly.
- Money formatter: INR → "₹1.00 Cr" and "₹25.00 L"; USD → "$1.2M"; JPY has no decimals.
- `ApiClient` (with a mocked Dio adapter): 422 body → `ValidationApiException` with field codes; timeout → `TimeoutApiException`.
- Blocs (`bloc_test` + `mocktail` use cases): `GoalListBloc` emits `Loading → Loading(isSlow: true) → Loaded` when the use case takes > 3 s; `GoalListEmpty` for an empty list.
- Widget tests: goal list empty state; form shows field error for a past date; results renders on-track message.
