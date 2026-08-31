# Build Plan: Context-Resilient Staged Delivery

**Companion to:** `technical-writing-app-blueprint-v2.md`
**Problem this solves:** the blueprint is now large enough that no single LLM session can hold it plus the codebase plus the current task. Context will be exhausted, and *before* it is exhausted the model will silently degrade — losing earlier decisions, re-solving solved problems, and confidently contradicting things agreed 40 messages ago. This document is the defence against that.

---

## Part 0 — The Core Principle

**The repository is the memory. The LLM is not.**

Every architectural decision, every completed feature, every rejected approach must exist as a file in the repo before the session that produced it ends. If it only exists in the chat history, treat it as lost. A session is a disposable worker; the repo is the only thing that persists.

The corollary: **the highest-value engineering work in this project is not the app — it is the state files that let any fresh session pick up in under 200 lines of reading.**

### The precedence rule

**Drift protection outranks everything else in this document, including the QA/QC improvement authority in Part 4.**

Where any two rules conflict, the one that preserves continuity and prevents unreviewed change wins. This is not a tiebreaker applied case-by-case — it is a standing order. An agent that is unsure whether it is permitted to change something is not permitted to change it.

The reasoning, stated once so it doesn't have to be re-argued: a deferred good idea costs a delay; an accepted bad one costs silent corruption of work already paid for, often undetected for weeks. Those risks are not comparable, so they are never weighed against each other.

---

## Part 1 — Layer 1: The Reconciliation Gate (highest priority, per your ask)

Before *any* proposed change is implemented, it passes a mandatory check that answers three questions in order. This runs first, every time, no exceptions.

### 1.1 The three questions

| # | Question | Fail action |
|---|---|---|
| Q1 | **Does this already exist in the app?** Search the codebase and `FEATURES.md` for the capability by function, not by name. | If yes → STOP. Report what exists, do not build. |
| Q2 | **Does it conflict with a locked decision?** Check `DECISIONS.md` (the A1–A6 architectural rulings and everything added since). | If yes → STOP. Surface the conflict; a human decides whether to unlock the decision. |
| Q3 | **Is it an improvement, and against what measure?** State the specific benefit and the specific cost (complexity, new dependency, perf, scope). | If no clear benefit → STOP. Log to `REJECTED.md` with reasoning. |

Only a change passing all three enters the build queue.

### 1.2 The files this gate reads

Four small files, kept deliberately short so they fit in any context window:

```
/state/
  FEATURES.md    — what is BUILT and working. One line per capability.
                   Status: ✅ done | 🔨 in progress | ⬜ planned
  DECISIONS.md   — locked architectural rulings (A1–A6 + additions),
                   each with a one-line rationale. Append-only.
  REJECTED.md    — what was considered and turned down, and why.
                   Prevents re-litigating the same idea every 3 sessions.
  CURRENT.md     — the single active task. Rewritten each session.
                   Max ~40 lines.
  PARKED.md      — good ideas deferred mid-session (Part 4.5). Reviewed
                   at phase gates from a clean session, never acted on
                   in the session that raised them. Max 100 lines.

/specs/
  <feature>.md   — one spec per feature (see Part 4.2). Written and
                   human-approved BEFORE implementation. Read only the
                   spec for the current task, never all of them.
```

**Hard size caps:** FEATURES.md ≤ 200 lines, DECISIONS.md ≤ 150, REJECTED.md ≤ 100, CURRENT.md ≤ 40. If one grows past its cap, that is a signal to consolidate, not to raise the cap. Total budget for all four: under ~5K tokens, so they can be re-read at the start of *every* session cheaply.

### 1.3 Why REJECTED.md matters more than it looks

Without it, every fresh session re-proposes the same rejected ideas (PlantUML, synced live SQLite, git-on-iOS) because it has no memory of why they were dropped. You then spend context re-explaining. One line each in a file prevents an entire class of wasted session.

---

## Part 2 — Layer 2: Session Discipline

### 2.1 The session contract

Every session — regardless of model — starts and ends the same way:

**Start (the "cold boot"):**
1. Read `/state/*.md` (all four, ~5K tokens).
2. Read `CURRENT.md` for the one task in play.
3. Read only the files that task touches. **Never** "read the codebase to get oriented."
4. Restate the task in one sentence and the acceptance criteria before writing code. If the restatement is wrong, the context is already bad — stop and correct before proceeding.

