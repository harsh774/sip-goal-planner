# Design

One-page summary. Full detail: [docs/HLD.md](docs/HLD.md) and [docs/LLD.md](docs/LLD.md).

## Architecture

```
Flutter app (web, Android)                      FastAPI                       PostgreSQL
 pages → Blocs → use cases → repositories ─HTTPS─▶ routes → services ─────────▶ users, goals,
          │                    → datasources  JSON  → repositories             goal_logs,
          └ Dart projection engine:             JWT   Python projection engine  transport_keys
            every number on screen                    (same formulas)
```

- **Client:** clean architecture per feature (data / domain / presentation) with Bloc. The Dart engine computes every SIP, chart and table on the device; the API only stores goals and adds up the dashboard totals.
- **API:** route → service → repository → model. Every goal query is scoped to the user and skips soft-deleted rows; each write and its history row commit in one transaction.
- **Data:** money and rates travel as strings (`"2500000.50"`) and are stored as `bigint` hundredths / basis points, so nothing is a float until the maths. Names, emails and history are AES-256-GCM encrypted at rest.
- **Deployment:** web on Cloudflare Pages, API on Render, PostgreSQL on Railway.

## The SIP formula

Inputs: target `G`, months to the goal `n`, already invested `C`, annual return `R`, yearly step-up `s`, inflation `π`.

1. **Monthly rate** (effective, so 12 % a year compounds to exactly 12 %): `i = (1 + R)^(1/12) − 1`
2. **Gap** after the existing corpus grows: `gap = G − C·(1 + i)^n`
3. **Required first-year SIP**, paid at the **start** of each month, rising by `s` once a year:

   `P₀ = gap / Σ_{m=0}^{n−1} (1 + s)^⌊m/12⌋ · (1 + i)^(n−m)`

   With `s = 0` this is the annuity-due closed form `P = gap · i / (((1 + i)^n − 1)(1 + i))`. The one sum also covers zero return and goals under a year.
4. **Rounding:** the SIP is rounded **up** (to a whole unit, or to 0.01 when inputs have paise) so the plan always reaches the target; every other amount is rounded half-up to 2 places.
5. **Today's money:** `G / (1 + π)^(n/12)`.

Worked example: ₹1 crore in 12 years, ₹20,000 invested, 12 % return → **₹32,205/month**, or **₹20,519** rising 10 % a year; worth ₹49.70 lakh in today's money at 6 % inflation. Both engines must pass the same cases in `shared/projection_vectors.json`, whose expected values come from an independent script.

## Trade-offs

**1. Maths in the client, not only on the server.** Results are instant: the form previews the plan on every keystroke and the dashboard plans each goal without a round trip. The cost is that the formula exists twice (Dart for the app, Python for the brief's `/projection` endpoint and the dashboard totals). Shared test vectors run in both suites keep the two from drifting.

**2. Encrypting personal data at rest instead of storing it plainly.** A leaked database or backup exposes no emails, names or goal names. The cost is that those columns can't be searched or sorted in SQL, so goal search filters by the plain columns in SQL and then matches decrypted names in the app — fine for one user's handful of goals, not for millions of rows. Amounts and dates stay plain so database `CHECK` constraints still guard them.
