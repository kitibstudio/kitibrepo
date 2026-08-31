# Rules Engine — Core Spine + First Structural Rules

Source: `docs/blueprint-v2.md` §3. Build order: `docs/build-plan.md` Stage 5.
Architecture: DECISIONS.md A5 (locked), GAP.md C4 (resolved). Nodes: N12, part of
N16, part of N13. Depends on: OutlineParser (done), LinkIndex (done),
MarkdownTableParser (done).

**Status: APPROVED 2026-08-31.** The Open RED (§ Open RED) was ruled by the human:
**"Not yet"**; no swift-markdown dependency; this spec ships unchanged.

## Intent

One engine finds every kind of document problem and reports them in one shape, so
that a new rule is a new file and never a new scanner.

## Scores

Per `build-plan.md` §4.1.

| Axis | Score | Justification |
|---|---|---|
| Value | 4 | Structural rot (heading jumps, empty sections, dead links) is invisible until a document is issued. |
| Verifiability | 5 | Pure functions: `(text, projection) -> [Diagnostic]`. No filesystem, no UI, no AST in this spec. |
| Blast radius | 2 | Read-only. The engine reports; it never edits a document. A wrong diagnostic is noise, not corruption. |
| Dependency depth | 3 | Needs the projection assembled from three existing Core parsers. No UI, no swift-markdown. |

**Priority = 4 × 5 ÷ (2 × 3) = 3.3.** Blast radius < 4 ⇒ no rollback plan required.

## Intent, stated as an architecture

```
document text ──► DocumentProjection ──► [Rule] ──► [Diagnostic]
                        ▲
                        │  (later, gated by the Open RED below)
                  swift-markdown AST ── as one more INPUT ADAPTER
```

`DocumentProjection` is the spine. The AST, when authorised, feeds *into* the
projection as an additional input — it is not the spine, and no rule ever imports
a parser type. This keeps every rule testable in `KitibTests` today, with no
dependency, and keeps the eventual dependency swap invisible to rules already
written.

## Acceptance criteria

1. **One diagnostic shape.** Every rule returns `[Diagnostic]`. A `Diagnostic`
   carries `ruleID`, `severity`, `message`, and a character range into the
   original document text. Nothing else. No rule invents its own result type.
2. **Pluggable.** `RuleEngine.run(rules:on:)` takes any `[Rule]` and returns the
   concatenated diagnostics. Adding a rule requires no change to the engine.
3. **Deterministic order.** Same text + same rule list → identical diagnostics in
   identical order, every run. Diagnostics are sorted by range start, then by
   `ruleID`, so two rules firing at the same offset never swap places.
4. **Severity is per-rule and configurable.** A `RuleConfiguration` can override
   any rule's severity or disable it entirely; a disabled rule produces nothing
   and costs nothing.
5. **Ranges are valid and accurate.** Every emitted range is within the document
   and covers the offending text — not the whole line, not the whole section. A
   diagnostic whose range does not contain its subject is a defect.
6. **The projection is built once.** `DocumentProjection.build(from:)` runs the
   existing parsers once; all rules read that one projection. No rule re-scans
   the raw text for structure the projection already carries.
7. **Heading-level jump** (N16). A heading that descends more than one level from
   its predecessor (`##` → `####`) is a warning, with the range covering the
   offending heading marker.
8. **Empty section** (N16). A heading with no non-blank content before the next
   heading of equal or higher level is a warning. A heading whose only content is
   subheadings is NOT empty.
9. **Broken wiki-link** (N16). A `[[link]]` that `LinkIndex.resolve` returns nil
   for is an error. Links inside code fences and inline backticks are never
   flagged — the existing `extractWikiLinks` exclusion is the sole authority.
10. **Forbidden phrase** (N13). A caller-supplied list of `(pattern, message,
    severity)` fires on prose only: never inside a fenced code block, inline
    code, a table's delimiter row, or frontmatter.

## Out of scope

- **The AST.** No `swift-markdown`, no cmark, in this spec. See Open RED.
- **Fixes.** No one-tap fix, no quick action, no document mutation. The engine
  reports. `Diagnostic` has no `fix` field — adding one later is a spec change,
  not a GREEN deviation.
