# DECISIONS.md — append-only. Cap: 150 lines.
# Mark each [from-code] (found in codebase) or [locked] (explicitly chosen).
#
# [from-code] to be populated by Session 0 audit
# Proposed A1-A6 from blueprint — promote to [locked] after reviewing GAP.md:

[from-code] D1: XcodeGen (project.yml) in use — agent edits project.yml and runs
  xcodegen generate; never edits project.pbxproj directly

[from-code] D2: App is named "Kitib" (Arabic كاتب — "writer"). Bundle ID: com.sean.kitib.
  Primary app icon from Resources/Assets.xcassets/AppIcon.appiconset/

[from-code] D3: Single SwiftUI codebase for macOS + iOS/iPadOS. Platform
  divergence lives in #if os() conditionals and per-platform source folders
  (Sources/macOS/, Sources/iOS/). Shared code in Sources/Shared/.

[from-code] D4: Documents are plain Markdown files on disk — always portable, always
  readable outside the app. User chooses a folder (security-scoped bookmark).
  File paths serve as document identifiers. No database.

[from-code] D5: Markdown → HTML export is a self-contained Swift converter
  (ExporterCore.swift) — no Pandoc, no external dependencies. KaTeX and Mermaid
  are bundled JS libraries loaded at render time in WKWebView.

[from-code] D6: macOS integrated terminal uses vendored SwiftTerm library
  (Vendor/SwiftTerm/) — xterm-class emulation, login zsh PTY. Not cross-platform
  (iOS has no terminal).

[from-code] D7: Per-document to-do lists persist in UserDefaults, keyed by file
  path. Not in the document file itself.

[from-code] D8: Preferences (focus mode, typewriter, line numbers, font size,
  appearance, etc.) persist in UserDefaults. Word goals per-file, also in UD.

[from-code] D9: Autosave debounced at 1.2 seconds. Dirty flag + explicit save
  on quit/file switch/export.

[from-code] D10: macOS editor uses AppKit NSTextView; iOS editor uses UIKit
  UITextView (TextKit 1 forced). Neither uses a cross-platform text framework.

[from-code] D11: Markdown syntax highlighting is regex-based on NSTextStorage —
  not AST-based. No cmark/swift-markdown dependency.

[from-code] D12: Scroll sync (editor ↔ preview) is bidirectional, fraction-based,
  using a ScrollSync bus in AppState. Editor and preview register callbacks.

[from-code] D13: Deployment targets: macOS 13.0, iOS/iPadOS 16.0. Swift 5.0.

[from-code] D14: No Swift Package Manager dependencies. All dependencies are
  vendored (SwiftTerm) or bundled as resource files (KaTeX, Mermaid JS).

[from-code] D15: Word-goal celebration uses CAEmitterLayer fireworks. macOS:
  floating NSPanel above the main window (AppKit content paints over SwiftUI).
  iOS: SwiftUI overlay with CAEmitterLayer.

# A1-A6 from blueprint. Ruled on by human 2026-08-10 after reviewing GAP.md.

[rejected] A1: Typst as export engine (embedded Rust via Swift FFI).
  Human ruling 2026-08-10 (GAP.md C1). The existing self-contained Swift
  Markdown->HTML converter (ExporterCore.swift) + WKWebView print/PDF is kept.
  Consequences: GAP C3 resolves to keep the WKWebView preview — there will be no
  paginated Typst preview. GAP N32 loses CeTZ; Graphviz/Pikchr remain open as
  figure engines. Stage 1 of build-plan.md no longer carries Typst FFI risk.

[proposed] A2: SQLite delta snapshots for version history
[proposed] A3: Append-only JSONL logs for shared state

[locked] A4: Stable UUIDs for documents and blocks; wiki-links via index.
  Human ruling 2026-08-10 (GAP.md C2). Added as an overlay — path-based
  operations (FileItem.id = url.path, D4) keep working unchanged. Prerequisite
  for N3 (block addressing), N4 (wiki-links/backlinks), N29 (revision tracking),
  and the provenance metadata in blueprint 2.4.

[locked] A5: One unified rules engine (AST walk -> pluggable rules -> diagnostics).
  Human ruling 2026-08-10 (GAP.md C4). The AST is a SECOND layer, for diagnostics
  only. The regex MarkdownHighlighter (D11) is untouched and remains the sole
  source of editor styling. Requires a swift-markdown dependency, which is RED
  per CLAUDE.md section 10 and is NOT yet authorised — it must be raised again
  when rules-engine work (N12-N18, N37) actually starts. N7 needs no AST, so
  this is not a blocker for the current task.

[proposed] A6: Apple NaturalLanguage permitted for on-device POS tagging

[locked] D16: Test harness is an XcodeGen-declared Xcode unit-test bundle
  (KitibTests), not SwiftPM. Human authorised the project.yml edit directly on
  2026-08-10, overriding the CLAUDE.md section 10 RED on adding a target. Scope
  of that grant: test-harness scaffolding in project.yml only. Any other
  project-level change remains RED and must be raised separately.

[locked] D17: gauntlet.sh gate_tests runs `xcodebuild test`, not `swift test`.
  There is no Package.swift and D16 chose an Xcode test bundle, so the original
  `swift test --quiet` gate could never pass — it made gauntlet.sh preflight a
  hard stop. Pure-logic code under Sources/Core is compiled directly into the
  test bundle rather than linked from the app targets, so tests do not build
  SwiftTerm or any UI layer.

[from-code] D18: Xcode lives at
  /Volumes/Samsung 990 2TB/Applications/Xcode.app — an EXTERNAL VOLUME — and
  `xcode-select -p` points at /Library/Developer/CommandLineTools, which cannot
  run xcodebuild. gauntlet.sh therefore sets DEVELOPER_DIR explicitly (overridable
  by exporting it first). Consequence: if that volume is not mounted, the test
  gate fails closed with a clear message rather than silently skipping.

[locked] D27: fixture expected outputs are PER PIPELINE STAGE, one file each, and
  every stage ADDS a file rather than rewriting one. Human ruling 2026-08-10,
  superseding D25's "re-baseline expected.md at each stage".
    expected-repairglyphs.md  T1  repairGlyphs
    expected-unwrapped.md     T2  + stripArtefacts + unwrapLines
    expected.md               T3  + dehyphenate + detectTables + preserveClauseNumbers
  D25 created a rule collision: it told each stage to rewrite expected.md, while
  prompts/gauntlet-task.txt forbids weakening or deleting a passing test. Adding
  transforms would have broken CorpusTests.testRepairGlyphsProducesExpectedOutput-
  ForEveryFixture with no legal move available to an unattended agent. Additive
  staging removes the conflict and keeps every finished stage regression-tested.
  Enumerated by FixtureCorpus.Stage; validate.sh validates every expected*.md it
  finds and requires the stage-1 file to exist.

