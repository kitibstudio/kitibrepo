# FTS5 Search Index

Source: `docs/blueprint-v2.md` §2.3. Build order: `docs/build-plan.md` Stage 3.

## Intent

Full-text search over all documents in the workspace — content and frontmatter —
with boolean operators, phrase search, and ranked snippets. No UI; the data
layer only.

## Scores

Per `build-plan.md` §4.1.

| Axis | Score | Justification |
|---|---|---|
| Value | 4 | Search is the primary navigation mechanism in a knowledge base. |
| Verifiability | 4 | SQLite FTS5 is deterministic; query results are machine-checkable. Snippets need human review for quality. |
| Blast radius | 2 | Read-only index; wrong results don't corrupt documents. Index is rebuildable from source files. |
| Dependency depth | 1 | Nothing must exist first. |

**Priority = 4 × 4 ÷ (2 × 1) = 8.0.** Blast radius < 4 ⇒ no rollback plan required.

## Acceptance criteria

1. **Index.** Documents are added as `(id: String, title: String?, content: String)`
   tuples. The index tokenises content for full-text search.
2. **Basic search.** A single word query returns every document containing that
   word, ranked by relevance.
3. **Phrase search.** `"voltage drop"` (quoted) matches only documents containing
   that exact phrase.
4. **Boolean AND.** `cable schedule` (default) matches documents containing both
   words (implicit AND).
5. **Boolean OR.** `cable OR schedule` matches documents containing either word.
6. **Boolean NOT.** `cable NOT schedule` matches documents containing "cable" but
   not "schedule".
7. **Case-insensitive.** `VOLTAGE` and `voltage` return the same results.
8. **Snippets.** Each result includes a snippet of text around the match,
   suitable for display in a results list.
9. **Update.** Re-indexing a document with the same ID replaces its previous
   content atomically.
10. **Remove.** Removing a document by ID makes it disappear from search results.

## Out of scope

- **UI** — no SwiftUI search field, results panel, or keyboard shortcut.
- **FTS5 database file on disk** — the index is in-memory. Persistence (saving
  the index to disk, rebuilding on launch) is the caller's concern.
- **Frontmatter field search** (`title:protection`) — Stage 3+.
- **Scoped searches / smart folders** — Stage 3+.
- **File-system watcher integration** — the caller decides when to re-index.
- **Stemming / language-specific tokenisation** — FTS5 defaults only.

## Test plan

- **Unit tests:** a known set of documents indexed; queries asserted for
  result IDs, ordering, and snippet content.
- **Boolean operator tests:** AND (implicit), OR, NOT, quoted phrases, mixed.
- **Update/remove tests:** re-index same ID → new content; remove → query
  returns no results for that doc.
- **Empty index tests:** search before any documents added → empty results.
- **Edge cases:** special characters in queries, very long documents, empty
  content, nil titles.

## Failure modes

1. **Silent no-results on valid query.** The FTS5 tokeniser strips a term the
   user expected to match (e.g. a number or symbol) — `11kV` becomes `11` and
   `kv` or is dropped entirely.
2. **Ranking surprises.** A document containing the term once in a footer ranks
   above one containing it ten times in the body because FTS5's default ranking
   (bm25) weights document length differently.
3. **Snippet truncation mid-word.** The snippet window cuts a word in half,
   producing a confusing preview.
4. **Update not atomic.** Updating a document leaves stale tokens from the
   previous version, producing false positives.
5. **SQL injection via search query.** FTS5 query syntax (`column:term`) could
   be exploited if the query string is not sanitised.

## Named entities

- `SearchIndex` — class (stateful, wraps SQLite FTS5). Methods:
  `init()`, `index(id:title:content:)`, `remove(id:)`,
  `search(_ query: String) -> [SearchResult]`.
- `SearchResult` — struct: `id: String, title: String?, snippet: String`.
- Location: `Sources/Core/Search/`. Tests: `Tests/KitibTests/Search/`.
- Uses `import SQLite3` (system library, no new dependency).
