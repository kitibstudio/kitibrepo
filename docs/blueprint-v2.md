# Feature Blueprint v2: Technical Writing & Engineering Documentation App

**Platforms:** macOS + iOS/iPadOS (single SwiftUI codebase)
**Architecture principle:** Local-first, deterministic, zero-AI, zero cloud dependency
**Positioning:** Not "a Markdown editor with sync" — *the writing environment that understands clauses, units, standards, and revisions.*


---

## 0. Architectural Decisions (Resolved)

These decisions replace the open questions in v1 and constrain everything below.

| # | Decision | Rationale |
|---|----------|-----------|
| A1 | **Typst** as the sole export engine (embedded Rust library via Swift FFI) | Pandoc (Haskell) cannot be embedded on iOS. Typst compiles on all platforms, is fast enough for live preview, and handles equations, tables, and templates natively. One engine, identical output everywhere. |
| A2 | **SQLite delta snapshots** for version history; git dropped from core | libgit2 fights the iOS sandbox and iCloud file coordination. Snapshots in the app database are sync-safe, cross-platform, and give full retention control. Optional git export remains a macOS power-user feature (Phase 4). |
| A3 | **Append-only JSONL logs + deterministic merge** for all shared state (glossary, citation registry, link index metadata) | A live SQLite file in an iCloud/WebDAV directory is a corruption trap (whole-file, last-writer-wins sync vs WAL writes). Per-device append logs merge conflict-free on read; SQLite becomes a local, rebuildable cache — never a synced artifact. JSON export falls out for free. |
| A4 | **Stable UUIDs** for documents and blocks; wiki-links resolve via an index, never by filename | Name-based links break on rename. Display names become aliases over stable IDs. |
| A5 | **One unified rules engine** (AST walk → pluggable rules → diagnostics) | Linting, abbreviation detection, disclaimer checks, and compliance tagging are the same pipeline, not four scanners. |
| A6 | **Apple NaturalLanguage framework permitted** for on-device POS tagging | Deterministic in practice, fully offline, no generation. The "no-AI" line is drawn at: *no generative models, no cloud inference, no non-reproducible output.* On-device linguistic tagging sits on the allowed side. |

---

## 1. Data Layer

### 1.1 File & Sync Model

- **Documents:** plain Markdown files in a user-visible directory (iCloud Drive container or user-chosen folder via security-scoped bookmarks; WebDAV as an alternative root). Files are the source of truth — always portable, always readable outside the app.
- **Frontmatter (YAML):** `id` (UUID), `title`, `aliases`, `project`, `revision`, `status`, `tags`, plus template variables (see §4.3).
- **Shared state (glossary, citations, snippets metadata):** per-device append-only JSONL logs stored *inside* the synced directory, e.g.:

```
/.appdata/
  glossary/
    log-{deviceID}.jsonl
  citations/
    log-{deviceID}.jsonl
  links/
    log-{deviceID}.jsonl
```

- Each entry: `{uuid, op: add|update|delete, timestamp, payload}`. Merge rule: union of entries, latest timestamp per UUID wins, deletes tombstone. Any device can rebuild the full state from the logs alone — deterministic, conflict-free, and safe under whole-file sync.
- **Local cache:** SQLite (FTS5 + indexes) lives in the app sandbox only, rebuilt from files + logs at any time. It is never synced.
- **Compaction:** background job periodically collapses old log entries into a checkpoint file per store, keeping logs bounded.

### 1.2 Version History (Snapshots)

- Delta snapshots stored in local SQLite: per-save diffs (debounced), plus explicit **milestone snapshots** the author names ("Issued P02", "Pre-review").
- Snapshot payloads are also written to `/.appdata/snapshots/log-{deviceID}.jsonl` so history survives device loss and merges across devices under the same A3 rules.
- Side-by-side diff view (word-level) on all platforms; three-pane on Mac/iPad, stacked on iPhone.
- Retention policy user-configurable (e.g., keep all milestones forever, thin per-save deltas after 90 days).

### 1.3 Identity & Linking

- Every document and every addressable block (heading, tagged paragraph) carries a stable ID.
- `[[...]]` links resolve: alias → ID → current file path, via the link index. Renames are free; the index updates, no file rewrites needed.
- Backlinks panel generated from the index; broken links (ID with no living target) surface as diagnostics through the rules engine (§3).