[locked] D26: scripts/validate.sh validates the fixture corpus WITHOUT executing
  repairGlyphs — it reads the files directly. A validator that calls the code it
  validates is an echo, not a check: a bug in the implementation would make both
  agree and both pass. Criteria 8 and 9 (determinism, idempotence) genuinely need
  the Swift and therefore live in CorpusTests, not here; validate.sh says so in
  its own header rather than implying coverage it does not have.
  Verified red 2026-08-10 against three seeded defects: a stray empty fixture
  directory, literal \uXXXX escape text in a fixture, and an NBSP surviving into
  an expected.md (the D23 regression).

[locked] D23: repairGlyphs converts NBSP (U+00A0) to a REGULAR SPACE, and never
  deletes it. ZWSP (U+200B) is still deleted. Human ruling 2026-08-10, amending
  spec criterion 4, which originally said both were "removed".
  Every NBSP in the fixture corpus is a value/unit separator — 1000 kVA, 11 kV,
  415 V, 170 mm, 50 Hz, 240 mm², 300 A. Deleting it produced 1000kVA / 50Hz /
  300A: output that reads as correct, is wrong, and would have been inherited by
  the unit-system work (N19, N30). Also applies to the double-encoded form
  ("Â" + NBSP), which must be recovered BEFORE bare NBSP is converted or a stray
  "Â" is left behind.

[locked] D24: repairGlyphs normalises U+2010 HYPHEN and U+2011 NON-BREAKING
  HYPHEN to plain "-", alongside em and en dash. These render identically to a
  hyphen-minus but are different code points, and PDFs emit them constantly.
  Without this, "low‐voltage" spelled with U+2010 is NOT the protected compound
  "low-voltage", so ProtectedCompounds never matches it and criterion 3 fails
  silently. Found 2026-08-10 by the first test that actually read the corpus.

[locked] D25: fixture expected.md files are STAGE-SCOPED — at T1 they hold the
  output of repairGlyphs alone, not the full pipeline. They must be re-baselined
  at T2 and T3, BY HAND, reading the diff. Never regenerate them by dumping the
  implementation's own output: that makes the corpus an echo of the code rather
  than a check on it.

[from-code] D22: XcodeGen emits CLASSIC file references, not Xcode synchronized
  groups (verified: 0 PBXFileSystemSynchronizedRootGroup in project.pbxproj).
  A .swift file created on disk is NOT in any target until `xcodegen generate`
  re-runs. Proven 2026-08-10: a deliberately failing test added without
  regenerating was ignored entirely and gate_tests exited 0 — i.e. tests can be
  written, not run, and still report success.
  CLAUDE.md section 10 states the source folder is "file-system-synchronized" and
  that creating a .swift file is enough. THAT IS FALSE for this project and needs
  human correction — it is the instruction most likely to silently void a session's
  test coverage. gate_tests now runs xcodegen itself so the gate cannot be fooled,
  and prompts/gauntlet-task.txt carries the same warning for the agent.

[locked] D20: PasteHealer transform order is repairGlyphs -> stripArtefacts ->
  unwrapLines -> dehyphenate -> detectTables -> preserveClauseNumbers.
  Human ruling 2026-08-10. This SUPERSEDES the order stated in blueprint 2.4.
  Encoding is normalised before anything matches on it; page furniture is removed
  while still line-isolated. The blueprint order stripped artefacts AFTER unwrap,
  which makes acceptance criterion 5 unsatisfiable. Reordering these is RED.

[locked] D21: specs/paste-healing.md is APPROVED and is built in three sequential
  tasks — T1 corpus+lexicon+repairGlyphs, T2 stripArtefacts+unwrapLines,
  T3 dehyphenate+detectTables+preserveClauseNumbers+heal(). Human ruling
  2026-08-10. One task per session; each commits green independently.

[locked] D19: gate_tests must NOT pass `-quiet` to xcodebuild, and must assert
  that at least one test actually executed. `-quiet` suppresses the executed-test
  count, and an xcodebuild run that executes ZERO tests still exits 0 — so the
  obvious implementation of this gate goes green while testing nothing. Verified
  2026-08-10 in both directions: green at exit 0 with 1 test executed, red at
  exit 65 with a deliberately broken assertion.

[from-code] D28: The repo lives under ~/Documents, which macOS protects with TCC.
  The xctest bundle reads the fixture corpus from disk at RUNTIME and inherits the
  privacy permissions of whatever launched it. A terminal without Documents/Full
  Disk Access therefore fails EVERY fixture read with NSCocoaErrorDomain 257,
  producing ~43 assertion failures that look exactly like code defects.
  Observed 2026-08-10 22:04: ./gauntlet.sh halted with "tests already red before
  starting" on a commit whose suite was green. Nothing was wrong with the code —
  same commit, clean tree, 26/0 when run from a process that had the permission.
  Mitigations in place: gate_tests probes readability first and prints the fix;
  FixtureCorpus.permissionHint turns error 257 into an explicit "this is a
  permissions problem, not a test failure" message.
  Permanent fix is the human's: grant the terminal Full Disk Access, or move the
  repo out of ~/Documents.

[from-code] D30: T2 detection thresholds, recorded so they are not re-litigated.
  stripArtefacts strips a line only if it is blank-ISOLATED on both sides, ≤72
  chars, carries a digit, is neither structural nor a clause citation, and its
  digit-normalised form recurs ≥3 times. unwrapLines unwraps a block only if ≥3
  of its prose lines sit within 20% of the block's longest line, and rejoins only
  across a line that does not end a sentence. Both thresholds are set on the same
  asymmetry: under-healing leaves visible breakage the writer fixes in one
  keystroke, over-healing deletes or merges content and reads as correct.
  Consequence worth knowing: furniture not separated from the body by a blank
  line is NOT stripped, and a block with no consistent right margin (a web paste)
  is left untouched — which is why two fixtures' stage-2 baseline equals stage 1.

[from-code] D31: T3 detection thresholds, recorded so they are not re-litigated.
  dehyphenate removes a hyphen only if the whitespace-delimited token carries no
  digit, contains no protected compound, the fragment before the hyphen is ≥2
  letters and is neither an all-caps acronym nor a word in CommonWords, and the
  fragment after it starts with a lowercase letter. A split across a real line
  break is NOT rejoined — unwrapLines already decided that block was not
  hard-wrapped, and this transform does not overrule it.
  detectTables marks up two shapes only: ≥3 consecutive non-structural lines
  splitting into the same number of cells (≥2) on runs of ≥2 spaces with
  IDENTICAL column offsets on every row; and ≥2 consecutive lines that all
  contain "|" with the same cell count, which gain a delimiter row and are
  otherwise left as typed. A block that already has a delimiter row is returned
  unchanged — that is what makes the transform idempotent.
  preserveClauseNumbers escapes an ordered-list marker only when it is exactly 3
  digits wide (411. → 411\.). 1- and 2-digit markers are left alone: "41." is
  genuinely ambiguous, and a real list that reaches 100 items barely exists —
  while a clause number rendered as "1." destroys the citation on screen.
  All three sit on the same asymmetry as D30: under-healing is visible and costs
  a keystroke, over-healing reads as correct and is not.

