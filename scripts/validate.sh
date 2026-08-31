#!/usr/bin/env bash
# ============================================================================
# validate.sh — document-integrity validators (build-plan.md §3.2)
#
# WHAT THIS COVERS
#   The paste-healing fixture corpus: that it is structurally sound, internally
#   consistent, and free of the corruption classes found on 2026-08-10.
#
# WHAT THIS DOES NOT COVER — read before trusting a pass
#   Criteria 8 (determinism) and 9 (idempotence) genuinely need Swift execution
#   (D26) and are covered by:
#     HealedStageTests.testHealIsDeterministicAcrossCorpus
#     HealedStageTests.testHealIsIdempotentAcrossCorpus
#     PasteHealerTests.testHealIsDeterministic / testHealIsIdempotent
#   Criterion 10 (clean input is a no-op) is covered by:
#     GoldenDocumentTests.testGoldenDocumentsRoundTripByteForByte
#     PasteHealerTests.testWellFormedMarkdownPassesThroughByteIdentical
#     scripts/golden-roundtrip.sh (structural gate — no excluded glyphs)
#   Engineering validators (SLD topology, ratings) do not exist yet.
#
# WHY THIS IS NOT JUST AN ECHO OF THE TESTS
#   It reads the fixtures WITHOUT running the implementation. A bug in
#   repairGlyphs cannot make these checks pass, and a corrupt fixture cannot
#   hide behind a matching expected.md. That independence is the point.
# ============================================================================

set -uo pipefail

CORPUS="Tests/Fixtures/paste-healing"
NAMES_SWIFT="Tests/KitibTests/PasteHealing/FixtureCorpus.swift"
FAILURES=0

fail() { echo "  FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "  ok: $*"; }

echo "validate.sh: paste-healing corpus integrity"

if [[ ! -d "$CORPUS" ]]; then
  echo "  FAIL: corpus directory missing: $CORPUS" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. On-disk directories must match FixtureCorpus.names exactly.
#    Empty leftover directories are invisible to git — this is the only place
#    outside CorpusTests that catches them.
# ---------------------------------------------------------------------------
if [[ -f "$NAMES_SWIFT" ]]; then
  DECLARED=$(sed -n '/static let names = \[/,/\]/p' "$NAMES_SWIFT" \
             | grep -oE '"[^"]+"' | tr -d '"' | sort)
  ONDISK=$(find "$CORPUS" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
  if [[ "$DECLARED" != "$ONDISK" ]]; then
    fail "corpus directories do not match FixtureCorpus.names"
    diff <(echo "$DECLARED") <(echo "$ONDISK") | sed 's/^/    /' >&2
  else
    pass "corpus directories match FixtureCorpus.names"
  fi
else
  fail "$NAMES_SWIFT missing — cannot verify the declared fixture list"
fi

# ---------------------------------------------------------------------------
# 2. Per-fixture checks
# ---------------------------------------------------------------------------
for dir in "$CORPUS"/*/; do
  name=$(basename "$dir")
  input="$dir/input.txt"

  [[ -f "$input" ]] || { fail "$name: input.txt missing"; continue; }
  [[ -s "$input" ]] || fail "$name: input.txt is empty"

  # Per-stage expected files (D27). Stage 1 is mandatory; later stages appear as
  # T2 and T3 land. Each stage ADDS a file — none is ever rewritten.
  [[ -f "$dir/expected-repairglyphs.md" ]] \
    || fail "$name: expected-repairglyphs.md missing (stage 1 is mandatory)"

  # Validate input.txt plus EVERY expected file present, whatever the stage.
  shopt -s nullglob
  stage_files=("$dir"expected*.md)
  shopt -u nullglob
  (( ${#stage_files[@]} > 0 )) || fail "$name: no expected*.md files at all"

  for expected in "${stage_files[@]}"; do
    base=$(basename "$expected")
    [[ -s "$expected" ]] || fail "$name: $base is empty"

    # A fixture whose expected output equals its input proves nothing.
    if cmp -s "$input" "$expected"; then
      fail "$name: input.txt and $base are identical — tests nothing"
    fi
  done

  # Both input and every expected file must be valid UTF-8.
  for f in "$input" "${stage_files[@]}"; do
    iconv -f UTF-8 -t UTF-8 "$f" >/dev/null 2>&1 \
      || fail "$name: $(basename "$f") is not valid UTF-8"
  done

  # Literal escape text, e.g. the six characters “ instead of the
  # character itself. This corrupted protected-compounds/input.txt when it was
  # written by a tool that did not interpret \u.
  for f in "$input" "${stage_files[@]}"; do
    if grep -qE '\\u[0-9a-fA-F]{4}' "$f"; then
      fail "$name: $(basename "$f") contains LITERAL \\uXXXX escape text — write real characters"
    fi
  done

  # Every expected file is post-repairGlyphs, so no mangled glyph may remain in
  # any of them. NBSP is included: it becomes a REGULAR space (D23), so a
  # surviving NBSP means the baseline still encodes the old deletion bug.
  for expected in "${stage_files[@]}"; do
  residue=$(perl -CSD -ne '
    my %bad = (
      "\x{FB01}" => "fi ligature",     "\x{FB02}" => "fl ligature",
      "\x{201C}" => "smart quote",     "\x{201D}" => "smart quote",
      "\x{201E}" => "smart quote",     "\x{201F}" => "smart quote",
      "\x{2018}" => "smart quote",     "\x{2019}" => "smart quote",
      "\x{2014}" => "em dash",         "\x{2013}" => "en dash",
      "\x{2010}" => "U+2010 hyphen",   "\x{2011}" => "U+2011 hyphen",
      "\x{00A0}" => "non-breaking space", "\x{200B}" => "zero-width space",
      "\x{00C2}" => "mojibake A-circumflex",
      "\x{00CE}" => "mojibake I-circumflex",
    );
    for my $c (keys %bad) { print "$bad{$c}\n" if index($_, $c) >= 0 }
  ' "$expected" | sort -u | tr '\n' ' ')
    [[ -z "$residue" ]] || fail "$name: $(basename "$expected") still contains: $residue"
  done
done

# ---------------------------------------------------------------------------
# 3. Protected compounds must appear byte-identical wherever they appear.
#    A compound written with U+2010 instead of '-' is NOT the compound — that
#    defect (D24) sat undetected behind seventeen passing tests.
# ---------------------------------------------------------------------------
LEXICON="Sources/Core/PasteHealing/ProtectedCompounds.swift"
if [[ -f "$LEXICON" ]]; then
  compounds=$(sed -n '/static let compounds/,/\]/p' "$LEXICON" \
              | grep -oE '"[^"]+"' | tr -d '"')
  while IFS= read -r c; do
    [[ -n "$c" ]] || continue
    # Build the same string with U+2010 in place of '-' and reject it.
    bad=${c//-/‐}
    if [[ "$bad" != "$c" ]] && grep -rqF "$bad" "$CORPUS"/*/expected*.md 2>/dev/null; then
      fail "protected compound '$c' appears with U+2010 HYPHEN in an expected file"
    fi
  done <<< "$compounds"
  pass "protected compounds carry no U+2010 variants in expected outputs"
else
  fail "$LEXICON missing — cannot verify protected compounds"
fi

# ---------------------------------------------------------------------------
if (( FAILURES > 0 )); then
  echo "validate.sh: $FAILURES failure(s)" >&2
  exit 1
fi
echo "validate.sh: corpus integrity OK"
exit 0
