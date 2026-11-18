# SIP Goal Planner

Plan what you're saving for. Enter a goal — "₹1 crore in 12 years, ₹20,000 already invested, 12% a year" — and see:

- the **monthly SIP** needed to reach it on time,
- how that changes with a **yearly step-up**,
- what the target is worth in **today's money** after inflation,
- a year-by-year growth chart and table.

Each goal keeps its own currency (11 supported); the dashboard totals all goals in one currency you pick.

*Returns are illustrative assumptions, not guarantees. Mutual fund investments are subject to market risks.*

## What's in the repo

| Path | What |
|---|---|
| [`backend/`](backend/README.md) | FastAPI + PostgreSQL API: auth, goals with history, search and filters, projection endpoint, optional encrypted payloads. |
| [`frontend/`](frontend/README.md) | Flutter app for web and Android: dashboard, goal form with live preview, results with chart, profile. |
| `shared/projection_vectors.json` | Test cases both projection engines (Python and Dart) must pass. |
| [`docs/HLD.md`](docs/HLD.md), [`docs/LLD.md`](docs/LLD.md) | Design: decisions, formulas, schema, endpoints, encryption protocol. |
| [`AI_USAGE.md`](AI_USAGE.md) | How AI tools were used on this project. |
| [`CLAUDE.md`](CLAUDE.md) | Guidance for Claude Code working in this repo. |

## Quick start

Needs Docker, Python 3 and Flutter 3.38+.

```bash
cp backend/.env.example backend/.env && python3 backend/scripts/generate_secrets.py >> backend/.env
docker compose up --build                                  # API on :8000 (Swagger at /docs), PostgreSQL on :5433
cd frontend && flutter run -d chrome --web-port 3000       # in a second terminal; app on :3000
```

Register in the app, add a goal, and open its plan. Android: `flutter run` on an emulator reaches the local API at `10.0.2.2`; see the frontend README for APK builds.

## How it fits together

```
Flutter app ──HTTPS, JSON (money as strings), Bearer JWT──▶ FastAPI ──▶ PostgreSQL
  │ all numbers on screen come from the Dart engine           │ goals, users, history (personal data encrypted at rest)
  └ optional: payloads sealed with AES-256-GCM, key wrapped   └ same engine in Python for /goals/{id}/projection
    with the server's RSA key (lock button in the nav bar)
```

- **Maths:** effective monthly rate `(1+R)^(1/12) − 1`, SIP paid at the start of each month, step-up once a year. The Python and Dart engines are held identical by the shared vectors.
- **Money:** never a float in transit or storage — strings in JSON, `bigint` hundredths in the database.
- **Privacy:** names, emails, goal names and history are AES-256-GCM encrypted at rest; login looks users up by an HMAC of the email.

## Tests

```bash
docker compose up -d db
(cd backend && uv run pytest)               # 108 tests, real PostgreSQL (sip_test)
(cd frontend && flutter test)               # 72 tests
```
