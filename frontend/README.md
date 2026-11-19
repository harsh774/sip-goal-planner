# SIP Goal Planner — Web and Android client

A Flutter app (web and Android) for planning savings goals. It shows the monthly SIP each goal needs, how a yearly step-up changes it, and what the target is worth in today's money. **Every number shown is calculated in the client**; the API stores goals and adds up the dashboard totals. Overview of the whole project: [`../README.md`](../README.md).

**Screens:** log in / sign up · My goals dashboard (totals across all goals, reaching-soon goals, search, filters, numbered pages) · goal form with live preview (pinned to the bottom on phones) · goal plan with chart, yearly table and comparison · profile and password · about · offline and 404 pages.

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
| `API_BASE_URL` | `http://localhost:8000/api/v1` (web), `http://10.0.2.2:8000/api/v1` (Android emulator) | `--dart-define=API_BASE_URL=https://…` |

The API only accepts browser requests from origins listed in its `CORS_ORIGINS`, which defaults to `http://localhost:3000`. That's why the commands use port 3000.

**Production build:** `flutter build web --dart-define=API_BASE_URL=…` writes static files to `build/web`.

**Deploy (Cloudflare Pages):** live at https://sip-goal-planner.pages.dev, API on Render.

```bash
flutter build web --release -O4 --no-source-maps --dart-define=API_BASE_URL=https://sip-goal-planner-zx14.onrender.com/api/v1
npx wrangler login                     # once
npx wrangler pages deploy build/web --project-name sip-goal-planner --branch main
```

`-O4` is the web equivalent of `--obfuscate` (which `flutter build web` doesn't accept): dart2js minifies and renames every identifier, and no source maps are published. String literals, such as UI text and the API URL, stay readable in any web build, so nothing secret belongs in the client. Pages serves `index.html` for any unknown path, so deep links and the app's 404 page work. The API's `CORS_ORIGINS` must include `https://sip-goal-planner.pages.dev`.

After adding a plugin, run `flutter clean` before building for web; a stale cached plugin registrant causes `MissingPluginException` at runtime.

**Android:** needs the Android SDK and JDK 17.

```bash
flutter run -d emulator-5554          # the emulator reaches the local API at 10.0.2.2
flutter build apk --release --dart-define=API_BASE_URL=https://…
```

The APK lands in `build/app/outputs/flutter-apk/app-release.apk`. Plain HTTP is allowed only to `10.0.2.2` and `localhost` (`android/app/src/main/res/xml/network_security_config.xml`); any other API must use HTTPS. Release builds are signed with the debug key until a real keystore is configured in `android/app/build.gradle.kts`.

**Icons:** the GP mark lives in `assets/branding/`; the favicon, PWA icons and Android launcher icons are generated from `app_icon.png`.

## Tests

```bash
flutter test                                                     # all
flutter test test/features/projection/domain/projection_calculator_test.dart   # one file
flutter test --plain-name "shared vectors"                       # by name
flutter analyze && dart format -l 100 --set-exit-if-changed lib test
```

**What's covered (72 tests):**
- **Projection engine:** the shared vectors in `../shared/projection_vectors.json`, the same file the backend's pytest suite runs; the closed-form check; step-up and cents rounding.
- **Money:** exact string ↔ integer parsing; INR lakh/crore and other currencies' formatting; amounts in words ("5 lakh 55 thousand 5 rupees").
- **Form validation:** mirrors the API rules.
- **Network:** `ApiClient` error mapping through a fake Dio adapter; malformed responses become errors, not crashes.
- **Encrypted payloads:** the interceptor against a fake server (seal/open, form bodies, 204, stale-key retry, sealed errors, off); a payload sealed by the Python server opened in Dart.
- **Blocs:** `DashboardBloc` (load, slow, empty, error, paging, filters, 300 ms search debounce), `ProfileCubit`, connectivity.
- **Widgets:** live preview panel, offline page, text-field height on focus, pinned footer.

## Architecture

Clean architecture, organised by feature. Dependencies point inward: **presentation → domain ← data**.

```
lib/
  app/          router (go_router, redirects on auth state), theme (design tokens)
  core/
    network/    Dio client, ApiClient wrapper, interceptors (auth, 401, encryption), remote_call, guard()
    error/      Failure (sealed), Result<T> (Success | Err)
    domain/     shared value types: Currency, Scaled (string <-> integer)
    format/     money and date formatting
    di/         get_it wiring
  features/
    security/   encryption settings, hybrid cipher (RSA-OAEP + AES-GCM), public-key source
    presentation/ haptics, event transformers (debounce), slow-connection notice
    auth/       data · domain · presentation   (log in, register, session, profile)
    goals/      data · domain · presentation   (dashboard, search, filters, form, validation)
    projection/ domain · presentation          (engine, results; no data layer)
    about/      presentation
  shared/       app shell + footer, state and loading views, offline gate, 404, buttons
```

**Rules for each layer:**
- **`domain`:** plain Dart. Entities, repository interfaces, use cases, and the projection engine. No Flutter, Dio or JSON.
- **`data`:**
  - Datasources call `ApiClient` through `remoteObject`/`remoteVoid`, which turn missing or mistyped payloads into an `ApiException`; they never use `!` on JSON.
  - Repositories wrap each call in `guard()`, so they return a `Result<T>`. Dio types never leave this layer.
- **`presentation`:** Blocs call use cases only.
  - Pages hold no business rules. Form validation lives in the domain (`GoalFormValidator`), so it can be tested without widgets.

**State management:**

| Bloc | Job |
|---|---|
| `AuthBloc` | the session for the whole app; listens for a 401 on any request and logs out |
| `DashboardBloc` | totals for all goals, reaching-soon goals, and the paged list; filters, sort and debounced search reload only the list |
| `ProfileCubit` | name update and password change |
| `ConnectivityCubit` | online/offline for the offline page |
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
  - The server adds it up (`GET /goals/summary`) using a fixed snapshot of ECB reference rates dated 18 Nov 2026 (`backend/app/services/fx.py`), with AED from its USD peg.
  - The total is labelled approximate. Live rates would be the next step.
- **Optional encrypted payloads.** The "Encrypted traffic" switch in the account menu (a lock button on the login page) seals each request and response (AES-256-GCM, key wrapped with the server's RSA key). The client id is the app version from `pubspec.yaml`. Protocol: `../docs/LLD.md` §5a.
- **Offline.** On web the browser's online/offline events drive the offline page; on Android, connectivity_plus.
- **The token is stored in localStorage** (`shared_preferences` on web).
  - Simple, and it survives a reload. The risk is that an XSS bug in the app could read it.
  - An httpOnly cookie with CSRF protection would be safer, but was out of scope for the time available.
- **English only.** The design's language picker is removed.

## Assumptions

- "Today", for the projections, is the device's local date.
- Returns are illustrative assumptions, not guarantees. Mutual fund investments are subject to market risks.
