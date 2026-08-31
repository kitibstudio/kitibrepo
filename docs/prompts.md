# Session Prompts

Copy-paste prompts for each session type. Keep at `docs/prompts.md`.

**Key difference between harnesses:**
- **Claude Code** loads `CLAUDE.md` automatically. Prompts can be short and point at it.
- **Hermes + DeepSeek** (and most other harnesses) do **not**. The prompt must tell it to read `CLAUDE.md` first *and* inline the critical rules, because a cheaper model will not reliably follow a pointer to a file it hasn't been forced to read.

---

# 1. SESSION 0 — The Audit

Run this **once**, before any build work. It writes no application code.
Use a cheap model — this is file reading and summarising.

### Claude Code

```
Read CLAUDE.md, then docs/blueprint-v2.md and docs/build-plan.md (Part 1 and Part 5 only).

TASK: Audit this existing codebase and create /state/. Write NO application code.

Populate /state/ from EVIDENCE IN THE CODEBASE, not from the blueprint.
The blueprint describes what we WANT. FEATURES.md must record what EXISTS.
If you seed it from the spec, the reconciliation gate becomes worthless.

Step 1 — Survey the Swift sources. For each capability, open the file and
confirm it actually works. Do not infer from filenames.

Step 2 — /state/FEATURES.md
  ✅ <capability> — <file(s)> — <one-line note on completeness>
  Use 🔨 for partial or stubbed. List ONLY what you found in code.
  An almost-empty file is a correct result if the codebase is early.
  Cap 200 lines.

Step 3 — /state/DECISIONS.md
  Architectural decisions ALREADY MADE IN CODE (persistence, file storage,
  view layer, any FFI, third-party deps). Mark each [from-code].
  Then append the blueprint's A1–A6, each marked [proposed] — NOT locked,
  because some may conflict with what exists. Cap 150 lines.

Step 4 — /state/GAP.md   ← the important one
  ## Already built, matches blueprint
  ## Already built, CONFLICTS with blueprint
  ## In blueprint, not built
  For each conflict: what the code does, what the blueprint proposes, which
  you'd keep and why (one line). Do NOT resolve them. I decide. Cap 150 lines.

Step 5 — /state/REJECTED.md
  Seed from blueprint §9 non-goals and §4.9 exclusions: PlantUML, Kroki,
  D2 (parked), synced live SQLite, git-on-iOS, generative AI in-product.
  One line each with the reason. Cap 100 lines.

Step 6 — /state/PARKED.md — create empty with a header.

Step 7 — /state/CURRENT.md
  Task: "Await human review of GAP.md before any build work." Nothing else.

RULES:
- Report what you find, not what should exist.
- If you cannot confirm a capability works, mark it 🔨 not ✅.
- Do not modify any Swift file.
- Do not add /state/ or /docs/ to the Xcode target.
- Finish by printing: features found, conflicts found.
```

### Hermes + DeepSeek

Same as above, but **prepend**:

```
FIRST: read CLAUDE.md in the repository root and follow it for this and
every future session. It is the governing document.

Critical rules, repeated here because they are not optional:
- Drift protection outranks improvement. Always.
- If unsure whether you may change something, you may not.
- The repository is the memory. Anything only in this chat is lost.
- Do not survey the whole codebase. Read only what the task names.

[then paste the Session 0 task above]
```

---

# 2. RECURRING — Every build session

### Claude Code

```
Follow CLAUDE.md.

Read /state/FEATURES.md, DECISIONS.md, REJECTED.md, PARKED.md, CURRENT.md,
and /specs/<feature>.md for the current task.

Restate the task in one sentence with its acceptance criteria, then stop
and wait for my confirmation before writing any code.
```

That is deliberately short — `CLAUDE.md` carries the rest.

### Hermes + DeepSeek

```
FIRST: read CLAUDE.md in the repository root. It governs this session.

Then read /state/FEATURES.md, DECISIONS.md, REJECTED.md, PARKED.md,
CURRENT.md, and /specs/<feature>.md for the current task.

PRECEDENCE: Drift protection outranks improvement. Always. If you are
unsure whether you may change something, you may not. Ambiguity resolves
toward MORE restriction.

GATE — before proposing anything:
1. Does this already exist? (FEATURES.md + code) → if yes, stop, say so.
2. Does it conflict with DECISIONS.md? → if yes, stop, surface it.
3. Is it an improvement? State the benefit AND the cost.

Restate the task in one sentence with its acceptance criteria.
STOP. Wait for my confirmation before writing code.

WHILE BUILDING:
- Write the failure-mode tests BEFORE the implementation.
- Read only files the task names. Do not survey the codebase.
- Do not improve adjacent code. Do not rename existing entities.

CHANGE AUTHORITY:
- GREEN (internal only, same interface, same criteria) → proceed, log it.
- AMBER (changes criteria/interface, or adds a dependency) → STOP, write
  to PARKED.md, do not implement this session.
- RED (contradicts DECISIONS.md, changes data model/file format/sync, or
  affects another feature) → STOP, write to PARKED.md, surface it.
- UNSURE → treat as RED.
You may improve HOW. You may not decide WHETHER, defer, or substitute.
Third Amber+ deviation → stop entirely, the spec is wrong. Say so.

DONE means ALL of: every acceptance criterion has a passing test; every
named failure mode has a test; validators pass; the deliberate-defect
corpus still trips them; golden docs round-trip; deviations logged; CI
green. Otherwise mark 🔨, not ✅.

BEFORE ENDING: update FEATURES.md, DECISIONS.md, REJECTED.md, PARKED.md,
rewrite CURRENT.md with the next task, and commit.
```

---

# 3. PHASE GATE — Expensive-model review

Run at Stages 0, 0.5, 1, 4, 5, 6. Reviews a **diff**, does not write code.
Use Opus 5 or Fable 5.

```
You are reviewing, not building. Write no code.

Read CLAUDE.md, /state/*.md, and the diff since the last phase gate
(git diff <last-gate-tag>..HEAD).

Report, in this order:

1. DRIFT — anything in the diff that contradicts DECISIONS.md, silently
   changed an interface, renamed an entity, or reintroduced something in
   REJECTED.md. Quote the specific line.

2. FALSE ✅ — any feature marked done in FEATURES.md that does not meet
   the full Definition of Done. Check the tests actually exist and
   actually assert the named failure modes.

3. DOCUMENT CORRECTNESS — does the change preserve document integrity?
   Round-trip fidelity, stable IDs, link resolution, no silent meaning
   loss in text transforms. This is the primary risk in a writing app.
   Only where the change touches engineering content (SLDs, ratings,
   calculations) additionally check real engineering validity.
   In both cases assume confident-but-wrong output is present.

4. PARKED REVIEW — for each item in PARKED.md: adopt, reject, or defer
   again, with one line of reasoning.

5. SPEC HEALTH — did the same spec generate repeated Amber deviations?
   If so the spec is underdetermined; say what is missing.

Be blunt. A clean review that misses a real problem costs more than a
harsh one. Do not congratulate.
```

---

# 4. Between sessions — the human's 30 seconds

1. Read the diff. Not all of it — the parts touching locked decisions.
2. Check `FEATURES.md` — is anything newly ✅ that you don't believe?
3. Check `PARKED.md` — anything worth pulling forward?
4. `/clear` before the next task.

**Never start a new task in a window that already ran a task.**
