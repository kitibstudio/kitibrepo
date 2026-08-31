# The path to Stage 8

Written 2026-08-14. Analysis only — this document decides nothing and authorises
nothing. It records what Stage 8 needs, in what order, and which rulings gate it.

Sources: `docs/build-plan.md` Part 5 (Stages 4–10) and §3.2; `docs/blueprint-v2.md`
§3, §4.2, §4.8, §4.10, §4.11; `state/DECISIONS.md` A2–A6, D11, D16, D22;
`state/GAP.md` node list; `state/FEATURES.md` (read in full, 2026-08-14);
`specs/rules-engine.md`.

---

## 1. What Stage 8 is

Four separate features, not one:

| Node | Feature | Blueprint |
|---|---|---|
| N15 | Glossary rules — orphaned abbreviation detection, define-in-glossary | §3.3 |
| N25 | Clause-level citation manager + standards registry | §4.2 |
| N37 | Normative language engine — shall/should/may/can, jurisdiction profiles | §4.10 |
| N38 | Contractual weight & standard-of-care overlay | §4.11 |

**Stages 6 and 7 are not prerequisites.** Build-plan Stage 8 says the language
layers "ride on the Stage 5 engine", and nothing in §4.10 or §4.11 touches
diagrams or live variables. 5 → 8 is a legitimate route, and skipping two stages
is the largest saving available on this path.

---

## 2. The three rulings that gate it

None of these are build work. All three are currently open.

### A3 — append-only JSONL log store (`[proposed]`, not locked)

The structural spine of Stage 8. The blueprint puts **four** of its data sets in
the A3 store:

- the glossary (§3.3)
- the standards registry, with the superseded-by chain (§4.2)
- the §4.10 jurisdiction/style profiles
- the §4.11 firm-owned dictionaries

Build-plan's stated reason for placing Stage 4 early is *"prove it before
glossary/citations depend on it"* — which is exactly this dependency. It is also
the highest blast-radius decision in the project.

**What A3 does and does not block:** every *classifier* below can be built,
tested and shipped with its dictionary as Swift data in Core. What A3 blocks is
the half that makes Stage 8 a firm tool rather than a personal one — shared,
synced, legal-team-owned packs. That is a real half, but it is separable, and
separating it is what lets items 1–5 proceed with no ruling at all.

### swift-markdown (RED, raised in `specs/rules-engine.md`)

At Stage 5 the dependency is optional and the recommendation is "not yet" — the
whole rules-engine spec ships without it. **At Stage 8 it stops being optional.**
§4.10 requires detecting *"a `shall` inside a NOTE or EXAMPLE block"* — a
requirement inside informative content, which ISO drafting rules forbid — and
says outright that AST context is what makes the check precise.

Deferring it through Stage 5 costs nothing, because `DocumentProjection` is
parser-agnostic by design and the AST enters as one more input adapter. Deferring
it *past* Stage 5 costs one diagnostic in §4.10.

### A6 — on-device NaturalLanguage POS tagging (`[proposed]`, not locked)

Needed for §4.10's *"passive requirements with no responsible subject"* —
`shall be installed` (by whom?). Scope that single diagnostic out and A6 is not
needed for Stage 8 at all. Keep it and A6 must be locked first.

---

## 3. The order of work, easiest first

Ease here means the build-plan §4.1 shape: pure function, Core-testable, no
dependency, no UI. Items 1–5 need **no ruling** and can start on spec approval.

### 1. Rules engine spine + first rules — Stage 5, N12 / N16 / N13
`specs/rules-engine.md`, awaiting approval. Pure functions, no dependency, fully
testable in `KitibTests`. Everything below emits into its `Diagnostic` type.
The non-negotiable trunk.

### 2. Contractual weight classifier — N38 core
The easiest *feature* on the list. §4.11 specifies "dictionary-classified,
deterministic": a term → tier table plus explanation and safer-alternative text.
Identical in shape to `ProtectedCompounds` / `CommonWords`, shipped as Swift data
in Core exactly as `HelpContent` already is (51 entries, proven inside the test
bundle). No AST, no POS, no store.

### 3. Normative verb classification — N37 core, minus two diagnostics
Same shape: per-profile verb tables. Covers shall/should/may/can/must,
disallowed substitutes (`will`, `is to be`, `has to`, `it is necessary to`),
`may not` ambiguity, and requirement verbs in headings — `OutlineParser` already
supplies headings. Deferred: notes/examples (needs the AST) and
passive-without-subject (needs A6).

### 4. Orphaned-abbreviation detection — N15, detection half
A token rule over prose, using the fence / inline-code / frontmatter exclusion
spans the Stage 5 projection already provides. Detection needs no store; only the
one-tap fixes and the per-project allowlist do.

### 5. Citation parsing + registry model — N25, first half
`@[BS 7671:2018+A2 §411.3.3]` is a pure parser. The registry — standard, edition,
amendment status, superseded-by chain — is a `Codable` struct in Core. Both are
buildable and testable before deciding where they persist.

### 6. Profile model and per-document selection
Codable profiles plus a frontmatter key. Cheap in itself, but this is the first
point where "where do these live?" must be answered — i.e. A3.

