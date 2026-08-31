# Rules engine fixtures

Corpus for specs/rules-engine.md Session 2 (the four rules). Every file is
loaded and compared by a test; RulesCorpusTests asserts the on-disk set
matches RulesFixtures.names exactly, so a stray or missing fixture fails.

| File | Rule | Expected diagnostics |
|---|---|---|
| exclusion-zones.md | all four | ZERO: each rule's trigger sits inside a fence, inline backticks, and frontmatter |
| heading-jump-defect.md | heading-level-jump | 2 warnings: `####` after `##`, `######` after `####` |
| heading-jump-clean.md | heading-level-jump | 0 |
| empty-section-defect.md | empty-section | 1 warning: `## Empty` |
| empty-section-clean.md | empty-section | 0: subheadings, table, fence, image all count as content |
| broken-link-defect.md | broken-wiki-link | 1 error: `[[missing]]` (index resolves `present`) |
| broken-link-clean.md | broken-wiki-link | 0: case-insensitive resolution |
| forbidden-defect.md | forbidden-phrase | 2: `TODO` (info), `Draft` (warning) |
| forbidden-clean.md | forbidden-phrase | 0 |

Caveats (inherited parser behaviour, recorded in D80/D82, not rules-engine
defects):

- extractWikiLinks is frontmatter-blind: a `[[link]]` in frontmatter IS
  extracted and would be flagged. The corpus therefore keeps `[[...]]` out of
  frontmatter; the sole-authority parser makes that zone untestable at zero.
- OutlineParser parses ATX headings inside frontmatter; the corpus keeps
  heading-like lines out of frontmatter for the same reason.
- Expected values are pinned in the rule tests, never derived by running the
  implementation (D26 spirit: a check that calls the code it checks is an
  echo).
