# CLAUDE.md

Project instructions. Loaded automatically at the start of every session.

---

## 0. PRECEDENCE — read first

**Drift protection outranks improvement. Always. Without exception.**

If you are unsure whether you are permitted to change something, you are not permitted. Ambiguity resolves toward **more** restriction, never less.

A deferred good idea costs a delay. An accepted bad one costs silent corruption of work already paid for, often undetected for weeks. These are not comparable risks and are never weighed against each other.

**The repository is the memory. You are not.** Anything that exists only in this conversation is lost when the session ends.

---

## 1. What this project is

A cross-platform (macOS / iPadOS / iOS) local-first Markdown writing environment for engineering documentation — design notes, reports, specs, and single-line diagrams. SwiftUI, deterministic, **no generative AI in the product itself**.

Full spec: `docs/blueprint-v2.md`
Build process: `docs/build-plan.md`

Do not read either in full. Read the section named in the current task.

UI rules: `docs/ui-conventions.md` — **read this one in full before building or
changing any view.** It is short, it is locked, and every rule in it was paid
for by a defect that shipped. UI here is not covered by the test suite (D16), so
those conventions are the only standing guard on it.

---

## 2. Session start — do this every time

1. Read `/state/FEATURES.md`, `DECISIONS.md`, `REJECTED.md`, `PARKED.md`, `CURRENT.md`.
2. Read `/specs/<feature>.md` for the current task only.
3. If the task touches any view, read `docs/ui-conventions.md` in full.
4. Read **only** the source files that task touches.
5. Restate the task in one sentence with its acceptance criteria. **Wait for confirmation before writing code.**

**Do not survey the codebase to "get oriented."** That is how the window fills before work starts.

---

## 3. The reconciliation gate — before proposing anything

| | Question | If yes/no |
|---|---|---|
| Q1 | Does this already exist? (check `FEATURES.md` + code, by function not by name) | If yes → **stop**, say so, build nothing |
| Q2 | Does it conflict with `DECISIONS.md`? | If yes → **stop**, surface the conflict |
| Q3 | Is it an improvement? State benefit **and** cost | If no clear benefit → **stop**, log to `REJECTED.md` |

---

## 4. Change authority

You may improve **how** a feature is built. You may **not** decide **whether** it is built, defer it, or substitute a different one. Scope belongs to the human.

- **GREEN** — internal implementation only; same interface, same acceptance criteria, same files. → Proceed. Log the deviation in the commit message and one line in `DECISIONS.md`.
- **AMBER** — changes acceptance criteria, changes a public interface, or adds a dependency. → **Stop. Write it to `PARKED.md`. Do not implement it this session.**
- **RED** — contradicts `DECISIONS.md`, changes the data model or file format, touches sync, or affects another feature's behaviour. → **Stop. Write to `PARKED.md`. Surface it.**
- **UNSURE which tier** → treat as RED.

If you propose a **third** Amber-or-above deviation in one session: stop entirely. The spec is wrong, not the plan. Say so and end the session.

---

## 5. While building

- **Write the failure-mode tests before the implementation.** The spec's *Failure modes* section is the list.
- Do not improve adjacent code.
- Do not rename existing entities. Exact identifiers only — `blockID` is not `blockId`.
- If the test suite was green at session start, it must be green at session end. A red suite means the work is **rejected**, not debugged into submission.

---

## 6. Definition of Done

Mark ✅ only when **all** are true. Otherwise 🔨.

1. Every acceptance criterion has a passing test
2. Every named failure mode has a test that would catch it
3. Domain validators pass
4. The deliberate-defect corpus still trips the validators
5. Golden documents round-trip unchanged
6. Deviations logged per §4
7. Full CI green

A feature wrongly marked ✅ is worse than one marked ⬜ — the reconciliation gate will then wave through work depending on it.

---

## 7. Session end — checkpoint before you stop

1. Update `FEATURES.md` (status + scores + implementing files)
2. Append any ruling to `DECISIONS.md`
3. Append any rejected approach to `REJECTED.md`
4. Append any deferred idea to `PARKED.md`
5. Rewrite `CURRENT.md` with the **next** task and any gotchas found
6. Commit — the message is the session summary

A session that ends without 1–5 has put its work at risk. The checkpoint is part of the task, not admin.

---

## 8. Context management

**Stop and checkpoint immediately if any of these occur:**

- `[Context compacted]` appears — **compaction is a session-ending event, not a continuation.** The summary is lossy and is exactly the drift this file exists to prevent.
- You rewrite something already working, or reintroduce something in `REJECTED.md`
- You contradict `DECISIONS.md` without flagging it
- You invent new names for existing entities
- You reference a file or function that does not exist
- You start improving code the task did not name
- Your summary of your own work is vague rather than specific

**Do not push through a tripwire.** Checkpoint, `/clear`, start fresh. Restarting is always cheaper than repairing a degraded context.

**Run `/clear` at every task boundary**, before compaction can fire. One task per session. If a task cannot be described in ~10 lines of acceptance criteria, it is too big — split it.

---

## Compact Instructions

If compaction runs, preserve these above all else:

1. The precedence rule (§0): drift protection outranks improvement, ambiguity resolves toward restriction.
2. The exact task from `CURRENT.md` and its acceptance criteria.
3. Every locked decision referenced this session, verbatim, and the fact that it is locked.
4. The change-authority tier of any deviation raised, and that Amber/Red were parked rather than implemented.
5. Exact entity names as they appear in the code — never paraphrase or normalise an identifier.
6. Which tests were passing at session start.

Discard exploratory reasoning, file-read output, and superseded drafts in preference to any of the above.

**After compaction, re-read `/state/*.md` before continuing** — then checkpoint and end the session.

---

## 9. Document correctness

This app emits documents that get **issued**. Software-correct is not the same as correct.

**The primary risk is document integrity** — the things that make a writing tool trustworthy:

- Text that round-trips: what was written is what exports, byte for byte
- Paste healing that repairs damage without destroying meaning (a rejoined `star-delta` is a silent corruption)
- Stable IDs that survive renames; links that resolve
- Frontmatter that parses; tables that survive editing
- No data loss on save, sync, or snapshot restore

**A narrower, specialist risk** applies to documents containing engineering content — SLDs, ratings, calculations — where output can be structurally valid and professionally wrong (a diagram with a plausible topology that is electrically invalid). Domain validators cover this subset; they are not a general gate.

Both classes share one property: **confident-but-wrong output that looks fine.** Assume you will produce it and cannot see it. That is what the validators, golden documents, and deliberate-defect corpus are for — **never weaken or bypass them to make a change pass.**

---

## 10. Build environment

- Swift / SwiftUI, single codebase for macOS + iOS/iPadOS
- `/state/`, `/specs/`, `/docs/`, `/.claude/`, `/captures/` are **not** in the Xcode target — never add them
- Files are plain Markdown on disk and remain readable without the app
- Never add a dependency without Amber approval (§4)

### Project-level changes are RED — never attempt them

**Never hand-edit `project.pbxproj`, `.xcodeproj`, `.xcworkspace`, `Info.plist`, `.entitlements`, or `Package.swift` dependency declarations.**

This project is generated by **XcodeGen** from `project.yml` (D1). `Kitib.xcodeproj` is a build artefact: anything typed into it is destroyed the next time `xcodegen generate` runs. `project.yml` is the only project file anyone edits, and editing it is still gated by the RED list below.

**Creating a `.swift` file on disk is NOT enough.** XcodeGen emits *classic* file references, not Xcode synchronized groups, so a new file belongs to no target until you run:

```
xcodegen generate
```

Skipping this does not fail loudly — it fails silently and looks like success. A test you wrote but did not regenerate is never compiled, the suite still exits `0`, and the run reports green having tested nothing. This is verified, not theoretical (D22), and it is how T1 shipped four bugs behind seventeen passing tests. **After creating any `.swift` file: regenerate, then confirm the `Executed N tests` count actually went up.**

If a task appears to require any of the following, it is **RED** — write it to `state/PARKED.md`, commit whatever is already green, and stop:

- Adding or removing a target
- Changing build settings, capabilities, or entitlements
- Adding or editing an `Info.plist` key (including launch screen configuration)
- Adding a Swift Package dependency
- Anything touching signing or provisioning

These are human decisions. In this project they are carried out by editing `project.yml` and re-running `xcodegen generate` — not in the Xcode GUI, and never by hand-editing the generated project. They are rare, and they change how every target builds. **A parked request costs a two-minute edit. A wrong one is discovered weeks later.**

You may freely create `.swift` files, subdirectories, test files, fixtures, and resources inside `Sources/` and `Tests/`. That is your territory — provided you regenerate afterwards.

### Running the tests

```
xcodegen generate
export DEVELOPER_DIR="/Volumes/Samsung 990 2TB/Applications/Xcode.app/Contents/Developer"
xcodebuild test -project Kitib.xcodeproj -scheme KitibTests -destination 'platform=macOS,arch=arm64'
```

- Xcode lives on an **external volume**, and `xcode-select` points at CommandLineTools, which cannot run `xcodebuild` (D18). If the volume is unmounted, testing is impossible — say so and stop rather than skipping the gate.
- **Never add `-quiet`.** It suppresses the executed-test count, and a run that executes *zero* tests still exits `0` (D19).
- `KitibTests` is a logic-test bundle with no app host. It compiles `Sources/Core` directly, so it never builds SwiftTerm or any UI layer. Anything requiring `AppState`, the editors, or export is **not** testable there by design (D16).

### A green suite is not a verified one

`scripts/defect-corpus.sh` and `golden-roundtrip.sh` are still stubs that `exit 0` unconditionally. Two of `gauntlet.sh`'s four gates therefore prove nothing. `gate_tests` and `validate.sh` are real. Do not read a clean gauntlet run as full verification until the other two are implemented.

`validate.sh` checks the fixture corpus **without running the implementation**, so a bug in the Swift cannot make it pass. Keep it that way: a validator that calls the code it is validating is an echo, not a check.

**Fixtures that no test loads are not coverage.** A corpus written to disk and never read reports as thoroughness and delivers nothing — that is exactly what T1 did. Every fixture must be loaded and compared by a test, and a test named `…Fixture…` must actually open a file.