**End (the "checkpoint"):**
1. Update `FEATURES.md` with what now works.
2. Append any new ruling to `DECISIONS.md`.
3. Append any rejected approach to `REJECTED.md`.
4. Rewrite `CURRENT.md` with the *next* task and any gotchas discovered.
5. Commit. The commit message is the session summary.

A session that ends without step 1–4 is a session whose work is at risk. Treat the checkpoint as part of the task, not as optional admin.

### 2.2 One task per session — sized to fit

**Rule: a task must be completable in roughly 40% of the context window.** The remaining 60% absorbs tool output, test failures, and iteration. If a task can't be described in ~10 lines of acceptance criteria, it is too big — split it.

Signs a task is too big (split immediately):
- It touches more than ~4 files
- Its description contains "and then" more than twice
- It requires reading a file over ~500 lines to understand

### 2.3 Degradation tripwires — how you *know* context is going bad

Watch for these. Any one of them means **stop, checkpoint, start a fresh session** — do not push through:

| Tripwire | What it looks like |
|---|---|
| **Re-solving** | Model rewrites something already working, or reintroduces a rejected approach |
| **Decision drift** | Model contradicts a locked A1–A6 decision without flagging it |
| **Naming drift** | Invents new names for existing entities (`BusBar2` when the code says `BB2`) |
| **Phantom features** | References functions/files that don't exist |
| **Widening scope** | Starts "improving" adjacent code you didn't ask about |
| **Summary hedging** | Vague summaries ("I've made various improvements") instead of specifics |
| **Test amnesia** | Forgets tests exist, or that they were passing |

Design sessions for this project produced live examples of exactly this class of failure — a duplicated block left behind by a bad edit, a structural element placed in the wrong parent, entities silently renamed between turns. All were caught only by a human reading the output. **Assume the model will not catch them — build the checks in Part 3 so the machine catches them instead.**

### 2.4 Budget protection

- **Cheap models do the cold boot.** Reading state files and restating the task doesn't need Opus. Route the orientation phase to DeepSeek V4 Flash.
- **Never paste the full blueprint into a session.** Reference the section number; the model reads only that section from the repo.
- **Kill a session at the first tripwire** rather than spending tokens trying to correct a degraded context. Restarting is always cheaper than repairing.
- **Batch the expensive reviews.** Fable 5 / Opus 5 review runs once per phase gate, reading a diff — not per session.

---

## Part 3 — Layer 3: Machine-Checkable Guardrails

Human review is the thing that runs out. Automate what you can so degradation is caught without you.

### 3.1 Tests as the anti-drift mechanism

Every completed feature ships with a test. The test suite is the objective record of what works — the one thing a degraded model cannot talk its way around. Rule: **if the suite was green at session start and is red at session end, the session's work is rejected, not debugged into submission.**

### 3.2 Validators (build these early — they pay for themselves)

Because these errors are subtle, look fine, and an LLM will not catch them.

**Document integrity — the majority of the risk, since this is a writing app:**
- **Round-trip validator** — parse → render → export → reparse must be lossless. Any drift is an error.
- **Protected-compound validator** — paste healing must never rejoin `low-voltage`, `star-delta`, `N+1`, `XLPE/SWA/PVC`. Silent meaning corruption.
- **Identity validator** — duplicate UUIDs, orphaned block IDs, wiki-links resolving to nothing.
- **Structure validator** — malformed frontmatter, heading-level jumps, tables broken by an edit, clause numbers (`411.3.3`) swallowed as list markup.
- **Duplicate-block detector** — repeated identical source segments left behind by a bad edit.
- **Unit-system validator** — §4.7's checker.

**Engineering content — a narrower specialist set, applying only to documents containing diagrams or calculations:**
- **SLD structural validator** — an `ats` node with fewer than 2 inputs is an error; an orphan node with no edges is an error; a `transformer` with one voltage is a warning.
- **Rating sanity validator** — a device rating below the calculated FLC of its source; a busbar rated below its incomer.

### 3.3 CI gate

Every commit runs: tests → validators → build. Red means the change doesn't land. This is what lets you trust work produced in a session you weren't watching closely.

---

## Part 4 — QA/QC: Weighting, Specification, Verification, and Bounded Change Authority

