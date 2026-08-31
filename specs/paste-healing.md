# Paste Healing

Source: `docs/blueprint-v2.md` §2.4. Build order: `docs/build-plan.md` Stage 0.5.
Status: **APPROVED by human 2026-08-10.** Transform order ruled on — see below.
Implemented across three sequential tasks (T1/T2/T3), also below.

## Intent

Text lifted from a standards PDF, data sheet, or Word document arrives broken —
hard-wrapped mid-sentence, words split across line breaks, mangled glyphs, page
furniture mixed into the prose. This repairs it on the way in, so the writer
stops doing that repair by hand on every clause they cite.

## Scores

Per `build-plan.md` §4.1 (Value × Verifiability ÷ (Blast radius × Dependency depth)).

| Axis | Score | Justification |
|---|---|---|
| Value | 5 | §2.4 calls PDF paste "the dominant input path" and this "the single most repetitive manual task in technical drafting". |
| Verifiability | 5 | Pure `String -> String`. No state, no UI, no platform API. Golden fixtures fully determine correctness — T1 under §4.3. |
| Blast radius | 4 | Cannot corrupt documents already on disk, but *can* silently destroy the meaning of text being brought in. A rejoined `star-delta` is wrong in a way that reads as correct. §4.4 names this exact case. |
| Dependency depth | 1 | Nothing must exist first. Does not need A4 UUIDs, the A3 store, or the AST. |

**Priority = 5 × 5 ÷ (4 × 1) = 6.25.** Blast radius 4 ⇒ rollback plan required (§4.1), see below.

## Acceptance criteria

Each is independently testable against a fixture pair (input file → expected output file).

1. **Line unwrap.** Lines hard-wrapped at a source column width rejoin into single
   paragraphs. Genuine paragraph breaks, list items, and table rows do **not** rejoin.
2. **Dehyphenation is lexicon-guarded.** A word split as `transfor-\nmer` rejoins to
   `transformer`. A compound whose leading fragment is itself a valid word does not
   rejoin.
3. **Protected compounds survive byte-identical**, including across a line break:
   `low-voltage`, `star-delta`, `XLPE/SWA/PVC`, `Dyn11`, `N+1`, `11kV/415V`.
4. **Glyph repair.** `ﬁ`/`ﬂ` ligatures expand; smart quotes normalise; em dash,
   en dash, U+2010 HYPHEN and U+2011 NON-BREAKING HYPHEN all normalise to plain
   `-`; **non-breaking space becomes a regular space** (NOT removed — see D23);
   zero-width space is removed; `°`, `Ω`, `²` and NBSP recover from their
   double-encoded forms.
   *Amended 2026-08-10 (D23, D24). Originally read "non-breaking and zero-width
   spaces are removed", which was wrong: every NBSP in the corpus is a value/unit
   separator, so removing it produced `1000kVA`, `50Hz`, `300A`. The U+2010/U+2011
   clause was added because PDFs emit those constantly and they are not the same
   code point as `-`, which silently broke criterion 3.*
5. **Artefact stripping.** Page numbers, running headers, and running footers are
   removed — detected by *recurrence across the pasted span*, never by a
   single-occurrence pattern match.
6. **Clause numbers are preserved, not consumed.** Leading `411.3.3`, `§7.2`, and
   `Table 4-2` survive as text and are never converted into Markdown list markup
   nor mistaken for a page number by criterion 5.
7. **Table detection.** Whitespace- or rule-aligned columns become a valid Markdown
   table. Text that merely happens to contain multiple spaces does not.
8. **Determinism.** The same input yields byte-identical output on every run.
9. **Idempotence.** `heal(heal(x)) == heal(x)` for every fixture in the corpus.
10. **Clean input is a no-op.** Well-formed Markdown passes through byte-identical —
    verified against the golden document corpus.

## Out of scope

Explicitly **not** built in this task:

- The paste hook itself, the `paste raw` / `paste healed` preview toggle, and undo
  integration. That is UI and needs a platform API; this is the transform only.
- **Provenance metadata** (source file/URL, page, timestamp on a block ID) — needs
  A4 block IDs (N3), which do not exist yet.
- **Tunable JSON profiles** in the A3 store — needs N2, which does not exist yet.
  The protected-compound lexicon ships as a hardcoded constant for now.
- Handing detected tables to the §2.1 grid editor — that editor is N8, not built.
- OCR correction beyond the glyph repairs named in criterion 4.

## Test plan

- **Unit / golden fixtures:** a corpus at `Tests/Fixtures/paste-healing/`, one
  directory per source class — multi-column standards PDF, data sheet, scanned OCR
  output, Word-to-clipboard, web page. Each fixture is an `input.txt` /
  `expected.md` pair. **The protected-compound fixtures are written first**, before
  the transform — per Stage 0.5 they *are* the acceptance criteria, not a check on
  them.
  **Every fixture MUST be loaded from disk and compared by a test.** Fixtures that
  exist but are never read are worse than none: they read as coverage and provide
  none. `FixtureCorpus.names` is the single list, and `CorpusTests` asserts the
  directories on disk match it exactly — so a stray or missing fixture fails the
  suite. Empty leftover directories are invisible to git and are caught no other way.
  **Expected outputs are PER STAGE, and each stage only ADDS one** (D27):
  - `expected-repairglyphs.md` — T1, after `repairGlyphs` alone
  - `expected-unwrapped.md` — T2, after `repairGlyphs` → `stripArtefacts` → `unwrapLines`
  - `expected.md` — T3, after the full six-transform pipeline (`PasteHealer.heal`)

  No stage rewrites an earlier stage's baseline and no stage edits an earlier
  stage's test. Growing the pipeline is therefore always additive — which matters
  because the unattended-agent contract forbids weakening or deleting a passing
  test, and a single re-baselined `expected.md` would force exactly that.
  It also keeps every completed stage permanently regression-tested.

  Author each new baseline **BY HAND and read the diff** — never by dumping the
  implementation's own output over it, which turns the corpus into an echo of the
  code instead of a check on it.