### 7. Diagnostics presentation — panel and inline underlines
Explicitly out of scope in `specs/rules-engine.md`, and untestable in
`KitibTests` (D16). Until it exists, everything above is invisible. T4 work: per
`docs/ui-conventions.md`, static appearance may be iterated against an
`ImageRenderer` PNG; gesture and feel may not.

### 8. A3 log store — Stage 4, N2
See §2. The gate between a personal tool and a firm tool.

### 9. swift-markdown integration
Small in code — one input adapter into `DocumentProjection`, by design — but a
RED project-level change and a phase-gate-worthy shift.

### 10. Block-level IDs — N3, second half of A4
`DocumentIdentity.injectID` gives document UUIDs today; block addressing does not
exist. Needed only for §4.10's requirements extraction "with stable block IDs",
which feeds the §4.5 compliance matrix. Scopeable out of Stage 8.

### 11. Snapshots — Stage 4, N1 / A2
Needed only for §4.11's QA gate recording acknowledgement in snapshot metadata.
Scopeable out of Stage 8.

### 12. The §4.8 heat-map overlay layer — N31
See §5. The hardest item, and deliberately left in Stage 10.

---

## 4. What remains in Stage 5

Assuming items 1–5 are approved and the heat map stays in Stage 10.

**Items 2–5 are Stage 8 features, not Stage 5.** Approving 1–5 completes item 1
only, and item 1 is *part* of Stage 5. Build-plan defines Stage 5 as three
things: "the AST pipeline, diagnostics panel, and the structural rules".
`specs/rules-engine.md` covers the third, partially.

### Three real blockers

**a. The diagnostics panel and inline underlines.** Named explicitly in Stage 5;
scoped out of the spec under D16. Item 7 above. The only remaining item that is
purely Stage 5 and blocks nothing downstream — but until it exists, every rule
built is invisible to the author.

**b. Five §3.2 document-integrity validators the four rules do not cover.**

| §3.2 validator | Status |
|---|---|
| Round-trip | ✅ `scripts/golden-roundtrip.sh` (real, narrow) |
| Protected-compound | ✅ `scripts/validate.sh` (real) |
| Identity — dead wiki-links | ✅ `BrokenWikiLinkRule` |
| Identity — duplicate UUIDs | ❌ |
| Structure — heading-level jumps | ✅ `HeadingLevelJumpRule` |
| Structure — malformed frontmatter | ❌ |
| Structure — tables broken by an edit | ❌ |
| Structure — clause numbers swallowed as list markup | ❌ |
| Duplicate-block detector | ❌ |

All five gaps are the same shape as the four specified rules, and three of them
have their machinery in Core already (`MarkdownTableParser`,
`preserveClauseNumbers`, frontmatter parsing). One session on top of item 1, not
a stage. Note that "identity — orphaned block IDs" is not listed as a gap: block
IDs do not exist (item 10), so there is nothing yet to orphan.

**c. The AST pipeline.** Deferrable *through* Stage 5 at no cost. Due at Stage 8
regardless — see §2.

### One finding: Stage 5 as written can never close

Stage 5's definition also claims validators that depend on stages *after* it:

- the **unit-system validator** (§3.2, §4.7) needs Stage 7
- the **SLD structural validator** and **rating sanity validator** (§3.2) need
  Stage 6 diagrams

Left as-is, Stage 5 stays permanently 🔨 for reasons that are not real, and the
reconciliation gate sees a stage that never completes. **Recommendation:**
re-assign those three explicitly to Stages 6 and 7. That is a build-plan edit and
a human decision — it is not taken here.

---

## 5. The §4.8 conflict, and the ruling taken

Both §4.10 and §4.11 describe themselves as rendering *"as a §4.8 heat-map
layer"*, with tap-to-understand popovers and a barcode minimap showing where
obligations cluster. But build-plan places heat maps (N31, §4.8) in **Stage 10**
— two stages after Stage 8. As written, Stage 8's presentation layer does not
exist when Stage 8 is built.

**Ruling taken (2026-08-14): heat maps stay in Stage 10.** Stage 8 therefore
ships as *classifications plus diagnostics in the panel* — the deterministic,
testable half — and gains its overlay, minimap and popovers at Stage 10.

Consequences, recorded so they are not rediscovered as a surprise:

- Stage 8 will not "feel like the blueprint" on delivery. The classifications
  will be right and visible in a list; the document will not be colour-coded by
  force or weight, and there will be no per-section obligation counts.
- The educational half of §4.11 — the popover teaching
  *check → review → confirm → verify → validate → certify* — is presentation.
  The explanation text should still be authored as Core data alongside each
  dictionary entry at Stage 8, so Stage 10 renders content that already exists
  and is already under test rather than writing it late.
- Nothing about the classifier design changes. This is a presentation deferral,
  not a scope cut.

---

## 6. Shortest honest path

1. Approve `specs/rules-engine.md` (ruling: swift-markdown "not yet").
2. Build item 1 — engine spine + four rules. Pure Core, test-first.
3. Close Stage 5's validator gaps — §4b above, five rules, same shape.
4. Build item 7 — the diagnostics panel. Stage 5 closes here.
5. Build items 2–5 — the Stage 8 classifiers, all Core, all testable, no ruling
   required.
6. **Stop at A3.** That is the decision that cannot be routed around, and by then
   four classifiers will be sitting in Core waiting to find out where their
   dictionaries live.

Steps 2–5 need no architectural ruling. That is the point of the ordering.
