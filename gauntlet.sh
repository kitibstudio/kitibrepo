#!/usr/bin/env bash
# ============================================================================
# gauntlet.sh — autonomous build loop
#
# THE CORE IDEA
# Context drift is not managed, it is sidestepped. Each iteration spawns a
# FRESH agent process with an empty window. The agent never approaches its
# context limit because it only ever does one task. The loop, the gates, and
# the memory live out here in bash — where they cannot degrade.
#
# The agent is a disposable worker. This script is the foreman.
#
# USAGE
#   ./gauntlet.sh 5          # run up to 5 tasks then stop
#   ./gauntlet.sh 1          # single task (use this first)
#
# STOP CONDITIONS (any one halts the loop)
#   - Agent exits non-zero
#   - Tests red after the task
#   - Domain validators fail
#   - Deliberate-defect corpus stops tripping (validators went blind)
#   - Golden documents no longer round-trip
#   - PARKED.md grew (agent hit an Amber/Red — needs human judgement)
#   - CURRENT.md unchanged (no progress — likely stuck or confused)
#   - No commit made
# ============================================================================

set -uo pipefail

MAX_TASKS="${1:-1}"
LOG="gauntlet-$(date +%Y%m%d-%H%M%S).log"
MODEL="${GAUNTLET_MODEL:-sonnet}"

# ---------------------------------------------------------------------------
# Agent invocation. Swap this one function to change harness.
# ---------------------------------------------------------------------------
run_agent() {
  case "${GAUNTLET_AGENT:-hermes}" in
    hermes)
      # VERIFY THESE FLAGS against `hermes --help` before the first real run.
      # Requirements are only: (a) exits when done, (b) non-zero on failure,
      # (c) FRESH CONTEXT each invocation. If hermes cannot guarantee (c), do
      # not use this script — see the note below.
      hermes run \
        --model "${GAUNTLET_MODEL:-deepseek-v4-pro}" \
        --prompt-file prompts/gauntlet-task.txt \
        --once
      ;;
    claude)
      claude -p "$(cat prompts/gauntlet-task.txt)" \
        --model "${GAUNTLET_MODEL:-sonnet}" \
        --max-turns 40 \
        --output-format json \
        --allowedTools "Read,Edit,Write,Bash(xcodegen:*),Bash(xcodebuild:*),Bash(./scripts/validate.sh),Bash(git add:*),Bash(git commit:*),Bash(git diff:*),Bash(git status:*)"
      ;;
    *)
      echo "run_agent: unknown GAUNTLET_AGENT '${GAUNTLET_AGENT}'" >&2
      return 1
      ;;
  esac
}
# Hermes + DeepSeek: replace the body above with your harness's one-shot
# invocation, e.g.:
#   hermes run --model deepseek-v4-pro --prompt-file prompts/gauntlet-task.txt --once
# The only requirements are: (a) it exits when done, (b) it returns a
# non-zero exit code on failure, (c) each invocation starts a fresh context.
# If your harness cannot guarantee (c), do not use this script — you will be
# accumulating drift invisibly across iterations.

# ---------------------------------------------------------------------------
# Gates. These run OUTSIDE the agent, so a confused agent cannot talk its
# way past them. This is the whole point.
# ---------------------------------------------------------------------------
# Xcode unit-test bundle, not SwiftPM — there is no Package.swift (D16/D17).
# DEVELOPER_DIR is set explicitly because Xcode lives on an external volume here
# and xcode-select points at CommandLineTools, which cannot run xcodebuild.
# Override by exporting DEVELOPER_DIR before invoking this script.
: "${DEVELOPER_DIR:=/Volumes/Samsung 990 2TB/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

