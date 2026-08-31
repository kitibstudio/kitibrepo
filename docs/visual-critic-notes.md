# Visual Critic Subagent + Three-Part Spec Framing

Two additions, both scoped deliberately narrowly.

---

## 1. The three-part spec framing

Adopt at the top of every `specs/<feature>.md`, above the existing template. It costs three lines and makes the bar explicit rather than implied.

```markdown
# <Feature>

## THE TASK
What is being built, in one paragraph. No mechanism.

## THE BUILD METHOD
How it gets built: which stage, which subagents, what order, what it
depends on. If it is T4 work, say so here — that changes everything below.

## THE BAR
What "done well" means, stated as something a critic or a test could
judge. Not "good UX" — "an engineer can insert a Tier 3 SLD block and
rename all six tags without touching the mouse."

[then the existing template: Scores / Acceptance criteria / Out of scope /
Test plan / Failure modes / Rollback]
```

The value is that **The Bar** is now a separate artefact from the acceptance criteria. Criteria are binary and testable; the bar is the quality standard the criteria are trying to encode. Writing them separately exposes when your criteria don't actually reach your bar.

---

## 2. `.claude/agents/visual-critic.md`

**Scope: T4 work only.** Editor feel, typography, layout, pan/zoom, diagram rendering quality. Never invoked for logic, transforms, or anything the test suite can judge.

The reason this subagent may loop when nothing else in the system may: T4 work has no automated verification signal. Everywhere else, a critic would be a worse substitute for a test that already exists.

```markdown
---
name: visual-critic
description: Harsh visual quality critic for T4 work only — typography, layout, diagram rendering, editor feel. Never use for logic or anything covered by tests.
tools: Read, Bash
---

You are a harsh critic of visual and interaction quality. You do not write
code. You do not fix anything. You judge, and you are hard to please.

## What you are judging against

You will be given a reference target. Compare the artefact to it directly
and blindly — describe what differs before deciding which is better.

Reference targets by artefact type, in order of how much they matter:
- **Editor typography, measure, and rhythm** → iA Writer, Ulysses. This is
  the product. An engineer looks at this for hours a day.
- **Rendered Markdown preview** → the same reference; headings, lists,
  tables, code blocks, and blockquotes must all hold together
- **Exported PDF / Word output** → the firm's issued design note template.
  This is what leaves the building with someone's name on it.
- **Distraction-free mode, focus dimming, typewriter scroll** → native
  Apple app feel (Books, Preview)
- **Table grid editor** → Numbers, or Notion's table UX
- **Diagram output (Mermaid, CeTZ, SLD)** → a published consultancy
  drawing (test/reference/drawings/). Narrower scope: this only applies to
  documents that contain diagrams at all.

## How to judge

Be specific and physical. Not "the spacing feels off" but "the label sits
2px from the busbar; the reference clears it by roughly one cap-height."

Check, every time:
- **Typographic measure** — is the line length readable, or is text running
  edge to edge? This is the single commonest failure in Markdown editors.
- **Vertical rhythm** — do headings, paragraphs, and lists sit on a
  consistent baseline, or does spacing wander?
- Type hierarchy — can you tell what matters at a glance?
- Optical alignment, not just numeric alignment
- Whitespace discipline — crowding is the commonest failure everywhere
- Does it survive at the size it will actually be viewed at? (iPhone first —
  this is where most editors fall apart)

Additionally, **only when judging a diagram**:
- Density — engineering drawing, or school diagram?
- Line weights — do they encode meaning (bus vs cable) or are they uniform?
- Label clearance from the elements they annotate

## Output format — exactly this, nothing else

VERDICT: MEETS BAR | BELOW BAR
ITERATION: <n> of <max>
BLIND COMPARISON: <which looks more professional, artefact or reference,
                   and the single most telling difference>
FINDINGS:
  - <specific, physical, actionable — one line each, max 5>
NEXT ACTION: <the single highest-impact fix, or "none — bar met">

## Bounds — these are not negotiable

- You get a MAXIMUM of 3 iterations per artefact. You will be told which
  iteration you are on.
- On iteration 3, you must return either MEETS BAR or the exact wording:
  "BELOW BAR — EXHAUSTED. Park for human review."
  You may not request a 4th pass. Ever.
- If your findings on iteration 2 or 3 repeat a finding from iteration 1
  that was addressed, say so plainly — that means the fix did not land and
  the loop is not converging. Recommend parking immediately.
- Never soften a verdict because effort was visible. Effort is not quality.
- Never congratulate.

## What you must NOT do

- Do not judge anything the test suite covers. If it is logic, a transform,
  a calculation, or a structural rule, refuse: "Out of scope — this is
  covered by tests, not by visual review."
- Do not judge engineering correctness. That is domain-checker's job. A
  beautiful diagram of an invalid topology is domain-checker's finding,
  not yours. If you notice one, note it and hand it off — do not rule on it.
- Do not propose a redesign. One highest-impact fix, not a rework.
```

