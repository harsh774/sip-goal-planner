# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

SIP Goal Planner: a FastAPI + PostgreSQL API (`backend/`) and a Flutter client for web and Android (`frontend/`). Users save savings goals; the app shows the monthly SIP needed, a yearly step-up variant and inflation-adjusted value. Design docs: `docs/HLD.md` (decisions D1–D14) and `docs/LLD.md` (formulas, schema, endpoints, encrypted-payload protocol §5a).

## Commands

Backend (run from `backend/`; needs `docker compose up -d db` from the repo root first — PostgreSQL on **port 5433**):

```bash
cp .env.example .env && python3 scripts/generate_secrets.py >> .env   # first time; API refuses to start without the 3 secrets
uv sync
uv run alembic upgrade head
uv run uvicorn app.main:app --port 8000          # Swagger at /docs
uv run pytest                                    # uses the separate sip_test database
uv run pytest tests/test_projection.py::test_shared_vectors
uv run ruff check . && uv run ruff format --check .
uv run --with pyright pyright app scripts tests alembic   # kept at 0 errors
uv run python scripts/rotate_transport_key.py 1.0.0 [--revoke N]
```

Or the whole stack: `docker compose up --build` (API runs `alembic upgrade head` on start).

Frontend (run from `frontend/`):

```bash
flutter run -d chrome --web-port 3000            # port 3000: the API's default CORS origin
flutter test
flutter test --plain-name "shared vectors"
flutter analyze && dart format -l 100 --set-exit-if-changed lib test
flutter build web --release                      # API URL: --dart-define=API_BASE_URL=...
flutter build apk --release                      # emulator reaches the local API at 10.0.2.2
```

After adding a Flutter plugin, run `flutter clean` before building web: a stale cached plugin registrant causes `MissingPluginException` at runtime.

## Architecture

**Maths lives twice, kept identical by shared vectors.** The projection engine exists in Python (`backend/app/services/projection.py`, used by `GET /goals/{id}/projection` and `/goals/summary`) and Dart (`frontend/lib/features/projection/domain/engine/projection_calculator.dart`, used for every number the app shows). Both test suites run `shared/projection_vectors.json`. Any formula or rounding change must land in both engines and the vector file; expected values in the vectors come from an independent script, not from either engine. Conventions: effective monthly rate `(1+R)^(1/12)−1`, SIP paid at the start of the month, step-up once a year; SIP rounded up (whole units, or 0.01 when the target or corpus has decimals); every other amount rounded half-up to 2 places.

**Money never travels or is stored as float.** API money and percentages are strings (`"2500000.50"`, `"12.5"`); `backend/app/schemas/money.py` converts them to `bigint` hundredths (rates in basis points) and back. The client mirrors this with `core/domain/scaled.dart`.

**Personal data is encrypted at rest** (`app/core/crypto.py`, `app/db/types.py` `EncryptedText`/`EncryptedJSON`; AES-256-GCM with a `v1:` prefix; email looked up by HMAC). Consequences: encrypted columns (names, emails, goal names, history) can't be searched or sorted in SQL — goal search filters in SQL by the plain columns, then matches decrypted names in Python (`GoalService._search`); migrations that touch these columns use `get_crypto()` (see 0002, 0003). At-rest key rotation is not implemented.

**Encrypted payloads (optional, toggled in the UI).** `app/api/encrypted_transport.py` is a pure ASGI middleware: requests carrying `X-Enc-Key` are opened with the per-request AES key (wrapped with RSA-OAEP-SHA256 for a versioned key in `transport_keys`) and their responses sealed with it; AAD binds payloads to method + path. Requests without the header pass through, so Swagger and tests work normally. The client id is the app version from `frontend/pubspec.yaml`; the server allowlist is `TRANSPORT_CLIENT_IDS`. Client side: `frontend/lib/core/network/interceptors/encryption_interceptor.dart` (retries once on `409 key_version_stale`).

**Backend layering:** route (`app/api/routes`) → service (`app/services`) → repository (`app/repositories`) → model. Every goal query is scoped to the user and skips soft-deleted rows; another user's goal is a 404, never 403. Every goal write and its `goal_logs` row commit in one transaction. Errors use one shape: validation `{"detail": [{"field", "code", "message"}]}` with stable codes the client maps to fields; others `{"detail": "..."}`. Fixed value sets are native PostgreSQL enums (adding a value needs a migration with `ALTER TYPE`). IDs are UUIDv7 generated in the app.

**Frontend:** clean architecture per feature (`lib/features/<f>/{data,domain,presentation}`), Bloc/Cubit state, `get_it` DI in `lib/core/di/injection.dart`, `go_router` in `lib/app/router.dart`. Only data-layer datasources talk to the API, through `ApiClient` + `remoteObject`/`remoteVoid` (`lib/core/network/remote_call.dart`), which turn malformed responses into `ApiException`s; repositories convert those to `Failure`s via `guard()` and return `Result<T>`.

**Tests:** backend tests hit a real PostgreSQL (`sip_test`); the session fixture runs migrations down to base and back up, and each test truncates tables — add new tables to the `TRUNCATE` in `tests/conftest.py`.

## Conventions

- Dart: use dot shorthands where the type is inferred (`crossAxisAlignment: .start`, `padding: const .all(24)`); put every fixed user-facing string in a private top-level `const _xxxText` at the top of its file (texts only — not paddings, sizes or styles); avoid the `!` operator (use pattern matching or `??`).
- Copy is English only. Returns are always labelled illustrative assumptions; the footer carries "Mutual fund investments are subject to market risks."
- Keep comments to what isn't obvious from the code.
