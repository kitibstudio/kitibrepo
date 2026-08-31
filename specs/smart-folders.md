# Smart Folders (saved searches)

Source: `docs/blueprint-v2.md` §2.3. Build order: Stage 3+.
Spec: this document. Status: **DRAFT — awaiting human approval.**

## Intent

A named, saved search that appears in the sidebar as a folder. Opening it runs the
query against the workspace and shows live results. The writer defines a query once
("earth-fault protection", "Dyn11", `cable NOT schedule`) and revisits it with one
click instead of re-typing it.

`SearchIndex` (FTS5) is built and tested but has **zero call sites** — no search
field, no results view, no AppState wiring. This feature is therefore the first
consumer of the search engine, not just a persistence layer.

## Scores

Per `build-plan.md` §4.1. GREEN-tier — UserDefaults persistence, no data-model
change, no file-format change, no new dependency.

| Axis | Score | Justification |
|---|---|---|
| Value | 4 | Recurring queries become one-click. Search stops being a tool and becomes structure. |
| Verifiability | 4 | Query→results is deterministic (FTS5). Folder CRUD and persistence are unit-testable. |
| Blast radius | 1 | Read-only index; a wrong result opens the wrong doc, never corrupts one. |
| Dependency depth | 1 | `SearchIndex` exists and is tested. Nothing else must exist first. |

## Acceptance criteria

Each independently testable.

1. **Smart folder model.** A `SmartFolder` is `(id: UUID, name: String, query: String)`.
   Persisted in UserDefaults as a JSON array. Create, rename, delete.

2. **Workspace indexing.** AppState builds a `SearchIndex` over every Markdown file
   under the open root folder, keyed by file path, title = filename stem, content =
   file text. Rebuilt when the root changes or a file is saved.

3. **Query execution.** Opening a smart folder runs its query against the index and
   shows hits (title + snippet) ranked by relevance. Empty query → empty results.
   No match → an explicit "No results" state, not a silent blank panel.

4. **Click-through.** Clicking a result opens that file in the editor.

5. **Persistence round-trip.** Smart folders survive app relaunch. Order preserved.

6. **Determinism.** Same query, same workspace, same results — every time.

7. **No-op on closed root.** With no folder open, smart folders render as an empty
   section with a hint, never crash.

## Out of scope

- **Global disk search** — index covers the open root folder only.
- **Live re-index on every keystroke** — index refreshes on file save / root change.
- **Query editing UI beyond name+query fields** — no syntax highlighting.
- **Nested/grouped smart folders**, sharing, or export.
- **Disk-persisted FTS5 database** — index stays in-memory (as built).
- **Frontmatter field search** (`title:protection`).

## Test plan

- **SmartFolderStoreTests:** create/rename/delete/order-preserving round-trip through
  UserDefaults (with an in-memory UserDefaults suite, not the real one).
- **SmartFolderSearchTests:** index a known set of documents, assert a saved query
  returns the expected IDs in ranked order; empty query → empty; no match → empty.
- **Fixture-backed:** reuse a small on-disk fixture set indexed and queried, asserting
  the fixture files are actually opened (not just declared).
- **Manual:** create a folder, type `cable`, see hits; relaunch, folder persists.

## Failure modes

1. **Stale index.** A file is edited but the index still holds old content, so a
   smart folder shows a hit for text that no longer exists. Guard: re-index on
   `textChanged`/save, or rebuild on folder open.
2. **Silent empty results.** A query that FTS5 tokenises into nothing (e.g. `11kV`)
   returns zero hits with no explanation. Guard: show "No results" plus the query.
3. **Path-keyed collisions.** Two files with the same name in different folders
   collide on filename stem. Guard: key by full path (already the `FileItem.id`
   convention, D4).
4. **Deleted file lingers.** A result points at a file deleted since indexing.
   Guard: filter results against files still on disk before opening.
5. **UserDefaults decode failure.** A corrupt smart-folder blob throws on launch.
   Guard: decode with `try?` and fall back to an empty list.

## Named entities

- `SmartFolder` — struct: `id: UUID, name: String, query: String`. Codable.
- `SmartFolderStore` — class: load/save/add/rename/delete over UserDefaults,
  key `"smartFolders"`.
- `SmartFolderResults` — computed in AppState: run a folder's query against the
  workspace `SearchIndex`.
- `SmartFolderPanel` — cross-platform SwiftUI view: lists folders, shows results,
  click-to-open.
- Location: `Sources/Core/Search/SmartFolder.swift` (model + store),
  `Sources/Shared/SmartFolderPanel.swift` (UI). Tests:
  `Tests/KitibTests/Search/SmartFolderTests.swift`.
