# CURRENT.md: the single active task. Rewritten each session. Cap: 40 lines.

## THIS SESSION: rules engine Session 1 of 2 (engine spine) (2026-08-31)

"GO WITH SESSION 1" confirmed the split proposed at the end of the previous
session: spine first, rules second. Built per specs/rules-engine.md (APPROVED,
D79). All exact spec identifiers; GREEN tier, no deviation.

- Diagnostic + DiagnosticSeverity, Rule, RuleConfiguration, RuleEngine:
  Sources/Core/Rules/ (6 files)
- DocumentProjection.build(from:linkIndex:) runs the four authorised sources
  once: OutlineParser, extractWikiLinks, MarkdownTableParser.findTableRange
  (probed per pipe line, containment re-checked, D80), ExclusionSpans
  (fences ```/~~~, inline backticks, frontmatter; the ONLY new scanning;
  tripwire respected)
- 52 new tests: Tests/KitibTests/Rules/ (RuleConfiguration 8, RuleEngine 14,
  DocumentProjection 30, incl. failure modes 1/2/3/7/9 at spine level)
- xcodegen generate + Executed-N rose 413 → 465 (D22); all 52 green;
  Kitib-macOS app target builds; all new content em-dash-free

PRE-EXISTING RED (not this session's; left untouched per §5): NewFileTargetTests
testSelectedFileAtDepthThreeTargetsDepthTwoParent expects /Vault/Projects/2026
but the code returns /Vault/Projects/2026/Riyadh (the file's actual parent).
Present in the 413-test baseline run before any Session-1 file existed. Human
decides: fix the test or fix NewFileTarget.

## NEXT: Session 2, the four rules + fixtures (specs/rules-engine.md)

HeadingLevelJumpRule (compare against the PREVIOUS heading's level, failure
mode 5; range covers the marker), EmptySectionRule (subheadings-only NOT
empty; table/image/fence-only NOT empty, failure mode 4), BrokenWikiLinkRule
(LinkIndex nil = error; no index supplied = nothing, failure mode 6; the only
error rule), ForbiddenPhraseRule (prose only; fences, inline code, delimiter
rows, frontmatter excluded). DoD: failure-mode tests before implementation;
per-rule fixtures with exact counts/ranges/severities; exclusion-zone corpus
(one fixture, expected ZERO diagnostics); range-validity property test over
every fixture; golden documents zero errors with pinned warning counts;
determinism; every fixture loaded by a test; fixtures at
Tests/KitibTests/Rules/Fixtures/ (spec location; add to project.yml
resources + a loader mirroring FixtureCorpus's bundle-first pattern, D29).

## Gotchas carried forward

- findTableRange: range ends BEFORE last row's trailing newline; walk-up can
  return a table above the probe line (containment re-check, D80).
- extractWikiLinks toggles fences on ``` only; ~~~ content IS link-scanned.
- FEATURES.md / DECISIONS.md pre-existing content is em-dash-heavy; new
  content stays em-dash-free (user rule).
- PagePlan protects TOP-LEVEL blocks only; standardPrintInfo() sets ZERO margins.
- FTS5 splits hyphenated terms; a saved query for one errors unless quoted.
- iPad in portrait reports .regular width; the sidebar collapses until toggled.
- PARKED still: background indexing (RED), lazy FileItem (AMBER), license files
  not in Xcode app resources (AMBER).
