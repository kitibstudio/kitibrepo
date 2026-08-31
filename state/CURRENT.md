# CURRENT.md: the single active task. Rewritten each session. Cap: 40 lines.

## THIS SESSION: rules engine Session 2 of 2 (the four rules) (2026-08-31)

CONFIRMED started Session 2. specs/rules-engine.md is now COMPLETE: all ten
acceptance criteria implemented and tested.

- HeadingLevelJumpRule, EmptySectionRule, BrokenWikiLinkRule,
  ForbiddenPhraseRule: Sources/Core/Rules/ (exact spec identifiers, ruleIDs
  heading-level-jump / empty-section / broken-wiki-link / forbidden-phrase)
- Engine fix (D81): severity replaced ONLY under an explicit configuration
  override, so per-phrase severities survive (criterion 10)
- ForbiddenPhraseRule mirrors MarkdownTableParser.isDelimiterRow for
  delimiter-row exclusion (D82, tripwire respected)
- Fixtures: Tests/KitibTests/Rules/Fixtures/ (9 + README), bundled as folder
  reference; Tests/KitibTests sources entry excludes Rules/Fixtures to avoid
  duplicate resource copies
- 49 new tests (corpus 5, heading-jump 8, empty-section 10, broken-link 8,
  forbidden 14, golden 3, engine +1). Suite: 514 tests; Executed-N rose
  465 -> 514 (D22); all new green; golden docs zero errors, warning pins
  all zero (a level-1 title followed by level-2 sections runs to EOF and
  holds content, so it is not empty)

PRE-EXISTING RED (unchanged, not this session's): NewFileTargetTests
testSelectedFileAtDepthThreeTargetsDepthTwoParent (expects
/Vault/Projects/2026, code returns /Vault/Projects/2026/Riyadh). Present in
the 413-test baseline before Session 1. Human decides: fix test or fix code.

## NEXT: human picks. The spec's deferred items, in rough order:

1. Problems panel + inline underlines: the presentation layer for
   diagnostics. Spec out of scope (D16-untestable UI; AppState + editors).
2. QA export gate: blueprint 3 "exports require a clean pass". Needs the
   diagnostics wired to export; separate spec.
3. Required-section-per-template rules: needs the template system (4.3),
   which does not exist.
4. Incremental on-edit evaluation: engine runs whole documents now; the
   pure (text) -> [Diagnostic] shape makes it safe to add later.
5. Any other build-plan stage the human wants.

## Gotchas carried forward

- extractWikiLinks is frontmatter-blind and toggles fences on ``` only
  (D80/D82): [[link]] in frontmatter IS flagged; corpus keeps [[...]] out.
- findTableRange: range ends BEFORE last row's trailing newline; walk-up can
  return a table above the probe line (containment re-check, D80).
- isDelimiterRow input arrives with a trailing newline; trim before pipe
  stripping (Session-2 bug caught by the delimiter-row test).
- FEATURES.md / DECISIONS.md pre-existing content is em-dash-heavy; new
  content stays em-dash-free (user rule).
- PagePlan protects TOP-LEVEL blocks only; standardPrintInfo() ZERO margins.
- FTS5 splits hyphenated terms; a saved query for one errors unless quoted.
- PARKED: background indexing (RED), lazy FileItem (AMBER), license files
  (AMBER), extractWikiLinks frontmatter-blindness (new, link feature).
