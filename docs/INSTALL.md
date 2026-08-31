# Install — what goes where, and who reads it

## Who reads what

| File | Read by | How |
|---|---|---|
| `CLAUDE.md` | **Agent** | Auto-loaded every session |
| `prompts/gauntlet-task.txt` | **Agent** | Piped in by `gauntlet.sh` |
| `.claude/agents/*.md` | **Agent** | Auto-routed by their `description` field |
| `specs/*.md` | **Agent** | Read when the task names one |
| `state/*.md` | **Agent** | Read every session |
| `docs/blueprint-v2.md` | **Agent** | Only the section a task names — never in full |
| `docs/build-plan.md` | **Agent** | Same |
| `docs/runbook.md` | **You** | Your operating manual. No AI reads it. |
| `gauntlet.sh`, `scripts/*.sh` | **Neither** | Executed by bash, not read as prose |

The distinction matters: agent-read files are *instructions* and must be
short and imperative. Human-read files are *explanations* and can be long.
Mixing them wastes context.

---

## Who creates what

**You create the Xcode project once. The agent fills it in from then on.**

Xcode 16+ uses **file-system-synchronized folders** by default: a `.swift`
file the agent writes to disk inside the source folder appears in the
project automatically, with no `project.pbxproj` edit. That removes the main
corruption risk. Check the navigator — **blue folder icons mean
synchronized**; yellow means the old group style, where every file addition
rewrites the project file. If yours are yellow, right-click the folder and
convert it before starting.

### Step 1 — You, in Xcode, once

1. **New Project → Multiplatform → App** — one target covering macOS and
   iOS/iPadOS
2. **Add a Unit Testing Bundle target.** Do not skip this: `gauntlet.sh`
   preflight runs `swift test` and halts if it fails, so the loop cannot
   start without a working test target
3. Set bundle ID, deployment targets, signing
4. Confirm the source folder is **synchronized** (blue icon)
5. Build once, run the empty test suite once — both must be green
6. `git init && git add -A && git commit -m "Xcode skeleton"`

That skeleton is your baseline. The gauntlet refuses to start from a dirty
tree or red tests, so this commit matters.

### Step 2 — The agent, from then on

Freely, inside the synchronized source folder:

- Create `.swift` files and subdirectories
- Create test files
- Create resources, fixtures, reference corpora
- Refactor, split, and move files within the folder

### Never the agent — these stay yours

| Change | Why |
|---|---|
| Add / remove a **target** | Rewrites `project.pbxproj` |
| **Build settings**, capabilities, entitlements | Project-level, GUI-managed |
| **`Info.plist`** keys (incl. iOS launch screen) | Fragile, and often signing-adjacent |
| Add a **Swift Package dependency** | Also requires Amber approval anyway (§4) |
| Signing / provisioning | Never automatable safely |

These are rare — a handful of GUI actions across the whole project. The
agent is instructed to treat any of them as **RED**: park it, stop, and let
you do it in two minutes. A parked request costs two minutes; a corrupted
`project.pbxproj` costs an afternoon.

**Optional alternative:** if you'd rather the agent manage project structure
too, XcodeGen or Tuist turn the project into a `project.yml` it can safely
edit and regenerate. That changes how you work day to day, so only take it
if you already prefer generated projects.

---

```bash
# From the folder containing the delivered files:
mkdir -p .claude/agents prompts specs state scripts docs captures

cp CLAUDE.md                    ./                    # repo root
cp gauntlet.sh                  ./
cp gauntlet-task.txt            prompts/
cp agents/*.md                  .claude/agents/
cp scripts/capture.sh           scripts/
cp runbook.md                   docs/
cp technical-writing-app-blueprint-v2.md  docs/blueprint-v2.md
cp build-plan-context-resilient.md        docs/build-plan.md
cp prompts.md                   docs/

chmod +x gauntlet.sh scripts/capture.sh
echo "captures/" >> .gitignore
```

**Do not add `state/`, `specs/`, `docs/`, `.claude/`, or `captures/` to the
Xcode target.** They would be bundled into the app binary as resources.

Verify the agents registered:

```bash
claude
/agents
```

You should see `reconciler`, `spec-tester`, `domain-checker`,
`visual-critic`, `gate-reviewer`.

---

## Set up the visual critic's references

The critic compares against something. Without reference images it has no
bar to judge against and will drift toward "looks fine to me."

```bash
mkdir -p test/reference/drawings
```

Put in `test/reference/`:
- A screenshot of iA Writer or Ulysses with a real document open
- One of your firm's issued design notes, exported as PNG
- In `drawings/`: a published consultancy SLD or riser drawing

These are the only things standing between "harsh critic" and "agreeable
critic." Spend ten minutes getting good ones.

---

## How a visual-critic task actually runs

This is the loop the main agent runs inside a T4 task. It is bounded — three
iterations, then park.

```
1. Implement the change.
2. Build and launch:      swift build && open ./YourApp.app
3. Capture:               ./scripts/capture.sh all
   → captures/latest-mac.png, captures/latest-iphone-se.png
4. Invoke the critic:

   "Use the visual-critic subagent. Iteration 1 of 3.
    Artefact: captures/latest-mac.png and captures/latest-iphone-se.png
    Reference: test/reference/ia-writer.png
    Judging: editor typography and vertical rhythm."

5. If BELOW BAR → apply NEXT ACTION only (not all findings), then repeat
   from step 2 with "Iteration 2 of 3".
6. On MEETS BAR → commit.
   On iteration 3 without MEETS BAR → append to state/PARKED.md and stop.
   On a repeated finding → park immediately, do not spend iteration 3.
```

**Why the capture step is not optional:** the critic's prompt makes it
refuse to judge without an image, returning `CANNOT JUDGE`. That refusal is
deliberate — a visual verdict inferred from source code is worse than no
verdict, because it sounds equally confident.

**Why only the NEXT ACTION is applied:** applying all five findings at once
means you cannot tell which one moved the needle, and it invites a rewrite
rather than a fix.

---

## Where the critic fits in the gauntlet

It doesn't run automatically, and that is intentional.

`gauntlet.sh` runs unattended, and its gates are all machine-checkable —
tests, validators, defect corpus, golden documents. Visual work has no such
signal, which is exactly why the critic exists and exactly why it cannot be
a gate in an unattended loop.

**T4 tasks are run interactively, not through `gauntlet.sh`.** The build
plan already says this: *"T4 work is never delegated to a cheap model in a
long loop."* The critic makes T4 work *better*, not autonomous.

The exhaustion path still integrates cleanly: a parked critic finding writes
to `state/PARKED.md`, and the next `gauntlet.sh` run halts on PARKED.md
growth — so the loop notices without needing a new gate.

---

## First run order

0. Xcode skeleton created, test target added, builds green, committed
   (see "Who creates what" above)
1. `claude` → Session 0 audit prompt (from `docs/prompts.md`)
2. Read `state/GAP.md` yourself, resolve conflicts, lock decisions
3. Write `specs/paste-healing.md`
4. `./gauntlet.sh 1` — one task, then read the diff
5. Only then scale up