[locked] D29: the fixture corpus is COPIED INTO THE TEST BUNDLE as a folder
  reference (project.yml, KitibTests resources build phase) and read from there
  at runtime. FixtureCorpus.corpusRoot prefers Bundle(...).resourceURL and only
  falls back to the #filePath source tree if that copy is absent;
  CorpusTests.testFixturesAreBundledNotReadFromSourceTree fails if the bundled
  copy is missing, so the fallback cannot silently mask a broken resources phase.
  Reason: D28. The bundle lives in DerivedData under ~/Library, which TCC does
  not gate, so the suite no longer depends on the xctest runner having Documents
  access. Proven 2026-08-10: 27 tests pass with Tests/Fixtures/paste-healing
  moved out of the repo entirely.
  Note: because it is a FOLDER reference, new fixture directories are copied
  automatically at build time — but they still must be added to
  FixtureCorpus.names, or CorpusTests and validate.sh both fail.
  This used the D16 project.yml grant (test-harness scaffolding only).

[locked] D32: defect-corpus.sh exit-code convention. GATE MODE (default,
  gauntlet): exit 0 when all three defects are confirmed present, exit non-zero
  when any expected defect is missing, undetectable, or the directory contains
  any file other than the three named defects (stray-files guard, added
  2026-08-11). SCAN MODE (custom directory): exit non-zero when any defect is
  found, exit 0 on a clean corpus. The scan mode implements the "both
  directions" verification from CURRENT.md — clean corpus → 0, each defect one
  at a time → non-zero. No Swift code is called; shapes are checked directly
  (D26).

[locked] D33: a scan of zero files exits non-zero. "Nothing to check" is a
  broken invocation, not a clean corpus (2026-08-11). This is the D19 lesson
  applied to the defect gate: a run that exercises nothing and exits 0 is the
  most dangerous false green. Scan mode prints the file count every run so a
  silent zero-match cannot recur unseen. Gate mode likewise prints its file
  count.

[locked] D35: dehyphenate inverted rule — positive evidence required (2026-08-11).
  Human ruling. `dehyphenate` removes a hyphen ONLY when the joined form is
  a known word in `RejoinableWords`.  An unknown joined form keeps its hyphen:
  under-healing is visible and costs a keystroke, over-healing reads as correct
  and is wrong.  This supersedes the dehyphenate clause of D31 — the old default
  (fuse unless the leading fragment is in CommonWords) was the wrong asymmetry
  and was caught by the golden document round-trip on its first run.  All other
  guards in `shouldRejoin` remain exactly as they were: no digit in token, no
  protected compound, left fragment ≥2 letters / not acronym / not in
  CommonWords, right fragment starts lowercase.  `CommonWords` becomes a
  secondary guard; `RejoinableWords` is the primary gate.

[locked] D36: N8 table grid editor — all cells are live TextFields (2026-08-11).
  Human ruling in-session. Every header and data cell is a TextField with
  `.textFieldStyle(.plain)`. Click-to-focus uses `.simultaneousGesture`
  with `DragGesture(minimumDistance: 0)` because `onTapGesture` fires after
  the ScrollView's NSScrollView consumes the mouse-down event on macOS.
  Focus is deferred via `DispatchQueue.main.async`. Tab/Shift-Tab navigates
  all cells via `@FocusState` + `CellID`. Headers use `row: -1` in the
  CellID namespace. Presentation: `.sheet` on macOS (resizable window),
  `.sheet` on iOS.

[locked] D37: Dynamic outline — section move inside-section check is
  heading-index-based, not text-range-based (2026-08-11). Human ruling
  in-session. Checking `destInsertion < NSMaxRange(sourceRange)` fails
  when a top-level section has been moved to document start (its section
  now spans all subsequent headings). Instead, `destinationIndex` is
  compared against the index of the first subsequent heading of equal or
  higher level: if `destinationIndex` falls within the section's heading
  span (sourceIndex+1 through sectionEndIdx-1), the move is rejected.
  A destination at `sectionEndIdx` (or beyond) is accepted — it inserts
  at the boundary, which is not "inside" the section.

[from-code] D38: Section text reinsertion adds a leading newline separator
  when the insertion point is mid-text and not already at a line boundary.
  Without this, the moved heading fuses with the preceding line when the
  remaining text does not end with a newline (e.g., the last line of a
  multiline string literal without a trailing blank line, or a document
  whose final line has no terminator). The guard checks `mutableText[adjustedDest-1]`,
  prepending `\n` when the character is not already a newline. All
  section text inherently starts at a line boundary (it begins with a
  heading line).

[from-code] D39: `unwrapLines` measures the wrap column per list item, not per
  block (2026-08-12). A block mixing an indented lettered list with the prose
  around it has two wrap columns, and a list whose items are mostly one short
  line (`b) marinas;`) sinks the at-margin ratio — so `wrapMeasure` found no
  margin and a standards-PDF `a) … j)` paste unwrapped nothing at all. The
  block is now split into segments at each list-marker line (`listSegments`)
  and each segment is measured and unwrapped on its own. This loosens no
  guard: every rejoin still satisfies `canRejoin`, and a segment too short to
  show a margin is left alone. No fixture baseline changed.

[from-code] D40: Consecutive LETTERED items are separated by a blank line;
  `-`, `*`, `1.` and `1)` items stay tight (2026-08-12). Markdown has no
  lettered list, so `a) …` / `b) …` on adjacent lines render as one
  soft-wrapped paragraph — the healed text looks right in the editor and the
  items visibly run together in the preview, which is what the user reported.
  `LineShape.isLetteredItem` distinguishes the two cases in
  `separateListItems`. The marker text is never rewritten: `j)` → `9.` would
  renumber a citation (failure mode 6).

[from-code] D41: `unwrapLines` inserts block separators on positive evidence
  only (2026-08-12). A PDF paste contains no blank lines, so every block
  boundary has to be inferred; Markdown joins adjacent lines, so a boundary
  that is not marked is a heading or a note swallowed into the prose beside
  it (reported on both macOS and iOS). A blank line is inserted between two
  lines that did NOT rejoin when any of four signals holds:
    1. the previous line stops short of the margin without finishing a
       sentence — a label (`1 SCOPE`, `1.1 General`);
    2. the previous line finished its sentence and the next is short and
       unterminated — the same label seen from above;
    3. the previous line is a finished list item and the next is not an item;
    4. the next line opens with a clause citation after a finished sentence.
  Signals 1 and 2 need a measurable margin (`wrapMeasure != nil`); in a pile
  of short fragments a short line is evidence of nothing. Signals 3 and 4 are
  structural and hold without one.
  The refusal to rejoin is NOT itself evidence: two lines left adjacent still
  render as one paragraph, which is correct whenever they were one wrapped
  paragraph, so a sentence ending mid-paragraph is deliberately left alone.
  Separating it would be failure mode 5 committed on purpose.
  Never inserted: inside a fence or frontmatter (`isSeparable` rejects any
  block containing a fence or a `---` rule — frontmatter is short unterminated
  lines top to bottom, exactly the shape signal 1 hunts); between table rows
  or column-aligned lines (detectTables is fifth in the locked order and needs
  them contiguous); around headings, rules and quotes, which already render as
  their own block; or between real `-`/`1.` list items, which would turn a
  tight list loose.
  Unmeasurable blocks are now separated but still never rejoined, so
  `wrapMeasure` remains the sole authority on rejoining.