gate_tests() {
  if [[ ! -d "$DEVELOPER_DIR" ]]; then
    echo "gate_tests: DEVELOPER_DIR not found: $DEVELOPER_DIR" >&2
    echo "  Xcode is required to run tests. Export DEVELOPER_DIR to its Developer dir." >&2
    return 1
  fi
  # The TESTS no longer read the source tree — fixtures are copied into the test
  # bundle (D29), so TCC on ~/Documents cannot break them. This probe guards the
  # SHELL side: validate.sh does read the source tree, and if this process cannot
  # see it the validator gate would fail for a reason unrelated to the code.
  if ! head -c 1 Tests/Fixtures/paste-healing/web/input.txt >/dev/null 2>&1; then
    echo "gate_tests: this process cannot READ the fixture corpus in the repo." >&2
    echo "  The tests will still pass (they use the bundled copy), but validate.sh" >&2
    echo "  reads the source tree and will fail. Grant your terminal Full Disk" >&2
    echo "  Access, or move the repo out of ~/Documents." >&2
    return 1
  fi

  # MUST regenerate first. XcodeGen emits classic file references, NOT Xcode
  # synchronized groups, so a .swift file created on disk is NOT in the target
  # until this runs. Verified 2026-08-10: a deliberately failing test added
  # without regenerating was ignored entirely and this gate exited 0.
  if ! xcodegen generate >/dev/null 2>&1; then
    echo "gate_tests: xcodegen generate failed" >&2
    return 1
  fi
  # NOT -quiet: it suppresses the executed-test count, which would let a run that
  # executes ZERO tests exit 0 and pass this gate silently.
  local out
  out=$(xcodebuild test \
          -project Kitib.xcodeproj \
          -scheme KitibTests \
          -destination 'platform=macOS,arch=arm64' 2>&1) || { echo "$out" | tail -40; return 1; }
  # Refuse to go green on an empty suite — a gate that runs nothing is blind.
  if ! grep -qE "Executed [1-9][0-9]* test" <<<"$out"; then
    echo "gate_tests: TEST SUCCEEDED but zero tests executed — treating as failure" >&2
    return 1
  fi
  grep -E "Executed [0-9]+ test" <<<"$out" | tail -1
}
gate_validators() { ./scripts/validate.sh; }
gate_defects()    { ./scripts/defect-corpus.sh; }   # must FAIL to detect => exit 0 when all defects caught
gate_golden()     { ./scripts/golden-roundtrip.sh; }

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

halt() {
  log "════ HALT: $1 ════"
  log "Repo left at: $(git rev-parse --short HEAD)"
  log "Review $LOG, then fix and re-run."
  exit 1
}

# ---------------------------------------------------------------------------
# Preflight — never start from a dirty or broken baseline
# ---------------------------------------------------------------------------
log "Preflight"
[[ -z "$(git status --porcelain)" ]] || halt "working tree dirty — commit or stash first"
gate_tests    || halt "tests already red before starting"
gate_defects  || halt "defect corpus not tripping before starting — validators are blind"
log "Preflight OK. Baseline: $(git rev-parse --short HEAD)"

# ---------------------------------------------------------------------------
# The loop
# ---------------------------------------------------------------------------
for ((i=1; i<=MAX_TASKS; i++)); do
  log ""
  log "──── TASK $i/$MAX_TASKS ────"

  BEFORE_HEAD=$(git rev-parse HEAD)
  BEFORE_CURRENT=$(md5sum state/CURRENT.md | cut -d' ' -f1)
  BEFORE_PARKED=$(wc -l < state/PARKED.md)

  log "Task: $(head -3 state/CURRENT.md | tail -1)"

  # ---- fresh agent, fresh context ----
  if ! run_agent >> "$LOG" 2>&1; then
    halt "agent exited non-zero (max-turns overflow, or hard error)"
  fi

  # ---- G1: did it actually do anything? ----
  AFTER_HEAD=$(git rev-parse HEAD)
  [[ "$BEFORE_HEAD" != "$AFTER_HEAD" ]] || halt "no commit made — agent did not complete the task"

  # ---- G2: escalation check (before spending time on tests) ----
  AFTER_PARKED=$(wc -l < state/PARKED.md)
  if (( AFTER_PARKED > BEFORE_PARKED )); then
    log "PARKED.md grew — agent raised an Amber/Red deviation:"
    tail -n $((AFTER_PARKED - BEFORE_PARKED)) state/PARKED.md | tee -a "$LOG"
    halt "human judgement required (this is correct behaviour, not a failure)"
  fi

  # ---- G3–G6: the machine-checked gauntlet ----
  log "Gate: tests";      gate_tests      || { git reset --hard "$BEFORE_HEAD"; halt "tests red — work reverted"; }
  log "Gate: validators"; gate_validators || { git reset --hard "$BEFORE_HEAD"; halt "validators failed — work reverted"; }
  log "Gate: defects";    gate_defects    || { git reset --hard "$BEFORE_HEAD"; halt "defect corpus no longer trips — validators weakened, work reverted"; }
  log "Gate: golden";     gate_golden     || { git reset --hard "$BEFORE_HEAD"; halt "golden docs changed — work reverted"; }

  # ---- G7: did it hand off properly? ----
  AFTER_CURRENT=$(md5sum state/CURRENT.md | cut -d' ' -f1)
  [[ "$BEFORE_CURRENT" != "$AFTER_CURRENT" ]] || halt "CURRENT.md unchanged — no handoff written, next task undefined"

  log "✓ TASK $i PASSED — $(git log -1 --pretty=%s)"
  git tag -f "gauntlet-last-good"
done

log ""
log "════ GAUNTLET COMPLETE: $i-1 tasks passed ════"
log "Next: $(head -3 state/CURRENT.md | tail -1)"
log "Review the diff before the next run: git diff $(git rev-parse --short "$BEFORE_HEAD")..HEAD"
