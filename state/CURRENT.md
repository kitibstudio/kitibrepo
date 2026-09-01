# CURRENT.md: the single active task. Rewritten each session. Cap: 40 lines.

## THIS SESSION: Problems panel, slice 1 of 2 (2026-09-01)

CONFIRMED started. specs/problems-panel.md APPROVED (D83); all nine
acceptance criteria implemented. The rules engine has its first call site:
the panel lists the open document's diagnostics, grouped by severity, with
click-to-scroll, an error-count badge, and a vault-backed link index so
broken-link detection is real.

- Core: KitibRules.all (4 rules, ForbiddenPhraseRule inert), Frontmatter-
  Metadata (title/aliases, ExclusionSpans-mirroring block detection),
  Diagnostic.nsRange(in:)/lineNumber(in:). 34 new tests, all green.
- AppState: showProblems (persisted), problems, errorCount, linkIndex in
  the SAME coalesced single walk as the search index (D83), evaluate-
  Problems() on open/save/newFile/openFolder/navigateUp/delete + panel
  appear/refresh; never per keystroke (criterion 2).
- ProblemsPanel + macOS/iOS columns + compact sheet + toolbar badge +
  Writer menu toggle at ⌘⇧E (was free).
- Suite: 548 tests (514 -> 548, D22), new all green. Both targets build;
  app launches and quits cleanly. Panel rendering + click-to-scroll are a
  human/simulator check (D16), per the spec.

PRE-EXISTING RED (unchanged): NewFileTargetTests
testSelectedFileAtDepthThreeTargetsDepthTwoParent. Human decides: fix test
or fix code.

## NEXT: slice 2, inline underlines (specs/problems-panel.md, out of scope)

Per-platform editor overlay driven by the same state.problems ranges:
NSTextView temporary attributes on macOS, TextKit on iOS. Separate session;
D11 stays the sole source of editor styling (A5). After it, the QA export
gate (exports require a clean pass) is the natural follow-on.

## Gotchas carried forward

- D50: SwiftTerm.Color shadows SwiftUI.Color in the macOS target; `Color.red`
  is a UInt16. Spell SwiftUI.Color explicitly in new macOS views.
- macOS DetailView body needs @ViewBuilder extraction (editorPane/mainSplit/
  toolbarContent); the compiler's expression budget blows otherwise.
- Diagnostic.nsRange(in:) contract: pass the range's own string; foreign
  indices trap in the stdlib, only a comparison bounds check is possible
  (D83). The panel re-evaluates on every open/save, so ranges are current.
- lineNumber counts \n SCALARS: Swift folds \r\n into one grapheme, so a
  Character scan misses the \n (CRLF bug caught by a test).
- Broken links can trail a file creation by up to the 1s index coalesce
  (D73 trade-off, documented).
- evaluateProblems runs on the main thread over the whole document: fine
  now; incremental/background evaluation stays parked.
- ForbiddenPhraseRule is inert (empty phrase list) until a rules settings
  UI exists (AMBER, PARKED).
- New content in state files stays em-dash-free (pre-existing content is
  em-dash-heavy).
- FTS5 splits hyphenated terms; a saved query for one errors unless quoted.
- PARKED: background indexing (RED), lazy FileItem (AMBER), license files
  (AMBER), extractWikiLinks frontmatter-blindness, iOS signing (RED).