[from-code] D42: `unwrapLines` segments a block at every line that opens a
  block, not only at list markers (2026-08-12). Verified against five
  standards-PDF samples. A page has several wrap columns: an indented list
  wraps short of the body, and a NOTE is set in smaller type so its lines run
  LONGER — measured together, the NOTE's margin becomes the block's and every
  body line falls below the threshold, so nothing unwraps at all. `opensABlock`
  = list marker, clause citation, or `isNoteOpener`. Segmenting decides only
  where a MEASUREMENT starts; whether a blank line goes in is
  `needsBlankSeparator`'s call, so a citation continuing the sentence above it
  is still not separated. A segment too short to measure borrows the block's
  margin (`unwrapBlock(_:fallback:)`) — without that, measuring a heading off a
  paragraph left the paragraph hard-wrapped.

[from-code] D43: Two more separation signals, and one rejected (2026-08-12).
  Added to D41's set:
    5. a line ending in `:` is a lead-in — its own paragraph, and `canRejoin`
       now refuses to merge across it. `1.3.1 … as given below:` was being
       swallowed into the paragraph it introduces.
    6. an unfinished line with an internal run of two or more spaces is a
       padded heading (`1.3   Installation of Premises`). Two aligned lines in
       a row are still treated as a possible table and left alone; the
       column-gap guard therefore now requires BOTH sides to be aligned, since
       a whitespace table needs three aligned rows and one aligned line beside
       ordinary prose cannot be part of one.
  Signal 1 (label line) was tightened from "short of the margin" to "at most
  HALF the margin": justified type sets many an ordinary wrapped line a few
  characters short, and the loose form split `3.12 Bonding Network (BN) - A set
  of` off from its own definition.
  REJECTED: "a finished sentence short of the margin in justified type ends a
  paragraph." It fired on multi-column-standards-pdf, where a sentence ends one
  character short of the threshold mid-paragraph, and it bought nothing on the
  samples — a justified paragraph's last line is often full-width. Consequence
  accepted and documented: two consecutive full paragraphs with no other cue
  stay adjacent and render as one. The PDF marks that boundary with leading and
  indentation, neither of which survives the clipboard; guessing would split
  paragraphs corpus-wide (failure mode 5), which is the worse error.

[from-code] D44: A segment too short to measure borrows the NEAREST MEASURED
  margin in its block, not the block's own (2026-08-12). Found by authoring the
  `lettered-list-standards-pdf` baselines by hand and reading the diff, which is
  exactly what that rule is for. The block's margin is set by whichever segment
  is widest — the NOTE in smaller type, the very thing segmenting exists to
  isolate — so a three-line clause under a heading was measured against a 62
  column, fell below the threshold and stayed hard-wrapped. A page is set in one
  body column, so the last margin actually measured in the block is the better
  estimate. Falls back to the block's margin before any segment has measured.

[from-code] D45: Corpus gains `lettered-list-standards-pdf` (2026-08-12), the
  first fixture with a lettered list, a NOTE and label lines. All three stage
  baselines authored BY HAND per D27 and the diff against the implementation
  read line by line — it disagreed twice, and both disagreements were defects in
  the code (D44), not in the baseline. Verified the fixture is actually
  exercised by mutating a baseline and confirming the suite fails.

[from-code] D46: Corpus gains three more standards-PDF fixtures (2026-08-12):
  `clause-lead-in-standards-pdf` (samples the licensing page — locks the colon
  lead-in of D43 signal 5 and the space-padded heading of signal 6),
  `definitions-with-notes-standards-pdf` and
  `definitions-with-list-standards-pdf` (definitions pages — lock the
  NOTE-in-smaller-type segmenting of D42 and the lettered list under 3.88).
  Corpus is now 11 fixtures. All nine baselines authored BY HAND and diffed
  line by line; each new fixture verified by mutation, which fails the suite.
  Two behaviours are deliberately LOCKED AS-IS rather than "fixed", both
  accepted because the lines stay adjacent and therefore still render as one
  paragraph:
  * `clause-lead-in`: the last two paragraphs stay adjacent — the D43
    limitation, now regression-tested rather than merely documented. If that
    boundary is ever inferable, this baseline is the thing that must change,
    deliberately and with the reason recorded.
  * `definitions-with-notes`: `3.14 Booth - Non-stationary unit intended to`
    does not rejoin with its continuation. At 43 characters against a 57
    column it is below `canRejoin`'s 80% threshold and above the label
    threshold. Loosening the 80% would change every fixture in the corpus, and
    the spec is explicit that a rejoin that did not happen is the survivable
    failure — the writer fixes it in one keystroke, and the render is correct
    meanwhile.

[from-code] D47: Table grid editor — row and column commands moved off the grid
  (2026-08-12). Reported as cluttered and cramped on both platforms. Every
  header cell and every row carried a drag handle AND a delete button, which
  read as noise and spent the width the content needed: columns truncated to
  `Descrip…` while two icons per row sat in the space. Those commands now live
  in a menu, opened from the row gutter or the column header, revealed on hover
  or when the row/column holds focus and reachable by long-press elsewhere. The
  gutter shows the row number otherwise, so nothing shifts when it changes.
  Capabilities are unchanged and two were added from the model's existing API:
  move row/column up/down/left/right by menu, which previously required a drag.

[from-code] D48: Column widths are measured from content, not fixed
  (2026-08-12). `minWidth: 90, maxWidth: 250` truncated any real heading no
  matter how large the window was. A column is now as wide as its widest cell
  (96-340pt), and leftover viewport width is shared EQUALLY between columns so a
  narrow table fills the sheet instead of huddling in its left third. Equal
  rather than proportional: proportional sharing lets one wide column run away
  with the room. `Color.clear` in the corner cell had to be given an explicit
  height — it is greedy, and it was stretching the header row to the full height
  of the sheet with the header text stranded in the middle.

[from-code] D49: macOS sheets get a resize grabber (`ResizableSheet`,
  Sources/macOS/ResizableSheet.swift, 2026-08-12). Spec criterion 4 asks for a
  "resizable sheet window" and SwiftUI gives a sheet no draggable edge, so the
  table editor opened at 480pt and stayed there — the reported "windows cannot
  be dragged wider". The grabber drives the content frame, which the sheet
  window follows, and the size persists in UserDefaults under
  `tableEditorSheet.width/.height`. Default 820x480, minimum 480x300. macOS
  only: iOS sheets are sized by detents, and the table editor now opens at
  `.large` there. `TableGridEditor` itself keeps zero platform conditionals.