---

## 2. Core Writing Environment

### 2.1 Editor

- Distraction-free mode: full-screen, typewriter scrolling, focus dimming at sentence/paragraph/section granularity. Adaptive: toolbar collapses on iPhone by default.
- Deterministic syntax highlighting tuned for technical content: units, equations (inline `$...$` and block), code fences, standard references.
- **Table editor (first-class):** Markdown tables render as an editable grid — tap/click a cell to edit, drag to reorder rows/columns, paste from Excel/Numbers, CSV import/export round-trip. The Markdown source stays canonical; the grid is a projection. This removes the single biggest friction for technical authors on touch devices.
- Dynamic outline: two-way bound to heading hierarchy; drag-and-drop section reordering (touch + pointer) rewrites the underlying Markdown atomically with a snapshot taken first.

### 2.2 Reference Sidebar

- Split-view auxiliary panel: pinned PDFs (PDFKit), Markdown references, glossary, citation registry, search results.
- Multi-window on iPadOS/macOS: reference material in a second window/Stage Manager pane alongside the draft.

### 2.3 Search

- SQLite FTS5 over all documents + frontmatter + glossary + citations.
- Boolean operators, phrase search, tag and path filters, snippet previews.
- Scoped searches saveable as sidebar "smart folders" (e.g., `project:expo AND "earthing resistance"`).

### 2.4 Paste Healing & Provenance

Paste from PDF is the dominant input path for engineering documents — every clause lifted from BS 7671, SBC, IEC, or a manufacturer's data sheet arrives damaged. Healing it on the way in removes the single most repetitive manual task in technical drafting.

- **Pure transform, no state:** clipboard text in → clean Markdown out. No UI surface, no persistence, no platform API beyond the paste hook — which makes it the most testable component in the app and a natural first build (see build plan).
- **Transforms, in order:**
  - **Line unwrap** — rejoin lines hard-wrapped at the source PDF's column width, preserving genuine paragraph breaks, list items, and table rows.
  - **Dehyphenation** — rejoin words split across a line break, *guarded by a lexicon check*: only rejoin when the leading fragment is not itself a valid word. Technical compounds must survive intact — `low-voltage`, `star-delta`, `XLPE/SWA/PVC`, `Dyn11`, `N+1`, `11kV/415V`. This is the one transform that can silently destroy meaning, so it is the one with the largest fixture set.
  - **Ligature and glyph repair** — `ﬁ`/`ﬂ` restoration, smart-quote and dash normalisation, non-breaking and zero-width space removal, degree/ohm/superscript-² recovery from mangled encodings.
  - **Artefact stripping** — page numbers, running headers/footers, and repeated watermark text detected by recurrence across the pasted span.
  - **Table detection** — whitespace- or rule-aligned columns reconstructed as Markdown tables, handed to the §2.1 grid editor rather than left as ragged text.
  - **Clause-number preservation** — leading numbering (`411.3.3`, `§7.2`, `Table 4-2`) retained and offered to the §4.2 citation manager rather than swallowed as list markup.
- **Preview and undo:** healing is applied on paste with a diff-style preview toggle (`paste raw` / `paste healed`), so a bad heal is never silent. Every heal is a single undo step.
- **Provenance metadata:** each pasted block records where it came from on the block's existing stable ID (A4) — source file or URL, page, and paste timestamp. Because the citation registry (§4.2) already models standards and editions, a pasted clause can carry *which standard and clause*, not merely "from a PDF". That lets the §3 rules engine flag a pasted clause whose source edition has since been superseded, and lets §4.11's contractual scan report where heavy language entered the document from.
- **Rules and profiles:** the transform set is a JSON profile in the A3 store, so a firm can tune it (own header/footer patterns, own protected-compound lexicon) and sync it. Ships with a default profile plus a technical-standards profile.
- **Verification:** a fixture corpus of real ugly pastes (multi-column standards PDFs, data sheets, scanned OCR output, Word-to-clipboard, web) with golden expected outputs. The corpus is the acceptance criterion — every bug found in the wild becomes a new fixture, permanently.

---

## 3. Unified Rules Engine (replaces v1's separate linter + abbreviation detector)