Layers 1–3 stop the process degrading. This part governs whether each *feature* is worth building, correctly built, and allowed to evolve.

### 4.1 Feature weighting — decide what deserves the budget

Every feature entering the queue is scored before it is specified. Scores go in `/state/FEATURES.md` alongside the entry.

| Axis | Scale | Meaning |
|---|---|---|
| **Value** | 1–5 | How much daily friction does this remove for the actual user? |
| **Verifiability** | 1–5 | Can success be machine-checked? 5 = pure function + golden tests. 1 = needs human eyes on a UI. |
| **Blast radius** | 1–5 | What breaks if it's wrong? 1 = isolated. 5 = corrupts documents or loses data. |
| **Dependency depth** | 1–5 | How much must exist first? |

**Build priority = Value × Verifiability ÷ (Blast radius × Dependency depth).**

This deliberately favours high-value, self-verifying, low-risk, low-dependency work — the shape that is cheapest to build agentically. Paste healing (§2.4) scores near the top on this formula, which is why it is Stage 0.5. Sync (A3) scores poorly on blast radius and is therefore gated behind explicit human review, not because it's unimportant but because being wrong is expensive.

**Anything scoring blast radius 4–5 requires a written rollback plan before implementation begins.**

### 4.2 The Feature Spec — required before any code

No feature is implemented from a blueprint paragraph alone. Each gets a short spec file at `/specs/<feature>.md`, written and human-approved first:

```
# <Feature>

## Intent
One sentence: what problem this solves for the user. Not the mechanism.

## Scores
Value / Verifiability / Blast radius / Dependency depth  → priority

## Acceptance criteria
Numbered, each independently testable, each phrased as an observable
behaviour — not an implementation detail.
Max 10. If you need more, the feature is too big; split it.

## Out of scope
What this explicitly does NOT do. (Prevents scope creep mid-session.)

## Test plan
- Unit / golden fixtures: <what>
- Validator rules: <what>
- Manual check (only if unavoidable): <what, and why it can't be automated>

## Failure modes
What "subtly wrong but plausible" looks like for this feature.
This is the section that catches LLM-shaped bugs — write it honestly.

## Rollback
How to remove this if it proves wrong. (Required if blast radius ≥ 4.)
```

**The Failure modes section is the highest-leverage part.** For paste healing it reads "rejoins a legitimate compound like `star-delta`"; for the link index, "resolves to a stale path after a rename"; for the SLD library, "renders a topology that looks plausible but is electrically invalid." Naming the failure mode up front is what lets you write a test for it *before* the model has a chance to produce it confidently.

### 4.3 Verification tiers — match the check to the risk

| Tier | Applies to | Verification required |
|---|---|---|
| **T1 — Self-verifying** | Pure transforms (paste healing, unit conversion, vdrop calcs) | Golden fixture suite. No human review needed to merge. |
| **T2 — Rule-checkable** | Structural output (document round-trip, link resolution, rules engine diagnostics, and — where present — SLD topology) | Validators (Part 3.2) + unit tests. Human spot-check at phase gate only. |
| **T3 — Behaviourally testable** | File model, snapshots, links, search | Integration tests incl. adversarial cases (rename, offline edit, concurrent write). Human test of the named failure modes. |
| **T4 — Requires human judgement** | Editor feel, layout, typography, pan/zoom, animation | Dogfooding. Explicitly time-boxed — do not let the agent iterate blind on T4 work; it burns budget with no verification signal. |

**Rule: T4 work is never delegated to a cheap model in a long loop.** Either you're in the room, or it doesn't get built that session. This is the single biggest budget leak in agentic UI work.

**T4 is two tiers wearing one label, and they need different handling.** See
`docs/ui-conventions.md` for both, in full, before any view work.

- *Static appearance* — layout, typography, density, state visuals. Not truly
  unverifiable: render the real view with `ImageRenderer` and look at the PNG.
  This has caught defects on every attempt (a header row stretched to full sheet
  height, a stationary row painting over a floating one, a translucent card
  colliding with the list behind it) that had all survived code review. An
  agent may iterate here, because each pass has a real signal.