[from-code] D50: `Color` is ambiguous in the macOS target — Vendor/SwiftTerm
  declares its own, and an unqualified `Color.primary` resolves to the
  terminal's and fails to compile. Existing code sidestepped this with
  leading-dot syntax (`.primary.opacity(…)`). TableGridEditor now says
  `SwiftUI.Color` explicitly, which is the version that survives a reader who
  does not know the trap is there.

[from-code] D51: the outline's drop target is computed from measured row
  frames, never from an assumed row height (Sources/Shared/OutlinePanel.swift,
  2026-08-13). The old code derived the target as
  `source + Int((offset / rowHeight).rounded())` with `rowHeight = 34`. Real
  rows are 30pt, and a heading that wraps to two lines is 40pt, so the
  insertion indicator pointed at the wrong row as soon as any heading wrapped —
  the reported "the visual clues of where things will land is bad". Rows now
  publish their frames through a PreferenceKey in the `outlineList` coordinate
  space and the slot is the count of rows whose midY is above the pointer.
  The frames are captured while idle and deliberately FROZEN for the duration
  of a drag: lifted rows carry a render offset, which `frame(in:)` reports, so
  re-reading mid-drag would chase itself.

[from-code] D52: the outline list is a plain `VStack`, not a `LazyVStack`.
  Verified by rendering, not assumed: a LazyVStack does not honour `zIndex`
  between its rows, so a stationary row painted over the lifted card, and it
  gives no frame at all for rows scrolled out of view — which would make the
  drop target wrong exactly when the list is long enough for it to matter. An
  outline is tens of rows; laziness bought nothing.

[from-code] D53: a drag lifts the heading AND every heading nested under it,
  because that is what `SectionMover` actually moves. The panel now shows the
  whole travelling group as one opaque floating stack with a count pill, leaves
  dashed ghosts in the vacated slots, and recedes the rest of the list. The
  lifted card must be OPAQUE (`OutlineSurface.color` under the accent tint) —
  a translucent tint let the stationary list read straight through the
  travelling section and the two collided illegibly.

[from-code] D54: `OutlinePanel.isValidDrop` mirrors `SectionMover`'s rejection
  rules rather than restating them loosely — invalid slots are `source` itself
  and everything from `source + 1` through `groupEnd`. Previously a drop inside
  your own section was accepted by the UI, returned nil from SectionMover, and
  did nothing at all; the panel now says "That is inside the section you are
  moving" in the status bar and withholds the indicator BEFORE the user
  commits. Slot `groupEnd` is treated as invalid here though SectionMover would
  allow it: it inserts the section exactly where it already ends, which is a
  no-op that would still rewrite the document.

[from-code] D55: one reorder engine on both platforms, differing only in how a
  drag starts — macOS on 4pt of movement from anywhere on the row (not the old
  20pt `≡` hit target), iOS on a 0.28s long press. The press threshold is what
  keeps the gesture off the scroll view, which is the conflict the spec names
  as a failure mode. This replaces the iOS `.editMode(.active)` List and its
  `moveCount` id-bump rebuild hack; `onSelect`/`onMove` are unchanged.

[from-code] D56: the iOS reorder is a long press that ARMS plus a simultaneous
  drag that moves and releases — deliberately not `LongPressGesture
  .sequenced(before: DragGesture)` (Sources/Shared/OutlinePanel.swift,
  2026-08-13). The sequenced form does not deliver `onEnded` when the finger
  lifts without a qualifying drag, so the lift was armed and never released:
  the row stayed lifted (blue) and, because a lift could only begin from an
  idle state, every later drag was refused. Reported as "it goes blue and stays
  there, and I can't drag into a new position" — the document still navigated
  underneath because the tap was a separate gesture that kept working. A
  simultaneous `DragGesture(minimumDistance: 0)` tracks from touch-down and
  therefore ALWAYS ends on lift, which is what clears the session.

[from-code] D57: `beginDrag(at:replacingExisting:)` — a long press takes over
  any session already open instead of being refused. macOS calls begin on every
  drag frame so it must stay idempotent there; a press is discrete, so iOS
  passes true. This is a recovery path, not an optimisation: the D56 bug was
  unrecoverable only because a lift could not start while one was already
  armed. Now a stuck session costs one press, not a relaunch.

[from-code] D58: on iOS the tap is resolved inside the reorder drag's `onEnded`
  (armed? no, and moved less than 10pt → select) rather than by a separate
  `onTapGesture`. A zero-distance drag recognises on touch-down and would race
  a tap gesture attached to the same row. One gesture, one verdict. macOS keeps
  `onTapGesture`, where the drag has a 4pt threshold and the two cannot race.

[from-code] D59: the outline ScrollView is `.scrollDisabled` while a section is
  lifted. The iOS reorder drag is a SIMULTANEOUS gesture, so without this the
  scroll view consumes the same finger and the lifted row slides against a
  moving list. UNVERIFIED BY EXECUTION — see the note in CURRENT.md.

[from-code] D60: the iOS reorder uses ONE recogniser — a zero-distance
  `DragGesture` in which hold, drag and tap are all decided, with the hold
  timed by hand (Sources/Shared/OutlinePanel.swift, 2026-08-13). This
  supersedes D56's two-gesture shape, which was itself a fix for the
  `.sequenced` shape. All three attempts and why the first two failed:

    1. `LongPressGesture.sequenced(before: DragGesture)` — never delivers
       `onEnded` when the finger lifts without a qualifying drag, so a lift
       could be armed and never released.
    2. `LongPressGesture` + `.simultaneousGesture(DragGesture(min: 0))` — a
       race. A zero-distance drag recognises on touch-down and can cancel the
       press. Reported as "worked initially, now I cannot highlight anything,
       but clicking still jumps the document": the tap was resolved inside the
       drag (D58) so it kept working, while the press had stopped winning.
       Nothing had changed except which recogniser won.
    3. One drag, hold timed with a token-guarded `asyncAfter` that arms only
       if the same touch is still down and has not strayed past `tapSlop`.

  The third rests on evidence rather than inference: the user's own report
  proved the simultaneous drag delivers both `onChanged` and `onEnded` on a
  real iPad, because tap-to-navigate — which lives inside those callbacks —
  kept working when everything else did not. The hold is then plain Swift on
  top of callbacks known to arrive, with no second recogniser to lose to.

[from-code] D61: `beginDrag` refuses to re-arm the row that is already lifted.
  Re-arming zeroes the session's translation, so the card would snap back to
  its origin mid-drag. Cheap guard, and it makes the arming path safe to call
  more than once per touch.

