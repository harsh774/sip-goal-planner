# SIP Goal Planner — Web client

A Flutter web app for planning savings goals. It shows the monthly SIP each goal needs, how a yearly step-up changes it, and what the target is worth in today's money. **Every number shown is calculated in the client**; the API only stores goals.

## Run it

Needs Flutter 3.38+ (Dart 3.10+) and the API running (see `../backend/README.md`).

```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port 3000
```

**Configuration:** a single build-time define.

| Define | Default | Notes |
|---|---|---|
| `API_BASE_URL` | `http://localhost:8000/api/v1` | `--dart-define=API_BASE_URL=https://…` |

The API only accepts browser requests from origins listed in its `CORS_ORIGINS`, which defaults to `http://localhost:3000`. That's why the commands use port 3000.

**Production build:** `flutter build web --dart-define=API_BASE_URL=…` writes static files to `build/web`.

## Tests

```bash
flutter test                                                     # all
flutter test test/features/projection/domain/projection_calculator_test.dart   # one file
flutter test --plain-name "shared vectors"                       # by name
dart analyze && dart format --set-exit-if-changed lib test
```

**What's covered (35 tests):**
- **Projection engine:** the shared vectors in `../shared/projection_vectors.json`, the same file the backend's pytest suite runs; the closed-form check; step-up rounding.
- **Money:** exact string ↔ integer parsing; INR lakh/crore and other currencies' formatting.
- **Goal totals:** mixed currencies are converted and flagged as approximate; a goal's own numbers never change.
- **Form validation:** mirrors the API rules.
- **`ApiClient`:** error mapping through a fake Dio adapter (422, 409, 401, 404, 500, timeout).
- **`GoalListBloc`:** the slow-connection, empty, error and currency-switch states (bloc_test with mocktail).
- **Widget:** the live preview panel.

## Architecture

Clean architecture, organised by feature. Dependencies point inward: **presentation → domain ← data**.

```
lib/
  app/          router (go_router, redirects on auth state), theme (design tokens)
  core/
    network/    Dio client, ApiClient wrapper, interceptors, ApiException, guard()
    error/      Failure (sealed), Result<T> (Success | Err)
    domain/     shared value types: Currency, Scaled (string <-> integer)
    format/     money and date formatting
    di/         get_it wiring
  features/
    auth/       data · domain · presentation   (log in, register, session)
    goals/      data · domain · presentation   (list, form, validation)
    projection/ domain · presentation          (engine, FX, results; no data layer)
  shared/       app shell, state views, disclaimer
```

**Rules for each layer:**
- **`domain`:** plain Dart. Entities, repository interfaces, use cases, and the projection engine. No Flutter, Dio or JSON.
- **`data`:**
  - Datasources call `ApiClient` and either return models or throw an `ApiException`.
  - Repositories wrap each call in `guard()`, so they return a `Result<T>`. Dio types never leave this layer.
- **`presentation`:** Blocs call use cases only.
  - Pages hold no business rules. Form validation lives in the domain (`GoalFormValidator`), so it can be tested without widgets.

**State management:**

| Bloc | Job |
|---|---|
| `AuthBloc` | the session for the whole app; listens for a 401 on any request and logs out |
| `GoalListBloc` | loads goals; works out per-goal SIPs and the total in the chosen currency on the device |
| `GoalFormBloc` | create or edit; client errors shown after the first submit, server errors mapped onto fields |
| `PlanPreviewCubit` | live preview, run on every valid change |
| `ProjectionBloc` | results screen: plan toggle and delete |

**Network states:**
- **Timeout:** every request has an overall 15-second limit. Dio's own connect timeout is unreliable on web.
- **Slow connection:** if a request is still running after 3 seconds, the bloc switches to `Loading(isSlow: true)` and the page shows the design's "still working" notice.
- **Errors:** the page shows an error view with a retry button.
- **Double taps:** submit and delete ignore repeat taps while a request is running (`droppable()`).

## Decisions and trade-offs

- **The maths runs in the client.** Results are instant, and the form previews the plan as you type.
  - The same engine also exists in Python for the API's projection endpoint, which the brief requires.
  - Both are held to the same shared test vectors, so they can't drift apart.
- **Money is never a `double` until the maths.**
  - The API sends strings. `Scaled` parses them into integer hundredths (rates into basis points).
  - Values are converted to `double` only inside the engine.
- **Each goal keeps its own currency.** "My goals" can show the total in any currency.
  - It converts using a fixed snapshot of ECB reference rates dated 18 Nov 2026 (`fx_rates.dart`), with AED from its USD peg.
  - The total is labelled approximate. Live rates would be the next step.
- **The token is stored in localStorage** (`shared_preferences` on web).
  - Simple, and it survives a reload. The risk is that an XSS bug in the app could read it.
  - An httpOnly cookie with CSRF protection would be safer, but was out of scope for the time available.
- **English only.** The design's language picker is removed.

## Assumptions

- "Today", for the projections, is the device's local date.
- Returns are illustrative assumptions, not guarantees. Mutual fund investments are subject to market risks.