**Pipeline:** Markdown → AST (swift-markdown / cmark) → rule evaluation → diagnostics (inline underlines + a Problems panel), run incrementally on edit.

**Rule types (pluggable):**

1. **Regex/token rules** — forbidden phrases, required disclaimers per document type, banned filler words, house-style enforcement. User-configured dictionaries, shareable as JSON rule packs.
2. **Linguistic rules** — passive voice, sentence length, readability, via on-device NaturalLanguage POS tagging (per A6). No regex false positives on "the cable was 50 m long."
3. **Glossary rules** — orphaned abbreviation detection: any acronym without a preceding spelled-out definition is flagged. One-tap fixes: *define in glossary*, *insert expansion at first use*, *mark as universally known* (per-project allowlist). Glossary lives in the A3 log store — identical resolution on every device; JSON/CSV import-export.
4. **Structural rules** — missing required sections per template (no "Limitations" section in a design note), heading-level jumps, empty sections, broken `[[links]]`, images without captions.
5. **Reference rules** — citations pointing at superseded standard editions (see §4.2), undefined variables (see §4.1), requirement IDs with no response (see §4.5).
6. **Unit-system rules** — units that don't conform to the document's declared unit system (see §4.7), with one-tap deterministic conversion fixes.

**Severity levels** (error/warning/info) configurable per rule; **QA gate**: exports can optionally require a clean pass at warning level or above (§5).

---

## 4. Engineering-Native Features (the defensible core)

### 4.1 Unit-Aware Live Variables

- Define once, reference everywhere: `{{Ib = 400 A}}` … later `{{Vdrop = Ib * R * L}}` … prose references `{{Ib}}` render the current value.
- Deterministic evaluation engine with SI unit algebra (A × Ω = V; incompatible units are a diagnostic, not a silent wrong answer). Think Soulver/Calca, embedded in Markdown, for design notes. The same engine computes derived electrical quantities from declared equipment data — full-load current from a transformer's kVA and voltage, prospective short-circuit current at a busbar from upstream transformer/generator impedance — so an SLD's PSCC and FLC annotations are calculated values tied to the source data, not numbers the author must remember to update by hand when TX1's rating changes.
- Recompute on edit; dependency graph visible ("what uses Ib?"); values export correctly formatted in PDF.
- Variables scoped per document, with optional project-level constants file (`/.appdata/constants.md`) for shared design parameters.

### 4.1a Inline Calculator

- Any line beginning with `=` is evaluated by the §4.1 engine, unit-aware.
- **The expression is always preserved; the result is rendered after it.** Never replace the source — the expression is the reasoning, and losing it breaks diffs and snapshots.

```
= 225A * 1.25          →   = 225A * 1.25 = 281.25 A
= 75kVA / (400 * sqrt(3))  →   = 75kVA / (400 * sqrt(3)) = 108.3 A
```

- **Unit conversion requires explicit syntax** — `→` or `in`:

```
= 40 ft → in          →   = 40 ft → in = 480 in
```

  A bare scalar is a multiplier, never a conversion factor. `= 40 ft * 12` yields **480 ft**, not 480 in. Implicit conversion is prohibited: a calculator that silently reinterprets a scalar as a unit factor produces confident wrong numbers in issued documents, which is worse than having no calculator.
- Dimensional errors (`= 5A + 3V`) are diagnostics, not silent coercions.

### 4.1b Engineering Autocomplete

- Completion is driven by an electrical dictionary, not ordinary prose. Typing `20a` offers `20 A`, `20 A, 1P`, `20 A, 2P`, `20 A breaker`; `xfmr` → `Transformer`; `mccb` → `Molded Case Circuit Breaker`.
- Office-specific abbreviations are user-defined and live in the A3 store, so a firm's shorthand syncs across devices and projects.
- Ships with IEC and ANSI dictionaries, selected by the §4.7 jurisdiction setting.

### 4.1c Panel Tag Recognition

- Tags matching configurable patterns (`LP-1`, `PP-2`, `MCC-1`, `DP-3`, `MDB1`, `EDB1`) are recognised as first-class entities on the §1.3 link index — so they get autocomplete, jump-to-definition, a reference list, and **rename-everywhere** for free. No separate mechanism.
- An undefined tag referenced in prose is a §3 diagnostic.