- **The Problems panel and inline underlines.** UI, and untestable in `KitibTests`
  (D16). This spec ships the engine and its rules; presentation is a separate task.
- **Incremental / on-edit evaluation.** Blueprint §3 asks for it. This spec runs
  the whole document. Making it incremental later must not change any rule's
  output — that is the point of the pure `(text) -> [Diagnostic]` shape.
- **Linguistic rules (N14) and glossary rules (N15).** They need POS tagging (A6,
  still `[proposed]`) and the A3 log store. Not in this spec.
- **Reference rules (N17), unit-system rules (N18), normative language (N37).**
  They ride on this engine but each needs its own spec.
- **Required-section-per-template rules.** Needs the template system (§4.3), which
  does not exist. Deferred deliberately, though it is part of N16.
- **JSON rule packs.** The forbidden-phrase rule takes its list from the caller as
  Swift values. On-disk rule-pack format is a later, separate decision.
- **The QA export gate** (blueprint §3, "exports require a clean pass"). Later.
- **Any change to `MarkdownHighlighter`.** D11 is untouched and remains the sole
  source of editor styling. A5 is explicit that the diagnostics layer is second
  and separate.

## The tripwire — projection is not a parser

This is the rule that keeps this spec from quietly becoming a hand-rolled Markdown
parser, which is exactly what D11 refused for highlighting.

**`DocumentProjection` may be assembled ONLY from:**

- `OutlineParser.parseHeadings` / `parse` — headings and section ranges
- `extractWikiLinks` — wiki-links, already fence-aware
- `MarkdownTableParser` — table ranges
- Span detection for **fenced code blocks, inline backticks, and the frontmatter
  block** — the three exclusion zones every rule needs, and the only new scanning
  this spec authorises

**Anything else is a stop.** If a rule needs emphasis spans, link destinations,
list nesting depth, block quote structure, inline HTML, or any other *inline*
syntax, the answer is not a new scanner in `DocumentProjection`. That need is the
signal that the AST is required — park the rule, raise the Open RED, and stop.

Reviewer's test: if a new `private static func` in the projection is matching
Markdown punctuation not in the list above, the tripwire has been crossed.

## Open RED — swift-markdown (human ruling required)

A5 is locked and says the pipeline is `AST walk -> pluggable rules -> diagnostics`.
The AST requires a `swift-markdown` package dependency, which is RED under
CLAUDE.md §10 and was explicitly deferred in `PARKED.md` "until rules-engine work
(N12–N18, N37) actually starts". It has now started, so it is raised here.

**RULED 2026-08-31: NOT YET.** The human chose the recommended option. This spec
ships unchanged; every criterion is met with no dependency; the tripwire stands
guard; N14/N15/N37 wait. Re-raise this question if a rule genuinely needs inline
structure that the projection's allowed scanners cannot provide.
**The question for the human: authorise `swift-markdown` as a Swift Package
dependency of `Sources/Core` and `KitibTests`, via `project.yml` + `xcodegen
generate` — yes or no?**

Three answers, all workable:

| Ruling | Consequence for this spec |
|---|---|
| **Not yet** (recommended for Stage 5) | This spec ships unchanged. Every criterion above is met with no dependency. The tripwire stands guard. N14/N15/N37 wait. |
| **Yes, now** | This spec still ships unchanged first; the AST is then added as a second `DocumentProjection` input adapter, in its own session. No rule changes. |
| **No, ever** | A5 must be re-opened — its stated mechanism becomes unbuildable, and the rules needing inline structure must be re-scoped or dropped. |

Note what does **not** change under any ruling: the engine, `Diagnostic`, `Rule`,
and all four rules in this spec are parser-agnostic and are written the same way
regardless. That is deliberate — it is why this question can be answered late
without wasting work.

## Test plan

- **Unit fixtures, per rule.** Small documents with a known defect and a known
  clean twin. Each rule asserts exact diagnostic count, range, and severity — not
  merely "at least one diagnostic".
- **Engine tests.** Empty rule list → no diagnostics. Two rules firing at the same
  offset → stable documented order. A disabled rule → nothing. Severity override
  → the overridden value.
- **Exclusion-zone corpus.** One fixture document containing each rule's trigger
  text placed inside a fenced code block, inside inline backticks, and inside
  frontmatter. Expected diagnostics: **zero**. This one fixture is the highest-value
  test in the spec — it is where the failure modes below live.