- *Gesture and feel* — drag, hold, scroll conflict, animation timing. Genuinely
  unverifiable in-session: touch injection needs Accessibility permission the
  agent environment lacks, and the test bundle has no app host. An agent must
  **not** loop here. It ships one reasoned change and hands back an ordered
  human check. Three successive gesture shapes shipped broken on iOS before one
  held; each looked correct when written.

The distinction matters because "T4, so just dogfood it" let appearance defects
through that a two-minute render would have caught.

### 4.4 Document QC — correctness beyond "the code runs"

This app emits documents that get *issued*. A software-correct feature can still produce a wrong document. Every feature carries a second check:

- **Validators** (Part 3.2) run in CI — document integrity first, engineering content where applicable.
- **Golden documents:** a corpus of known-correct documents — a design note, a spec extract, a report with tables and figures, and one containing an SLD — that must round-trip and re-render identically after any change to the parsing, rendering, or rules pipeline. Regression here is a merge blocker.
- **Deliberate-defect corpus:** documents containing *known* errors that the validators must catch. Weighted the way the product is:
  - *Document-level (majority):* a paste that rejoined `star-delta`; a duplicate frontmatter UUID; a wiki-link to a renamed file; a table destroyed by unwrapping; a clause number stripped as a page number; a document that fails to round-trip.
  - *Engineering content (narrower):* an ATS with one input; a busbar rated below its incomer; a superseded citation; a `shall` inside a NOTE.

A validator that passes clean documents but misses these is not doing its job.

*Both classes share one signature: output that looks fine and is wrong. That is what confident generation produces, and it is precisely what a human reviewer stops catching once they are reading quickly.*

### 4.5 Bounded change authority — permission to find a better way

> **PRECEDENCE RULE — this overrides everything else in Part 4.**
> **When drift protection and improvement authority conflict, drift protection wins. Every time. Without exception.**
>
> A better idea is worth almost nothing compared to a stable, trustworthy codebase. Good ideas recur — you will have the same insight again next week, and it will still be a good idea then, and you can implement it deliberately from a clean session with a written spec. Work destroyed by a confidently-wrong session in a degraded context does not come back, and worse, you may not notice it went until much later.
>
> The asymmetry is the whole argument: **the cost of deferring a good improvement is a delay. The cost of accepting a bad one mid-session is silent corruption of work you already paid for.** Those are not comparable risks, so they do not get weighed against each other — the tie always breaks the same way.
>
> **Practical consequence:** when an agent is uncertain which authority tier a change falls under, it is by definition Red. Ambiguity resolves *upward* in restriction, never downward. "It's probably just internal" is a Red-tier statement.

The agent **may** deviate from the spec's proposed mechanism, and should, when a better approach emerges — *within* the bounds below. But the authority is bounded by what the change touches, not by how good the idea seems.

| Tier | Scope of change | Authority |
|---|---|---|
| **Green — proceed** | Internal implementation only. Same public interface, same acceptance criteria, same files. Better algorithm, cleaner structure, fewer dependencies. | Proceed without asking. Log the deviation in the commit message and append one line to `/state/DECISIONS.md`. |
| **Amber — propose, then proceed** | Changes the acceptance criteria, the public interface, or adds a dependency. Still within the feature's scope. | Stop. Write the proposal as a short diff against the spec: what changes, why it's better, what it costs. Proceed only on explicit approval. |
| **Red — stop** | Contradicts a locked decision in `DECISIONS.md`, changes the data model or file format, affects sync, alters another feature's behaviour, or expands scope beyond the spec. | Stop. Surface the conflict. Human decides. Never proceed unilaterally — this is how a session with degraded context destroys working work. |

**Every deviation, at any tier, is logged.** A green-tier change that is never recorded is indistinguishable from drift the next time a fresh session reads the code and finds it doesn't match the spec.

**The counter-rule that makes this safe:** improvement authority is granted for *how*, never for *whether*. An agent may propose a better mechanism for an accepted feature; it may not decide a feature is unnecessary, defer it, or substitute a different feature it finds more interesting. Scope belongs to the human.

**And a tripwire:** if a session proposes more than two Amber-or-above deviations, treat it as a signal the spec was wrong — stop building, fix the spec, restart the session. Repeated redesign pressure mid-implementation almost always means the specification was underdetermined, not that the model is being clever.