[from-code] D62: UI conventions are written down and locked in
  `docs/ui-conventions.md` (2026-08-13), referenced from CLAUDE.md §1/§2 and
  build-plan §4.3. Every rule in it cites the defect that produced it — the
  file is a defect ledger, not a style guide, and it is worth reading only for
  as long as that stays true. Rules are LOCKED: changing one is RED, adding one
  after a new defect is the intended growth path.

  It also splits T4 in two, because "T4, so dogfood it" was letting appearance
  defects through that a two-minute `ImageRenderer` pass catches: static
  appearance is verifiable in-session and an agent may iterate on it; gesture
  and feel are not verifiable here at all (no touch injection, no app host) and
  an agent must ship one reasoned change and hand back a human check instead of
  looping.

[from-code] D63: interface examples are written in the reader's domain, not the
  author's (Sources/Shared/SmartFolderPanel.swift, 2026-08-13). The smart
  folder sheet shipped with `cable schedule`, `voltage drop` and `earth-fault`.
  Kitib is a writing environment whose engineering content is one use among
  several, and those examples told every other writer the tool was not for
  them. Replaced with `draft revision`, `draft OR outline`,
  `chapter NOT appendix`, `"opening paragraph"`, and made tappable so an
  example is a starting point rather than something to retype.

[from-code] D64: the hyphenation guidance was wrong and is now both correct and
  conditional. Measured against FTS5 directly, not assumed:

      MATCH 'copy-edit'    -> error: no such column: edit
      MATCH '"copy-edit"'  -> matches
      MATCH 'copy edit'    -> matches

  The shipped note said a hyphenated query "returns nothing" and advised
  searching a different word. It raises an ERROR, and quoting fixes it — the
  advice was wrong in both halves. `AppState.searchSmartFolder` swallows the
  throw with `try?`, so the malformed query arrived as an empty array and was
  indistinguishable from a genuine miss; the permanent orange warning in the
  form was compensating for that.

  Now: `QueryLint.bareHyphenatedTerm` detects the case, the form shows the
  advice ONLY when the typed query contains a bare hyphenated term, and offers
  "Add quotes"; the results pane distinguishes "needs quotes" from "no matches"
  and offers the same fix.

[from-code] D65: `QueryLint` lives in `Sources/Core/Search/`, not beside the
  view that uses it. It is a pure function, and Sources/Shared is outside the
  test bundle (D16) — leaving it in the panel would have made a rule about
  query correctness permanently untestable. 15 tests in
  `Tests/KitibTests/Search/QueryLintTests.swift`; suite 317 -> 332, and the
  count was checked to rise (D22).

  General form: **if a piece of new UI logic can be phrased as a pure function,
  it belongs in Core where it can be tested.** What stays in the view is
  arrangement.

[from-code] D66: `.buttonStyle(.borderless)` cannot be drawn by `ImageRenderer`
  — it renders as a yellow prohibited block, as does `TextField`. Established
  with a probe view holding the suspect control beside known-good ones, before
  changing any code; it was very nearly "fixed" as a real defect. The three
  borderless buttons in the panel were switched to `.plain` with an explicit
  accent colour, which looks the same on macOS and can be verified. A control
  that cannot be rendered is a control that cannot be checked.

[from-code] D67: A paste that arrives with NO line breaks is a first-class source
  class, not an edge case. Reported 2026-08-13: a run of numbered definitions
  copied out of Word healed into one undifferentiated slab. Every mechanism that
  gives a clause its own block — `blockSegments`, `opensABlock`,
  `needsBlankSeparator` signal 4 — reads LINES, and the clipboard carried one.
  Only `splitLetterItems` fired, which is why the render broke at `a)`/`b)` and
  nowhere else. Fixed by generalising the unlined pre-split into
  `splitBlockOpeners`, which reuses `LineShape.startsWithDottedNumeral` and
  `isNoteOpener` rather than restating them.

  Mid-line evidence is weaker than a line break, so the split is deliberately
  NARROWER than `opensABlock`: it needs a completed sentence in front of it, a
  dotted numeral must be followed by a capitalised title (`3.73 Electrical` is a
  definition, `0.4 s` is a value), and only capital `NOTE`/`NOTES` counts.
  `Table`, `Clause`, `Figure` and the rest are excluded mid-line: there they are
  more often prose than a block head, and a wrong split cuts a paragraph in half
  (failure mode 5), which is the worse error.

  GREEN, and verified as such: every one of the 11 existing fixtures produces
  byte-identical `heal` output before and after. No baseline was re-authored —
  had one moved, the change would have been AMBER and parked.

[from-code] D68: Help CONTENT lives in `Sources/Core/Help`, not beside the view.
  The Help window is the one surface that is believed on sight and checked by
  nobody: `Sources/Shared` is outside `KitibTests` (D16), so help text written
  in the view cannot be asserted on at all. That is precisely how the smart
  folder hyphenation advice — wrong in both halves — stayed shipped until D64
  caught it by hand.

  So `HelpEntry`/`HelpContent`/`HelpSearch` are Core data and Core logic, and
  `HelpView` is presentation only. `HelpContentTests` now holds the rules that
  used to be good intentions: every Cheatsheet entry carries an example; every
  guide has at least two steps; guide titles are written as the reader's problem
  ("I pasted from a PDF…"); no entry may contain the retracted D64 advice; no
  entry may use an author-domain example (D63); fenced and `$$` examples must
  balance; a table example must include its `| --- |` row. A future edit that
  breaks any of these fails the suite instead of shipping.

  Examples are also checked against THIS renderer, not Markdown in general.
  `ExporterCore.inline` matches `*italic*` only, so a test rejects any example
  showing `_underscore_` emphasis — generic-Markdown advice that would render as
  literal underscores here.

[from-code] D69: One Help window, three lanes, one search field — not a separate
  "Use Case" menu. The use-case content (now the Guides lane) was the missing
  half of the help; a second top-level surface was not. Two entry points make
  the reader guess which one to open before they can look anything up, and the
  search then either covers one lane (useless) or is built twice. Searching
  spans every lane and reports which lane each hit came from, so the taxonomy
  never has to be understood in advance. Typing widens the selection to All
  once, on the transition only, so a reader can still narrow afterwards.

  Search is deliberately NOT FTS5. A few dozen fixed entries do not justify an
  index, and FTS5 would import the tokenizer behaviour `QueryLint` exists to
  apologise for — a reader searching help must never meet a malformed-query
  error. Fold-and-contains is exact and has no syntax to get wrong.

[from-code] D70: The Help empty state distinguishes three different nothings —
  the answer is in another lane (offers the count and a way across), you
  mistyped (offers near-miss terms), or the app does not do this (says so).
  Same principle as D64: a blank pane conflates "wrong word" with "not a
  feature", and the reader cannot tell which without it. Near misses use
  Damerau-Levenshtein, not plain Levenshtein: a transposition is the commonest
  typing mistake and plain edit distance scores `tabel`/`table` at 2, the same
  as an unrelated word.

  A Copy button must hand over something usable. The smart folder example
  originally carried its explanations in an aligned second column inside the
  code block, which Copy would have pasted into the reader's document — the
  gloss moved to the `renders` line.

