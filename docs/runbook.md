# Runbook: Building With the Gauntlet Loop

How to actually run this, from an existing codebase to shipped features.

---

## The two-layer model

| Layer | Isolates | Mechanism |
|---|---|---|
| **Gauntlet loop** | Context *between* tasks | Fresh `claude -p` process per task. Empty window every time. |
| **Subagents** | Context *within* a task | Heavy reading happens in a separate window; only the verdict returns. |

Without subagents, the reconciliation gate alone can burn 40% of a task's window reading state files and grepping the codebase — before any work starts. With them, that becomes a two-line answer coming back from a worker whose context you never pay for again.

---

# PART A — One-time setup

## Step 1 — Repo layout

```
YourRepo/
├── YourApp.xcodeproj
├── YourApp/
├── CLAUDE.md                    ← governs every session
├── gauntlet.sh                  ← the loop
├── docs/
│   ├── blueprint-v2.md
│   ├── build-plan.md
│   └── prompts.md
├── prompts/
│   └── gauntlet-task.txt        ← fed to each fresh agent
├── specs/                       ← one file per feature (Part 4.2)
├── state/                       ← the memory
├── scripts/
│   ├── validate.sh
│   ├── defect-corpus.sh
│   └── golden-roundtrip.sh
└── .claude/agents/              ← subagent definitions
```

```bash
mkdir -p prompts specs state scripts .claude/agents
chmod +x gauntlet.sh
```

**Do not add `state/`, `specs/`, `docs/`, or `.claude/` to the Xcode target.**

## Step 2 — Write the four subagents

Create these as Markdown with YAML frontmatter in `.claude/agents/`. Each gets its own context window; each returns a short verdict.

### `.claude/agents/reconciler.md`
```markdown
---
name: reconciler
description: Runs the reconciliation gate before any feature work. Use PROACTIVELY at the start of every build task, before writing code.
tools: Read, Grep, Glob
---

You answer one question and return a short verdict. You never write code.

Given a proposed feature:
1. Search state/FEATURES.md AND the actual source for this capability BY
   FUNCTION, not by name. A feature called "paste cleanup" is the same as
   "paste healing".
2. Check state/DECISIONS.md for any conflict.
3. Check state/REJECTED.md — was this already turned down?

Return EXACTLY this format, nothing more:

VERDICT: PROCEED | EXISTS | CONFLICT | REJECTED
EVIDENCE: <file:line or "none found">
DETAIL: <one sentence>

Bias toward EXISTS and CONFLICT. A false PROCEED causes duplicated work;
a false EXISTS costs one human glance. These are not equal errors.
```

### `.claude/agents/spec-tester.md`
```markdown
---
name: spec-tester
description: Writes failing tests from a spec's acceptance criteria and failure modes, before implementation exists.
tools: Read, Write, Bash
---

You write tests. You never write implementation code.

Read the named spec file. For EVERY acceptance criterion and EVERY entry
under "Failure modes", write a test.

Rules:
- Tests must FAIL right now. If a test passes before implementation, it is
  testing nothing — rewrite it.
- Failure-mode tests are the priority. They encode what "subtly wrong but
  plausible" looks like, which is what an LLM will actually produce.
- Never weaken an assertion to make it pass.

Return: the count of tests written, and confirmation that all fail.
```

### `.claude/agents/domain-checker.md`
```markdown
---
name: domain-checker
description: Specialist checker for electrical engineering content. Use ONLY when a change touches SLDs, ratings, or calculations — not on general document, editor, or Markdown work.
tools: Read, Grep, Bash
---

You check engineering validity in the subset of documents that contain
electrical content. Most work in this project does not — if the change is
to the editor, parser, export, or any Markdown handling, reply
"Out of scope" and stop.

When you are in scope, assume confident-but-wrong output is present and
hunt for it.

Known failure signatures — check every one:
- An ATS or transfer switch with fewer than two source inputs
- A busbar or device rated below the full-load current of its source
- A breaker breaking capacity below the bus PSCC
- Downstream protection set at or above its upstream device (loss of
  discrimination)
- A trip unit or relay specified for the wrong voltage class
- HV and LV values compared without the transformer turns ratio applied
- Units mixed within one declared system

Return EXACTLY:
VERDICT: PASS | FAIL
FINDINGS: <one line per issue, with file:line>

Report what is wrong. Do not fix it. Do not congratulate.
```

### `.claude/agents/gate-reviewer.md`
```markdown
---
name: gate-reviewer
description: Phase-gate diff review. Invoke manually at stage boundaries only.
tools: Read, Grep, Bash
---

You review a diff. You never write code.

Report in this order:
1. DRIFT — anything contradicting state/DECISIONS.md, a silent interface
   change, a renamed entity, or something from REJECTED.md reintroduced.
   Quote the line.
2. FALSE ✅ — features marked done that miss the Definition of Done. Check
   the tests EXIST and actually ASSERT the named failure modes.
3. DOMAIN — engineering validity of any electrical output.
4. PARKED — for each PARKED.md item: adopt / reject / defer, one line each.
5. SPEC HEALTH — did one spec generate repeated Amber deviations? Then it
   is underdetermined. Say what is missing.

Be blunt. A clean review that misses a real problem costs more than a harsh
one. Do not congratulate.
```