**Where deferred ideas go — `/state/PARKED.md`.** Deferral must not mean loss, or the precedence rule creates pressure to smuggle changes through as Green. Any Amber or Red idea that isn't approved on the spot gets one line in `PARKED.md`: what was proposed, which feature it touches, why it was deferred. It is reviewed at the next phase gate, from a clean session, with a proper spec if adopted. Cap: 100 lines.

This is what makes "drift protection wins" sustainable rather than merely restrictive — the agent is not being told its idea is bad, only that *now, mid-implementation, in a context of unknown quality* is the wrong moment to act on it. The idea is preserved; the timing is corrected.

**A note on why this rule exists at all.** A degraded session does not announce itself. It produces confident, fluent, plausible output — which is exactly what a good improvement proposal also looks like. There is no reliable way, from inside the session, to distinguish "I have found a better approach" from "I have lost the context that explains why the current approach was chosen." Since the two are indistinguishable in the moment, the only safe policy is to treat improvement pressure as suspect by default and route it through a clean session where the distinction can actually be made.

### 4.6 Definition of Done

A feature is done when *all* of these are true — not when the code runs:

1. Every acceptance criterion in the spec has a passing test.
2. Its named failure modes each have a test that would catch them.
3. Domain validators pass, and the deliberate-defect corpus still trips them.
4. The golden-document corpus round-trips unchanged.
5. `FEATURES.md` updated: 🔨 → ✅, with the file(s) implementing it.
6. Any deviation logged per 4.5.
7. Full CI suite green.

Anything short of all seven is 🔨, not ✅. **A feature marked ✅ that is not actually done is worse than one marked ⬜**, because the reconciliation gate (Part 1) will wave through work that depends on it.

---

## Part 5 — Revised Build Order

The blueprint's original Phase 1–4 ordering is *feature-logical* but not *risk-logical*. Reordered so that the things which de-risk everything else come first, and each stage is independently testable.

### Stage 0 — Scaffolding for the process itself (before any app code)
Build `/state/*.md`, the repo skeleton, the test harness, and CI. **Deliverable:** a fresh session can cold-boot in under 5K tokens and CI blocks a bad commit.
*Why first: this is the machinery that protects every later stage. Building it after you're already deep is too late.*