[from-code] D71: `WKWebView.printOperation(with:)` is not used. On macOS 26 it
  never returns: `op.run()` enters `-[NSView _printForCurrentOperation]` and
  emits pages forever, growing the output without bound — one line of HTML
  reached 206 MB in 30 seconds and was still climbing. That is what ⌘P did, and
  what PDF export did after the save panel. Reproduced in a signed, bundled app
  stripped to a plain `WKWebView` with default `NSPrintInfo`, no margins and no
  pagination settings; it also reproduced with the view hosted in an offscreen
  window, in a visible window, with `verticalPagination = .fit` (which should
  force a single page), and with the operation started outside the JavaScript
  callback. `NSPrintOperation` itself is sound — `PDFDocument.printOperation`
  completes in 0.3s. The defect is WebKit's printing view, whose frame stays
  0×0, so pagination never advances.

  The two earlier attempts (7773779 runModal→run, 9d6349b NSTextView→WebKit)
  were treating this same defect from the wrong end.

  Kitib now renders the document as one continuous page, cuts it into pages
  with `PagePlan`, and captures each page with `createPDF`, which terminates
  and honours the requested rect exactly. `NSPrintOperation(view: webView)`
  was measured too and rejected: it completes, but every page is blank.

  Consequences, all deliberate:
  - Page breaks are ours, not WebKit's. `break-inside: avoid` in the print CSS
    is no longer what protects a table or a code fence — `PagePlan` is, and it
    protects TOP-LEVEL blocks only. A table nested inside a list or blockquote
    can still be split.
  - A page ends where the next page starts, so a block moved down to stay
    intact leaves white space above it rather than being printed twice. Caught
    by rendering, not by review: the first cut ran each page on for a full page
    height and printed the straddling table on both pages.
  - The web view frame is widened by the scrollbar gutter before measuring, so
    text lays out across the full printable width instead of sitting left with
    a 17pt gap on the right.
  - `standardPrintInfo()` now sets ZERO margins. The pages already carry the
    50pt margins, and the print job must not inset them a second time.
  - Print and PDF export now report failure rather than doing nothing. A silent
    no-op on ⌘P is the same class of defect as the one being fixed.

  `PagePlan` lives in Core with 17 failure-mode tests, because the arithmetic —
  not the WebKit call — is what decides whether a page is dropped, duplicated,
  or unbounded. The `maxPages` ceiling is there so that no future change can
  reintroduce unbounded output in any form.

[from-code] D72: Every name the app invents for a new file or folder goes
  through `UniqueName.next(base:isTaken:)` in Core. The sidebar's new-folder
  button did nothing on its second and every later press, because
  `createDirectory(withIntermediateDirectories: true)` returns success — not an
  error — when the directory already exists, so the collision was invisible at
  the call site. `newFile` had always carried its own uniquing loop; `newFolder`
  had none, and the asymmetry was the whole defect.

  Uniquing is Core, not AppState, because `Sources/Shared` is not compiled by
  KitibTests (D16) — logic left there cannot be tested at all. The predicate
  form (`isTaken: (String) -> Bool`) keeps the function free of filesystem
  access and puts case policy at the call site, where the volume is known.

  Three rules the tests pin down: gaps are filled, so deleting "New Folder 2"
  makes the next press reuse that name rather than climbing forever; a base that
  already ends in a number keeps it ("Section 2" → "Section 2 2", never
  "Section 3"), because that digit is the user's, not a suffix we own; and a
  predicate that never yields terminates at `attemptLimit` with a UUID-suffixed
  name instead of hanging a button press.

  `newFile`'s own inline loop was left alone — out of scope for the fix.

[from-code] D73: The search index is rebuilt on a coalesced timer, never
  synchronously from a file operation. `rebuildSearchIndex()` opens and reads
  every Markdown file under the root and re-inserts it into FTS5, on the main
  thread — and it was called from `refreshTree()`, which every file operation,
  the autosave and the FSEvents watcher call. One save therefore cost two whole-
  vault passes: the autosave indexed directly, then the app's own write woke the
  watcher, which rebuilt the tree and indexed again. That was the sidebar lag.

  `scheduleIndexRebuild()` collapses a burst into one pass after
  `indexCoalesceDelay` (1.0s). **Ruled by the human, 2026-08-14, as a RED
  change**: search and smart-folder results may now trail the disk by up to that
  delay. Accepted — the alternative was a UI that stalls on every keystroke's
  autosave. The index is still built immediately when it does not exist yet, so
  the first query after opening a root is never empty.

  Not done, and deliberately: moving the read + insert to a background queue.
  SQLite connections have thread affinity and `SearchIndex` is covered by the
  suite; that is a separate, larger change.

[from-code] D74: A List selection binding must store what it is given, and
  folder expansion is keyed by path. Two defects in the sidebar, one cause —
  state that SwiftUI owned but the model threw away.

  The selection binding's setter opened files and discarded the value, so
  clicking a folder highlighted a row that the binding then denied. SwiftUI and
  the model disagreed and the next click on another row was dropped: select a
  folder, and the sidebar was stuck. Selection is now `@State selectedRowID`,
  with `onChange` opening files and mirroring `selectedFileID` when a file is
  opened from elsewhere (recents, wiki-link).

  Expansion was `DisclosureGroup`'s implicit state, which is keyed on view
  identity — and `refreshTree()` replaces every `FileItem`, so the tree
  re-collapsed on every save. It is now a `Set<String>` of paths held by
  `SidebarView`, which survives the rebuild.

  Clicking a folder's name toggles it, not only the chevron — but on **macOS
  only**, because a tap on an iOS list row already toggles a `DisclosureGroup`
  and a second toggle would cancel the first out.

  Selection is set in the `isExpanded` binding's setter, not in the tap. The
  chevron is `DisclosureGroup`'s own control: it reaches neither the label
  gesture nor the List, so a chevron click left the highlight behind even after
  the label click was fixed. The setter is the single path both ways of opening
  a folder go through, which is the only place that covers both.

  The tap must not rely on the List for the highlight either. The first cut left the highlight
  to the List and it stayed stranded on the previously clicked folder: `.onDrag`
  on the row label swallows the mouse-down, so the List never learns the click
  happened. This is the trap already recorded for the file rows, which is why
  they open from an explicit tap rather than from selection. One gesture now
  owns the whole interaction — set `selectedRowID`, then toggle — per
  ui-conventions §3. The file rows set `selectedRowID` in their tap for the same
  reason: without it, clicking the already-open file could not pull the
  highlight back off a folder.

