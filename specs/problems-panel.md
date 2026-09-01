# Problems Panel: Stage 5 presentation, slice 1 of 2 (the panel)

Status: APPROVED 2026-09-01 (human confirmation; D83).
Parent: specs/rules-engine.md (COMPLETE 2026-08-31). Its "Out of scope" section
defers presentation: "The Problems panel and inline underlines. UI, and
untestable in KitibTests (D16). This spec ships the engine and its rules;
presentation is a separate task." This is that separate task, sliced: slice 1
= the panel, slice 2 = inline underlines (NOT in this spec).

Scores (build-plan §4.1): Value 5 / Verifiability 2 / Blast radius 2 / Dep
depth 1 -> priority 5.0. Verifiability is 2, not 5: the Core pieces are
testable, the panel and its wiring are not (D16), and that is stated rather
than papered over.

## What this spec is

The rules engine (four rules, 514-test suite) has ZERO call sites in the app.
Diagnostics are computed and never seen. This spec wires the engine to the
document the user is writing and shows its output in a Problems panel: a
list of findings for the CURRENT document, grouped by severity, each row
clickable to jump the editor to the offending text.

Current document only. Vault-wide diagnostics are a different product shape
(iterate every file, jump between files) and are out of scope.

## Acceptance criteria

1. **The panel lists the engine's diagnostics for the open document**,
   grouped by severity (errors, warnings, info), preserving the engine's
   deterministic order within each group. Each row shows severity icon,
   message, ruleID, and 1-based line number.
2. **Evaluation runs on four triggers only**: document open, save (including
   the 1.2s autosave), the panel's appearance, and the panel's refresh
   button. It never runs per keystroke; on-edit evaluation is the separate
   incremental task (CURRENT.md option 4).
3. **Clicking a row scrolls the editor to the diagnostic's range** via the
   existing `scrollToHeading` bridge (set by both editors, EditorView.swift
   line 421 / EditorView_iOS.swift line 344), converted from
   `Range<String.Index>` to `NSRange` with a Core helper. The panel stays
   open after a click, so the writer can work through several findings.
4. **The toolbar gains a Problems button** (exclamationmark.triangle icon)
   showing a red badge with the error count when errors exist; the Writer
   menu gains a "Problems" toggle bound to the same state, ⌘⇧E (unused in
   KitibCommands today). Both disabled/hidden when no document is open.
5. **Broken-link detection has a real index**: a `LinkIndex` is built from
   the open vault (frontmatter title + aliases via a new Core extractor,
   filename-stem fallback always), rebuilt inside the existing coalesced
   index pass (D73) so a file burst costs one walk. With no vault open the
   engine receives `nil` and BrokenWikiLinkRule emits nothing (engine spec
   failure mode 6).
6. **The default ruleset is `KitibRules.all`**: the four spec rules, fresh
   `RuleConfiguration()` (all enabled, default severities). ForbiddenPhraseRule
   ships with an empty phrase list and is documented inert until a rules
   settings surface exists (future AMBER, out of scope here).
7. **Every new Core piece is tested** in KitibTests: `KitibRules.all`,
   `FrontmatterMetadata.extract(from:)`, `Diagnostic.nsRange(in:)` and
   `Diagnostic.lineNumber(in:)`. The panel and AppState wiring are
   D16-untestable; they are verified by building both targets, the unchanged
   514-test suite, and a rendered check (simulator/manual).
8. **Golden documents stay clean**: the existing GoldenDocumentRuleTests
   already pins zero errors and zero warnings for the ruleset; this spec
   adds no new golden requirement and must not disturb the pins.
9. **Empty states**: zero diagnostics shows "No problems"; the panel is not
   shown when no document is open.

## Placement (platform split, mirroring TodoPanel)

- macOS + iPad (regular width): a right-hand column in the existing
  HSplitView, `frame(minWidth: 220, idealWidth: 280, maxWidth: 380)` on
  macOS, width 280 on iPad, toggled by the toolbar button and the menu.
- iPhone (compact width): a sheet with `.medium`/`.large` detents, same
  toggle, using the TodoPanel `onClose` pattern.
- The panel does NOT close on select, on either platform. This differs from
  the outline sheet on macOS deliberately: an outline is navigated once, a
  problems list is worked through.

## Out of scope

- **Inline underlines** (slice 2). Needs per-platform editor overlay work
  (temporary attributes on NSTextStorage / TextKit). D11 stays the sole
  source of editor styling; the diagnostics overlay is separate (A5).
- **Rules settings UI**: enable/disable, severity overrides, phrase editing.
  Needs a settings surface; AMBER when taken up. Until then
  ForbiddenPhraseRule is inert by design.
- **Incremental on-edit evaluation** (CURRENT.md option 4; the pure
  `(text) -> [Diagnostic]` shape makes it safe later).
- **Vault-wide problems.**
- **The QA export gate** (CURRENT.md option 2; needs this panel's
  diagnostics wired to export).
- **Fixes / quick actions**: `Diagnostic` has no `fix` field and this spec
  adds none. The panel reports and navigates.

## Failure modes

Each needs a test BEFORE the implementation, or an explicit note that it is
D16-untestable and therefore a human check.

1. **Stale diagnostics after a file switch.** The panel shows the previous
   document's problems. Guard: `evaluateProblems()` runs on every open and
   clears to `[]` when no document is open. D16-untestable; human check.
