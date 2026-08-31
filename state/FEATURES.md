# FEATURES.md — what EXISTS, confirmed from code. Cap: 200 lines.
# ✅ = implemented and confirmed by reading the file.
# 🔨 = partial, stubbed, or cannot confirm it works.
# Listed in source-file order, not blueprint order.

## App Shell

✅ App entry point (KitibApp) — Sources/Shared/KitibApp.swift — macOS + iOS, AppState, scenePhase save
✅ ContentView (app shell) — Sources/Shared/ContentView.swift — NavSplitView(macOS)/AdaptiveShell(iOS), folder importer, Help/About sheets, template picker

## State & File Management

✅ AppState (central observable) — Sources/Shared/AppState.swift — FileItem tree, open/save/rename/move/delete/duplicate/newFolder, security-scoped bookmarks, FSEvents watcher (macOS), autosave (1.2s debounce), word goals, to-dos, recent files (last 12), scroll sync, find bridge. init() opens NO folder and touches no filesystem (D77) — it reads lastFolderName from UserDefaults only; reopenLastFolder() does the restore on demand.
🔨 Launch + folder opening — Sources/Shared/{AppState,ContentView,SidebarView}.swift + Sources/iOS/FileBrowser_iOS.swift — No vault work at launch, so no dock bounce (D77). Empty states offer "Open Folder…" plus "Reopen “name”" when a previous folder is remembered; the reopen offer clears itself if the bookmark is stale and the path is gone. Sidebar header gains a folder button beside the D76 chevron.up — the only in-app route to another folder on iPad. 🔨 not ✅: no UI is testable (D16). The empty state IS visually verified on an iPad Pro 11 M4 simulator (both buttons render, launch shows no folder open); the macOS empty state and the sidebar header button are still unrendered.
✅ Menu bar (macOS + iPadOS) — Sources/Shared/KitibCommands.swift — File (New Document ⌘N, Open Folder… ⌘O, Save ⌘S, Print ⌘P macOS-only), Edit find group (⌘F/⌥⌘F/⌘G/⇧⌘G/⌘E), Writer menu (focus, typewriter, line numbers, split preview, front matter, terminal macOS-only, to-dos, outline, appearance, text size, lorem ipsum, print options), About and Help. Shared since D78 — it was macOS-only, so iPad had nothing but "Close Window". Print and Terminal are #if os(macOS) because their implementations are. The five duplicate .keyboardShortcut modifiers on the DetailView_iOS toolbar were removed; ⌘N on iPad now creates an Untitled document rather than opening the template picker (deliberate, macOS parity).
🔨 File tree (outline sidebar) — Sources/Shared/SidebarView.swift — Recursive OutlineRows, FolderRow drop targets, context menus (Rename, Duplicate, Reveal in Finder, Trash, New File/Folder Here, Open in Terminal). Selection is real @State and folder expansion is keyed by path so it survives refreshTree (D74). macOS: drag-and-drop reorganization + explicit-tap opening (onDrag swallows mouse-down). iOS: native List selection + onChange opening (D75 — the macOS tap/onDrag/onDrop workarounds are #if os(macOS)). 🔨 not ✅: no UI here is testable (D16) and the click behaviour is human-check-required
✅ UniqueName (new-name collision) — Sources/Core/FileNaming/UniqueName.swift — next(base:isTaken:): base if free, else first free "base N"; fills gaps, never increments a number already in the base, terminates at attemptLimit with a UUID suffix. No filesystem access; used by AppState.newFolder (D72). 12 tests — Tests/KitibTests/FileNaming/UniqueNameTests.swift
✅ Up-navigation — Sources/Shared/SidebarView.swift + AppState.navigateUp() — chevron.up button in the sidebar header moves the root to its parent folder (D76). macOS: plain-path reassignment. iOS: startAccessingSecurityScopedResource() on the parent first, falling back to the folder importer when the parent is outside the picker grant. New parent is persisted; button disabled at the filesystem root. Verified by compiling both targets + the unchanged 403-test suite; not unit-testable (D16).

## Editor

✅ macOS editor — Sources/macOS/EditorView.swift — NSTextView, custom LineNumberRuler (NSRulerView), focus dimming (temporary attributes), typewriter scrolling, scroll sync with preview, find/replace bridge (NSTextFinder), live Markdown highlighting, selection stats, centered 760pt column
✅ iOS editor — Sources/iOS/EditorView_iOS.swift — UITextView (TextKit 1 forced), LineNumberGutter (UIView), focus dimming, typewriter scrolling, scroll sync, find bridge (UIFindInteraction), selection stats, centered column

## Syntax Highlighting

✅ Markdown highlighter — Sources/Shared/MarkdownHighlighter.swift — Regex-based live styling on NSTextStorage: headings, bold, italic, code, links, lists, math ($…$), images, tables (pipes), fenced blocks, blockquotes, horizontal rules

## Preview

✅ Live HTML preview — Sources/Shared/PreviewView.swift — WKWebView, in-place JS update (no reloads), scroll sync (bidirectional), file-switch detection, numbered captions toggle, frontmatter toggle

## Export Pipeline

✅ Page planning — Sources/Core/Export/PagePlan.swift — Cuts a continuously-rendered document into printed pages without splitting a top-level block; bounded by `maxPages`. Tested by Tests/KitibTests/Export/PagePlanTests.swift (17 failure-mode tests)

✅ Markdown → HTML converter — Sources/Shared/ExporterCore.swift — Self-contained: headings, bold, italic, code, links, images (data URIs for local files), tables, blockquotes, lists (loose-list support), horizontal rules, frontmatter parsing & metadata table, Mermaid code blocks, $$ math blocks, numbered figures/tables/equations/diagrams, full HTML page with KaTeX + Mermaid
✅ macOS export — Sources/macOS/Exporter+macOS.swift — Print and PDF export (WebPaginator: offscreen WKWebView → createPDF per page → PDFDocument; NOT WKWebView.printOperation, which never returns on macOS 26 — D71), PDF page number stamping, HTML export (save panel), Copy as Rich Text (NSTextStorage to pasteboard)
✅ iOS export — Sources/iOS/Exporter+iOS.swift — PDF (WKWebView.createPDF), HTML temp file for share sheet, rich text copy (RTF + plain text to UIPasteboard)

## Bundled Web Assets

✅ KaTeX + Mermaid bundling — Sources/Shared/WebAssets.swift — Loads katex.min.css/js, auto-render.min.js, mermaid.min.js from app bundle web/ folder; used by preview and export

## Templates

✅ Document templates — Sources/Shared/Templates.swift — 6 templates: Blank, Report (with extensive Mermaid examples), Article (with frontmatter + flowchart), Design Note (with frontmatter + flowchart), Blog Post, LinkedIn Post; each with optional word goal

## Stats & Goals

✅ Stats bar — Sources/Shared/StatsBar.swift — Words, chars, lines, paragraph count, reading time, selection stats (words/chars), word goal progress bar, dirty/saved indicator, goal popover

## To-Do Lists

✅ Per-document to-dos — Sources/Shared/TodoPanel.swift — Add, toggle, delete, clear done; persisted per file in UserDefaults; platform-adaptive sizing (Mac dense, iOS touch targets)

## Integrated Terminal (macOS only)

✅ Terminal — Sources/macOS/TerminalView.swift — Vendored SwiftTerm, xterm-class emulation, login zsh PTY, TerminalSession manages lifecycle, TerminalPanel (SwiftUI header + NSView host), light/dark appearance tracking

## Menu Bar

(See "Menu bar (macOS + iPadOS)" under State & File Management — KitibCommands
moved to Sources/Shared/KitibCommands.swift in D78 and is no longer macOS-only.)

## Platform Layer

✅ Cross-platform shims — Sources/Platform/Platform.swift — PlatformColor, PlatformFont, PlatformImage typealiases; FindAction enum; Platform.beep() + delete() helpers; semantic color extensions; italic font
✅ macOS delegate — Sources/macOS/AppDelegate_macOS.swift — Save on quit, terminal stop, icon set, appearance apply. (KitibCommands moved out to Sources/Shared in D78.)
✅ macOS DetailView — Sources/macOS/DetailView_macOS.swift — Editor + Preview + Todos in HSplitView, Terminal in VSplitView, StatsBar, toolbar with all toggles + export/share menu
✅ iOS adaptive shell — Sources/iOS/FileBrowser_iOS.swift (consolidated from
   AdaptiveShell_iOS.swift) — Compact/regular split: iPhone NavigationStack +
   FileBrowser vs iPad NavigationSplitView + SidebarView
✅ iOS FileBrowser — Sources/iOS/FileBrowser_iOS.swift — Push-navigation file browser with breadcrumbs, search, swipe actions (delete/rename/duplicate), recents section
✅ iOS DetailView — Sources/iOS/DetailView_iOS.swift — Compact: preview full-screen, to-dos as sheet. Regular: editor/preview/todos side by side. Fireworks overlay. Export + share sheet.

## Fun

✅ Fireworks (macOS) — Sources/macOS/FireworksController.swift — Floating NSPanel with CAEmitterLayer rocket→burst celebration on word goal
✅ Fireworks (iOS) — Sources/iOS/Fireworks_iOS.swift — SwiftUI overlay with CAEmitterLayer burst
✅ Lorem Ipsum generator — Sources/Shared/LoremIpsum.swift — Sentence, paragraph(s) with canonical opening or random

## Help & About

🔨 Help window — Sources/Shared/HelpView.swift — Searchable three-lane reference (Cheatsheet / Guides / Shortcuts). One search field over every lane, lane hit-counts, copyable examples, collapsible guides, three distinct empty states. Rendered and looked at in 16 states; no gesture or clipboard verification possible from a session (D16) — 🔨 not ✅ per ui-conventions §1.3
✅ Help content model — Sources/Core/Help/{HelpEntry,HelpContent,HelpSearch}.swift — 51 entries as data in Core so they are inside the test bundle; fold-and-contains search with title/keyword/body weighting and Damerau near-miss suggestions (D68)
✅ About window — Sources/Shared/AboutView.swift — Icon, version, name etymology

## Project Config

✅ XcodeGen — project.yml — Two targets: Kitib-macOS + Kitib-iOS; macOS 13.0 / iOS 16.0; bundle ID com.sean.kitib
✅ App icon asset catalog — Resources/Assets.xcassets/AppIcon.appiconset/ — Full set for Mac + iPhone + iPad

## Vendored Dependencies

✅ SwiftTerm — Vendor/SwiftTerm/ — Full xterm-class terminal emulator: PTY, Metal-accelerated rendering, search, sixel, Kitty graphics protocol

## Tests

✅ Test harness (KitibTests) — project.yml + Tests/KitibTests/HarnessSmokeTests.swift —
   macOS logic-test bundle, no app host, compiles Sources/Core directly. Verified
   green (1 test executed) AND verified red on a broken assertion (exit 65).
   Run: DEVELOPER_DIR=<xcode>/Contents/Developer xcodebuild test -project
   Kitib.xcodeproj -scheme KitibTests -destination 'platform=macOS,arch=arm64'
✅ gauntlet.sh gate_tests — xcodebuild; runs xcodegen first (D22) and refuses to
   pass on an empty suite
✅ scripts/validate.sh — real validator. Checks paste-healing corpus integrity
   WITHOUT executing repairGlyphs, so a Swift bug cannot make it pass: dirs match
   FixtureCorpus.names, both files present/non-empty/valid UTF-8, no tautological
   pairs, no literal \uXXXX escape text, no mangled-glyph residue in expected.md,
   no U+2010 variants of protected compounds. Verified red on 3 seeded defects.
✅ scripts/defect-corpus.sh — real gate, corrected 2026-08-11 (commit 57c8681
   vacuous-proof correction). Three defect files at Tests/Fixtures/defect-corpus/
   (rejoined-compound.md, destroyed-table.md, stripped-clause.md). Shape-based
   checks — no Swift (D26). Gate mode: exits 0 when all three defects confirmed
   present, FAILS if the directory contains anything other than the three expected
   files (D32). Scan mode: recursive find, exits non-zero when any defect found,
   exits non-zero on zero files (D33), prints file count every run. Verified both
   directions: gate mode → 0 (3 files, all 3 detected), clean fixture corpus
   (recursive) → 0 (24 files scanned, no defects), each individual defect → 1.
   Original "verified green on clean corpus" was vacuous: the non-recursive glob
   matched zero files against Tests/Fixtures/paste-healing/ and exited 0 having
   read nothing — the D19 failure pattern exactly. Corrected 2026-08-11.
✅ Golden document corpus — Tests/Fixtures/golden-documents/ — 5 hand-authored
   documents (01-design-note.md through 05-edge-cases.md) + README.md. Covers
   design note, spec extract, test report with tables and Mermaid, minimal doc,
   and edge cases. One document contains an SLD (03-test-report.md, Mermaid
   flowchart).
✅ GoldenDocumentTests — Tests/KitibTests/GoldenDocumentTests.swift — 4 tests:
   corpus non-empty assertion, every document loads, byte-for-byte round-trip
   (criterion 10 — ALL FIVE DOCUMENTS GREEN after D35), bundled-not-source-tree
   check.  The two failures caught on first run (CommonWords gap) resolved by
   the inverted dehyphenate rule.
   Test count: 136 (up from 125 — 11 new DehyphenateLexiconTests).
✅ scripts/golden-roundtrip.sh — real integrity gate. Checks the golden corpus
   WITHOUT running Swift (D26): directory exists, ≥1 .md, every file non-empty/
   valid UTF-8/ends with newline, no excluded code points (D23/D24 glyphs:
   U+2014, U+2013, U+2010, U+2011, U+2018, U+2019, U+201C, U+201D, U+00A0,
   U+200B, U+FB01, U+FB02). Prints file count every run; zero files exits
   non-zero (D33). Verified both directions: 6 files → exit 0, zero files →
   exit 2. Green alongside validate.sh and defect-corpus.sh — gauntlet.sh now
   has three real gates of four.

## Paste Healing (T1 — corpus, ProtectedCompounds, repairGlyphs)

Scores (build-plan §4.1): Value 5 / Verifiability 5 / Blast radius 4 / Dep depth 1
→ priority 6.25. Spec: specs/paste-healing.md.

✅ ProtectedCompounds lexicon — Sources/Core/PasteHealing/ProtectedCompounds.swift — all 6 compounds
✅ repairGlyphs — Sources/Core/PasteHealing/RepairGlyphs.swift — ligature expansion,
   smart-quote normalise, em/en/U+2010/U+2011 → "-" (D24), NBSP → space and ZWSP
   removed (D23), double-encoded recovery for ° Ω ² and NBSP
✅ Paste-healing fixture corpus — Tests/Fixtures/paste-healing/ — 7 dirs: 5 source
classes + protected-compounds + paginated-standards-pdf. Each has input.txt plus
one expected file PER PIPELINE STAGE (D27): expected-repairglyphs.md,
expected-unwrapped.md, expected.md.
✅ Fixture loader + corpus tests — Tests/KitibTests/PasteHealing/FixtureCorpus.swift,
   CorpusTests.swift — loads every fixture from disk via #filePath and asserts the
   directories on disk match FixtureCorpus.names exactly
✅ Paste-healing tests — Tests/KitibTests/PasteHealing/RepairGlyphsTests.swift +
   CorpusTests.swift + StripArtefactsTests.swift + UnwrapLinesTests.swift +
   UnwrappedStageTests.swift + DehyphenateTests.swift +
   DehyphenateLexiconTests.swift + DetectTablesTests.swift +
   PreserveClauseNumbersTests.swift + PasteHealerTests.swift +
   HealedStageTests.swift — 136 tests total (incl. harness smoke + Goldens), 0 failures

## Paste Healing (T2 — stripArtefacts, unwrapLines)

✅ LineShape (shared line classifier) — Sources/Core/PasteHealing/LineShape.swift —
   isStructural (heading/list/quote/fence/rule/pipe row/indented), isClauseCitation
   (§, dotted numeral, Table/Figure/Clause/Annex/Appendix/Regulation), hasColumnGap,
   endsSentence. One implementation so both transforms classify a line identically.
✅ stripArtefacts — Sources/Core/PasteHealing/StripArtefacts.swift — removes page
   furniture by RECURRENCE (≥3 after digit-normalisation, so "Page 1 of 9"/"Page 2 of
   9" key alike). A line qualifies only if blank-isolated on BOTH sides, ≤72 chars,
   carries a digit, and is neither structural nor a clause citation. Swallows one
   blank left behind by a removal.
✅ unwrapLines — Sources/Core/PasteHealing/UnwrapLines.swift — rejoins hard-wrapped
   paragraphs. A block unwraps only if ≥3 of its prose lines sit within 20% of its
   longest line; rejoin stops at sentence-terminal punctuation, blank lines,
   structure, column gaps and clause citations. A trailing "-" rejoins with NO space
   so criterion 3 holds across a line break and T3's dehyphenate still sees the
   hyphen. CRLF text is left alone. Input that arrives with NO line breaks (a
   Word/PDF paragraph copy) is pre-split first: `splitBlockOpeners` breaks before
   a dotted-numeral-plus-title, a `§`, or a capital `NOTE` that follows a
   completed sentence, then `splitLetterItems` breaks before `a)`/`b)` (D67).
✅ Stage-2 corpus baselines — Tests/Fixtures/paste-healing/*/expected-unwrapped.md —
   all 6 hand-authored. protected-compounds and web are byte-identical to stage 1 by
   design (every line ends a sentence / no consistent wrap column); both were proven
   to be genuinely loaded and compared by seeding a defect into each.

✅ scripts/validate.sh — criteria 8/9/10 coverage documented. Criterion 8
   (determinism) and 9 (idempotence) are Swift-execution checks (D26) covered by
   HealedStageTests + PasteHealerTests. Criterion 10 (clean-input no-op) is
   covered by GoldenDocumentTests + PasteHealerTests + golden-roundtrip.sh.
   validate.sh header now points to the owning tests rather than claiming a gap.

## Paste Healing (T3 — dehyphenate, detectTables, preserveClauseNumbers, heal)

✅ RejoinableWords lexicon — Sources/Core/PasteHealing/RejoinableWords.swift —
   hardcoded set of words a hyphenation split may legitimately reconstruct.
   Case-insensitive; strips trailing -s for plural resolution.  The primary
   gate of the inverted dehyphenate rule (D35): a hyphen is removed only when
   the joined form is a known word.  Err towards a SHORTER list — a missing
   word leaves a visible hyphen, an unwanted word fuses two words silently.
✅ CommonWords lexicon — Sources/Core/PasteHealing/CommonWords.swift — hardcoded,
   over-inclusive set of words that may lead a hyphenated compound. Not a
   spell-checker: no AppKit/NaturalLanguage dependency, so the same paste heals
   identically on every machine (criterion 2's second clause).  Now a secondary
   guard; `RejoinableWords` is the primary gate.
✅ dehyphenate — Sources/Core/PasteHealing/Dehyphenate.swift — removes a hyphen
   only when the token carries no digit, contains no protected compound, the left
   fragment is ≥2 letters / not an acronym / not in CommonWords, the right
   fragment starts lowercase, AND the joined form (with trailing punctuation
   stripped) is a known word in `RejoinableWords` (D35).  An unknown joined
   form keeps its hyphen — under-healing is visible and costs a keystroke,
   over-healing reads as correct and is not.
✅ detectTables — Sources/Core/PasteHealing/DetectTables.swift — whitespace-aligned
   (≥3 lines, same cell count ≥2, identical column offsets on every row) becomes a
   Markdown table; pipe rows lacking a delimiter row gain one and are otherwise
   left as typed. Fences and indented blocks untouched. A block that already has a
   delimiter row is returned unchanged, which is what makes it idempotent.
✅ preserveClauseNumbers — Sources/Core/PasteHealing/PreserveClauseNumbers.swift —
   escapes a 3-digit ordered-list marker (`411. Protection` → `411\. Protection`)
   so a clause number is not rendered as `1.`; 1- and 2-digit markers, dotted
   numerals, §, Table/Figure citations and fenced content untouched.
✅ PasteHealer.heal — Sources/Core/PasteHealing/PasteHealer.swift — the entry
   point, composing all six transforms in the D20-locked order. No call site: the
   paste hook is out of scope per the spec.
✅ Stage-3 corpus baselines — Tests/Fixtures/paste-healing/*/expected.md — all 6
   hand-authored. Every one is byte-identical to its stage-2 baseline BY DESIGN:
   no fixture contains a hyphenation split, aligned columns or a clause header, so
   the three T3 transforms are correctly identity across the corpus. All six were
   proven genuinely loaded by seeding a defect into each and getting exactly six
   failures.

✅ Paginated-standards-pdf fixture — Tests/Fixtures/paste-healing/paginated-standards-pdf/ —
   exercises criteria 2, 5, 6 and 7 positively. Contains running headers (≥3
   recurrence, blank-isolated), a `transfor-\nmer` hyphenation split, a
   whitespace-aligned rating table, and `411. General` clause headers. Added
   2026-08-11 — closes the corpus gap that was AMBER in PARKED.md.

✅ Unlined-word-paste fixture — Tests/Fixtures/paste-healing/unlined-word-paste/ —
   the sixth source class: a run of numbered definitions on ONE line, as Word and
   most PDF viewers put it on the clipboard. Exercises `splitBlockOpeners` (D67)
   end to end — clause openers, a capital NOTE, lettered items, an em dash and an
   NBSP unit separator. All three stage baselines hand-authored and diffed; the
   corpus is now 12 directories. Added 2026-08-13.

🔨 CommonWords is a curated list, not a dictionary — and is now a secondary
guard. The inverted rule (D35) makes `RejoinableWords` the primary gate:
a compound whose joined form is not known keeps its hyphen regardless of
whether its leading fragment is in CommonWords.

## Paste Healing Preview Toggle (Stage 3 — paste hook + preview sheet)

Scores (build-plan §4.1): Value 4 / Verifiability 5 / Blast radius 2 / Dep depth 1
→ priority 10.0. Spec: specs/paste-preview-toggle.md.

✅ PasteHealer.shouldSkipPastePreview — static guard: ≤80 chars AND no newline.
   Sources/Core/PasteHealing/PasteHealer.swift
✅ PasteDiff — public LCS line-diff: DiffLine enum + computeDiff function.
   Sources/Core/PasteHealing/PasteDiff.swift
✅ PastePreviewSheet — cross-platform SwiftUI sheet: side-by-side raw/healed
   diff, red/green color coding, 11pt monospaced, macOS min 480×280, iOS
   .medium/.large detents. Sources/Shared/PastePreviewSheet.swift
✅ macOS paste hook — KitibTextView.paste(_:) override → Coordinator.handlePaste.
   Re-entry guard: pastePreviewText != nil. Sheet in DetailView_macOS.swift.
✅ iOS paste hook — same subclass pattern. Sheet in DetailView_iOS.swift.
✅ AppState — showPastePreview (persisted toggle), pastePreviewText,
   pastePreviewHealed (computed), accept/reject/dismiss methods.
✅ Toolbar toggle — bandage icon on both platforms.
✅ Tests — 5 PastePreviewStateTests + 8 DiffLineTests. Suite: 291 tests, 0 failures.

## Document Identity (Stage 2 — UUID injection)

Scores (build-plan §4.1): Value 4 / Verifiability 5 / Blast radius 3 / Dep depth 1
→ priority 6.67. Spec: specs/file-identity.md.

✅ DocumentIdentity.injectID — Sources/Core/DocumentIdentity/DocumentIdentity.swift —
   injects a stable v4 UUID into YAML frontmatter when no `id` key exists.
   Idempotent; never overwrites an existing `id` (UUID or human-readable).
   Public API lowercases the UUID string (Foundation.UUID can return uppercase).
✅ UUID injection fixture corpus — Tests/Fixtures/uuid-injection/ — 6 directories
   covering: empty doc, content with no frontmatter, frontmatter without id,
   frontmatter with multiple keys (preservation), existing valid UUID (no-op),
   existing human-readable id (preservation). All fixtures use common test UUID
   so expected outputs are literal and comparable.
✅ DocumentIdentityTests — Tests/KitibTests/DocumentIdentity/DocumentIdentityTests.swift —
   12 tests: fixture-backed acceptance criteria, idempotence (including
   different-UUID-on-second-pass), UUIDv4 format validation, determinism,
   edge cases (whitespace before id:, id: in body vs frontmatter, description
   containing "id:" in value, frontmatter without closing fence), plus 10K
   collision check. Fixtures loaded from source tree via #filePath; bundled
   copy added to project.yml for TCC safety.
✅ project.yml updated — uuid-injection folder reference under KitibTests
   resources build phase (test-harness scaffolding, within D16 grant).

## Link Index (Stage 2 — wiki-link resolution)

Scores (build-plan §4.1): Value 4 / Verifiability 5 / Blast radius 2 / Dep depth 2
→ priority 5.0. Spec: specs/link-index.md.

✅ LinkIndex — Sources/Core/LinkIndex/LinkIndex.swift — resolves `[[wiki-links]]`
   to file paths via frontmatter metadata. Resolution order: title match → alias
   match → filename-stem fallback. Case-insensitive. First entry wins on
   duplicate keys. Accepts caller-supplied `[Entry]` tuples; no filesystem access.
✅ extractWikiLinks — Sources/Core/LinkIndex/LinkIndex.swift — finds every
   `[[target]]` span in a document, excluding those inside fenced code blocks
   (```) and inline backtick spans. Returns (global-range, target-text) pairs
   in document order. Empty `[[]]` links are skipped.
✅ LinkIndexTests — Tests/KitibTests/LinkIndex/LinkIndexTests.swift — 30 tests:
   13 for LinkIndex (title/alias/stem resolution, case-insensitive, priority
   ordering, first-wins determinism, broken-link nil, whitespace trimming) +
   17 for extractWikiLinks (basic/multiple/adjacent/heading/special-char links,
   code-fence immunity, inline-backtick immunity, nested fences, empty `[[]]`,
   unclosed links, tilde-fence non-toggle, indented-fence toggle).

## FTS5 Search (Stage 3 — full-text search index)

Scores (build-plan §4.1): Value 4 / Verifiability 4 / Blast radius 2 / Dep depth 1
→ priority 8.0. Spec: specs/fts5-search.md.

✅ SearchIndex — Sources/Core/Search/SearchIndex.swift — in-memory SQLite FTS5
   full-text search. Documents indexed as (id, title?, content). Search returns
   ranked results with highlighted snippets via FTS5 snippet(). Supports phrase
   search, boolean AND/OR/NOT, case-insensitive matching. Updates are atomic
   (delete+insert in a transaction). Uses import SQLite3 directly — no wrapper
   library, no new dependency.
✅ SearchIndexTests — Tests/KitibTests/Search/SearchIndexTests.swift — 22 tests:
   basic search, multi-document, phrase search, implicit AND, OR, NOT,
   case-insensitive, snippets with highlighting, update atomicity, remove,
   empty query/index, nil titles, title-field search, special characters,
   ranking (tf-idf), stale-token guard.

## Smart Folders (Stage 3 — saved searches in the sidebar)

Scores (build-plan §4.1): Value 4 / Verifiability 4 / Blast radius 1 / Dep depth 1
→ priority 16.0. Spec: specs/smart-folders.md. GREEN-tier.

✅ SmartFolder — struct (id, name, query), Codable. SmartFolderStore — load/
   save/add/rename/delete over UserDefaults (injectable defaults for tests).
   Sources/Core/Search/SmartFolder.swift
✅ QueryLint — pure detection of bare hyphenated terms (which FTS5 rejects with
   an error, not an empty result) + a quoting fix. In Core so it is testable
   (D65). 15 tests — Sources/Core/Search/QueryLint.swift
✅ AppState bridge — smartFolders (persisted), activeSmartFolderID,
   showSmartFolders, rebuildSearchIndex (walks root tree, indexes every .md
   by path), searchSmartFolder, activeSmartFolderResults, CRUD + open methods.
   Index rebuilt on refreshTree and saveCurrentFile. Sources/Shared/AppState.swift
✅ SmartFolderPanel — cross-platform SwiftUI: folder list + live results,
   add sheet, rename/delete context menu, click-through to open file.
   Sources/Shared/SmartFolderPanel.swift
✅ Sidebar integration — "SMART FOLDERS" section below the file tree with
   folder rows and a + button; sheet presentation. Sources/Shared/SidebarView.swift
✅ SmartFolderTests — 11 tests: CRUD round-trip, order preservation across
   reload, rename/delete by id (+ unknown-id no-ops), corrupt-blob recovery,
   query execution against SearchIndex, empty/no-match. Suite: 315 tests, 0 failures.

## Table Model (Stage 3 — Markdown table parser and grid model)

Scores (build-plan §4.1): Value 4 / Verifiability 5 / Blast radius 2 / Dep depth 1
→ priority 10.0. Spec: specs/table-model.md.

✅ MarkdownTable — Sources/Core/TableModel/MarkdownTable.swift — editable grid
   model for Markdown pipe tables. Parses fenced and unfenced tables, extracts
   alignment from delimiter row. Mutations: setCell, insertRow, deleteRow,
   insertColumn, deleteColumn. Serializes to fenced Markdown. Round-trip
   parse→serialize→reparse preserves headers, alignments, and data.
   Column-count mismatches handled (padding/truncation). Surrounding text
   preserved. Last-column deletion refused.
✅ MarkdownTableTests — Tests/KitibTests/TableModel/MarkdownTableTests.swift —
   33 tests: fenced/unfenced/mixed parse, alignment parsing (left/center/right),
   cell editing, row/column insert/delete, round-trip through serialize+reparse,
   surrounding text preservation, edge cases (empty cells, single column/row,
   no-table nil, header-without-delimiter nil), column-count mismatch padding,
   alignment serialization, full mutation round-trip, findTableRange (cursor in
   header/data/delimiter/outside/surrounding text, table at start/end of document).

## Table Grid Editor (N8 — SwiftUI grid projection over MarkdownTable)

Scores (build-plan §4.1): Value 4 / Verifiability 4 / Blast radius 3 / Dep depth 1
→ priority 5.33. Spec: specs/table-grid-editor.md.

✅ findTableRange — Sources/Core/TableModel/MarkdownTable.swift — detects the
   NSRange of the Markdown pipe table containing a cursor position. Walks
   upward and downward from the cursor to locate the delimiter and header
   rows, then collects all data rows. Returns nil when cursor is outside a table.
✅ TableGridEditor — Sources/Shared/TableGridEditor.swift — cross-platform
   SwiftUI editable grid view. Binds to MarkdownTable. Renders headers (bold,
   distinct background), alignment indicators, and data rows. Click/tap a cell
   to edit inline via TextField. Return commits; Escape discards.
✅ macOS integration — Sources/macOS/EditorView.swift + DetailView_macOS.swift —
   EditorView.Coordinator detects table at cursor on selection change, sets
   AppState.cursorInTable. Toolbar button ("tablecells" icon) appears when
   cursor is in a table. Resizable sheet shows TableGridEditor. On commit,
   serializes and replaces the table text in NSTextView.
✅ iOS integration — Sources/iOS/EditorView_iOS.swift + DetailView_iOS.swift —
   Same coordinator pattern on UITextView. Toolbar button triggers sheet with
   TableGridEditor. On commit, serializes and inserts via UITextView.
✅ AppState table editor state — cursorInTable, editingTable, editingTableRange,
   replaceTableText, openTableGrid — Sources/Shared/AppState.swift.

## Dynamic Outline (Stage 3 — heading hierarchy + section reorder)

Scores (build-plan §4.1): Value 4 / Verifiability 4 / Blast radius 3 / Dep depth 2
→ priority 2.67. Spec: specs/dynamic-outline.md.

✅ OutlineHeading — struct: level, text, lineNumber, range — Sources/Core/Outline/OutlineParser.swift
✅ OutlineNode — tree node with parent/children/sectionRange; id now
   "L\(level):\(text):L\(lineNumber)" so duplicate heading texts don't
   collide in SwiftUI ForEach — Sources/Core/Outline/OutlineParser.swift
✅ OutlineParser — parseHeadings (ATX, ignores fenced code blocks), buildHierarchy
   (ancestor-walk for level gaps), computeSectionRanges (heading to next
   equal-or-higher level) — Sources/Core/Outline/OutlineParser.swift
✅ SectionMover — moves a section by extracting its text range and reinserting
   at destination; newline-separator guard; heading-index-based inside-section
   rejection; trailing-blank-line skimming (strips excess \n\n after extracted
   section to avoid dragging inter-section gaps) — Sources/Core/Outline/SectionMover.swift
✅ OutlinePanel — cross-platform SwiftUI view, one reorder engine on both
   platforms (D51-D55). Drop target measured from real row frames via
   RowFramePreference in the "outlineList" space, frozen for the duration of a
   drag; plain VStack so zIndex holds and offscreen rows still have frames. A
   drag lifts the heading plus every nested heading as one opaque floating
   stack (count pill), leaves dashed ghosts in the vacated slots, and recedes
   the rest. Overlay drop indicator — the list never reflows mid-drag —
   indented to the level the section will land at. Status bar names the
   outcome, and refuses in orange when the target is inside the moving section
   (mirrors SectionMover's rejection, previously a silent no-op). Header with
   heading count, hierarchy rails, per-level markers, empty state. macOS drags
   from anywhere on the row (4pt); iOS long-press 0.28s + haptics.
   Sources/Shared/OutlinePanel.swift
✅ macOS integration — toolbar button (list.bullet), sheet, ⌘⇧O shortcut,
   scroll-to-heading via NSTextView.scrollRangeToVisible, move via
   replaceTableText bridge, Escape dismiss, sheet-closes-on-select —
   Sources/macOS/DetailView_macOS.swift, Sources/macOS/EditorView.swift
✅ iOS integration — toolbar button (list.bullet), sheet (.medium/.large
   detents), scroll-to via UITextView.scrollRangeToVisible —
   Sources/iOS/DetailView_iOS.swift, Sources/iOS/EditorView_iOS.swift
✅ AppState outline bridge — showOutline (persisted), outlineNodes (computed
   from text), scrollToHeading callback, moveOutlineSection method —
   Sources/Shared/AppState.swift
✅ 38 outline tests: OutlineParserFailureModeTests (5), OutlineParserTests (15),
   SectionMoverTests (11), plus 7 existing outline tests. Suite: 278 tests, 0
   failures.

## Web/ asset directory

🔨 web/ directory not found in repository — must be manually provisioned (KaTeX + Mermaid JS files); referenced by WebAssets.swift

## Rules Engine: Core Spine (Stage 5, Session 1 of 2)

Scores (spec §Scores): Value 4 / Verifiability 5 / Blast radius 2 / Dep depth 3
→ priority 3.3. Spec: specs/rules-engine.md (APPROVED 2026-08-31, D79).
Session split (human-confirmed): Session 1 = spine, Session 2 = the four rules.

✅ Diagnostic + DiagnosticSeverity: Sources/Core/Rules/Diagnostic.swift - the
  one shape every rule returns (ruleID, severity, message, range:
  Range<String.Index>). Nothing else; no fix field (spec out of scope).
✅ Rule protocol: Sources/Core/Rules/Rule.swift - ruleID, defaultSeverity,
  evaluate(_ projection:). A new rule is a new file; the engine never changes.
✅ DocumentProjection: Sources/Core/Rules/DocumentProjection.swift -
  build(from:linkIndex:) runs the four authorised sources ONCE (criterion 6):
  OutlineParser headings + section ranges, extractWikiLinks, table ranges via
  MarkdownTableParser.findTableRange (probed per pipe line, containment
  re-checked, D80), and the exclusion zones. linkIndex is Optional so rules
  can distinguish "index says no" from "no index supplied" (failure mode 6).
  Also: range(fromNSRange:) conversion helper + isInside{Fence,InlineCode,
  Frontmatter} queries.
✅ ExclusionSpans: Sources/Core/Rules/ExclusionSpans.swift - the ONLY new
  scanning (tripwire): fenced code (``` and ~~~, toggle semantics matching
  OutlineParser, unterminated fences run to EOF), inline backticks (matching
  runs of equal length per CommonMark 6.1, multiline-capable, unclosed spans
  run to paragraph end), frontmatter (--- opener, ---/... closer, at document
  start only).
✅ RuleConfiguration: Sources/Core/Rules/RuleConfiguration.swift - per-ruleID
  enable/disable + severity override (criterion 4).
✅ RuleEngine: Sources/Core/Rules/RuleEngine.swift - run(rules:on:
  configuration:) concatenates, skips disabled rules BEFORE evaluate (they
  cost nothing), applies severity overrides, sorts by (range start, ruleID,
  rule index, emit index) for a deterministic TOTAL order (criterion 3,
  failure mode 7; Swift's sorted is not stable, so rule/emit index
  tie-breakers are required).
✅ Rules tests: Tests/KitibTests/Rules/ - 52 tests: RuleConfigurationTests
  (8), RuleEngineTests (14), DocumentProjectionTests (30). Covers failure
  modes 1 (fence + backtick immunity at scanner level), 2 (frontmatter),
  3 (exact ranges + out-of-bounds nil), 7 (order determinism), 9 (severity
  override) and criteria 1-6. Suite: 465 tests, all 52 green; Executed-N
  rose 413 → 465 (D22).
✅ HeadingLevelJumpRule: Sources/Core/Rules/HeadingLevelJumpRule.swift -
  pairwise against the PREVIOUS heading's level (failure mode 5); range
  covers the marker run only; message pins the jump (level A to level B).
✅ EmptySectionRule: Sources/Core/Rules/EmptySectionRule.swift - any
  non-whitespace content counts, so subheadings/table/fence/image-only
  sections are NOT empty (failure mode 4); a heading followed directly by
  another heading IS empty; range covers the heading line.
✅ BrokenWikiLinkRule: Sources/Core/Rules/BrokenWikiLinkRule.swift - the
  spec's only error rule; nil index emits nothing (failure mode 6); reads
  projection.wikiLinks, so fence/backtick exclusion is extractWikiLinks'
  (sole authority); range covers the [[link]] span.
✅ ForbiddenPhraseRule: Sources/Core/Rules/ForbiddenPhraseRule.swift -
  caller-supplied (pattern, message, severity); literal case-insensitive
  substring matching; excludes fences, inline code, frontmatter (failure
  mode 2) and table delimiter rows (D82); per-phrase severity preserved
  unless the configuration overrides (D81); empty patterns ignored.
✅ Rules fixtures: Tests/KitibTests/Rules/Fixtures/ - 9 fixtures + README
  (defect/clean twin per rule + exclusion-zones corpus), bundled as a folder
  reference (project.yml, D29), loader RulesFixtures (bundle-first).
✅ Session-2 tests: RulesCorpusTests (5, incl. exclusion-zones ZERO +
  determinism), HeadingLevelJumpRuleTests (8), EmptySectionRuleTests (10),
  BrokenWikiLinkRuleTests (8), ForbiddenPhraseRuleTests (14),
  GoldenDocumentRuleTests (3, zero errors + pinned warning counts, all zero),
  +1 RuleEngine severity-preservation test (D81). Suite: 514 tests, all new
  green; Executed-N rose 465 -> 514 (D22). Kitib-macOS builds.
✅ Spec complete: all ten acceptance criteria implemented and tested; the
  four rules are the last of specs/rules-engine.md's deliverables.
⬜ Presentation layer (Problems panel, inline underlines) and the QA export
  gate are out of scope per the spec; separate tasks, human-scheduled.