### 4.1d Cable Notation Formatter

- Converts shorthand into office-standard notation on the fly: `3x240+1x120` → `3c 240mm² XLPE Cu + 1c 120mm² Cu CPC`.
- The expansion template is a JSON profile in the A3 store — house standards differ between firms, and follow the §4.7 jurisdiction for mm²/kcmil.
- Expanded notation resolves against the §4.9 cable legend, so a formatted cable and its legend entry stay one source.

### 4.1e Small Frictions

- **Timestamp insertion** — one shortcut inserts `2026-08-07 21:55`. Format follows the document's locale/template.
- **Decision log block** — inserts a standard block (Date / Author / Subject / Decision / Accepted because / Impacted Drawings). Blocks are §4.4-taggable and roll up into the §4.6 revision delta, so a decision log is queryable rather than decorative.
- **Recent values sidebar** — recently used engineering values (`160A MCCB`, `3c 70mm² Cu XLPE + 35mm² CPC`, `1000kVA Transformer`) listed for one-click insertion. Session-local by default; pinnable to the project.

### 4.2 Clause-Level Citation Manager

- Structured citations: `@[BS 7671:2018+A2 §411.3.3]`, `@[SBC 401 Table 4-2]`, `@[NFPA 72 §17.7.3.2]`.
- Backed by a local **standards registry** (A3 log store): standard, edition, amendment status, superseded-by chain — user-maintained, importable/exportable as JSON so a team registry can be shared.
- On export: citations auto-format per template style; a References section generates itself.
- Rules engine flags citations to superseded editions ("BS 7671:2018 cited; registry lists +A3:2024 as current").
- Sidebar: click a citation → pinned PDF of the standard opens at the bookmarked page (user-attached PDFs + page bookmarks per clause).

### 4.3 Templates & Document Variables

- Document templates (design note, report, memo, LinkedIn post) defined as Markdown + Typst template pairs with declared variables (`project_no`, `revision`, `author`, `checker`).
- Variables live in frontmatter; templates declare which are required — missing ones are structural diagnostics.
- Corporate branding (cover, header/footer, fonts, colour tokens) lives entirely in the Typst template layer; the Markdown stays clean.

### 4.4 Transclusion & Snippet Tagging

- **Transclusion:** `![[doc-id#block-id]]` embeds a block from another document by reference — rendered inline, updated live, exported resolved. Single source of truth for boilerplate clauses across specs; edit once, correct everywhere.
- **Snippet tagging:** tag any block with one or more channels (`channel: linkedin`, `channel: exec-summary`, `channel: changelog`) via inline comment or block attribute.
- **Repurposing pipeline:** per-channel templates (character limits, structure) assemble tagged blocks into a draft post/summary — deterministic extraction and reformatting, never rewriting. Character-limit tracking per channel (X/LinkedIn) shown live.
- Because transcluded blocks carry IDs, a LinkedIn extract *is* the report paragraph — not a drifting copy.

### 4.5 Requirements & Compliance Matrix

- Tag paragraphs with requirement IDs: `req: EMP-021`, `req: SBC-401-4.3`.
- One command generates a compliance matrix (requirement → responding clause(s) → status) as CSV/XLSX and as a formatted table in the exported PDF.
- Rules engine flags requirement IDs declared in a project register but answered nowhere. Built on the same block-metadata layer as §4.4 — cheap to build, very valuable for tender responses.

### 4.6 Revision & Issue Tracking

- Documents get *issued*, not just saved. An **Issue** action: bumps the revision (P01 → P02), takes a milestone snapshot, records purpose-of-issue.
- Auto-generated **revision history table** (Rev / Date / Description / By / Chk) injected into the export from snapshot metadata.
- **Delta summary:** deterministic diff between any two issues rendered as a change list ("§4.2 amended: cable CSA 185→240 mm²").
- **Redline export:** tracked-changes DOCX (via a Swift OOXML writer) or change-bar PDF between issues, for external review workflows that live in Word.

### 4.7 Unit System Enforcement & Conversion