## Step 3 — Write the three gate scripts

These run in bash, outside any agent, so a confused agent cannot argue past them.

```bash
# scripts/validate.sh — domain validators over the repo's own .sld fixtures
# scripts/defect-corpus.sh — MUST exit 0 only when every seeded defect is caught
# scripts/golden-roundtrip.sh — known-good docs must render byte-identical
```

Seed `defect-corpus.sh` with real errors across the whole product, not just one feature area:

- **Document/Markdown level** (the majority — this is the product): a paste that rejoins `star-delta` into one word; a frontmatter block with a duplicate UUID; a wiki-link pointing at a renamed file; a table whose rows were destroyed by unwrapping; a clause number (`411.3.3`) stripped as if it were a page number; a document that fails to round-trip through export unchanged.
- **Electrical/diagram level** (narrower — applies only to documents containing diagrams): a single-input ATS; a 1000A busbar on a 1391A source; a superseded citation; a `shall` inside a NOTE.

**If these stop tripping, your validators went blind — that is the single most important check in the system.**

---

# PART B — First run

## Step 4 — Session 0: the audit

Interactive, not headless. You want to watch this one.

```bash
claude
```
Then paste the Session 0 prompt from `docs/prompts.md`.

It creates `state/FEATURES.md`, `DECISIONS.md`, `REJECTED.md`, `PARKED.md`, `GAP.md`, `CURRENT.md` — **from your code, never from the blueprint.**

## Step 5 — Read GAP.md yourself

This is the one step that cannot be delegated. Go straight to *"Already built, CONFLICTS with blueprint."*

For each conflict, decide: keep the code, or keep the blueprint. Then edit `DECISIONS.md` by hand — promote the surviving A1–A6 entries from `[proposed]` to `[locked]`.

**Nothing runs until this is done.** A gauntlet built on unresolved conflicts will confidently build the wrong thing at speed.

## Step 6 — Write the first spec

`specs/paste-healing.md`, using the Part 4.2 template. Fill in **Failure modes** honestly — for this one:

```
- Rejoins a legitimate compound: low-voltage, star-delta, N+1, XLPE/SWA/PVC
- Unwraps a genuine paragraph break as if it were a wrap
- Strips a clause number (411.3.3) mistaking it for a page number
- Destroys a table by unwrapping its rows
```

Then set `state/CURRENT.md` to this task.

## Step 7 — Single dry run

```bash
./gauntlet.sh 1
```

One task. Then stop and actually read what it did:

```bash
git log -1 --stat
git diff HEAD~1
cat state/CURRENT.md
```

**What you are checking:** did it write failure-mode tests first? Did it update state files? Is the commit message a real summary? Did it stay inside the task?

If any answer is no, fix the prompt or the spec — not the code. The loop is only as good as its instructions, and this is the cheapest moment to find that out.

---

# PART C — Running it

## Step 8 — Scale up gradually

```bash
./gauntlet.sh 3     # after one clean single run
./gauntlet.sh 5     # after a clean 3
```

Never jump straight to a long run. Each increase is a bet that the previous size was trustworthy.

## Step 9 — The daily rhythm

**Morning (2 min)**
```bash
git pull && cat state/CURRENT.md && cat state/PARKED.md
./gauntlet.sh 3
```

**When it halts** — read the last lines of the log. A halt is the system working:

| Halt | Meaning | Your action |
|---|---|---|
| PARKED.md grew | Agent hit Amber/Red — precedence rule fired | Decide: adopt, reject, or defer. This is the main one. |
| Tests red | Work already reverted | Read the failing test; usually the spec was ambiguous |
| Defect corpus not tripping | Validators weakened | **Investigate seriously.** Someone made a check blind. |
| No commit | Agent stuck or confused | Check `CURRENT.md` is a real, sized task |
| CURRENT.md unchanged | No handoff written | Usually a too-big task — split it |

**Evening (5 min)** — skim the day's diff, clear PARKED.md by deciding each item, write tomorrow's `CURRENT.md`.

## Step 10 — Phase gates

At Stages 0, 1, 4, 5, 6 — stop the loop and run an expensive review:

```bash
git tag stage-N-complete
claude --model opus
```
Then: `Use the gate-reviewer subagent to review git diff stage-{N-1}-complete..HEAD`

The subagent reads the whole diff in its own window and returns findings — your main session never carries it.

---

# Cost control

- **Gauntlet loop:** cheapest model that passes the gates. Start Sonnet; try DeepSeek V4 Pro on Stage 0.5's pure transforms and compare cost-per-*completed-task*, not per token.
- **Subagents share the parent's billing** — no separate cost, but they do consume tokens. `reconciler` and `domain-checker` are cheap (short outputs). Do not spawn subagents for work the main agent could do in two file reads.
- **Expensive models only at phase gates**, reading diffs.
- **`--max-turns 40`** is the runaway-cost circuit breaker. Lower it if tasks are small.

---

# The three rules that matter most

1. **Never start a run with a dirty tree or red tests.** The script enforces it; do not work around it.
2. **A halt is success, not failure.** The system stopping to ask is the entire point. Do not tune the stop conditions to make runs longer.
3. **Never weaken a gate to make a run pass.** If the defect corpus stops tripping, you have not fixed anything — you have removed the thing that would have told you.
