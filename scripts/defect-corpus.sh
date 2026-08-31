#!/usr/bin/env bash
# ============================================================================
# defect-corpus.sh — deliberate-defect gate (build-plan.md §4.4)
#
# TWO MODES (automatic, based on the directory argument):
#
#   GATE MODE (default, no arg, or explicit Tests/Fixtures/defect-corpus):
#     Expects exactly three named defect files and NOTHING ELSE in the
#     directory. Exits 0 when all three defects are confirmed present.
#     Exits non-zero if any expected defect is missing, undetectable, or
#     if the directory contains stray files.
#
#   SCAN MODE (any other directory):
#     Recursively scans every .md/.txt file for the three defect shapes.
#     Exits non-zero when ANY defect is found — this is the "both
#     directions" verification: run against the clean fixture corpus
#     (exit 0) and against each individual defect (exit non-zero).
#
# WHAT THIS DOES NOT DO
#   It does NOT call PasteHealer or any Swift code to decide (D26).
#   It reads the defect files and checks shapes directly, the way
#   scripts/validate.sh does for the golden fixture corpus.
# ============================================================================

set -uo pipefail

DEFECT_DIR="${1:-Tests/Fixtures/defect-corpus}"
DEFAULT_DIR="Tests/Fixtures/defect-corpus"
LEXICON="Sources/Core/PasteHealing/ProtectedCompounds.swift"

# Resolve the mode: gate mode when using the default defect-corpus dir.
if [[ "$DEFECT_DIR" == "$DEFAULT_DIR" ]]; then
  MODE="gate"
else
  MODE="scan"
fi

FAILURES=0
FOUND_DEFECTS=0

fail() { echo "  FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "  ok: $*"; }

echo "defect-corpus.sh: deliberate-defect checks ($MODE mode)"

# ---------------------------------------------------------------------------
# Preflight: the target must exist.
# ---------------------------------------------------------------------------
if [[ ! -d "$DEFECT_DIR" && ! -f "$DEFECT_DIR" ]]; then
  echo "  FAIL: no such file or directory: $DEFECT_DIR" >&2
  exit 1
fi

# If the argument is a single file, scan mode scans just that file.
if [[ -f "$DEFECT_DIR" ]]; then
  MODE="scan"
fi

# ---------------------------------------------------------------------------
# Helper: collect files recursively.
# ---------------------------------------------------------------------------
collect_files() {
  if [[ -f "$1" ]]; then
    # Single file: just echo it if it has a matching extension.
    case "$1" in
      *.md|*.txt) echo "$1" ;;
    esac
  else
    find "$1" -type f \( -name '*.md' -o -name '*.txt' \) | sort
  fi
}

# ---------------------------------------------------------------------------
# 1. Rejoined protected compound — "star-delta" → "stardelta", etc.
#    Build the set of rejoined forms by stripping hyphens from every
#    protected compound that contains them. A file that contains any of
#    these rejoined forms has the signature failure (criterion 3).
# ---------------------------------------------------------------------------
check_rejoined_compound() {
  local file="$1"
  local found=0

  if [[ -f "$LEXICON" ]]; then
    while IFS= read -r compound; do
      [[ -n "$compound" ]] || continue
      local rejoined="${compound//-/}"
      if [[ "$rejoined" != "$compound" ]] && grep -qF "$rejoined" "$file" 2>/dev/null; then
        echo "  caught: rejoined protected compound '$compound' → '$rejoined' in $(basename "$file")"
        found=1
        break
      fi
    done < <(sed -n '/static let compounds/,/\]/p' "$LEXICON" \
             | grep -oE '"[^"]+"' | tr -d '"')
  else
    fail "rejoined-compound: $LEXICON missing — cannot extract compounds"
  fi

  if (( found )); then
    FOUND_DEFECTS=$((FOUND_DEFECTS + 1))
  fi
  return $(( 1 - found ))   # 0=found, 1=not-found
}