- **Validator rules:** extend `scripts/validate.sh` to assert criteria 8, 9, and 10
  across the whole corpus (determinism, idempotence, clean-input no-op).
- **Defect corpus:** `scripts/defect-corpus.sh` gains the rejoined-`star-delta` case,
  the table-destroyed-by-unwrap case, and the clause-number-stripped-as-page-number
  case. All three are named in `build-plan.md` §4.4 and must be *caught*.
- **Manual check:** none. This feature is T1 and requires no human eyes to merge.

## Failure modes

What "subtly wrong but plausible" looks like here. Each needs a test that fails
before the implementation exists.

1. **The signature failure: a rejoined compound.** `star-delta` becomes `stardelta`,
   `low-voltage` becomes `lowvoltage`. The output is a valid English-looking word
   and the diff is one character. This is the failure the whole lexicon guard exists
   to prevent, and it will not be caught by reading the output.
2. **A table flattened by line unwrap.** Rows rejoin into one paragraph of ragged
   text. The information is still *present*, so a quick read says "fine", but the
   structure — which is the meaning — is gone.
3. **A clause number eaten as a page number.** `411.3.3` at the head of a pasted
   clause is stripped by artefact detection. The prose survives, so nothing looks
   damaged, but the citation is now unanchored and the §4.2 citation manager will
   never see it.
4. **Over-eager artefact recurrence.** A phrase legitimately repeated across a long
   pasted span — a defined term, a repeated column header — is detected as a running
   header and deleted.
5. **A genuine paragraph break swallowed.** Two distinct paragraphs merge because
   the first ended near the wrap column. Reads as one longer paragraph; nobody
   notices.
6. **Numbered list mistaken for clause numbers, or the reverse.** `1.` `2.` `3.`
   become literal text, or `411.3.3` becomes an ordered-list item renumbered to `1.`.
7. **Non-idempotence.** Healing an already-healed paste damages it further —
   plausible if unwrap and dehyphenation are not guarded against their own output.
   Criterion 9 exists solely to catch this.

## Rollback

Required — blast radius 4.

The transform is a pure function behind a single entry point, `PasteHealer.heal(_:)`,
and this task adds no call site (the paste hook is out of scope). Rollback is
therefore: delete `Sources/Core/PasteHealing/` and its fixture directory. Nothing
else references it, no persisted data is written, and no document on disk is
touched. Reverting the commit is sufficient and complete.

## Named entities

Fixed here so later sessions use these exact identifiers (CLAUDE.md §5) and do not
invent variants.

- `PasteHealer` — the namespace. Entry point `PasteHealer.heal(_ raw: String) -> String`.
- Per-transform functions, individually testable:
  `unwrapLines`, `dehyphenate`, `repairGlyphs`, `stripArtefacts`,
  `detectTables`, `preserveClauseNumbers`.
- `ProtectedCompounds` — the hardcoded lexicon guarding criterion 3.
- Location: `Sources/Core/PasteHealing/`. Tests: `Tests/KitibTests/PasteHealing/`.

## Transform order — LOCKED

Human ruling 2026-08-10. This **supersedes** the order stated in blueprint §2.4
and is binding. `PasteHealer.heal(_:)` applies exactly this sequence:

1. `repairGlyphs`
2. `stripArtefacts`
3. `unwrapLines`
4. `dehyphenate`
5. `detectTables`
6. `preserveClauseNumbers`

Rationale, recorded so it is not re-litigated: encoding is normalised before any
transform matches on characters, and page furniture is removed while it is still
line-isolated. Blueprint §2.4's order ran artefact stripping *after* unwrap, by
which point headers and page numbers have been merged into surrounding paragraphs
— which makes acceptance criterion 5 unsatisfiable and directly causes failure
mode 5.

**Do not reorder these.** Changing this sequence is RED — it contradicts a locked
decision (DECISIONS.md D20).

## Implementation tasks — three sequential sessions

Human ruling 2026-08-10. The spec is built in three independently-testable slices,
each committing green. One task per session, per CLAUDE.md §8.

**T1 — corpus and glyph repair.**
Build `Tests/Fixtures/paste-healing/` (all five source classes), the
`ProtectedCompounds` lexicon, and `repairGlyphs`. Satisfies criteria 4 and 8, and
establishes criterion 3's fixtures. Per build-plan Stage 0.5 the protected-compound
fixtures are written **first, before any transform** — they are the acceptance
criteria, not a check on them.

**T2 — artefact stripping and line unwrap.**
`stripArtefacts` then `unwrapLines`. Satisfies criteria 1 and 5. Covers failure
modes 2, 4, and 5 — the recurrence-detection and paragraph-merge cases.

**T3 — dehyphenation, tables, clause numbers.**
`dehyphenate` (guarded by T1's lexicon), `detectTables`, `preserveClauseNumbers`,
and the `PasteHealer.heal(_:)` entry point composing all six in the locked order.
Satisfies criteria 2, 3, 6, 7, 9, 10. Covers failure modes 1, 3, 6, and 7.

Criteria 8 (determinism), 9 (idempotence), and 10 (clean-input no-op) are asserted
across the whole corpus by `scripts/validate.sh` and must hold at the end of every
task, not only T3.
