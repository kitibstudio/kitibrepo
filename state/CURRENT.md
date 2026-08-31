# CURRENT.md — the single active task. Rewritten each session. Cap: 40 lines.

## THIS SESSION — repo re-established + docs repair (2026-08-31)

The working copy at /Volumes/Samsung 990 2TB/Development/Kitib Studio had NO git
repo (the old one lives at ~/Documents/Claude/Projects/MD, last commit 2026-08-17,
diverged). Created a fresh repo here (main, 3ef3ca8) and pushed to
github.com/kitibstudio/kitibrepo; the remote's old pre-XcodeGen history was
archived to branch legacy-pre-xcodegen, main force-pushed.

Repaired pre-existing corruption: bash ENOSPC junk lines sat at file scope in
Sources/Shared/{ContentView,KitibCommands,SidebarView}.swift (invalid Swift;
targets would not compile). Stripped (fbaf6a3). Both targets build.

README rewritten for the cross-platform XcodeGen project (037d4ce): three
platforms, real build path, current layout, 6 templates, full shortcut table,
shipped features. Screenshots tracked (!images/*.png exception). Two false
claims caught and removed before commit (rules engine, doc-id injection: Core
types exist with zero call sites). THIRD-PARTY-LICENSES.txt gained bundled
versions. Zero em dashes, semicolon style. LICENSE unchanged: MIT, (c) 2026 Sean.

## RULED — swift-markdown Open RED (D79, 2026-08-31)

Human ruling: NOT YET. specs/rules-engine.md is APPROVED; no dependency; tripwire
stands guard; N14/N15/N37 wait. Re-raise if a rule needs inline syntax the
projection cannot scan.

## NEXT — build the rules engine per specs/rules-engine.md (Stage 5)

Acceptance criteria (spec §Acceptance criteria): one Diagnostic shape
(ruleID/severity/message/range); pluggable RuleEngine.run(rules:on:); deterministic
order (range start, then ruleID); per-rule configurable severity/disable; valid
accurate ranges; projection built once; heading-level jump; empty section;
broken wiki-link (nil-vs-no-index distinction, failure mode 6); forbidden phrase
on prose only. Out of scope: AST, fixes, Problems panel, incremental eval,
linguistic/glossary/reference/unit/normative rules, JSON rule packs, export gate,
MarkdownHighlighter changes.

DoD per AGENTS.md §6 + spec §Test plan: failure-mode tests BEFORE implementation;
unit fixtures per rule with exact counts/ranges/severities; exclusion-zone corpus
(one fixture, expected ZERO diagnostics); range-validity property test; golden
documents zero errors with pinned warning counts; determinism test; every fixture
loaded by a test; xcodegen generate + confirm Executed-N count rises.

## Gotchas carried forward

- PagePlan protects TOP-LEVEL blocks only; standardPrintInfo() sets ZERO margins.
- FTS5 splits hyphenated terms; a saved query for one errors unless quoted.
- iPad in portrait reports .regular width; the sidebar collapses until toggled.
- PARKED still: background indexing (RED), lazy FileItem (AMBER), license files
  not in Xcode app resources (AMBER).