2. **UTF-16 range conversion off-by-one.** `NSRange(diagnostic.range, in:
   text)` must cover exactly the offending substring when non-ASCII text
   precedes the range. Core-testable with an emoji-bearing prefix.
3. **False broken links from a stale index.** A file created moments ago can
   resolve for up to the D73 coalesce delay; accepted and documented, same
   trade-off as search. An empty vault makes every link error; that is
   honest (the links genuinely do not resolve) and is recorded, not
   "fixed".
4. **The panel re-sorts or duplicates.** The engine order is deterministic
   (criterion 3 of the engine spec); the panel must not sort. Core-adjacent
   pin: `KitibRules.all` is stable; the grouping is a view concern.
5. **Frontmatter misparse.** An unclosed `---` opener returns nil (never
   partial garbage); keys not at line start are ignored; quoted title values
   are unquoted; a `title:` inside the body is not frontmatter. All
   Core-testable.
6. **Per-keystroke evaluation sneaks in.** The four triggers are pinned;
   adding a `textChanged` hook is a spec change, not a GREEN tweak.
7. **Empty-phrase ForbiddenPhraseRule misbehaves.** Must emit nothing, not
   crash, on any text. Core-testable via `KitibRules.all`.

## Test plan

- **KitibRulesTests** (Tests/KitibTests/Rules/): `all` holds exactly the
  four ruleIDs `heading-level-jump`, `empty-section`, `broken-wiki-link`,
  `forbidden-phrase`; ruleIDs unique; exactly one `.error` default severity
  (engine spec failure mode 9); running `KitibRules.all` over a plain prose
  document emits zero diagnostics (empty phrase list is inert).
- **FrontmatterMetadataTests** (Tests/KitibTests/LinkIndex/): no frontmatter
  -> nil; title only; title + aliases (flow `[a, b]` and block `- a` lists);
  missing title; quoted values; unclosed opener -> nil; `---` in the body is
  not frontmatter; trailing `...` closer accepted.
- **DiagnosticNavigationTests** (Tests/KitibTests/Rules/): `nsRange(in:)`
  round-trips through `String(range, in:)` for ASCII, emoji prefix, range at
  document start and end; `lineNumber(in:)` is 1-based across multi-line
  documents.
- No new fixture corpus: the new Core pieces are unit-tested with inline
  strings. Per CLAUDE.md §10, any fixture added later must be loaded and
  compared by a test.
- Golden pins untouched: GoldenDocumentRuleTests keeps asserting zero errors
  and zero warnings.
- `xcodegen generate` after adding files; the Executed-N count must rise
  (D22). Both targets build. Panel rendering and click-to-scroll are a
  human/simulator check (D16).

## Named entities

Exact identifiers. Do not normalise or paraphrase.

- `ProblemsPanel`: SwiftUI view, Sources/Shared/ProblemsPanel.swift.
- `AppState.showProblems: Bool`: persisted ("showProblems"), mirrors
  `showTodos`/`showOutline`.
- `AppState.problems: [Diagnostic]`: `@Published private(set)`, the open
  document's current diagnostics.
- `AppState.evaluateProblems()`: runs the engine over `text` with
  `KitibRules.all` and a fresh `RuleConfiguration()`, storing the result.
  Called from `open(file:)`, `saveCurrentFile()`, panel appear, refresh.
- `AppState.linkIndex: LinkIndex?`: private; built by a private
  `rebuildLinkIndex()` walking `rootItem` (frontmatter via
  `FrontmatterMetadata`, `LinkIndex.Entry(path: title: aliases:)`), invoked
  from `rebuildSearchIndex()` so the D73 coalesce covers both indexes. nil
  when no root is open.
- `KitibRules`: enum, Sources/Core/Rules/KitibRules.swift,
  `static let all: [Rule]` = HeadingLevelJumpRule(), EmptySectionRule(),
  BrokenWikiLinkRule(), ForbiddenPhraseRule(phrases: []).
- `FrontmatterMetadata`: struct, Sources/Core/LinkIndex/FrontmatterMetadata.swift.
  Fields `title: String?`, `aliases: [String]`.
  `static func extract(from text: String) -> FrontmatterMetadata?`: nil
  unless a complete frontmatter block (`---` opener, `---`/`...` closer,
  document start only, mirroring ExclusionSpans) exists.
- `Diagnostic.nsRange(in text: String) -> NSRange?` and
  `Diagnostic.lineNumber(in text: String) -> Int`: extension in
  Sources/Core/Rules/Diagnostic+Navigation.swift (an extension in a new
  file; `Diagnostic` itself is untouched, per the engine spec).
- Reused as-is: `RuleEngine.run`, `DocumentProjection.build(from:
  linkIndex:)`, `scrollToHeading` bridge, `TodoPanel` onClose pattern,
  `activeColor` toolbar convention.

## Change tier

GREEN. Internal implementation only: new files in Sources/ and Tests/,
AppState additions, no public interface changes, no renames, no new
dependencies, no project.yml edit (xcodegen picks up new files on
regenerate, D22). Acceptance criteria are this spec's own. The D16 caveat
is stated in criterion 7: the panel's behaviour is verified by build +
render, not by the suite.
