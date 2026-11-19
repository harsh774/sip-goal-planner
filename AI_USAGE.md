# AI Usage

How AI tools were used on this project. Kept up to date as the work goes on.

## Tools and configuration

- **Claude Code** (VS Code extension, Claude Opus), with the Superpowers plugin. I used its brainstorming skill to turn the brief into a design before writing any code.
- **Claude Design**, for the UI mockups: 21 artboards covering desktop, phone and every UI state.
- Agent configuration committed in this repo: `CLAUDE.md` (commands, architecture, conventions).

## What I delegated

| Area | What the AI did | What I decided |
|---|---|---|
| Design docs | Drafted `docs/HLD.md` and `docs/LLD.md` from the brief and the Claude Design canvas | Stack, the effective monthly rate, maths in the client, a currency per goal, encryption scope, `bigint` storage with string inputs, UUIDv7, soft delete with history, English only, Bloc and clean architecture on the client |
| Backend scaffolding | FastAPI app, layering (route → service → repository → model), Alembic migration, Docker setup | The layering and the data conventions above |
| Backend tests | Wrote the pytest suite and the shared projection vectors | Which edge cases had to be covered |
| Frontend | Flutter app for web and Android: clean-architecture layers, Dio `ApiClient` with typed exceptions, Blocs, Dart projection engine, pages following the Claude Design canvas | Bloc + clean architecture, client-side maths with shared vectors, the per-goal currency rule, English only |
| Later features | Dashboard (search with 300 ms debounce, filters, paging, totals), profile and password change, about, offline and 404 pages, loading skeletons, amounts in words, Android build and GP icon | Every feature and its behaviour: what the dashboard shows, that totals ignore filters, debounce timing, the offline wording, default rates (10% return, 2% inflation) |
| Encrypted payloads | Implemented the protocol on both sides: RSA key pairs per client in `transport_keys`, the ASGI middleware, the Dio interceptor, rotation CLI, tests | **The scheme was my design**: a fresh AES key per request wrapped with the server's RSA public key, keys stored with a version, a public-key endpoint per client id, the app version as client id, and a UI switch to try it |
| Code quality | Dot shorthands and file-level text constants across the client, no `!` operator, datasource try/catch, pyright to zero errors | These conventions |
| Deployment | Render and Railway setup, DB copy, Cloudflare Pages deploy, `$PORT` and connection keepalives | Hosts: Render, Railway, Cloudflare Pages |
| Frontend tests | Engine against the shared vectors, money parsing and formatting, validator, `ApiClient` error mapping, bloc states, widget test | That the engine must run the backend's exact vector file |
| Docs | READMEs, `DESIGN.md`, HLD/LLD with Mermaid diagrams, `CLAUDE.md`, this file's first draft | Reviewed and edited |

## Where the AI was wrong, and how it was caught

1. **A "correction" that was itself wrong.** The first LLD gave the example goal's total invested as ₹46,57,520. The AI later "fixed" it to 32,205 × 144 = ₹46,37,520 and recorded that as its own mistake. But the LLD defines total invested as the existing ₹20,000 **plus** every SIP, so the first number was right. This was caught by comparing screenshots of the running app (which shows ₹46,57,520 from the shared engine) against the claim. Lesson: check a correction against the spec's definitions, not just the arithmetic.
2. **Money silently turned into strings.** The first draft of the goal service called `model_dump()` on the request to check JPY decimals. Because the money fields serialise to strings, `value % 100` would have run on `"10000.50"` and crashed. It was caught in review before the code ever ran, and replaced with direct attribute access.
3. **The design's maths disagreed with ours.** The Claude Design mockups calculate the monthly rate as 12% ÷ 12, which gives ₹30,772 a month for the example goal; our documented formula gives ₹32,205. This was found by reading the design's code rather than trusting its screenshots. I chose the effective rate and had the explainer text reworded.

4. **Wrong assumption about Bloc in the tests.** The first `GoalListBloc` tests assumed Bloc drops an `emit` equal to the initial state, so they left out the first `GoalListLoading()`. Four tests failed. Reading the failure output showed that Bloc always emits the first state. The tests were corrected; the bloc was right.
5. **Name clash with a Flutter widget.** A shared widget was first called `Banner`, which collides with Flutter's own `Banner` in `material.dart`. The analyzer caught it before anything ran, and it was renamed `NoticeBanner`.
6. **A body on a 204.** With encryption on, the middleware sealed a body onto `204 No Content` responses (delete goal, change password). This broke HTTP framing and desynced keep-alive connections. A separate AI code-review pass caught it and reproduced it on a real uvicorn server; the fix was checked the same way. The same review found that revoking the active key broke the public-key endpoint.
7. **A footer that wouldn't sit at the bottom.** The footer's `Column` filled the remaining space and drew its content at the top. Screenshots showed it; a widget test reproduced it before the one-line fix (`mainAxisSize: .min`).
8. **Text fields shrinking on focus.** The theme used an underline border at rest and an outline border on focus, which moved the label and cut 14 px. I reported it; a test that fails on the old theme now guards it.
9. **A stale build cache.** After adding plugins, the web build still registered only the old ones, so the app failed with `MissingPluginException`. Found by printing the error in the browser; fixed with `flutter clean`.

## What I wrote by hand

- **`SafeArea` around the app** (`frontend/lib/app/app.dart`), so content clears the status bar and notch on Android. I noticed the overlap on the device and added the wrapper myself.
- **App version `1.0.0`** in `pubspec.yaml`, which the encryption scheme then used as the client id.

The encryption code is not on this list: I designed the scheme (see above), and the AI implemented it.

## How the output was checked

- Projection numbers come from a shared test-vector file. Its expected values were produced by an **independent** script (closed form for level SIPs), not by the engine under test.
- The API was exercised end to end with `curl` before tests were written. Raw SQL confirmed that personal data is stored as ciphertext and amounts as scaled integers.
- `ruff check`, `ruff format --check` and the full pytest suite pass before each commit.
- The Dart engine runs the **same** `shared/projection_vectors.json` as pytest, so the two engines can't silently drift apart.
- `flutter analyze` (with strict casts and raw types) and `flutter test` pass before each frontend commit; pyright reports zero errors on the backend.
- UI changes were checked with headless-browser screenshots of the running app, and the encrypted traffic in a real browser (ciphertext on the wire, key rotation mid-session).
- A separate code-review agent reviewed the encryption, search and offline work; its Critical and Important findings were fixed and re-verified.
- The exchange rates in `backend/app/services/fx.py` were fetched from the ECB feed (frankfurter.dev) on the day; they weren't recalled from memory.