- **Declared unit system per document (or project default):** frontmatter key `units: metric | imperial | dual`. Templates can mandate one (a US design note template locks `imperial`; an SBC report locks `metric`).
- **Deterministic unit scanner:** the rules engine tokenizes prose, tables, and `{{variables}}` for unit expressions (mm², kcmil, ft, m/s, cfm, l/s, °F, °C, psi, kPa, AWG…). Any unit outside the declared system is flagged inline as a diagnostic.
- **One-tap proposed fix:** each flag carries the converted value in the correct system, with unit-appropriate rounding and significant-figure rules (`500 ft → 152.4 m`, offered as `152 m` with the exact value retained in metadata). Fix-all per document available, snapshot taken first.
- **Trade-size lookup tables, not blind arithmetic:** nominal sizes convert via mapping tables rather than raw math — conductor sizes (240 mm² ↔ 500 kcmil nearest equivalent, flagged as *nominal*, not exact), conduit trade sizes (¾″ ↔ 20 mm), pipe NPS ↔ DN, luminaire/breaker frame conventions. Tables are user-extensible JSON in the A3 store, so office-standard equivalences sync across devices and can be shared as packs.
- **Dual-unit mode:** for jurisdictions that expect both, `dual` renders primary + parenthetical secondary on export (`240 mm² (500 kcmil)`), generated at export time from the canonical value — the source stays single-unit and never drifts.
- **Variables integration:** the §4.1 engine respects the declared system — a `{{Vdrop}}` computed from mixed inputs normalizes internally and displays in the document's system; defining a variable in the wrong system is itself a diagnostic.
- **Ambiguity handling:** context-dependent tokens (a bare `"` or `'`, "gal" US vs imperial) are flagged as *needs confirmation* rather than auto-converted; the chosen interpretation is recorded per document so the question is asked once.

### 4.8 Prose Heat Maps & Rhythm Analytics

- **Overlay layers on the editor** — toggleable, one at a time or blended, colour-coding sentences/clauses in place:
  - **Voice:** passive vs active (on-device POS tagging per A6), with intensity showing confidence; agentless passives ("was installed") distinguished from agented ones.
  - **Sentence length:** gradient from short to long; instant visual detection of the 60-word clause monsters that infest spec writing.
  - **Rhythm & pace:** rolling variance of sentence length and syllable density — a wall of same-length sentences shows flat; alternating short/long shows textured. The Gary Provost effect, made visible.
  - **Syntactic load:** clause depth and subordination per sentence (comma/conjunction/relative-pronoun structure from the POS stream) — flags sentences readers must parse twice.
  - **Hedge & filler density:** "generally", "typically", "it should be noted that" — configurable dictionary shared with the regex rule packs.
  - **Tense & mood consistency:** shall/will/must drift within a requirements section highlighted — a genuine spec-writing failure mode.
- **Document minimap ("barcode view"):** a compressed vertical strip rendering the whole document's pattern for the selected layer — scan a 60-page report's rhythm in one glance, tap a band to jump there. Works as the scrollbar on iPhone.
- **Per-section statistics panel:** avg/max sentence length, passive %, readability scores (Flesch, Gunning Fog — deterministic formulas), syllables per word; deltas shown against the template's declared targets (an exec summary can declare `max_passive: 10%`, enforced as an info-level diagnostic via §3).
- **Comparison mode:** heat map diffs between two snapshots — did the P02 edit actually tighten §5, or just move the sludge?
- **Implementation:** computed incrementally on the same AST + POS pass the rules engine already runs (§3, rule type 2) — the heat map is a *view* over existing diagnostics data, not a second pipeline. All on-device, identical output on every platform.

### 4.9 Figures & Diagrams

- **Engine tiers (all text-described, version-controlled, offline):**
  - **Mermaid (already incorporated):** quick flowcharts, sequence and state diagrams. Rendered offscreen via JavaScriptCore → SVG — no WebView in the export path, fully deterministic.
  - **CeTZ + plotting packages (via the embedded Typst engine):** publication-grade vector figures and charts — axes, log scales, annotations, engineering plots — compiled in the same pass as the document. Zero additional dependency.
  - **Graphviz (embedded C library, dot/neato):** auto-layout for large graphs Mermaid can't handle — system topologies, dependency and cause-and-effect diagrams at 40+ nodes.
  - **Pikchr (embedded C library):** lightweight box-and-line sketches with precise positional control; the fast "sketch it on site" tier.
