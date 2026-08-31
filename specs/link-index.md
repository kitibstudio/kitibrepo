# Link Index — Wiki-Link Resolution

Source: `docs/blueprint-v2.md` §1.3. Build order: `docs/build-plan.md` Stage 2.
Architecture: DECISIONS.md A4 (locked). Depends on: DocumentIdentity.injectID (done).

## Intent

`[[wiki-links]]` resolve to file paths via a frontmatter-based index — by title,
alias, or filename stem — so renaming a file on disk never breaks a link.

## Scores

Per `build-plan.md` §4.1.

| Axis | Score | Justification |
|---|---|---|
| Value | 4 | Links are the backbone of a knowledge base; broken links are the most visible rot. |
| Verifiability | 5 | Pure data structure + String parsing. No filesystem needed — the index accepts `[(path, metadata)]` tuples. |
| Blast radius | 2 | Read-only resolution. The index is rebuilt from source files; wrong resolution is visible immediately. |
| Dependency depth | 2 | Depends on frontmatter `id` (DocumentIdentity, done). No AST, no UI. |

**Priority = 4 × 5 ÷ (2 × 2) = 5.0.** Blast radius < 4 ⇒ no rollback plan required.

## Acceptance criteria

1. **Title match.** `[[My Document]]` resolves to the file whose frontmatter
   `title: My Document` matches, regardless of the filename on disk.
2. **Alias match.** `[[short-name]]` resolves to the file whose frontmatter
   `aliases: [short-name, other]` contains that alias.
3. **Filename-stem fallback.** `[[my-doc]]` resolves to `my-doc.md` when no
   title or alias matches — the filename stem (without extension) is the
   lowest-priority match.
4. **Case-insensitive.** `[[my document]]` matches `title: My Document`.
   Matching is case-insensitive for titles and aliases. Path resolution is
   platform-specific.
5. **Broken link detection.** A link whose target matches nothing in the index
   is flagged as broken (`nil` path).
6. **Multiple links.** A document containing several `[[links]]` resolves each
   independently — one broken link does not affect others.
7. **Deterministic.** Same index + same link text → same resolution every time.
8. **Code-fence immunity.** `[[text]]` inside a fenced code block or inline
   backticks is NOT resolved — it's literal Markdown, not a wiki-link.

## Out of scope

- **Filesystem scanning** — the index is built from caller-supplied tuples, not
  by reading a directory. The caller (AppState) provides `[(path, metadata)]`.
- **Backlinks panel** — needs UI (Stage 3+).
- **Block-level links** (`[[doc#heading]]`) — needs block IDs (Stage 5+).
- **Link rendering in preview/export** — UI concern.
- **Live re-indexing on file add/rename** — the index is rebuilt on demand;
  the caller decides when.
- **Transclusion** (`![[doc]]`) — Stage 9.

## Test plan

- **Unit fixtures:** a set of `(path, id, title, aliases)` tuples forming known
  indexes. Tests assert resolution for each acceptance criterion.
- **Link-extraction unit tests:** documents with `[[links]]` in various
  positions — prose, headings, inside code fences, inside inline backticks,
  multiple on one line, adjacent without spacing.
- **Golden fixtures:** a directory of `.md` files with known frontmatter.
  The index is built from them; a separate document containing `[[links]]`
  is tested for correct resolution.
- **Broken-link corpus:** links to non-existent targets assert `nil` resolution.

## Failure modes

1. **Filename shadows title.** Two documents share the same title — which one
   wins? Resolution must be deterministic (first in index order wins).
2. **Case-confused duplicates.** `title: Alpha` and `title: alpha` in different
   files — the index must detect the collision and choose deterministically
   rather than silently oscillating.
3. **Link text with special characters.** `[[BS 7671:2018]]` contains a colon —
   the link parser must handle it, and the matcher must find the title exactly.
4. **Code-fence false negative.** A `[[link]]` inside a code fence that the
   parser misses gets resolved — corrupting a code example into a hyperlink.
5. **Silent nil on typo.** `[[Protction]]` (misspelled title) returns nil
   with no diagnostic — the author doesn't know the link is broken.

## Named entities

- `LinkIndex` — the struct. `init(entries: [Entry])` where `Entry` is
  `(path: String, id: String?, title: String?, aliases: [String])`.
- `LinkIndex.resolve(_ target: String) -> String?` — returns the matched path
  or nil.
- `extractWikiLinks(_ raw: String) -> [(range: Range<String.Index>, target: String)]`
  — finds all `[[...]]` in a document, excluding those inside code fences and
  inline backticks.
- Location: `Sources/Core/LinkIndex/`. Tests: `Tests/KitibTests/LinkIndex/`.
