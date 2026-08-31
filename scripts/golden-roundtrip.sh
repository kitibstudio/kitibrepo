#!/usr/bin/env bash
# ============================================================================
# golden-roundtrip.sh — golden-document corpus integrity gate
# (build-plan.md §4.4)
#
# WHAT THIS COVERS
#   The golden-document corpus at Tests/Fixtures/golden-documents/: that it
#   exists, contains well-formed documents, and carries no characters that a
#   healing pass would legitimately change.
#
# WHAT THIS DOES NOT COVER — read before trusting a pass
#   The actual round trip. Criterion 10 ("clean input is a no-op") requires
#   executing PasteHealer.heal, which is Swift. That assertion lives in
#   GoldenDocumentTests.swift, not here — this script checks corpus integrity
#   WITHOUT running the implementation (D26). A Swift bug cannot make these
#   checks pass, and a corrupt golden document cannot hide behind a heal
#   that also happens to be wrong.
#
# WHY THIS SPLIT EXISTS
#   Decided 2026-08-11: the round trip lives in XCTest because it needs the
#   implementation, and the shell gate checks integrity only. The split is
#   the point (D26) and must not be merged later.
# ============================================================================

set -uo pipefail

GOLDENS="Tests/Fixtures/golden-documents"
FAILURES=0

fail() { echo "  FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "  ok: $*"; }

echo "golden-roundtrip.sh: golden-document corpus integrity"

# ---------------------------------------------------------------------------
# Preflight: the directory must exist.
# ---------------------------------------------------------------------------
if [[ ! -d "$GOLDENS" ]]; then
  echo "  FAIL: golden-document corpus directory missing: $GOLDENS" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Collect .md files (non-recursive — golden documents are a flat directory).
# README.md is documentation, not a golden document, but the gate checks it
# too: it was hand-authored under the same no-tuning rule and must also be
# well-formed. Adding a document means git-add to this directory; the gate
# picks it up automatically.
# ---------------------------------------------------------------------------
shopt -s nullglob
md_files=("$GOLDENS"/*.md)
shopt -u nullglob
FILE_COUNT=${#md_files[@]}
echo "  files in golden corpus: $FILE_COUNT"

# A scan that finds zero .md files exits non-zero — "nothing to check" is a
# broken invocation, not a clean corpus (D19/D33).
if (( FILE_COUNT == 0 )); then
  echo "  FAIL: no .md files found under $GOLDENS — nothing to check" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Per-file checks.
# ---------------------------------------------------------------------------
for f in "${md_files[@]}"; do
  bn=$(basename "$f")

  # (a) Non-empty.
  if [[ ! -s "$f" ]]; then
    fail "$bn: file is empty"
    continue
  fi

  # (b) Valid UTF-8.
  if ! iconv -f UTF-8 -t UTF-8 "$f" >/dev/null 2>&1; then
    fail "$bn: not valid UTF-8"
    continue
  fi

  # (c) Ends with a trailing newline.
  if [[ $(tail -c 1 "$f" | xxd -p) != "0a" ]]; then
    fail "$bn: does not end with a newline"
  fi

  # (d) No excluded code points. These are the characters a healing pass
  #     legitimately normalises (D23, D24, criterion 4):
  #       U+2014  em dash
  #       U+2013  en dash
  #       U+2010  hyphen
  #       U+2011  non-breaking hyphen
  #       U+2018  left single smart quote
  #       U+2019  right single smart quote
  #       U+201C  left double smart quote
  #       U+201D  right double smart quote
  #       U+00A0  non-breaking space
  #       U+200B  zero width space
  #       U+FB01  fi ligature
  #       U+FB02  fl ligature
  residue=$(perl -CSD -ne '
    my %bad = (
      "\x{2014}" => "em dash",
      "\x{2013}" => "en dash",
      "\x{2010}" => "U+2010 hyphen",
      "\x{2011}" => "U+2011 non-breaking hyphen",
      "\x{2018}" => "left single smart quote",
      "\x{2019}" => "right single smart quote",
      "\x{201C}" => "left double smart quote",
      "\x{201D}" => "right double smart quote",
      "\x{00A0}" => "non-breaking space",
      "\x{200B}" => "zero width space",
      "\x{FB01}" => "fi ligature",
      "\x{FB02}" => "fl ligature",
    );
    for my $c (keys %bad) { print "$bad{$c}\n" if index($_, $c) >= 0 }
  ' "$f" | sort -u | tr '\n' ' ')
  if [[ -n "$residue" ]]; then
    fail "$bn: contains excluded code points: $residue"
  fi
done

# ---------------------------------------------------------------------------
if (( FAILURES > 0 )); then
  echo "golden-roundtrip.sh: $FAILURES failure(s)" >&2
  exit 1
fi
echo "golden-roundtrip.sh: golden corpus integrity OK"
exit 0