- **SLD symbol library (differentiator):** a shipped CeTZ package of IEC 60617 and ANSI/IEEE electrical symbols — breakers, transformers, generators, CTs, busbars, ATS/transfer switches, isolators, bus couplers, multifunction meters, motors, star-delta/soft-starter blocks, earthing — so single-line diagrams are described in text, render to publication quality, and diff like prose in snapshots. Symbol set selected automatically by the document's `units`/template jurisdiction (§4.7 metric → IEC, imperial → ANSI), overridable. Buses and rated links (`busbar B1 "1000A"`, a copper busbar run between a source and an ATS) render with their amperage and material inline on the diagram; other point-to-point conductors are tagged (`C1`, `C2`…) and resolve against a cable-size legend block in the same source, rendered as a table beneath the diagram — so a schedule and a diagram never drift out of sync, because they're the same source. Protective devices (breakers, ACBs) carry structured settings data — frame rating, overload (Ir) pickup, and trip-unit/relay model — as a label string on the device node, rendered as a compact stacked block beside the symbol. Because the data is structured, not just printed, a **protection & discrimination check** (§3, rule type 7) becomes possible: comparing upstream vs downstream Ir/Isd/Ii settings for loss of selectivity, and flagging a downstream device rated at or above its upstream device's setting. The same device data can also generate a standalone **protection settings schedule** table, following the same source-of-truth pattern as the cable legend.
- **Topology palette (drag-and-drop insertion):** the app menu carries a library of parameterised topology blocks the author drags into a document rather than typing from scratch — including Uptime Tier 1 (N, single path), Tier 2 (N+1 capacity, single path), Tier 3 (dual path, STS merge), and Tier 4 (dual path, no shared device, dual-corded load), alongside smaller units (transformer incomer, ATS pair, motor starter way, UPS way). Each palette item inserts the `sld` source text at the cursor with placeholder tags (`Q1A`, `UPSA`) ready to rename, not a locked graphic — so a dropped Tier 3 block is immediately editable text like anything else, diffs normally, and can be promoted to Tier 4 by editing rather than re-inserting. Palette items are the same bundled-Markdown format as the §4.9 usage-guide examples, so a firm's own house topologies can be saved into the palette and synced through the A3 store.
- **Variable-driven figures:** CeTZ plots may reference §4.1 live variables and document tables — a voltage-drop-vs-length curve redraws when `{{Ib}}` changes, and is guaranteed current at issue. Stale hand-pasted charts cease to exist.
- **Unified theme layer:** one figure theme derived from the document template (fonts, colour tokens, stroke weights, arrowheads) injected into every engine — Mermaid theme config, Graphviz attributes, CeTZ styles — so all diagrams on a page look like siblings. Themes live with templates in the A3 store and export inside rule packs.
- **Pipeline:** source block → engine → SVG → cached by content hash in the local cache → embedded by Typst at export. Live preview on all platforms; a diagram block failing to compile is a diagnostic in the Problems panel (§3), not a silent blank. Live preview renders in a proper pan/zoom canvas, not a scaled-to-fit static image: pinch-to-zoom and drag-to-pan on iPad/iPhone, scroll-to-zoom and drag-to-pan with pointer/trackpad on Mac, plus a fit-to-width/reset-zoom control and an optional minimap for large diagrams (a full-building riser or a busy SLD shouldn't force text below a legible size just to fit the pane).
- **Built-in figure usage guide:** each engine ships with an in-app guide — a browsable gallery of worked examples (flowchart, sequence, topology, plot, SLD…) rendered live in the app's own theme, each showing the source block beside its output. Every example has an **Insert into document** action that drops the snippet at the cursor as a working starting point, and a **playground** mode where the user edits the example source and watches it re-render before committing. Guides cover engine choice too ("40+ nodes → Graphviz, not Mermaid"), and the gallery is extensible: any figure in the user's own documents can be saved to it as a personal/team example (stored in the A3 store, so the office gallery syncs and can be shared as a pack). Guides are bundled Markdown + figure blocks — no network, and they update with each engine version so examples never drift from supported syntax.
- **Deliberately excluded:** PlantUML (Java — cannot embed on iOS), Kroki (server-side — violates local-first). D2 parked for review (Go embedding cost).

### 4.10 Normative Language Engine

- **Verb classification** per ISO/IEC Directives Part 2 (Clause 7 verbal forms): *shall / shall not* = requirement, *should / should not* = recommendation, *may / need not* = permission, *can / cannot* = possibility or capability, *must* = external constraint only (restated law or physics, never an internal requirement). Disallowed substitutes ("will", "is to be", "has to", "it is necessary to") are detected as equivalents and flagged.
- **Jurisdiction/style profiles** (user-editable JSON in the A3 store, selected per template alongside §4.7 units): ISO/IEC Directives, CEN/CENELEC, NFPA Manual of Style, UK statutory drafting, US plain-language ("must" preferred, "shall" deprecated), and contract mode. The same verb carries different weight per profile — the engine's classifications, permitted forms, and explanations all follow the active profile.
- **Overlay & minimap:** renders as a §4.8 heat-map layer — colour-coded by force (requirement / recommendation / permission / possibility), with the barcode view showing where a document's obligations cluster. Per-section counts in the statistics panel ("§5: 14 requirements, 3 recommendations, 1 permission").
- **Tap-to-understand:** tapping any highlighted verb opens a popover with the exact meaning under the active profile, the governing clause (e.g., ISO/IEC Directives Part 2 §7.2), what it legally/normatively commits the reader to, and a correct-vs-incorrect usage pair. A full verbal-forms reference card lives in the sidebar for learning rather than lookup-only.
- **Diagnostics (via §3 rules engine):**
  - "must" used for an internal requirement in ISO-profile documents; "shall" in US plain-language mode.
  - **Normative verbs inside informative content** — a "shall" inside a NOTE or EXAMPLE block violates ISO drafting rules (notes cannot contain requirements); AST context makes this a precise check.
  - **"may not" ambiguity** (prohibition vs absence of permission) — flagged as *needs rewording* with "shall not" / "need not" offered as fixes.
  - Requirement verbs in headings, mixed-force sentences ("shall … and should …"), and passive requirements with no responsible subject ("shall be installed" — by whom?).
- **Requirements extraction:** every shall-statement is enumerable — one command lists all requirements with stable block IDs, feeding the §4.5 compliance matrix and giving the delta summary (§4.6) a *requirements changed between issues* view: exactly which obligations P02 added, removed, or reworded.

### 4.11 Contractual Weight & Standard-of-Care Overlay

- **Purpose:** highlight the liability weight of contractual verbs and phrases in scopes of services, specifications, and reports — and educate the author on what each word actually commits them (or their firm) to.
- **Weight tiers (dictionary-classified, deterministic):**
  - **Absolute obligation:** *guarantee, warrant, ensure, certify* — strict duties above the professional negligence standard; frequently outside PI insurance cover.
  - **Elevated duty:** *verify, validate, approve, supervise, inspect, witness, attest, accept, sign off* — imply independent confirmation, formal acceptance, or assumption of responsibility for others' work.
  - **Professional standard:** *review, observe, coordinate, comment, endeavour, reasonable skill and care* — the defensible tier for consultancy scopes.
  - **Vague / disputed:** *best efforts, workmanlike, to the satisfaction of, as required, industry standard, fit for purpose* — phrases with contested or jurisdiction-dependent meaning.
- **Contract-family profiles** (same profile architecture as §4.10, selected per template): FIDIC, NEC, JCT, AIA/EJCDC, bespoke — the same word carries different weight per family and jurisdiction, and popover content, tiers, and suggested alternatives follow the active profile.
- **The confirmation cluster gets dedicated education:** *check → review → confirm → verify → validate → certify* is a gradient of escalating duty, and authors swap these words as synonyms when they aren't. Popovers teach the distinctions — including the ISO 9000 one: **verification** confirms specified requirements have been met; **validation** confirms fitness for the intended use. Writing "validate the design" when you meant "verify against the specification" claims responsibility for whether the thing *works in service*, not just whether it matches the drawings — a materially larger obligation. In commissioning and QA contexts the profile flags V-word misuse against the declared meaning rather than just the tier.
- **Overlay & popovers:** renders as a §4.8 layer, heat-coded by tier; tapping a term shows *what it commits you to*, the standard-of-care implication, why it matters, and a **safer alternative with rationale** ("approve → review: preserves professional standard; approval can transfer responsibility for the contractor's design"). Barcode minimap reveals where a document's obligation weight concentrates.
- **Firm-owned dictionaries:** the app ships a starter pack, but tiers, terms, explanations, and alternatives are a JSON pack in the A3 store — intended to be owned and maintained by the firm's legal/risk team, synced to every author, and shareable across the office. All guidance is explicitly educational, not legal advice, and says so in-app.
- **Diagnostics & QA gate:** absolute-obligation verbs in a scope-of-services template are warnings by default; the §5 QA gate can require each tier-1 term to be individually acknowledged (with the acknowledgement recorded in snapshot metadata) before issue — an audit trail showing heavy words were deliberate, not accidental.
- **AI-draft safety net:** pasted or externally drafted text (where models habitually reach for *ensure* and *verify* as filler) gets the same deterministic scan on import — heavy language introduced by any source is caught before it's issued.

---

## 5. Export Pipeline

- **Engine:** embedded Typst (A1). Live paginated preview on all platforms — what you see is the issued page, including headers, footers, and page numbers.
- **Outputs:** PDF (branded report), plain/clean Markdown, HTML, DOCX (for redlines and clients who demand Word), per-channel social text (§4.4).
- **Pre-flight:** optional QA gate — export blocked or watermarked "DRAFT — QA INCOMPLETE" until the rules engine passes at the configured severity; compliance matrix and revision table freshness checked.
- Export presets per template stored in the project, so "Issue P03 as PDF" is one action on iPhone from site.

---

## 6. Metrics & Targets

- Live word/character counts; per-channel character budgets (from channel templates) with progress indicators.
- Section-level word budgets declared in templates ("Exec summary ≤ 300 words") enforced as info-level diagnostics.
- Writing session log (local only): words per session, streaks — stored in local cache, never synced unless user opts the log into `/.appdata/`.

---

## 7. Platform Notes

| Concern | macOS | iPadOS | iOS |
|---|---|---|---|
| Layout | Three-pane (outline / editor / reference) | Two-pane + multi-window / Stage Manager | Single pane, sheets for outline & diagnostics |
| Input | Pointer, keyboard shortcuts, menu bar | Touch + Pencil (PDF markup in sidebar), keyboard | Touch-first; quick-capture entry point for field notes |
| Files | Full folder access | Security-scoped bookmarks | Same, plus Share-sheet import |
| Export | All formats | All formats | All formats (Typst runs identically) |
| Git bridge | Optional (Phase 4) | — | — |

Field-capture flow (iPhone): quick note → auto-frontmatter (project inferred from last context) → lands in an Inbox folder for later filing on Mac/iPad.

---

## 8. Phased Delivery

**Phase 1 — Foundation (MVP)**
Editor + distraction-free mode; paste healing + provenance (§2.4); file model + frontmatter IDs; iCloud directory sync of *files only*; FTS5 search; outline; basic Typst PDF export with one template; table grid editor.

**Phase 2 — Trust layer**
Snapshots + diff view; A3 log stores; glossary + orphaned-abbreviation rules; regex rule packs; stable-ID wiki-links + backlinks; reference sidebar with PDFs.

**Phase 3 — Engineering-native**
Unit-aware variables; unit system enforcement + conversion fixes (§4.7); normative language engine — profiles, overlay, popovers, diagnostics (§4.10); contractual weight & standard-of-care overlay (§4.11); CeTZ figures + unified diagram theme layer (§4.9); citation manager + standards registry; templates with variables + QA gates; revision/issue tracking + rev table + delta summary.

**Phase 4 — Reach**
Transclusion + snippet repurposing pipeline; compliance matrix + requirements extraction from normative statements (§4.5, §4.10); redline DOCX export; WebDAV sync root; linguistic (POS) rules + prose heat maps & rhythm analytics (§4.8); Graphviz + Pikchr engines, SLD symbol library, variable-driven figures (§4.9); macOS git bridge; shareable JSON rule packs / team registries.

---

## 9. Explicit Non-Goals

- No generative AI, no cloud inference, no telemetry-dependent features.
- No proprietary file format — Markdown files remain readable and complete without the app.
- No synced live databases — all synced state is append-only logs (A3), full stop.
- No real-time multi-user collaboration in v1–v4 (the log architecture leaves the door open).