- **Range-validity property test.** For every fixture, assert every diagnostic
  range is within bounds and that the substring it covers is non-empty.
- **Golden documents.** The existing golden corpus must produce **zero** errors.
  Warnings are permitted and their exact count is pinned, so a rule that starts
  over-firing is caught by a diff rather than by a human reading a panel.
- **Determinism.** The same document run twice yields byte-identical diagnostic
  arrays.
- Every fixture written to disk must be loaded and compared by a test (CLAUDE.md
  §10). Fixtures that no test opens are not coverage.
- `xcodegen generate` after adding files; confirm the `Executed N tests` count
  actually rises (D22).

## Failure modes

The section that catches LLM-shaped bugs. Each needs a test **before** the
implementation.

1. **A rule fires inside a code fence.** The single most likely defect. A document
   demonstrating bad Markdown in a code block gets its example flagged — the
   engine is now wrong about a document that is correct. Every rule must be
   proven fence-immune individually; passing because the *engine* filters is not
   the same as the rule being correct.
2. **Frontmatter read as prose.** `title: Draft — do not issue` trips the
   forbidden-phrase rule. Frontmatter is metadata, not prose.
3. **Off-by-one ranges.** The diagnostic underlines the character before the
   defect, or the whole line. It looks right in a test asserting "one diagnostic"
   and is visibly wrong the moment a UI draws it.
4. **Plausible-but-wrong empty-section detection.** A section containing only a
   table, only an image, or only a code fence is reported as empty. The document
   is fine; the rule is naïve about what content is.
5. **Heading-jump false positive after a section move.** `SectionMover` produces
   legitimate documents whose heading levels a naïve pairwise check misreads.
   The rule compares against the *previous heading's* level, not against a
   running expectation.
6. **Broken-link false positive on an unbuilt index.** An empty `LinkIndex`
   makes every link broken. The engine must distinguish "index says no" from
   "no index supplied" and emit nothing in the latter case — an error storm on
   every document is worse than no rule at all.
7. **Diagnostic order drift.** Rules run in dictionary/set order somewhere, so
   the same document produces the same diagnostics in a different sequence.
   Silent until it makes a golden test flake.
8. **The engine grows a parser.** The tripwire above, crossed gradually: one
   emphasis-span helper, then one list-depth helper, and D11's refusal has been
   reinvented inside `Sources/Core/Rules`.
9. **Severity inflation.** Warnings emitted as errors, so the eventual export QA
   gate blocks on style opinions. Only criteria 9 (broken link) is an error in
   this spec; everything else is a warning or info.
10. **Over-firing that reads as thoroughness.** A rule that flags forty things per
    document is indistinguishable from a broken rule until someone reads them.
    The pinned golden warning counts are the guard.

## Named entities

Exact identifiers. Do not normalise or paraphrase.

- `Diagnostic` — `struct`. Fields: `ruleID: String`, `severity: DiagnosticSeverity`,
  `message: String`, `range: Range<String.Index>`.
- `DiagnosticSeverity` — `enum`: `.error`, `.warning`, `.info`.
- `Rule` — `protocol`. `var ruleID: String { get }`,
  `var defaultSeverity: DiagnosticSeverity { get }`,
  `func evaluate(_ projection: DocumentProjection) -> [Diagnostic]`.
- `DocumentProjection` — `struct`. `static func build(from text: String,
  linkIndex: LinkIndex?) -> DocumentProjection`. Carries the raw `text`, headings,
  section ranges, wiki-links, table ranges, and the code/frontmatter exclusion
  spans. See the tripwire for what it may and may not contain.
- `RuleConfiguration` — `struct`. Per-`ruleID` enable flag and severity override.
- `RuleEngine` — `enum`. `static func run(rules: [Rule], on projection:
  DocumentProjection, configuration: RuleConfiguration) -> [Diagnostic]`.
- `HeadingLevelJumpRule`, `EmptySectionRule`, `BrokenWikiLinkRule`,
  `ForbiddenPhraseRule` — the four rules.
- Location: `Sources/Core/Rules/`. Tests: `Tests/KitibTests/Rules/`.
  Fixtures: `Tests/KitibTests/Rules/Fixtures/`.
