# AI Usage

How AI tools were used on this project. Kept up to date as the work goes on.

## Tools and configuration

- **Claude Code** (VS Code extension, Claude Opus), with the Superpowers plugin. I used its brainstorming skill to turn the brief into a design before writing any code.
- **Claude Design**, for the UI mockups: 21 artboards covering desktop, phone and every UI state.
- Agent configuration committed in this repo: `CLAUDE.md` *(to be added)*.

## What I delegated

| Area | What the AI did | What I decided |
|---|---|---|
| Design docs | Drafted `docs/HLD.md` and `docs/LLD.md` from the brief and the Claude Design canvas | Stack, the effective monthly rate, maths in the client, a currency per goal, encryption scope, `bigint` storage with string inputs, UUIDv7, soft delete with history, English only, Bloc and clean architecture on the client |
| Backend scaffolding | FastAPI app, layering (route → service → repository → model), Alembic migration, Docker setup | The layering and the data conventions above |
| Backend tests | Wrote the pytest suite and the shared projection vectors | Which edge cases had to be covered |
| Frontend | Flutter web app: clean-architecture layers, Dio `ApiClient` with typed exceptions, Blocs, Dart projection engine, pages following the Claude Design canvas | Bloc + clean architecture, client-side maths with shared vectors, the per-goal currency rule, a fixed FX snapshot for the total, English only |
| Frontend tests | Engine against the shared vectors, money parsing and formatting, validator, `ApiClient` error mapping, bloc states, widget test | That the engine must run the backend's exact vector file |
| Docs | READMEs and this file's first draft | Reviewed and edited |

## Where the AI was wrong, and how it was caught

1. **A "correction" that was itself wrong.** The first LLD gave the example goal's total invested as ₹46,57,520. The AI later "fixed" it to 32,205 × 144 = ₹46,37,520 and recorded that as its own mistake. But the LLD defines total invested as the existing ₹20,000 **plus** every SIP, so the first number was right. This was caught by comparing screenshots of the running app (which shows ₹46,57,520 from the shared engine) against the claim. Lesson: check a correction against the spec's definitions, not just the arithmetic.
2. **Money silently turned into strings.** The first draft of the goal service called `model_dump()` on the request to check JPY decimals. Because the money fields serialise to strings, `value % 100` would have run on `"10000.50"` and crashed. It was caught in review before the code ever ran, and replaced with direct attribute access.
3. **The design's maths disagreed with ours.** The Claude Design mockups calculate the monthly rate as 12% ÷ 12, which gives ₹30,772 a month for the example goal; our documented formula gives ₹32,205. This was found by reading the design's code rather than trusting its screenshots. I chose the effective rate and had the explainer text reworded.

4. **Wrong assumption about Bloc in the tests.** The first `GoalListBloc` tests assumed Bloc drops an `emit` equal to the initial state, so they left out the first `GoalListLoading()`. Four tests failed. Reading the failure output showed that Bloc always emits the first state. The tests were corrected; the bloc was right.
5. **Name clash with a Flutter widget.** A shared widget was first called `Banner`, which collides with Flutter's own `Banner` in `material.dart`. The analyzer caught it before anything ran, and it was renamed `NoticeBanner`.

## What I wrote by hand

*To fill in: one piece written deliberately without AI, and why.*

## How the output was checked

- Projection numbers come from a shared test-vector file. Its expected values were produced by an **independent** script (closed form for level SIPs), not by the engine under test.
- The API was exercised end to end with `curl` before tests were written. Raw SQL confirmed that personal data is stored as ciphertext and amounts as scaled integers.
- `ruff check`, `ruff format --check` and the full pytest suite pass before each commit.
- The Dart engine runs the **same** `shared/projection_vectors.json` as pytest, so the two engines can't silently drift apart.
- `dart analyze` (with strict casts and raw types) and `flutter test` pass before each frontend commit. `flutter build web` compiles cleanly.
- The exchange rates in `fx_rates.dart` were fetched from the ECB feed (frankfurter.dev) on the day; they weren't recalled from memory.