[from-code] D75: iOS sidebar selection uses the native List, not the macOS
  gesture workarounds (2026-08-15). The file row's
  `.simultaneousGesture(TapGesture())` and the file/folder rows' `.onDrag` /
  `.onDrop` are now `#if os(macOS)`. Those exist only because, on macOS,
  `.onDrag` swallows the mouse-down on a quick click and a custom tap is the
  only way to open reliably (D74). On iOS neither premise holds: `.onDrag`
  starts from a long press, and a custom tap races the List's own selection
  (ui-conventions §3). iOS now opens files through `List(selection:)` +
  `.onChange(of: selectedRowID)`, the same plain path the iPhone browser
  (Sources/iOS/FileBrowser_iOS.swift) already uses and that is the one known
  working on a device. Consequence: sidebar drag-and-drop reordering is
  macOS-only. It was never specified or tested for iOS and is the prime
  suspect for the "nothing selectable on iPad" report; parked, not dropped.

[locked] D76: Sidebar "up one level" navigation (2026-08-16). Human ruling
  in-session on "cannot navigate my drive, no way to move back from the
  folder it opens on". A chevron.up button in the SidebarView header moves
  the root to its parent folder via AppState.navigateUp(); the new parent
  becomes the persisted root, and the button is disabled at the filesystem
  root (whose parent is itself).

  Platform split, deliberate:
  - macOS: the app is not sandboxed, so a plain path to the parent works;
    navigateUp() reassigns rootURL directly.
  - iOS: the document-picker grant covers the picked folder and its
    descendants only, so a parent is normally out of scope. navigateUp()
    calls startAccessingSecurityScopedResource() on the parent first; if
    that is refused it re-presents the folder importer (chooseFolder())
    instead of navigating to a folder the app cannot read. The open
    document is saved and cleared only after a real upward move is
    confirmed, so a cancelled picker does not disturb it.

  Cost, already parked not introduced: each step up widens the tree and the
  whole-vault search re-index (the eager-tree and main-thread-index items in
  PARKED.md), now reachable in one click.

  Not unit-testable: navigateUp lives in AppState (Sources/Shared, outside
  KitibTests per D16). Verified by compiling both targets and the unchanged
  403-test suite.

[from-code] D77: The app opens no folder at launch. `AppState.init()` no longer
  restores the persisted root; it reads the folder's *name* from UserDefaults
  and nothing else. **Ruled by the human, 2026-08-17, as a RED change** — it
  changes what D76's outstanding relaunch check verifies.

  What it fixes, and why it was worse than it looked. `init()` ran
  `restoreRootFromBookmark()` → `refreshTree()` → `FileItem.init`, which
  recurses the whole tree, then `scheduleIndexRebuild()`, whose nil-index guard
  skips the 1s coalesce (D73) and indexes every Markdown file into FTS5
  synchronously. All of it inside `App.init()`, before the first window exists —
  so macOS bounced the dock icon until it finished.

  The persisted root on this machine was `/`, climbed to with D76's up-chevron.
  Launch was therefore recursively enumerating the entire filesystem, including
  /System and mounted volumes, and reading every .md file it found. The bounce
  was not a slow launch; it was a launch that effectively never completed.

  The same line hid the Open button. Four "Open Folder…" affordances exist
  (SidebarView, ContentView's empty state, FileBrowser_iOS, the File menu) and
  every one is gated on no folder being open — a state that was unreachable once
  init() always restored one. Removing the auto-restore made the existing
  buttons visible again; no new open affordance was needed for the empty state.

  Replaced by an explicit `reopenLastFolder()` behind a "Reopen “name”" button
  beside "Open Folder…", so one click restores the old behaviour. It returns
  false and clears `lastFolderName` when the bookmark is stale and the path is
  gone, rather than leaving a button that does nothing.

  Two duplicate-work bugs fixed in passing (GREEN): the old restore path called
  `refreshTree()` and `startWatchingRoot()` explicitly *after* assigning
  `rootURL`, whose `didSet` already does both — so every restore walked and
  indexed the vault twice. Assigning `rootURL` is now the whole operation.

  Consequence for the two PARKED performance items: background indexing (RED)
  and lazy `FileItem` loading (AMBER) are no longer needed to fix *launch*, and
  stay parked. They still apply to opening a very large folder by hand, which is
  now a pause the user asked for rather than one they cannot avoid.

  Also added: a folder button in the SidebarView header next to the D76
  chevron.up, so switching folders is reachable while a folder is open. iPad had
  no in-app route at all (no menu bar); iPhone already had "Open Another
  Folder…" in its toolbar menu and was left alone.

  Not unit-testable: all of it is AppState + views (Sources/Shared, outside
  KitibTests per D16). Verified by both targets building, the unchanged 403-test
  suite, and by launching the built app — it now sits at 0.0% CPU 86s after
  launch with the persisted root still `/`.

[from-code] D78: `KitibCommands` is shared, not macOS-only. iPadOS builds a real
  menu bar from `.commands` exactly as macOS does, but the type was declared in
  `Sources/macOS/AppDelegate_macOS.swift` — a file the iOS target does not
  compile — and the `.commands` modifier itself was inside `#if os(macOS)` in
  KitibApp.swift. iPad therefore fell back to the system default menu: File held
  "Close Window" and nothing else. No New Document, no Open Folder, no Find, no
  Save, no Help. Reported by the human, 2026-08-17.

  Moved verbatim to `Sources/Shared/KitibCommands.swift` and applied on both
  platforms. Two items stay `#if os(macOS)`, because their implementations are
  macOS-only and the iOS target would not link:
  - **Print…** — `Exporter.printDocument` is declared only in
    Exporter+macOS.swift; iOS exports via its own share-sheet path.
  - **Terminal** — `AppState.openTerminal` is `#if os(macOS)` (SwiftTerm).
  Everything else compiles and is wired on iOS, including Find: the iOS editor
  sets `state.performFind` (EditorView_iOS.swift), so the Edit-menu find
  commands drive the real editor.

  Five shortcuts had to move rather than be duplicated. `DetailView_iOS`'s
  toolbar buttons carried `.keyboardShortcut` for ⌘N, ⇧⌘F, ⇧⌘L, ⇧⌘P and ⇧⌘D —
  the same keys `KitibCommands` binds. Registering both would collide and would
  list each shortcut twice in the ⌘ HUD, so the toolbar modifiers were removed;
  the menu now owns every shortcut on both platforms and the toolbar buttons
  remain tappable. **One deliberate behaviour change:** ⌘N on iPad opened the
  template picker (`showTemplates`, local @State inside DetailView_iOS and so
  unreachable from a Commands struct); it now creates an Untitled document, the
  same as macOS. That is the parity the human asked for. The template picker is
  unchanged and still reachable from the toolbar's doc.badge.plus button — it
  simply no longer has a keyboard shortcut.

  Verified: both targets build (the iOS build compiling KitibCommands is what
  proves every non-gated command exists on iOS), 403-test suite unchanged and
  green, and the app was installed and launched on an iPad Pro 11 M4 simulator.
  NOT verified: the menu bar's actual contents. Rendering it needs a held ⌘ on a
  hardware keyboard, and simctl cannot send key events — human check required.