# ---------------------------------------------------------------------------
# 2. Table destroyed by unwrap — rows merged into one paragraph.
#    A line carrying 3+ numeric values separated by runs of 2+ spaces but
#    with NO pipe characters is table data that should have been a markdown
#    table but was flattened by unwrap.
# ---------------------------------------------------------------------------
check_destroyed_table() {
  local file="$1"
  if grep -qE '^[^|]*[0-9]+([.][0-9]+)?[ ]{2,}[^|]*[0-9]+([.][0-9]+)?[ ]{2,}[^|]*[0-9]+([.][0-9]+)?' "$file" 2>/dev/null; then
    echo "  caught: table destroyed by unwrap in $(basename "$file")"
    FOUND_DEFECTS=$((FOUND_DEFECTS + 1))
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# 3. Clause number stripped as a page number — "411.3.3" deleted.
#    File contains clause-adjacent context but the specific clause number
#    that was stripped is absent. The context is the signature: text about
#    "Protection against electric shock" or a "411" heading without the
#    dotted sub-clause number that was eaten by stripArtefacts.
# ---------------------------------------------------------------------------
check_stripped_clause() {
  local file="$1"
  local has_context=0
  local has_number=0

  if grep -qF "Protection against electric shock" "$file" 2>/dev/null; then
    has_context=1
  fi
  if grep -qE '^411\.' "$file" 2>/dev/null; then
    has_context=1
  fi
  if grep -qF "411.3.3" "$file" 2>/dev/null; then
    has_number=1
  fi

  if (( has_context )) && ! (( has_number )); then
    echo "  caught: clause number stripped (411.3.3 absent) in $(basename "$file")"
    FOUND_DEFECTS=$((FOUND_DEFECTS + 1))
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Run checks
# ---------------------------------------------------------------------------
if [[ "$MODE" == "gate" ]]; then
  # GATE MODE: exact three named files, nothing else in the directory.
  EXPECTED_FILES=("rejoined-compound.md" "destroyed-table.md" "stripped-clause.md")

  all_files=()
  while IFS= read -r f; do
    all_files+=("$f")
  done < <(find "$DEFECT_DIR" -type f | sort)
  FILE_COUNT=${#all_files[@]}
  echo "  files in defect corpus: $FILE_COUNT"

  # Guard: must be exactly 3 files.
  if (( FILE_COUNT != 3 )); then
    echo "  directory contents:" >&2
    for f in "${all_files[@]}"; do
      echo "    $(echo "$f" | sed "s|^$DEFECT_DIR/||")" >&2
    done
    fail "defect corpus must contain exactly 3 files, found $FILE_COUNT"
  fi

  # Guard: every file must be one of the expected three.
  for f in "${all_files[@]}"; do
    bn=$(basename "$f")
    known=0
    for expected in "${EXPECTED_FILES[@]}"; do
      [[ "$bn" == "$expected" ]] && known=1 && break
    done
    if (( ! known )); then
      fail "unexpected file in defect corpus: $bn"
    fi
  done

  # Guard: every expected file must exist and be non-empty.
  for bn in "${EXPECTED_FILES[@]}"; do
    f="$DEFECT_DIR/$bn"
    if [[ ! -f "$f" ]]; then
      fail "expected defect file missing: $bn"
    elif [[ ! -s "$f" ]]; then
      fail "expected defect file empty: $bn"
    fi
  done

  # Check each defect.
  REJOINED="$DEFECT_DIR/rejoined-compound.md"
  TABLE="$DEFECT_DIR/destroyed-table.md"
  CLAUSE="$DEFECT_DIR/stripped-clause.md"

  [[ -f "$REJOINED" ]] && check_rejoined_compound "$REJOINED" \
    || fail "rejoined compound: no rejoined compound found in rejoined-compound.md"
  [[ -f "$TABLE" ]]    && check_destroyed_table "$TABLE" \
    || fail "destroyed table: no flattened table data found in destroyed-table.md"
  [[ -f "$CLAUSE" ]]   && check_stripped_clause "$CLAUSE" \
    || fail "stripped clause: no clause-411 context with missing 411.3.3"

  if (( FAILURES > 0 )); then
    echo "defect-corpus.sh: $FAILURES failure(s) — one or more defects not detected" >&2
    exit 1
  fi
  echo "defect-corpus.sh: all three defects confirmed present"
  exit 0
else
  # SCAN MODE: recursive scan, every .md/.txt file in the directory tree.
  files=()
  while IFS= read -r f; do
    files+=("$f")
  done < <(collect_files "$DEFECT_DIR")
  FILE_COUNT=${#files[@]}
  echo "  files scanned: $FILE_COUNT"

  # A scan that finds zero files exits non-zero — "nothing to check" is a
  # broken invocation, not a clean corpus (D19/D33).
  if (( FILE_COUNT == 0 )); then
    echo "  FAIL: no .md/.txt files found under $DEFECT_DIR — nothing to check" >&2
    exit 2
  fi

  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    check_rejoined_compound "$f"
    check_destroyed_table "$f"
    check_stripped_clause "$f"
  done

  if (( FOUND_DEFECTS > 0 )); then
    echo "defect-corpus.sh: $FOUND_DEFECTS defect(s) detected — validators NOT blind" >&2
    exit 1
  fi
  echo "defect-corpus.sh: no defects found (clean corpus)"
  exit 0
fi