### Stage 0.5 — Paste healing (the calibration task)
The §2.4 transform set plus its fixture corpus. Pure string→string, zero UI, zero state, no platform APIs.
**Test:** the golden fixture suite passes; every ugly-paste sample in the corpus produces its expected output.
*Why here, before the vertical slice: this is the ideal task to calibrate your session process on. Success is objectively machine-verifiable, so the agent can iterate without you reviewing by eye — which is exactly the property that makes agentic work cheap (per Part 2.4's budget notes). It has no dependencies beyond the block model, it can't break anything else, and if your session discipline is going to fail, it fails here on a throwaway-cheap task rather than mid-way through the Typst FFI. Ship it, then judge the process before committing to Stage 1.*

**Note on the one risky transform:** dehyphenation must be lexicon-guarded. Naive rejoining destroys `low-voltage`, `star-delta`, `N+1`, `XLPE/SWA/PVC`. Build the protected-compound fixtures *first*, before the transform — they are the acceptance criteria, not an afterthought.

### Stage 1 — The vertical slice (thin end-to-end proof)
One document opens → renders → exports to PDF. Nothing else. No sync, no rules engine, no diagrams.
**Test:** open a `.md`, see it, export it, reopen it. **Why:** proves the riskiest integration (Typst FFI on both platforms) before any feature work depends on it. If Typst embedding fails on iOS, you learn it in week one, not month three.

### Stage 2 — File model + identity
Frontmatter, UUIDs, the link index, folder access on both platforms.
**Test:** rename a file, links still resolve. **Why:** everything downstream assumes stable IDs; retrofitting them later is a rewrite.

### Stage 3 — Editor + search
Distraction-free editing, outline, FTS5 search, table grid editor.
**Test:** usable for real writing. **Why:** first point the app is genuinely useful to you — start dogfooding here, which surfaces design problems no spec review would.

### Stage 4 — Snapshots + A3 log store
Version history, diff view, the append-only JSONL merge.
**Test:** edit on two devices offline, reconcile, no data loss. **Why:** the highest-risk architecture decision (A3) — prove it before glossary/citations depend on it.

### Stage 5 — Rules engine core + first validators
The AST pipeline, diagnostics panel, and the *structural* rules — the document-integrity validators from §3.2 first, then the narrower engineering ones.
**Why here:** these validators become your automated safety net for all later stages. Building them mid-project means everything before them was unchecked.

### Stage 6 — Diagrams: Mermaid + CeTZ + palette
Rendering pipeline, theme layer, pan/zoom canvas, SLD symbol library, and the **Tier 1–4 drag-and-drop palette**.
**Test:** drop a Tier 3 block, rename tags, export — and the Stage 5 validators catch a deliberately broken topology.

### Stage 7 — Live variables + unit system
§4.1 and §4.7, plus variable-driven figures.
**Why after diagrams:** the figures need something to bind to.

### Stage 8 — Glossary, citations, normative + contractual overlays
The language layers (§4.10, §4.11), riding on the Stage 5 engine.

### Stage 9 — Revision/issue tracking, compliance matrix, transclusion
The document-lifecycle features.

### Stage 10 — Repurposing, heat maps, redline export
The remaining reach items.

**Phase gates:** Stages 0, 1, 4, 5, and 6 get a Fable 5 / Opus 5 review of the accumulated diff before proceeding. Those are the five points where a wrong foundation is expensive to unwind. The rest can proceed on cheaper models plus CI.

---

## Part 6 — What Changes in the Blueprint

Add to `technical-writing-app-blueprint-v2.md`:
- §2.4 **Paste healing & provenance** (done) — pure transform, fixture-verified, built at Stage 0.5.
- §4.1a–4.1e **Friction-reduction features** (done) — inline calculator (expression preserved, explicit conversion syntax), engineering autocomplete, panel tag recognition, cable notation formatter, timestamp/decision-block/recent-values.
- §4.9 gains the **topology palette** (done — Tier 1–4 blocks, drag-and-drop, editable-text insertion).
- §8's phasing is superseded by Part 5 above; keep the blueprint's phases as *feature grouping*, use this document's stages as *build order*.
- A new §11 "Build Process" pointing at this document, so a fresh session reading the blueprint discovers the process rules.

---

## Part 7 — The One-Page Session Prompt

Paste this at the start of every build session, whatever the model:

```
PRECEDENCE: Drift protection outranks improvement. Always. If you are
unsure whether you are allowed to change something, you are not allowed.
Ambiguity resolves toward MORE restriction, never less.

Read /state/FEATURES.md, DECISIONS.md, REJECTED.md, PARKED.md, CURRENT.md,
and the spec at /specs/<feature>.md for the current task.

RECONCILIATION GATE — before proposing anything:
1. Does this already exist? (check FEATURES.md + codebase) → if yes, stop and say so.
2. Does it conflict with DECISIONS.md? → if yes, stop and surface the conflict.
3. Is it an improvement? State the benefit AND the cost.

Then restate the task in one sentence with its acceptance criteria from
the spec. Wait for confirmation before writing code.

WHILE BUILDING:
- Write the failure-mode tests BEFORE the implementation.
- Read only files the task touches. Do not survey the codebase.
- Do not improve adjacent code.

CHANGE AUTHORITY — if you find a better approach:
- GREEN (internal implementation only, same interface, same criteria):
  proceed, and log the deviation in the commit message + DECISIONS.md.
- AMBER (changes acceptance criteria, interface, or adds a dependency):
  STOP. Write it to PARKED.md. Do not implement it this session.
- RED (contradicts DECISIONS.md, changes data model/file format/sync,
  or affects another feature): STOP. Write to PARKED.md. Surface it.
- UNSURE which tier: treat as RED.

You may improve HOW a feature is built. You may not decide WHETHER it
is built, defer it, or substitute a different one.
If you propose a 3rd Amber+ deviation, stop entirely — the spec is
wrong, not the plan. Say so and end the session.

DEFINITION OF DONE — do not mark ✅ unless all are true:
every acceptance criterion has a passing test; every named failure mode
has a test; domain validators pass; deliberate-defect corpus still trips
them; golden documents round-trip unchanged; deviations logged; CI green.
Otherwise mark 🔨.

BEFORE ENDING: update FEATURES.md (with scores), DECISIONS.md,
REJECTED.md, PARKED.md, rewrite CURRENT.md with the next task, and commit.
```