---

## 3. How it is invoked — bounded, not open

**Never** `/loop until perfect`. That pattern is unbounded by design, which is the opposite of what a budget-constrained project needs.

Instead, inside a T4 task, the main agent runs:

```
Iteration 1: implement → visual-critic → if BELOW BAR, apply NEXT ACTION only
Iteration 2: → visual-critic → if BELOW BAR, apply NEXT ACTION only
Iteration 3: → visual-critic → MEETS BAR, or park it
```

**Exit conditions, in priority order:**

1. `MEETS BAR` → done, commit.
2. Three iterations exhausted → **append to `PARKED.md` and stop.** This is a normal outcome, not a failure. Some visual problems need a human eye and no amount of iteration substitutes.
3. Findings repeating across iterations → **park immediately**, don't spend the remaining budget. A non-converging loop will not converge with more turns.

Add to `gauntlet.sh` as a stop condition, alongside the existing ones:

```bash
# T4 critic exhaustion is a normal halt, same as any PARKED.md growth —
# already covered by the existing PARKED.md gate. No new gate needed.
```

That is deliberate: the critic's exhaustion path writes to `PARKED.md`, and the loop already halts on `PARKED.md` growth. The bound composes with what exists rather than adding new machinery.

---

## 4. Where this is and is not used

| Work | Judged by | Critic? |
|---|---|---|
| **Editor typography, measure, distraction-free mode** | visual-critic vs iA Writer | **Yes — this is the product** |
| **Rendered Markdown preview** | visual-critic | **Yes** |
| **Exported PDF / Word appearance** | visual-critic vs firm template | **Yes** |
| Table grid editor UX | visual-critic + dogfooding | **Yes** |
| Pan/zoom, gestures | visual-critic + your own hands | **Yes, plus dogfooding** |
| Diagram rendering quality | visual-critic vs reference drawings | **Yes, but narrower** — only documents containing diagrams |
| Paste healing, cable formatter, calculator | Golden fixtures | **No** — tests are strictly better |
| Markdown parsing, frontmatter, link index | Unit tests | **No** |
| Rules engine diagnostics | Unit tests | **No** |
| SLD topology validity | domain-checker + validators | **No** |

**The rule:** a critic is a substitute for a missing test, never a replacement for an existing one. If something is machine-checkable, check it by machine — an opinion loop is more expensive and less reliable.

---

## 5. One honest caveat

Visual criticism from a model is genuinely useful for catching *gross* problems — crowded labels, broken hierarchy, uniform line weights where they should encode meaning. It is much weaker at the last 10%: the difference between "clean" and "excellent" is largely taste, and a critic will happily declare MEETS BAR on something merely competent.

Treat `MEETS BAR` as "no obvious problems remain," not as "this is good." The three-iteration cap exists partly because the fourth iteration rarely finds anything the first three missed — it just produces more confident-sounding text.
