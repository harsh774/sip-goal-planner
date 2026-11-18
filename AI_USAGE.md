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
| Docs | READMEs and this file's first draft | Reviewed and edited |

## Where the AI was wrong, and how it was caught

1. **Wrong number in the design doc.** The first LLD gave the example goal's total invested as ₹46,57,520. The correct value is 32,205 × 144 = ₹46,37,520. It was caught by recomputing every number in the worked example with a separate script before relying on it.
2. **Money silently turned into strings.** The first draft of the goal service called `model_dump()` on the request to check JPY decimals. Because the money fields serialise to strings, `value % 100` would have run on `"10000.50"` and crashed. It was caught in review before the code ever ran, and replaced with direct attribute access.
3. **The design's maths disagreed with ours.** The Claude Design mockups calculate the monthly rate as 12% ÷ 12, which gives ₹30,772 a month for the example goal; our documented formula gives ₹32,205. This was found by reading the design's code rather than trusting its screenshots. I chose the effective rate and had the explainer text reworded.

## What I wrote by hand

*To fill in: one piece written deliberately without AI, and why.*

## How the output was checked

- Projection numbers come from a shared test-vector file. Its expected values were produced by an **independent** script (closed form for level SIPs), not by the engine under test.
- The API was exercised end to end with `curl` before tests were written. Raw SQL confirmed that personal data is stored as ciphertext and amounts as scaled integers.
- `ruff check`, `ruff format --check` and the full pytest suite pass before each commit.
